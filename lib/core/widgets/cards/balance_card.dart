// lib/core/widgets/cards/balance_card.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sabi_wallet/core/constants/colors.dart';

class BalanceCard extends StatefulWidget {
  final double balanceBtc;
  final double balanceNgn;
  final bool showConfetti;

  const BalanceCard({
    super.key,
    required this.balanceBtc,
    required this.balanceNgn,
    this.showConfetti = false,
  });

  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard>
    with SingleTickerProviderStateMixin {
  bool _showSats = false;
  late AnimationController _flipController;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    
    if (widget.showConfetti) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        HapticFeedback.heavyImpact();
      });
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _toggleBalance() {
    setState(() => _showSats = !_showSats);
    _flipController.forward(from: 0);
    HapticFeedback.mediumImpact();
  }

  String _formatNgn(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
  }

  String _formatSats(double btc) {
    final sats = (btc * 100000000).toInt();
    return sats.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onLongPress: _toggleBalance,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with "Total Balance" text only
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Balance',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    // Eye icon removed as per design
                  ],
                ),
                const SizedBox(height: 16),
                // Main balance - huge NGN or SATS (56px as requested)
                AnimatedBuilder(
                  animation: _flipController,
                  builder: (context, child) {
                    final angle = _flipController.value * 3.14159;
                    final transform = Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateX(angle);

                    return Transform(
                      transform: transform,
                      alignment: Alignment.center,
                      child: _flipController.value < 0.5
                          ? _buildNgnBalance()
                          : Transform(
                              transform: Matrix4.rotationX(3.14159),
                              alignment: Alignment.center,
                              child: _buildSatsBalance(),
                            ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                // Show "Syncing..." if balance is 0, otherwise show BTC amount
                widget.balanceBtc == 0.0
                    ? const Text(
                        'Syncing...',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    : Text(
                        '≈ ${widget.balanceBtc.toStringAsFixed(5)} BTC',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNgnBalance() {
    return Text(
      '₦${_formatNgn(widget.balanceNgn)}',
      key: const ValueKey('ngn'),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 56, // Increased from 48 to 56px as requested
        fontWeight: FontWeight.w700,
        height: 1.0,
      ),
    );
  }

  Widget _buildSatsBalance() {
    return Text(
      '${_formatSats(widget.balanceBtc)} sats',
      key: const ValueKey('sats'),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 56, // Increased from 48 to 56px as requested
        fontWeight: FontWeight.w700,
        height: 1.0,
      ),
    );
  }
}