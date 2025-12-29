import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../services/nostr/dm_service.dart';
import 'nostr_profile_screen.dart';

/// Provider for DM service
final dmServiceProvider = Provider<DMService>((ref) => DMService());

/// Provider for unread count
final dmUnreadCountProvider = StreamProvider<int>((ref) {
  final dmService = ref.watch(dmServiceProvider);
  return dmService.unreadCountStream;
});

/// DM Inbox Screen - Shows all conversations
class NostrDMInboxScreen extends ConsumerStatefulWidget {
  const NostrDMInboxScreen({super.key});

  @override
  ConsumerState<NostrDMInboxScreen> createState() => _NostrDMInboxScreenState();
}

class _NostrDMInboxScreenState extends ConsumerState<NostrDMInboxScreen> {
  final DMService _dmService = DMService();
  bool _isLoading = true;
  List<DMConversation> _conversations = [];
  StreamSubscription? _dmSubscription;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _dmSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    setState(() => _isLoading = true);

    try {
      await _dmService.initialize();
      await _dmService.fetchDMHistory();
      await _dmService.enrichWithProfiles();

      _conversations = _dmService.conversations;

      // Listen for new DMs
      _dmSubscription = _dmService.dmStream.listen((dm) {
        if (mounted) {
          setState(() {
            _conversations = _dmService.conversations;
          });
        }
      });
    } catch (e) {
      debugPrint('Error loading DMs: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refresh() async {
    await _dmService.fetchDMHistory();
    await _dmService.enrichWithProfiles();
    if (mounted) {
      setState(() {
        _conversations = _dmService.conversations;
      });
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
        title: Text(
          'Messages',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white70, size: 22.sp),
            onPressed: _refresh,
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFF7931A)),
              )
              : _conversations.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                onRefresh: _refresh,
                color: const Color(0xFFF7931A),
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  itemCount: _conversations.length,
                  itemBuilder: (context, index) {
                    return _ConversationTile(
                      conversation: _conversations[index],
                      onTap: () => _openConversation(_conversations[index]),
                    );
                  },
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
            Icons.message_outlined,
            size: 64.sp,
            color: const Color(0xFF6B6B80),
          ),
          SizedBox(height: 16.h),
          Text(
            'No messages yet',
            style: TextStyle(
              color: const Color(0xFFA1A1B2),
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Messages from other Nostr users\nwill appear here',
            textAlign: TextAlign.center,
            style: TextStyle(color: const Color(0xFF6B6B80), fontSize: 14.sp),
          ),
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
        _conversations = _dmService.conversations;
      });
    });
  }
}

/// Conversation tile widget
class _ConversationTile extends StatelessWidget {
  final DMConversation conversation;
  final VoidCallback onTap;

  const _ConversationTile({required this.conversation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasTradeContext =
        conversation.offerTitle != null || conversation.relatedOfferId != null;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: const Color(0xFF1A1A2E), width: 1),
          ),
        ),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 24.r,
                  backgroundColor: const Color(0xFF2A2A3E),
                  backgroundImage:
                      conversation.avatarUrl != null
                          ? CachedNetworkImageProvider(conversation.avatarUrl!)
                          : null,
                  child:
                      conversation.avatarUrl == null
                          ? Icon(
                            Icons.person,
                            color: Colors.white54,
                            size: 24.sp,
                          )
                          : null,
                ),
                // Unread badge
                if (conversation.unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: EdgeInsets.all(4.r),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF7931A),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        conversation.unreadCount > 9
                            ? '9+'
                            : conversation.unreadCount.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: 12.w),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          conversation.displayName ??
                              _formatPubkey(conversation.pubkey),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15.sp,
                            fontWeight:
                                conversation.unreadCount > 0
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatTime(conversation.lastMessageAt),
                        style: TextStyle(
                          color:
                              conversation.unreadCount > 0
                                  ? const Color(0xFFF7931A)
                                  : const Color(0xFF6B6B80),
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      // Trade context badge
                      if (hasTradeContext)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.h,
                          ),
                          margin: EdgeInsets.only(right: 6.w),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7931A).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.currency_bitcoin,
                                color: const Color(0xFFF7931A),
                                size: 10.sp,
                              ),
                              SizedBox(width: 2.w),
                              Text(
                                'Trade',
                                style: TextStyle(
                                  color: const Color(0xFFF7931A),
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: Text(
                          conversation.lastMessagePreview ?? '',
                          style: TextStyle(
                            color:
                                conversation.unreadCount > 0
                                    ? Colors.white70
                                    : const Color(0xFF6B6B80),
                            fontSize: 13.sp,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Chevron
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

  String _formatPubkey(String pubkey) {
    if (pubkey.length > 12) {
      return '${pubkey.substring(0, 8)}...${pubkey.substring(pubkey.length - 4)}';
    }
    return pubkey;
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 60) {
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

/// Single conversation screen
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
  StreamSubscription? _dmSubscription;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _dmSubscription?.cancel();
    super.dispose();
  }

  void _loadMessages() {
    final convo = _dmService.conversations.firstWhere(
      (c) => c.pubkey == widget.pubkey,
      orElse: () => DMConversation(pubkey: widget.pubkey),
    );
    setState(() {
      _messages = convo.messages;
    });

    // Listen for new messages
    _dmSubscription = _dmService.dmStream.listen((dm) {
      if (dm.senderPubkey == widget.pubkey ||
          dm.recipientPubkey == widget.pubkey) {
        if (mounted) {
          setState(() {
            _messages =
                _dmService.conversations
                    .firstWhere(
                      (c) => c.pubkey == widget.pubkey,
                      orElse: () => DMConversation(pubkey: widget.pubkey),
                    )
                    .messages;
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

    final success = await _dmService.sendDM(
      recipientPubkey: widget.pubkey,
      message: text,
      relatedOfferId: widget.relatedOfferId,
    );

    if (mounted) {
      setState(() => _isSending = false);
      if (success) {
        _messageController.clear();
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
        title: InkWell(
          onTap: () => _viewProfile(),
          child: Row(
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
                  widget.displayName ?? _formatPubkey(widget.pubkey),
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
        actions: [
          // Start trade button
          if (widget.relatedOfferId != null)
            IconButton(
              icon: Icon(
                Icons.currency_bitcoin,
                color: const Color(0xFFF7931A),
                size: 22.sp,
              ),
              onPressed: () {
                // TODO: Navigate to trade with this user
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Trade feature coming soon')),
                );
              },
            ),
          IconButton(
            icon: Icon(
              Icons.person_outline,
              color: Colors.white70,
              size: 22.sp,
            ),
            onPressed: _viewProfile,
          ),
        ],
      ),
      body: Column(
        children: [
          // Trade context banner
          if (widget.relatedOfferId != null)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              color: const Color(0xFFF7931A).withOpacity(0.1),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: const Color(0xFFF7931A),
                    size: 16.sp,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'This conversation is about a P2P trade offer',
                      style: TextStyle(
                        color: const Color(0xFFF7931A),
                        fontSize: 12.sp,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      // TODO: Open offer details
                    },
                    child: Text(
                      'View Offer',
                      style: TextStyle(
                        color: const Color(0xFFF7931A),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Messages
          Expanded(
            child:
                _messages.isEmpty
                    ? Center(
                      child: Text(
                        'No messages yet.\nSay hello! 👋',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFF6B6B80),
                          fontSize: 14.sp,
                        ),
                      ),
                    )
                    : ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.all(16.w),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final showDate =
                            index == 0 ||
                            !_isSameDay(
                              _messages[index - 1].timestamp,
                              msg.timestamp,
                            );
                        return Column(
                          children: [
                            if (showDate)
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                child: Text(
                                  _formatDate(msg.timestamp),
                                  style: TextStyle(
                                    color: const Color(0xFF6B6B80),
                                    fontSize: 12.sp,
                                  ),
                                ),
                              ),
                            _MessageBubble(message: msg),
                          ],
                        );
                      },
                    ),
          ),
          // Input
          Container(
            padding: EdgeInsets.fromLTRB(
              16.w,
              8.h,
              16.w,
              MediaQuery.of(context).padding.bottom + 8.h,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF111128),
              border: Border(top: BorderSide(color: const Color(0xFF1A1A2E))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: TextStyle(color: Colors.white, fontSize: 14.sp),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(
                        color: const Color(0xFF6B6B80),
                        fontSize: 14.sp,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24.r),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF1A1A2E),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                SizedBox(width: 8.w),
                GestureDetector(
                  onTap: _isSending ? null : _sendMessage,
                  child: Container(
                    width: 44.w,
                    height: 44.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7931A),
                      shape: BoxShape.circle,
                    ),
                    child:
                        _isSending
                            ? Padding(
                              padding: EdgeInsets.all(12.r),
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
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
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
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
                  : const Color(0xFF1A1A2E),
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
              style: TextStyle(
                color: message.isFromMe ? Colors.white : Colors.white,
                fontSize: 14.sp,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              DateFormat('HH:mm').format(message.timestamp),
              style: TextStyle(
                color:
                    message.isFromMe ? Colors.white70 : const Color(0xFF6B6B80),
                fontSize: 10.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
