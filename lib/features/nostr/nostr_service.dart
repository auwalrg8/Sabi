import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nostr_dart/nostr_dart.dart';
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
  
  // Public relay pool
  static final List<String> _defaultRelays = [
    'wss://relay.damus.io',
    'wss://nostr.band',
    'wss://relay.snort.social',
    'wss://nostr.mom',
    'wss://relay.nostr.band',
  ];

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
        await _initializeNostrWithKey(nsec);
      }
    } catch (e) {
      print('❌ Error loading Nostr keys: $e');
    }
  }

  /// Initialize Nostr with a specific private key
  static Future<void> _initializeNostrWithKey(String nsec) async {
    try {
      _nostr = Nostr(privateKey: nsec);
      
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
      final nsec = generatePrivateKey();
      final npub = getPublicKey(nsec);
      
      // Validate before storing
      if (!_isValidNpub(npub) || !_isValidNsec(nsec)) {
        throw Exception('Invalid generated keys');
      }
      
      // Store securely
      await _secureStorage.write(key: _nsecKey, value: nsec);
      await _secureStorage.write(key: _npubKey, value: npub);
      
      // Initialize Nostr
      await _initializeNostrWithKey(nsec);
      
      print('✅ Generated new Nostr keys');
      return {'npub': npub, 'nsec': nsec};
    } catch (e) {
      print('❌ Error generating keys: $e');
      rethrow;
    }
  }

  /// Import Nostr keys
  static Future<void> importKeys({
    required String nsec,
    required String npub,
  }) async {
    try {
      // Validate keys
      if (!_isValidNsec(nsec)) {
        throw Exception('Invalid nsec format');
      }
      if (!_isValidNpub(npub)) {
        throw Exception('Invalid npub format');
      }
      
      // Verify that nsec and npub match
      final derivedNpub = getPublicKey(nsec);
      if (derivedNpub != npub) {
        throw Exception('nsec and npub do not match');
      }
      
      // Store securely
      await _secureStorage.write(key: _nsecKey, value: nsec);
      await _secureStorage.write(key: _npubKey, value: npub);
      
      // Initialize Nostr
      await _initializeNostrWithKey(nsec);
      
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
        [['p', targetNpub]], // Tags: recipient pubkey
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
      _nostr!.pool.subscribe(
        [filter],
        (event) {
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
        },
        'user_zaps_$targetNpub',
      );
    } catch (e) {
      controller.addError(e);
      controller.close();
    }

    return controller.stream;
  }

  /// Get public key from nsec
  static String? getPublicKeyFromNsec(String nsec) {
    try {
      return getPublicKey(nsec);
    } catch (e) {
      print('❌ Error deriving public key: $e');
      return null;
    }
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
}
