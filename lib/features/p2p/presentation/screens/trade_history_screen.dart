// Trade History Screen
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/p2p_models.dart';
import '../../providers/p2p_providers.dart';
import '../theme/p2p_theme.dart';
import '../widgets/p2p_widgets.dart';

class TradeHistoryScreen extends ConsumerWidget {
  const TradeHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFilter = ref.watch(tradeHistoryFilterProvider);
    final tradesAsync = ref.watch(tradeHistoryNotifierProvider);

    return Scaffold(
      backgroundColor: P2PColors.background,
      appBar: const P2PAppBar(title: 'Trade History'),
      body: Column(
        children: [
          const SizedBox(height: 16),
          // Filter chips
          P2PFilterChips<TradeHistoryFilter>(
            filters: TradeHistoryFilter.values,
            selectedFilter: selectedFilter,
            labelBuilder: (filter) => switch (filter) {
              TradeHistoryFilter.all => 'All',
              TradeHistoryFilter.completed => 'Completed',
              TradeHistoryFilter.cancelled => 'Cancelled',
              TradeHistoryFilter.disputed => 'Disputed',
            },
            onSelected: (filter) {
              ref.read(tradeHistoryFilterProvider.notifier).state = filter;
            },
          ),
          const SizedBox(height: 24),
          // Trade list
          Expanded(
            child: tradesAsync.when(
              data: (trades) {
                if (trades.isEmpty) {
                  return P2PEmptyState(
                    message: selectedFilter == TradeHistoryFilter.all
                        ? 'No trades yet'
                        : 'No ${selectedFilter.name} trades',
                    icon: Icons.history,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(tradeHistoryNotifierProvider);
                  },
                  color: P2PColors.primary,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: trades.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _TradeHistoryCard(trade: trades[index]);
                    },
                  ),
                );
              },
              loading: () => const P2PLoadingState(),
              error: (error, _) => P2PErrorState(
                message: error.toString(),
                onRetry: () => ref.invalidate(tradeHistoryNotifierProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TradeHistoryCard extends StatelessWidget {
  final Trade trade;

  const _TradeHistoryCard({required this.trade});

  @override
  Widget build(BuildContext context) {
    final isBuy = trade.type == TradeType.buy;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: P2PDecorations.cardDecoration,
      child: Row(
        children: [
          // Trade type icon
          P2PTradeTypeIcon(isBuy: isBuy),
          const SizedBox(width: 12),
          // Trade info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isBuy ? 'Bought from' : 'Sold to',
                      style: P2PTextStyles.bodySmall,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      trade.counterpartyName,
                      style: P2PTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  formatDate(trade.createdAt),
                  style: P2PTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          // Amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isBuy ? '+' : ''}${trade.satsAmount.toInt()} sats',
                style: P2PTextStyles.bodyMedium.copyWith(
                  color: isBuy ? P2PColors.success : P2PColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatFiat(trade.fiatAmount),
                style: P2PTextStyles.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
