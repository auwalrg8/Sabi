import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:sabi_wallet/services/nostr/dm_service.dart';
import 'package:sabi_wallet/services/nostr/feed_aggregator.dart';
import 'package:sabi_wallet/services/nostr/nostr_profile_service.dart';
import 'package:sabi_wallet/features/p2p/presentation/widgets/p2p_offer_preview_widget.dart';
import 'nostr_profile_screen.dart';

/// Provider for DM service
final dmServiceProvider = Provider<DMService>((ref) => DMService());

/// Provider for unread count
final dmUnreadCountProvider = StreamProvider<int>((ref) {
  final dmService = ref.watch(dmServiceProvider);
  return dmService.unreadCountStream;
});

/// DM Inbox Screen - Shows all conversations with FOLLOWS/OTHER tabs (like Primal)
class NostrDMInboxScreen extends ConsumerStatefulWidget {
  const NostrDMInboxScreen({super.key});

  @override
  ConsumerState<NostrDMInboxScreen> createState() => _NostrDMInboxScreenState();
}

class _NostrDMInboxScreenState extends ConsumerState<NostrDMInboxScreen>
    with SingleTickerProviderStateMixin {
  final DMService _dmService = DMService();
  final FeedAggregator _feedAggregator = FeedAggregator();
  bool _isLoading = true;
  List<DMConversation> _allConversations = [];
  List<DMConversation> _followsConversations = [];
  List<DMConversation> _otherConversations = [];
  Set<String> _userFollows = {};
  StreamSubscription? _dmSubscription;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initialize();
  }

  @override
  void dispose() {
    _dmSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    // PHASE 1: Quick initialization - show cached data IMMEDIATELY
    try {
      await _dmService.initializeFast();

      // Show cached conversations right away
      _allConversations = _dmService.conversations;
      _filterConversations();

      if (mounted && _allConversations.isNotEmpty) {
        setState(() => _isLoading = false);
      }

      // Listen for new DMs (works during background fetch too)
      _dmSubscription = _dmService.dmStream.listen((dm) {
        if (mounted) {
          setState(() {
            _allConversations = _dmService.conversations;
            _filterConversations();
          });
        }
      });
    } catch (e) {
      debugPrint('Error in fast init: $e');
    }

    // PHASE 2: Background fetch - load follows and new messages without blocking UI
    _fetchInBackground();
  }

  Future<void> _fetchInBackground() async {
    try {
      // Load user follows in background
      final userPubkey = NostrProfileService().currentPubkey;
      if (userPubkey != null) {
        _feedAggregator.init(userPubkey).then((_) async {
          final follows = await _feedAggregator.fetchFollows(userPubkey);
          _userFollows = follows.toSet();
          if (mounted) {
            setState(() => _filterConversations());
          }
        });
      }

      // Fetch new messages in background with smaller initial batch
      await _dmService.fetchDMHistory(limit: 100);

      // Update UI with new messages
      if (mounted) {
        setState(() {
          _allConversations = _dmService.conversations;
          _filterConversations();
          _isLoading = false;
        });
      }

      // Enrich profiles in background (non-blocking)
      _dmService.enrichWithProfiles().then((_) {
        if (mounted) setState(() {});
      });
    } catch (e) {
      debugPrint('Error in background fetch: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterConversations() {
    _followsConversations =
        _allConversations
            .where((c) => _userFollows.contains(c.pubkey))
            .toList();
    _otherConversations =
        _allConversations
            .where((c) => !_userFollows.contains(c.pubkey))
            .toList();
  }

  Future<void> _refresh() async {
    await _dmService.fetchDMHistory();
    await _dmService.enrichWithProfiles();
    if (mounted) {
      setState(() {
        _allConversations = _dmService.conversations;
        _filterConversations();
      });
    }
  }

  Future<void> _markAllAsRead() async {
    for (final convo in _allConversations) {
      await _dmService.markConversationAsRead(convo.pubkey);
    }
    if (mounted) {
      setState(() {
        _allConversations = _dmService.conversations;
        _filterConversations();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('All messages marked as read'),
          backgroundColor: const Color(0xFF2A2A3E),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  int get _followsUnreadCount =>
      _followsConversations.fold(0, (sum, c) => sum + c.unreadCount);
  int get _otherUnreadCount =>
      _otherConversations.fold(0, (sum, c) => sum + c.unreadCount);

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
        title: Text(
          'Messages',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          // Mark All Read
          if (_dmService.totalUnreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: Text(
                'Mark All Read',
                style: TextStyle(
                  color: const Color(0xFFF7931A),
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(48.h),
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 16.w),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(25.r),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: const Color(0xFFF7931A),
                borderRadius: BorderRadius.circular(25.r),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
              ),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('FOLLOWS'),
                      if (_followsUnreadCount > 0) ...[
                        SizedBox(width: 6.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Text(
                            _followsUnreadCount > 99
                                ? '99+'
                                : _followsUnreadCount.toString(),
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('OTHER'),
                      if (_otherUnreadCount > 0) ...[
                        SizedBox(width: 6.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Text(
                            _otherUnreadCount > 99
                                ? '99+'
                                : _otherUnreadCount.toString(),
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFF7931A)),
              )
              : TabBarView(
                controller: _tabController,
                children: [
                  _buildConversationList(_followsConversations),
                  _buildConversationList(_otherConversations),
                ],
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openNewMessage(),
        backgroundColor: const Color(0xFFF7931A),
        child: Icon(Icons.edit, color: Colors.white, size: 24.sp),
      ),
    );
  }

  Widget _buildConversationList(List<DMConversation> conversations) {
    if (conversations.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: const Color(0xFFF7931A),
      child: ListView.builder(
        padding: EdgeInsets.only(top: 16.h, bottom: 80.h),
        itemCount: conversations.length,
        itemBuilder: (context, index) {
          return _ConversationTile(
            conversation: conversations[index],
            isFollowing: _userFollows.contains(conversations[index].pubkey),
            onTap: () => _openConversation(conversations[index]),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final isFollowsTab = _tabController.index == 0;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24.r),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 48.sp,
              color: const Color(0xFFF7931A).withOpacity(0.6),
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            isFollowsTab ? 'No messages from follows' : 'No other messages',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            isFollowsTab
                ? 'Start a conversation with\npeople you follow'
                : 'Messages from people you\ndon\'t follow will appear here',
            textAlign: TextAlign.center,
            style: TextStyle(color: const Color(0xFF6B6B80), fontSize: 14.sp),
          ),
          if (isFollowsTab) ...[
            SizedBox(height: 24.h),
            ElevatedButton.icon(
              onPressed: () => _openNewMessage(),
              icon: Icon(Icons.edit, size: 18.sp),
              label: const Text('New Message'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF7931A),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24.r),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openConversation(DMConversation conversation) {
    // Mark as read
    _dmService.markConversationAsRead(conversation.pubkey);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => _ConversationScreen(
              pubkey: conversation.pubkey,
              displayName: conversation.displayName,
              avatarUrl: conversation.avatarUrl,
              relatedOfferId: conversation.relatedOfferId,
            ),
      ),
    ).then((_) {
      // Refresh when returning
      setState(() {
        _allConversations = _dmService.conversations;
        _filterConversations();
      });
    });
  }

  void _openNewMessage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _NewMessageScreen()),
    ).then((selectedUser) {
      if (selectedUser != null && selectedUser is Map<String, dynamic>) {
        // Open conversation with selected user
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => _ConversationScreen(
                  pubkey: selectedUser['pubkey'] as String,
                  displayName: selectedUser['displayName'] as String?,
                  avatarUrl: selectedUser['avatarUrl'] as String?,
                ),
          ),
        ).then((_) {
          setState(() {
            _allConversations = _dmService.conversations;
            _filterConversations();
          });
        });
      }
    });
  }
}

/// Conversation tile widget (Primal-style)
class _ConversationTile extends StatelessWidget {
  final DMConversation conversation;
  final bool isFollowing;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.isFollowing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasTradeContext =
        conversation.offerTitle != null || conversation.relatedOfferId != null;
    final hasUnread = conversation.unreadCount > 0;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          children: [
            // Avatar with online indicator style
            Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          hasUnread
                              ? const Color(0xFFF7931A)
                              : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 26.r,
                    backgroundColor: const Color(0xFF2A2A3E),
                    backgroundImage:
                        conversation.avatarUrl != null
                            ? CachedNetworkImageProvider(
                              conversation.avatarUrl!,
                            )
                            : null,
                    child:
                        conversation.avatarUrl == null
                            ? Text(
                              _getInitials(conversation.displayName),
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                            : null,
                  ),
                ),
                // Trade badge
                if (hasTradeContext)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: EdgeInsets.all(4.r),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7931A),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF0C0C1A),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.currency_bitcoin,
                        color: Colors.white,
                        size: 10.sp,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: 14.w),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Name
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                conversation.displayName ??
                                    _formatPubkey(conversation.pubkey),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15.sp,
                                  fontWeight:
                                      hasUnread
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Following badge
                            if (isFollowing) ...[
                              SizedBox(width: 6.w),
                              Icon(
                                Icons.check_circle,
                                color: const Color(0xFFF7931A),
                                size: 14.sp,
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Time
                      Text(
                        _formatTime(conversation.lastMessageAt),
                        style: TextStyle(
                          color:
                              hasUnread
                                  ? const Color(0xFFF7931A)
                                  : const Color(0xFF6B6B80),
                          fontSize: 12.sp,
                          fontWeight:
                              hasUnread ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      // Message preview
                      Expanded(
                        child: Text(
                          conversation.lastMessagePreview ?? '',
                          style: TextStyle(
                            color:
                                hasUnread
                                    ? Colors.white70
                                    : const Color(0xFF6B6B80),
                            fontSize: 13.sp,
                            fontWeight:
                                hasUnread ? FontWeight.w500 : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      // Unread badge
                      if (hasUnread) ...[
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7931A),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Text(
                            conversation.unreadCount > 99
                                ? '99+'
                                : conversation.unreadCount.toString(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  String _formatPubkey(String pubkey) {
    if (pubkey.length > 12) {
      return '${pubkey.substring(0, 8)}...${pubkey.substring(pubkey.length - 4)}';
    }
    return pubkey;
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return 'now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d';
    } else {
      return DateFormat('MMM d').format(time);
    }
  }
}

/// Single conversation screen (Primal-style)
class _ConversationScreen extends StatefulWidget {
  final String pubkey;
  final String? displayName;
  final String? avatarUrl;
  final String? relatedOfferId;

  const _ConversationScreen({
    required this.pubkey,
    this.displayName,
    this.avatarUrl,
    this.relatedOfferId,
  });

  @override
  State<_ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<_ConversationScreen> {
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
    _initializeAndLoadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _dmSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeAndLoadMessages() async {
    setState(() => _isLoading = true);

    // Ensure DM service is initialized
    await _dmService.initialize();

    // Fetch conversation history specifically for this user (includes their relays)
    await _dmService.fetchConversationHistory(widget.pubkey, limit: 500);

    _loadMessages();

    if (mounted) {
      setState(() => _isLoading = false);
      // Scroll to bottom after loading
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _loadMessages() {
    final convo = _dmService.conversations.firstWhere(
      (c) => c.pubkey == widget.pubkey,
      orElse: () => DMConversation(pubkey: widget.pubkey),
    );
    setState(() {
      _messages = List.from(convo.messages);
    });

    // Listen for new messages
    _dmSubscription?.cancel();
    _dmSubscription = _dmService.dmStream.listen((dm) {
      if (dm.senderPubkey == widget.pubkey ||
          dm.recipientPubkey == widget.pubkey) {
        if (mounted) {
          setState(() {
            final convo = _dmService.conversations.firstWhere(
              (c) => c.pubkey == widget.pubkey,
              orElse: () => DMConversation(pubkey: widget.pubkey),
            );
            _messages = List.from(convo.messages);
          });
          _scrollToBottom();
        }
      }
    });
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
    _messageController.clear();

    final success = await _dmService.sendDM(
      recipientPubkey: widget.pubkey,
      message: text,
      relatedOfferId: widget.relatedOfferId,
    );

    if (mounted) {
      setState(() {
        _isSending = false;
        // Refresh messages from DMService after sending
        final convo = _dmService.conversations.firstWhere(
          (c) => c.pubkey == widget.pubkey,
          orElse: () => DMConversation(pubkey: widget.pubkey),
        );
        _messages = List.from(convo.messages);
      });

      if (success) {
        // Scroll to bottom to show new message
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
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
    final displayName = widget.displayName ?? _formatPubkey(widget.pubkey);
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
        title: InkWell(
          onTap: () => _viewProfile(),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18.r,
                backgroundColor: const Color(0xFF2A2A3E),
                backgroundImage:
                    widget.avatarUrl != null
                        ? CachedNetworkImageProvider(widget.avatarUrl!)
                        : null,
                child:
                    widget.avatarUrl == null
                        ? Text(
                          _getInitials(widget.displayName),
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                        : null,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Tap to view profile',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: const Color(0xFF6B6B80),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          // Trade button
          if (widget.relatedOfferId != null)
            IconButton(
              icon: Icon(
                Icons.currency_bitcoin,
                color: const Color(0xFFF7931A),
                size: 22.sp,
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Trade feature coming soon')),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Trade context banner
          if (widget.relatedOfferId != null)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFF7931A).withOpacity(0.15),
                    const Color(0xFFF7931A).withOpacity(0.05),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(6.r),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7931A).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(
                      Icons.handshake,
                      color: const Color(0xFFF7931A),
                      size: 16.sp,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      'P2P Trade Conversation',
                      style: TextStyle(
                        color: const Color(0xFFF7931A),
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Messages
          Expanded(
            child:
                _isLoading
                    ? Center(
                      child: CircularProgressIndicator(
                        color: const Color(0xFFF7931A),
                      ),
                    )
                    : _messages.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(20.r),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A2E),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.waving_hand,
                              size: 36.sp,
                              color: const Color(0xFFF7931A),
                            ),
                          ),
                          SizedBox(height: 16.h),
                          Text(
                            'Say hello to $displayName!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Start the conversation',
                            style: TextStyle(
                              color: const Color(0xFF6B6B80),
                              fontSize: 13.sp,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final showDate =
                            index == 0 ||
                            !_isSameDay(
                              _messages[index - 1].timestamp,
                              msg.timestamp,
                            );
                        final showTime =
                            index == _messages.length - 1 ||
                            _messages[index + 1].isFromMe != msg.isFromMe ||
                            _messages[index + 1].timestamp
                                    .difference(msg.timestamp)
                                    .inMinutes >
                                5;
                        return Column(
                          children: [
                            if (showDate)
                              Container(
                                margin: EdgeInsets.symmetric(vertical: 16.h),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 6.h,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1A2E),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Text(
                                  _formatDate(msg.timestamp),
                                  style: TextStyle(
                                    color: const Color(0xFF6B6B80),
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            _MessageBubble(message: msg, showTime: showTime),
                          ],
                        );
                      },
                    ),
          ),
          // Input bar (Primal style)
          Container(
            padding: EdgeInsets.fromLTRB(
              12.w,
              10.h,
              12.w,
              MediaQuery.of(context).padding.bottom + 10.h,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF111128),
              border: Border(
                top: BorderSide(color: const Color(0xFF1A1A2E), width: 1),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    constraints: BoxConstraints(maxHeight: 120.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(24.r),
                    ),
                    child: TextField(
                      controller: _messageController,
                      style: TextStyle(color: Colors.white, fontSize: 15.sp),
                      decoration: InputDecoration(
                        hintText: 'Message $displayName',
                        hintStyle: TextStyle(
                          color: const Color(0xFF6B6B80),
                          fontSize: 15.sp,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 18.w,
                          vertical: 12.h,
                        ),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.newline,
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                GestureDetector(
                  onTap: _isSending ? null : _sendMessage,
                  child: Container(
                    width: 46.w,
                    height: 46.h,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF7931A), Color(0xFFE8A838)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF7931A).withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child:
                        _isSending
                            ? Padding(
                              padding: EdgeInsets.all(13.r),
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : Icon(
                              Icons.arrow_upward,
                              color: Colors.white,
                              size: 22.sp,
                            ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _viewProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NostrProfileScreen(pubkey: widget.pubkey),
      ),
    );
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  String _formatPubkey(String pubkey) {
    if (pubkey.length > 12) {
      return '${pubkey.substring(0, 8)}...${pubkey.substring(pubkey.length - 4)}';
    }
    return pubkey;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) {
      return 'Today';
    } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    } else {
      return DateFormat('EEEE, MMM d').format(date);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

/// Message bubble widget (Primal-style with pink sent bubbles)
class _MessageBubble extends StatelessWidget {
  final DirectMessage message;
  final bool showTime;

  const _MessageBubble({required this.message, this.showTime = true});

  @override
  Widget build(BuildContext context) {
    // Check if message contains P2P offer reference
    final hasP2PReference = containsP2POfferReference(message.content);

    return Padding(
      padding: EdgeInsets.only(bottom: showTime ? 8.h : 3.h),
      child: Column(
        crossAxisAlignment:
            message.isFromMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
        children: [
          Align(
            alignment:
                message.isFromMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              child:
                  hasP2PReference
                      ? _buildMessageWithP2PPreview(context)
                      : _buildRegularMessage(context),
            ),
          ),
          if (showTime)
            Padding(
              padding: EdgeInsets.only(
                top: 4.h,
                left: message.isFromMe ? 0 : 4.w,
                right: message.isFromMe ? 4.w : 0,
              ),
              child: Text(
                DateFormat('h:mm a').format(message.timestamp),
                style: TextStyle(
                  color: const Color(0xFF6B6B80),
                  fontSize: 10.sp,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRegularMessage(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      decoration: BoxDecoration(
        gradient:
            message.isFromMe
                ? const LinearGradient(
                  colors: [Color(0xFFF7931A), Color(0xFFE8A838)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
                : null,
        color: message.isFromMe ? null : const Color(0xFF1F1F35),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(18.r),
          topRight: Radius.circular(18.r),
          bottomLeft: Radius.circular(message.isFromMe ? 18.r : 4.r),
          bottomRight: Radius.circular(message.isFromMe ? 4.r : 18.r),
        ),
      ),
      child: Text(
        message.content,
        style: TextStyle(color: Colors.white, fontSize: 15.sp, height: 1.3),
      ),
    );
  }

  Widget _buildMessageWithP2PPreview(BuildContext context) {
    // Extract the naddr references
    final naddrRefs = extractNaddrReferences(message.content);

    // Get the text parts (before and after the reference)
    String textContent = message.content;
    for (final ref in naddrRefs) {
      textContent = textContent.replaceAll(ref, '');
    }
    textContent = textContent.trim();

    return Column(
      crossAxisAlignment:
          message.isFromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        // Show text content if any
        if (textContent.isNotEmpty)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            margin: EdgeInsets.only(bottom: 6.h),
            decoration: BoxDecoration(
              gradient:
                  message.isFromMe
                      ? const LinearGradient(
                        colors: [Color(0xFFF7931A), Color(0xFFE8A838)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                      : null,
              color: message.isFromMe ? null : const Color(0xFF1F1F35),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18.r),
                topRight: Radius.circular(18.r),
                bottomLeft: Radius.circular(18.r),
                bottomRight: Radius.circular(18.r),
              ),
            ),
            child: Text(
              textContent,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15.sp,
                height: 1.3,
              ),
            ),
          ),
        // Show P2P offer previews
        ...naddrRefs.map(
          (ref) => P2POfferPreviewWidget(
            naddrReference: ref,
            compact: true,
            onTap: () {
              // Navigate to offer detail
              // This will be handled by the widget
            },
          ),
        ),
      ],
    );
  }
}

/// New Message Screen - Search and select user to message
class _NewMessageScreen extends StatefulWidget {
  const _NewMessageScreen();

  @override
  State<_NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends State<_NewMessageScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FeedAggregator _feedAggregator = FeedAggregator();
  final NostrProfileService _profileService = NostrProfileService();

  // Static cache to persist across screen rebuilds
  static List<Map<String, dynamic>>? _cachedFollowsList;
  static DateTime? _cacheTime;
  static const _cacheDuration = Duration(minutes: 5);

  List<Map<String, dynamic>> _followsList = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadFollows();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFollows() async {
    // Check cache first
    if (_cachedFollowsList != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheDuration) {
      setState(() {
        _followsList = _cachedFollowsList!;
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userPubkey = _profileService.currentPubkey;
      if (userPubkey != null) {
        await _feedAggregator.init(userPubkey);
        final follows = await _feedAggregator.fetchFollows(userPubkey);

        // Fetch profiles in parallel batches for speed
        final profiles = <Map<String, dynamic>>[];
        final pubkeysToFetch = follows.take(100).toList();

        // Process in batches of 10 for parallel fetching
        for (var i = 0; i < pubkeysToFetch.length; i += 10) {
          final batch = pubkeysToFetch.skip(i).take(10).toList();
          final batchResults = await Future.wait(
            batch.map((pubkey) async {
              final profile = await _profileService.fetchProfile(pubkey);
              if (profile != null) {
                return {
                  'pubkey': pubkey,
                  'displayName':
                      profile.displayName ??
                      profile.name ??
                      _formatPubkey(pubkey),
                  'avatarUrl': profile.picture,
                  'nip05': profile.nip05,
                };
              } else {
                return {
                  'pubkey': pubkey,
                  'displayName': _formatPubkey(pubkey),
                  'avatarUrl': null,
                  'nip05': null,
                };
              }
            }),
          );
          profiles.addAll(batchResults);

          // Update UI progressively
          if (mounted && i == 0) {
            setState(() {
              _followsList = List.from(profiles);
              _isLoading = false; // Show results immediately
            });
          }
        }

        // Cache the results
        _cachedFollowsList = profiles;
        _cacheTime = DateTime.now();

        if (mounted) {
          setState(() {
            _followsList = profiles;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading follows: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchQuery = '';
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _searchQuery = query;
      _isSearching = true;
    });

    // Check if it's an npub
    if (query.startsWith('npub1') && query.length >= 63) {
      try {
        // Convert npub to hex
        final hexPubkey = NostrProfileService.npubToHex(query);
        if (hexPubkey != null) {
          final profile = await _profileService.fetchProfile(hexPubkey);
          setState(() {
            _searchResults = [
              {
                'pubkey': hexPubkey,
                'displayName':
                    profile?.displayName ??
                    profile?.name ??
                    _formatPubkey(hexPubkey),
                'avatarUrl': profile?.picture,
                'nip05': profile?.nip05,
              },
            ];
            _isSearching = false;
          });
          return;
        }
      } catch (e) {
        debugPrint('Invalid npub: $e');
      }
    }

    // Filter follows by name
    final filtered =
        _followsList.where((user) {
          final name = (user['displayName'] as String?)?.toLowerCase() ?? '';
          final nip05 = (user['nip05'] as String?)?.toLowerCase() ?? '';
          final q = query.toLowerCase();
          return name.contains(q) || nip05.contains(q);
        }).toList();

    setState(() {
      _searchResults = filtered;
      _isSearching = false;
    });
  }

  void _selectUser(Map<String, dynamic> user) {
    Navigator.pop(context, user);
  }

  @override
  Widget build(BuildContext context) {
    final displayList = _searchQuery.isEmpty ? _followsList : _searchResults;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C0C1A),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.white, size: 24.sp),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'New Message',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: EdgeInsets.all(16.w),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: Colors.white, fontSize: 15.sp),
              decoration: InputDecoration(
                hintText: 'Search by name or paste npub...',
                hintStyle: TextStyle(
                  color: const Color(0xFF6B6B80),
                  fontSize: 15.sp,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: const Color(0xFF6B6B80),
                  size: 22.sp,
                ),
                suffixIcon:
                    _searchController.text.isNotEmpty
                        ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: const Color(0xFF6B6B80),
                            size: 20.sp,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            _search('');
                          },
                        )
                        : null,
                filled: true,
                fillColor: const Color(0xFF1A1A2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.r),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 14.h,
                ),
              ),
              onChanged: _search,
            ),
          ),
          // Section header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                Text(
                  _searchQuery.isEmpty ? 'People You Follow' : 'Results',
                  style: TextStyle(
                    color: const Color(0xFF6B6B80),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  '(${displayList.length})',
                  style: TextStyle(
                    color: const Color(0xFFF7931A),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8.h),
          // User list
          Expanded(
            child:
                _isLoading || _isSearching
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFF7931A),
                      ),
                    )
                    : displayList.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchQuery.isEmpty
                                ? Icons.people_outline
                                : Icons.search_off,
                            size: 48.sp,
                            color: const Color(0xFF6B6B80),
                          ),
                          SizedBox(height: 12.h),
                          Text(
                            _searchQuery.isEmpty
                                ? 'No follows yet'
                                : 'No users found',
                            style: TextStyle(
                              color: const Color(0xFF6B6B80),
                              fontSize: 14.sp,
                            ),
                          ),
                          if (_searchQuery.isEmpty) ...[
                            SizedBox(height: 8.h),
                            Text(
                              'You can paste an npub to message anyone',
                              style: TextStyle(
                                color: const Color(0xFF4A4A5E),
                                fontSize: 12.sp,
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      itemCount: displayList.length,
                      itemBuilder: (context, index) {
                        final user = displayList[index];
                        return _UserTile(
                          displayName: user['displayName'] as String,
                          avatarUrl: user['avatarUrl'] as String?,
                          nip05: user['nip05'] as String?,
                          onTap: () => _selectUser(user),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  String _formatPubkey(String pubkey) {
    if (pubkey.length > 12) {
      return '${pubkey.substring(0, 8)}...${pubkey.substring(pubkey.length - 4)}';
    }
    return pubkey;
  }
}

/// User tile for new message selection
class _UserTile extends StatelessWidget {
  final String displayName;
  final String? avatarUrl;
  final String? nip05;
  final VoidCallback onTap;

  const _UserTile({
    required this.displayName,
    this.avatarUrl,
    this.nip05,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24.r,
              backgroundColor: const Color(0xFF2A2A3E),
              backgroundImage:
                  avatarUrl != null
                      ? CachedNetworkImageProvider(avatarUrl!)
                      : null,
              child:
                  avatarUrl == null
                      ? Text(
                        _getInitials(displayName),
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                      : null,
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (nip05 != null) ...[
                    SizedBox(height: 2.h),
                    Row(
                      children: [
                        Icon(
                          Icons.verified,
                          color: const Color(0xFFF7931A),
                          size: 12.sp,
                        ),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: Text(
                            nip05!,
                            style: TextStyle(
                              color: const Color(0xFF6B6B80),
                              fontSize: 12.sp,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: const Color(0xFF6B6B80),
              size: 20.sp,
            ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }
}
