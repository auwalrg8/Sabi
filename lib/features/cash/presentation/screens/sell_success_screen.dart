import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/features/cash/presentation/providers/cash_provider.dart';

class SellSuccessScreen extends ConsumerWidget {
  const SellSuccessScreen({super.key});

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
          padding: EdgeInsets.symmetric(horizontal: 21.w, vertical: 69.5.h),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  Container(
                    width: 128.w,
                    height: 128.h,
                    padding: EdgeInsets.all(24.w),
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
                    '${formatter.format(latestTransaction?.amountSats ?? 0)} sats received !',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w700,
                      height: 1.67,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 10.h),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 17.sp,
                        color: AppColors.textTertiary,
                        fontFamily: 'Inter',
                      ),
                      children: [
                        TextSpan(
                          text:
                              '₦ ${formatter.format(cashState.amountToReceive.toInt())}',
                          style: TextStyle(fontSize: 15.sp),
                        ),
                        TextSpan(text: ' on the road to your bank'),
                      ],
                    ),
                  ),
                  SizedBox(height: 30.h),
                  Container(
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0x26000000),
                          blurRadius: 8.r,
                          offset: Offset(0, 4.h),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              color: AppColors.primary,
                              size: 20.sp,
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                spacing: 2.h,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Expected arrival',
                                    style: TextStyle(
                                      color: AppColors.textTertiary,
                                      fontSize: 13.sp,
                                    ),
                                  ),
                                  Text(
                                    'Within 2 – 5 minutes',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16.h),
                        Divider(height: 1.h, color: const Color(0xFF1F2937)),
                        SizedBox(height: 15.h),
                        _buildDetailRow(
                          'Bitcoin sent',
                          '${formatter.format(latestTransaction?.amountSats ?? 0)} sats',
                        ),
                        SizedBox(height: 8.h),
                        _buildDetailRow(
                          'Naira to receive',
                          '₦${formatter.format(cashState.amountToReceive.toInt())}',
                          isHighlighted: true,
                        ),
                        SizedBox(height: 8.h),
                        _buildDetailRow(
                          'Bank account',
                          cashState.accountNumber ?? '0707479453',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  SizedBox(
                    width: 350.w,
                    height: 52.h,
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
                        'Sell Again',
                        style: TextStyle(
                          color: AppColors.surface,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 15.h),
                  TextButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'TODO: Receipt sharing functionality',
                            style: TextStyle(color: AppColors.surface),
                          ),
                          backgroundColor: AppColors.accentGreen,
                        ),
                      );
                    },
                    icon: Icon(
                      Icons.share,
                      color: const Color(0xCCFFFFFF),
                      size: 16.sp,
                    ),
                    label: Text(
                      'Share Receipt',
                      style: TextStyle(
                        color: const Color(0xCCFFFFFF),
                        fontSize: 12.sp,
                      ),
                    ),
                  ),
                  SizedBox(height: 15.h),
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
                        'Done',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isHighlighted = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: AppColors.textTertiary, fontSize: 13.sp),
        ),
        Text(
          value,
          style: TextStyle(
            color: isHighlighted ? AppColors.accentGreen : Colors.white,
            fontSize: 14.sp,
            fontWeight: isHighlighted ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
