import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import '../data/p2p_state.dart';

/// Visual trade status progress bar
class TradeStatusBar extends StatelessWidget {
  final TradeStatus status;

  const TradeStatusBar({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getStatusIcon(status),
                color: _getStatusColor(status),
                size: 18.sp,
              ),
              SizedBox(width: 8.w),
              Text(
                _getStatusLabel(status),
                style: TextStyle(
                  color: _getStatusColor(status),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          
          // Progress indicator
          Row(
            children: [
              _buildStep(0, 'Requested', _getStepState(0)),
              _buildConnector(_getStepState(0) >= 1),
              _buildStep(1, 'Payment', _getStepState(1)),
              _buildConnector(_getStepState(1) >= 1),
              _buildStep(2, 'Confirmed', _getStepState(2)),
              _buildConnector(_getStepState(2) >= 1),
              _buildStep(3, 'Complete', _getStepState(3)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep(int index, String label, int state) {
    // state: 0 = pending, 1 = current, 2 = completed
    Color bgColor;
    Color textColor;
    IconData? icon;

    if (state == 2) {
      bgColor = AppColors.accentGreen;
      textColor = AppColors.accentGreen;
      icon = Icons.check;
    } else if (state == 1) {
      bgColor = AppColors.primary;
      textColor = AppColors.primary;
      icon = null;
    } else {
      bgColor = AppColors.textTertiary.withOpacity(0.3);
      textColor = AppColors.textTertiary;
      icon = null;
    }

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 24.w,
            height: 24.h,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: icon != null
                  ? Icon(icon, color: Colors.white, size: 14.sp)
                  : Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 10.sp,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildConnector(bool isActive) {
    return Container(
      height: 2.h,
      width: 20.w,
      margin: EdgeInsets.only(bottom: 16.h),
      color: isActive ? AppColors.accentGreen : AppColors.textTertiary.withOpacity(0.3),
    );
  }

  int _getStepState(int step) {
    // Returns: 0 = pending, 1 = current, 2 = completed
    final statusIndex = _getStatusIndex(status);
    
    if (step < statusIndex) return 2; // completed
    if (step == statusIndex) return 1; // current
    return 0; // pending
  }

  int _getStatusIndex(TradeStatus status) {
    switch (status) {
      case TradeStatus.requested:
        return 0;
      case TradeStatus.awaitingPayment:
      case TradeStatus.paymentSent:
        return 1;
      case TradeStatus.paymentConfirmed:
      case TradeStatus.releasing:
        return 2;
      case TradeStatus.completed:
        return 4; // All completed
      case TradeStatus.cancelled:
      case TradeStatus.disputed:
      case TradeStatus.expired:
        return -1; // Special state
    }
  }

  IconData _getStatusIcon(TradeStatus status) {
    switch (status) {
      case TradeStatus.requested:
        return Icons.hourglass_empty;
      case TradeStatus.awaitingPayment:
        return Icons.payment;
      case TradeStatus.paymentSent:
        return Icons.send;
      case TradeStatus.paymentConfirmed:
        return Icons.check_circle_outline;
      case TradeStatus.releasing:
        return Icons.currency_bitcoin;
      case TradeStatus.completed:
        return Icons.check_circle;
      case TradeStatus.cancelled:
        return Icons.cancel;
      case TradeStatus.disputed:
        return Icons.warning;
      case TradeStatus.expired:
        return Icons.timer_off;
    }
  }

  Color _getStatusColor(TradeStatus status) {
    switch (status) {
      case TradeStatus.requested:
      case TradeStatus.awaitingPayment:
        return AppColors.accentYellow;
      case TradeStatus.paymentSent:
      case TradeStatus.paymentConfirmed:
      case TradeStatus.releasing:
        return AppColors.primary;
      case TradeStatus.completed:
        return AppColors.accentGreen;
      case TradeStatus.cancelled:
      case TradeStatus.disputed:
        return AppColors.accentRed;
      case TradeStatus.expired:
        return AppColors.textTertiary;
    }
  }

  String _getStatusLabel(TradeStatus status) {
    switch (status) {
      case TradeStatus.requested:
        return 'Trade Requested';
      case TradeStatus.awaitingPayment:
        return 'Awaiting Payment';
      case TradeStatus.paymentSent:
        return 'Payment Sent';
      case TradeStatus.paymentConfirmed:
        return 'Payment Confirmed';
      case TradeStatus.releasing:
        return 'Releasing Bitcoin';
      case TradeStatus.completed:
        return 'Trade Completed';
      case TradeStatus.cancelled:
        return 'Trade Cancelled';
      case TradeStatus.disputed:
        return 'Trade Disputed';
      case TradeStatus.expired:
        return 'Trade Expired';
    }
  }
}
