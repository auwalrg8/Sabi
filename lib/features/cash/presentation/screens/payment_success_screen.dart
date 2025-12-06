import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import '../providers/cash_provider.dart';

class PaymentSuccessScreen extends ConsumerWidget {
  const PaymentSuccessScreen({super.key});

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
          padding: const EdgeInsets.symmetric(horizontal: 21),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 128,
                height: 128,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentGreen.withValues(alpha: 0.2),
                ),
                child: const Icon(
                  Icons.check,
                  size: 80,
                  color: AppColors.accentGreen,
                ),
              ),
              const SizedBox(height: 30),
              Text(
                '₦${formatter.format(cashState.selectedAmount.toInt())} received!',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  height: 1.67,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                '${formatter.format(latestTransaction?.amountSats ?? 0)} sats landed in your wallet',
                style: const TextStyle(
                  fontSize: 17,
                  color: AppColors.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              Container(
                width: 364,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
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
                    _buildDetailRow(
                      'Amount paid',
                      '₦${formatter.format(cashState.selectedAmount.toInt())}',
                      isValue: true,
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      'Bitcoin received',
                      '${formatter.format(latestTransaction?.amountSats ?? 0)} sats',
                      isValue: true,
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      'Time',
                      _formatTime(
                        latestTransaction?.timestamp ?? DateTime.now(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      'Reference',
                      latestTransaction?.reference ?? 'SAB-BUY-9K2M7P',
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Column(
                children: [
                  SizedBox(
                    width: 350,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Buy Again',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextButton.icon(
                    onPressed: () {
                      _shareReceipt(context, latestTransaction);
                    },
                    icon: const Icon(
                      Icons.share,
                      color: Color(0xCCFFFFFF),
                      size: 16,
                    ),
                    label: const Text(
                      'Share Receipt',
                      style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: 350,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isValue = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textTertiary,
            fontSize: isValue ? 14 : 12,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isValue ? AppColors.accentGreen : Colors.white,
            fontSize: isValue ? 14 : 12,
            fontWeight: isValue ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _shareReceipt(BuildContext context, dynamic transaction) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Receipt sharing functionality'),
        backgroundColor: AppColors.accentGreen,
      ),
    );
  }
}
