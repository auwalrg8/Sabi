import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import '../providers/cash_provider.dart';

class SellSuccessScreen extends ConsumerWidget {
  const SellSuccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cashState = ref.watch(cashProvider);
    final formatter = NumberFormat('#,###');
    final latestTransaction = cashState.transactions.isNotEmpty
        ? cashState.transactions.first
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 21, vertical: 69.5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
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
                    '${formatter.format(latestTransaction?.amountSats ?? 0)} sats received!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      height: 1.67,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 17,
                        color: AppColors.textTertiary,
                        fontFamily: 'Inter',
                      ),
                      children: [
                        TextSpan(
                          text: '₦${formatter.format(cashState.amountToReceive.toInt())}',
                          style: const TextStyle(fontSize: 15),
                        ),
                        const TextSpan(text: ' in on the road to your bank'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(20),
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
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Expected arrival',
                                    style: TextStyle(
                                      color: AppColors.textTertiary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const Text(
                                    'Within 2–5 minutes',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          height: 1,
                          color: const Color(0xFF1F2937),
                        ),
                        const SizedBox(height: 15),
                        _buildDetailRow(
                          'Bitcoin sent',
                          '${formatter.format(latestTransaction?.amountSats ?? 0)} sats',
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          'Naira to receive',
                          '₦${formatter.format(cashState.amountToReceive.toInt())}',
                          isHighlighted: true,
                        ),
                        const SizedBox(height: 8),
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
                    width: 350,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Sell Again',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Receipt sharing functionality'),
                          backgroundColor: AppColors.accentGreen,
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.share,
                      color: Color(0xCCFFFFFF),
                      size: 16,
                    ),
                    label: const Text(
                      'Share Receipt',
                      style: TextStyle(
                        color: Color(0xCCFFFFFF),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: 350,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 14,
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

  Widget _buildDetailRow(String label, String value,
      {bool isHighlighted = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isHighlighted ? AppColors.accentGreen : Colors.white,
            fontSize: 12,
            fontWeight: isHighlighted ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
