import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_confetti/flutter_confetti.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'nostr_service.dart';
import 'nostr_edit_modal.dart';
import 'nostr_profile_screen.dart';
import 'nostr_search_screen.dart';
import 'nostr_dm_inbox_screen.dart';
import '../../services/breez_spark_service.dart';
import 'package:sabi_wallet/services/nostr/nostr_service.dart' as nostr_v2;

// New services - to be used for enhanced features
// ignore: unused_import
import 'providers/nostr_providers.dart';
// ignore: unused_import
import 'widgets/enhanced_zap_slider.dart';

/// Filter types for the feed
enum FeedFilter { global, following, trending24h }

/// Nostr feed screen displaying real posts from relays
/// Now uses the upgraded Nostr services with FeedAggregator
class NostrFeedScreen extends ConsumerStatefulWidget {
  const NostrFeedScreen({super.key});

  @override
  ConsumerState<NostrFeedScreen> createState() => _NostrFeedScreenState();
}

class _NostrFeedScreenState extends ConsumerState<NostrFeedScreen> {
  List<NostrFeedPost> _posts = [];
  List<NostrFeedPost> _filteredPosts = [];
  bool _isLoading =
      false; // Start as false - we show cached content immediately
  bool _isRefreshing = false; // Background refresh indicator
  String? _userNpub;
  String? _userHexPubkey;
  List<String> _userFollows = [];
  final Map<String, int> _zapCounts = {};
  final Set<String> _likedPosts = {}; // Track liked post IDs
  FeedFilter _currentFilter =
      FeedFilter.following; // Default to following feed (Primal-style)
  Map<String, Map<String, String>> _authorMetadataCache = {};
  bool _followsFeedEmpty = false; // Track if follows feed returned no posts
  bool _hasCachedContent = false;

  @override
  void initState() {
    super.initState();
    _initFeed();
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Initialize feed - load cached content immediately, then refresh in background
  Future<void> _initFeed() async {
    // Step 1: Load cached content immediately (no loading state)
    await _loadCachedContent();

    // Step 2: Refresh in background
    _refreshFeedInBackground();
  }

  /// Load cached posts and metadata - shows content instantly
  Future<void> _loadCachedContent() async {
    try {
      // Load cached metadata first
      _authorMetadataCache = await NostrService.loadCachedMetadata();

      // Load cached posts
      final cachedPosts = await NostrService.loadCachedPosts();

      if (cachedPosts.isNotEmpty) {
        // Apply cached metadata to posts
        for (final post in cachedPosts) {
          if (_authorMetadataCache.containsKey(post.authorPubkey)) {
            final meta = _authorMetadataCache[post.authorPubkey]!;
            post.authorName =
                meta['name'] ?? meta['display_name'] ?? post.authorName;
            post.authorAvatar = meta['picture'] ?? meta['avatar'];
            post.lightningAddress = meta['lud16'];
          }
        }

        if (mounted) {
          setState(() {
            _posts = cachedPosts;
            _hasCachedContent = true;
            _applyFilter();
          });
        }
      } else {
        // No cached content - show loading state
        if (mounted) {
          setState(() => _isLoading = true);
        }
      }
    } catch (e) {
      print('Error loading cached content: $e');
      if (mounted) {
        setState(() => _isLoading = true);
      }
    }
  }

  /// Refresh feed in background without blocking UI
  /// Optimized for speed - shows posts immediately, fetches metadata later
  Future<void> _refreshFeedInBackground() async {
    if (mounted) {
      setState(() => _isRefreshing = true);
    }

    final debug = NostrService.debugService;
    debug.info('SCREEN', 'Fast refresh started', 'filter: $_currentFilter');

    try {
      // Quick init - skip if already done
      await NostrService.init();
      final npub = await NostrService.getNpub();
      _userNpub = npub;

      // FAST PATH: Fetch posts directly without reinitializing relays
      List<NostrFeedPost> newPosts = [];

      if (_currentFilter == FeedFilter.following && npub != null) {
        _userHexPubkey = NostrService.npubToHex(npub);

        if (_userHexPubkey != null) {
          // Try to get cached follows first for speed
          _userFollows = await NostrService.getCachedFollows();

          if (_userFollows.isEmpty) {
            // No cached follows, fetch from relays (this is the slow part)
            _userFollows = await NostrService.fetchUserFollowsDirect(
              _userHexPubkey!,
            );
          }

          if (_userFollows.isNotEmpty) {
            newPosts = await NostrService.fetchFollowsFeedDirect(
              followPubkeys: _userFollows,
              limit: 50,
            );

            if (newPosts.isEmpty && mounted) {
              setState(() => _followsFeedEmpty = true);
            }
          } else {
            if (mounted) setState(() => _followsFeedEmpty = true);
            newPosts = await NostrService.fetchGlobalFeedDirect(limit: 50);
          }
        }
      } else {
        newPosts = await NostrService.fetchGlobalFeedDirect(limit: 50);
      }

      // SHOW POSTS IMMEDIATELY - don't wait for metadata
      if (mounted && newPosts.isNotEmpty) {
        // Apply any cached metadata we already have
        for (final post in newPosts) {
          final meta = _authorMetadataCache[post.authorPubkey];
          if (meta != null) {
            post.authorName =
                meta['name'] ?? meta['display_name'] ?? post.authorName;
            post.authorAvatar = meta['picture'] ?? meta['avatar'];
            post.lightningAddress = meta['lud16'];
          }
        }

        setState(() {
          _posts = NostrService.mergePosts(newPosts, _posts);
          _applyFilter();
          _isLoading = false;
          _isRefreshing = false;
          _hasCachedContent = true;
        });

        debug.success('SCREEN', 'Posts displayed', '${_posts.length} posts');

        // Save to cache
        NostrService.cachePosts(_posts);
      }

      // BACKGROUND: Fetch metadata for posts without avatars (non-blocking)
      _fetchMissingMetadataInBackground(newPosts);

      // BACKGROUND: Fetch engagement data (non-blocking)
      _fetchEngagementData(_posts);
    } catch (e, stackTrace) {
      debug.error('SCREEN', 'Background refresh error', '$e\n$stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  /// Fetch missing metadata in background without blocking the feed
  Future<void> _fetchMissingMetadataInBackground(
    List<NostrFeedPost> posts,
  ) async {
    final uniqueAuthors =
        posts
            .where((p) => p.authorAvatar == null)
            .map((p) => p.authorPubkey)
            .toSet()
            .where((pubkey) => !_authorMetadataCache.containsKey(pubkey))
            .take(10)
            .toList();

    if (uniqueAuthors.isEmpty) return;

    for (final pubkey in uniqueAuthors) {
      try {
        final metadata = await NostrService.fetchAuthorMetadataDirect(pubkey);
        if (metadata.isNotEmpty) {
          _authorMetadataCache[pubkey] = metadata;

          // Update posts with this author
          if (mounted) {
            setState(() {
              for (final post in _posts) {
                if (post.authorPubkey == pubkey) {
                  post.authorName =
                      metadata['name'] ??
                      metadata['display_name'] ??
                      post.authorName;
                  post.authorAvatar = metadata['picture'] ?? metadata['avatar'];
                  post.lightningAddress = metadata['lud16'];
                }
              }
            });
          }
        }
      } catch (e) {
        // Ignore metadata fetch errors - not critical
      }
    }

    // Cache updated metadata
    NostrService.cacheAuthorMetadata(_authorMetadataCache);
  }

  /// Manual pull-to-refresh
  Future<void> _loadFeed() async {
    await _refreshFeedInBackground();
  }

  /// Fetch real engagement data for posts
  Future<void> _fetchEngagementData(List<NostrFeedPost> posts) async {
    if (posts.isEmpty) return;

    try {
      final socialService = nostr_v2.SocialInteractionService();
      final eventIds = posts.take(20).map((p) => p.id).toList();

      final engagementMap = await socialService.fetchBatchEngagement(eventIds);

      if (mounted && engagementMap.isNotEmpty) {
        setState(() {
          for (final post in _posts) {
            final engagement = engagementMap[post.id];
            if (engagement != null) {
              post.likeCount = engagement.likeCount;
              post.replyCount = engagement.replyCount;
              post.repostCount = engagement.repostCount;
              post.zapAmount = engagement.zapTotalSats;
            }
          }
          // Re-apply filter to update filtered posts
          _applyFilter();
        });

        debugPrint(
          '📊 [ENGAGEMENT] Fetched engagement data for ${engagementMap.length} posts',
        );
      }
    } catch (e) {
      debugPrint('⚠️ [ENGAGEMENT] Failed to fetch engagement: $e');
    }
  }

  void _applyFilter() {
    List<NostrFeedPost> filtered = List.from(_posts);

    // Apply feed filter
    switch (_currentFilter) {
      case FeedFilter.global:
        // Global posts, sorted by timestamp
        filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        break;
      case FeedFilter.following:
        // Posts from follows, sorted by timestamp
        filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        break;
      case FeedFilter.trending24h:
        final yesterday = DateTime.now().subtract(const Duration(hours: 24));
        filtered =
            filtered.where((p) => p.timestamp.isAfter(yesterday)).toList();
        filtered.sort(
          (a, b) => (b.zapAmount + b.replyCount * 100).compareTo(
            a.zapAmount + a.replyCount * 100,
          ),
        );
        break;
    }

    setState(() => _filteredPosts = filtered);
  }

  void _openSearchScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NostrSearchScreen()),
    );
  }

  void _openMessagesScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NostrDMInboxScreen()),
    );
  }

  void _onFilterChanged(FeedFilter filter) {
    if (_currentFilter != filter) {
      setState(() => _currentFilter = filter);
      // Reload feed when switching between follows and global
      _loadFeed();
    }
  }

  /// Handle zap using the new ZapService (NIP-57 compliant)
  void _handleZapPost(NostrFeedPost post, int satoshis) async {
    final lightningAddress = post.lightningAddress;

    // Check if user has a lightning address
    if (lightningAddress == null || lightningAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${post.authorName} has no Lightning address configured',
          ),
          backgroundColor: const Color(0xFFA1A1B2),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Text('Sending $satoshis sats to ${post.authorName}...'),
            ],
          ),
          backgroundColor: const Color(0xFFF7931A),
          duration: const Duration(seconds: 10),
        ),
      );

      // Use the new ZapService for NIP-57 compliant zaps
      final zapService = nostr_v2.ZapService();
      final result = await zapService.sendZap(
        recipientPubkey: post.authorPubkey,
        amountSats: satoshis,
        eventId: post.id,
        comment: 'Zap from Sabi Wallet',
        getBalance: () async {
          // Get balance from Breez SDK
          final balance = await BreezSparkService.getBalance();
          return balance;
        },
        payInvoice: (String bolt11) async {
          // Pay invoice using Breez SDK and return payment hash
          final paymentResult = await BreezSparkService.sendPayment(
            bolt11,
            sats: satoshis,
            comment: 'Zap from Sabi Wallet',
            recipientName: post.authorName,
          );
          // Extract payment hash from result
          return paymentResult['payment']?.id as String?;
        },
      );

      // Hide loading snackbar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (result.isSuccess) {
        // Show confetti for success
        Confetti.launch(
          context,
          options: const ConfettiOptions(
            particleCount: 50,
            spread: 360,
            y: 0.5,
          ),
        );

        // Update local zap count
        setState(() {
          _zapCounts[post.id] =
              (_zapCounts[post.id] ?? post.zapAmount) + satoshis;
        });

        final nairaAmount = NostrService.satsToNaira(satoshis);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '⚡ Zapped ${post.authorName} ${NostrService.formatNaira(nairaAmount)}!',
            ),
            backgroundColor: const Color(0xFFF7931A),
            duration: const Duration(seconds: 2),
          ),
        );
        debugPrint('✅ Zap sent: $satoshis sats to ${post.authorName}');
      } else if (result.isInsufficientBalance) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'Insufficient balance'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Zap failed: ${result.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error sending zap: $e');
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to zap: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleLikePost(NostrFeedPost post) async {
    final wasLiked = _likedPosts.contains(post.id);

    // Optimistic UI update
    setState(() {
      if (wasLiked) {
        _likedPosts.remove(post.id);
      } else {
        _likedPosts.add(post.id);
      }
    });

    // Send like reaction to Nostr relays (NIP-25)
    if (!wasLiked) {
      try {
        final socialService = nostr_v2.SocialInteractionService();
        final success = await socialService.likeEvent(
          eventId: post.id,
          eventPubkey: post.authorPubkey,
        );

        if (!success && mounted) {
          // Revert on failure
          setState(() => _likedPosts.remove(post.id));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to like post'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _likedPosts.remove(post.id));
        }
      }
    }
  }

  void _handleRepost(NostrFeedPost post) async {
    // Show confirmation
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF111128),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
            title: Text(
              'Repost this note?',
              style: TextStyle(color: Colors.white, fontSize: 18.sp),
            ),
            content: Text(
              'This will share this note to your followers.',
              style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 14.sp),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Color(0xFFA1A1B2)),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF7931A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: const Text(
                  'Repost',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        final socialService = nostr_v2.SocialInteractionService();
        final success = await socialService.repostEvent(
          eventId: post.id,
          eventPubkey: post.authorPubkey,
          eventContent: post.content,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success ? 'Reposted! 🔄' : 'Failed to repost'),
              backgroundColor: success ? const Color(0xFF00FFB2) : Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _handleReply(NostrFeedPost post) {
    // Show reply dialog
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => _ReplyModal(
            post: post,
            onSent: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Reply sent! 💬'),
                  backgroundColor: Color(0xFF00FFB2),
                ),
              );
            },
          ),
    );
  }

  void _handleShare(NostrFeedPost post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111128),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder:
          (context) => SafeArea(
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B6B80),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    'Share',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ShareOption(
                        icon: Icons.link,
                        label: 'Copy Link',
                        onTap: () {
                          final link = nostr_v2.SocialInteractionService()
                              .getWebLink(post.id);
                          Clipboard.setData(ClipboardData(text: link));
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Link copied!'),
                              backgroundColor: Color(0xFF00FFB2),
                            ),
                          );
                        },
                      ),
                      _ShareOption(
                        icon: Icons.content_copy,
                        label: 'Copy Text',
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: post.content));
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Text copied!'),
                              backgroundColor: Color(0xFF00FFB2),
                            ),
                          );
                        },
                      ),
                      _ShareOption(
                        icon: Icons.share,
                        label: 'Share',
                        onTap: () {
                          Navigator.pop(context);
                          final link = nostr_v2.SocialInteractionService()
                              .getWebLink(post.id);
                          Share.share('${post.content}\n\n$link');
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),
                ],
              ),
            ),
          ),
    );
  }

  void _navigateToProfile(NostrFeedPost post) {
    // Navigate to full profile screen with the author's pubkey
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => NostrProfileScreen(
              pubkey: post.authorPubkey,
              initialName: post.authorName,
              initialAvatarUrl: post.authorAvatar,
            ),
      ),
    );
  }

  void _showCreateAccountModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => NostrEditModal(
            onSaved: () {
              _loadFeed();
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C1A),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 24.sp,
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Text(
                    'Nostr Feed',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  // Messages button with unread badge
                  GestureDetector(
                    onTap: () => _openMessagesScreen(),
                    child: Stack(
                      children: [
                        Icon(
                          Icons.mail_outline,
                          color: Colors.white,
                          size: 24.sp,
                        ),
                        // Unread badge will be shown via StreamBuilder in actual implementation
                        // For now just the icon
                      ],
                    ),
                  ),
                  SizedBox(width: 16.w),
                  // Search button - opens search screen
                  GestureDetector(
                    onTap: () => _openSearchScreen(),
                    child: Icon(Icons.search, color: Colors.white, size: 24.sp),
                  ),
                ],
              ),
            ),

            // Filter tabs - Following first (Primal-style default)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                children: [
                  _FilterTab(
                    label: 'Following',
                    isSelected: _currentFilter == FeedFilter.following,
                    onTap: () => _onFilterChanged(FeedFilter.following),
                  ),
                  SizedBox(width: 8.w),
                  _FilterTab(
                    label: 'Global',
                    isSelected: _currentFilter == FeedFilter.global,
                    onTap: () => _onFilterChanged(FeedFilter.global),
                  ),
                  SizedBox(width: 8.w),
                  _FilterTab(
                    label: 'Trending 24h',
                    isSelected: _currentFilter == FeedFilter.trending24h,
                    onTap: () => _onFilterChanged(FeedFilter.trending24h),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),

            // Refresh indicator at top when refreshing in background
            if (_isRefreshing && _hasCachedContent)
              Container(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 14.r,
                      height: 14.r,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFF7931A),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Fetching new posts...',
                      style: TextStyle(
                        color: const Color(0xFFA1A1B2),
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),

            // Feed content
            Expanded(
              child:
                  (_isLoading && !_hasCachedContent)
                      ? _buildSimpleLoader()
                      : _userNpub == null && !_hasCachedContent
                      ? _buildNoAccountState()
                      : (_followsFeedEmpty &&
                          _currentFilter == FeedFilter.following &&
                          _filteredPosts.isEmpty)
                      ? _buildFollowsEmptyState()
                      : _filteredPosts.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                        onRefresh: _loadFeed,
                        backgroundColor: const Color(0xFF111128),
                        color: const Color(0xFFF7931A),
                        child: ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          itemCount: _filteredPosts.length,
                          itemBuilder: (context, index) {
                            final post = _filteredPosts[index];
                            return _NostrPostCard(
                              post: post,
                              zapAmount: _zapCounts[post.id] ?? post.zapAmount,
                              onZap:
                                  (satoshis) => _handleZapPost(post, satoshis),
                              onLike: () => _handleLikePost(post),
                              onRepost: () => _handleRepost(post),
                              onReply: () => _handleReply(post),
                              onShare: () => _handleShare(post),
                              onProfileTap: () => _navigateToProfile(post),
                              isLiked: _likedPosts.contains(post.id),
                              showImages: true, // Always show images
                              likeCount: post.likeCount,
                              repostCount: post.repostCount,
                              replyCount: post.replyCount,
                            );
                          },
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoAccountState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.electric_bolt,
              size: 64.sp,
              color: const Color(0xFFF7931A),
            ),
            SizedBox(height: 16.h),
            Text(
              'Welcome to Nostr!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Create or import your Nostr identity to see posts from people you follow.',
              style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 14.sp),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            ElevatedButton(
              onPressed: _showCreateAccountModal,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF7931A),
                padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(
                'Get Started',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.article_outlined,
            size: 64.sp,
            color: const Color(0xFFA1A1B2),
          ),
          SizedBox(height: 16.h),
          Text(
            'No posts found',
            style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 16.sp),
          ),
          SizedBox(height: 8.h),
          TextButton(
            onPressed: _loadFeed,
            child: Text(
              'Refresh',
              style: TextStyle(color: const Color(0xFFF7931A), fontSize: 14.sp),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowsEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: const Color(0xFFF7931A).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bolt,
                size: 48.sp,
                color: const Color(0xFFF7931A),
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              _userFollows.isEmpty
                  ? 'No follows yet'
                  : 'Your follows are quiet today',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),
            Text(
              _userFollows.isEmpty
                  ? 'Follow some Bitcoiners to see their posts here!'
                  : 'Zap someone to wake them up! ⚡',
              style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 14.sp),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => _onFilterChanged(FeedFilter.global),
                  icon: Icon(
                    Icons.public,
                    size: 18.sp,
                    color: const Color(0xFFF7931A),
                  ),
                  label: Text(
                    'Browse Global',
                    style: TextStyle(
                      color: const Color(0xFFF7931A),
                      fontSize: 14.sp,
                    ),
                  ),
                ),
                SizedBox(width: 16.w),
                TextButton.icon(
                  onPressed: _loadFeed,
                  icon: Icon(
                    Icons.refresh,
                    size: 18.sp,
                    color: const Color(0xFF00FFB2),
                  ),
                  label: Text(
                    'Refresh',
                    style: TextStyle(
                      color: const Color(0xFF00FFB2),
                      fontSize: 14.sp,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleLoader() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: Color(0xFFF7931A),
            strokeWidth: 3,
          ),
          SizedBox(height: 16.h),
          Text(
            'Loading feed...',
            style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 14.sp),
          ),
        ],
      ),
    );
  }
}

/// Filter tab widget
class _FilterTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF7931A) : const Color(0xFF111128),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFFA1A1B2),
            fontSize: 12.sp,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Nostr post card widget with Primal-inspired design
/// Features: Clean layout, bottom action bar with reply/repost/like/zap
class _NostrPostCard extends StatefulWidget {
  final NostrFeedPost post;
  final int zapAmount;
  final Function(int) onZap;
  final VoidCallback onLike;
  final VoidCallback onRepost;
  final VoidCallback onReply;
  final VoidCallback onShare;
  final VoidCallback onProfileTap;
  final bool isLiked;
  final bool showImages;
  final int likeCount;
  final int repostCount;
  final int replyCount;

  const _NostrPostCard({
    required this.post,
    required this.zapAmount,
    required this.onZap,
    required this.onLike,
    required this.onRepost,
    required this.onReply,
    required this.onShare,
    required this.onProfileTap,
    required this.isLiked,
    required this.showImages,
    this.likeCount = 0,
    this.repostCount = 0,
    this.replyCount = 0,
  });

  @override
  State<_NostrPostCard> createState() => _NostrPostCardState();
}

class _NostrPostCardState extends State<_NostrPostCard> {
  bool _showZapSlider = false;
  double _zapValue = 21; // Default 21 sats (Primal-style)
  final Set<int> _unblurredImages = {};

  // Extract image URLs from post content
  List<String> _extractImageUrls(String content) {
    final urlRegex = RegExp(
      r'https?://[^\s]+\.(?:jpg|jpeg|png|gif|webp)(?:\?[^\s]*)?',
      caseSensitive: false,
    );
    return urlRegex.allMatches(content).map((m) => m.group(0)!).toList();
  }

  // Check if image might be NSFW (simple heuristic)
  bool _isPotentiallyNsfw(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.contains('nsfw') ||
        lowerUrl.contains('adult') ||
        lowerUrl.contains('xxx') ||
        lowerUrl.contains('porn');
  }

  // Get text content without image URLs
  String _getTextContent(String content, List<String> imageUrls) {
    String text = content;
    for (final url in imageUrls) {
      text = text.replaceAll(url, '');
    }
    return text.trim();
  }

  void _showZapSliderModal() {
    setState(() => _showZapSlider = true);
  }

  void _confirmZap() {
    widget.onZap(_zapValue.toInt());
    setState(() => _showZapSlider = false);
  }

  void _openFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullScreenImageView(imageUrl: imageUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrls = _extractImageUrls(widget.post.content);
    final textContent = _getTextContent(widget.post.content, imageUrls);
    final hasImages = imageUrls.isNotEmpty && widget.showImages;

    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      decoration: BoxDecoration(
        color: const Color(0xFF111128),
        border: Border(
          bottom: BorderSide(color: const Color(0xFF1E1E3F), width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main content area
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                GestureDetector(
                  onTap: widget.onProfileTap,
                  child: Container(
                    width: 40.w,
                    height: 40.h,
                    decoration: BoxDecoration(
                      color: _getAvatarColor(widget.post.authorName),
                      shape: BoxShape.circle,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child:
                        widget.post.authorAvatar != null
                            ? CachedNetworkImage(
                              imageUrl: widget.post.authorAvatar!,
                              fit: BoxFit.cover,
                              placeholder:
                                  (context, url) => _buildAvatarPlaceholder(),
                              errorWidget:
                                  (context, url, error) =>
                                      _buildAvatarPlaceholder(),
                            )
                            : _buildAvatarPlaceholder(),
                  ),
                ),
                SizedBox(width: 12.w),
                // Content column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Name, handle, time
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.post.authorName,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 4.w),
                          // Verified badge (if applicable)
                          if (widget.post.authorName.toLowerCase().contains(
                                'bitcoin',
                              ) ||
                              widget.zapAmount > 1000)
                            Icon(
                              Icons.verified,
                              color: const Color(0xFFF7931A),
                              size: 14.sp,
                            ),
                          SizedBox(width: 4.w),
                          Text(
                            '· ${_formatTime(widget.post.timestamp)}',
                            style: TextStyle(
                              color: const Color(0xFF6B6B80),
                              fontSize: 13.sp,
                            ),
                          ),
                        ],
                      ),
                      // NIP-05 identifier if available
                      if (widget.post.lightningAddress != null)
                        Padding(
                          padding: EdgeInsets.only(top: 1.h),
                          child: Text(
                            widget.post.lightningAddress!,
                            style: TextStyle(
                              color: const Color(0xFF6B6B80),
                              fontSize: 12.sp,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      SizedBox(height: 6.h),
                      // Post content
                      if (textContent.isNotEmpty)
                        Text(
                          textContent,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15.sp,
                            height: 1.4,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Images section (if any)
          if (hasImages) ...[
            SizedBox(height: 8.h),
            _buildImagesSection(imageUrls),
          ],

          // Zap slider (when active)
          if (_showZapSlider) ...[SizedBox(height: 8.h), _buildZapSlider()],

          // Action bar (Primal-style bottom icons)
          if (!_showZapSlider)
            Padding(
              padding: EdgeInsets.fromLTRB(52.w, 8.h, 16.w, 12.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Reply
                  _ActionButton(
                    icon: Icons.chat_bubble_outline,
                    count: widget.replyCount,
                    color: const Color(0xFF6B6B80),
                    onTap: widget.onReply,
                  ),
                  // Repost
                  _ActionButton(
                    icon: Icons.repeat,
                    count: widget.repostCount,
                    color: const Color(0xFF6B6B80),
                    onTap: widget.onRepost,
                  ),
                  // Like
                  _ActionButton(
                    icon:
                        widget.isLiked ? Icons.favorite : Icons.favorite_border,
                    count:
                        widget.isLiked
                            ? widget.likeCount + 1
                            : widget.likeCount,
                    color:
                        widget.isLiked
                            ? const Color(0xFFE91E63)
                            : const Color(0xFF6B6B80),
                    activeColor: const Color(0xFFE91E63),
                    isActive: widget.isLiked,
                    onTap: widget.onLike,
                  ),
                  // Zap
                  _ActionButton(
                    icon: Icons.electric_bolt,
                    count: widget.zapAmount,
                    color:
                        widget.zapAmount > 0
                            ? const Color(0xFFF7931A)
                            : const Color(0xFF6B6B80),
                    activeColor: const Color(0xFFF7931A),
                    isActive: widget.zapAmount > 0,
                    showSats: true,
                    onTap: _showZapSliderModal,
                  ),
                  // Share/More
                  GestureDetector(
                    onTap: widget.onShare,
                    child: Icon(
                      Icons.ios_share,
                      color: const Color(0xFF6B6B80),
                      size: 18.sp,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarPlaceholder() {
    return Center(
      child: Text(
        widget.post.authorName.isNotEmpty
            ? widget.post.authorName[0].toUpperCase()
            : '?',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildImagesSection(List<String> imageUrls) {
    if (imageUrls.length == 1) {
      return _buildSingleImage(imageUrls[0], 0);
    } else {
      // Multiple images - horizontal carousel
      return SizedBox(
        height: 200.h,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          itemCount: imageUrls.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: EdgeInsets.only(
                right: index < imageUrls.length - 1 ? 8.w : 0,
              ),
              child: _buildCarouselImage(imageUrls[index], index),
            );
          },
        ),
      );
    }
  }

  Widget _buildSingleImage(String url, int index) {
    final isNsfw = _isPotentiallyNsfw(url);
    final isUnblurred = _unblurredImages.contains(index);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: GestureDetector(
        onTap: () {
          if (isNsfw && !isUnblurred) {
            setState(() => _unblurredImages.add(index));
          } else {
            _openFullScreenImage(context, url);
          }
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20.r),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 300.h),
            child: Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder:
                      (context, url) => Container(
                        height: 200.h,
                        color: const Color(0xFF111128).withOpacity(0.2),
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(
                              const Color(0xFFF7931A).withOpacity(0.5),
                            ),
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                  errorWidget:
                      (context, url, error) => Container(
                        height: 100.h,
                        color: const Color(0xFF111128),
                        child: Center(
                          child: Icon(
                            Icons.broken_image,
                            color: const Color(0xFFA1A1B2),
                            size: 32.sp,
                          ),
                        ),
                      ),
                ),
                // NSFW blur overlay
                if (isNsfw && !isUnblurred)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20.r),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          color: Colors.black.withOpacity(0.5),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.visibility_off,
                                  color: Colors.white,
                                  size: 32.sp,
                                ),
                                SizedBox(height: 8.h),
                                Text(
                                  'Sensitive Content',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  'Tap to unblur',
                                  style: TextStyle(
                                    color: const Color(0xFFA1A1B2),
                                    fontSize: 12.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCarouselImage(String url, int index) {
    final isNsfw = _isPotentiallyNsfw(url);
    final isUnblurred = _unblurredImages.contains(index);

    return GestureDetector(
      onTap: () {
        if (isNsfw && !isUnblurred) {
          setState(() => _unblurredImages.add(index));
        } else {
          _openFullScreenImage(context, url);
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        child: Stack(
          children: [
            CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              width: 200.w,
              height: 200.h,
              placeholder:
                  (context, url) => Container(
                    width: 200.w,
                    height: 200.h,
                    color: const Color(0xFF111128).withOpacity(0.2),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(
                          const Color(0xFFF7931A).withOpacity(0.5),
                        ),
                        strokeWidth: 2,
                      ),
                    ),
                  ),
              errorWidget:
                  (context, url, error) => Container(
                    width: 200.w,
                    height: 200.h,
                    color: const Color(0xFF111128),
                    child: Center(
                      child: Icon(
                        Icons.broken_image,
                        color: const Color(0xFFA1A1B2),
                        size: 32.sp,
                      ),
                    ),
                  ),
            ),
            // NSFW blur overlay
            if (isNsfw && !isUnblurred)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20.r),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      color: Colors.black.withOpacity(0.5),
                      child: Center(
                        child: Icon(
                          Icons.visibility_off,
                          color: Colors.white,
                          size: 24.sp,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildZapSlider() {
    // Zap presets with sats values
    final zapPresets = [
      {'label': '21', 'sats': 21},
      {'label': '100', 'sats': 100},
      {'label': '500', 'sats': 500},
      {'label': '1K', 'sats': 1000},
      {'label': '5K', 'sats': 5000},
      {'label': '10K', 'sats': 10000},
    ];

    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C1A),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFF7931A).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with selected amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Zap Amount',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7931A).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.electric_bolt,
                      color: const Color(0xFFF7931A),
                      size: 14.sp,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      '${_zapValue.toInt()} sats',
                      style: TextStyle(
                        color: const Color(0xFFF7931A),
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          // Preset buttons grid
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children:
                zapPresets.map((preset) {
                  final sats = preset['sats'] as int;
                  final label = preset['label'] as String;
                  final isSelected = _zapValue.toInt() == sats;

                  return GestureDetector(
                    onTap: () => setState(() => _zapValue = sats.toDouble()),
                    child: Container(
                      width: 60.w,
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? const Color(0xFFF7931A)
                                : const Color(0xFF111128),
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(
                          color:
                              isSelected
                                  ? const Color(0xFFF7931A)
                                  : const Color(0xFF2A2A3E),
                        ),
                      ),
                      child: Column(
                        children: [
                          if (sats == 21)
                            Icon(
                              Icons.electric_bolt,
                              color:
                                  isSelected
                                      ? Colors.white
                                      : const Color(0xFFF7931A),
                              size: 14.sp,
                            ),
                          Text(
                            label,
                            style: TextStyle(
                              color:
                                  isSelected
                                      ? Colors.white
                                      : const Color(0xFFA1A1B2),
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'sats',
                            style: TextStyle(
                              color:
                                  isSelected
                                      ? Colors.white.withOpacity(0.8)
                                      : const Color(0xFF6B6B80),
                              fontSize: 10.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
          ),
          SizedBox(height: 16.h),
          // Custom amount row
          GestureDetector(
            onTap: _showCustomZapInput,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 12.w),
              decoration: BoxDecoration(
                color: const Color(0xFF111128),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: const Color(0xFF2A2A3E)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit, color: const Color(0xFFA1A1B2), size: 14.sp),
                  SizedBox(width: 8.w),
                  Text(
                    'Custom Amount',
                    style: TextStyle(
                      color: const Color(0xFFA1A1B2),
                      fontSize: 13.sp,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16.h),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showZapSlider = false),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111128),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Center(
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: const Color(0xFFA1A1B2),
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: GestureDetector(
                  onTap: _confirmZap,
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF7931A), Color(0xFFFF9500)],
                      ),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.electric_bolt,
                            color: Colors.white,
                            size: 16.sp,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            'Zap ${_zapValue.toInt()} sats',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCustomZapInput() {
    final controller = TextEditingController(
      text: _zapValue.toInt().toString(),
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF111128),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.electric_bolt,
                  color: const Color(0xFFF7931A),
                  size: 20.sp,
                ),
                SizedBox(width: 8.w),
                Text(
                  'Custom Zap',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24.sp,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: TextStyle(
                  color: const Color(0xFF6B6B80),
                  fontSize: 24.sp,
                ),
                suffix: Text(
                  'sats',
                  style: TextStyle(
                    color: const Color(0xFFA1A1B2),
                    fontSize: 14.sp,
                  ),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: const Color(0xFF2A2A3E),
                    width: 2.w,
                  ),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: const Color(0xFFF7931A),
                    width: 2.w,
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Color(0xFFA1A1B2)),
                ),
              ),
              TextButton(
                onPressed: () {
                  final value = int.tryParse(controller.text);
                  if (value != null && value > 0 && value <= 1000000) {
                    setState(() => _zapValue = value.toDouble());
                    Navigator.pop(context);
                  }
                },
                child: const Text(
                  'Set',
                  style: TextStyle(
                    color: Color(0xFFF7931A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFFF7931A),
      const Color(0xFF00FFB2),
      const Color(0xFF6366F1),
      const Color(0xFFEC4899),
      const Color(0xFF8B5CF6),
    ];
    return colors[name.hashCode % colors.length];
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${time.month}/${time.day}/${time.year}';
    }
  }
}

/// Full screen image viewer
class _FullScreenImageView extends StatelessWidget {
  final String imageUrl;

  const _FullScreenImageView({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder:
                (context, url) => const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(Color(0xFFF7931A)),
                  ),
                ),
            errorWidget:
                (context, url, error) => const Center(
                  child: Icon(
                    Icons.broken_image,
                    color: Colors.white,
                    size: 64,
                  ),
                ),
          ),
        ),
      ),
    );
  }
}

/// Primal-style action button for post cards
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;
  final Color? activeColor;
  final bool isActive;
  final bool showSats;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.count,
    required this.color,
    this.activeColor,
    this.isActive = false,
    this.showSats = false,
    required this.onTap,
  });

  String _formatCount(int n) {
    if (n == 0) return '';
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    final displayCount = _formatCount(count);
    final displayColor = isActive ? (activeColor ?? color) : color;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 4.w),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: displayColor, size: 18.sp),
            if (displayCount.isNotEmpty) ...[
              SizedBox(width: 4.w),
              Text(
                showSats && count > 0 ? '$displayCount sats' : displayCount,
                style: TextStyle(
                  color: displayColor,
                  fontSize: 12.sp,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Share option button for share sheet
class _ShareOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ShareOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56.w,
            height: 56.h,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E3F),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFFF7931A), size: 24.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            label,
            style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 12.sp),
          ),
        ],
      ),
    );
  }
}

/// Reply modal for composing replies
class _ReplyModal extends StatefulWidget {
  final NostrFeedPost post;
  final VoidCallback onSent;

  const _ReplyModal({required this.post, required this.onSent});

  @override
  State<_ReplyModal> createState() => _ReplyModalState();
}

class _ReplyModalState extends State<_ReplyModal> {
  final _controller = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    if (_controller.text.trim().isEmpty) return;

    setState(() => _isSending = true);

    try {
      final socialService = nostr_v2.SocialInteractionService();
      final eventId = await socialService.replyToEvent(
        eventId: widget.post.id,
        eventPubkey: widget.post.authorPubkey,
        content: _controller.text.trim(),
      );

      if (eventId != null && mounted) {
        Navigator.pop(context);
        widget.onSent();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send reply'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Reply to @${widget.post.authorName}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: const Color(0xFF111128),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Text(
              widget.post.content.length > 100
                  ? '${widget.post.content.substring(0, 100)}...'
                  : widget.post.content,
              style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 13.sp),
            ),
          ),
          SizedBox(height: 16.h),
          TextField(
            controller: _controller,
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Write your reply...',
              hintStyle: const TextStyle(color: Color(0xFF6B6B80)),
              filled: true,
              fillColor: const Color(0xFF111128),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          SizedBox(height: 16.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSending ? null : _sendReply,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF7931A),
                disabledBackgroundColor: const Color(0xFF2A2A3E),
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child:
                  _isSending
                      ? SizedBox(
                        width: 20.w,
                        height: 20.h,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                      : Text(
                        'Reply',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }
}
