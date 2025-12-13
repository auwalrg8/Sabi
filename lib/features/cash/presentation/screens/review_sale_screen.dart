import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/features/cash/presentation/providers/cash_provider.dart';
import 'pay_invoice_screen.dart';

class ReviewSaleScreen extends ConsumerWidget {
  const ReviewSaleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cashState = ref.watch(cashProvider);
    final formatter = NumberFormat('#,###');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(30.w),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 24.w,
                      height: 24.h,
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                      ),
                      child: Icon(
                        Icons.arrow_back,
                        color: Colors.white,
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
                          'Review Sale',
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
                    Text(
                      'Receiving Account',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 17.h),

                    Container(
                      padding: EdgeInsets.all(20.r),
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
                      child: Row(
                        children: [
                          Container(
                            width: 48.w,
                            height: 48.h,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 16.w),
                          Expanded(
                            child: Column(
                              spacing: 3.h,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cashState.bankName ?? 'Access Bank',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  cashState.accountNumber ?? '0707479453',
                                  style: TextStyle(
                                    color: AppColors.textTertiary,
                                    fontSize: 14.sp,
                                  ),
                                ),
                                Text(
                                  cashState.accountName ?? 'Auwal Abubakar',
                                  style: TextStyle(
                                    color: AppColors.textTertiary,
                                    fontSize: 12.sp,
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
                      padding: EdgeInsets.all(17.r),
                      decoration: BoxDecoration(
                        color: const Color(0x1A111128),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: AppColors.primary),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x26000000),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'We go generate Lightning invoice. Pay from your Sabi balance, then we send Naira to your bank within 2–5 minutes.',
                            style: TextStyle(
                              color: Color(0xFFD1D5DB),
                              fontSize: 12.sp,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 17.h),

                    Container(
                      padding: EdgeInsets.all(20.r),
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'You send',
                                style: TextStyle(
                                  color: AppColors.textTertiary,
                                  fontSize: 14.sp,
                                ),
                              ),
                              Text(
                                '~${formatter.format(cashState.bitcoinToSell)} sats',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'You receive',
                                style: TextStyle(
                                  color: AppColors.textTertiary,
                                  fontSize: 14.sp,
                                ),
                              ),
                              Text(
                                '₦${formatter.format(cashState.amountToReceive.toInt())}',
                                style: TextStyle(
                                  color: AppColors.accentGreen,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Fee',
                                style: TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 13.sp,
                                ),
                              ),
                              Text(
                                '₦${formatter.format(cashState.fee.toInt())}',
                                style: TextStyle(
                                  color: AppColors.textTertiary,
                                  fontSize: 13.sp,
                                ),
                              ),
                            ],
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
              child: SizedBox(
                width: double.infinity,
                height: 52.h,
                child: ElevatedButton(
                  onPressed: () {
                    ref.read(cashProvider.notifier).generateReference();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PayInvoiceScreen(),
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
                    'Generate Invoice',
                    style: TextStyle(
                      color: AppColors.surface,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
