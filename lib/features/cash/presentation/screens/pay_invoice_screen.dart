import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import '../providers/cash_provider.dart';
import 'sell_success_screen.dart';

class PayInvoiceScreen extends ConsumerStatefulWidget {
  const PayInvoiceScreen({super.key});

  @override
  ConsumerState<PayInvoiceScreen> createState() => _PayInvoiceScreenState();
}

class _PayInvoiceScreenState extends ConsumerState<PayInvoiceScreen> {
  int _remainingSeconds = 886;
  Timer? _timer;
  bool _isPaying = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
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

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _payFromSabiBalance() async {
    setState(() {
      _isPaying = true;
    });

    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    await ref.read(cashProvider.notifier).processPayment();

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const SellSuccessScreen()),
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
              padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 30.h),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _isPaying ? null : () => Navigator.pop(context),
                    child: Container(
                      width: 24.w,
                      height: 24.h,
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                      ),
                      child: Icon(
                        Icons.arrow_back,
                        color: _isPaying ? Colors.grey : Colors.white,
                        size: 24.sp,
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pay Invoice',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 17.w,
                        vertical: 17.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x1A111128),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFF4D4F)),
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
                            color: Color(0xFFFF4D4F),
                            size: 20.sp,
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Column(
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
                                    color: Color(0xFFFF4D4F),
                                    fontSize: 17.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
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
                          Text(
                            'Send',
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 12.sp,
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            formatter.format(cashState.bitcoinToSell),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 31.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'sats',
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 14.sp,
                            ),
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
                              horizontal: 13.w,
                              vertical: 13.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(
                                color: AppColors.primary,
                                width: 4.w,
                              ),
                            ),
                            child: Container(
                              width: 230.w,
                              height: 230.h,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Stack(
                                children: [
                                  Center(
                                    child: Icon(
                                      Icons.qr_code,
                                      size: 150.sp,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Center(
                                    child: Container(
                                      width: 60.w,
                                      height: 60.h,
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.currency_bitcoin,
                                        color: Colors.white,
                                        size: 30.sp,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 16.h),
                          Text(
                            'Scan with any Lightning wallet',
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 12.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 17.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 16.h,
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Lightning Invoice',
                                style: TextStyle(
                                  color: AppColors.textTertiary,
                                  fontSize: 12.sp,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(
                                    const ClipboardData(
                                      text:
                                          'lnbc617000n1pjk2x3xpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypqdqqcqzpgxqyz5vqsp5zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zygs9qyyssqzjqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypq',
                                    ),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Invoice copied',
                                        style: TextStyle(
                                          color: AppColors.surface,
                                        ),
                                      ),
                                      backgroundColor: AppColors.accentGreen,
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.w,
                                    vertical: 8.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Icon(
                                    Icons.copy,
                                    color: AppColors.textTertiary,
                                    size: 18.sp,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            'lnbc617000n1pjk2x3xpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypqdqqcqzpgxqyz5vqsp5zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zygs9qyyssqzjqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypq',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.sp,
                              height: 1.6,
                            ),
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
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52.h,
                    child: ElevatedButton(
                      onPressed: _isPaying ? null : _payFromSabiBalance,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isPaying
                                ? const Color(0xFF814F1A)
                                : AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                      ),
                      child: Text(
                        _isPaying ? 'Paying...' : 'Pay from Sabi Balance',
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
                    'Or scan QR with external wallet',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 10.sp),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
