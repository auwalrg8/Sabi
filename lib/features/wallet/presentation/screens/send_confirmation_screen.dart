import 'package:flutter/material.dart';
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
                padding: const EdgeInsets.all(30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Confirm',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
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
          _buildRow('To', transaction.recipient.name, transaction.recipient.identifier),
          const SizedBox(height: 16),
          _buildRow(
            'Amount',
            '₦${transaction.amount.toStringAsFixed(0)}',
            '~ ${transaction.amountInSats.toStringAsFixed(0)} sats',
          ),
          const SizedBox(height: 16),
          _buildFeeRow(),
          const Divider(color: AppColors.surface, height: 32),
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
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
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
        const Text(
          'Fee',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        Text(
          '${transaction.feeInSats.toStringAsFixed(0)} sats (~₦${transaction.fee.toStringAsFixed(0)})',
          style: const TextStyle(
            color: AppColors.accentGreen,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildTotalRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Total',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          '₦${transaction.total.toStringAsFixed(0)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildSendButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(30, 0, 30, 30),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: () => _sendNow(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text(
            'Send now',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
