import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/services/nostr/dm_service.dart';
import 'package:sabi_wallet/services/nostr/nostr_profile_service.dart';

/// P2P Offer Messages Screen - Per-offer DM threads
/// Shows all conversations related to a specific P2P offer
class P2POfferMessagesScreen extends ConsumerStatefulWidget {
  final String offerId;
  final String offerTitle;

  const P2POfferMessagesScreen({
    super.key,
    required this.offerId,
    required this.offerTitle,
  });

  @override
  ConsumerState<P2POfferMessagesScreen> createState() =>
      _P2POfferMessagesScreenState();
}

class _P2POfferMessagesScreenState
    extends ConsumerState<P2POfferMessagesScreen> {
  final DMService _dmService = DMService();
  final NostrProfileService _profileService = NostrProfileService();
  List<DMConversation> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOfferConversations();
  }

  Future<void> _loadOfferConversations() async {
    setState(() => _isLoading = true);

    // Initialize DM service if needed
    await _dmService.initialize();
    await _dmService.fetchDMHistory();

    // Filter conversations for this offer
    final allConversations = _dmService.conversations;
    final offerConversations =
        allConversations.where((c) {
          // Check if any message has this offer ID in tags
          for (final msg in c.messages) {
            for (final tag in msg.tags) {
              if (tag.length >= 2 &&
                  (tag[0] == 'e' || tag[0] == 'offer') &&
                  tag[1] == widget.offerId) {
                return true;
              }
            }
          }
          // Also check the conversation's relatedOfferId
          return c.relatedOfferId == widget.offerId;
        }).toList();

    // Fetch profile info for each conversation
    for (final convo in offerConversations) {
      if (convo.displayName == null) {
        final profile = await _profileService.fetchProfile(convo.pubkey);
        if (profile != null) {
          convo.displayName = profile.displayName ?? profile.name;
          convo.avatarUrl = profile.picture;
        }
      }
    }

    setState(() {
      _conversations = offerConversations;
      _isLoading = false;
    });
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Messages',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Text(
              widget.offerTitle,
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.orange),
              )
              : _conversations.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                onRefresh: _loadOfferConversations,
                color: Colors.orange,
                child: ListView.builder(
                  padding: EdgeInsets.all(16.w),
                  itemCount: _conversations.length,
                  itemBuilder: (context, index) {
                    final convo = _conversations[index];
                    return _ConversationTile(
                      conversation: convo,
                      onTap: () => _openConversation(convo),
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
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF111128),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            'No messages yet',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Inquiries for this offer will appear here',
            style: TextStyle(color: Colors.grey[600], fontSize: 14.sp),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _openConversation(DMConversation convo) {
    // Mark as read
    _dmService.markConversationAsRead(convo.pubkey);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) =>
                _OfferChatScreen(conversation: convo, offerId: widget.offerId),
      ),
    ).then((_) => _loadOfferConversations()); // Refresh on return
  }
}

/// Conversation Tile Widget
class _ConversationTile extends StatelessWidget {
  final DMConversation conversation;
  final VoidCallback onTap;

  const _ConversationTile({required this.conversation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color:
            conversation.unreadCount > 0
                ? const Color(0xFF111128)
                : const Color(0xFF111128).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12.r),
        border:
            conversation.unreadCount > 0
                ? Border.all(color: Colors.orange.withOpacity(0.3))
                : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12.r),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey[800],
                  backgroundImage:
                      conversation.avatarUrl != null
                          ? NetworkImage(conversation.avatarUrl!)
                          : null,
                  child:
                      conversation.avatarUrl == null
                          ? Text(
                            _getInitials(conversation.displayName),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                          : null,
                ),
                SizedBox(width: 12.w),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conversation.displayName ??
                                  _truncatePubkey(conversation.pubkey),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15.sp,
                                fontWeight:
                                    conversation.unreadCount > 0
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            _formatTimeAgo(conversation.lastMessageAt),
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12.sp,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conversation.lastMessagePreview ?? 'No messages',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 13.sp,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (conversation.unreadCount > 0)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Text(
                                '${conversation.unreadCount}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Icon(Icons.chevron_right, color: Colors.grey[600]),
              ],
            ),
          ),
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
    return name.substring(0, 1).toUpperCase();
  }

  String _truncatePubkey(String pubkey) {
    if (pubkey.length <= 12) return pubkey;
    return '${pubkey.substring(0, 6)}...${pubkey.substring(pubkey.length - 6)}';
  }

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

/// Individual Offer Chat Screen
class _OfferChatScreen extends StatefulWidget {
  final DMConversation conversation;
  final String offerId;

  const _OfferChatScreen({required this.conversation, required this.offerId});

  @override
  State<_OfferChatScreen> createState() => _OfferChatScreenState();
}

class _OfferChatScreenState extends State<_OfferChatScreen> {
  final DMService _dmService = DMService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<DirectMessage> _messages = [];
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _listenForNewMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadMessages() {
    // Filter messages for this offer conversation
    final messages =
        widget.conversation.messages.where((m) {
          // Check if message has this offer in tags
          for (final tag in m.tags) {
            if (tag.length >= 2 &&
                (tag[0] == 'e' || tag[0] == 'offer') &&
                tag[1] == widget.offerId) {
              return true;
            }
          }
          // Include all messages from this conversation if related to offer
          return true;
        }).toList();

    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    setState(() => _messages = messages);

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _listenForNewMessages() {
    _dmService.dmStream.listen((message) {
      if (message.senderPubkey == widget.conversation.pubkey ||
          message.recipientPubkey == widget.conversation.pubkey) {
        _loadMessages();
      }
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() => _isSending = true);
    _messageController.clear();

    final success = await _dmService.sendDM(
      recipientPubkey: widget.conversation.pubkey,
      message: message,
      relatedOfferId: widget.offerId,
    );

    setState(() => _isSending = false);

    if (success) {
      _loadMessages();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message'),
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
              radius: 18,
              backgroundColor: Colors.grey[800],
              backgroundImage:
                  widget.conversation.avatarUrl != null
                      ? NetworkImage(widget.conversation.avatarUrl!)
                      : null,
              child:
                  widget.conversation.avatarUrl == null
                      ? Icon(Icons.person, color: Colors.grey, size: 18)
                      : null,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                widget.conversation.displayName ??
                    _truncatePubkey(widget.conversation.pubkey),
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Offer Context Banner
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            color: Colors.orange.withOpacity(0.1),
            child: Row(
              children: [
                Icon(Icons.local_offer, color: Colors.orange, size: 16),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'Regarding: ${widget.offerId.length >= 16 ? '${widget.offerId.substring(0, 16)}...' : widget.offerId}',
                    style: TextStyle(color: Colors.orange, fontSize: 12.sp),
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
                        'No messages yet',
                        style: TextStyle(color: Colors.grey[600]),
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

          // Input
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: const Color(0xFF111128),
              border: Border(
                top: BorderSide(color: Colors.grey[800]!, width: 0.5),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A2E),
                        borderRadius: BorderRadius.circular(24.r),
                      ),
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon:
                          _isSending
                              ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : Icon(Icons.send, color: Colors.white),
                      onPressed: _isSending ? null : _sendMessage,
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

  String _truncatePubkey(String pubkey) {
    if (pubkey.length <= 12) return pubkey;
    return '${pubkey.substring(0, 6)}...${pubkey.substring(pubkey.length - 6)}';
  }
}

/// Message Bubble Widget
class _MessageBubble extends StatelessWidget {
  final DirectMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        mainAxisAlignment:
            message.isFromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: message.isFromMe ? Colors.orange : const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16.r),
                topRight: Radius.circular(16.r),
                bottomLeft: Radius.circular(message.isFromMe ? 16.r : 4.r),
                bottomRight: Radius.circular(message.isFromMe ? 4.r : 16.r),
              ),
            ),
            child: Column(
              crossAxisAlignment:
                  message.isFromMe
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
              children: [
                Text(
                  message.content,
                  style: TextStyle(color: Colors.white, fontSize: 14.sp),
                ),
                SizedBox(height: 4.h),
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(
                    color:
                        message.isFromMe
                            ? Colors.white.withOpacity(0.7)
                            : Colors.grey[500],
                    fontSize: 10.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
