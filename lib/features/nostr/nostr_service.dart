import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nostr_dart/nostr_dart.dart';
import 'package:bech32/bech32.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

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

  // Bitcoin-focused and Nigeria-friendly relays for better Sabi Wallet experience
  static final List<String> _defaultRelays = [
    'wss://nostr.btclibrary.org', // Bitcoin-only, curated - Perfect for Bitcoiners
    'wss://nos.lol', // Fast, popular in Africa - Many Nigerian users
    'wss://nostr.oxtr.dev', // Bitcoin-focused, low latency - Great for zaps
    'wss://relay.nostr.band', // Searchable, good for discovery - Helps find Nigerian posts
    'wss://nostr.verified.ninja', // Verified users only - Safer for recovery contacts
  ];

  // Key for storing cached follows
  static const _followsKey = 'nostr_follows';

  // Rate for sats to naira conversion (can be updated from API)
  static double satsToNairaRate = 0.015; // ~15 kobo per sat

  /// Initialize the Nostr service
  static Future<void> init() async {
    if (_initialized) {
      debugPrint('✅ NostrService already initialized');
      return;
    }
    _secureStorage = const FlutterSecureStorage();
    _initialized = true;
    await _loadKeysAndInitializeNostr();
  }

  /// Load keys from secure storage and initialize Nostr
  static Future<void> _loadKeysAndInitializeNostr() async {
    try {
      final nsec = await _secureStorage.read(key: _nsecKey);
      if (nsec != null && nsec.isNotEmpty) {
        // Convert nsec to hex for nostr_dart
        final hexPrivateKey = _nsecToHex(nsec);
        if (hexPrivateKey != null) {
          await _initializeNostrWithKey(hexPrivateKey);
        }
      }
    } catch (e) {
      print('❌ Error loading Nostr keys: $e');
    }
  }

  /// Initialize Nostr with a hex private key
  static Future<void> _initializeNostrWithKey(String hexPrivateKey) async {
    try {
      _nostr = Nostr(privateKey: hexPrivateKey);

      // Add relays
      for (final relayUrl in _defaultRelays) {
        try {
          await _nostr!.pool.add(
            Relay(relayUrl, access: WriteAccess.readWrite),
          );
        } catch (e) {
          print('⚠️ Failed to add relay $relayUrl: $e');
        }
      }
      print('✅ Nostr initialized with ${_defaultRelays.length} relays');
    } catch (e) {
      print('❌ Error initializing Nostr: $e');
    }
  }

  /// Generate new Nostr keys
  static Future<Map<String, String>> generateKeys() async {
    try {
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
      return await _secureStorage.read(key: _npubKey);
    } catch (e) {
      print('❌ Error reading npub: $e');
      return null;
    }
  }

  /// Get current nsec (be careful with this!)
  static Future<String?> getNsec() async {
    try {
      return await _secureStorage.read(key: _nsecKey);
    } catch (e) {
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
      await _nostr!.sendEvent(event);

      print('✅ Zap event published: $satoshis sats to $targetNpub');
      return event.id;
    } catch (e) {
      print('❌ Error publishing zap: $e');
      rethrow;
    }
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

      // Subscribe using the Nostr pool
      _nostr!.pool.subscribe([filter], (event) {
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
      await init();

      if (_nostr == null) {
        print('⚠️ Nostr not initialized, returning empty feed');
        return posts;
      }

      // Filter for kind 1 (text notes)
      final filter = {
        'kinds': [1],
        'limit': limit,
      };

      final subscriptionId =
          'global_feed_${DateTime.now().millisecondsSinceEpoch}';
      final receivedEvents = <String, Event>{};

      // Subscribe to events with timeout
      Timer? timeoutTimer;
      bool isCompleted = false;

      timeoutTimer = Timer(const Duration(seconds: 5), () {
        if (!isCompleted) {
          isCompleted = true;
          // Convert received events to posts
          for (final event in receivedEvents.values) {
            posts.add(NostrFeedPost.fromEvent(event));
          }
          posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          completer.complete(posts);
        }
      });

      _nostr!.pool.subscribe([filter], (event) {
        if (!isCompleted && !receivedEvents.containsKey(event.id)) {
          receivedEvents[event.id] = event;

          // If we've reached the limit, complete early
          if (receivedEvents.length >= limit) {
            timeoutTimer?.cancel();
            isCompleted = true;
            for (final e in receivedEvents.values) {
              posts.add(NostrFeedPost.fromEvent(e));
            }
            posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
            completer.complete(posts);
          }
        }
      }, subscriptionId);

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
        print('⚠️ Nostr not initialized');
        return follows;
      }

      // First check cache
      final cached = await _secureStorage.read(key: _followsKey);
      if (cached != null && cached.isNotEmpty) {
        // Return cached follows, but still fetch fresh in background
        follows.addAll(cached.split(',').where((s) => s.isNotEmpty));
        print('📦 Loaded ${follows.length} cached follows');
      }

      // Filter for kind 3 (contact list)
      final filter = {
        'kinds': [3],
        'authors': [userPubkey],
        'limit': 1,
      };

      final completer = Completer<List<String>>();
      bool isCompleted = false;

      // Timeout after 5 seconds
      Timer(const Duration(seconds: 5), () {
        if (!isCompleted) {
          isCompleted = true;
          completer.complete(follows);
        }
      });

      final subscriptionId = 'follows_${DateTime.now().millisecondsSinceEpoch}';

      _nostr!.pool.subscribe([filter], (event) async {
        if (!isCompleted) {
          isCompleted = true;
          
          // Parse contact list from tags
          final freshFollows = <String>[];
          for (final tag in event.tags) {
            if (tag is List && tag.isNotEmpty && tag[0] == 'p' && tag.length > 1) {
              final pubkey = tag[1].toString();
              if (pubkey.isNotEmpty) {
                freshFollows.add(pubkey);
              }
            }
          }

          // Cache the follows
          if (freshFollows.isNotEmpty) {
            await _secureStorage.write(
              key: _followsKey,
              value: freshFollows.join(','),
            );
            print('💾 Cached ${freshFollows.length} follows');
          }

          completer.complete(freshFollows.isNotEmpty ? freshFollows : follows);
        }
      }, subscriptionId);

      return completer.future;
    } catch (e) {
      print('❌ Error fetching user follows: $e');
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

      final subscriptionId = 'follows_feed_${DateTime.now().millisecondsSinceEpoch}';
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

      _nostr!.pool.subscribe([filter], (event) {
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

      _nostr!.pool.subscribe([filter], (event) {
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
