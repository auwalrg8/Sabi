import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';
import 'package:intl/intl.dart';

class PaymentDetailScreen extends StatelessWidget {
  final PaymentRecord payment;

  const PaymentDetailScreen({super.key, required this.payment});

  @override
  Widget build(BuildContext context) {
    final isInbound = payment.isIncoming;
    final amountColor =
        isInbound ? AppColors.accentGreen : const Color(0xFFFF4D4F);
    final amountPrefix = isInbound ? '+' : '-';
    final typeText = isInbound ? 'Received' : 'Sent';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20.h),
                child: Column(
                  children: [
                    SizedBox(height: 20.h),
                    // Amount Circle
                    Container(
                      width: 120.w,
                      height: 120.h,
                      decoration: BoxDecoration(
                        color: amountColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isInbound
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                        color: amountColor,
                        size: 60.sp,
                      ),
                    ),
                    SizedBox(height: 24.h),
                    // Amount
                    Text(
                      '$amountPrefix${payment.amountSats} sats',
                      style: TextStyle(
                        color: amountColor,
                        fontSize: 36.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    // Type
                    Text(
                      typeText,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 40.h),
                    // Details Card
                    Container(
                      padding: EdgeInsets.all(20.h),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow(
                            'Status',
                            'Completed',
                            Icons.check_circle,
                            AppColors.accentGreen,
                          ),
                          Divider(color: AppColors.textSecondary, height: 32.h),
                          _buildDetailRow(
                            'Type',
                            typeText,
                            isInbound ? Icons.call_received : Icons.call_made,
                            AppColors.textSecondary,
                          ),
                          Divider(color: AppColors.textSecondary, height: 32.h),
                          _buildDetailRow(
                            'Time',
                            _formatDateTime(payment.timestamp),
                            Icons.access_time,
                            AppColors.textSecondary,
                          ),
                          Divider(color: AppColors.textSecondary, height: 32.h),
                          _buildDetailRow(
                            'Amount',
                            '${payment.amountSats} sats',
                            Icons.bolt,
                            AppColors.textSecondary,
                          ),
                          Divider(color: AppColors.textSecondary, height: 32.h),
                          _buildDetailRow(
                            'Fees',
                            '${payment.feeSats} sats',
                            Icons.receipt,
                            AppColors.textSecondary,
                          ),
                          if (payment.description.isNotEmpty) ...[
                            Divider(
                              color: AppColors.textSecondary,
                              height: 32.h,
                            ),
                            _buildDetailRow(
                              'Description',
                              payment.description,
                              Icons.description,
                              AppColors.textSecondary,
                            ),
                          ],
                          if (payment.bolt11 != null &&
                              payment.bolt11!.isNotEmpty) ...[
                            Divider(
                              color: AppColors.textSecondary,
                              height: 32.h,
                            ),
                            _buildInvoiceRow(context, payment.bolt11!),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
          SizedBox(width: 16.w),
          Text(
            'Payment Details',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    return Row(
      children: [
        Container(
          width: 40.w,
          height: 42.h,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Icon(icon, color: iconColor, size: 20.sp),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInvoiceRow(BuildContext context, String invoice) {
    return Row(
      children: [
        Container(
          width: 40.w,
          height: 42.h,
          decoration: BoxDecoration(
            color: AppColors.textSecondary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.receipt_long,
            color: AppColors.textSecondary,
            size: 20.sp,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Invoice',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                '${invoice.substring(0, 20)}...${invoice.substring(invoice.length - 20)}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 8.w),
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: invoice));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Invoice copied to clipboard'),
                backgroundColor: AppColors.accentGreen,
                duration: Duration(seconds: 2),
              ),
            );
          },
          child: Container(
            padding: EdgeInsets.all(8.h),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(Icons.copy, color: AppColors.primary, size: 18.sp),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final paymentDate = DateTime(dt.year, dt.month, dt.day);

    final timeFormat = DateFormat('h:mm a');
    final dateFormat = DateFormat('MMM d, yyyy');

    if (paymentDate == today) {
      return 'Today, ${timeFormat.format(dt)}';
    } else if (paymentDate == yesterday) {
      return 'Yesterday, ${timeFormat.format(dt)}';
    } else {
      return '${dateFormat.format(dt)}, ${timeFormat.format(dt)}';
    }
  }
}
