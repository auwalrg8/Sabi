import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';
import 'package:sabi_wallet/services/rate_service.dart';
import 'package:sabi_wallet/core/utils/date_utils.dart' as date_utils;

class PaymentDetailScreen extends StatefulWidget {
  final PaymentRecord payment;

  const PaymentDetailScreen({super.key, required this.payment});

  @override
  State<PaymentDetailScreen> createState() => _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends State<PaymentDetailScreen> {
  double? _btcToNgnRate;

  @override
  void initState() {
    super.initState();
    _loadRate();
  }

  Future<void> _loadRate() async {
    final rate = await RateService.getBtcToNgnRate();
    if (mounted) {
      setState(() {
        _btcToNgnRate = rate;
      });
    }
  }

  String _getNairaValue(int sats) {
    if (_btcToNgnRate == null) return 'Loading...';
    final btc = sats / 100000000;
    final naira = btc * _btcToNgnRate!;
    return '₦${naira.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}';
  }

  @override
  Widget build(BuildContext context) {
    final isInbound = widget.payment.isIncoming;
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
                      '$amountPrefix${widget.payment.amountSats} sats',
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
                            date_utils.formatFullDateTime(
                              widget.payment.paymentTime,
                            ),
                            Icons.access_time,
                            AppColors.textSecondary,
                          ),
                          Divider(color: AppColors.textSecondary, height: 32.h),
                          _buildDetailRow(
                            'Amount',
                            '${widget.payment.amountSats} sats',
                            Icons.bolt,
                            AppColors.textSecondary,
                          ),
                          if (_btcToNgnRate != null) ...[
                            Padding(
                              padding: EdgeInsets.only(left: 40.w, top: 4.h),
                              child: Text(
                                _getNairaValue(widget.payment.amountSats),
                                style: TextStyle(
                                  color: AppColors.textSecondary.withValues(
                                    alpha: 0.7,
                                  ),
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                          Divider(color: AppColors.textSecondary, height: 32.h),
                          _buildDetailRow(
                            'Fees',
                            '${widget.payment.feeSats} sats',
                            Icons.receipt,
                            AppColors.textSecondary,
                          ),
                          if (_btcToNgnRate != null &&
                              widget.payment.feeSats > 0) ...[
                            Padding(
                              padding: EdgeInsets.only(left: 40.w, top: 4.h),
                              child: Text(
                                _getNairaValue(widget.payment.feeSats),
                                style: TextStyle(
                                  color: AppColors.textSecondary.withValues(
                                    alpha: 0.7,
                                  ),
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                          if (widget.payment.description.isNotEmpty) ...[
                            Divider(
                              color: AppColors.textSecondary,
                              height: 32.h,
                            ),
                            _buildDetailRow(
                              'Description',
                              widget.payment.description,
                              Icons.description,
                              AppColors.textSecondary,
                            ),
                          ],
                          if (widget.payment.bolt11 != null &&
                              widget.payment.bolt11!.isNotEmpty) ...[
                            Divider(
                              color: AppColors.textSecondary,
                              height: 32.h,
                            ),
                            _buildInvoiceRow(context, widget.payment.bolt11!),
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
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
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
}
