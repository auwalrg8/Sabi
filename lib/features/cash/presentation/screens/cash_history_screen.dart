import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import '../../domain/models/cash_transaction.dart';
import '../providers/cash_provider.dart';

class CashHistoryScreen extends ConsumerWidget {
  const CashHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cashState = ref.watch(cashProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Cash History',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                itemCount: cashState.transactions.length,
                itemBuilder: (context, index) {
                  final transaction = cashState.transactions[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TransactionCard(transaction: transaction),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final CashTransaction transaction;

  const _TransactionCard({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isBuy = transaction.type == CashTransactionType.buy;
    final iconColor = isBuy ? AppColors.accentGreen : AppColors.accentRed;
    final iconBgColor = isBuy
        ? AppColors.accentGreen.withValues(alpha: 0.2)
        : AppColors.accentRed.withValues(alpha: 0.2);
    final formatter = NumberFormat('#,###');

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isBuy ? Icons.trending_up : Icons.trending_down,
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
                  isBuy ? 'Bought' : 'Sold',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  transaction.formattedDate,
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isBuy ? '+' : '−'}${formatter.format(transaction.amountSats)} sats',
                style: TextStyle(
                  color: isBuy ? AppColors.accentGreen : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${isBuy ? '−' : '+'}₦${formatter.format(transaction.amountNGN.toInt())}',
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
