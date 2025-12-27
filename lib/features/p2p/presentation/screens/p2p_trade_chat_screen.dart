import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:sabi_wallet/features/p2p/data/p2p_offer_model.dart';
import 'package:sabi_wallet/features/p2p/data/trade_model.dart';
import 'package:sabi_wallet/features/p2p/data/models/social_profile_model.dart';
import 'package:sabi_wallet/features/p2p/presentation/screens/p2p_success_screen.dart';
import 'package:sabi_wallet/features/p2p/presentation/widgets/social_profile_widget.dart';
import 'package:sabi_wallet/features/p2p/services/p2p_trade_service.dart';
import 'package:sabi_wallet/features/p2p/utils/p2p_logger.dart';

/// P2P Trade Chat Screen with escrow timer
class P2PTradeChatScreen extends ConsumerStatefulWidget {
  final P2POfferModel offer;
  final double tradeAmount;
  final double receiveSats;

  const P2PTradeChatScreen({
    super.key,
    required this.offer,
    required this.tradeAmount,
    required this.receiveSats,
  });

  @override
  ConsumerState<P2PTradeChatScreen> createState() => _P2PTradeChatScreenState();
}

class _P2PTradeChatScreenState extends ConsumerState<P2PTradeChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final formatter = NumberFormat('#,###');

  TradeStatus _tradeStatus = TradeStatus.awaitingPayment;
  int _escrowTimeLeft = kTradeTimerSeconds; // 4 minutes - protects against BTC price volatility
  Timer? _escrowTimer;
  final List<_ChatMessage> _messages = [];
  bool _isTyping = false;
  File? _selectedProof; // Store selected proof image
  
  // Profile sharing state
  ProfileShareRequest? _profileShareRequest;
  List<SocialProfile>? _sharedCounterpartyProfiles;
  bool _hasRequestedProfileShare = false;

  @override
  void initState() {
    super.initState();
    _startEscrowTimer();
    P2PLogger.info('Trade', 'Trade chat started', metadata: {
      'offerId': widget.offer.id,
      'tradeAmount': widget.tradeAmount,
      'receiveSats': widget.receiveSats,
    });
    _addSystemMessage('Trade started. Complete payment within 4 minutes.');
    _addSystemMessage('⚠️ 4-minute window protects against BTC price changes. Act fast!');
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _escrowTimer?.cancel();
    super.dispose();
  }

  void _startEscrowTimer() {
    _escrowTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_escrowTimeLeft > 0) {
        setState(() => _escrowTimeLeft--);
        
        // Add warning messages at specific times
        if (_escrowTimeLeft == kWarning2Min) {
          _addSystemMessage('⏰ 2 minutes remaining! Complete payment now.');
        } else if (_escrowTimeLeft == kWarning1Min) {
          _addSystemMessage('⚠️ 1 minute remaining! Hurry up!');
        } else if (_escrowTimeLeft == kWarning30Sec) {
          _addSystemMessage('🚨 30 seconds remaining! Trade will expire soon!');
        }
      } else {
        timer.cancel();
        P2PLogger.warning('Trade', 'Trade timer expired', metadata: {
          'offerId': widget.offer.id,
        });
        _addSystemMessage('⏰ Payment window expired. Trade cancelled.');
        setState(() => _tradeStatus = TradeStatus.cancelled);
      }
    });
  }

  String get _formattedTime {
    final minutes = _escrowTimeLeft ~/ 60;
    final seconds = _escrowTimeLeft % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _addSystemMessage(String text) {
    setState(() {
      _messages.add(_ChatMessage(
        text: text,
        isSystem: true,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  void _addMessage(String text, {bool isMe = true, File? image}) {
    setState(() {
      _messages.add(_ChatMessage(
        text: text,
        isMe: isMe,
        isSystem: false,
        timestamp: DateTime.now(),
        image: image,
      ));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
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

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _addMessage(text);
    _messageController.clear();

    // Simulate seller response
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _addMessage('Got it! I\'ll check and confirm once received.', isMe: false);
      }
    });
  }

  Future<void> _pickProofImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF111128),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A3E),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              'Upload Payment Proof',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 24.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ImageSourceOption(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
                _ImageSourceOption(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
              ],
            ),
            SizedBox(height: 24.h),
          ],
        ),
      ),
    );

    if (source == null) return;

    final XFile? file = await _picker.pickImage(
      source: source,
      maxWidth: 1280,
      imageQuality: 80,
    );

    if (file == null) return;

    final proofFile = File(file.path);
    setState(() => _selectedProof = proofFile);
    _addMessage('Payment proof uploaded (${_selectedProof?.path.split('/').last})', image: proofFile);
    _addSystemMessage('Payment proof received. Waiting for seller confirmation.');
  }

  void _markAsPaid() {
    P2PLogger.info('Trade', 'User marked trade as paid', metadata: {
      'offerId': widget.offer.id,
      'timeRemaining': _escrowTimeLeft,
    });
    setState(() => _tradeStatus = TradeStatus.paid);
    _addSystemMessage('✅ You marked this order as paid. Waiting for seller to release BTC.');

    // Simulate seller release after delay
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _tradeStatus == TradeStatus.paid) {
        _releaseBtc();
      }
    });
  }

  void _releaseBtc() {
    _escrowTimer?.cancel();
    P2PLogger.info('Trade', 'BTC released successfully', metadata: {
      'offerId': widget.offer.id,
      'satsReceived': widget.receiveSats,
    });
    setState(() => _tradeStatus = TradeStatus.released);
    _addSystemMessage('🎉 BTC has been released to your wallet!');

    // Navigate to success screen
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => P2PSuccessScreen(
              amount: widget.tradeAmount,
              sats: widget.receiveSats,
              merchantName: widget.offer.name,
            ),
          ),
        );
      }
    });
  }

  void _cancelTrade() {
    P2PLogger.info('Trade', 'User cancelled trade', metadata: {
      'offerId': widget.offer.id,
      'timeRemaining': _escrowTimeLeft,
    });
    _escrowTimer?.cancel();
    setState(() => _tradeStatus = TradeStatus.cancelled);
    _addSystemMessage('Trade has been cancelled.');
    
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111128),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20.sp),
          onPressed: () => _showExitConfirmation(),
        ),
        title: Row(
          children: [
            Container(
              width: 36.w,
              height: 36.h,
              decoration: BoxDecoration(
                color: _getAvatarColor(widget.offer.name),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  widget.offer.name[0].toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.offer.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _getStatusText(),
                    style: TextStyle(
                      color: _getStatusColor(),
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.white, size: 24.sp),
            onPressed: () => _showTradeOptions(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Escrow Timer Bar - 4 minute countdown
          _EscrowTimerBar(
            timeLeft: _formattedTime,
            status: _tradeStatus,
            progress: _escrowTimeLeft / kTradeTimerSeconds,
            isUrgent: _escrowTimeLeft <= kWarning1Min,
          ),

          // Trade Info Card
          _TradeInfoCard(
            amount: widget.tradeAmount,
            sats: widget.receiveSats,
            paymentMethod: widget.offer.paymentMethod,
          ),
          
          // Incoming profile share request
          if (_profileShareRequest != null && _profileShareRequest!.isPending)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: ProfileShareRequestCard(
                request: _profileShareRequest!,
                onAcceptMutual: () => _respondToProfileRequest(ShareConsent.mutual),
                onAcceptViewOnly: () => _respondToProfileRequest(ShareConsent.viewOnly),
                onDecline: () => _respondToProfileRequest(ShareConsent.declined),
              ),
            ),
          
          // Shared counterparty profiles
          if (_sharedCounterpartyProfiles != null && _sharedCounterpartyProfiles!.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: SharedProfilesView(
                profiles: _sharedCounterpartyProfiles!,
                traderName: widget.offer.name,
              ),
            ),

          // Chat Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _ChatBubble(message: message);
              },
            ),
          ),

          // Action Buttons based on status
          if (_tradeStatus == TradeStatus.awaitingPayment)
            _buildAwaitingPaymentActions(),

          if (_tradeStatus == TradeStatus.paid)
            _buildPaidActions(),

          // Message Input
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildAwaitingPaymentActions() {
    return Container(
      padding: EdgeInsets.all(16.w),
      color: const Color(0xFF111128),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickProofImage,
                  icon: Icon(Icons.upload_file, size: 18.sp),
                  label: Text('Upload Proof'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF2A2A3E)),
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: ElevatedButton(
                  onPressed: _markAsPaid,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FFB2),
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    'I\'ve Paid',
                    style: TextStyle(
                      color: const Color(0xFF0C0C1A),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
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

  Widget _buildPaidActions() {
    return Container(
      padding: EdgeInsets.all(16.w),
      color: const Color(0xFF111128),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 14.h),
              decoration: BoxDecoration(
                color: const Color(0xFFF7931A).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18.w,
                    height: 18.h,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(const Color(0xFFF7931A)),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    'Waiting for seller to release BTC...',
                    style: TextStyle(
                      color: const Color(0xFFF7931A),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
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

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: const BoxDecoration(
        color: Color(0xFF0C0C1A),
        border: Border(
          top: BorderSide(color: Color(0xFF2A2A3E), width: 1),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              onPressed: _pickProofImage,
              icon: Icon(
                Icons.attach_file,
                color: const Color(0xFFA1A1B2),
                size: 24.sp,
              ),
            ),
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF111128),
                  borderRadius: BorderRadius.circular(24.r),
                ),
                child: TextField(
                  controller: _messageController,
                  style: TextStyle(color: Colors.white, fontSize: 14.sp),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(
                      color: const Color(0xFF6B6B80),
                      fontSize: 14.sp,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                  ),
                  onChanged: (value) {
                    setState(() => _isTyping = value.isNotEmpty);
                  },
                ),
              ),
            ),
            SizedBox(width: 8.w),
            GestureDetector(
              onTap: _isTyping ? _sendMessage : null,
              child: Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: _isTyping ? const Color(0xFFF7931A) : const Color(0xFF2A2A3E),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.send,
                  color: _isTyping ? Colors.white : const Color(0xFF6B6B80),
                  size: 20.sp,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusText() {
    switch (_tradeStatus) {
      case TradeStatus.awaitingPayment:
        return 'Awaiting payment';
      case TradeStatus.paid:
        return 'Payment submitted';
      case TradeStatus.releasing:
        return 'Releasing BTC...';
      case TradeStatus.released:
        return 'Completed';
      case TradeStatus.disputed:
        return 'Disputed';
      case TradeStatus.cancelled:
        return 'Cancelled';
      default:
        return 'In progress';
    }
  }

  Color _getStatusColor() {
    switch (_tradeStatus) {
      case TradeStatus.awaitingPayment:
        return const Color(0xFFF7931A);
      case TradeStatus.paid:
      case TradeStatus.releasing:
        return const Color(0xFF00FFB2);
      case TradeStatus.released:
        return const Color(0xFF00FFB2);
      case TradeStatus.disputed:
      case TradeStatus.cancelled:
        return const Color(0xFFFF6B6B);
      default:
        return const Color(0xFFA1A1B2);
    }
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

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Text(
          'Leave Trade?',
          style: TextStyle(color: Colors.white, fontSize: 18.sp),
        ),
        content: Text(
          'The trade is still in progress. Are you sure you want to leave?',
          style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Stay', style: TextStyle(color: const Color(0xFFA1A1B2))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text('Leave', style: TextStyle(color: const Color(0xFFFF6B6B))),
          ),
        ],
      ),
    );
  }

  void _showTradeOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111128),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A3E),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 24.h),
            // Profile sharing option
            if (SocialProfileService.hasProfilesToShare && !_hasRequestedProfileShare)
              _OptionTile(
                icon: Icons.handshake_outlined,
                label: 'Request Trust Share',
                color: const Color(0xFFF7931A),
                onTap: () {
                  Navigator.pop(ctx);
                  _showProfileShareDialog();
                },
              ),
            _OptionTile(
              icon: Icons.cancel,
              label: 'Cancel Trade',
              color: const Color(0xFFFF6B6B),
              onTap: () {
                Navigator.pop(ctx);
                _showCancelConfirmation();
              },
            ),
            _OptionTile(
              icon: Icons.help_outline,
              label: 'Get Help',
              color: const Color(0xFFF7931A),
              onTap: () => Navigator.pop(ctx),
            ),
            SizedBox(height: 16.h),
          ],
        ),
      ),
    );
  }
  
  void _showProfileShareDialog() {
    final profiles = SocialProfileService.getProfiles();
    if (profiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Add social profiles in Settings first'),
          backgroundColor: const Color(0xFFF7931A),
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => ProfileShareDialog(
        availableProfiles: profiles,
        counterpartyName: widget.offer.name,
        onSubmit: (platforms) => _sendProfileShareRequest(platforms),
      ),
    );
  }
  
  void _sendProfileShareRequest(List<SocialPlatform> platforms) {
    setState(() {
      _hasRequestedProfileShare = true;
    });
    
    P2PLogger.info('Trade', 'Sent profile share request', metadata: {
      'offerId': widget.offer.id,
      'platforms': platforms.map((p) => p.name).toList(),
    });
    
    _addSystemMessage('📤 You sent a trust profile share request to ${widget.offer.name}');
    
    // Simulate response (in real app, this would be via chat/messaging)
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _handleProfileShareResponse(accepted: true, mutual: true);
      }
    });
  }
  
  void _handleProfileShareResponse({required bool accepted, required bool mutual}) {
    if (!accepted) {
      _addSystemMessage('${widget.offer.name} declined the profile share request');
      return;
    }
    
    // Mock shared profiles from counterparty
    setState(() {
      _sharedCounterpartyProfiles = [
        SocialProfile(
          id: '1',
          platform: SocialPlatform.x,
          handle: '@${widget.offer.name.toLowerCase().replaceAll(' ', '')}',
          isVerified: true,
          addedAt: DateTime.now(),
        ),
        SocialProfile(
          id: '2', 
          platform: SocialPlatform.telegram,
          handle: '@${widget.offer.name.toLowerCase().replaceAll(' ', '')}',
          isVerified: false,
          addedAt: DateTime.now(),
        ),
      ];
    });
    
    if (mutual) {
      _addSystemMessage('🤝 Both profiles shared! You can now view each other\'s social profiles.');
    } else {
      _addSystemMessage('👁️ ${widget.offer.name} shared their profiles with you.');
    }
  }
  
  void _respondToProfileRequest(ShareConsent consent) {
    if (_profileShareRequest == null) return;
    
    final request = _profileShareRequest!;
    P2PLogger.info('Trade', 'Responded to profile share request', metadata: {
      'offerId': widget.offer.id,
      'consent': consent.name,
    });
    
    setState(() {
      _profileShareRequest = request.copyWith(
        status: consent == ShareConsent.declined 
            ? ProfileShareStatus.declined 
            : ProfileShareStatus.accepted,
        response: consent,
        respondedAt: DateTime.now(),
      );
    });
    
    if (consent == ShareConsent.declined) {
      _addSystemMessage('You declined the profile share request');
    } else if (consent == ShareConsent.mutual) {
      // Share my profiles (would be sent to counterparty in real implementation)
      _addSystemMessage('🤝 Profiles shared mutually!');
      // Mock receiving their profiles
      _handleProfileShareResponse(accepted: true, mutual: true);
    } else {
      _addSystemMessage('👁️ You can view their profiles (one-way)');
      _handleProfileShareResponse(accepted: true, mutual: false);
    }
  }

  void _showCancelConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Text(
          'Cancel Trade?',
          style: TextStyle(color: Colors.white, fontSize: 18.sp),
        ),
        content: Text(
          'Are you sure you want to cancel this trade? BTC will be returned to escrow. This action cannot be undone.',
          style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('No', style: TextStyle(color: const Color(0xFFA1A1B2))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _cancelTrade();
            },
            child: Text('Yes, Cancel', style: TextStyle(color: const Color(0xFFFF6B6B))),
          ),
        ],
      ),
    );
  }
}

/// Escrow Timer Bar
class _EscrowTimerBar extends StatelessWidget {
  final String timeLeft;
  final TradeStatus status;
  final double progress;
  final bool isUrgent;

  const _EscrowTimerBar({
    required this.timeLeft,
    required this.status,
    required this.progress,
    this.isUrgent = false,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = status == TradeStatus.awaitingPayment || status == TradeStatus.paid;
    // Use more urgent colors for 4-minute timer
    Color color;
    if (progress > 0.5) {
      color = const Color(0xFF00FFB2); // Green - plenty of time
    } else if (progress > 0.25) {
      color = const Color(0xFFF7931A); // Orange - hurry up
    } else {
      color = const Color(0xFFFF6B6B); // Red - very urgent
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      color: isUrgent ? const Color(0xFF1A0A0A) : const Color(0xFF111128),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.lock,
                    color: const Color(0xFFF7931A),
                    size: 18.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    isUrgent ? '⚠️ Complete Now!' : 'Escrow Active',
                    style: TextStyle(
                      color: isUrgent ? const Color(0xFFFF6B6B) : const Color(0xFFA1A1B2),
                      fontSize: 13.sp,
                      fontWeight: isUrgent ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              if (isActive)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20.r),
                    border: isUrgent ? Border.all(color: color, width: 1) : null,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.timer, color: color, size: 16.sp),
                      SizedBox(width: 4.w),
                      Text(
                        timeLeft,
                        style: TextStyle(
                          color: color,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (isActive) ...[
            SizedBox(height: 8.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(4.r),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: const Color(0xFF2A2A3E),
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 4.h,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Trade Info Card
class _TradeInfoCard extends StatelessWidget {
  final double amount;
  final double sats;
  final String paymentMethod;

  const _TradeInfoCard({
    required this.amount,
    required this.sats,
    required this.paymentMethod,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,###');

    return Container(
      margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF111128),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFF2A2A3E)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You Pay',
                  style: TextStyle(
                    color: const Color(0xFFA1A1B2),
                    fontSize: 12.sp,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '₦${formatter.format(amount.toInt())}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward,
            color: const Color(0xFFA1A1B2),
            size: 24.sp,
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'You Receive',
                  style: TextStyle(
                    color: const Color(0xFFA1A1B2),
                    fontSize: 12.sp,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '${formatter.format(sats.toInt())} sats',
                  style: TextStyle(
                    color: const Color(0xFF00FFB2),
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Chat Bubble
class _ChatBubble extends StatelessWidget {
  final _ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) {
      return Container(
        margin: EdgeInsets.symmetric(vertical: 8.h),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12.r),
        ),
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
                message.text,
                style: TextStyle(
                  color: const Color(0xFFA1A1B2),
                  fontSize: 13.sp,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4.h),
        constraints: BoxConstraints(maxWidth: 280.w),
        child: Column(
          crossAxisAlignment:
              message.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: message.isMe ? const Color(0xFFF7931A) : const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16.r),
                  topRight: Radius.circular(16.r),
                  bottomLeft: Radius.circular(message.isMe ? 16.r : 4.r),
                  bottomRight: Radius.circular(message.isMe ? 4.r : 16.r),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.image != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8.r),
                      child: Image.file(
                        message.image!,
                        width: 200.w,
                        height: 150.h,
                        fit: BoxFit.cover,
                      ),
                    ),
                    SizedBox(height: 8.h),
                  ],
                  Text(
                    message.text,
                    style: TextStyle(
                      color: message.isMe ? Colors.white : const Color(0xFFE0E0E0),
                      fontSize: 14.sp,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              _formatTime(message.timestamp),
              style: TextStyle(
                color: const Color(0xFF6B6B80),
                fontSize: 11.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

/// Chat Message Model
class _ChatMessage {
  final String text;
  final bool isMe;
  final bool isSystem;
  final DateTime timestamp;
  final File? image;

  _ChatMessage({
    required this.text,
    this.isMe = true,
    this.isSystem = false,
    required this.timestamp,
    this.image,
  });
}

/// Image Source Option
class _ImageSourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ImageSourceOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(icon, color: const Color(0xFFF7931A), size: 32.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            label,
            style: TextStyle(
              color: const Color(0xFFA1A1B2),
              fontSize: 14.sp,
            ),
          ),
        ],
      ),
    );
  }
}

/// Option Tile
class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      onTap: onTap,
    );
  }
}
