import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/models.dart';

/// Event and metadata caching service for instant feed loading
class EventCacheService {
  static final EventCacheService _instance = EventCacheService._internal();
  factory EventCacheService() => _instance;
  EventCacheService._internal();

  static const String _feedCacheBox = 'nostr_feed_cache';
  static const String _profileCacheBox = 'nostr_profile_cache';
  static const String _followsCacheBox = 'nostr_follows_cache';
  static const String _metadataCacheBox = 'nostr_metadata';

  static const int _maxFeedPosts = 200;
  static const int _maxCachedProfiles = 500;

  Box? _feedBox;
  Box? _profileBox;
  Box? _followsBox;
  Box? _metaBox;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  /// Initialize the cache service
  Future<void> init() async {
    if (_initialized) return;

    try {
      _feedBox = await Hive.openBox(_feedCacheBox);
      _profileBox = await Hive.openBox(_profileCacheBox);
      _followsBox = await Hive.openBox(_followsCacheBox);
      _metaBox = await Hive.openBox(_metadataCacheBox);
      _initialized = true;
      debugPrint('✅ EventCacheService initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize EventCacheService: $e');
    }
  }
  
  /// Alias for init() for backward compatibility
  Future<void> initialize() => init();

  // ==================== FEED POSTS ====================

  /// Save feed posts to cache
  Future<void> cacheFeedPosts(List<NostrFeedPost> posts, {String feedType = 'global'}) async {
    if (!_initialized || _feedBox == null) return;

    try {
      // Get existing posts
      final existingJson = _feedBox!.get(feedType) as String?;
      final existing = existingJson != null
          ? (jsonDecode(existingJson) as List<dynamic>)
              .map((e) => NostrFeedPost.fromCacheJson(e as Map<String, dynamic>))
              .toList()
          : <NostrFeedPost>[];

      // Merge and deduplicate
      final merged = _mergePosts(posts, existing);

      // Save (limit to max posts)
      final toSave = merged.take(_maxFeedPosts).map((p) => p.toJson()).toList();
      await _feedBox!.put(feedType, jsonEncode(toSave));

      debugPrint('📦 Cached ${toSave.length} posts for $feedType feed');
    } catch (e) {
      debugPrint('❌ Failed to cache feed posts: $e');
    }
  }

  /// Load cached feed posts
  Future<List<NostrFeedPost>> loadCachedFeedPosts({String feedType = 'global'}) async {
    if (!_initialized || _feedBox == null) return [];

    try {
      final json = _feedBox!.get(feedType) as String?;
      if (json == null) return [];

      final list = jsonDecode(json) as List<dynamic>;
      final posts = list
          .map((e) => NostrFeedPost.fromCacheJson(e as Map<String, dynamic>))
          .toList();

      debugPrint('📦 Loaded ${posts.length} cached posts for $feedType feed');
      return posts;
    } catch (e) {
      debugPrint('❌ Failed to load cached posts: $e');
      return [];
    }
  }

  /// Clear feed cache
  Future<void> clearFeedCache({String? feedType}) async {
    if (!_initialized || _feedBox == null) return;

    if (feedType != null) {
      await _feedBox!.delete(feedType);
    } else {
      await _feedBox!.clear();
    }
  }

  // ==================== PROFILES ====================

  /// Cache a profile
  Future<void> cacheProfile(NostrProfile profile) async {
    if (!_initialized || _profileBox == null) return;

    try {
      await _profileBox!.put(profile.pubkey, jsonEncode(profile.toJson()));
      
      // Prune if too many
      if (_profileBox!.length > _maxCachedProfiles) {
        final keysToRemove = _profileBox!.keys.take(_profileBox!.length - _maxCachedProfiles);
        for (final key in keysToRemove) {
          await _profileBox!.delete(key);
        }
      }
    } catch (e) {
      debugPrint('❌ Failed to cache profile: $e');
    }
  }

  /// Cache multiple profiles
  Future<void> cacheProfiles(List<NostrProfile> profiles) async {
    for (final profile in profiles) {
      await cacheProfile(profile);
    }
  }

  /// Get cached profile
  Future<NostrProfile?> getCachedProfile(String pubkey) async {
    if (!_initialized || _profileBox == null) return null;

    try {
      final json = _profileBox!.get(pubkey) as String?;
      if (json == null) return null;

      return NostrProfile.fromCacheJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  /// Get multiple cached profiles
  Future<Map<String, NostrProfile>> getCachedProfiles(List<String> pubkeys) async {
    final results = <String, NostrProfile>{};
    
    for (final pubkey in pubkeys) {
      final profile = await getCachedProfile(pubkey);
      if (profile != null) {
        results[pubkey] = profile;
      }
    }
    
    return results;
  }

  // ==================== FOLLOWS ====================

  /// Cache user's follows (kind 3 contact list)
  Future<void> cacheFollows(String userPubkey, List<String> follows) async {
    if (!_initialized || _followsBox == null) return;

    try {
      await _followsBox!.put(userPubkey, jsonEncode(follows));
      await _followsBox!.put('${userPubkey}_timestamp', DateTime.now().millisecondsSinceEpoch);
      debugPrint('📦 Cached ${follows.length} follows for user');
    } catch (e) {
      debugPrint('❌ Failed to cache follows: $e');
    }
  }

  /// Get cached follows
  Future<List<String>> getCachedFollows(String userPubkey) async {
    if (!_initialized || _followsBox == null) return [];

    try {
      final json = _followsBox!.get(userPubkey) as String?;
      if (json == null) return [];

      return (jsonDecode(json) as List<dynamic>).cast<String>();
    } catch (e) {
      return [];
    }
  }

  /// Get follows cache timestamp
  Future<DateTime?> getFollowsCacheTime(String userPubkey) async {
    if (!_initialized || _followsBox == null) return null;

    final timestamp = _followsBox!.get('${userPubkey}_timestamp') as int?;
    if (timestamp == null) return null;

    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  // ==================== METADATA ====================

  /// Store metadata (generic key-value)
  Future<void> setMetadata(String key, dynamic value) async {
    if (!_initialized || _metaBox == null) return;
    await _metaBox!.put(key, jsonEncode(value));
  }

  /// Get metadata
  Future<T?> getMetadata<T>(String key) async {
    if (!_initialized || _metaBox == null) return null;

    try {
      final json = _metaBox!.get(key) as String?;
      if (json == null) return null;
      return jsonDecode(json) as T;
    } catch (e) {
      return null;
    }
  }

  /// Store user's own pubkey and npub
  Future<void> cacheUserKeys(String pubkey, String npub) async {
    await setMetadata('user_pubkey', pubkey);
    await setMetadata('user_npub', npub);
  }

  /// Get user's cached pubkey
  Future<String?> getUserPubkey() async {
    return await getMetadata<String>('user_pubkey');
  }

  /// Get user's cached npub
  Future<String?> getUserNpub() async {
    return await getMetadata<String>('user_npub');
  }

  // ==================== UTILITIES ====================

  /// Merge new posts with existing, newest first, no duplicates
  List<NostrFeedPost> _mergePosts(List<NostrFeedPost> newPosts, List<NostrFeedPost> existing) {
    final seenIds = <String>{};
    final merged = <NostrFeedPost>[];

    // Add new posts first
    for (final post in newPosts) {
      if (!seenIds.contains(post.id)) {
        seenIds.add(post.id);
        merged.add(post);
      }
    }

    // Then existing posts
    for (final post in existing) {
      if (!seenIds.contains(post.id)) {
        seenIds.add(post.id);
        merged.add(post);
      }
    }

    // Sort by timestamp, newest first
    merged.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return merged;
  }

  /// Clear all caches
  Future<void> clearAll() async {
    await _feedBox?.clear();
    await _profileBox?.clear();
    await _followsBox?.clear();
    await _metaBox?.clear();
    debugPrint('🧹 All caches cleared');
  }

  /// Get cache statistics
  Map<String, dynamic> get stats {
    return {
      'feedPosts': _feedBox?.length ?? 0,
      'profiles': _profileBox?.length ?? 0,
      'follows': _followsBox?.length ?? 0,
    };
  }
}
