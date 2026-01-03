import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../data/models/models.dart';

/// Dialog to display refund invoice with QR code
class RefundDialog extends StatelessWidget {
  final VtuOrder order;
  final VoidCallback? onDismiss;

  const RefundDialog({super.key, required this.order, this.onDismiss});

  static Future<void> show(BuildContext context, VtuOrder order) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => RefundDialog(order: order),
    );
  }

  @override
  Widget build(BuildContext context) {
    final invoice = order.refundInvoice ?? '';
    final isInvoiceValid = invoice.isNotEmpty;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Container(
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          color: const Color(0xFF111128),
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(color: const Color(0xFF2A2A3E)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Refund Request',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 32.w,
                    height: 32.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      color: const Color(0xFFA1A1B2),
                      size: 18.sp,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),

            // Status badge
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: Color(order.refundStatus.color).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    order.refundStatus == RefundStatus.completed
                        ? Icons.check_circle
                        : Icons.hourglass_empty,
                    color: Color(order.refundStatus.color),
                    size: 16.sp,
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    order.refundStatus == RefundStatus.completed
                        ? 'Refund Completed'
                        : 'Awaiting Agent Payment',
                    style: TextStyle(
                      color: Color(order.refundStatus.color),
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),

            // Refund amount
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Refund Amount',
                    style: TextStyle(
                      color: const Color(0xFFA1A1B2),
                      fontSize: 14.sp,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.flash_on,
                        color: const Color(0xFFF7931A),
                        size: 18.sp,
                      ),
                      Text(
                        '${order.amountSats} sats',
                        style: TextStyle(
                          color: const Color(0xFFF7931A),
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),

            if (isInvoiceValid &&
                order.refundStatus == RefundStatus.requested) ...[
              // QR Code
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: QrImageView(
                  data: invoice,
                  version: QrVersions.auto,
                  size: 200.w,
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                ),
              ),
              SizedBox(height: 16.h),

              // Invoice text (truncated)
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Column(
                  children: [
                    Text(
                      'Lightning Invoice',
                      style: TextStyle(
                        color: const Color(0xFF6B7280),
                        fontSize: 11.sp,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      _truncateInvoice(invoice),
                      style: TextStyle(
                        color: const Color(0xFFA1A1B2),
                        fontSize: 12.sp,
                        fontFamily: 'monospace',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),

              // Copy button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _copyInvoice(context, invoice),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A2E),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      side: const BorderSide(color: Color(0xFF2A2A3E)),
                    ),
                  ),
                  icon: Icon(Icons.copy, size: 18.sp),
                  label: Text(
                    'Copy Invoice',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12.h),

              // Instructions
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7931A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: const Color(0xFFF7931A),
                      size: 18.sp,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        'Share this invoice with the agent. Once paid, your refund will be credited automatically.',
                        style: TextStyle(
                          color: const Color(0xFFA1A1B2),
                          fontSize: 12.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (order.refundStatus == RefundStatus.completed) ...[
              // Completed state
              Icon(
                Icons.check_circle,
                color: const Color(0xFF66BB6A),
                size: 64.sp,
              ),
              SizedBox(height: 16.h),
              Text(
                'Refund Received!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                '${order.amountSats} sats have been credited to your wallet',
                style: TextStyle(
                  color: const Color(0xFFA1A1B2),
                  fontSize: 14.sp,
                ),
                textAlign: TextAlign.center,
              ),
              if (order.refundCompletedAt != null) ...[
                SizedBox(height: 8.h),
                Text(
                  'Completed: ${_formatDate(order.refundCompletedAt!)}',
                  style: TextStyle(
                    color: const Color(0xFF6B7280),
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _truncateInvoice(String invoice) {
    if (invoice.length <= 40) return invoice;
    return '${invoice.substring(0, 20)}...${invoice.substring(invoice.length - 20)}';
  }

  void _copyInvoice(BuildContext context, String invoice) {
    Clipboard.setData(ClipboardData(text: invoice));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            const Text('Invoice copied to clipboard'),
          ],
        ),
        backgroundColor: const Color(0xFF66BB6A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
