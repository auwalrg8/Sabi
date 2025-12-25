import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';
import 'package:sabi_wallet/services/rate_service.dart';
import 'package:sabi_wallet/services/receipt_service.dart';
import 'package:sabi_wallet/core/utils/date_utils.dart' as date_utils;
import 'package:sabi_wallet/l10n/app_localizations.dart';

class PaymentDetailScreen extends StatefulWidget {
  final PaymentRecord payment;

  const PaymentDetailScreen({super.key, required this.payment});

  @override
  State<PaymentDetailScreen> createState() => _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends State<PaymentDetailScreen> {
  double? _btcToNgnRate;
  final GlobalKey _receiptKey = GlobalKey();
  bool _isSharing = false;

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

  Future<void> _shareAsImage() async {
    setState(() => _isSharing = true);
    try {
      await ReceiptService.shareAsImage(
        _receiptKey,
        subject: 'Sabi Wallet Payment Receipt',
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _shareAsPdf() async {
    setState(() => _isSharing = true);
    try {
      final isInbound = widget.payment.isIncoming;
      final nairaAmount =
          _btcToNgnRate != null
              ? (widget.payment.amountSats / 100000000 * _btcToNgnRate!)
              : null;
      final data = ReceiptData(
        type: isInbound ? 'receive' : 'send',
        recipientName:
            isInbound
                ? 'You'
                : (widget.payment.description.isNotEmpty
                    ? widget.payment.description
                    : 'Unknown'),
        recipientIdentifier: widget.payment.bolt11 ?? '',
        amountSats: widget.payment.amountSats,
        amountNgn: nairaAmount,
        feeSats: widget.payment.feeSats,
        memo:
            widget.payment.description.isNotEmpty
                ? widget.payment.description
                : null,
        timestamp: DateTime.fromMillisecondsSinceEpoch(widget.payment.paymentTime * 1000),
        transactionId: widget.payment.id,
      );
      await ReceiptService.shareAsPdf(data);
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  void _showShareOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.shareOptionsTitle,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 12.h),
              _buildShareOption(
                icon: Icons.image_rounded,
                title: AppLocalizations.of(context)!.shareImage,
                subtitle: AppLocalizations.of(context)!.shareImageSubtitle,
                onTap: () {
                  Navigator.pop(context);
                  _shareAsImage();
                },
              ),
              SizedBox(height: 8.h),
              _buildShareOption(
                icon: Icons.picture_as_pdf_rounded,
                title: AppLocalizations.of(context)!.sharePdf,
                subtitle: AppLocalizations.of(context)!.sharePdfSubtitle,
                onTap: () {
                  Navigator.pop(context);
                  _shareAsPdf();
                },
              ),
              SizedBox(height: 16.h),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShareOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 48.w,
                height: 48.h,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(icon, color: AppColors.primary, size: 24.sp),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.textSecondary,
                size: 16.sp,
              ),
            ],
          ),
        ),
      ),
    );
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
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20.h),
                    child: RepaintBoundary(
                      key: _receiptKey,
                      child: Container(
                        color: AppColors.background,
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
                                  Divider(
                                    color: AppColors.textSecondary,
                                    height: 32.h,
                                  ),
                                  _buildDetailRow(
                                    'Type',
                                    typeText,
                                    isInbound
                                        ? Icons.call_received
                                        : Icons.call_made,
                                    AppColors.textSecondary,
                                  ),
                                  Divider(
                                    color: AppColors.textSecondary,
                                    height: 32.h,
                                  ),
                                  _buildDetailRow(
                                    'Time',
                                    date_utils.formatFullDateTime(
                                      widget.payment.paymentTime,
                                    ),
                                    Icons.access_time,
                                    AppColors.textSecondary,
                                  ),
                                  Divider(
                                    color: AppColors.textSecondary,
                                    height: 32.h,
                                  ),
                                  _buildDetailRow(
                                    'Amount',
                                    '${widget.payment.amountSats} sats',
                                    Icons.bolt,
                                    AppColors.textSecondary,
                                  ),
                                  if (_btcToNgnRate != null) ...[
                                    Padding(
                                      padding: EdgeInsets.only(
                                        left: 40.w,
                                        top: 4.h,
                                      ),
                                      child: Text(
                                        _getNairaValue(
                                          widget.payment.amountSats,
                                        ),
                                        style: TextStyle(
                                          color: AppColors.textSecondary
                                              .withValues(alpha: 0.7),
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                  Divider(
                                    color: AppColors.textSecondary,
                                    height: 32.h,
                                  ),
                                  _buildDetailRow(
                                    'Fees',
                                    '${widget.payment.feeSats} sats',
                                    Icons.receipt,
                                    AppColors.textSecondary,
                                  ),
                                  if (_btcToNgnRate != null &&
                                      widget.payment.feeSats > 0) ...[
                                    Padding(
                                      padding: EdgeInsets.only(
                                        left: 40.w,
                                        top: 4.h,
                                      ),
                                      child: Text(
                                        _getNairaValue(widget.payment.feeSats),
                                        style: TextStyle(
                                          color: AppColors.textSecondary
                                              .withValues(alpha: 0.7),
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (widget
                                      .payment
                                      .description
                                      .isNotEmpty) ...[
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
                                    _buildInvoiceRow(
                                      context,
                                      widget.payment.bolt11!,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              'Powered by Sabi Wallet',
                              style: TextStyle(
                                color: AppColors.textSecondary.withValues(
                                  alpha: 0.6,
                                ),
                                fontSize: 11.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Share button
                Container(
                  padding: EdgeInsets.all(20.h),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52.h,
                    child: OutlinedButton(
                      onPressed:
                          _isSharing
                              ? null
                              : () {
                                HapticFeedback.lightImpact();
                                _showShareOptions();
                              },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.share_rounded,
                            color: AppColors.primary,
                            size: 18.sp,
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            AppLocalizations.of(context)!.shareReceipt,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Loading overlay
          if (_isSharing)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: Center(
                child: Container(
                  padding: EdgeInsets.all(24.r),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppColors.primary),
                      SizedBox(height: 16.h),
                      Text(
                        'Generating receipt...',
                        style: TextStyle(color: Colors.white, fontSize: 14.sp),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
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
