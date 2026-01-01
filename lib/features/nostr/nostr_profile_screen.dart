import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_confetti/flutter_confetti.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'nostr_service.dart';
import '../../services/nostr/nostr_service.dart' as nostr_v2;
import '../../services/nostr/dm_service.dart';
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
  int _totalZapsReceived = 0;

  // Social proof - Primal-style features
  bool _followsYou = false;
  List<Map<String, String?>> _followedByList = []; // {pubkey, name, avatar}

  // Tabs
  late TabController _tabController;

  // Zap
  bool _isZapping = false;

  // Track liked posts
  final Set<String> _likedPosts = {};

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
      // Get current user to check if viewing own profile (fast, local)
      final currentNpub = await NostrService.getNpub();
      if (currentNpub != null) {
        _currentUserPubkey = NostrService.npubToHex(currentNpub);
        _isCurrentUser = _currentUserPubkey == widget.pubkey;
      }

      // Check follow status from cache immediately (fast, local)
      if (_currentUserPubkey != null && !_isCurrentUser) {
        final userFollows = await NostrService.getCachedFollows();
        _isFollowing = userFollows.contains(widget.pubkey);
      }

      // Fetch profile metadata FIRST and show UI immediately
      final profileService = nostr_v2.NostrProfileService();
      final profile = await profileService.fetchProfile(widget.pubkey);

      // Show profile immediately while other data loads
      if (mounted) {
        setState(() {
          _profile = profile;
          _isLoading = false; // Show UI now!
        });
      }

      // Fetch remaining data in parallel (non-blocking for UI)
      final results = await Future.wait([
        NostrService.fetchUserPostsDirect(widget.pubkey, limit: 30),
        NostrService.fetchFollowingCount(widget.pubkey),
        NostrService.fetchFollowerCount(widget.pubkey),
        _fetchTotalZaps(),
      ]);

      // Process posts
      final posts = results[0] as List<NostrFeedPost>;
      final followingCount = results[1] as int;
      final followerCount = results[2] as int;
      final totalZaps = results[3] as int;

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

      if (mounted) {
        setState(() {
          _posts = mainPosts;
          _replies = replies;
          _mediaPosts = mediaPosts;
          _followingCount = followingCount;
          _followerCount = followerCount;
          _totalZapsReceived = totalZaps;
        });
      }

      // Fetch social proof data in background (non-blocking)
      if (!_isCurrentUser && _currentUserPubkey != null) {
        _fetchSocialProof();
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Fetch social proof: "follows you" and "followed by" data
  Future<void> _fetchSocialProof() async {
    try {
      // Check if this profile follows the current user
      final theirFollows = await NostrService.fetchUserFollowsDirect(
        widget.pubkey,
      );
      final followsYou = theirFollows.contains(_currentUserPubkey);

      // Get mutual follows (people the current user follows who also follow this profile)
      final myFollows = await NostrService.getCachedFollows();
      final profileService = nostr_v2.NostrProfileService();

      final mutualFollowers = <Map<String, String?>>[];
      int count = 0;
      for (final pubkey in myFollows) {
        if (count >= 5) break; // Only show 5 avatars

        // Check if this person follows the profile we're viewing
        final theirFollowList = await NostrService.fetchUserFollowsDirect(
          pubkey,
        );
        if (theirFollowList.contains(widget.pubkey)) {
          final profile = await profileService.fetchProfile(pubkey);
          mutualFollowers.add({
            'pubkey': pubkey,
            'name': profile?.displayName ?? profile?.name,
            'avatar': profile?.picture,
          });
          count++;
        }
      }

      if (mounted) {
        setState(() {
          _followsYou = followsYou;
          _followedByList = mutualFollowers;
        });
      }
    } catch (e) {
      debugPrint('Error fetching social proof: $e');
    }
  }

  /// Fetch total zaps with error handling (returns 0 on error)
  Future<int> _fetchTotalZaps() async {
    try {
      final zapService = nostr_v2.ZapService();
      return await zapService.getTotalZapsReceived(widget.pubkey);
    } catch (e) {
      debugPrint('Error fetching zaps: $e');
      return 0;
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

  /// Open DM conversation with this user
  void _openMessageScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => _DirectMessageScreen(
              pubkey: widget.pubkey,
              displayName: _profile?.displayNameOrFallback,
              avatarUrl: _profile?.picture,
            ),
      ),
    );
  }

  /// Show QR code modal with npub and lightning address
  void _showQRModal() {
    final npub =
        _profile?.npub ??
        NostrService.hexToNpub(widget.pubkey) ??
        widget.pubkey;
    final lightningAddress = _profile?.lightningAddress;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111128),
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            expand: false,
            builder:
                (context, scrollController) => SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: EdgeInsets.all(24.w),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Handle bar
                        Container(
                          width: 40.w,
                          height: 4.h,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3A3A4E),
                            borderRadius: BorderRadius.circular(2.r),
                          ),
                        ),
                        SizedBox(height: 24.h),

                        // Avatar
                        CircleAvatar(
                          radius: 40.r,
                          backgroundColor: const Color(0xFF2A2A3E),
                          backgroundImage:
                              _profile?.picture != null
                                  ? CachedNetworkImageProvider(
                                    _profile!.picture!,
                                  )
                                  : null,
                          child:
                              _profile?.picture == null
                                  ? Icon(
                                    Icons.person,
                                    size: 40.sp,
                                    color: Colors.white54,
                                  )
                                  : null,
                        ),
                        SizedBox(height: 12.h),

                        // Name
                        Text(
                          _profile?.displayNameOrFallback ?? 'Unknown',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 24.h),

                        // QR Code
                        Container(
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          child: QrImageView(
                            data: 'nostr:$npub',
                            version: QrVersions.auto,
                            size: 200.w,
                            backgroundColor: Colors.white,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Colors.black,
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        SizedBox(height: 24.h),

                        // Npub section
                        _QRInfoTile(
                          label: 'Nostr Public Key',
                          value: npub,
                          icon: Icons.key,
                          onCopy: () => _copyToClipboard(npub, 'npub'),
                        ),

                        if (lightningAddress != null) ...[
                          SizedBox(height: 16.h),
                          _QRInfoTile(
                            label: 'Lightning Address',
                            value: lightningAddress,
                            icon: Icons.flash_on,
                            iconColor: const Color(0xFFF7931A),
                            onCopy:
                                () => _copyToClipboard(
                                  lightningAddress,
                                  'Lightning address',
                                ),
                          ),
                        ],

                        SizedBox(height: 24.h),

                        // Share button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _shareProfile();
                            },
                            icon: const Icon(Icons.share, color: Colors.white),
                            label: Text(
                              'Share Profile',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF7931A),
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
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

  // ==================== POST INTERACTION HANDLERS ====================

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

    // Send like reaction to Nostr relays
    if (!wasLiked) {
      try {
        final socialService = nostr_v2.SocialInteractionService();
        final success = await socialService.likeEvent(
          eventId: post.id,
          eventPubkey: post.authorPubkey,
        );

        if (!success && mounted) {
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

  void _handleRepostPost(NostrFeedPost post) async {
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
                  backgroundColor: const Color(0xFF00FFB2),
                ),
                child: const Text(
                  'Repost',
                  style: TextStyle(color: Colors.black),
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
              content: Text(success ? 'Reposted!' : 'Failed to repost'),
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

  void _handleReplyToPost(NostrFeedPost post) {
    // Show reply modal
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111128),
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder:
          (context) => _ReplyModal(
            post: post,
            onReply: (content) async {
              final socialService = nostr_v2.SocialInteractionService();
              final replyId = await socialService.replyToEvent(
                eventId: post.id,
                eventPubkey: post.authorPubkey,
                content: content,
              );
              return replyId != null;
            },
          ),
    );
  }

  void _handleZapPost(NostrFeedPost post, int satoshis) async {
    if (post.lightningAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This user has no Lightning address'),
          backgroundColor: Color(0xFFA1A1B2),
        ),
      );
      return;
    }

    try {
      final zapService = nostr_v2.ZapService();
      final result = await zapService.sendZap(
        recipientPubkey: post.authorPubkey,
        amountSats: satoshis,
        eventId: post.id,
        comment: 'Zap from Sabi Wallet',
        getBalance: () async => await BreezSparkService.getBalance(),
        payInvoice: (String bolt11) async {
          final paymentResult = await BreezSparkService.sendPayment(
            bolt11,
            sats: satoshis,
            comment: 'Zap',
            recipientName: post.authorName,
          );
          return paymentResult['payment']?.id as String?;
        },
      );

      if (result.isSuccess && mounted) {
        Confetti.launch(
          context,
          options: const ConfettiOptions(
            particleCount: 30,
            spread: 360,
            y: 0.5,
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚡ Zapped $satoshis sats!'),
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
    }
  }

  void _handleSharePost(NostrFeedPost post) {
    // Use hex ID for sharing - njump supports both note1 and hex IDs
    Share.share(
      '${post.content}\n\nhttps://njump.me/${post.id}',
      subject: 'Note from ${post.authorName}',
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
                // Avatar and action buttons row (Primal-style)
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
                    // Primal-style action buttons row
                    if (!_isCurrentUser) ...[
                      // QR Code button
                      _ProfileActionButton(
                        icon: Icons.qr_code_2,
                        onTap: _showQRModal,
                      ),
                      SizedBox(width: 8.w),
                      // Zap button
                      _ProfileActionButton(
                        icon: Icons.flash_on,
                        iconColor: const Color(0xFFF7931A),
                        isLoading: _isZapping,
                        onTap: _handleZap,
                      ),
                      SizedBox(width: 8.w),
                      // Message button
                      _ProfileActionButton(
                        icon: Icons.mail_outline,
                        onTap: _openMessageScreen,
                      ),
                      SizedBox(width: 8.w),
                      // Follow button
                      GestureDetector(
                        onTap: _toggleFollow,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
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
                            _isFollowing ? 'unfollow' : 'follow',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      // QR button for own profile
                      _ProfileActionButton(
                        icon: Icons.qr_code_2,
                        onTap: _showQRModal,
                      ),
                      SizedBox(width: 8.w),
                      // Edit profile button for current user
                      GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Edit profile coming soon'),
                            ),
                          );
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
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
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                SizedBox(height: 12.h),

                // Name, verification, and "follows you" badge
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
                    if (_followsYou && !_isCurrentUser) ...[
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A3E),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          'follows you',
                          style: TextStyle(
                            color: const Color(0xFFA1A1B2),
                            fontSize: 11.sp,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                // NIP-05 / Lightning address
                GestureDetector(
                  onTap: () {
                    final text = _profile?.nip05 ?? _profile?.lightningAddress;
                    if (text != null) _copyToClipboard(text, 'Address');
                  },
                  child: Text(
                    _profile?.nip05 ??
                        _profile?.lightningAddress ??
                        _profile?.shortNpub ??
                        '',
                    style: TextStyle(
                      color: const Color(0xFFA1A1B2),
                      fontSize: 14.sp,
                    ),
                  ),
                ),

                // About (with overflow protection)
                if (_profile?.about != null && _profile!.about!.isNotEmpty) ...[
                  SizedBox(height: 6.h),
                  Text(
                    _profile!.about!,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.sp,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // Website link
                if (_profile?.website != null) ...[
                  SizedBox(height: 4.h),
                  GestureDetector(
                    onTap: () => _openWebsite(_profile!.website!),
                    child: Text(
                      _profile!.website!.replaceAll(RegExp(r'https?://'), ''),
                      style: TextStyle(
                        color: const Color(0xFF00FFB2),
                        fontSize: 13.sp,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],

                SizedBox(height: 8.h),

                // Stats row (Following / Followers)
                Row(
                  children: [
                    Text(
                      '${_formatCount(_followingCount)} ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'following',
                      style: TextStyle(
                        color: const Color(0xFFA1A1B2),
                        fontSize: 14.sp,
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Text(
                      '${_formatCount(_followerCount)} ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'followers',
                      style: TextStyle(
                        color: const Color(0xFFA1A1B2),
                        fontSize: 14.sp,
                      ),
                    ),
                    if (_totalZapsReceived > 0) ...[
                      SizedBox(width: 16.w),
                      Icon(
                        Icons.bolt,
                        color: const Color(0xFFF7931A),
                        size: 14.sp,
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        '${_formatCount(_totalZapsReceived)} sats',
                        style: TextStyle(
                          color: const Color(0xFFF7931A),
                          fontSize: 14.sp,
                        ),
                      ),
                    ],
                    if (_followsYou && !_isCurrentUser) ...[
                      SizedBox(width: 12.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7931A).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          'follows you',
                          style: TextStyle(
                            color: const Color(0xFFF7931A),
                            fontSize: 11.sp,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                // Followed by section (Primal-style)
                if (_followedByList.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  _buildFollowedBySection(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Build the "Followed by" section with avatars
  Widget _buildFollowedBySection() {
    return Row(
      children: [
        // Stacked avatars
        SizedBox(
          width: (_followedByList.length * 20.w) + 12.w,
          height: 24.h,
          child: Stack(
            children:
                _followedByList.asMap().entries.map((entry) {
                  final index = entry.key;
                  final follower = entry.value;
                  return Positioned(
                    left: index * 16.w,
                    child: Container(
                      width: 24.w,
                      height: 24.h,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF0C0C1A),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 10.r,
                        backgroundColor: const Color(0xFF2A2A3E),
                        backgroundImage:
                            follower['avatar'] != null
                                ? CachedNetworkImageProvider(
                                  follower['avatar']!,
                                )
                                : null,
                        child:
                            follower['avatar'] == null
                                ? Icon(
                                  Icons.person,
                                  size: 10.sp,
                                  color: Colors.white54,
                                )
                                : null,
                      ),
                    ),
                  );
                }).toList(),
          ),
        ),
        SizedBox(width: 4.w),
        Expanded(
          child: Text(
            'Followed by ${_followedByList.map((f) => f['name'] ?? 'user').take(3).join(', ')}${_followedByList.length > 3 ? '...' : ''}',
            style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 12.sp),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
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
        return _InteractivePostCard(
          post: post,
          profile: _profile,
          onLike: () => _handleLikePost(post),
          onRepost: () => _handleRepostPost(post),
          onReply: () => _handleReplyToPost(post),
          onZap: (sats) => _handleZapPost(post, sats),
          onShare: () => _handleSharePost(post),
        );
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

/// Interactive post card with full functionality
class _InteractivePostCard extends StatefulWidget {
  final NostrFeedPost post;
  final nostr_v2.NostrProfile? profile;
  final VoidCallback onLike;
  final VoidCallback onRepost;
  final VoidCallback onReply;
  final Function(int) onZap;
  final VoidCallback onShare;

  const _InteractivePostCard({
    required this.post,
    required this.profile,
    required this.onLike,
    required this.onRepost,
    required this.onReply,
    required this.onZap,
    required this.onShare,
  });

  @override
  State<_InteractivePostCard> createState() => _InteractivePostCardState();
}

class _InteractivePostCardState extends State<_InteractivePostCard> {
  bool _isLiked = false;
  double _zapValue = 21;

  // Extract image URLs from content
  List<String> _extractImageUrls(String content) {
    final urlRegex = RegExp(
      r'https?://[^\s]+\.(?:jpg|jpeg|png|gif|webp)(?:\?[^\s]*)?',
      caseSensitive: false,
    );
    return urlRegex.allMatches(content).map((m) => m.group(0)!).toList();
  }

  String _getTextContent(String content, List<String> imageUrls) {
    String text = content;
    for (final url in imageUrls) {
      text = text.replaceAll(url, '');
    }
    return text.trim();
  }

  void _handleLike() {
    setState(() => _isLiked = !_isLiked);
    widget.onLike();
  }

  void _showZapModal() {
    showModalBottomSheet(
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
                        '⚡ Zap this post',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 24.h),
                      Wrap(
                        spacing: 12.w,
                        runSpacing: 12.h,
                        alignment: WrapAlignment.center,
                        children:
                            [21, 100, 500, 1000, 5000].map((amount) {
                              final isSelected = _zapValue.toInt() == amount;
                              return GestureDetector(
                                onTap:
                                    () => setModalState(
                                      () => _zapValue = amount.toDouble(),
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
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onZap(_zapValue.toInt());
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF7931A),
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          child: Text(
                            'Zap ${_zapValue.toInt()} sats',
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

  @override
  Widget build(BuildContext context) {
    final imageUrls = _extractImageUrls(widget.post.content);
    final textContent = _getTextContent(widget.post.content, imageUrls);
    final hasImages = imageUrls.isNotEmpty;

    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      decoration: BoxDecoration(
        color: const Color(0xFF111128),
        border: const Border(
          bottom: BorderSide(color: Color(0xFF1E1E3F), width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post content
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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

          // Images (if any)
          if (hasImages)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: GestureDetector(
                  onTap: () => _showFullImage(context, imageUrls[0]),
                  child: CachedNetworkImage(
                    imageUrl: imageUrls[0],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 200.h,
                    placeholder:
                        (_, __) => Container(
                          height: 200.h,
                          color: const Color(0xFF2A2A3E),
                          child: const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation(
                                Color(0xFFF7931A),
                              ),
                            ),
                          ),
                        ),
                    errorWidget:
                        (_, __, ___) => Container(
                          height: 100.h,
                          color: const Color(0xFF2A2A3E),
                          child: const Icon(
                            Icons.broken_image,
                            color: Color(0xFFA1A1B2),
                          ),
                        ),
                  ),
                ),
              ),
            ),

          // Action bar
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Reply
                _PostActionButton(
                  icon: Icons.chat_bubble_outline,
                  count: widget.post.replyCount,
                  onTap: widget.onReply,
                ),
                // Repost
                _PostActionButton(
                  icon: Icons.repeat,
                  count: widget.post.repostCount,
                  onTap: widget.onRepost,
                ),
                // Like
                _PostActionButton(
                  icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                  count:
                      _isLiked
                          ? widget.post.likeCount + 1
                          : widget.post.likeCount,
                  color:
                      _isLiked
                          ? const Color(0xFFE91E63)
                          : const Color(0xFF6B6B80),
                  onTap: _handleLike,
                ),
                // Zap
                _PostActionButton(
                  icon: Icons.electric_bolt,
                  count: widget.post.zapAmount,
                  color:
                      widget.post.zapAmount > 0
                          ? const Color(0xFFF7931A)
                          : const Color(0xFF6B6B80),
                  onTap: _showZapModal,
                ),
                // Share
                GestureDetector(
                  onTap: widget.onShare,
                  child: Icon(
                    Icons.ios_share,
                    color: const Color(0xFF6B6B80),
                    size: 18.sp,
                  ),
                ),
                // Time
                Text(
                  widget.post.timeAgo,
                  style: TextStyle(
                    color: const Color(0xFF6B6B80),
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFullImage(BuildContext context, String url) {
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

/// Action button for post interactions
class _PostActionButton extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;
  final VoidCallback onTap;

  const _PostActionButton({
    required this.icon,
    required this.count,
    required this.onTap,
    this.color = const Color(0xFF6B6B80),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18.sp),
          if (count > 0) ...[
            SizedBox(width: 4.w),
            Text(
              count > 999
                  ? '${(count / 1000).toStringAsFixed(1)}K'
                  : count.toString(),
              style: TextStyle(color: color, fontSize: 12.sp),
            ),
          ],
        ],
      ),
    );
  }
}

/// Reply modal for composing replies
class _ReplyModal extends StatefulWidget {
  final NostrFeedPost post;
  final Future<bool> Function(String) onReply;

  const _ReplyModal({required this.post, required this.onReply});

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

  Future<void> _send() async {
    if (_controller.text.trim().isEmpty) return;

    setState(() => _isSending = true);
    final success = await widget.onReply(_controller.text.trim());
    setState(() => _isSending = false);

    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reply sent!'),
          backgroundColor: Color(0xFF00FFB2),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send reply'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16.w,
        right: 16.w,
        top: 16.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reply to ${widget.post.authorName}',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12.h),
          // Original post preview
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(8.r),
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
            autofocus: true,
            style: TextStyle(color: Colors.white, fontSize: 15.sp),
            decoration: InputDecoration(
              hintText: 'Write your reply...',
              hintStyle: TextStyle(color: const Color(0xFF6B6B80)),
              filled: true,
              fillColor: const Color(0xFF1A1A2E),
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
              onPressed: _isSending ? null : _send,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF7931A),
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child:
                  _isSending
                      ? SizedBox(
                        height: 20.h,
                        width: 20.w,
                        child: const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                          strokeWidth: 2,
                        ),
                      )
                      : Text(
                        'Reply',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Profile action button (Primal-style circular button)
class _ProfileActionButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final bool isLoading;
  final VoidCallback onTap;

  const _ProfileActionButton({
    required this.icon,
    this.iconColor = Colors.white,
    this.isLoading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: 36.w,
        height: 36.h,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A3E),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF3A3A4E)),
        ),
        child:
            isLoading
                ? Padding(
                  padding: EdgeInsets.all(8.w),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(iconColor),
                  ),
                )
                : Icon(icon, color: iconColor, size: 18.sp),
      ),
    );
  }
}

/// QR Info tile for the QR modal
class _QRInfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onCopy;

  const _QRInfoTile({
    required this.label,
    required this.value,
    required this.icon,
    this.iconColor = Colors.white,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: const Color(0xFF6B6B80),
                    fontSize: 12.sp,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  value.length > 30
                      ? '${value.substring(0, 15)}...${value.substring(value.length - 10)}'
                      : value,
                  style: TextStyle(color: Colors.white, fontSize: 14.sp),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.copy, color: const Color(0xFFA1A1B2), size: 20.sp),
            onPressed: onCopy,
          ),
        ],
      ),
    );
  }
}

/// Direct Message screen for messaging a user from their profile
class _DirectMessageScreen extends StatefulWidget {
  final String pubkey;
  final String? displayName;
  final String? avatarUrl;

  const _DirectMessageScreen({
    required this.pubkey,
    this.displayName,
    this.avatarUrl,
  });

  @override
  State<_DirectMessageScreen> createState() => _DirectMessageScreenState();
}

class _DirectMessageScreenState extends State<_DirectMessageScreen> {
  final DMService _dmService = DMService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<DirectMessage> _messages = [];
  bool _isSending = false;
  bool _isLoading = true;
  StreamSubscription? _dmSubscription;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _dmSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    setState(() => _isLoading = true);

    try {
      await _dmService.initialize();
      await _dmService.fetchDMHistory();
      _loadMessages();
    } catch (e) {
      debugPrint('Error initializing DM: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _loadMessages() {
    final convo = _dmService.conversations.cast<DMConversation?>().firstWhere(
      (c) => c?.pubkey == widget.pubkey,
      orElse: () => null,
    );

    setState(() {
      _messages = convo?.messages ?? [];
    });

    // Listen for new messages
    _dmSubscription = _dmService.dmStream.listen((dm) {
      if (dm.senderPubkey == widget.pubkey ||
          dm.recipientPubkey == widget.pubkey) {
        _loadMessages();
        _scrollToBottom();
      }
    });

    // Mark as read
    _dmService.markConversationAsRead(widget.pubkey);

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);

    final success = await _dmService.sendDM(
      recipientPubkey: widget.pubkey,
      message: text,
    );

    if (mounted) {
      setState(() => _isSending = false);
      if (success) {
        _messageController.clear();
        _loadMessages();
        _scrollToBottom();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send message'),
            backgroundColor: Color(0xFFFF6B6B),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C0C1A),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20.sp,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16.r,
              backgroundColor: const Color(0xFF2A2A3E),
              backgroundImage:
                  widget.avatarUrl != null
                      ? CachedNetworkImageProvider(widget.avatarUrl!)
                      : null,
              child:
                  widget.avatarUrl == null
                      ? Icon(Icons.person, color: Colors.white54, size: 16.sp)
                      : null,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                widget.displayName ?? 'User',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFF7931A)),
              )
              : Column(
                children: [
                  // Messages list
                  Expanded(
                    child:
                        _messages.isEmpty
                            ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline,
                                    size: 48.sp,
                                    color: const Color(0xFF6B6B80),
                                  ),
                                  SizedBox(height: 12.h),
                                  Text(
                                    'No messages yet',
                                    style: TextStyle(
                                      color: const Color(0xFFA1A1B2),
                                      fontSize: 16.sp,
                                    ),
                                  ),
                                  SizedBox(height: 8.h),
                                  Text(
                                    'Send a message to start the conversation',
                                    style: TextStyle(
                                      color: const Color(0xFF6B6B80),
                                      fontSize: 14.sp,
                                    ),
                                  ),
                                ],
                              ),
                            )
                            : ListView.builder(
                              controller: _scrollController,
                              padding: EdgeInsets.all(16.w),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                final message = _messages[index];
                                return _MessageBubble(message: message);
                              },
                            ),
                  ),
                  // Input area
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111128),
                      border: Border(
                        top: BorderSide(color: const Color(0xFF1A1A2E)),
                      ),
                    ),
                    child: SafeArea(
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15.sp,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Type a message...',
                                hintStyle: TextStyle(
                                  color: const Color(0xFF6B6B80),
                                ),
                                filled: true,
                                fillColor: const Color(0xFF1A1A2E),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24.r),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16.w,
                                  vertical: 12.h,
                                ),
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          GestureDetector(
                            onTap: _isSending ? null : _sendMessage,
                            child: Container(
                              width: 44.w,
                              height: 44.h,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF7931A),
                                shape: BoxShape.circle,
                              ),
                              child:
                                  _isSending
                                      ? Padding(
                                        padding: EdgeInsets.all(12.w),
                                        child: const CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation(
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                      : Icon(
                                        Icons.send,
                                        color: Colors.white,
                                        size: 20.sp,
                                      ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
    );
  }
}

/// Message bubble widget
class _MessageBubble extends StatelessWidget {
  final DirectMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment:
          message.isFromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 8.h,
          left: message.isFromMe ? 48.w : 0,
          right: message.isFromMe ? 0 : 48.w,
        ),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        decoration: BoxDecoration(
          color:
              message.isFromMe
                  ? const Color(0xFFF7931A)
                  : const Color(0xFF2A2A3E),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16.r),
            topRight: Radius.circular(16.r),
            bottomLeft: Radius.circular(message.isFromMe ? 16.r : 4.r),
            bottomRight: Radius.circular(message.isFromMe ? 4.r : 16.r),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.content,
              style: TextStyle(color: Colors.white, fontSize: 14.sp),
            ),
            SizedBox(height: 4.h),
            Text(
              _formatTime(message.timestamp),
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 10.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${time.day}/${time.month}';
  }
}
