import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import '../providers/cash_provider.dart';

class PaymentSuccessScreen extends ConsumerWidget {
  const PaymentSuccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cashState = ref.watch(cashProvider);
    final formatter = NumberFormat('#,###');
    final latestTransaction =
        cashState.transactions.isNotEmpty ? cashState.transactions.first : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 21.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 128.w,
                height: 128.h,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentGreen.withValues(alpha: 0.2),
                ),
                child: Icon(
                  Icons.check,
                  size: 80.sp,
                  color: AppColors.accentGreen,
                ),
              ),
              SizedBox(height: 30.h),
              Text(
                '₦${formatter.format(cashState.selectedAmount.toInt())} received!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w700,
                  height: 1.67,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16.h),
              Text(
                '${formatter.format(latestTransaction?.amountSats ?? 0)} sats landed in your wallet',
                style: TextStyle(
                  fontSize: 17.sp,
                  color: AppColors.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 30.h),
              Container(
                width: 364.w,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20.r),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  spacing: 12.h,
                  children: [
                    _buildDetailRow(
                      'Amount paid',
                      '₦${formatter.format(cashState.selectedAmount.toInt())}',
                      isValue: true,
                    ),
                    _buildDetailRow(
                      'Bitcoin received',
                      '${formatter.format(latestTransaction?.amountSats ?? 0)} sats',
                      isValue: true,
                    ),
                    _buildDetailRow(
                      'Time',
                      _formatTime(
                        latestTransaction?.timestamp ?? DateTime.now(),
                      ),
                    ),
                    _buildDetailRow(
                      'Reference',
                      latestTransaction?.reference ?? 'SAB-BUY-9K2M7P',
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Column(
                children: [
                  SizedBox(
                    width: 350.w,
                    height: 50.h,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                      ),
                      child: Text(
                        'Buy Again',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 15.h),
                  TextButton.icon(
                    onPressed: () {
                      _shareReceipt(context, latestTransaction);
                    },
                    icon: Icon(
                      Icons.share,
                      color: Color(0xCCFFFFFF),
                      size: 16.sp,
                    ),
                    label: Text(
                      'Share Receipt',
                      style: TextStyle(
                        color: Color(0xCCFFFFFF),
                        fontSize: 12.sp,
                      ),
                    ),
                  ),
                  SizedBox(height: 15.h),
                  SizedBox(
                    width: 350.w,
                    height: 50.h,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                      ),
                      child: Text(
                        'Done',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 30.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isValue = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textTertiary,
            fontSize: isValue ? 14.sp : 12.sp,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isValue ? AppColors.accentGreen : Colors.white,
            fontSize: isValue ? 14.sp : 12.sp,
            fontWeight: isValue ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _shareReceipt(BuildContext context, dynamic transaction) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'TODO: Receipt sharing functionality',
          style: TextStyle(color: AppColors.surface),
        ),
        backgroundColor: AppColors.accentGreen,
      ),
    );
  }
}
