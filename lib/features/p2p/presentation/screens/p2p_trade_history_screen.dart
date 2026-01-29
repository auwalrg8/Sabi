import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/features/p2p/data/trade_model.dart';

/// P2P Trade History Screen - Past trades with filters
class P2PTradeHistoryScreen extends ConsumerStatefulWidget {
  const P2PTradeHistoryScreen({super.key});

  @override
  ConsumerState<P2PTradeHistoryScreen> createState() =>
      _P2PTradeHistoryScreenState();
}

class _P2PTradeHistoryScreenState extends ConsumerState<P2PTradeHistoryScreen> {
  String _selectedFilter = 'All';
  final formatter = NumberFormat('#,###');

  final List<String> _filters = ['All', 'Completed', 'Cancelled', 'Disputed'];

  // Trade history - real trades will come from provider
  final List<_HistoryTrade> _trades = [];

  List<_HistoryTrade> get _filteredTrades {
    if (_selectedFilter == 'All') return _trades;
    return _trades.where((t) {
      switch (_selectedFilter) {
        case 'Completed':
          return t.status == TradeStatus.released;
        case 'Cancelled':
          return t.status == TradeStatus.cancelled;
        case 'Disputed':
          return t.status == TradeStatus.disputed;
        default:
          return true;
      }
    }).toList();
  }

  Map<String, double> get _stats {
    final completed =
        _trades.where((t) => t.status == TradeStatus.released).toList();
    final totalVolume = completed.fold<double>(0, (sum, t) => sum + t.amount);
    final totalSats = completed.fold<double>(0, (sum, t) => sum + t.sats);

    return {
      'totalTrades': _trades.length.toDouble(),
      'completedTrades': completed.length.toDouble(),
      'totalVolume': totalVolume,
      'totalSats': totalSats,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C0C1A),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20.sp,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Trade History',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: Column(
        children: [
          // Stats Summary
          Padding(
            padding: EdgeInsets.all(16.w),
            child: _StatsCard(stats: _stats),
          ),

          // Filters
          SizedBox(
            height: 40.h,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              itemCount: _filters.length,
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: EdgeInsets.only(right: 8.w),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedFilter = filter),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? const Color(0xFFF7931A)
                                : const Color(0xFF111128),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color:
                              isSelected
                                  ? const Color(0xFFF7931A)
                                  : const Color(0xFF2A2A3E),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        filter,
                        style: TextStyle(
                          color:
                              isSelected
                                  ? AppColors.surface
                                  : const Color(0xFFA1A1B2),
                          fontSize: 13.sp,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 16.h),

          // Trade List
          Expanded(
            child:
                _filteredTrades.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            size: 64.sp,
                            color: const Color(0xFF6B6B80),
                          ),
                          SizedBox(height: 16.h),
                          Text(
                            'No trades found',
                            style: TextStyle(
                              color: const Color(0xFFA1A1B2),
                              fontSize: 16.sp,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      itemCount: _filteredTrades.length,
                      itemBuilder: (context, index) {
                        final trade = _filteredTrades[index];
                        return Padding(
                          padding: EdgeInsets.only(bottom: 12.h),
                          child: _HistoryTradeCard(trade: trade),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

/// Stats Card
class _StatsCard extends StatelessWidget {
  final Map<String, double> stats;

  const _StatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,###');

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF7931A).withValues(alpha: 0.15),
            const Color(0xFF111128),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: const Color(0xFFF7931A).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  label: 'Total Trades',
                  value: _safeToInt(stats['totalTrades']!).toString(),
                  icon: Icons.swap_horiz,
                ),
              ),
              Container(width: 1, height: 50.h, color: const Color(0xFF2A2A3E)),
              Expanded(
                child: _StatItem(
                  label: 'Completed',
                  value: _safeToInt(stats['completedTrades']!).toString(),
                  icon: Icons.check_circle,
                  valueColor: const Color(0xFF00FFB2),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Divider(color: const Color(0xFF2A2A3E)),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  label: 'Total Volume',
                  value: '₦${_formatVolume(stats['totalVolume']!)}',
                  icon: Icons.account_balance_wallet,
                ),
              ),
              Container(width: 1, height: 50.h, color: const Color(0xFF2A2A3E)),
              Expanded(
                child: _StatItem(
                  label: 'Sats Acquired',
                  value: formatter.format(_safeToInt(stats['totalSats']!)),
                  icon: Icons.currency_bitcoin,
                  valueColor: const Color(0xFFF7931A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatVolume(double volume) {
    if (volume >= 1000000) {
      return '${(volume / 1000000).toStringAsFixed(1)}M';
    } else if (volume >= 1000) {
      return '${(volume / 1000).toStringAsFixed(0)}K';
    }
    return volume.toStringAsFixed(0);
  }
}

/// Stat Item
class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFFA1A1B2), size: 20.sp),
        SizedBox(height: 8.h),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          label,
          style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 11.sp),
        ),
      ],
    );
  }
}

/// History Trade Card
class _HistoryTradeCard extends StatelessWidget {
  final _HistoryTrade trade;

  const _HistoryTradeCard({required this.trade});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,###');

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF111128),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44.w,
                height: 44.h,
                decoration: BoxDecoration(
                  color: _getAvatarColor(trade.merchantName),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    trade.merchantName[0].toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          trade.merchantName,
                          style: TextStyle(
                            color: AppColors.textPrimary.withValues(alpha: 0.8),
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: (trade.isBuying
                                    ? const Color(0xFF00FFB2)
                                    : const Color(0xFFFF6B6B))
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Text(
                            trade.isBuying ? 'BUY' : 'SELL',
                            style: TextStyle(
                              color:
                                  trade.isBuying
                                      ? const Color(0xFF00FFB2)
                                      : const Color(0xFFFF6B6B),
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      _formatDate(trade.completedAt),
                      style: TextStyle(
                        color: const Color(0xFFA1A1B2),
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(
                        trade.status,
                      ).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(trade.status),
                          color: _getStatusColor(trade.status),
                          size: 12.sp,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          _getStatusText(trade.status),
                          style: TextStyle(
                            color: _getStatusColor(trade.status),
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: const Color(0xFF0C0C1A),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Amount',
                      style: TextStyle(
                        color: const Color(0xFFA1A1B2),
                        fontSize: 11.sp,
                      ),
                    ),
                    Text(
                      '₦${formatter.format(_safeToInt(trade.amount))}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'via',
                      style: TextStyle(
                        color: const Color(0xFF6B6B80),
                        fontSize: 10.sp,
                      ),
                    ),
                    Text(
                      trade.paymentMethod,
                      style: TextStyle(
                        color: const Color(0xFFA1A1B2),
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Sats',
                      style: TextStyle(
                        color: const Color(0xFFA1A1B2),
                        fontSize: 11.sp,
                      ),
                    ),
                    Text(
                      '${trade.isBuying ? '+' : '-'}${formatter.format(_safeToInt(trade.sats))}',
                      style: TextStyle(
                        color:
                            trade.isBuying
                                ? const Color(0xFF00FFB2)
                                : const Color(0xFFFF6B6B),
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFFF7931A),
      const Color(0xFF00FFB2),
      const Color(0xFF6366F1),
      const Color(0xFFEC4899),
      const Color(0xFF8B5CF6),
    ];
    return colors[name.hashCode % colors.length];
  }

  Color _getStatusColor(TradeStatus status) {
    switch (status) {
      case TradeStatus.released:
        return const Color(0xFF00FFB2);
      case TradeStatus.cancelled:
        return const Color(0xFFA1A1B2);
      case TradeStatus.disputed:
        return const Color(0xFFFF6B6B);
      default:
        return const Color(0xFFA1A1B2);
    }
  }

  IconData _getStatusIcon(TradeStatus status) {
    switch (status) {
      case TradeStatus.released:
        return Icons.check_circle;
      case TradeStatus.cancelled:
        return Icons.cancel;
      case TradeStatus.disputed:
        return Icons.gavel;
      default:
        return Icons.help;
    }
  }

  String _getStatusText(TradeStatus status) {
    switch (status) {
      case TradeStatus.released:
        return 'Completed';
      case TradeStatus.cancelled:
        return 'Cancelled';
      case TradeStatus.disputed:
        return 'Disputed';
      default:
        return 'Unknown';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

/// History Trade Model
class _HistoryTrade {
  final String id;
  final String merchantName;
  final double amount;
  final double sats;
  final TradeStatus status;
  final String paymentMethod;
  final DateTime completedAt;
  final bool isBuying;

  _HistoryTrade({
    required this.id,
    required this.merchantName,
    required this.amount,
    required this.sats,
    required this.status,
    required this.paymentMethod,
    required this.completedAt,
    required this.isBuying,
  });
}

/// Safely converts double to int, handling Infinity and NaN
int _safeToInt(double value, [int defaultValue = 0]) {
  if (value.isNaN || value.isInfinite) return defaultValue;
  return value.toInt();
}
