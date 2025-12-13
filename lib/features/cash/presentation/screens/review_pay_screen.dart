import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:intl/intl.dart';
import '../providers/cash_provider.dart';
import 'payment_processing_screen.dart';

class ReviewPayScreen extends ConsumerStatefulWidget {
  const ReviewPayScreen({super.key});

  @override
  ConsumerState<ReviewPayScreen> createState() => _ReviewPayScreenState();
}

class _ReviewPayScreenState extends ConsumerState<ReviewPayScreen> {
  Timer? _timer;
  int _remainingSeconds = 15 * 60;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$label copied to clipboard',
          style: TextStyle(color: AppColors.surface),
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.accentGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cashState = ref.watch(cashProvider);
    final formatter = NumberFormat('#,###');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(16.h),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    'Review & Pay',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 30.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 17.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 17.w,
                        vertical: 17.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x1A111128),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: AppColors.accentRed),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x26000000),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            color: AppColors.accentRed,
                            size: 20.sp,
                          ),
                          SizedBox(width: 12.w),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Complete payment in',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                _formatTime(_remainingSeconds),
                                style: TextStyle(
                                  color: AppColors.accentRed,
                                  fontSize: 17.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 17.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20.w,
                        vertical: 20.h,
                      ),
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
                          _buildRow(
                            'You pay',
                            '₦${formatter.format(cashState.totalToPay.toInt())}',
                            isTitle: true,
                          ),
                          _buildRow(
                            'You get',
                            '~${formatter.format(cashState.estimatedSats)} sats',
                            valueColor: AppColors.accentGreen,
                            isTitle: true,
                          ),
                          _buildRow(
                            'Fee',
                            '₦${formatter.format(cashState.fee.toInt())}',
                            valueSize: 12,
                            labelColor: const Color(0xFF6B7280),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 17.h),
                    Text(
                      'Payment Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 17.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20.w,
                        vertical: 20.h,
                      ),
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
                        spacing: 16.h,
                        children: [
                          _buildPaymentDetail(context, 'Bank', 'GTBank', false),
                          _buildPaymentDetail(
                            context,
                            'Account Number',
                            '069 420 1337',
                            false,
                          ),
                          _buildPaymentDetail(
                            context,
                            'Account Name',
                            'Sabi Wallet Limited',
                            false,
                          ),
                          const Divider(height: 1, color: Color(0xFF1F2937)),
                          _buildPaymentDetail(
                            context,
                            'Reference',
                            cashState.currentReference ?? 'SAB-BUY-9K2M7P',
                            true,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 17.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24.w,
                        vertical: 24.h,
                      ),
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
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 36.w,
                              vertical: 36.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                            child: Icon(
                              Icons.qr_code_2,
                              size: 120.sp,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                          SizedBox(height: 12.h),
                          Text(
                            'Scan with GTBank or Opay app',
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 12.sp,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 30.h),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(31.w, 0, 31.w, 30.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52.h,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => const PaymentProcessingScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                      ),
                      child: Text(
                        'I Have Paid',
                        style: TextStyle(
                          color: AppColors.surface,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    'Upload proof of payment after clicking',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10.sp,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(
    String label,
    String value, {
    Color? valueColor,
    Color? labelColor,
    double? valueSize,
    bool isTitle = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: labelColor ?? AppColors.textTertiary,
            fontSize: isTitle ? 14.sp : 12.sp,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: valueSize ?? (isTitle ? 17.sp : 12.sp),
            fontWeight: isTitle ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentDetail(
    BuildContext context,
    String label,
    String value,
    bool isHighlighted,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: AppColors.textTertiary, fontSize: 12.sp),
            ),
            SizedBox(height: 4.h),
            Text(
              value,
              style: TextStyle(
                color: isHighlighted ? AppColors.primary : Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        IconButton(
          onPressed: () => _copyToClipboard(context, value, label),
          icon: Icon(
            Icons.copy,
            size: 18.sp,
            color: isHighlighted ? AppColors.primary : AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}
