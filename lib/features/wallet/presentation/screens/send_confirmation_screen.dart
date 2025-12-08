import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/features/wallet/domain/models/send_transaction.dart';
import 'package:sabi_wallet/features/wallet/presentation/screens/send_progress_screen.dart';

class SendConfirmationScreen extends StatelessWidget {
  final SendTransaction transaction;

  const SendConfirmationScreen({super.key, required this.transaction});

  void _sendNow(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SendProgressScreen(transaction: transaction),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(30.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 25.sp,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        SizedBox(width: 10.w),
                        Text(
                          'Confirm',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 30.h),
                    _buildConfirmationCard(),
                  ],
                ),
              ),
            ),
            _buildSendButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmationCard() {
    return Container(
      padding: EdgeInsets.all(24.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildRow(
            'To',
            transaction.recipient.name,
            transaction.recipient.identifier,
          ),
          SizedBox(height: 16.h),
          _buildRow(
            'Amount',
            '₦${transaction.amount.toStringAsFixed(0)}',
            '~ ${transaction.amountInSats.toStringAsFixed(0)} sats',
          ),
          SizedBox(height: 16.h),
          _buildFeeRow(),
          Divider(color: AppColors.surface, height: 32.h),
          _buildTotalRow(),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, String subtitle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14.h),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              subtitle,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeeRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Fee',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
        ),
        Text(
          '${transaction.feeInSats.toStringAsFixed(0)} sats (~₦${transaction.fee.toStringAsFixed(0)})',
          style: TextStyle(color: AppColors.accentGreen, fontSize: 12.sp),
        ),
      ],
    );
  }

  Widget _buildTotalRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Total',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          '₦${transaction.total.toStringAsFixed(0)}',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildSendButton(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(30.w, 0, 30.w, 30.h),
      child: SizedBox(
        width: double.infinity,
        height: 50.h,
        child: ElevatedButton(
          onPressed: () => _sendNow(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
          ),
          child: Text(
            'Send now',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
