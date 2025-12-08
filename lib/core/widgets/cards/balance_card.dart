import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:flutter_confetti/flutter_confetti.dart';

class BalanceCard extends StatefulWidget {
  final int balanceSats;
  final bool showConfetti;
  final bool isOnline;
  final bool isBalanceHidden;
  final VoidCallback? onToggleHide;

  const BalanceCard({
    super.key,
    required this.balanceSats,
    this.showConfetti = false,
    this.isOnline = true,
    this.isBalanceHidden = false,
    this.onToggleHide,
  });

  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard> {
  @override
  void initState() {
    super.initState();

    if (widget.showConfetti) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        HapticFeedback.heavyImpact();
      });
    }
  }

  String _formatSats(int sats) {
    return sats.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
  }

  String _satsToBTC(int sats) {
    // 1 BTC = 100,000,000 sats
    final btc = sats / 100000000;
    return btc.toStringAsFixed(5);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.surface,
                AppColors.surface.withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
          // Header: Title + Hide Button
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Total Balance',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              // Hide balance button
              IconButton(
                onPressed: widget.onToggleHide,
                icon: Icon(
                  widget.isBalanceHidden ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.textSecondary,
                  size: 22,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Sats balance display
          if (widget.isBalanceHidden)
            const Text(
              '••••',
              style: TextStyle(
                color: Colors.white,
                fontSize: 56,
                fontWeight: FontWeight.w700,
                height: 1.0,
                letterSpacing: 8,
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _formatSats(widget.balanceSats),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 56,
                        fontWeight: FontWeight.w700,
                        height: 0.9,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'sats',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        height: 0.9,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '≈ ${_satsToBTC(widget.balanceSats)} BTC',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
        ],
      ),
    ),
        // Confetti overlay
        if (widget.showConfetti)
          const Positioned.fill(
            child: IgnorePointer(
              child: Confetti(),
            ),
          ),
      ],
    );
  }
}