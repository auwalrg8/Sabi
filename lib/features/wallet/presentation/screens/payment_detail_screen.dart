import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';
import 'package:intl/intl.dart';

class PaymentDetailScreen extends StatelessWidget {
  final PaymentRecord payment;

  const PaymentDetailScreen({
    super.key,
    required this.payment,
  });

  @override
  Widget build(BuildContext context) {
    final isInbound = payment.isIncoming;
    final amountColor = isInbound ? AppColors.accentGreen : const Color(0xFFFF4D4F);
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
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // Amount Circle
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: amountColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isInbound
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                        color: amountColor,
                        size: 60,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Amount
                    Text(
                      '$amountPrefix${payment.amountSats} sats',
                      style: TextStyle(
                        color: amountColor,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Type
                    Text(
                      typeText,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Details Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow(
                            'Status',
                            'Completed',
                            Icons.check_circle,
                            AppColors.accentGreen,
                          ),
                          const Divider(color: AppColors.textSecondary, height: 32),
                          _buildDetailRow(
                            'Type',
                            typeText,
                            isInbound ? Icons.call_received : Icons.call_made,
                            AppColors.textSecondary,
                          ),
                          const Divider(color: AppColors.textSecondary, height: 32),
                          _buildDetailRow(
                            'Time',
                            _formatDateTime(payment.timestamp),
                            Icons.access_time,
                            AppColors.textSecondary,
                          ),
                          const Divider(color: AppColors.textSecondary, height: 32),
                          _buildDetailRow(
                            'Amount',
                            '${payment.amountSats} sats',
                            Icons.bolt,
                            AppColors.textSecondary,
                          ),
                          const Divider(color: AppColors.textSecondary, height: 32),
                          _buildDetailRow(
                            'Fees',
                            '${payment.feeSats} sats',
                            Icons.receipt,
                            AppColors.textSecondary,
                          ),
                          if (payment.description.isNotEmpty) ...[
                            const Divider(color: AppColors.textSecondary, height: 32),
                            _buildDetailRow(
                              'Description',
                              payment.description,
                              Icons.description,
                              AppColors.textSecondary,
                            ),
                          ],
                          if (payment.bolt11 != null && payment.bolt11!.isNotEmpty) ...[
                            const Divider(color: AppColors.textSecondary, height: 32),
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
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'Payment Details',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, Color iconColor) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
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
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.textSecondary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.receipt_long,
            color: AppColors.textSecondary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Invoice',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${invoice.substring(0, 20)}...${invoice.substring(invoice.length - 20)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.copy,
              color: AppColors.primary,
              size: 18,
            ),
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
