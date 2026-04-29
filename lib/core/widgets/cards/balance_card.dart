import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:flutter_confetti/flutter_confetti.dart';
import 'package:sabi_wallet/services/rate_service.dart';
import 'package:sabi_wallet/features/wallet/presentation/providers/rate_provider.dart';
import 'package:sabi_wallet/features/profile/presentation/providers/settings_provider.dart';
import 'package:sabi_wallet/features/wallet/presentation/providers/onchain_deposits_provider.dart';
import 'package:sabi_wallet/features/wallet/presentation/providers/auto_claim_manager.dart';
import 'package:sabi_wallet/features/wallet/presentation/screens/onchain_deposits_screen.dart';

class BalanceCard extends ConsumerStatefulWidget {
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
  ConsumerState<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends ConsumerState<BalanceCard> {
  bool _showFiat = false;
  // When Stable Balance is enabled, toggle primary display between sats/BTC and USDB
  bool _showStable = false;
  double? _btcToFiatRate; // user-selected fiat rate (NGN or USD)
  double? _btcToUsdRate; // always fetch USD rate for USDB display
  FiatCurrency _currentCurrency = FiatCurrency.ngn;
  String? _lastShownAutoClaimId;

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
    final currency = ref.read(selectedFiatCurrencyProvider);
    final rate = await RateService.getBtcToFiatRate(currency);
    if (mounted) {
      setState(() {
        _btcToFiatRate = rate;
        _currentCurrency = currency;
      });
    }
    // Always load USD rate for Stable Balance display
    try {
      final usdRate = await RateService.getBtcToFiatRate(FiatCurrency.usd);
      if (mounted) setState(() => _btcToUsdRate = usdRate);
    } catch (_) {}
  }

  void _toggleCurrency() {
    HapticFeedback.selectionClick();
    setState(() {
      // If stable is enabled and stable is currently showing, flip back to sats
      if (_showStable) {
        _showStable = false;
        _showFiat = false;
      } else {
        _showFiat = !_showFiat;
      }
    });
  }

  void _toggleStablePrimary() {
    HapticFeedback.selectionClick();
    setState(() => _showStable = !_showStable);
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
    // Watch for currency changes
    final selectedCurrency = ref.watch(selectedFiatCurrencyProvider);

    // Reload rate if currency changed
    if (selectedCurrency != _currentCurrency) {
      _currentCurrency = selectedCurrency;
      _loadRate();
    }

    return Stack(
      children: [
        // Ensure auto-claim manager is instantiated (app-wide)
        Builder(builder: (_) {
          ref.read(autoClaimManagerProvider);
          return const SizedBox.shrink();
        }),

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
                        widget.isBalanceHidden
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: AppColors.textSecondary,
                        size: 22,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Balance display (sats, fiat, or Stable USDB)
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
                else if (_showStable && _btcToUsdRate != null)
                  // Stable USDB primary view
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '\$',
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
                                _formatFiat(widget.balanceSats, _btcToUsdRate!),
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
                else if (_showFiat && _btcToFiatRate != null)
                  // Fiat view (NGN or USD based on settings)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            _currentCurrency.symbol,
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
                                _formatFiat(
                                  widget.balanceSats,
                                  _btcToFiatRate!,
                                ),
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
                  // Sats view (default)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
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
                      const SizedBox(height: 4),
                    ],
                  ),
                // On-chain breakdown: show total unclaimed on-chain deposits
                SizedBox(height: 8),
                Builder(builder: (ctx) {
                  final deposits = ref.watch(onchainDepositsListProvider);
                  final unclaimed = deposits.fold<int>(0, (p, e) => p + e.amountSats);
                  // Listen for auto-claim events to surface SnackBar
                  final event = ref.watch(autoClaimEventProvider);
                  if (event != null && event.id != _lastShownAutoClaimId) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Auto-claimed ${event.amountSats} sats from ${event.txid.substring(0, 8)}...')));
                      _lastShownAutoClaimId = event.id;
                      // Clear the event after showing
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        ref.read(autoClaimEventProvider.notifier).state = null;
                      });
                    });
                  }
                  if (unclaimed <= 0) return const SizedBox.shrink();
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OnchainDepositsScreen()));
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'On‑chain: ${_formatSats(unclaimed)} sats',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.open_in_new, size: 14, color: AppColors.textSecondary),
                      ],
                    ),
                  );
                }),
                // Stable toggle badge is rendered at Stack level (see below)
              ],
            ),
          ),
        ),
        // Stable toggle badge (rendered at Stack level so Positioned is valid)
        if (ref.watch(settingsNotifierProvider).stableBalanceEnabled)
          Positioned(
            right: 12,
            top: 12,
            child: GestureDetector(
              onTap: _toggleStablePrimary,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _showStable ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _showStable ? 'USDB' : 'sats',
                  style: TextStyle(
                    color: _showStable ? AppColors.surface : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        // Confetti overlay
        if (widget.showConfetti)
          const Positioned.fill(child: IgnorePointer(child: Confetti())),
      ],
    );
  }

  String _formatFiat(int sats, double rate) {
    final btc = sats / 100000000;
    final fiatValue = btc * rate;
    // Use 2 decimal places for USD, 0 for NGN
    final decimals = _currentCurrency == FiatCurrency.usd ? 2 : 0;
    return fiatValue
        .toStringAsFixed(decimals)
        .replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
  }
}
