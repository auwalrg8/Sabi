import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:flutter_confetti/flutter_confetti.dart';
import 'package:sabi_wallet/services/rate_service.dart';

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
  bool _showNaira = false;
  double? _btcToNgnRate;
  @override
  void initState() {
    super.initState();
    _loadRate();

    if (widget.showConfetti) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        HapticFeedback.heavyImpact();
      });
    }
  }

  Future<void> _loadRate() async {
    final rate = await RateService.getBtcToNgnRate();
    if (mounted) {
      setState(() {
        _btcToNgnRate = rate;
      });
    }
  }

  void _toggleCurrency() {
    HapticFeedback.selectionClick();
    setState(() {
      _showNaira = !_showNaira;
    });
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
        GestureDetector(
          onTap: _toggleCurrency,
          child: Container(
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
          // Balance display (sats or naira)
          if (widget.isBalanceHidden)
            const Text(
              '••••',
              style: TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w700,
                height: 0.9,
                letterSpacing: 8,
              ),
            )
          else if (_showNaira && _btcToNgnRate != null)
            // Naira view
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '₦',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        height: 0.9,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _formatNaira(widget.balanceSats, _btcToNgnRate!),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.w700,
                            height: 0.9,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${_formatSats(widget.balanceSats)} sats',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
              ],
            )
          else
            // Sats view
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
                        fontSize: 40,
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
                // if (_btcToNgnRate != null) ...[
                //   const SizedBox(height: 4),
                //   Text(
                //     '≈ ${_formatNairaShort(widget.balanceSats, _btcToNgnRate!)}',
                //     style: TextStyle(
                //       color: AppColors.textSecondary.withValues(alpha: 0.8),
                //       fontSize: 14,
                //       fontWeight: FontWeight.w500,
                //     ),
                //     textAlign: TextAlign.center,
                //   ),
                // ],
                const SizedBox(height: 4),
              ],
            ),
            ],
          ),
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

  String _formatNaira(int sats, double rate) {
    final btc = sats / 100000000;
    final naira = btc * rate;
    return naira.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
  }
}