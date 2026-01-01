import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:bech32/bech32.dart';
import 'package:nostr_dart/nostr_dart.dart';
import 'relay_pool_manager.dart';
import 'nostr_profile_service.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:pointycastle/export.dart' as pc;

/// Model for a DM conversation
class DMConversation {
  final String pubkey; // Other party's pubkey
  String? displayName;
  String? avatarUrl;
  final List<DirectMessage> messages;
  int unreadCount;
  DateTime lastMessageAt;
  String? lastMessagePreview;

  /// Optional P2P offer context if DM is related to an offer
  String? relatedOfferId;
  String? offerTitle;

  DMConversation({
    required this.pubkey,
    this.displayName,
    this.avatarUrl,
    List<DirectMessage>? messages,
    this.unreadCount = 0,
    DateTime? lastMessageAt,
    this.lastMessagePreview,
    this.relatedOfferId,
    this.offerTitle,
  }) : messages = messages ?? [],
       lastMessageAt = lastMessageAt ?? DateTime.now();
}

/// Model for a single direct message
class DirectMessage {
  final String id;
  final String senderPubkey;
  final String recipientPubkey;
  final String content;
  final DateTime timestamp;
  final bool isFromMe;
  final bool isRead;

  /// Tags that might reference P2P offers or other events
  final List<List<String>> tags;

  DirectMessage({
    required this.id,
    required this.senderPubkey,
    required this.recipientPubkey,
    required this.content,
    required this.timestamp,
    required this.isFromMe,
    this.isRead = false,
    this.tags = const [],
  });
}

/// Service for managing Nostr DMs (NIP-04)
class DMService {
  static final DMService _instance = DMService._internal();
  factory DMService() => _instance;
  DMService._internal();

  final RelayPoolManager _relayPool = RelayPoolManager();
  final NostrProfileService _profileService = NostrProfileService();
  final _storage = const FlutterSecureStorage();

  // Cache of conversations
  final Map<String, DMConversation> _conversations = {};

  // Stream controller for real-time DM updates
  final _dmController = StreamController<DirectMessage>.broadcast();
  Stream<DirectMessage> get dmStream => _dmController.stream;

  // Stream controller for unread count
  final _unreadController = StreamController<int>.broadcast();
  Stream<int> get unreadCountStream => _unreadController.stream;

  bool _isSubscribed = false;
  int _totalUnread = 0;

  /// Get total unread count
  int get totalUnreadCount => _totalUnread;

  /// Get all conversations sorted by last message
  List<DMConversation> get conversations {
    final list = _conversations.values.toList();
    list.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    return list;
  }

  /// Initialize DM service and start listening
  Future<void> initialize() async {
    if (_isSubscribed) return;

    final pubkey = _profileService.currentPubkey;
    if (pubkey == null) {
      debugPrint('⚠️ DMService: No pubkey available, cannot initialize');
      return;
    }

    // Ensure relay pool is initialized
    if (!_relayPool.isInitialized) {
      debugPrint('📨 DMService: Initializing relay pool...');
      await _relayPool.init();
    }

    // Load cached conversations
    await _loadCachedConversations();

    // Subscribe to incoming DMs
    await _subscribeToDMs(pubkey);

    _isSubscribed = true;
    debugPrint('✅ DMService: Initialized and subscribed to DMs');
  }

  /// Subscribe to DMs sent to us
  Future<void> _subscribeToDMs(String pubkey) async {
    debugPrint('📨 DMService: Subscribing to DMs for $pubkey');

    // Ensure relay pool is initialized
    if (!_relayPool.isInitialized) {
      await _relayPool.init();
    }

    // Filter for DMs sent to us (kind 4 = encrypted DM)
    final filter = <String, dynamic>{
      'kinds': [4],
      '#p': [pubkey],
    };

    _relayPool.subscribe(filter, (event) async {
      try {
        await _handleIncomingDM(event, pubkey);
      } catch (e) {
        debugPrint('⚠️ DMService: Error handling DM: $e');
      }
    });
  }

  /// Fetch DM history from ALL relays with generous limits
  Future<void> fetchDMHistory({int limit = 100}) async {
    final pubkey = _profileService.currentPubkey;
    if (pubkey == null) {
      debugPrint('⚠️ DMService: No pubkey, cannot fetch DMs');
      return;
    }

    // Ensure relay pool is initialized
    if (!_relayPool.isInitialized) {
      debugPrint('📨 DMService: Initializing relay pool for DM history...');
      await _relayPool.init();
    }

    final connectedCount = _relayPool.connectedCount;
    debugPrint(
      '📨 DMService: Fetching DM history from $connectedCount relays...',
    );

    // Fetch DMs sent to us - no time limit, get ALL historical DMs
    final receivedFilter = <String, dynamic>{
      'kinds': [4],
      '#p': [pubkey],
      'limit': limit,
    };

    // Fetch DMs sent by us
    final sentFilter = <String, dynamic>{
      'kinds': [4],
      'authors': [pubkey],
      'limit': limit,
    };

    // Use longer timeout and query ALL connected relays
    final received = await _relayPool.fetch(
      filter: receivedFilter,
      timeoutSeconds: 30,
      maxEvents: limit * 3, // Allow more events than limit
      maxRelays: 15, // Query all relays including new ones
    );

    final sent = await _relayPool.fetch(
      filter: sentFilter,
      timeoutSeconds: 30,
      maxEvents: limit * 3,
      maxRelays: 15,
    );

    debugPrint(
      '📨 DMService: Fetched ${received.length} incoming, ${sent.length} sent DMs',
    );

    int processedReceived = 0;
    int processedSent = 0;
    int decryptionErrors = 0;

    // Process received DMs
    for (final event in received) {
      final success = await _handleIncomingDM(event, pubkey);
      if (success) {
        processedReceived++;
      } else {
        decryptionErrors++;
      }
    }

    // Process sent DMs
    for (final event in sent) {
      final success = await _handleSentDM(event, pubkey);
      if (success) {
        processedSent++;
      } else {
        decryptionErrors++;
      }
    }

    debugPrint(
      '📨 DMService: Processed $processedReceived incoming, $processedSent sent (${decryptionErrors} decryption errors)',
    );
    debugPrint('📨 DMService: Total ${_conversations.length} conversations');

    // Cache conversations
    await _cacheConversations();
  }

  /// Handle incoming DM event - returns true if successful
  Future<bool> _handleIncomingDM(dynamic event, String myPubkey) async {
    try {
      final senderPubkey = event.pubkey as String;
      final content = event.content as String;
      final id = event.id as String;
      final createdAt = event.timestamp as int;
      final tags =
          (event.tags as List<dynamic>)
              .map(
                (t) => (t as List<dynamic>).map((e) => e.toString()).toList(),
              )
              .toList();

      // Decrypt the message
      final decrypted = await _decryptMessage(content, senderPubkey);
      if (decrypted == null) {
        return false;
      }

      final dm = DirectMessage(
        id: id,
        senderPubkey: senderPubkey,
        recipientPubkey: myPubkey,
        content: decrypted,
        timestamp: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
        isFromMe: false,
        tags: tags,
      );

      _addMessageToConversation(senderPubkey, dm, isIncoming: true);
      _dmController.add(dm);
      return true;
    } catch (e) {
      debugPrint('⚠️ DMService: Error handling incoming DM: $e');
      return false;
    }
  }

  /// Handle sent DM event (our outgoing messages) - returns true if successful
  Future<bool> _handleSentDM(dynamic event, String myPubkey) async {
    try {
      final id = event.id as String;
      final content = event.content as String;
      final createdAt = event.timestamp as int;
      final tags =
          (event.tags as List<dynamic>)
              .map(
                (t) => (t as List<dynamic>).map((e) => e.toString()).toList(),
              )
              .toList();

      // Find recipient from tags
      String? recipientPubkey;
      for (final tag in tags) {
        if (tag.isNotEmpty && tag[0] == 'p' && tag.length > 1) {
          recipientPubkey = tag[1];
          break;
        }
      }

      if (recipientPubkey == null) return false;

      // Decrypt the message
      final decrypted = await _decryptMessage(content, recipientPubkey);
      if (decrypted == null) return false;

      final dm = DirectMessage(
        id: id,
        senderPubkey: myPubkey,
        recipientPubkey: recipientPubkey,
        content: decrypted,
        timestamp: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
        isFromMe: true,
        isRead: true,
        tags: tags,
      );

      _addMessageToConversation(recipientPubkey, dm, isIncoming: false);
      return true;
    } catch (e) {
      debugPrint('⚠️ DMService: Error handling sent DM: $e');
      return false;
    }
  }

  /// Add message to conversation
  void _addMessageToConversation(
    String otherPubkey,
    DirectMessage dm, {
    required bool isIncoming,
  }) {
    if (!_conversations.containsKey(otherPubkey)) {
      _conversations[otherPubkey] = DMConversation(pubkey: otherPubkey);
    }

    final convo = _conversations[otherPubkey]!;

    // Check for duplicates
    if (convo.messages.any((m) => m.id == dm.id)) return;

    convo.messages.add(dm);
    convo.messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (dm.timestamp.isAfter(convo.lastMessageAt)) {
      convo.lastMessageAt = dm.timestamp;
      convo.lastMessagePreview =
          dm.content.length > 50
              ? '${dm.content.substring(0, 50)}...'
              : dm.content;
    }

    if (isIncoming && !dm.isRead) {
      convo.unreadCount++;
      _totalUnread++;
      _unreadController.add(_totalUnread);
    }

    // Check for P2P offer context
    _detectOfferContext(dm, convo);
  }

  /// Detect if DM is related to a P2P offer
  void _detectOfferContext(DirectMessage dm, DMConversation convo) {
    // Check tags for offer references
    for (final tag in dm.tags) {
      if (tag.length >= 2) {
        // Look for 'e' tag referencing an event (could be offer)
        if (tag[0] == 'e') {
          convo.relatedOfferId = tag[1];
        }
        // Look for custom offer tag
        if (tag[0] == 'offer') {
          convo.relatedOfferId = tag[1];
        }
      }
    }

    // Check content for P2P keywords
    final lower = dm.content.toLowerCase();
    if (lower.contains('offer') ||
        lower.contains('trade') ||
        lower.contains('buy') ||
        lower.contains('sell') ||
        lower.contains('btc') ||
        lower.contains('sats') ||
        lower.contains('available')) {
      // Mark as trade-related even without explicit tag
      convo.offerTitle ??= 'Trade Inquiry';
    }
  }

  /// Send a DM to another user
  Future<bool> sendDM({
    required String recipientPubkey,
    required String message,
    String? relatedOfferId,
  }) async {
    final myPubkey = _profileService.currentPubkey;
    if (myPubkey == null) {
      debugPrint('❌ DMService: No pubkey available');
      return false;
    }

    try {
      // Ensure relay pool is initialized
      if (!_relayPool.isInitialized) {
        await _relayPool.init();
      }

      // Get nsec for encryption and signing
      final nsec = await _profileService.getNsec();
      if (nsec == null) {
        debugPrint('❌ DMService: No nsec available');
        return false;
      }

      final hexPrivKey = _nsecToHex(nsec);
      if (hexPrivKey == null) {
        debugPrint('❌ DMService: Failed to convert nsec to hex');
        return false;
      }

      // Encrypt message
      final encrypted = await _encryptMessage(
        message,
        recipientPubkey,
        hexPrivKey,
      );
      if (encrypted == null) {
        debugPrint('❌ DMService: Failed to encrypt message');
        return false;
      }

      // Build tags
      final tags = <List<String>>[
        ['p', recipientPubkey],
      ];
      if (relatedOfferId != null) {
        tags.add(['e', relatedOfferId]);
      }

      // Create and sign event using nostr_dart
      // ignore: unused_local_variable
      final nostrInstance = Nostr(privateKey: hexPrivKey);
      final event = Event(myPubkey, 4, tags, encrypted);

      final signedEvent = <String, dynamic>{
        'id': event.id,
        'pubkey': myPubkey,
        'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'kind': 4,
        'tags': tags,
        'content': encrypted,
        'sig': event.sig,
      };

      debugPrint(
        '📤 DMService: Publishing signed DM event ${event.id.substring(0, 8)}...',
      );

      // Publish to relays
      final successCount = await _relayPool.publish(signedEvent);

      if (successCount > 0) {
        debugPrint('✅ DMService: DM sent to $successCount relays');
        // Add to local conversation
        final dm = DirectMessage(
          id: event.id,
          senderPubkey: myPubkey,
          recipientPubkey: recipientPubkey,
          content: message,
          timestamp: DateTime.now(),
          isFromMe: true,
          isRead: true,
        );
        _addMessageToConversation(recipientPubkey, dm, isIncoming: false);
        return true;
      }

      debugPrint('❌ DMService: Failed to publish to any relay');
      return false;
    } catch (e) {
      debugPrint('❌ DMService: Error sending DM: $e');
      return false;
    }
  }

  /// Mark conversation as read
  void markConversationAsRead(String pubkey) {
    final convo = _conversations[pubkey];
    if (convo != null) {
      _totalUnread -= convo.unreadCount;
      convo.unreadCount = 0;
      _unreadController.add(_totalUnread);
    }
  }

  /// Encrypt message using NIP-04
  Future<String?> _encryptMessage(
    String message,
    String recipientPubkey,
    String privateKeyHex,
  ) async {
    try {
      // Generate shared secret using ECDH
      final sharedSecret = _computeSharedSecret(privateKeyHex, recipientPubkey);
      if (sharedSecret == null) return null;

      // Generate random IV
      final iv = encrypt.IV.fromSecureRandom(16);

      // Encrypt with AES-256-CBC
      final key = encrypt.Key.fromBase64(base64.encode(sharedSecret));
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.cbc),
      );
      final encrypted = encrypter.encrypt(message, iv: iv);

      // NIP-04 format: base64(encrypted)?iv=base64(iv)
      return '${encrypted.base64}?iv=${iv.base64}';
    } catch (e) {
      debugPrint('❌ DMService: Encryption error: $e');
      return null;
    }
  }

  /// Decrypt message using NIP-04
  Future<String?> _decryptMessage(
    String encryptedContent,
    String otherPubkey,
  ) async {
    try {
      final nsec = await _profileService.getNsec();
      if (nsec == null) return null;

      final hexPrivKey = _nsecToHex(nsec);
      if (hexPrivKey == null) return null;

      // Parse NIP-04 format
      final parts = encryptedContent.split('?iv=');
      if (parts.length != 2) return null;

      final encryptedData = base64.decode(parts[0]);
      final ivData = base64.decode(parts[1]);

      // Compute shared secret
      final sharedSecret = _computeSharedSecret(hexPrivKey, otherPubkey);
      if (sharedSecret == null) return null;

      // Decrypt
      final key = encrypt.Key.fromBase64(base64.encode(sharedSecret));
      final iv = encrypt.IV(ivData);
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.cbc),
      );
      final encrypted = encrypt.Encrypted(encryptedData);
      final decrypted = encrypter.decrypt(encrypted, iv: iv);

      return decrypted;
    } catch (e) {
      debugPrint('⚠️ DMService: Decryption error: $e');
      return null;
    }
  }

  /// Compute ECDH shared secret using secp256k1
  /// This implements proper NIP-04 shared secret computation
  List<int>? _computeSharedSecret(String privateKeyHex, String otherPubkeyHex) {
    try {
      // Parse private key
      final privateKeyBytes = _hexToBytes(privateKeyHex);
      if (privateKeyBytes == null) return null;

      // Parse public key (add 02 prefix for compressed format if needed)
      String pubkeyWithPrefix = otherPubkeyHex;
      if (otherPubkeyHex.length == 64) {
        // x-only pubkey, need to add prefix (assume even y)
        pubkeyWithPrefix = '02$otherPubkeyHex';
      }
      final publicKeyBytes = _hexToBytes(pubkeyWithPrefix);
      if (publicKeyBytes == null) return null;

      // Set up secp256k1 curve
      final domainParams = pc.ECDomainParameters('secp256k1');

      // Create private key
      final privateKeyBigInt = _bytesToBigInt(privateKeyBytes);
      final ecPrivateKey = pc.ECPrivateKey(privateKeyBigInt, domainParams);

      // Decode public key point
      final publicKeyPoint = domainParams.curve.decodePoint(publicKeyBytes);
      if (publicKeyPoint == null) return null;

      // Perform ECDH: multiply public key by private key scalar
      final sharedPoint = publicKeyPoint * ecPrivateKey.d;
      if (sharedPoint == null || sharedPoint.x == null) return null;

      // NIP-04 uses only the x-coordinate of the shared point
      final sharedX = sharedPoint.x!.toBigInteger();
      if (sharedX == null) return null;

      // Convert to 32 bytes (padded if needed)
      final sharedXBytes = _bigIntToBytes(sharedX, 32);

      debugPrint('🔐 DMService: Computed proper ECDH shared secret');
      return sharedXBytes;
    } catch (e) {
      debugPrint('❌ DMService: ECDH computation error: $e');
      return null;
    }
  }

  /// Convert hex string to bytes
  Uint8List? _hexToBytes(String hex) {
    try {
      if (hex.length % 2 != 0) return null;
      final bytes = Uint8List(hex.length ~/ 2);
      for (int i = 0; i < hex.length; i += 2) {
        bytes[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
      }
      return bytes;
    } catch (e) {
      return null;
    }
  }

  /// Convert bytes to BigInt
  BigInt _bytesToBigInt(Uint8List bytes) {
    BigInt result = BigInt.zero;
    for (int i = 0; i < bytes.length; i++) {
      result = (result << 8) | BigInt.from(bytes[i]);
    }
    return result;
  }

  /// Convert BigInt to bytes with specified length
  List<int> _bigIntToBytes(BigInt value, int length) {
    final bytes = <int>[];
    var v = value;
    while (v > BigInt.zero) {
      bytes.insert(0, (v & BigInt.from(0xff)).toInt());
      v = v >> 8;
    }
    // Pad to required length
    while (bytes.length < length) {
      bytes.insert(0, 0);
    }
    return bytes.take(length).toList();
  }

  /// Convert nsec to hex
  String? _nsecToHex(String nsec) {
    try {
      if (!nsec.startsWith('nsec1')) return null;
      final decoded = const Bech32Codec().decode(nsec);
      final data = _convertBits(decoded.data, 5, 8, false);
      if (data == null) return null;
      return data.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    } catch (e) {
      return null;
    }
  }

  List<int>? _convertBits(List<int> data, int fromBits, int toBits, bool pad) {
    var acc = 0;
    var bits = 0;
    final result = <int>[];
    final maxv = (1 << toBits) - 1;

    for (final value in data) {
      if (value < 0 || (value >> fromBits) != 0) return null;
      acc = (acc << fromBits) | value;
      bits += fromBits;
      while (bits >= toBits) {
        bits -= toBits;
        result.add((acc >> bits) & maxv);
      }
    }

    if (pad) {
      if (bits > 0) result.add((acc << (toBits - bits)) & maxv);
    } else if (bits >= fromBits || ((acc << (toBits - bits)) & maxv) != 0) {
      return null;
    }

    return result;
  }

  /// Cache conversations to local storage
  Future<void> _cacheConversations() async {
    try {
      final data = _conversations.map(
        (key, value) => MapEntry(key, {
          'pubkey': value.pubkey,
          'displayName': value.displayName,
          'avatarUrl': value.avatarUrl,
          'unreadCount': value.unreadCount,
          'lastMessageAt': value.lastMessageAt.millisecondsSinceEpoch,
          'lastMessagePreview': value.lastMessagePreview,
          'relatedOfferId': value.relatedOfferId,
          'offerTitle': value.offerTitle,
        }),
      );
      await _storage.write(key: 'dm_conversations', value: jsonEncode(data));
    } catch (e) {
      debugPrint('⚠️ DMService: Error caching conversations: $e');
    }
  }

  /// Load cached conversations
  Future<void> _loadCachedConversations() async {
    try {
      final cached = await _storage.read(key: 'dm_conversations');
      if (cached == null) return;

      final data = jsonDecode(cached) as Map<String, dynamic>;
      for (final entry in data.entries) {
        final map = entry.value as Map<String, dynamic>;
        _conversations[entry.key] = DMConversation(
          pubkey: map['pubkey'] as String,
          displayName: map['displayName'] as String?,
          avatarUrl: map['avatarUrl'] as String?,
          unreadCount: map['unreadCount'] as int? ?? 0,
          lastMessageAt: DateTime.fromMillisecondsSinceEpoch(
            map['lastMessageAt'] as int? ?? 0,
          ),
          lastMessagePreview: map['lastMessagePreview'] as String?,
          relatedOfferId: map['relatedOfferId'] as String?,
          offerTitle: map['offerTitle'] as String?,
        );
        _totalUnread += _conversations[entry.key]!.unreadCount;
      }
      _unreadController.add(_totalUnread);
    } catch (e) {
      debugPrint('⚠️ DMService: Error loading cached conversations: $e');
    }
  }

  /// Enrich conversations with profile data
  Future<void> enrichWithProfiles() async {
    for (final convo in _conversations.values) {
      if (convo.displayName == null) {
        final profile = await _profileService.fetchProfile(convo.pubkey);
        if (profile != null) {
          convo.displayName = profile.displayName ?? profile.name;
          convo.avatarUrl = profile.picture;
        }
      }
    }
  }

  /// Dispose resources
  void dispose() {
    _dmController.close();
    _unreadController.close();
  }
}
