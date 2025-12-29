import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_confetti/flutter_confetti.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'nostr_service.dart';
import '../../services/nostr/nostr_service.dart' as nostr_v2;
import '../../services/breez_spark_service.dart';

/// Full-featured Nostr Profile Screen
/// Displays user profile with banner, stats, posts, and social actions
class NostrProfileScreen extends ConsumerStatefulWidget {
  final String pubkey;
  final String? initialName;
  final String? initialAvatarUrl;

  const NostrProfileScreen({
    super.key,
    required this.pubkey,
    this.initialName,
    this.initialAvatarUrl,
  });

  @override
  ConsumerState<NostrProfileScreen> createState() => _NostrProfileScreenState();
}

class _NostrProfileScreenState extends ConsumerState<NostrProfileScreen>
    with SingleTickerProviderStateMixin {
  nostr_v2.NostrProfile? _profile;
  bool _isLoading = true;
  bool _isFollowing = false;
  bool _isCurrentUser = false;
  String? _currentUserPubkey;

  // Content
  List<NostrFeedPost> _posts = [];
  List<NostrFeedPost> _replies = [];
  List<NostrFeedPost> _mediaPosts = [];

  // Stats
  int _followerCount = 0;
  int _followingCount = 0;

  // Tabs
  late TabController _tabController;

  // Zap
  bool _isZapping = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    try {
      // Get current user to check if viewing own profile
      final currentNpub = await NostrService.getNpub();
      if (currentNpub != null) {
        _currentUserPubkey = NostrService.npubToHex(currentNpub);
        _isCurrentUser = _currentUserPubkey == widget.pubkey;
      }

      // Fetch profile metadata
      final profileService = nostr_v2.NostrProfileService();
      final profile = await profileService.fetchProfile(widget.pubkey);

      // Fetch user's posts
      final posts = await NostrService.fetchUserPostsDirect(
        widget.pubkey,
        limit: 30,
      );

      // Separate posts and replies
      final mainPosts = <NostrFeedPost>[];
      final replies = <NostrFeedPost>[];
      final mediaPosts = <NostrFeedPost>[];

      for (final post in posts) {
        // Check if it's a reply (has 'e' tag reference)
        if (post.content.startsWith('nostr:') ||
            post.content.contains('@') && post.replyCount > 0) {
          replies.add(post);
        } else {
          mainPosts.add(post);
        }

        // Check for media
        if (_hasMedia(post.content)) {
          mediaPosts.add(post);
        }
      }

      // Fetch follower/following counts
      final followingCount = await NostrService.fetchFollowingCount(
        widget.pubkey,
      );
      final followerCount = await NostrService.fetchFollowerCount(
        widget.pubkey,
      );

      // Check if current user follows this profile
      if (_currentUserPubkey != null && !_isCurrentUser) {
        final userFollows = await NostrService.getCachedFollows();
        _isFollowing = userFollows.contains(widget.pubkey);
      }

      if (mounted) {
        setState(() {
          _profile = profile;
          _posts = mainPosts;
          _replies = replies;
          _mediaPosts = mediaPosts;
          _followingCount = followingCount;
          _followerCount = followerCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _hasMedia(String content) {
    final mediaExtensions = [
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.webp',
      '.mp4',
      '.mov',
    ];
    final lowerContent = content.toLowerCase();
    return mediaExtensions.any((ext) => lowerContent.contains(ext)) ||
        content.contains('https://image.nostr.build') ||
        content.contains('https://nostr.build') ||
        content.contains('https://i.imgur.com');
  }

  Future<void> _toggleFollow() async {
    if (_isCurrentUser || _currentUserPubkey == null) return;

    try {
      final success = await NostrService.toggleFollow(
        targetPubkey: widget.pubkey,
        currentlyFollowing: _isFollowing,
      );

      if (success && mounted) {
        setState(() {
          _isFollowing = !_isFollowing;
          _followerCount += _isFollowing ? 1 : -1;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isFollowing ? 'Following' : 'Unfollowed'),
            backgroundColor: const Color(0xFFF7931A),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to ${_isFollowing ? 'unfollow' : 'follow'}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleZap() async {
    if (_profile?.lightningAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This user has no Lightning address configured'),
          backgroundColor: Color(0xFFA1A1B2),
        ),
      );
      return;
    }

    // Show zap amount picker
    final amount = await _showZapAmountPicker();
    if (amount == null) return;

    setState(() => _isZapping = true);

    try {
      final zapService = nostr_v2.ZapService();
      final result = await zapService.sendZap(
        recipientPubkey: widget.pubkey,
        amountSats: amount,
        comment: 'Profile zap from Sabi Wallet',
        getBalance: () async => await BreezSparkService.getBalance(),
        payInvoice: (String bolt11) async {
          final paymentResult = await BreezSparkService.sendPayment(
            bolt11,
            sats: amount,
            comment: 'Zap',
            recipientName: _profile?.displayNameOrFallback ?? 'User',
          );
          return paymentResult['payment']?.id as String?;
        },
      );

      if (result.isSuccess && mounted) {
        Confetti.launch(
          context,
          options: const ConfettiOptions(
            particleCount: 50,
            spread: 360,
            y: 0.5,
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚡ Zapped $amount sats!'),
            backgroundColor: const Color(0xFFF7931A),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'Zap failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Zap error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isZapping = false);
    }
  }

  Future<int?> _showZapAmountPicker() async {
    int selectedAmount = 1000;

    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF111128),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setModalState) => Padding(
                  padding: EdgeInsets.all(24.w),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '⚡ Zap ${_profile?.displayNameOrFallback ?? "User"}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 24.h),
                      // Preset amounts
                      Wrap(
                        spacing: 12.w,
                        runSpacing: 12.h,
                        alignment: WrapAlignment.center,
                        children:
                            [21, 100, 500, 1000, 5000, 10000].map((amount) {
                              final isSelected = selectedAmount == amount;
                              return GestureDetector(
                                onTap:
                                    () => setModalState(
                                      () => selectedAmount = amount,
                                    ),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16.w,
                                    vertical: 12.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        isSelected
                                            ? const Color(0xFFF7931A)
                                            : const Color(0xFF2A2A3E),
                                    borderRadius: BorderRadius.circular(12.r),
                                    border:
                                        isSelected
                                            ? null
                                            : Border.all(
                                              color: const Color(0xFF3A3A4E),
                                            ),
                                  ),
                                  child: Text(
                                    amount >= 1000
                                        ? '${amount ~/ 1000}K'
                                        : amount.toString(),
                                    style: TextStyle(
                                      color:
                                          isSelected
                                              ? Colors.white
                                              : const Color(0xFFA1A1B2),
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                      SizedBox(height: 24.h),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed:
                              () => Navigator.pop(context, selectedAmount),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF7931A),
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          child: Text(
                            'Zap $selectedAmount sats',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),
                    ],
                  ),
                ),
          ),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied'),
        backgroundColor: const Color(0xFFF7931A),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _shareProfile() {
    final npub =
        _profile?.npub ??
        NostrService.hexToNpub(widget.pubkey) ??
        widget.pubkey;
    final name = _profile?.displayNameOrFallback ?? 'Nostr User';
    Share.share(
      'Check out $name on Nostr!\n\nnostr:$npub\n\nhttps://njump.me/$npub',
      subject: '$name on Nostr',
    );
  }

  Future<void> _openWebsite(String url) async {
    // Copy website URL to clipboard and show snackbar
    String fullUrl = url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      fullUrl = 'https://$url';
    }
    _copyToClipboard(fullUrl, 'Website URL');
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111128),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder:
          (context) => Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _OptionTile(
                  icon: Icons.copy,
                  label: 'Copy npub',
                  onTap: () {
                    Navigator.pop(context);
                    final npub =
                        _profile?.npub ?? NostrService.hexToNpub(widget.pubkey);
                    if (npub != null) _copyToClipboard(npub, 'npub');
                  },
                ),
                if (_profile?.lightningAddress != null)
                  _OptionTile(
                    icon: Icons.flash_on,
                    label: 'Copy Lightning Address',
                    onTap: () {
                      Navigator.pop(context);
                      _copyToClipboard(
                        _profile!.lightningAddress!,
                        'Lightning address',
                      );
                    },
                  ),
                _OptionTile(
                  icon: Icons.share,
                  label: 'Share Profile',
                  onTap: () {
                    Navigator.pop(context);
                    _shareProfile();
                  },
                ),
                if (!_isCurrentUser)
                  _OptionTile(
                    icon: Icons.block,
                    label: 'Mute User',
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: Implement mute
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Mute feature coming soon'),
                        ),
                      );
                    },
                  ),
                SizedBox(height: 16.h),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C1A),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Color(0xFFF7931A)),
                ),
              )
              : RefreshIndicator(
                onRefresh: _loadProfile,
                color: const Color(0xFFF7931A),
                backgroundColor: const Color(0xFF111128),
                child: CustomScrollView(
                  slivers: [
                    // Collapsing header with banner and profile info
                    SliverAppBar(
                      expandedHeight: 280.h,
                      pinned: true,
                      backgroundColor: const Color(0xFF0C0C1A),
                      leading: IconButton(
                        icon: Container(
                          padding: EdgeInsets.all(8.r),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      actions: [
                        IconButton(
                          icon: Container(
                            padding: EdgeInsets.all(8.r),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.more_vert,
                              color: Colors.white,
                            ),
                          ),
                          onPressed: _showMoreOptions,
                        ),
                      ],
                      flexibleSpace: FlexibleSpaceBar(
                        background: _buildProfileHeader(),
                      ),
                    ),

                    // Tab bar
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _TabBarDelegate(
                        tabBar: TabBar(
                          controller: _tabController,
                          indicatorColor: const Color(0xFFF7931A),
                          labelColor: const Color(0xFFF7931A),
                          unselectedLabelColor: const Color(0xFFA1A1B2),
                          tabs: [
                            Tab(text: 'Posts (${_posts.length})'),
                            Tab(text: 'Replies (${_replies.length})'),
                            Tab(text: 'Media (${_mediaPosts.length})'),
                          ],
                        ),
                      ),
                    ),

                    // Tab content
                    SliverFillRemaining(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildPostsList(_posts),
                          _buildPostsList(_replies),
                          _buildMediaGrid(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildProfileHeader() {
    final displayName =
        _profile?.displayNameOrFallback ?? widget.initialName ?? 'Unknown';
    final avatarUrl = _profile?.picture ?? widget.initialAvatarUrl;
    final bannerUrl = _profile?.banner;

    return Stack(
      children: [
        // Banner
        Container(
          height: 140.h,
          width: double.infinity,
          color: const Color(0xFF2A2A3E),
          child:
              bannerUrl != null
                  ? CachedNetworkImage(
                    imageUrl: bannerUrl,
                    fit: BoxFit.cover,
                    errorWidget:
                        (_, __, ___) =>
                            Container(color: const Color(0xFF2A2A3E)),
                  )
                  : Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1A1A2E), Color(0xFF2A2A3E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
        ),

        // Profile content below banner
        Positioned(
          top: 100.h,
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar and action buttons row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Avatar
                    Container(
                      width: 80.w,
                      height: 80.h,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF0C0C1A),
                          width: 4,
                        ),
                        color: const Color(0xFF2A2A3E),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child:
                          avatarUrl != null
                              ? CachedNetworkImage(
                                imageUrl: avatarUrl,
                                fit: BoxFit.cover,
                                errorWidget:
                                    (_, __, ___) => Icon(
                                      Icons.person,
                                      size: 40.sp,
                                      color: const Color(0xFFA1A1B2),
                                    ),
                              )
                              : Icon(
                                Icons.person,
                                size: 40.sp,
                                color: const Color(0xFFA1A1B2),
                              ),
                    ),
                    const Spacer(),
                    // Action buttons
                    if (!_isCurrentUser) ...[
                      // Zap button
                      _ActionButton(
                        icon: Icons.flash_on,
                        color: const Color(0xFFF7931A),
                        isLoading: _isZapping,
                        onTap: _handleZap,
                      ),
                      SizedBox(width: 8.w),
                      // Follow button
                      GestureDetector(
                        onTap: _toggleFollow,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20.w,
                            vertical: 8.h,
                          ),
                          decoration: BoxDecoration(
                            color:
                                _isFollowing
                                    ? const Color(0xFF2A2A3E)
                                    : const Color(0xFFF7931A),
                            borderRadius: BorderRadius.circular(20.r),
                            border:
                                _isFollowing
                                    ? Border.all(color: const Color(0xFFF7931A))
                                    : null,
                          ),
                          child: Text(
                            _isFollowing ? 'Following' : 'Follow',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      // Edit profile button for current user
                      GestureDetector(
                        onTap: () {
                          // TODO: Navigate to edit profile
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Edit profile coming soon'),
                            ),
                          );
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20.w,
                            vertical: 8.h,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2A3E),
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(color: const Color(0xFF3A3A4E)),
                          ),
                          child: Text(
                            'Edit Profile',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                SizedBox(height: 12.h),

                // Name and verification
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_profile?.nip05 != null) ...[
                      SizedBox(width: 4.w),
                      Icon(
                        Icons.verified,
                        color: const Color(0xFFF7931A),
                        size: 18.sp,
                      ),
                    ],
                  ],
                ),

                // NIP-05 or npub
                GestureDetector(
                  onTap: () {
                    final npub =
                        _profile?.npub ?? NostrService.hexToNpub(widget.pubkey);
                    if (npub != null) _copyToClipboard(npub, 'npub');
                  },
                  child: Text(
                    _profile?.nip05 ?? _profile?.shortNpub ?? '',
                    style: TextStyle(
                      color: const Color(0xFFA1A1B2),
                      fontSize: 14.sp,
                    ),
                  ),
                ),

                // About
                if (_profile?.about != null && _profile!.about!.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  Text(
                    _profile!.about!,
                    style: TextStyle(color: Colors.white, fontSize: 14.sp),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                SizedBox(height: 8.h),

                // Website and Lightning
                Row(
                  children: [
                    if (_profile?.website != null) ...[
                      GestureDetector(
                        onTap: () => _openWebsite(_profile!.website!),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.link,
                              color: const Color(0xFF00FFB2),
                              size: 14.sp,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              _profile!.website!.replaceAll(
                                RegExp(r'https?://'),
                                '',
                              ),
                              style: TextStyle(
                                color: const Color(0xFF00FFB2),
                                fontSize: 12.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 16.w),
                    ],
                    if (_profile?.lightningAddress != null)
                      GestureDetector(
                        onTap:
                            () => _copyToClipboard(
                              _profile!.lightningAddress!,
                              'Lightning address',
                            ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.flash_on,
                              color: const Color(0xFFF7931A),
                              size: 14.sp,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              _profile!.lightningAddress!,
                              style: TextStyle(
                                color: const Color(0xFFF7931A),
                                fontSize: 12.sp,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                SizedBox(height: 12.h),

                // Stats row
                Row(
                  children: [
                    _buildStat(_posts.length.toString(), 'Posts'),
                    SizedBox(width: 24.w),
                    _buildStat(_formatCount(_followerCount), 'Followers'),
                    SizedBox(width: 24.w),
                    _buildStat(_formatCount(_followingCount), 'Following'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStat(String value, String label) {
    return Row(
      children: [
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(width: 4.w),
        Text(
          label,
          style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 14.sp),
        ),
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  Widget _buildPostsList(List<NostrFeedPost> posts) {
    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: 48.sp,
              color: const Color(0xFFA1A1B2),
            ),
            SizedBox(height: 12.h),
            Text(
              'No posts yet',
              style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 16.sp),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return _PostCard(post: post);
      },
    );
  }

  Widget _buildMediaGrid() {
    if (_mediaPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 48.sp,
              color: const Color(0xFFA1A1B2),
            ),
            SizedBox(height: 12.h),
            Text(
              'No media posts yet',
              style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 16.sp),
            ),
          ],
        ),
      );
    }

    // Extract image URLs from posts
    final imageUrls = <String>[];
    final urlPattern = RegExp(
      r'https?://[^\s<>\[\]()]+\.(jpg|jpeg|png|gif|webp)',
      caseSensitive: false,
    );

    for (final post in _mediaPosts) {
      final matches = urlPattern.allMatches(post.content);
      for (final match in matches) {
        imageUrls.add(match.group(0)!);
      }
    }

    if (imageUrls.isEmpty) {
      return Center(
        child: Text(
          'No images found',
          style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 16.sp),
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(4.w),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4.w,
        mainAxisSpacing: 4.h,
      ),
      itemCount: imageUrls.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => _showFullImage(imageUrls[index]),
          child: CachedNetworkImage(
            imageUrl: imageUrls[index],
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: const Color(0xFF2A2A3E)),
            errorWidget:
                (_, __, ___) => Container(
                  color: const Color(0xFF2A2A3E),
                  child: const Icon(
                    Icons.broken_image,
                    color: Color(0xFFA1A1B2),
                  ),
                ),
          ),
        );
      },
    );
  }

  void _showFullImage(String url) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: InteractiveViewer(
                child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
              ),
            ),
          ),
    );
  }
}

/// Tab bar delegate for sliver
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabBarDelegate({required this.tabBar});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: const Color(0xFF0C0C1A), child: tabBar);
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      false;
}

/// Action button widget
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isLoading;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    this.isLoading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: 40.w,
        height: 40.h,
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          shape: BoxShape.circle,
          border: Border.all(color: color),
        ),
        child:
            isLoading
                ? Padding(
                  padding: EdgeInsets.all(10.r),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                )
                : Icon(icon, color: color, size: 20.sp),
      ),
    );
  }
}

/// Option tile for bottom sheet
class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        label,
        style: TextStyle(color: Colors.white, fontSize: 16.sp),
      ),
      onTap: onTap,
    );
  }
}

/// Post card for profile
class _PostCard extends StatelessWidget {
  final NostrFeedPost post;

  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF1E1E3F))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            post.content,
            style: TextStyle(color: Colors.white, fontSize: 14.sp),
          ),
          SizedBox(height: 12.h),
          // Engagement row
          Row(
            children: [
              _EngagementItem(
                icon: Icons.chat_bubble_outline,
                count: post.replyCount,
              ),
              SizedBox(width: 24.w),
              _EngagementItem(icon: Icons.repeat, count: post.repostCount),
              SizedBox(width: 24.w),
              _EngagementItem(
                icon: Icons.favorite_border,
                count: post.likeCount,
              ),
              const Spacer(),
              Text(
                post.timeAgo,
                style: TextStyle(
                  color: const Color(0xFF6B6B80),
                  fontSize: 12.sp,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Engagement item widget
class _EngagementItem extends StatelessWidget {
  final IconData icon;
  final int count;

  const _EngagementItem({required this.icon, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFFA1A1B2), size: 16.sp),
        if (count > 0) ...[
          SizedBox(width: 4.w),
          Text(
            count.toString(),
            style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 12.sp),
          ),
        ],
      ],
    );
  }
}
