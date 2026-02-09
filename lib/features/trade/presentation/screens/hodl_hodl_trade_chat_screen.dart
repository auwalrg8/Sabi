import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/services/hodl_hodl/hodl_hodl.dart';

import 'trade_success_screen.dart';

/// Trade Chat Screen
/// Shows escrow status, chat messages, and release funds button
class HodlHodlTradeChatScreen extends ConsumerStatefulWidget {
  final HodlHodlContract contract;

  const HodlHodlTradeChatScreen({
    Key? key,
    required this.contract,
  }) : super(key: key);

  @override
  ConsumerState<HodlHodlTradeChatScreen> createState() => _HodlHodlTradeChatScreenState();
}

class _HodlHodlTradeChatScreenState extends ConsumerState<HodlHodlTradeChatScreen> {
  Timer? _refreshTimer;
  HodlHodlContract? _currentContract;
  bool _isPerformingAction = false;

  @override
  void initState() {
    super.initState();
    _currentContract = widget.contract;
    // Auto-refresh contract status every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshContract();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshContract() async {
    try {
      final service = ref.read(hodlHodlServiceProvider);
      final updated = await service.getContract(_currentContract!.id);
      if (mounted) {
        setState(() => _currentContract = updated);
      }
    } catch (e) {
      // Silently fail on refresh
    }
  }

  @override
  Widget build(BuildContext context) {
    final contract = _currentContract!;
    final messagesAsync = ref.watch(hodlHodlChatMessagesProvider(contract.id));
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white, size: 24.sp),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trade with ${contract.counterparty.login}',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Contract: ${contract.id}',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11.sp,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white70, size: 22.sp),
            onPressed: _refreshContract,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status card
            _buildStatusCard(contract),
            
            // Escrow info
            _buildEscrowCard(contract),
            
            // Payment info
            if (contract.paymentMethodInstruction != null)
              _buildPaymentInfoCard(contract),
            
            // Timer (if applicable)
            if (contract.paymentWindowTimeLeftSeconds != null)
              _buildTimerCard(contract),
            
            // Chat messages
            Expanded(
              child: messagesAsync.when(
                data: (messages) => _buildChatList(messages),
                loading: () => Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (_, __) => _buildEmptyChat(),
              ),
            ),
            
            // Action buttons
            _buildActionButtons(contract),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(HodlHodlContract contract) {
    Color statusColor;
    IconData statusIcon;
    
    switch (contract.status) {
      case 'pending':
        statusColor = AppColors.accentYellow;
        statusIcon = Icons.hourglass_empty;
        break;
      case 'depositing':
        statusColor = AppColors.primary;
        statusIcon = Icons.download;
        break;
      case 'in_progress':
        statusColor = AppColors.accentGreen;
        statusIcon = Icons.play_circle;
        break;
      case 'paid':
        statusColor = const Color(0xFF9333EA);
        statusIcon = Icons.check_circle;
        break;
      case 'completed':
        statusColor = AppColors.accentGreen;
        statusIcon = Icons.verified;
        break;
      case 'canceled':
        statusColor = Colors.grey;
        statusIcon = Icons.cancel;
        break;
      case 'disputed':
        statusColor = AppColors.accentRed;
        statusIcon = Icons.warning;
        break;
      default:
        statusColor = Colors.white54;
        statusIcon = Icons.info;
    }

    return Container(
      margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withOpacity(0.2),
            statusColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(statusIcon, color: statusColor, size: 24.sp),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contract.statusDisplay,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  _getStatusMessage(contract),
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${contract.volume} BTC',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${_getCurrencySymbol(contract.currencyCode)}${contract.value}',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12.sp,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEscrowCard(HodlHodlContract contract) {
    final escrow = contract.escrow;
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security, color: AppColors.accentGreen, size: 18.sp),
              SizedBox(width: 8.w),
              Text(
                'Escrow',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: escrow.address != null
                      ? AppColors.accentGreen.withOpacity(0.2)
                      : AppColors.accentYellow.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  escrow.address != null ? 'Ready' : 'Pending',
                  style: TextStyle(
                    color: escrow.address != null ? AppColors.accentGreen : AppColors.accentYellow,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (escrow.address != null) ...[
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      escrow.address!,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11.sp,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: escrow.address!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Address copied'),
                          backgroundColor: AppColors.accentGreen,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Icon(Icons.copy, color: Colors.white54, size: 16.sp),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildEscrowStat('Deposited', escrow.amountDeposited ?? '0'),
                _buildEscrowStat('Confirmations', '${escrow.confirmations}/${contract.confirmations}'),
                _buildEscrowStat(
                  'Verified',
                  escrow.youConfirmed && escrow.counterpartyConfirmed ? 'Both' : 
                    escrow.youConfirmed ? 'You' : 
                    escrow.counterpartyConfirmed ? 'Them' : 'None',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEscrowStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white54,
            fontSize: 10.sp,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentInfoCard(HodlHodlContract contract) {
    final payment = contract.paymentMethodInstruction!;
    
    return Container(
      margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payment, color: AppColors.primary, size: 18.sp),
              SizedBox(width: 8.w),
              Text(
                payment.paymentMethodName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (payment.details.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                payment.details,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13.sp,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimerCard(HodlHodlContract contract) {
    final secondsLeft = contract.paymentWindowTimeLeftSeconds ?? 0;
    final minutes = secondsLeft ~/ 60;
    final seconds = secondsLeft % 60;
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: minutes < 10 ? AppColors.accentRed.withOpacity(0.1) : AppColors.surface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: minutes < 10 ? AppColors.accentRed.withOpacity(0.3) : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.timer,
            color: minutes < 10 ? AppColors.accentRed : Colors.white54,
            size: 20.sp,
          ),
          SizedBox(width: 12.w),
          Text(
            'Time remaining: ',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13.sp,
            ),
          ),
          Text(
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
            style: TextStyle(
              color: minutes < 10 ? AppColors.accentRed : Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList(List<HodlHodlChatMessage> messages) {
    if (messages.isEmpty) {
      return _buildEmptyChat();
    }
    
    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isMe = message.author == 'You'; // This would need to be determined by comparing with user login
        
        return Container(
          margin: EdgeInsets.only(bottom: 12.h),
          child: Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMe && !message.fromAdmin) ...[
                Container(
                  width: 32.w,
                  height: 32.h,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Center(
                    child: Text(
                      message.author.isNotEmpty ? message.author[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
              ],
              Flexible(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: message.fromAdmin
                        ? AppColors.accentYellow.withOpacity(0.1)
                        : isMe
                            ? AppColors.primary.withOpacity(0.2)
                            : AppColors.surface,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.fromAdmin)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.admin_panel_settings, color: AppColors.accentYellow, size: 12.sp),
                            SizedBox(width: 4.w),
                            Text(
                              'Admin',
                              style: TextStyle(
                                color: AppColors.accentYellow,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      Text(
                        message.text,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        _formatTime(message.sentAt),
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 10.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, color: Colors.white24, size: 48.sp),
          SizedBox(height: 16.h),
          Text(
            'No messages yet',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14.sp,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Chat on hodlhodl.com to message your counterparty',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white38,
              fontSize: 12.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(HodlHodlContract contract) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Primary action based on status
            if (contract.canMarkAsPaid)
              _buildPrimaryButton(
                label: 'I Have Paid',
                color: AppColors.primary,
                icon: Icons.check,
                onPressed: _markAsPaid,
              ),
            
            if (contract.canReleaseFunds)
              _buildPrimaryButton(
                label: 'Release Funds',
                color: AppColors.accentGreen,
                icon: Icons.send,
                onPressed: _releaseFunds,
              ),
            
            if (contract.status == 'pending' && !contract.escrow.youConfirmed)
              _buildPrimaryButton(
                label: 'Confirm Escrow',
                color: AppColors.primary,
                icon: Icons.verified,
                onPressed: _confirmEscrow,
              ),
            
            // Secondary actions
            if (contract.canBeCanceled) ...[
              SizedBox(height: 8.h),
              TextButton(
                onPressed: _cancelContract,
                child: Text(
                  'Cancel Trade',
                  style: TextStyle(
                    color: AppColors.accentRed,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56.h,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          elevation: 0,
        ),
        onPressed: _isPerformingAction ? null : onPressed,
        icon: _isPerformingAction
            ? SizedBox(
                width: 20.w,
                height: 20.h,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Icon(icon, color: Colors.white),
        label: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Future<void> _confirmEscrow() async {
    setState(() => _isPerformingAction = true);
    HapticFeedback.mediumImpact();
    
    try {
      final success = await ref.read(hodlHodlContractNotifierProvider.notifier)
          .confirmEscrow(_currentContract!.id);
      
      if (success) {
        _showSuccess('Escrow confirmed');
        _refreshContract();
      } else {
        _showError('Failed to confirm escrow');
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isPerformingAction = false);
    }
  }

  Future<void> _markAsPaid() async {
    final confirmed = await _showConfirmDialog(
      'Mark as Paid',
      'Are you sure you have sent the payment? Only confirm if you have actually transferred the funds.',
    );
    
    if (!confirmed) return;
    
    setState(() => _isPerformingAction = true);
    HapticFeedback.mediumImpact();
    
    try {
      final success = await ref.read(hodlHodlContractNotifierProvider.notifier)
          .markAsPaid(_currentContract!.id);
      
      if (success) {
        _showSuccess('Marked as paid');
        _refreshContract();
      } else {
        _showError('Failed to mark as paid');
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isPerformingAction = false);
    }
  }

  Future<void> _releaseFunds() async {
    final confirmed = await _showConfirmDialog(
      'Release Funds',
      'Have you received the payment? This will release the Bitcoin to the buyer. This action cannot be undone.',
    );
    
    if (!confirmed) return;
    
    setState(() => _isPerformingAction = true);
    HapticFeedback.heavyImpact();
    
    // Note: Full release requires client-side transaction signing
    // For beta, we'll show instructions to complete on hodlhodl.com
    _showInfo(
      'To release funds, please complete the transaction on hodlhodl.com. '
      'Full in-app release will be available in a future update.',
    );
    
    setState(() => _isPerformingAction = false);
    
    // Navigate to success screen after showing info
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => TradeSuccessScreen(contract: _currentContract!),
          ),
        );
      }
    });
  }

  Future<void> _cancelContract() async {
    final confirmed = await _showConfirmDialog(
      'Cancel Trade',
      'Are you sure you want to cancel this trade?',
    );
    
    if (!confirmed) return;
    
    setState(() => _isPerformingAction = true);
    
    try {
      final success = await ref.read(hodlHodlContractNotifierProvider.notifier)
          .cancelContract(_currentContract!.id);
      
      if (success) {
        _showSuccess('Trade canceled');
        Navigator.pop(context);
      } else {
        _showError('Failed to cancel trade');
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isPerformingAction = false);
    }
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Text(
          title,
          style: TextStyle(color: Colors.white, fontSize: 18.sp),
        ),
        content: Text(
          message,
          style: TextStyle(color: Colors.white70, fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.accentRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.accentGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      ),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      ),
    );
  }

  String _getStatusMessage(HodlHodlContract contract) {
    switch (contract.status) {
      case 'pending':
        return 'Waiting for escrow confirmation from both parties';
      case 'depositing':
        return 'Seller is depositing BTC to escrow';
      case 'in_progress':
        return contract.yourRole == 'buyer' 
            ? 'Send payment and mark as paid'
            : 'Waiting for buyer to send payment';
      case 'paid':
        return contract.yourRole == 'seller'
            ? 'Buyer has sent payment. Verify and release funds.'
            : 'Waiting for seller to release funds';
      case 'completed':
        return 'Trade completed successfully!';
      case 'canceled':
        return 'This trade was canceled';
      case 'disputed':
        return 'This trade is under dispute';
      default:
        return '';
    }
  }

  String _getCurrencySymbol(String code) {
    switch (code) {
      case 'NGN':
        return '₦';
      case 'USD':
        return '\$';
      default:
        return code;
    }
  }

  String _formatTime(String isoTime) {
    try {
      final dt = DateTime.parse(isoTime);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }
}
