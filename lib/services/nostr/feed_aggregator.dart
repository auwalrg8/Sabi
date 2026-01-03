import 'dart:async';
import 'package:flutter/foundation.dart';
import 'models/models.dart';
import 'relay_pool_manager.dart';
import 'event_cache_service.dart';

/// Feed type enum
enum FeedType { following, global, trending }

/// Feed aggregator with smart algorithms for Following (default) and Global feeds
class FeedAggregator {
  static final FeedAggregator _instance = FeedAggregator._internal();
  factory FeedAggregator() => _instance;
  FeedAggregator._internal();

  final RelayPoolManager _relayPool = RelayPoolManager();
  final EventCacheService _cache = EventCacheService();

  // Profile cache for enriching posts
  final Map<String, NostrProfile> _profileCache = {};

  // User's follows
  List<String> _userFollows = [];
  String? _userPubkey;

  bool _initialized = false;

  bool get isInitialized => _initialized;
  bool get hasFollows => _userFollows.isNotEmpty;
  int get followsCount => _userFollows.length;
  String? get userPubkey => _userPubkey;

  /// Initialize the feed aggregator
  Future<void> init(String? userPubkey) async {
    if (_initialized) return;

    _userPubkey = userPubkey;

    // Load cached follows
    if (userPubkey != null) {
      _userFollows = await _cache.getCachedFollows(userPubkey);
      debugPrint('📰 Loaded ${_userFollows.length} cached follows');
    }

    // Load cached profiles
    if (_userFollows.isNotEmpty) {
      final cached = await _cache.getCachedProfiles(
        _userFollows.take(50).toList(),
      );
      _profileCache.addAll(cached);
    }

    _initialized = true;
  }

  /// Set user's pubkey and load their follows
  Future<void> setUser(String pubkey) async {
    _userPubkey = pubkey;

    // Load cached follows first
    _userFollows = await _cache.getCachedFollows(pubkey);

    // Fetch fresh follows in background
    _fetchFollowsInBackground(pubkey);
  }

  /// Fetch user's follows (kind 3 contact list)
  Future<List<String>> fetchFollows(String pubkey) async {
    debugPrint('📰 Fetching follows for ${pubkey.substring(0, 8)}...');

    final events = await _relayPool.fetch(
      filter: {
        'kinds': [3],
        'authors': [pubkey],
        'limit': 1,
      },
      timeoutSeconds: 10,
      maxEvents: 1,
    );

    if (events.isEmpty) {
      debugPrint('📰 No follows found');
      return _userFollows;
    }

    // Parse follows from tags
    final follows = <String>[];
    for (final tag in events.first.tags) {
      if (tag.isNotEmpty && tag[0] == 'p' && tag.length > 1) {
        follows.add(tag[1]);
      }
    }

    _userFollows = follows;

    // Cache follows
    await _cache.cacheFollows(pubkey, follows);

    debugPrint('📰 Fetched ${follows.length} follows');
    return follows;
  }

  void _fetchFollowsInBackground(String pubkey) {
    Future(() async {
      await fetchFollows(pubkey);
    });
  }

  /// Fetch feed posts (Following or Global)
  /// Returns cached content immediately, then refreshes in background
  Future<List<NostrFeedPost>> fetchFeed({
    FeedType type = FeedType.following,
    int limit = 50,
    DateTime? before,
    bool forceRefresh = false,
  }) async {
    final cacheKey = type == FeedType.following ? 'following' : 'global';

    // If not forcing refresh and we have cache, return it immediately
    if (!forceRefresh) {
      final cached = await _cache.loadCachedFeedPosts(feedType: cacheKey);
      if (cached.isNotEmpty) {
        debugPrint('📰 Returning ${cached.length} cached posts for $cacheKey');
        // Refresh in background
        _refreshFeedInBackground(type, limit);
        return cached;
      }
    }

    // Fetch fresh
    return await _fetchFreshFeed(type, limit, before);
  }

  /// Fetch fresh feed from relays
  Future<List<NostrFeedPost>> _fetchFreshFeed(
    FeedType type,
    int limit,
    DateTime? before,
  ) async {
    debugPrint('📰 Fetching fresh ${type.name} feed...');

    Map<String, dynamic> filter;

    if (type == FeedType.following) {
      if (_userFollows.isEmpty) {
        debugPrint('📰 No follows, falling back to global');
        return await _fetchFreshFeed(FeedType.global, limit, before);
      }

      // Following feed: posts from followed users, last 48 hours
      final since = DateTime.now().subtract(const Duration(hours: 48));
      filter = {
        'kinds': [1],
        'authors': _userFollows.take(100).toList(), // Limit authors per query
        'since': since.millisecondsSinceEpoch ~/ 1000,
        'limit': limit,
      };

      if (before != null) {
        filter['until'] = before.millisecondsSinceEpoch ~/ 1000;
      }
    } else {
      // Global feed: any posts, last 7 days
      final since = DateTime.now().subtract(const Duration(days: 7));
      filter = {
        'kinds': [1],
        'since': since.millisecondsSinceEpoch ~/ 1000,
        'limit': limit,
      };

      if (before != null) {
        filter['until'] = before.millisecondsSinceEpoch ~/ 1000;
      }
    }

    final events = await _relayPool.fetch(
      filter: filter,
      timeoutSeconds: 8,
      maxEvents: limit,
    );

    // Convert to feed posts
    var posts = events.map((e) => NostrFeedPost.fromEvent(e)).toList();

    // Filter spam
    posts = _filterSpam(posts);

    // Sort by timestamp
    posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Enrich with profile data
    await _enrichPostsWithProfiles(posts);

    // Cache
    final cacheKey = type == FeedType.following ? 'following' : 'global';
    await _cache.cacheFeedPosts(posts, feedType: cacheKey);

    debugPrint('📰 Fetched ${posts.length} posts for ${type.name} feed');
    return posts;
  }

  void _refreshFeedInBackground(FeedType type, int limit) {
    Future(() async {
      await _fetchFreshFeed(type, limit, null);
    });
  }

  /// Enrich posts with author profile data
  Future<void> _enrichPostsWithProfiles(List<NostrFeedPost> posts) async {
    // Get unique authors we don't have cached
    final unknownAuthors =
        posts
            .map((p) => p.authorPubkey)
            .where((pubkey) => !_profileCache.containsKey(pubkey))
            .toSet()
            .take(20) // Limit parallel fetches
            .toList();

    if (unknownAuthors.isNotEmpty) {
      // Fetch profiles in parallel
      final profiles = await fetchProfiles(unknownAuthors);

      for (final profile in profiles) {
        _profileCache[profile.pubkey] = profile;
        await _cache.cacheProfile(profile);
      }
    }

    // Apply cached profiles to posts
    for (final post in posts) {
      if (_profileCache.containsKey(post.authorPubkey)) {
        post.applyProfile(_profileCache[post.authorPubkey]!);
      }
    }
  }

  /// Fetch multiple profiles (kind 0)
  Future<List<NostrProfile>> fetchProfiles(List<String> pubkeys) async {
    if (pubkeys.isEmpty) return [];

    final events = await _relayPool.fetch(
      filter: {
        'kinds': [0],
        'authors': pubkeys,
      },
      timeoutSeconds: 5,
      maxEvents: pubkeys.length,
    );

    final profiles = <NostrProfile>[];
    final seenPubkeys = <String>{};

    for (final event in events) {
      if (seenPubkeys.contains(event.pubkey)) continue;
      seenPubkeys.add(event.pubkey);

      try {
        final npub = _hexToNpub(event.pubkey) ?? event.pubkey;
        final profile = NostrProfile.fromEventContent(
          event.pubkey,
          npub,
          event.content,
          createdAt: event.createdAt,
        );
        profiles.add(profile);
      } catch (e) {
        debugPrint('⚠️ Failed to parse profile: $e');
      }
    }

    return profiles;
  }

  /// Fetch a single profile
  Future<NostrProfile?> fetchProfile(String pubkey) async {
    // Check cache first
    if (_profileCache.containsKey(pubkey)) {
      return _profileCache[pubkey];
    }

    final cached = await _cache.getCachedProfile(pubkey);
    if (cached != null) {
      _profileCache[pubkey] = cached;
      return cached;
    }

    // Fetch from relays
    final profiles = await fetchProfiles([pubkey]);
    if (profiles.isNotEmpty) {
      _profileCache[pubkey] = profiles.first;
      await _cache.cacheProfile(profiles.first);
      return profiles.first;
    }

    return null;
  }

  /// Filter spam posts
  List<NostrFeedPost> _filterSpam(List<NostrFeedPost> posts) {
    return posts.where((post) {
      // Filter too short posts
      if (post.content.trim().length < 3) return false;

      // Filter posts with too many hashtags
      if (post.hashtags.length > 10) return false;

      // Filter posts that are just URLs
      final cleanContent = post.cleanContent.trim();
      if (cleanContent.isEmpty && post.linkUrls.length > 3) return false;

      // Filter posts with excessive mentions
      if (post.mentionedPubkeys.length > 20) return false;

      return true;
    }).toList();
  }

  /// Load more posts (pagination)
  Future<List<NostrFeedPost>> loadMore({
    required FeedType type,
    required DateTime beforeTimestamp,
    int limit = 30,
  }) async {
    return await _fetchFreshFeed(type, limit, beforeTimestamp);
  }

  /// Stream of new posts (for real-time updates)
  Stream<NostrFeedPost> subscribeToFeed({FeedType type = FeedType.following}) {
    final controller = StreamController<NostrFeedPost>();

    final filter =
        type == FeedType.following && _userFollows.isNotEmpty
            ? {
              'kinds': [1],
              'authors': _userFollows.take(100).toList(),
              'since': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            }
            : {
              'kinds': [1],
              'since': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            };

    final subs = _relayPool.subscribe(filter, (event) async {
      final post = NostrFeedPost.fromEvent(event);

      // Apply profile if cached
      if (_profileCache.containsKey(post.authorPubkey)) {
        post.applyProfile(_profileCache[post.authorPubkey]!);
      }

      controller.add(post);
    });

    controller.onCancel = () {
      _relayPool.unsubscribeAll(subs);
    };

    return controller.stream;
  }

  // ==================== Utilities ====================

  /// Convert hex pubkey to npub (simplified)
  String? _hexToNpub(String hexPubKey) {
    // This is a simplified version - the full implementation is in NostrCore
    // For now, just return a shortened version
    if (hexPubKey.length > 8) {
      return 'npub1${hexPubKey.substring(0, 8)}...';
    }
    return null;
  }

  /// Clear all caches and reset
  Future<void> reset() async {
    _profileCache.clear();
    _userFollows.clear();
    _userPubkey = null;
    await _cache.clearFeedCache();
    _initialized = false;
  }

  /// Get profile from cache
  NostrProfile? getCachedProfile(String pubkey) => _profileCache[pubkey];
}
