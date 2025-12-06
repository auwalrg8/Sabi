import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/features/wallet/domain/models/send_transaction.dart';

class SendSuccessScreen extends StatelessWidget {
  final SendTransaction transaction;

  const SendSuccessScreen({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            _buildAnimatedDots(),
            Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(30, 60, 30, 30),
                    child: Column(
                      children: [
                        _buildSuccessIcon(),
                        const SizedBox(height: 30),
                        _buildTitle(),
                        const SizedBox(height: 30),
                        _buildDetailsCard(),
                      ],
                    ),
                  ),
                ),
                _buildDoneButton(context),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedDots() {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: DotsPainter(),
        ),
      ),
    );
  }

  Widget _buildSuccessIcon() {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: AppColors.accentGreen.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.check_circle_outline,
        color: AppColors.accentGreen,
        size: 48,
      ),
    );
  }

  Widget _buildTitle() {
    return const Column(
      children: [
        Text(
          'Sent!',
          style: TextStyle(
            color: AppColors.accentGreen,
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Payment successful',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsCard() {
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
          _buildRecipientInfo(),
          const Divider(color: AppColors.background, height: 40),
          _buildTransactionDetails(),
          const SizedBox(height: 24),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildRecipientInfo() {
    return Column(
      children: [
        const Text(
          'Paid to',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          transaction.recipient.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          transaction.recipient.identifier,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionDetails() {
    return Column(
      children: [
        _buildDetailRow('Amount', '₦${transaction.amount.toStringAsFixed(0)}'),
        const SizedBox(height: 12),
        _buildDetailRow('Time', '23 Nov 2025, 19:22'),
        const SizedBox(height: 12),
        _buildTransactionIdRow(),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionIdRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Transaction ID',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        GestureDetector(
          onTap: () {
            Clipboard.setData(const ClipboardData(text: 'abc123...'));
          },
          child: Row(
            children: [
              const Text(
                'abc123...',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 10,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.copy,
                color: AppColors.primary,
                size: 14,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.share, size: 16),
            label: const Text('Share Receipt'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.flash_on, size: 16),
            label: const Text('Zap 210 sats'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDoneButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(30, 0, 30, 30),
      child: SizedBox(
        width: double.infinity,
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
            'Done',
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

class DotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accentGreen
      ..style = PaintingStyle.fill;

    final positions = [
      Offset(size.width * 0.91, size.height * 0.21),
      Offset(size.width * 0.86, size.height * 0.02),
      Offset(size.width * 0.24, size.height * 0.53),
      Offset(size.width * 0.97, size.height * 0.97),
      Offset(size.width * 0.73, size.height * 0.16),
      Offset(size.width * 0.11, size.height * 0.63),
      Offset(size.width * 0.28, size.height * 0.80),
      Offset(size.width * 0.41, size.height * 0.97),
    ];

    for (final pos in positions) {
      canvas.drawCircle(pos, 8, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
