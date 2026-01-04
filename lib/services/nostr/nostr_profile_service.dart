import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nostr_dart/nostr_dart.dart';
import 'package:bech32/bech32.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'models/models.dart';
import 'relay_pool_manager.dart';
import 'event_cache_service.dart';

/// Profile service for managing Nostr identity (Kind 0)
/// Includes lud16 Lightning address and nostr.build image upload
class NostrProfileService {
  static final NostrProfileService _instance = NostrProfileService._internal();
  factory NostrProfileService() => _instance;
  NostrProfileService._internal();

  static const _npubKey = 'nostr_npub';
  static const _nsecKey = 'nostr_nsec';
  static const _hexPubKey = 'nostr_hex_pubkey';
  static const _hexPrivKey = 'nostr_hex_privkey';
  // Quick-cache keys for instant home screen display
  static const _quickCacheNameKey = 'nostr_quick_name';
  static const _quickCachePictureKey = 'nostr_quick_picture';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Static cached values for instant access (loaded on app start)
  static String? _cachedDisplayName;
  static String? _cachedPicture;

  /// Get cached display name instantly (no async)
  static String? get cachedDisplayName => _cachedDisplayName;

  /// Get cached picture URL instantly (no async)
  static String? get cachedPicture => _cachedPicture;
  final RelayPoolManager _relayPool = RelayPoolManager();
  final EventCacheService _cache = EventCacheService();

  NostrProfile? _currentProfile;
  String? _hexPrivateKey;
  String? _hexPublicKey;
  bool _initialized = false;

  bool get isInitialized => _initialized;
  bool get hasKeys => _hexPrivateKey != null;
  NostrProfile? get currentProfile => _currentProfile;
  String? get currentPubkey => _hexPublicKey;
  String? get currentNpub => _currentProfile?.npub;

  /// Load quick cache synchronously at app startup for instant display
  /// Call this early in main() before any UI builds
  static Future<void> loadQuickCache() async {
    try {
      const storage = FlutterSecureStorage();
      _cachedDisplayName = await storage.read(key: _quickCacheNameKey);
      _cachedPicture = await storage.read(key: _quickCachePictureKey);
      debugPrint(
        '⚡ Quick cache loaded: name=${_cachedDisplayName ?? "null"}, pic=${_cachedPicture != null}',
      );
    } catch (e) {
      debugPrint('⚠️ Failed to load quick cache: $e');
    }
  }

  /// Update quick cache when profile changes
  Future<void> _updateQuickCache(NostrProfile profile) async {
    try {
      final name = profile.displayNameOrFallback;
      final picture = profile.picture;

      // Only update if changed
      if (name != _cachedDisplayName || picture != _cachedPicture) {
        _cachedDisplayName = name;
        _cachedPicture = picture;
        await _secureStorage.write(key: _quickCacheNameKey, value: name);
        if (picture != null) {
          await _secureStorage.write(
            key: _quickCachePictureKey,
            value: picture,
          );
        } else {
          await _secureStorage.delete(key: _quickCachePictureKey);
        }
        debugPrint('⚡ Quick cache updated: $name');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to update quick cache: $e');
    }
  }

  /// Initialize the profile service
  /// Set [force] to true to re-check keys even if already initialized
  Future<void> init({bool force = false}) async {
    if (_initialized && !force) return;

    try {
      // Load keys from secure storage
      _hexPrivateKey = await _secureStorage.read(key: _hexPrivKey);
      _hexPublicKey = await _secureStorage.read(key: _hexPubKey);

      // If hex keys not found, check for legacy bech32 keys from NostrService
      if (_hexPrivateKey == null) {
        final legacyNsec = await _secureStorage.read(key: _nsecKey);
        final legacyNpub = await _secureStorage.read(key: _npubKey);

        if (legacyNsec != null && legacyNsec.startsWith('nsec1')) {
          debugPrint('🔄 Found legacy nsec, converting to hex...');
          _hexPrivateKey = _nsecToHex(legacyNsec);
          if (_hexPrivateKey != null) {
            _hexPublicKey = getPublicKey(_hexPrivateKey!);
            // Store hex versions for future use
            await _secureStorage.write(key: _hexPrivKey, value: _hexPrivateKey);
            await _secureStorage.write(key: _hexPubKey, value: _hexPublicKey);
            debugPrint('✅ Converted legacy keys to hex format');
          }
        } else if (legacyNpub != null && legacyNpub.startsWith('npub1')) {
          // Read-only mode - only public key available
          debugPrint('🔄 Found legacy npub, converting to hex...');
          _hexPublicKey = npubToHex(legacyNpub);
          if (_hexPublicKey != null) {
            await _secureStorage.write(key: _hexPubKey, value: _hexPublicKey);
            debugPrint('✅ Converted legacy npub to hex format');
          }
        }
      }

      // If we have hex keys, try to load/fetch profile
      if (_hexPublicKey != null) {
        debugPrint('🔑 Loaded pubkey: ${_hexPublicKey!.substring(0, 8)}...');

        // Try cache first
        _currentProfile = await _cache.getCachedProfile(_hexPublicKey!);

        // Update quick cache for instant display on next app start
        if (_currentProfile != null) {
          await _updateQuickCache(_currentProfile!);
        }

        // Fetch fresh in background
        if (_currentProfile != null) {
          _fetchProfileInBackground(_hexPublicKey!);
        } else {
          // No cache, fetch now
          _currentProfile = await fetchProfile(_hexPublicKey!);
        }
      }

      _initialized = true;
      debugPrint('✅ NostrProfileService initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize NostrProfileService: $e');
      _initialized = true; // Mark as initialized even on error to prevent loops
    }
  }

  /// Generate new Nostr keys
  Future<Map<String, String>> generateKeys() async {
    // Generate private key (hex)
    _hexPrivateKey = generatePrivateKey();
    // Derive public key (hex)
    _hexPublicKey = getPublicKey(_hexPrivateKey!);

    // Convert to bech32
    final nsec = _hexToNsec(_hexPrivateKey!);
    final npub = hexToNpub(_hexPublicKey!);

    if (nsec == null || npub == null) {
      throw Exception('Failed to encode keys to bech32');
    }

    // Store securely
    await _secureStorage.write(key: _hexPrivKey, value: _hexPrivateKey);
    await _secureStorage.write(key: _hexPubKey, value: _hexPublicKey);
    await _secureStorage.write(key: _nsecKey, value: nsec);
    await _secureStorage.write(key: _npubKey, value: npub);

    // Create initial profile
    _currentProfile = NostrProfile(pubkey: _hexPublicKey!, npub: npub);

    debugPrint('✅ Generated new Nostr keys');
    return {'npub': npub, 'nsec': nsec};
  }

  /// Import existing Nostr keys
  Future<void> importKeys({String? nsec, String? npub}) async {
    if (nsec != null && nsec.startsWith('nsec1')) {
      // Import private key
      _hexPrivateKey = _nsecToHex(nsec);
      if (_hexPrivateKey == null) {
        throw Exception('Invalid nsec format');
      }
      _hexPublicKey = getPublicKey(_hexPrivateKey!);
      final derivedNpub = hexToNpub(_hexPublicKey!);

      // Store
      await _secureStorage.write(key: _hexPrivKey, value: _hexPrivateKey);
      await _secureStorage.write(key: _hexPubKey, value: _hexPublicKey);
      await _secureStorage.write(key: _nsecKey, value: nsec);
      await _secureStorage.write(key: _npubKey, value: derivedNpub);

      // Fetch profile
      _currentProfile = await fetchProfile(_hexPublicKey!);

      debugPrint('✅ Imported nsec');
    } else if (npub != null && npub.startsWith('npub1')) {
      // Import public key only (read-only mode)
      _hexPublicKey = npubToHex(npub);
      if (_hexPublicKey == null) {
        throw Exception('Invalid npub format');
      }
      _hexPrivateKey = null;

      await _secureStorage.write(key: _hexPubKey, value: _hexPublicKey);
      await _secureStorage.write(key: _npubKey, value: npub);
      await _secureStorage.delete(key: _hexPrivKey);
      await _secureStorage.delete(key: _nsecKey);

      // Fetch profile
      _currentProfile = await fetchProfile(_hexPublicKey!);

      debugPrint('✅ Imported npub (read-only mode)');
    } else {
      throw Exception('Please provide a valid nsec or npub');
    }
  }

  /// Clear all keys and profile
  Future<void> clearKeys() async {
    await _secureStorage.delete(key: _hexPrivKey);
    await _secureStorage.delete(key: _hexPubKey);
    await _secureStorage.delete(key: _nsecKey);
    await _secureStorage.delete(key: _npubKey);
    await _secureStorage.delete(key: _quickCacheNameKey);
    await _secureStorage.delete(key: _quickCachePictureKey);
    _hexPrivateKey = null;
    _hexPublicKey = null;
    _currentProfile = null;
    _cachedDisplayName = null;
    _cachedPicture = null;
    debugPrint('✅ Nostr keys cleared');
  }

  /// Fetch a profile from relays
  Future<NostrProfile?> fetchProfile(String pubkey) async {
    debugPrint('👤 Fetching profile for ${pubkey.substring(0, 8)}...');

    final events = await _relayPool.fetch(
      filter: {
        'kinds': [0],
        'authors': [pubkey],
        'limit': 1,
      },
      timeoutSeconds: 5,
      maxEvents: 1,
    );

    if (events.isEmpty) {
      debugPrint('👤 No profile found');
      return null;
    }

    final event = events.first;
    final npub = hexToNpub(pubkey) ?? pubkey;

    try {
      final profile = NostrProfile.fromEventContent(
        pubkey,
        npub,
        event.content,
        createdAt: event.createdAt,
      );

      // Cache
      await _cache.cacheProfile(profile);

      // Update quick cache if this is current user's profile
      if (pubkey == _hexPublicKey) {
        await _updateQuickCache(profile);
      }

      debugPrint('👤 Profile fetched: ${profile.displayNameOrFallback}');
      return profile;
    } catch (e) {
      debugPrint('❌ Failed to parse profile: $e');
      return null;
    }
  }

  void _fetchProfileInBackground(String pubkey) {
    Future(() async {
      final profile = await fetchProfile(pubkey);
      if (profile != null) {
        _currentProfile = profile;
      }
    });
  }

  /// Update the current user's profile
  /// Returns true if successful
  Future<bool> updateProfile({
    String? name,
    String? displayName,
    String? about,
    String? picture,
    String? banner,
    String? nip05,
    String? lud16,
    String? website,
  }) async {
    // Ensure service is initialized before updating
    if (!_initialized || _hexPrivateKey == null) {
      debugPrint('⚠️ NostrProfileService not initialized, initializing now...');
      await init(force: true);
    }

    if (_hexPrivateKey == null || _hexPublicKey == null) {
      debugPrint('❌ NostrProfileService: No private key available after init');
      debugPrint('❌ _hexPrivateKey is null: ${_hexPrivateKey == null}');
      debugPrint('❌ _hexPublicKey is null: ${_hexPublicKey == null}');
      throw Exception(
        'No private key available - cannot update profile. Please set up Nostr keys first.',
      );
    }

    debugPrint('📝 Updating profile for ${_hexPublicKey!.substring(0, 8)}...');

    // Get current profile or create new one
    final current =
        _currentProfile ??
        NostrProfile(
          pubkey: _hexPublicKey!,
          npub: hexToNpub(_hexPublicKey!) ?? '',
        );

    // Create updated profile
    final updated = current.copyWith(
      name: name,
      displayName: displayName,
      about: about,
      picture: picture,
      banner: banner,
      nip05: nip05,
      lud16: lud16,
    );

    // Build event content
    final content = jsonEncode(updated.toEventContent());

    // Create and sign event
    final event = _createSignedEvent(kind: 0, content: content, tags: []);

    if (event == null) {
      throw Exception('Failed to sign event');
    }

    // Publish to relays
    final successCount = await _relayPool.publish(event);

    if (successCount > 0) {
      _currentProfile = updated;
      await _cache.cacheProfile(updated);
      debugPrint(
        '✅ Profile updated successfully (published to $successCount relays)',
      );
      return true;
    }

    debugPrint('❌ Failed to publish profile update');
    return false;
  }

  /// Upload image to nostr.build
  /// Returns the URL of the uploaded image
  Future<String?> uploadImage(File imageFile) async {
    debugPrint('📷 Uploading image to nostr.build...');

    try {
      final uri = Uri.parse('https://nostr.build/api/v2/upload/files');
      final request = http.MultipartRequest('POST', uri);

      // Add the file
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      // Send request
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;

        // nostr.build response format
        if (json['status'] == 'success' && json['data'] != null) {
          final data = json['data'] as List<dynamic>;
          if (data.isNotEmpty) {
            final imageUrl = data[0]['url'] as String?;
            if (imageUrl != null) {
              debugPrint('✅ Image uploaded: $imageUrl');
              return imageUrl;
            }
          }
        }
      }

      debugPrint('❌ Upload failed: ${response.statusCode} ${response.body}');
      return null;
    } catch (e) {
      debugPrint('❌ Upload error: $e');
      return null;
    }
  }

  /// Upload image from bytes (for picker results)
  Future<String?> uploadImageBytes(Uint8List bytes, String filename) async {
    debugPrint('📷 Uploading image bytes to nostr.build...');

    try {
      final uri = Uri.parse('https://nostr.build/api/v2/upload/files');
      final request = http.MultipartRequest('POST', uri);

      // Add the file
      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );

      // Send request
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;

        if (json['status'] == 'success' && json['data'] != null) {
          final data = json['data'] as List<dynamic>;
          if (data.isNotEmpty) {
            final imageUrl = data[0]['url'] as String?;
            if (imageUrl != null) {
              debugPrint('✅ Image uploaded: $imageUrl');
              return imageUrl;
            }
          }
        }
      }

      debugPrint('❌ Upload failed: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('❌ Upload error: $e');
      return null;
    }
  }

  /// Create a signed Nostr event
  Map<String, dynamic>? _createSignedEvent({
    required int kind,
    required String content,
    required List<List<String>> tags,
  }) {
    if (_hexPrivateKey == null || _hexPublicKey == null) return null;

    try {
      final createdAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Build event for signing
      final eventData = [
        0, // Reserved for signature
        _hexPublicKey!,
        createdAt,
        kind,
        tags,
        content,
      ];

      // Calculate event ID (SHA256 of serialized event)
      final serialized = jsonEncode(eventData);
      final hash = sha256.convert(utf8.encode(serialized));
      debugPrint('📝 Event hash: ${hash.toString().substring(0, 16)}...');

      // Sign with nostr_dart - Event class handles ID and signature
      // ignore: unused_local_variable
      final nostrInstance = Nostr(privateKey: _hexPrivateKey!);
      final event = Event(_hexPublicKey!, kind, tags, content);

      debugPrint(
        '✅ Event signed with pubkey: ${_hexPublicKey!.substring(0, 8)}...',
      );

      return {
        'id': event.id,
        'pubkey': _hexPublicKey!,
        'created_at': createdAt,
        'kind': kind,
        'tags': tags,
        'content': content,
        'sig': event.sig,
      };
    } catch (e) {
      debugPrint('❌ Failed to sign event: $e');
      return null;
    }
  }

  /// Follow a user
  Future<bool> follow(String pubkey) async {
    // Get current follows
    final follows = await _cache.getCachedFollows(_hexPublicKey ?? '');

    if (follows.contains(pubkey)) {
      return true; // Already following
    }

    final newFollows = [...follows, pubkey];
    return await _publishFollowList(newFollows);
  }

  /// Unfollow a user
  Future<bool> unfollow(String pubkey) async {
    final follows = await _cache.getCachedFollows(_hexPublicKey ?? '');

    if (!follows.contains(pubkey)) {
      return true; // Not following anyway
    }

    final newFollows = follows.where((p) => p != pubkey).toList();
    return await _publishFollowList(newFollows);
  }

  /// Publish updated follow list (kind 3)
  Future<bool> _publishFollowList(List<String> follows) async {
    if (_hexPrivateKey == null) {
      throw Exception('No private key - cannot update follows');
    }

    final tags = follows.map((p) => ['p', p]).toList();

    final event = _createSignedEvent(kind: 3, content: '', tags: tags);

    if (event == null) return false;

    final successCount = await _relayPool.publish(event);

    if (successCount > 0) {
      await _cache.cacheFollows(_hexPublicKey!, follows);
      debugPrint('✅ Follow list updated ($successCount relays)');
      return true;
    }

    return false;
  }

  /// Check if following a user
  Future<bool> isFollowing(String pubkey) async {
    final follows = await _cache.getCachedFollows(_hexPublicKey ?? '');
    return follows.contains(pubkey);
  }

  // ==================== Bech32 Utilities ====================

  /// Convert hex public key to npub (bech32)
  static String? hexToNpub(String hexPubKey) {
    try {
      final bytes = <int>[];
      for (var i = 0; i < hexPubKey.length; i += 2) {
        bytes.add(int.parse(hexPubKey.substring(i, i + 2), radix: 16));
      }

      final converted = _convertBits(bytes, 8, 5, true);
      if (converted == null) return null;

      return const Bech32Codec().encode(Bech32('npub', converted));
    } catch (e) {
      return null;
    }
  }

  /// Convert npub (bech32) to hex public key
  static String? npubToHex(String npub) {
    try {
      if (!npub.startsWith('npub1')) return null;

      final decoded = const Bech32Codec().decode(npub);
      final data = _convertBits(decoded.data, 5, 8, false);
      if (data == null) return null;

      return data.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    } catch (e) {
      return null;
    }
  }

  /// Convert hex private key to nsec (bech32)
  String? _hexToNsec(String hexPrivKey) {
    try {
      final bytes = <int>[];
      for (var i = 0; i < hexPrivKey.length; i += 2) {
        bytes.add(int.parse(hexPrivKey.substring(i, i + 2), radix: 16));
      }

      final converted = _convertBits(bytes, 8, 5, true);
      if (converted == null) return null;

      return const Bech32Codec().encode(Bech32('nsec', converted));
    } catch (e) {
      return null;
    }
  }

  /// Convert nsec (bech32) to hex private key
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

  /// Convert bits between different bases (for bech32)
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
      if (value < 0 || (value >> fromBits) != 0) return null;
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

  /// Get stored npub
  Future<String?> getNpub() async {
    return await _secureStorage.read(key: _npubKey);
  }

  /// Get stored nsec (be careful!)
  Future<String?> getNsec() async {
    return await _secureStorage.read(key: _nsecKey);
  }

  /// Check if Nostr is configured
  Future<bool> isConfigured() async {
    final npub = await getNpub();
    return npub != null && npub.isNotEmpty;
  }
}
