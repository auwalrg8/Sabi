import 'package:flutter/material.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/features/wallet/domain/models/transaction.dart';

class TransactionItem extends StatelessWidget {
  final Transaction transaction;

  const TransactionItem({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isIncoming = transaction.type == 'receive';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  isIncoming
                      ? AppColors.accentGreen.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isIncoming ? Icons.download : Icons.send,
              color: isIncoming ? AppColors.accentGreen : Colors.red,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        transaction.counterparty ?? 'Unknown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Text(
                      '${transaction.amountBtc.toStringAsFixed(6)} ₿',
                      style: TextStyle(
                        color: isIncoming ? AppColors.accentGreen : Colors.red,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Text(
                  '₦${transaction.amountNgn.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${transaction.date.hour}:${transaction.date.minute.toString().padLeft(2, '0')}',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
