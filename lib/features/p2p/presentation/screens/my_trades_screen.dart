// My Trades (Active Trades) Screen
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/p2p_models.dart';
import '../../providers/p2p_providers.dart';
import '../theme/p2p_theme.dart';
import '../widgets/p2p_widgets.dart';
import 'merchant_profile_screen.dart';

class MyTradesScreen extends ConsumerWidget {
  const MyTradesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tradesAsync = ref.watch(activeTradesNotifierProvider);

    return Scaffold(
      backgroundColor: P2PColors.background,
      appBar: const P2PAppBar(title: 'My Trades'),
      body: tradesAsync.when(
        data: (trades) {
          if (trades.isEmpty) {
            return const P2PEmptyState(
              message: 'No active trades',
              icon: Icons.swap_horiz,
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(activeTradesNotifierProvider.notifier).refresh();
            },
            color: P2PColors.primary,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: trades.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _ActiveTradeCard(trade: trades[index]);
              },
            ),
          );
        },
        loading: () => const P2PLoadingState(),
        error: (error, _) => P2PErrorState(
          message: error.toString(),
          onRetry: () =>
              ref.read(activeTradesNotifierProvider.notifier).refresh(),
        ),
      ),
    );
  }
}

class _ActiveTradeCard extends ConsumerWidget {
  final Trade trade;

  const _ActiveTradeCard({required this.trade});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        // Navigate to trade details or merchant profile
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                MerchantProfileScreen(merchantId: trade.counterpartyId),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: P2PDecorations.cardDecoration,
        child: Column(
          children: [
            Row(
              children: [
                // Avatar
                P2PAvatar(
                  imageUrl: trade.counterpartyAvatar,
                  name: trade.counterpartyName,
                  size: 44,
                ),
                const SizedBox(width: 12),
                // Trade info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trade.counterpartyName,
                        style: P2PTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            formatFiat(trade.fiatAmount),
                            style: P2PTextStyles.bodySmall,
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: P2PColors.textMuted,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${trade.satsAmount.toInt()} sats',
                            style: P2PTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status badge
                _buildStatusBadge(trade.status),
              ],
            ),
            const SizedBox(height: 12),
            // Time left and releasing status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (trade.timeLeft != null)
                  P2PTimeLeft(timeLeft: trade.timeLeft!),
                if (trade.status == TradeStatus.releasingSoon ||
                    trade.status == TradeStatus.paid)
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 16,
                        color: P2PColors.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Releasing soon',
                        style: P2PTextStyles.bodySmall.copyWith(
                          color: P2PColors.success,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(TradeStatus status) {
    return switch (status) {
      TradeStatus.paid => P2PStatusBadge.paid(),
      TradeStatus.awaitingPayment => P2PStatusBadge.awaitingPayment(),
      TradeStatus.releasingSoon => P2PStatusBadge.paid(),
      TradeStatus.completed => P2PStatusBadge.completed(),
      TradeStatus.cancelled => P2PStatusBadge.cancelled(),
      TradeStatus.disputed => P2PStatusBadge.disputed(),
      _ => P2PStatusBadge(
          label: status.name,
          color: P2PColors.textSecondary,
        ),
    };
  }
}
