import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sabi_wallet/features/p2p/services/p2p_trade_manager.dart';
import 'package:sabi_wallet/features/p2p/presentation/screens/p2p_trade_chat_screen.dart';
import 'package:sabi_wallet/features/p2p/data/p2p_offer_model.dart';

/// Safely converts double to int, handling Infinity and NaN
int _safeToInt(double value, [int defaultValue = 0]) {
  if (value.isNaN || value.isInfinite) return defaultValue;
  return value.toInt();
}

/// Seller Trade Management Card - Binance-like UX for managing active trades
/// Shows trade details, buyer info, payment status, and action buttons
class SellerTradeManagementCard extends ConsumerStatefulWidget {
  final P2PTrade trade;
  final P2POfferModel? offer;
  final VoidCallback? onTradeUpdated;

  const SellerTradeManagementCard({
    super.key,
    required this.trade,
    this.offer,
    this.onTradeUpdated,
  });

  @override
  ConsumerState<SellerTradeManagementCard> createState() =>
      _SellerTradeManagementCardState();
}

class _SellerTradeManagementCardState
    extends ConsumerState<SellerTradeManagementCard> {
  final formatter = NumberFormat('#,###');
  Timer? _timer;
  int _timeLeftSeconds = 0;
  bool _isReleasingFunds = false;
  bool _isConfirmingPayment = false;

  @override
  void initState() {
    super.initState();
    _calculateTimeLeft();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _calculateTimeLeft() {
    final elapsed = DateTime.now().difference(widget.trade.createdAt).inSeconds;
    _timeLeftSeconds = (P2PTradeManager.tradeTimerSeconds - elapsed).clamp(0, P2PTradeManager.tradeTimerSeconds);
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _timeLeftSeconds > 0) {
        setState(() => _timeLeftSeconds--);
      }
    });
  }

  String get _formattedTimeLeft {
    final minutes = _timeLeftSeconds ~/ 60;
    final seconds = _timeLeftSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Color get _statusColor {
    switch (widget.trade.status) {
      case P2PTradeStatus.pendingPayment:
        return Colors.amber;
      case P2PTradeStatus.paymentSubmitted:
        return Colors.blue;
      case P2PTradeStatus.releasing:
        return Colors.purple;
      case P2PTradeStatus.completed:
        return Colors.green;
      case P2PTradeStatus.cancelled:
      case P2PTradeStatus.expired:
        return Colors.red;
      case P2PTradeStatus.disputed:
        return Colors.orange;
    }
  }

  String get _statusText {
    switch (widget.trade.status) {
      case P2PTradeStatus.pendingPayment:
        return 'Waiting for Payment';
      case P2PTradeStatus.paymentSubmitted:
        return '💳 Buyer Marked Paid';
      case P2PTradeStatus.releasing:
        return 'Releasing BTC...';
      case P2PTradeStatus.completed:
        return '✅ Completed';
      case P2PTradeStatus.cancelled:
        return 'Cancelled';
      case P2PTradeStatus.expired:
        return 'Expired';
      case P2PTradeStatus.disputed:
        return '⚠️ Disputed';
    }
  }

  IconData get _statusIcon {
    switch (widget.trade.status) {
      case P2PTradeStatus.pendingPayment:
        return Icons.hourglass_empty;
      case P2PTradeStatus.paymentSubmitted:
        return Icons.payment;
      case P2PTradeStatus.releasing:
        return Icons.send;
      case P2PTradeStatus.completed:
        return Icons.check_circle;
      case P2PTradeStatus.cancelled:
      case P2PTradeStatus.expired:
        return Icons.cancel;
      case P2PTradeStatus.disputed:
        return Icons.warning;
    }
  }

  Future<void> _confirmPaymentReceived() async {
    setState(() => _isConfirmingPayment = true);
    
    final confirmed = await P2PTradeManager().confirmPaymentReceived(widget.trade.id);
    
    if (mounted) {
      setState(() => _isConfirmingPayment = false);
      
      if (confirmed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment confirmed! You can now release the BTC.'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onTradeUpdated?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to confirm payment'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _releaseFunds() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Release Funds?', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will send ${formatter.format(widget.trade.satsAmount)} sats to the buyer\'s Lightning wallet.',
              style: TextStyle(color: Colors.grey[400]),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Only release after confirming you received ₦${formatter.format(_safeToInt(widget.trade.fiatAmount))}',
                      style: TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Release BTC', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isReleasingFunds = true);

    final released = await P2PTradeManager().releaseBtc(widget.trade.id);

    if (mounted) {
      setState(() => _isReleasingFunds = false);

      if (released) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('BTC released successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
        widget.onTradeUpdated?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to release funds. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openChat() {
    if (widget.offer == null) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => P2PTradeChatScreen(
          offer: widget.offer!,
          tradeAmount: widget.trade.fiatAmount,
          receiveSats: widget.trade.satsAmount.toDouble(),
          isSeller: true,
          existingTrade: widget.trade,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trade = widget.trade;
    final showReleaseButton = trade.status == P2PTradeStatus.paymentSubmitted ||
        trade.status == P2PTradeStatus.releasing;
    final showConfirmButton = trade.status == P2PTradeStatus.paymentSubmitted;
    final isActive = trade.status == P2PTradeStatus.pendingPayment ||
        trade.status == P2PTradeStatus.paymentSubmitted ||
        trade.status == P2PTradeStatus.releasing;

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: const Color(0xFF111128),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: _statusColor.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _statusColor.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with trade ID and status
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.vertical(top: Radius.circular(15.r)),
            ),
            child: Row(
              children: [
                Icon(_statusIcon, color: _statusColor, size: 20.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trade #${trade.id.substring(0, 8).toUpperCase()}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _statusText,
                        style: TextStyle(
                          color: _statusColor,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Timer (only for active trades)
                if (isActive)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: _timeLeftSeconds < 60
                          ? Colors.red.withOpacity(0.2)
                          : Colors.grey[800],
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer,
                          size: 14.sp,
                          color: _timeLeftSeconds < 60 ? Colors.red : Colors.white70,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          _formattedTimeLeft,
                          style: TextStyle(
                            color: _timeLeftSeconds < 60 ? Colors.red : Colors.white,
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
          ),

          // Buyer Info Section
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              children: [
                // Buyer row
                Row(
                  children: [
                    // Buyer avatar
                    CircleAvatar(
                      radius: 20.r,
                      backgroundColor: Colors.grey[800],
                      child: Text(
                        (trade.buyerName ?? 'B').substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Buyer',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 11.sp,
                            ),
                          ),
                          Text(
                            trade.buyerName ?? 'Anonymous',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Chat button
                    if (widget.offer != null)
                      IconButton(
                        onPressed: _openChat,
                        icon: Icon(Icons.chat_bubble_outline, color: Colors.orange),
                        tooltip: 'Chat with buyer',
                      ),
                  ],
                ),
                SizedBox(height: 16.h),

                // Amount details
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C0C1A),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'You Receive',
                              style: TextStyle(color: Colors.grey[500], fontSize: 11.sp),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              '₦${formatter.format(_safeToInt(trade.fiatAmount))}',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.all(8.r),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.swap_horiz, color: Colors.orange, size: 20.sp),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'You Send',
                              style: TextStyle(color: Colors.grey[500], fontSize: 11.sp),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              '${formatter.format(trade.satsAmount)} sats',
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
                ),
                SizedBox(height: 12.h),

                // Payment method
                Row(
                  children: [
                    Icon(Icons.account_balance, color: Colors.grey[500], size: 16.sp),
                    SizedBox(width: 8.w),
                    Text(
                      trade.paymentMethod,
                      style: TextStyle(color: Colors.grey[400], fontSize: 13.sp),
                    ),
                  ],
                ),

                // Payment proof indicator (if buyer submitted proof)
                if (trade.proofImagePaths.isNotEmpty) ...[
                  SizedBox(height: 12.h),
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.receipt_long, color: Colors.blue, size: 18.sp),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'Buyer submitted payment proof',
                            style: TextStyle(color: Colors.blue, fontSize: 12.sp),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            // TODO: Show proof image viewer
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Proof viewer coming soon')),
                            );
                          },
                          child: Text('View', style: TextStyle(color: Colors.blue)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Action Buttons
          if (isActive)
            Container(
              padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
              child: Row(
                children: [
                  // Chat button (expanded)
                  if (widget.offer != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _openChat,
                        icon: Icon(Icons.chat, size: 18.sp),
                        label: Text('Chat'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: BorderSide(color: Colors.orange.withOpacity(0.5)),
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        ),
                      ),
                    ),
                  
                  if (widget.offer != null && (showConfirmButton || showReleaseButton))
                    SizedBox(width: 12.w),

                  // Confirm Payment button
                  if (showConfirmButton && !showReleaseButton)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isConfirmingPayment ? null : _confirmPaymentReceived,
                        icon: _isConfirmingPayment
                            ? SizedBox(
                                width: 18.sp,
                                height: 18.sp,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(Icons.check, size: 18.sp),
                        label: Text(_isConfirmingPayment ? 'Confirming...' : 'Confirm Payment'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        ),
                      ),
                    ),

                  // Release Funds button
                  if (showReleaseButton)
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _isReleasingFunds ? null : _releaseFunds,
                        icon: _isReleasingFunds
                            ? SizedBox(
                                width: 18.sp,
                                height: 18.sp,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(Icons.send, size: 18.sp),
                        label: Text(_isReleasingFunds ? 'Releasing...' : 'Release ₿ to Buyer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // Activity timeline for completed/cancelled trades
          if (!isActive)
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
              child: Row(
                children: [
                  Icon(Icons.access_time, color: Colors.grey[600], size: 14.sp),
                  SizedBox(width: 6.w),
                  Text(
                    _getCompletionTime(),
                    style: TextStyle(color: Colors.grey[500], fontSize: 12.sp),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _getCompletionTime() {
    final completedAt = widget.trade.completedAt ?? widget.trade.cancelledAt;
    if (completedAt == null) return '';
    
    final duration = completedAt.difference(widget.trade.createdAt);
    if (duration.inMinutes < 1) {
      return 'Completed in ${duration.inSeconds}s';
    } else if (duration.inHours < 1) {
      return 'Completed in ${duration.inMinutes}m';
    } else {
      return 'Completed in ${duration.inHours}h ${duration.inMinutes % 60}m';
    }
  }
}
