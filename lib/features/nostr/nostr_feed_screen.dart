import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_confetti/flutter_confetti.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:http/http.dart' as http;
import 'nostr_service.dart';
import 'nostr_edit_modal.dart';
import '../../services/breez_spark_service.dart';

/// Filter types for the feed
enum FeedFilter { global, following, trending24h }

/// Nostr feed screen displaying real posts from relays
class NostrFeedScreen extends StatefulWidget {
  const NostrFeedScreen({super.key});

  @override
  State<NostrFeedScreen> createState() => _NostrFeedScreenState();
}

class _NostrFeedScreenState extends State<NostrFeedScreen> {
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
  FeedFilter _currentFilter = FeedFilter.global; // Default to global feed
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showImages = false; // Default to text-only mode for low-data users
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
    _searchController.dispose();
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
  Future<void> _refreshFeedInBackground() async {
    if (mounted) {
      setState(() => _isRefreshing = true);
    }

    final debug = NostrService.debugService;
    debug.info(
      'SCREEN',
      'Background refresh started',
      'filter: $_currentFilter',
    );

    try {
      // Initialize Nostr service (quick if already done)
      await NostrService.init();

      // Get stored npub
      final npub = await NostrService.getNpub();
      _userNpub = npub;

      // Quick relay initialization
      await NostrService.reinitialize();

      List<NostrFeedPost> newPosts = [];

      if (_currentFilter == FeedFilter.following && npub != null) {
        _userHexPubkey = NostrService.npubToHex(npub);

        if (_userHexPubkey != null) {
          _userFollows = await NostrService.fetchUserFollowsDirect(
            _userHexPubkey!,
          );

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

      // Fetch author metadata for new posts in PARALLEL (much faster than sequential)
      final uniqueAuthors =
          newPosts
              .map((p) => p.authorPubkey)
              .toSet()
              .where((pubkey) => !_authorMetadataCache.containsKey(pubkey))
              .take(15)
              .toList();

      // Parallel fetch - all metadata at once instead of one-by-one
      if (uniqueAuthors.isNotEmpty) {
        final metadataFutures =
            uniqueAuthors.map((pubkey) async {
              try {
                final metadata = await NostrService.fetchAuthorMetadataDirect(
                  pubkey,
                );
                return MapEntry(pubkey, metadata);
              } catch (e) {
                return MapEntry(pubkey, <String, String>{});
              }
            }).toList();

        final results = await Future.wait(metadataFutures);
        for (final entry in results) {
          if (entry.value.isNotEmpty) {
            _authorMetadataCache[entry.key] = entry.value;
          }
        }
      }

      // Apply all cached metadata to posts
      for (final post in newPosts) {
        final meta = _authorMetadataCache[post.authorPubkey];
        if (meta != null) {
          post.authorName =
              meta['name'] ?? meta['display_name'] ?? post.authorName;
          post.authorAvatar = meta['picture'] ?? meta['avatar'];
          post.lightningAddress = meta['lud16'];
        }
      }

      if (mounted) {
        setState(() {
          // Merge new posts with existing (new first, no duplicates)
          _posts = NostrService.mergePosts(newPosts, _posts);
          _applyFilter();
          _isLoading = false;
          _isRefreshing = false;
          _hasCachedContent = true;
        });

        // Save to cache for next time
        await NostrService.cachePosts(_posts);
        await NostrService.cacheAuthorMetadata(_authorMetadataCache);

        debug.success(
          'SCREEN',
          'Background refresh complete',
          '${_posts.length} posts',
        );
      }
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

  /// Manual pull-to-refresh
  Future<void> _loadFeed() async {
    await _refreshFeedInBackground();
  }

  void _applyFilter() {
    List<NostrFeedPost> filtered = List.from(_posts);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered =
          filtered
              .where(
                (post) =>
                    post.content.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ||
                    post.authorName.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ),
              )
              .toList();
    }

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

  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query);
    _applyFilter();
  }

  void _onFilterChanged(FeedFilter filter) {
    if (_currentFilter != filter) {
      setState(() => _currentFilter = filter);
      // Reload feed when switching between follows and global
      _loadFeed();
    }
  }

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
              Text('Sending ${satoshis} sats to ${post.authorName}...'),
            ],
          ),
          backgroundColor: const Color(0xFFF7931A),
          duration: const Duration(seconds: 10),
        ),
      );

      // Step 1: Get LNURL-pay callback from lightning address
      // Lightning address format: name@domain -> https://domain/.well-known/lnurlp/name
      final parts = lightningAddress.split('@');
      if (parts.length != 2) {
        throw Exception('Invalid lightning address format');
      }
      final name = parts[0];
      final domain = parts[1];
      final lnurlEndpoint = 'https://$domain/.well-known/lnurlp/$name';

      // Fetch LNURL-pay parameters
      final lnurlResponse = await http.get(Uri.parse(lnurlEndpoint));
      if (lnurlResponse.statusCode != 200) {
        throw Exception('Failed to get LNURL-pay info');
      }

      final lnurlData = jsonDecode(lnurlResponse.body) as Map<String, dynamic>;
      final callback = lnurlData['callback'] as String?;
      final minSendable =
          (lnurlData['minSendable'] as num?) ?? 1000; // millisats
      final maxSendable =
          (lnurlData['maxSendable'] as num?) ?? 100000000000; // millisats

      if (callback == null) {
        throw Exception('No callback URL in LNURL response');
      }

      // Convert sats to millisats
      final amountMsat = satoshis * 1000;

      // Check amount bounds
      if (amountMsat < minSendable || amountMsat > maxSendable) {
        throw Exception(
          'Amount out of range (${minSendable ~/ 1000}-${maxSendable ~/ 1000} sats)',
        );
      }

      // Step 2: Request invoice from callback
      final separator = callback.contains('?') ? '&' : '?';
      final invoiceUrl = '$callback${separator}amount=$amountMsat';
      final invoiceResponse = await http.get(Uri.parse(invoiceUrl));

      if (invoiceResponse.statusCode != 200) {
        throw Exception('Failed to get invoice');
      }

      final invoiceData =
          jsonDecode(invoiceResponse.body) as Map<String, dynamic>;
      final invoice = invoiceData['pr'] as String?;

      if (invoice == null || invoice.isEmpty) {
        throw Exception('No invoice received');
      }

      // Step 3: Pay the invoice using Breez SDK
      await BreezSparkService.sendPayment(
        invoice,
        sats: satoshis,
        comment: 'Zap from Sabi Wallet',
        recipientName: post.authorName,
      );

      // Hide loading snackbar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Show confetti for success
      Confetti.launch(
        context,
        options: const ConfettiOptions(particleCount: 50, spread: 360, y: 0.5),
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

  void _handleLikePost(NostrFeedPost post) {
    setState(() {
      if (_likedPosts.contains(post.id)) {
        _likedPosts.remove(post.id);
      } else {
        _likedPosts.add(post.id);
      }
    });
    // TODO: Send like reaction to Nostr relays (NIP-25)
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
                  // Show Images toggle
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Images',
                        style: TextStyle(
                          color:
                              _showImages
                                  ? const Color(0xFFF7931A)
                                  : const Color(0xFFA1A1B2),
                          fontSize: 12.sp,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      SizedBox(
                        height: 24.h,
                        child: Switch(
                          value: _showImages,
                          onChanged: (val) => setState(() => _showImages = val),
                          activeThumbColor: const Color(0xFFF7931A),
                          activeTrackColor: const Color(
                            0xFFF7931A,
                          ).withOpacity(0.3),
                          inactiveThumbColor: const Color(0xFFA1A1B2),
                          inactiveTrackColor: const Color(0xFF111128),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: 8.w),
                  // Refresh button
                  GestureDetector(
                    onTap: _isRefreshing ? null : _loadFeed,
                    child: Icon(
                      Icons.refresh,
                      color:
                          _isRefreshing
                              ? const Color(0xFFA1A1B2)
                              : Colors.white,
                      size: 24.sp,
                    ),
                  ),
                ],
              ),
            ),

            // Search bar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF111128),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: TextStyle(color: Colors.white, fontSize: 14.sp),
                  decoration: InputDecoration(
                    hintText: 'Search posts...',
                    hintStyle: TextStyle(
                      color: const Color(0xFFA1A1B2),
                      fontSize: 14.sp,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: const Color(0xFFA1A1B2),
                      size: 20.sp,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 12.h,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 12.h),

            // Filter tabs
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                children: [
                  _FilterTab(
                    label: 'Global',
                    isSelected: _currentFilter == FeedFilter.global,
                    onTap: () => _onFilterChanged(FeedFilter.global),
                  ),
                  SizedBox(width: 8.w),
                  _FilterTab(
                    label: 'Following',
                    isSelected: _currentFilter == FeedFilter.following,
                    onTap: () => _onFilterChanged(FeedFilter.following),
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
                      ? _buildSkeletonLoader()
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
                              isLiked: _likedPosts.contains(post.id),
                              showImages: _showImages,
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

  Widget _buildSkeletonLoader() {
    return Skeletonizer(
      enabled: true,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Container(
            margin: EdgeInsets.only(bottom: 12.h),
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: const Color(0xFF111128),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44.w,
                      height: 44.h,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2A2A3E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 120.w,
                            height: 14.h,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A3E),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Container(
                            width: 80.w,
                            height: 12.h,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A3E),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 60.w,
                      height: 24.h,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A3E),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Container(
                  width: double.infinity,
                  height: 16.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A3E),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
                SizedBox(height: 8.h),
                Container(
                  width: 250.w,
                  height: 16.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A3E),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
                SizedBox(height: 8.h),
                Container(
                  width: 180.w,
                  height: 16.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A3E),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
              ],
            ),
          );
        },
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

/// Nostr post card widget with Moniepoint navy style
class _NostrPostCard extends StatefulWidget {
  final NostrFeedPost post;
  final int zapAmount;
  final Function(int) onZap;
  final VoidCallback onLike;
  final bool isLiked;
  final bool showImages;

  const _NostrPostCard({
    required this.post,
    required this.zapAmount,
    required this.onZap,
    required this.onLike,
    required this.isLiked,
    required this.showImages,
  });

  @override
  State<_NostrPostCard> createState() => _NostrPostCardState();
}

class _NostrPostCardState extends State<_NostrPostCard> {
  bool _showZapSlider = false;
  double _zapValue = 100; // Default 100 sats
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
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: const Color(0xFF111128),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Avatar + Name + Time + Zap Amount
                    Row(
                      children: [
                        // Avatar with image support
                        Container(
                          width: 44.w,
                          height: 44.h,
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
                                        (context, url) => Center(
                                          child: Text(
                                            widget.post.authorName.isNotEmpty
                                                ? widget.post.authorName[0]
                                                    .toUpperCase()
                                                : '?',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 18.sp,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    errorWidget:
                                        (context, url, error) => Center(
                                          child: Text(
                                            widget.post.authorName.isNotEmpty
                                                ? widget.post.authorName[0]
                                                    .toUpperCase()
                                                : '?',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 18.sp,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                  )
                                  : Center(
                                    child: Text(
                                      widget.post.authorName.isNotEmpty
                                          ? widget.post.authorName[0]
                                              .toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                        ),
                        SizedBox(width: 12.w),
                        // Name + Time
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.post.authorName,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _formatTime(widget.post.timestamp),
                                style: TextStyle(
                                  color: const Color(0xFFA1A1B2),
                                  fontSize: 12.sp,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Zap amount display
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 4.h,
                          ),
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
                                NostrService.formatNaira(
                                  NostrService.satsToNaira(widget.zapAmount),
                                ),
                                style: TextStyle(
                                  color: const Color(0xFFF7931A),
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),

                    // Text Content
                    if (textContent.isNotEmpty)
                      Text(
                        textContent,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          height: 1.5,
                        ),
                      ),
                  ],
                ),
              ),

              // Images section
              if (hasImages) ...[
                _buildImagesSection(imageUrls),
                SizedBox(height: 8.h),
              ],

              // Action Button Row (at the bottom, not overlapping)
              if (!_showZapSlider)
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Like button
                      GestureDetector(
                        onTap: widget.onLike,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 8.h,
                          ),
                          decoration: BoxDecoration(
                            color:
                                widget.isLiked
                                    ? const Color(0xFFEC4899).withOpacity(0.15)
                                    : const Color(0xFF111128),
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(
                              color:
                                  widget.isLiked
                                      ? const Color(0xFFEC4899)
                                      : const Color(
                                        0xFFA1A1B2,
                                      ).withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.isLiked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color:
                                    widget.isLiked
                                        ? const Color(0xFFEC4899)
                                        : const Color(0xFFA1A1B2),
                                size: 16.sp,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                'Like',
                                style: TextStyle(
                                  color:
                                      widget.isLiked
                                          ? const Color(0xFFEC4899)
                                          : const Color(0xFFA1A1B2),
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      // Zap button
                      GestureDetector(
                        onTap: _showZapSliderModal,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 8.h,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7931A),
                            borderRadius: BorderRadius.circular(20.r),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF7931A).withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
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
                                'Zap',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Zap Slider (when active)
              if (_showZapSlider) _buildZapSlider(),
            ],
          ),
        ],
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
    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C1A),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFF7931A).withOpacity(0.3)),
      ),
      child: Column(
        children: [
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
                      NostrService.formatNaira(
                        NostrService.satsToNaira(_zapValue.toInt()),
                      ),
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
          SizedBox(height: 12.h),
          // Slider from 21 to 10000 sats
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: const Color(0xFFF7931A),
              inactiveTrackColor: const Color(0xFF111128),
              thumbColor: const Color(0xFFF7931A),
              overlayColor: const Color(0xFFF7931A).withOpacity(0.2),
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 10.r),
              trackHeight: 6.h,
            ),
            child: Slider(
              value: _zapValue,
              min: 21,
              max: 10000,
              divisions: 100,
              onChanged: (val) => setState(() => _zapValue = val),
            ),
          ),
          SizedBox(height: 4.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                NostrService.formatNaira(NostrService.satsToNaira(21)),
                style: TextStyle(
                  color: const Color(0xFFA1A1B2),
                  fontSize: 10.sp,
                ),
              ),
              Text(
                NostrService.formatNaira(NostrService.satsToNaira(10000)),
                style: TextStyle(
                  color: const Color(0xFFA1A1B2),
                  fontSize: 10.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
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
                      color: const Color(0xFFF7931A),
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
                            'Zap!',
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
