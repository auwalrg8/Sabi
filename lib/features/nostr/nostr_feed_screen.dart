import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_confetti/flutter_confetti.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'nostr_service.dart';
import 'nostr_edit_modal.dart';

/// Filter types for the feed
enum FeedFilter { newThreads, latest, trending24h }

/// Nostr feed screen displaying real posts from relays
class NostrFeedScreen extends StatefulWidget {
  const NostrFeedScreen({Key? key}) : super(key: key);

  @override
  State<NostrFeedScreen> createState() => _NostrFeedScreenState();
}

class _NostrFeedScreenState extends State<NostrFeedScreen> {
  List<NostrFeedPost> _posts = [];
  List<NostrFeedPost> _filteredPosts = [];
  bool _isLoading = true;
  String? _userNpub;
  String? _userHexPubkey;
  List<String> _userFollows = [];
  Map<String, int> _zapCounts = {};
  FeedFilter _currentFilter = FeedFilter.newThreads; // Default to follows feed
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showImages = false; // Default to text-only mode for low-data users
  Map<String, Map<String, String>> _authorMetadataCache = {};
  bool _followsFeedEmpty = false; // Track if follows feed returned no posts

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFeed() async {
    setState(() {
      _isLoading = true;
      _followsFeedEmpty = false;
    });

    try {
      await NostrService.init();
      final npub = await NostrService.getNpub();
      setState(() => _userNpub = npub);

      List<NostrFeedPost> posts = [];

      if (_currentFilter == FeedFilter.newThreads) {
        // Fetch follows feed - posts from people the user follows
        if (npub != null) {
          // Convert npub to hex pubkey for fetching follows
          _userHexPubkey = NostrService.npubToHex(npub);
          
          if (_userHexPubkey != null) {
            // Fetch user's follows (kind-3 contact list)
            _userFollows = await NostrService.fetchUserFollows(_userHexPubkey!);
            debugPrint('👥 User follows ${_userFollows.length} accounts');

            if (_userFollows.isNotEmpty) {
              // Fetch posts from follows (last 48 hours)
              posts = await NostrService.fetchFollowsFeed(
                followPubkeys: _userFollows,
                limit: 50,
              );
              
              if (posts.isEmpty) {
                setState(() => _followsFeedEmpty = true);
              }
            } else {
              // No follows yet - show empty state
              setState(() => _followsFeedEmpty = true);
            }
          }
        }
      } else {
        // Fetch global feed for Latest and Trending
        posts = await NostrService.fetchGlobalFeed(limit: 50);
      }

      // Fetch author metadata for each unique author
      final uniqueAuthors = posts.map((p) => p.authorPubkey).toSet();
      for (final pubkey in uniqueAuthors) {
        if (!_authorMetadataCache.containsKey(pubkey)) {
          final metadata = await NostrService.fetchAuthorMetadata(pubkey);
          if (metadata.isNotEmpty) {
            _authorMetadataCache[pubkey] = metadata;
            // Update posts with metadata
            for (final post in posts) {
              if (post.authorPubkey == pubkey) {
                post.authorName = metadata['name'] ?? post.authorName;
                post.authorAvatar = metadata['picture'];
              }
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _posts = posts;
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading feed: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
      case FeedFilter.newThreads:
        // Posts from follows, sorted by timestamp
        filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        break;
      case FeedFilter.latest:
        // Global posts, sorted by timestamp
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
    try {
      // Show confetti immediately for feedback
      Confetti.launch(
        context,
        options: const ConfettiOptions(particleCount: 50, spread: 360, y: 0.5),
      );

      // Update local zap count
      setState(() {
        _zapCounts[post.id] =
            (_zapCounts[post.id] ?? post.zapAmount) + satoshis;
      });

      // Send real payment via Breez SDK
      final nairaAmount = NostrService.satsToNaira(satoshis);

      // For now, show success with naira amount
      // In production, would create LNURL-pay or zap invoice
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⚡ Zapped ${post.authorName} ${NostrService.formatNaira(nairaAmount)}!',
          ),
          backgroundColor: const Color(0xFFF7931A),
          duration: const Duration(seconds: 2),
        ),
      );

      // TODO: Implement actual Lightning zap payment
      // await BreezSparkService.sendPayment(zapInvoice);
    } catch (e) {
      print('❌ Error sending zap: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to zap: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
                          activeColor: const Color(0xFFF7931A),
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
                  GestureDetector(
                    onTap: _loadFeed,
                    child: Icon(
                      Icons.refresh,
                      color: Colors.white,
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
                    label: 'New Threads',
                    isSelected: _currentFilter == FeedFilter.newThreads,
                    onTap: () => _onFilterChanged(FeedFilter.newThreads),
                  ),
                  SizedBox(width: 8.w),
                  _FilterTab(
                    label: 'Latest',
                    isSelected: _currentFilter == FeedFilter.latest,
                    onTap: () => _onFilterChanged(FeedFilter.latest),
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

            // Feed content
            Expanded(
              child:
                  _isLoading
                      ? _buildSkeletonLoader()
                      : _userNpub == null
                      ? _buildNoAccountState()
                      : (_followsFeedEmpty && _currentFilter == FeedFilter.newThreads)
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
              style: TextStyle(
                color: const Color(0xFFA1A1B2),
                fontSize: 14.sp,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => _onFilterChanged(FeedFilter.latest),
                  icon: Icon(Icons.public, size: 18.sp, color: const Color(0xFFF7931A)),
                  label: Text(
                    'Browse Global',
                    style: TextStyle(color: const Color(0xFFF7931A), fontSize: 14.sp),
                  ),
                ),
                SizedBox(width: 16.w),
                TextButton.icon(
                  onPressed: _loadFeed,
                  icon: Icon(Icons.refresh, size: 18.sp, color: const Color(0xFF00FFB2)),
                  label: Text(
                    'Refresh',
                    style: TextStyle(color: const Color(0xFF00FFB2), fontSize: 14.sp),
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
  final bool showImages;

  const _NostrPostCard({
    required this.post,
    required this.zapAmount,
    required this.onZap,
    required this.showImages,
  });

  @override
  State<_NostrPostCard> createState() => _NostrPostCardState();
}

class _NostrPostCardState extends State<_NostrPostCard> {
  bool _showZapSlider = false;
  double _zapValue = 100; // Default 100 sats
  Set<int> _unblurredImages = {};

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

              // Zap Button Row (at the bottom, not overlapping)
              if (!_showZapSlider)
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
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
