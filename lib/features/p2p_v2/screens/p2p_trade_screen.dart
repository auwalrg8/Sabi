import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';
import '../providers/p2p_provider.dart';
import '../data/p2p_state.dart';
import '../widgets/trade_status_bar.dart';

/// P2P v2 Trade Screen
/// 
/// Real-time trade flow with:
/// - Status tracking
/// - Chat messages
/// - Receipt upload
/// - Payment confirmation
/// - Bitcoin release
class P2PV2TradeScreen extends ConsumerStatefulWidget {
  final String tradeId;

  const P2PV2TradeScreen({super.key, required this.tradeId});

  @override
  ConsumerState<P2PV2TradeScreen> createState() => _P2PV2TradeScreenState();
}

class _P2PV2TradeScreenState extends ConsumerState<P2PV2TradeScreen> {
  final _chatController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isUploading = false;
  bool _isReleasing = false;

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trade = ref.watch(p2pTradeProvider(widget.tradeId));
    final notifier = ref.read(p2pV2Provider.notifier);
    
    if (trade == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Text(
            'Trade not found',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16.sp),
          ),
        ),
      );
    }

    final isBuyer = trade.buyerPubkey == notifier.myPubkey;
    final isSeller = trade.sellerPubkey == notifier.myPubkey;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context, trade),
            
            // Status bar
            TradeStatusBar(status: trade.status),
            
            // Trade info card
            _buildTradeInfoCard(trade, isBuyer),
            
            // Messages
            Expanded(
              child: _buildMessagesList(trade),
            ),
            
            // Bottom action area
            _buildBottomActions(trade, notifier, isBuyer, isSeller),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, P2PTrade trade) {
    return Container(
      padding: EdgeInsets.all(16.w),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40.w,
              height: 40.h,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(Icons.arrow_back, color: Colors.white, size: 20.sp),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trade',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '#${trade.id.substring(0, 12)}...',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
          
          // Timer (if applicable)
          if (!trade.isCompleted && !trade.isCancelled)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: AppColors.accentYellow.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer, color: AppColors.accentYellow, size: 14.sp),
                  SizedBox(width: 4.w),
                  Text(
                    _formatTimeRemaining(trade),
                    style: TextStyle(
                      color: AppColors.accentYellow,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTradeInfoCard(P2PTrade trade, bool isBuyer) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Amount',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 11.sp,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      trade.formattedAmount,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 40.h,
                color: AppColors.borderColor,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Payment',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 11.sp,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      trade.paymentMethod,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          
          // Role indicator
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: (isBuyer ? AppColors.accentGreen : AppColors.primary).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isBuyer ? Icons.shopping_cart : Icons.sell,
                  color: isBuyer ? AppColors.accentGreen : AppColors.primary,
                  size: 16.sp,
                ),
                SizedBox(width: 8.w),
                Text(
                  isBuyer ? 'You are buying' : 'You are selling',
                  style: TextStyle(
                    color: isBuyer ? AppColors.accentGreen : AppColors.primary,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(P2PTrade trade) {
    final messages = trade.messages;
    
    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 48.sp,
              color: AppColors.textTertiary,
            ),
            SizedBox(height: 12.h),
            Text(
              'No messages yet',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14.sp,
              ),
            ),
            Text(
              'Trade updates will appear here',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 12.sp,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(16.w),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return _buildMessageBubble(message, trade);
      },
    );
  }

  Widget _buildMessageBubble(TradeMessage message, P2PTrade trade) {
    final notifier = ref.read(p2pV2Provider.notifier);
    final isMe = message.senderPubkey == notifier.myPubkey;
    
    if (message.isSystemMessage) {
      return _buildSystemMessage(message);
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(12.w),
        constraints: BoxConstraints(maxWidth: 280.w),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16.r),
            topRight: Radius.circular(16.r),
            bottomLeft: Radius.circular(isMe ? 16.r : 4.r),
            bottomRight: Radius.circular(isMe ? 4.r : 16.r),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.imageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8.r),
                child: Image.network(
                  message.imageUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 100.h,
                    color: AppColors.background,
                    child: Center(
                      child: Icon(Icons.image_not_supported, color: AppColors.textTertiary),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 8.h),
            ],
            Text(
              message.content,
              style: TextStyle(
                color: isMe ? Colors.white : AppColors.textPrimary,
                fontSize: 14.sp,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              _formatTime(message.timestamp),
              style: TextStyle(
                color: isMe ? Colors.white70 : AppColors.textTertiary,
                fontSize: 10.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemMessage(TradeMessage message) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        children: [
          Expanded(child: Divider(color: AppColors.borderColor)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: Text(
              message.content,
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 12.sp,
              ),
            ),
          ),
          Expanded(child: Divider(color: AppColors.borderColor)),
        ],
      ),
    );
  }

  Widget _buildBottomActions(
    P2PTrade trade,
    P2PStateNotifier notifier,
    bool isBuyer,
    bool isSeller,
  ) {
    // Trade is completed or cancelled
    if (trade.isCompleted || trade.isCancelled) {
      return _buildCompletedBanner(trade);
    }

    // Show appropriate action based on status and role
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.borderColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status-specific action buttons
          _buildActionButtons(trade, notifier, isBuyer, isSeller),
          
          SizedBox(height: 12.h),
          
          // Chat input
          _buildChatInput(trade, notifier),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    P2PTrade trade,
    P2PStateNotifier notifier,
    bool isBuyer,
    bool isSeller,
  ) {
    switch (trade.status) {
      case TradeStatus.requested:
        if (isSeller) {
          return Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'Reject',
                  AppColors.accentRed,
                  () => _rejectTrade(notifier),
                  outlined: true,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildActionButton(
                  'Accept Trade',
                  AppColors.accentGreen,
                  () => _acceptTrade(notifier),
                ),
              ),
            ],
          );
        }
        return _buildWaitingIndicator('Waiting for seller to accept...');

      case TradeStatus.awaitingPayment:
        if (isBuyer) {
          return Column(
            children: [
              _buildActionButton(
                'I\'ve Sent Payment',
                AppColors.primary,
                () => _markPaymentSent(notifier),
              ),
              SizedBox(height: 8.h),
              _buildUploadReceiptButton(),
            ],
          );
        }
        return _buildWaitingIndicator('Waiting for buyer to send payment...');

      case TradeStatus.paymentSent:
        if (isBuyer) {
          return Column(
            children: [
              _buildUploadReceiptButton(),
              SizedBox(height: 8.h),
              _buildWaitingIndicator('Waiting for seller to confirm payment...'),
            ],
          );
        }
        if (isSeller) {
          return Column(
            children: [
              // Show receipt if uploaded
              if (trade.receiptUrl != null)
                _buildReceiptPreview(trade.receiptUrl!),
              SizedBox(height: 12.h),
              _buildActionButton(
                'Confirm Payment Received',
                AppColors.accentGreen,
                () => _confirmPayment(notifier),
              ),
            ],
          );
        }
        return const SizedBox.shrink();

      case TradeStatus.paymentConfirmed:
        if (isSeller) {
          // Check if we have buyer's Lightning invoice
          if (trade.buyerLightningInvoice == null || trade.buyerLightningInvoice!.isEmpty) {
            return Column(
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20.sp),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          'Waiting for buyer to submit their Lightning invoice...',
                          style: TextStyle(color: Colors.orange, fontSize: 12.sp),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
          return _buildActionButton(
            _isReleasing ? 'Releasing...' : 'Release Bitcoin',
            AppColors.primary,
            _isReleasing ? null : () => _releaseBitcoin(notifier),
            isLoading: _isReleasing,
          );
        }
        // Buyer side - check if they submitted invoice
        if (isBuyer) {
          if (trade.buyerLightningInvoice == null || trade.buyerLightningInvoice!.isEmpty) {
            return Column(
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Submit your Lightning invoice',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'The seller needs your Lightning invoice to release the Bitcoin.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12.h),
                _buildActionButton(
                  'Generate Invoice',
                  AppColors.primary,
                  () => _generateAndSubmitInvoice(trade),
                ),
              ],
            );
          }
          return _buildWaitingIndicator('Seller is releasing Bitcoin...');
        }
        return _buildWaitingIndicator('Seller is releasing Bitcoin...');

      case TradeStatus.releasing:
        return _buildWaitingIndicator('Bitcoin is being released...');

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildActionButton(
    String label,
    Color color,
    VoidCallback? onPressed, {
    bool outlined = false,
    bool isLoading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48.h,
      child: outlined
          ? OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: color),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(
                label,
                style: TextStyle(color: color, fontSize: 14.sp, fontWeight: FontWeight.w600),
              ),
            )
          : ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                disabledBackgroundColor: color.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: isLoading
                  ? SizedBox(
                      width: 20.w,
                      height: 20.h,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      label,
                      style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w600),
                    ),
            ),
    );
  }

  Widget _buildWaitingIndicator(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.accentYellow.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16.w,
            height: 16.h,
            child: CircularProgressIndicator(
              color: AppColors.accentYellow,
              strokeWidth: 2,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppColors.accentYellow,
                fontSize: 13.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadReceiptButton() {
    return SizedBox(
      width: double.infinity,
      height: 48.h,
      child: OutlinedButton.icon(
        onPressed: _isUploading ? null : _uploadReceipt,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.textSecondary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
        icon: _isUploading
            ? SizedBox(
                width: 16.w,
                height: 16.h,
                child: CircularProgressIndicator(
                  color: AppColors.textSecondary,
                  strokeWidth: 2,
                ),
              )
            : Icon(Icons.upload_file, color: AppColors.textSecondary, size: 18.sp),
        label: Text(
          _isUploading ? 'Uploading...' : 'Upload Payment Receipt',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14.sp,
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptPreview(String receiptUrl) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6.r),
            child: Image.network(
              receiptUrl,
              width: 60.w,
              height: 60.h,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 60.w,
                height: 60.h,
                color: AppColors.surface,
                child: Icon(Icons.receipt, color: AppColors.textTertiary),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment Receipt',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Uploaded by buyer',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 11.sp,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _showFullReceipt(receiptUrl),
            icon: Icon(Icons.fullscreen, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildChatInput(P2PTrade trade, P2PStateNotifier notifier) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _chatController,
            style: TextStyle(color: Colors.white, fontSize: 14.sp),
            decoration: InputDecoration(
              hintText: 'Type a message...',
              hintStyle: TextStyle(color: AppColors.textTertiary),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24.r),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            ),
          ),
        ),
        SizedBox(width: 8.w),
        GestureDetector(
          onTap: () => _sendMessage(notifier, trade.id),
          child: Container(
            width: 44.w,
            height: 44.h,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.send, color: Colors.white, size: 20.sp),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedBanner(P2PTrade trade) {
    final isCompleted = trade.isCompleted;
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: (isCompleted ? AppColors.accentGreen : AppColors.accentRed).withOpacity(0.1),
        border: Border(
          top: BorderSide(
            color: isCompleted ? AppColors.accentGreen : AppColors.accentRed,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Icon(
              isCompleted ? Icons.check_circle : Icons.cancel,
              color: isCompleted ? AppColors.accentGreen : AppColors.accentRed,
              size: 32.sp,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCompleted ? 'Trade Completed!' : 'Trade Cancelled',
                    style: TextStyle(
                      color: isCompleted ? AppColors.accentGreen : AppColors.accentRed,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    isCompleted
                        ? '${trade.formattedAmount} has been transferred'
                        : 'This trade has been cancelled',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Action handlers
  Future<void> _acceptTrade(P2PStateNotifier notifier) async {
    await notifier.acceptTrade(widget.tradeId);
  }

  Future<void> _rejectTrade(P2PStateNotifier notifier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Reject Trade', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to reject this trade?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Reject', style: TextStyle(color: AppColors.accentRed)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await notifier.rejectTrade(widget.tradeId);
    }
  }

  Future<void> _markPaymentSent(P2PStateNotifier notifier) async {
    await notifier.markPaymentSent(widget.tradeId);
  }

  Future<void> _uploadReceipt() async {
    setState(() => _isUploading = true);

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image != null) {
        // TODO: Upload to storage and get URL
        // For now, just use local path
        final notifier = ref.read(p2pV2Provider.notifier);
        await notifier.uploadReceipt(widget.tradeId, image.path);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Receipt uploaded'),
              backgroundColor: AppColors.accentGreen,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload receipt: $e'),
            backgroundColor: AppColors.accentRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _confirmPayment(P2PStateNotifier notifier) async {
    await notifier.confirmPayment(widget.tradeId);
  }

  Future<void> _releaseBitcoin(P2PStateNotifier notifier) async {
    final trade = ref.read(p2pTradeProvider(widget.tradeId));
    if (trade == null) return;
    
    // Verify we have the buyer's Lightning invoice
    if (trade.buyerLightningInvoice == null || trade.buyerLightningInvoice!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Waiting for buyer to submit their Lightning invoice'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Release Bitcoin', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to release ${trade.satsAmount} sats to the buyer? This action cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Release', style: TextStyle(color: AppColors.accentGreen)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isReleasing = true);
      try {
        await notifier.releaseBitcoin(widget.tradeId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Bitcoin released successfully! ⚡'),
              backgroundColor: AppColors.accentGreen,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to release Bitcoin: $e'),
              backgroundColor: AppColors.accentRed,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isReleasing = false);
        }
      }
    }
  }

  /// Generate a Lightning invoice for the trade amount and submit it
  Future<void> _generateAndSubmitInvoice(P2PTrade trade) async {
    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20.w,
                height: 20.h,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
              SizedBox(width: 12.w),
              Text('Generating Lightning invoice...'),
            ],
          ),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 10),
        ),
      );

      // Generate invoice for the trade amount
      final invoice = await BreezSparkService.createInvoice(
        sats: trade.satsAmount,
        memo: 'P2P Trade #${trade.id.substring(0, 8)}',
      );

      if (invoice.isEmpty) {
        throw Exception('Failed to generate invoice');
      }

      // Submit the invoice to the seller
      final notifier = ref.read(p2pV2Provider.notifier);
      await notifier.submitBuyerInvoice(trade.id, invoice);

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invoice submitted! Waiting for seller to release Bitcoin.'),
            backgroundColor: AppColors.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate invoice: $e'),
            backgroundColor: AppColors.accentRed,
          ),
        );
      }
    }
  }

  Future<void> _sendMessage(P2PStateNotifier notifier, String tradeId) async {
    final message = _chatController.text.trim();
    if (message.isEmpty) return;

    _chatController.clear();
    await notifier.sendChatMessage(tradeId, message);
    
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

  void _showFullReceipt(String receiptUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12.r),
              child: Image.network(
                receiptUrl,
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(height: 16.h),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Close',
                style: TextStyle(color: Colors.white, fontSize: 16.sp),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeRemaining(P2PTrade trade) {
    // Trade timeout: 30 minutes from creation
    final timeout = trade.createdAt.add(const Duration(minutes: 30));
    final remaining = timeout.difference(DateTime.now());
    
    if (remaining.isNegative) return 'Expired';
    
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
