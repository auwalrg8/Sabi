import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_confetti/flutter_confetti.dart';
import 'nostr_service.dart';
import 'nostr_zap_slider.dart';

/// Nostr feed screen displaying user's posts and incoming zaps
class NostrFeedScreen extends StatefulWidget {
  const NostrFeedScreen({Key? key}) : super(key: key);

  @override
  State<NostrFeedScreen> createState() => _NostrFeedScreenState();
}

class _NostrFeedScreenState extends State<NostrFeedScreen> {
  List<NostrPost> _posts = [];
  bool _isLoading = true;
  String? _userNpub;
  Map<String, int> _zapCounts = {};

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    try {
      final npub = await NostrService.getNpub();
      if (npub == null) {
        setState(() => _isLoading = false);
        return;
      }

      setState(() => _userNpub = npub);

      // Generate mock posts for demo
      // In production, these would come from Nostr relays
      _posts = _generateMockPosts();

      // Subscribe to incoming zaps
      NostrService.subscribeToZaps(npub).listen(
        (zapData) {
          if (mounted) {
            _handleIncomingZap(zapData);
          }
        },
        onError: (e) {
          print('❌ Error subscribing to zaps: $e');
        },
      );

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('❌ Error loading feed: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<NostrPost> _generateMockPosts() {
    return [
      NostrPost(
        id: '1',
        author: 'user1',
        content: 'Just launched my new Bitcoin project! 🚀',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        zapCount: 15,
      ),
      NostrPost(
        id: '2',
        author: 'user2',
        content: 'The future of money is decentralized.',
        timestamp: DateTime.now().subtract(const Duration(hours: 5)),
        zapCount: 32,
      ),
      NostrPost(
        id: '3',
        author: 'user3',
        content: 'Building in public on Lightning Network ⚡',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        zapCount: 8,
      ),
    ];
  }

  void _handleIncomingZap(Map<String, dynamic> zapData) {
    final satoshis = zapData['satoshis'] ?? 0;
    final message = zapData['message'] ?? '';

    // Show confetti animation
    Confetti.launch(
      context,
      options: const ConfettiOptions(
        particleCount: 50,
        spread: 360,
        y: 0.5,
      ),
    );

    // Show notification
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Zapped! ⚡ $satoshis sats${message.isNotEmpty ? ' - $message' : ''}'),
        backgroundColor: const Color(0xFF00FFB2),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _handleZapPost(NostrPost post, int satoshis) async {
    try {
      if (_userNpub != null) {
        await NostrService.publishZapEvent(
          targetNpub: _userNpub!,
          satoshis: satoshis,
          message: 'Zapped from Sabi Wallet',
        );

        // Update local zap count
        setState(() {
          _zapCounts[post.id] = (_zapCounts[post.id] ?? 0) + 1;
        });

        // Show confetti
        Confetti.launch(
          context,
          options: const ConfettiOptions(
            particleCount: 50,
            spread: 360,
            y: 0.5,
          ),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C0C1A),
        elevation: 0,
        title: const Text(
          'Nostr Feed ⚡',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFFF7931A)),
              ),
            )
          : _userNpub == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_off,
                        size: 64.sp,
                        color: const Color(0xFFA1A1B2),
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        'Nostr not configured',
                        style: TextStyle(
                          color: const Color(0xFFA1A1B2),
                          fontSize: 14.sp,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadFeed,
                  backgroundColor: const Color(0xFF111128),
                  color: const Color(0xFFF7931A),
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    itemCount: _posts.length,
                    itemBuilder: (context, index) {
                      final post = _posts[index];
                      final zapCount = _zapCounts[post.id] ?? post.zapCount;

                      return Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 8.h,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF111128),
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          padding: EdgeInsets.all(16.w),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header: Avatar + Name + Time
                              Row(
                                children: [
                                  // Avatar
                                  Container(
                                    width: 40.w,
                                    height: 40.h,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF7931A),
                                      borderRadius: BorderRadius.circular(20.r),
                                    ),
                                    child: Center(
                                      child: Text(
                                        post.author[0].toUpperCase(),
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
                                          post.author,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 13.sp,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          _formatTime(post.timestamp),
                                          style: TextStyle(
                                            color: const Color(0xFFA1A1B2),
                                            fontSize: 11.sp,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Zap count display
                                  if (zapCount > 0)
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8.w,
                                        vertical: 4.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF7931A).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6.r),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '⚡',
                                            style: TextStyle(fontSize: 12.sp),
                                          ),
                                          SizedBox(width: 4.w),
                                          Text(
                                            '$zapCount',
                                            style: TextStyle(
                                              color: const Color(0xFFF7931A),
                                              fontSize: 11.sp,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(height: 12.h),

                              // Content
                              Text(
                                post.content,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.sp,
                                  height: 1.5,
                                ),
                              ),
                              SizedBox(height: 12.h),

                              // Zap slider
                              NostrZapSlider(
                                userName: post.author,
                                onZap: (satoshis) {
                                  _handleZapPost(post, satoshis);
                                },
                                onConfetti: () {
                                  Confetti.launch(
                                    context,
                                    options: const ConfettiOptions(
                                      particleCount: 50,
                                      spread: 360,
                                      y: 0.5,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${time.month}/${time.day}/${time.year}';
    }
  }
}

/// Model for Nostr posts
class NostrPost {
  final String id;
  final String author;
  final String content;
  final DateTime timestamp;
  final int zapCount;

  NostrPost({
    required this.id,
    required this.author,
    required this.content,
    required this.timestamp,
    required this.zapCount,
  });
}
