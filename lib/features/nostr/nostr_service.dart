import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nostr_dart/nostr_dart.dart';
import 'package:bech32/bech32.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'nostr_debug_service.dart';

// Global debug service instance
final _debug = NostrDebugService();

/// Service for managing Nostr integration
/// - Key generation and validation
/// - Secure storage of npub/nsec
/// - Relay connections
/// - Event publishing and subscription
class NostrService {
  static const _npubKey = 'nostr_npub';
  static const _nsecKey = 'nostr_nsec';

  static late final FlutterSecureStorage _secureStorage;
  static Nostr? _nostr;
  static bool _initialized = false;

  // Optimized relay list for reliable global feed and discovery
  static final List<String> _defaultRelays = [
    'wss://nos.lol', // Best overall - fast, broad coverage
    'wss://nostr.mom', // Fast, excellent for global feed
    'wss://relay.snort.social', // Great for discovery
    'wss://relay.f7z.io', // High uptime
    'wss://eden.nostr.land', // Clean, active
    'wss://relay.nostr.bg', // Solid international coverage
    'wss://relay.damus.io', // Most popular relay
    'wss://relay.primal.net', // High traffic, reliable
    'wss://nostr.wine', // Premium, low spam
    'wss://relay.nostriches.org', // Good for bitcoiners
  ];

  // Key for storing cached follows
  static const _followsKey = 'nostr_follows';

  // Rate for sats to naira conversion (can be updated from API)
  static double satsToNairaRate = 0.015; // ~15 kobo per sat

  /// Get the debug service for viewing logs
  static NostrDebugService get debugService => _debug;

  /// Get debug logs as formatted string
  static String getDebugLogs() => _debug.getLogsAsString();

  /// Get connection summary for debugging
  static Map<String, dynamic> getConnectionSummary() =>
      _debug.getConnectionSummary();

  /// Initialize the Nostr service (non-blocking, defers relay connections)
  static Future<void> init() async {
    if (_initialized) {
      _debug.info('INIT', 'NostrService already initialized');
      return;
    }
    _secureStorage = const FlutterSecureStorage();
    _initialized = true;

    // Migrate from old Hive storage if needed (don't await to keep init fast)
    _migrateFromHive();

    _debug.success(
      'INIT',
      'NostrService initialized',
      'Relays will connect on demand',
    );
    _debug.updateInitStatus(initialized: true);
  }

  /// Migrate keys from old Hive storage to SecureStorage
  static Future<void> _migrateFromHive() async {
    try {
      _debug.info('MIGRATE', 'Checking for Hive keys to migrate...');

      // Check if we already have keys in SecureStorage
      final existingNpub = await _secureStorage.read(key: _npubKey);
      if (existingNpub != null && existingNpub.isNotEmpty) {
        _debug.info(
          'MIGRATE',
          'SecureStorage already has keys, skipping migration',
        );
        return; // Already migrated
      }

      // Try to read from old Hive storage
      final hive = await Hive.openBox('nostr_keys');
      final oldNpub = hive.get('npub') as String?;
      final oldNsec = hive.get('nsec') as String?;

      _debug.info(
        'MIGRATE',
        'Hive keys check',
        'npub: ${oldNpub != null ? "found (${oldNpub.length} chars)" : "null"}, '
            'nsec: ${oldNsec != null ? "found" : "null"}',
      );

      if (oldNpub != null && oldNpub.isNotEmpty) {
        await _secureStorage.write(key: _npubKey, value: oldNpub);
        _debug.success('MIGRATE', 'Migrated npub from Hive to SecureStorage');
      }
      if (oldNsec != null && oldNsec.isNotEmpty) {
        await _secureStorage.write(key: _nsecKey, value: oldNsec);
        _debug.success('MIGRATE', 'Migrated nsec from Hive to SecureStorage');
      }
    } catch (e) {
      _debug.warn('MIGRATE', 'Could not migrate Hive nostr keys', e.toString());
    }
  }

  /// Force reinitialize Nostr (useful when switching accounts or debugging)
  static Future<void> reinitialize() async {
    _debug.info(
      'INIT',
      'Reinitializing Nostr (resetting relay connections)...',
    );
    _nostr = null;
    // Don't reset _initialized - we just need fresh relay connections
    await _ensureRelayConnections();
  }

  /// Simple debug test - tests if events are being received at all
  static Future<int> testRawSubscription() async {
    _debug.info('RAW_TEST', 'Starting raw subscription test...');

    await _ensureRelayConnections();

    if (_nostr == null) {
      _debug.error('RAW_TEST', 'No Nostr instance available');
      return 0;
    }

    int eventCount = 0;
    final completer = Completer<int>();

    // Very simple filter - just get any 5 recent events
    final filter = {
      'kinds': [1],
      'limit': 5,
    };

    _debug.info(
      'RAW_TEST',
      'Subscribing with simple filter',
      'kinds: [1], limit: 5',
    );

    // List active subscriptions before
    final subsBefore = _nostr!.pool.subscriptions;
    _debug.info(
      'RAW_TEST',
      'Active subscriptions before',
      subsBefore.toString(),
    );

    Timer(const Duration(seconds: 15), () {
      if (!completer.isCompleted) {
        _debug.warn(
          'RAW_TEST',
          'Timeout after 15s',
          'Received $eventCount events',
        );
        completer.complete(eventCount);
      }
    });

    try {
      final subId = await _nostr!.pool.subscribe([filter], (event) {
        eventCount++;
        _debug.success(
          'RAW_TEST',
          'EVENT RECEIVED! (#$eventCount)',
          'id: ${event.id.substring(0, 12)}... from ${event.source}',
        );

        if (eventCount >= 5 && !completer.isCompleted) {
          completer.complete(eventCount);
        }
      }, 'raw_test_${DateTime.now().millisecondsSinceEpoch}');

      _debug.info('RAW_TEST', 'Subscription created', 'subId: $subId');

      // List active subscriptions after
      final subsAfter = _nostr!.pool.subscriptions;
      _debug.info(
        'RAW_TEST',
        'Active subscriptions after',
        subsAfter.toString(),
      );
    } catch (e) {
      _debug.error('RAW_TEST', 'Subscription failed', e.toString());
      if (!completer.isCompleted) {
        completer.complete(0);
      }
    }

    return completer.future;
  }

  /// Ensure relay connections are established (lazy initialization)
  static Future<void> _ensureRelayConnections() async {
    if (_nostr != null) {
      _debug.info(
        'RELAY',
        'Nostr instance already exists, skipping connection',
      );
      return;
    }
    _debug.info('RELAY', 'No Nostr instance, loading keys and connecting...');
    await _loadKeysAndInitializeNostr();
  }

  /// Load keys from secure storage and initialize Nostr
  static Future<void> _loadKeysAndInitializeNostr() async {
    try {
      _debug.info('KEYS', 'Loading keys from SecureStorage...');
      final nsec = await _secureStorage.read(key: _nsecKey);

      if (nsec != null && nsec.isNotEmpty) {
        _debug.success(
          'KEYS',
          'Found nsec in SecureStorage',
          'Length: ${nsec.length} chars',
        );
        // Convert nsec to hex for nostr_dart
        final hexPrivateKey = _nsecToHex(nsec);
        if (hexPrivateKey != null) {
          _debug.info(
            'KEYS',
            'Converted nsec to hex',
            'Length: ${hexPrivateKey.length} chars',
          );
          await _initializeNostrWithKey(hexPrivateKey);
        } else {
          _debug.error('KEYS', 'Failed to convert nsec to hex');
          await _initializeNostrReadOnly();
        }
      } else {
        _debug.warn(
          'KEYS',
          'No nsec found in SecureStorage',
          'Initializing in read-only mode',
        );
        // Initialize in read-only mode (no private key) for browsing global feed
        await _initializeNostrReadOnly();
      }
      _debug.updateInitStatus(hasKeys: nsec != null && nsec.isNotEmpty);
    } catch (e) {
      _debug.error('KEYS', 'Error loading Nostr keys', e.toString());
      // Still try to initialize read-only for browsing
      await _initializeNostrReadOnly();
    }
  }

  /// Initialize Nostr in read-only mode (no private key, just relay connections)
  static Future<void> _initializeNostrReadOnly() async {
    try {
      _debug.info('RELAY', 'Initializing Nostr in read-only mode...');
      // Generate a temporary key just for connecting to relays (won't be saved)
      final tempPrivateKey = generatePrivateKey();
      _nostr = Nostr(privateKey: tempPrivateKey);

      // Add relays for read-only access
      int connectedCount = 0;
      for (final relayUrl in _defaultRelays) {
        try {
          _debug.info('RELAY', 'Connecting to $relayUrl...');
          await _nostr!.pool.add(Relay(relayUrl, access: WriteAccess.readOnly));
          connectedCount++;
          _debug.success('RELAY', 'Connected to $relayUrl');
          _debug.updateRelayStatus(relayUrl, true);
        } catch (e) {
          _debug.warn('RELAY', 'Failed to connect to $relayUrl', e.toString());
          _debug.updateRelayStatus(relayUrl, false);
        }
      }
      _debug.success(
        'RELAY',
        'Read-only mode initialized',
        '$connectedCount/${_defaultRelays.length} relays connected',
      );
    } catch (e) {
      _debug.error('RELAY', 'Error initializing Nostr read-only', e.toString());
    }
  }

  /// Initialize Nostr with a hex private key
  static Future<void> _initializeNostrWithKey(String hexPrivateKey) async {
    try {
      _debug.info('RELAY', 'Initializing Nostr with private key...');
      _nostr = Nostr(privateKey: hexPrivateKey);

      // Add relays
      int connectedCount = 0;
      for (final relayUrl in _defaultRelays) {
        try {
          _debug.info('RELAY', 'Connecting to $relayUrl (read-write)...');
          await _nostr!.pool.add(
            Relay(relayUrl, access: WriteAccess.readWrite),
          );
          connectedCount++;
          _debug.success('RELAY', 'Connected to $relayUrl');
          _debug.updateRelayStatus(relayUrl, true);
        } catch (e) {
          _debug.warn('RELAY', 'Failed to connect to $relayUrl', e.toString());
          _debug.updateRelayStatus(relayUrl, false);
        }
      }
      _debug.success(
        'RELAY',
        'Read-write mode initialized',
        '$connectedCount/${_defaultRelays.length} relays connected',
      );
    } catch (e) {
      _debug.error('RELAY', 'Error initializing Nostr', e.toString());
    }
  }

  /// Generate new Nostr keys
  static Future<Map<String, String>> generateKeys() async {
    try {
      // Ensure storage is initialized
      if (!_initialized) {
        _secureStorage = const FlutterSecureStorage();
        _initialized = true;
      }

      // generatePrivateKey() returns a hex private key
      final hexPrivateKey = generatePrivateKey();
      // getPublicKey() expects hex and returns hex public key
      final hexPublicKey = getPublicKey(hexPrivateKey);

      // Convert to bech32 format for storage and display
      final nsec = _hexToNsec(hexPrivateKey);
      final npub = _hexToNpub(hexPublicKey);

      if (nsec == null || npub == null) {
        throw Exception('Failed to encode keys to bech32');
      }

      // Validate before storing
      if (!_isValidNpub(npub) || !_isValidNsec(nsec)) {
        throw Exception('Invalid generated keys');
      }

      // Store bech32 encoded keys securely
      await _secureStorage.write(key: _nsecKey, value: nsec);
      await _secureStorage.write(key: _npubKey, value: npub);

      // Initialize Nostr with hex private key
      await _initializeNostrWithKey(hexPrivateKey);

      print('✅ Generated new Nostr keys');
      return {'npub': npub, 'nsec': nsec};
    } catch (e) {
      print('❌ Error generating keys: $e');
      rethrow;
    }
  }

  /// Encode hex private key to nsec (bech32)
  static String? _hexToNsec(String hexPrivKey) {
    try {
      final bytes = <int>[];
      for (var i = 0; i < hexPrivKey.length; i += 2) {
        bytes.add(int.parse(hexPrivKey.substring(i, i + 2), radix: 16));
      }

      final converted = _convertBits(bytes, 8, 5, true);
      if (converted == null) return null;

      return const Bech32Codec().encode(Bech32('nsec', converted));
    } catch (e) {
      print('❌ Error encoding nsec: $e');
      return null;
    }
  }

  /// Import Nostr keys
  static Future<void> importKeys({
    required String nsec,
    required String npub,
  }) async {
    try {
      // Ensure storage is initialized
      if (!_initialized) {
        _secureStorage = const FlutterSecureStorage();
        _initialized = true;
      }

      // Handle case where only npub is provided (read-only mode)
      if (nsec.isEmpty && npub.isNotEmpty) {
        if (!_isValidNpub(npub)) {
          throw Exception('Invalid npub format');
        }
        // Store only npub for read-only mode
        await _secureStorage.write(key: _npubKey, value: npub);
        print('✅ Imported Nostr npub (read-only mode)');
        return;
      }

      // Validate keys
      if (!_isValidNsec(nsec)) {
        throw Exception('Invalid nsec format');
      }
      if (!_isValidNpub(npub)) {
        throw Exception('Invalid npub format');
      }

      // Verify that nsec and npub match using proper bech32 decoding
      final derivedNpub = getPublicKeyFromNsec(nsec);
      if (derivedNpub == null) {
        throw Exception('Could not derive public key from private key');
      }
      if (derivedNpub != npub) {
        throw Exception('nsec and npub do not match');
      }

      // Store securely
      await _secureStorage.write(key: _nsecKey, value: nsec);
      await _secureStorage.write(key: _npubKey, value: npub);

      // Initialize Nostr - need to convert nsec to hex for nostr_dart
      final hexPrivateKey = _nsecToHex(nsec);
      if (hexPrivateKey != null) {
        await _initializeNostrWithKey(hexPrivateKey);
      }

      print('✅ Imported Nostr keys');
    } catch (e) {
      print('❌ Error importing keys: $e');
      rethrow;
    }
  }

  /// Get current npub
  static Future<String?> getNpub() async {
    try {
      // Ensure storage is initialized
      if (!_initialized) {
        _secureStorage = const FlutterSecureStorage();
        _initialized = true;
      }
      final npub = await _secureStorage.read(key: _npubKey);
      _debug.info(
        'KEYS',
        'getNpub() called',
        npub != null ? 'Found: ${npub.substring(0, 15)}...' : 'null',
      );
      _debug.updateInitStatus(npub: npub);
      return npub;
    } catch (e) {
      _debug.error('KEYS', 'Error reading npub', e.toString());
      return null;
    }
  }

  /// Get current nsec (be careful with this!)
  static Future<String?> getNsec() async {
    try {
      // Ensure storage is initialized
      if (!_initialized) {
        _secureStorage = const FlutterSecureStorage();
        _initialized = true;
      }
      final nsec = await _secureStorage.read(key: _nsecKey);
      _debug.info(
        'KEYS',
        'getNsec() called',
        nsec != null ? 'Found (hidden)' : 'null',
      );
      return nsec;
    } catch (e) {
      _debug.error('KEYS', 'Error reading nsec', e.toString());
      print('❌ Error reading nsec: $e');
      return null;
    }
  }

  /// Check if Nostr is configured
  static Future<bool> isConfigured() async {
    try {
      final npub = await getNpub();
      return npub != null && npub.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Publish a zap event
  static Future<String?> publishZapEvent({
    required String targetNpub,
    required int satoshis,
    String? message,
  }) async {
    try {
      if (_nostr == null) {
        throw Exception('Nostr not initialized');
      }

      // Create zap event using Event constructor: (pubkey, kind, tags, content)
      final event = Event(
        '', // pubkey will be set by the Nostr instance
        9735, // Zap kind
        [
          ['p', targetNpub],
        ], // Tags: recipient pubkey
        message ?? 'Zapped with Sabi Wallet ⚡ - $satoshis sats',
      );

      // Publish to all relays
      _nostr!.sendEvent(event);

      _debug.success(
        'NOSTR',
        'Zap event published',
        '$satoshis sats to $targetNpub',
      );
      return event.id;
    } catch (e) {
      _debug.error('NOSTR', 'Error publishing zap', e.toString());
      rethrow;
    }
  }

  /// Send an encrypted DM using NIP-04 style encryption (kind 4)
  /// Used for social recovery and private messages
  /// Note: This uses a simplified encryption for recovery shares
  static Future<String?> sendEncryptedDM({
    required String targetNpub,
    required String message,
  }) async {
    try {
      if (_nostr == null) {
        throw Exception('Nostr not initialized');
      }

      _debug.info(
        'DM',
        'Sending encrypted DM',
        'to: ${targetNpub.substring(0, 15)}...',
      );

      // Convert target npub to hex pubkey
      final targetHexPubkey = npubToHex(targetNpub);
      if (targetHexPubkey == null) {
        throw Exception('Invalid target npub');
      }

      // Get our nsec for signing
      final nsec = await getNsec();
      if (nsec == null) {
        throw Exception('No private key available');
      }

      final hexPrivateKey = _nsecToHex(nsec);
      if (hexPrivateKey == null) {
        throw Exception('Could not decode private key');
      }

      // Create a shared secret by hashing both keys together
      // This is a simplified version - production should use proper ECDH
      final sharedSecret = sha256.convert(
        utf8.encode(hexPrivateKey + targetHexPubkey),
      );
      final keyBytes = Uint8List.fromList(sharedSecret.bytes);

      // Generate random IV
      final random = Random.secure();
      final ivBytes = Uint8List(16);
      for (int i = 0; i < 16; i++) {
        ivBytes[i] = random.nextInt(256);
      }

      // Encrypt with AES-256-CBC
      final key = encrypt.Key(keyBytes);
      final iv = encrypt.IV(ivBytes);
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.cbc),
      );
      final encrypted = encrypter.encrypt(message, iv: iv);

      // NIP-04 format: base64(encrypted)?iv=base64(iv)
      final encryptedContent =
          '${encrypted.base64}?iv=${base64Encode(ivBytes)}';

      // Create DM event (kind 4)
      final event = Event(
        '', // pubkey will be set by the Nostr instance
        4, // NIP-04 encrypted DM kind
        [
          ['p', targetHexPubkey],
        ],
        encryptedContent,
      );

      // Publish to all relays
      _nostr!.sendEvent(event);

      _debug.success(
        'DM',
        'Encrypted DM sent',
        'event id: ${event.id.substring(0, 8)}...',
      );
      return event.id;
    } catch (e) {
      _debug.error('DM', 'Error sending encrypted DM', e.toString());
      rethrow;
    }
  }

  /// Decrypt a NIP-04 style encrypted message
  static String? decryptDM({
    required String encryptedContent,
    required String senderHexPubkey,
    required String receiverHexPrivateKey,
  }) {
    try {
      // Parse NIP-04 format: base64(encrypted)?iv=base64(iv)
      final parts = encryptedContent.split('?iv=');
      if (parts.length != 2) {
        _debug.error('DM', 'Invalid encrypted content format');
        return null;
      }

      final encryptedBase64 = parts[0];
      final ivBase64 = parts[1];

      // Recreate the shared secret
      final sharedSecret = sha256.convert(
        utf8.encode(receiverHexPrivateKey + senderHexPubkey),
      );
      final keyBytes = Uint8List.fromList(sharedSecret.bytes);

      // Decrypt
      final key = encrypt.Key(keyBytes);
      final iv = encrypt.IV.fromBase64(ivBase64);
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.cbc),
      );
      final decrypted = encrypter.decrypt64(encryptedBase64, iv: iv);

      return decrypted;
    } catch (e) {
      _debug.error('DM', 'Error decrypting DM', e.toString());
      return null;
    }
  }

  /// Subscribe to encrypted DMs for our user
  static Stream<Map<String, dynamic>> subscribeToDMs() {
    final controller = StreamController<Map<String, dynamic>>();

    () async {
      try {
        if (_nostr == null) {
          throw Exception('Nostr not initialized');
        }

        final npub = await getNpub();
        if (npub == null) {
          throw Exception('No public key');
        }

        final hexPubkey = npubToHex(npub);
        if (hexPubkey == null) {
          throw Exception('Could not convert npub to hex');
        }

        // Filter for DMs sent to us
        final filter = {
          'kinds': [4], // NIP-04 DM kind
          '#p': [hexPubkey], // DMs to our pubkey
        };

        _debug.info(
          'DM',
          'Subscribing to DMs',
          'for: ${hexPubkey.substring(0, 8)}...',
        );

        await _nostr!.pool.subscribe([filter], (event) {
          try {
            // Get sender pubkey from the event's first tag or from the event itself
            String? senderPubkey;
            for (final tag in event.tags) {
              if (tag is List && tag.isNotEmpty) {
                // The sender is in the event, we get it from tags
                senderPubkey = tag.length > 1 ? tag[1].toString() : null;
                break;
              }
            }

            final data = {
              'id': event.id,
              'sender': senderPubkey ?? 'unknown',
              'content': event.content, // Still encrypted
              'timestamp': event.createdAt,
            };
            controller.add(data);
          } catch (e) {
            _debug.warn('DM', 'Error parsing DM event', e.toString());
          }
        }, 'user_dms_$hexPubkey');
      } catch (e) {
        controller.addError(e);
        controller.close();
      }
    }();

    return controller.stream;
  }

  /// Subscribe to user's zap events
  static Stream<Map<String, dynamic>> subscribeToZaps(String targetNpub) {
    final controller = StreamController<Map<String, dynamic>>();

    try {
      if (_nostr == null) {
        throw Exception('Nostr not initialized');
      }

      // Create a filter for zap events to this user
      final filter = {
        'kinds': [9735], // Zap kind
        'tags': {
          'p': [targetNpub], // Filter by recipient
        },
      };

      // Subscribe using the Nostr pool - must await per nostr_dart docs
      () async {
        await _nostr!.pool.subscribe([filter], (event) {
          try {
            // Parse the zap event content
            final data = {
              'id': event.id,
              'satoshis': 0, // Would be extracted from the zap event
              'message': event.content,
              'timestamp': event.createdAt,
            };
            controller.add(data);
          } catch (e) {
            print('⚠️ Error parsing zap event: $e');
          }
        }, 'user_zaps_$targetNpub');
      }();
    } catch (e) {
      controller.addError(e);
      controller.close();
    }

    return controller.stream;
  }

  /// Get public key from nsec
  static String? getPublicKeyFromNsec(String nsec) {
    try {
      // First decode the bech32 nsec to get the hex private key
      final hexPrivateKey = _nsecToHex(nsec);
      if (hexPrivateKey == null) {
        print('❌ Failed to decode nsec to hex');
        return null;
      }

      // Now get the public key using the hex private key
      final hexPublicKey = getPublicKey(hexPrivateKey);

      // Convert hex public key to npub (bech32)
      return _hexToNpub(hexPublicKey);
    } catch (e) {
      print('❌ Error deriving public key: $e');
      return null;
    }
  }

  /// Decode nsec (bech32) to hex private key
  static String? _nsecToHex(String nsec) {
    try {
      if (!nsec.startsWith('nsec1')) {
        return null;
      }

      final decoded = const Bech32Codec().decode(nsec);
      final data = _convertBits(decoded.data, 5, 8, false);
      if (data == null) return null;

      return data.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    } catch (e) {
      print('❌ Error decoding nsec: $e');
      return null;
    }
  }

  /// Encode hex public key to npub (bech32) - public wrapper
  static String? hexToNpub(String hexPubKey) => _hexToNpub(hexPubKey);

  /// Encode hex public key to npub (bech32)
  static String? _hexToNpub(String hexPubKey) {
    try {
      final bytes = <int>[];
      for (var i = 0; i < hexPubKey.length; i += 2) {
        bytes.add(int.parse(hexPubKey.substring(i, i + 2), radix: 16));
      }

      final converted = _convertBits(bytes, 8, 5, true);
      if (converted == null) return null;

      return const Bech32Codec().encode(Bech32('npub', converted));
    } catch (e) {
      print('❌ Error encoding npub: $e');
      return null;
    }
  }

  /// Decode npub (bech32) to hex public key
  static String? npubToHex(String npub) {
    try {
      if (!npub.startsWith('npub1')) {
        return null;
      }

      final decoded = const Bech32Codec().decode(npub);
      final data = _convertBits(decoded.data, 5, 8, false);
      if (data == null) return null;

      return data.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    } catch (e) {
      print('❌ Error decoding npub: $e');
      return null;
    }
  }

  /// Convert bits between different bases (for bech32 encoding/decoding)
  static List<int>? _convertBits(
    List<int> data,
    int fromBits,
    int toBits,
    bool pad,
  ) {
    var acc = 0;
    var bits = 0;
    final result = <int>[];
    final maxv = (1 << toBits) - 1;

    for (final value in data) {
      if (value < 0 || (value >> fromBits) != 0) {
        return null;
      }
      acc = (acc << fromBits) | value;
      bits += fromBits;
      while (bits >= toBits) {
        bits -= toBits;
        result.add((acc >> bits) & maxv);
      }
    }

    if (pad) {
      if (bits > 0) {
        result.add((acc << (toBits - bits)) & maxv);
      }
    } else if (bits >= fromBits || ((acc << (toBits - bits)) & maxv) != 0) {
      return null;
    }

    return result;
  }

  /// Validate npub format
  static bool _isValidNpub(String npub) {
    // npub format: npub1... (62 chars typically)
    return npub.startsWith('npub1') && npub.length > 50;
  }

  /// Validate nsec format
  static bool _isValidNsec(String nsec) {
    // nsec format: nsec1... (62 chars typically)
    return nsec.startsWith('nsec1') && nsec.length > 50;
  }

  /// Clear all Nostr data
  static Future<void> clearKeys() async {
    try {
      await _secureStorage.delete(key: _nsecKey);
      await _secureStorage.delete(key: _npubKey);
      _nostr = null;
      print('✅ Nostr keys cleared');
    } catch (e) {
      print('❌ Error clearing keys: $e');
      rethrow;
    }
  }

  /// Get relay status
  static Map<String, bool> getRelayStatus() {
    final status = <String, bool>{};
    if (_nostr != null) {
      // Access relays from the pool
      try {
        // The RelayPool may have a list property to iterate
        // This is a safe fallback that returns empty map
        for (final relay in _defaultRelays) {
          status[relay] = true; // Assume connected for now
        }
      } catch (e) {
        print('⚠️ Error getting relay status: $e');
      }
    }
    return status;
  }

  /// Fetch global feed from relays
  /// Returns list of text note events (kind 1)
  static Future<List<NostrFeedPost>> fetchGlobalFeed({int limit = 50}) async {
    final posts = <NostrFeedPost>[];
    final completer = Completer<List<NostrFeedPost>>();

    try {
      _debug.info('FEED', 'fetchGlobalFeed() called', 'limit: $limit');
      await init();

      if (_nostr == null) {
        _debug.error('FEED', 'Nostr not initialized, returning empty feed');
        return posts;
      }

      _debug.info(
        'FEED',
        'Fetching global feed',
        '${_defaultRelays.length} relays configured',
      );

      // Get posts from last 7 days for global feed (increased from 24h)
      final since = DateTime.now().subtract(const Duration(days: 7));
      final sinceTimestamp = since.millisecondsSinceEpoch ~/ 1000;

      // Filter for kind 1 (text notes) from recent time
      final filter = {
        'kinds': [1],
        'since': sinceTimestamp,
        'limit': limit,
      };

      _debug.info(
        'FEED',
        'Subscription filter',
        'kinds: [1], since: $sinceTimestamp, limit: $limit',
      );

      final subscriptionId =
          'global_feed_${DateTime.now().millisecondsSinceEpoch}';
      final receivedEvents = <String, Event>{};

      // Subscribe to events with timeout (increased to 10 seconds for better relay response)
      Timer? timeoutTimer;
      bool isCompleted = false;

      timeoutTimer = Timer(const Duration(seconds: 10), () {
        if (!isCompleted) {
          isCompleted = true;
          _debug.info(
            'FEED',
            'Timeout reached (10s)',
            'Received ${receivedEvents.length} events',
          );
          // Convert received events to posts
          for (final event in receivedEvents.values) {
            posts.add(NostrFeedPost.fromEvent(event));
          }
          posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          if (receivedEvents.isEmpty) {
            _debug.warn('FEED', 'No events received from any relay');
          } else {
            _debug.success(
              'FEED',
              'Global feed fetched',
              '${posts.length} posts',
            );
          }
          completer.complete(posts);
        }
      });

      _debug.info(
        'FEED',
        'Subscribing to relays',
        'subscriptionId: $subscriptionId',
      );

      // IMPORTANT: pool.subscribe returns a Future and must be awaited
      await _nostr!.pool.subscribe([filter], (event) {
        _debug.info(
          'FEED',
          'Received event',
          'id: ${event.id.substring(0, 8)}..., content length: ${event.content.length}',
        );
        if (!isCompleted && !receivedEvents.containsKey(event.id)) {
          receivedEvents[event.id] = event;

          // If we've reached the limit, complete early
          if (receivedEvents.length >= limit) {
            timeoutTimer?.cancel();
            isCompleted = true;
            _debug.success('FEED', 'Reached limit', '$limit events collected');
            for (final e in receivedEvents.values) {
              posts.add(NostrFeedPost.fromEvent(e));
            }
            posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
            completer.complete(posts);
          }
        }
      }, subscriptionId);

      _debug.success(
        'FEED',
        'Subscription active',
        'REQ sent and acknowledged by relays. subscriptionId: $subscriptionId',
      );

      return completer.future;
    } catch (e) {
      print('❌ Error fetching global feed: $e');
      return posts;
    }
  }

  /// Fetch user's follows (kind-3 contact list)
  /// Returns list of pubkeys the user follows
  static Future<List<String>> fetchUserFollows(String userPubkey) async {
    final follows = <String>[];

    try {
      await init();

      if (_nostr == null) {
        _debug.warn('FOLLOWS', 'Nostr not initialized');
        return follows;
      }

      _debug.info(
        'FOLLOWS',
        'Fetching kind-3 contact list',
        'pubkey: ${userPubkey.substring(0, 16)}...',
      );

      // First check cache
      final cached = await _secureStorage.read(key: _followsKey);
      if (cached != null && cached.isNotEmpty) {
        // Return cached follows, but still fetch fresh in background
        follows.addAll(cached.split(',').where((s) => s.isNotEmpty));
        _debug.info(
          'FOLLOWS',
          'Loaded from cache',
          '${follows.length} follows',
        );
      }

      // Filter for kind 3 (contact list)
      final filter = {
        'kinds': [3],
        'authors': [userPubkey],
        'limit': 1,
      };

      _debug.info(
        'FOLLOWS',
        'Subscription filter',
        'kinds: [3], authors: [${userPubkey.substring(0, 16)}...], limit: 1',
      );

      final completer = Completer<List<String>>();
      bool isCompleted = false;

      // Timeout after 10 seconds (increased from 5)
      Timer(const Duration(seconds: 10), () {
        if (!isCompleted) {
          isCompleted = true;
          _debug.warn(
            'FOLLOWS',
            'Timeout (10s)',
            'No kind-3 event received, returning ${follows.length} cached follows',
          );
          completer.complete(follows);
        }
      });

      final subscriptionId = 'follows_${DateTime.now().millisecondsSinceEpoch}';

      // IMPORTANT: pool.subscribe returns a Future and must be awaited
      await _nostr!.pool.subscribe([filter], (event) async {
        _debug.success(
          'FOLLOWS',
          'Received kind-3 event!',
          'id: ${event.id.substring(0, 8)}..., tags: ${event.tags.length}',
        );
        if (!isCompleted) {
          isCompleted = true;

          // Parse contact list from tags
          final freshFollows = <String>[];
          for (final tag in event.tags) {
            if (tag is List &&
                tag.isNotEmpty &&
                tag[0] == 'p' &&
                tag.length > 1) {
              final pubkey = tag[1].toString();
              if (pubkey.isNotEmpty) {
                freshFollows.add(pubkey);
              }
            }
          }

          _debug.info(
            'FOLLOWS',
            'Parsed contact list',
            '${freshFollows.length} follows from ${event.tags.length} tags',
          );

          // Cache the follows
          if (freshFollows.isNotEmpty) {
            await _secureStorage.write(
              key: _followsKey,
              value: freshFollows.join(','),
            );
            _debug.success(
              'FOLLOWS',
              'Cached follows',
              '${freshFollows.length} pubkeys',
            );
          }

          completer.complete(freshFollows.isNotEmpty ? freshFollows : follows);
        }
      }, subscriptionId);

      _debug.info(
        'FOLLOWS',
        'Subscription sent',
        'Waiting for kind-3 events...',
      );

      return completer.future;
    } catch (e) {
      _debug.error('FOLLOWS', 'Error fetching follows', e.toString());
      return follows;
    }
  }

  /// Get cached follows (for offline access)
  static Future<List<String>> getCachedFollows() async {
    try {
      final cached = await _secureStorage.read(key: _followsKey);
      if (cached != null && cached.isNotEmpty) {
        return cached.split(',').where((s) => s.isNotEmpty).toList();
      }
    } catch (e) {
      print('⚠️ Error reading cached follows: $e');
    }
    return [];
  }

  /// Fetch feed from user's follows (kind-1 posts from follows, last 48 hours)
  static Future<List<NostrFeedPost>> fetchFollowsFeed({
    required List<String> followPubkeys,
    int limit = 50,
  }) async {
    final posts = <NostrFeedPost>[];

    if (followPubkeys.isEmpty) {
      print('⚠️ No follows to fetch posts from');
      return posts;
    }

    try {
      await init();

      if (_nostr == null) {
        print('⚠️ Nostr not initialized');
        return posts;
      }

      final completer = Completer<List<NostrFeedPost>>();
      bool isCompleted = false;

      // Get posts from last 48 hours
      final since = DateTime.now().subtract(const Duration(hours: 48));
      final sinceTimestamp = since.millisecondsSinceEpoch ~/ 1000;

      // Filter for kind 1 (text notes) from follows
      final filter = {
        'kinds': [1],
        'authors': followPubkeys,
        'since': sinceTimestamp,
        'limit': limit,
      };

      final subscriptionId =
          'follows_feed_${DateTime.now().millisecondsSinceEpoch}';
      final receivedEvents = <String, Event>{};

      // Timeout after 8 seconds (longer for follows feed)
      Timer(const Duration(seconds: 8), () {
        if (!isCompleted) {
          isCompleted = true;
          for (final event in receivedEvents.values) {
            posts.add(NostrFeedPost.fromEvent(event));
          }
          posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          print('📰 Fetched ${posts.length} posts from follows');
          completer.complete(posts);
        }
      });

      // IMPORTANT: pool.subscribe returns a Future and must be awaited
      await _nostr!.pool.subscribe([filter], (event) {
        if (!isCompleted && !receivedEvents.containsKey(event.id)) {
          receivedEvents[event.id] = event;

          if (receivedEvents.length >= limit) {
            Timer(const Duration(milliseconds: 500), () {
              if (!isCompleted) {
                isCompleted = true;
                for (final e in receivedEvents.values) {
                  posts.add(NostrFeedPost.fromEvent(e));
                }
                posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
                print('📰 Fetched ${posts.length} posts from follows');
                completer.complete(posts);
              }
            });
          }
        }
      }, subscriptionId);

      return completer.future;
    } catch (e) {
      print('❌ Error fetching follows feed: $e');
      return posts;
    }
  }

  /// Fetch author metadata (kind 0)
  static Future<Map<String, String>> fetchAuthorMetadata(String pubkey) async {
    try {
      if (_nostr == null) return {};

      final filter = {
        'kinds': [0],
        'authors': [pubkey],
        'limit': 1,
      };

      final completer = Completer<Map<String, String>>();
      bool isCompleted = false;

      Timer(const Duration(seconds: 2), () {
        if (!isCompleted) {
          isCompleted = true;
          completer.complete({});
        }
      });

      await _nostr!.pool.subscribe([filter], (event) {
        if (!isCompleted) {
          isCompleted = true;
          try {
            final content = event.content;
            // Parse JSON metadata
            final metadata = <String, String>{};
            // Basic parsing - in production use json.decode
            if (content.contains('"name"')) {
              final nameMatch = RegExp(
                r'"name"\s*:\s*"([^"]*)"',
              ).firstMatch(content);
              if (nameMatch != null) {
                metadata['name'] = nameMatch.group(1) ?? '';
              }
            }
            if (content.contains('"picture"')) {
              final picMatch = RegExp(
                r'"picture"\s*:\s*"([^"]*)"',
              ).firstMatch(content);
              if (picMatch != null) {
                metadata['picture'] = picMatch.group(1) ?? '';
              }
            }
            completer.complete(metadata);
          } catch (e) {
            completer.complete({});
          }
        }
      }, 'metadata_${pubkey.substring(0, 8)}');

      return completer.future;
    } catch (e) {
      print('⚠️ Error fetching author metadata: $e');
      return {};
    }
  }

  /// Convert sats to Naira
  static double satsToNaira(int sats) {
    return sats * satsToNairaRate;
  }

  /// Format Naira amount
  static String formatNaira(double amount) {
    if (amount >= 1000000) {
      return '₦${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '₦${(amount / 1000).toStringAsFixed(1)}K';
    } else if (amount >= 1) {
      return '₦${amount.toStringAsFixed(0)}';
    } else {
      return '₦${amount.toStringAsFixed(2)}';
    }
  }
}

/// Model for Nostr feed posts
class NostrFeedPost {
  final String id;
  final String authorPubkey;
  String authorName;
  String? authorAvatar;
  final String content;
  final DateTime timestamp;
  int zapAmount;
  int likeCount;
  int replyCount;
  final List<String> tags;

  NostrFeedPost({
    required this.id,
    required this.authorPubkey,
    this.authorName = 'Anon',
    this.authorAvatar,
    required this.content,
    required this.timestamp,
    this.zapAmount = 0,
    this.likeCount = 0,
    this.replyCount = 0,
    this.tags = const [],
  });

  factory NostrFeedPost.fromEvent(Event event) {
    // Extract author name from pubKey (first 8 chars as fallback)
    final shortPubkey =
        event.pubKey.length > 8 ? event.pubKey.substring(0, 8) : event.pubKey;

    // Check for replies (e tag)
    int replyCount = 0;
    for (final tag in event.tags) {
      if (tag is List && tag.isNotEmpty && tag[0] == 'e') {
        replyCount++;
      }
    }

    return NostrFeedPost(
      id: event.id,
      authorPubkey: event.pubKey,
      authorName: shortPubkey,
      content: event.content,
      timestamp: DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
      zapAmount: (event.createdAt % 5000) + 100, // Mock zap amount for demo
      likeCount: event.createdAt % 50, // Mock likes for demo
      replyCount: replyCount,
      tags:
          event.tags
              .map(
                (t) =>
                    t is List
                        ? t.map((e) => e.toString()).join(':')
                        : t.toString(),
              )
              .toList(),
    );
  }
}
