import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/features/p2p/data/trade_model.dart';
import 'package:sabi_wallet/features/p2p/data/p2p_offer_model.dart';
import 'package:sabi_wallet/features/p2p/providers/p2p_providers.dart';
import 'package:sabi_wallet/features/p2p/providers/nip99_p2p_providers.dart';

/// P2P My Trades Screen - Active trades list
class P2PMyTradesScreen extends ConsumerStatefulWidget {
  const P2PMyTradesScreen({super.key});

  @override
  ConsumerState<P2PMyTradesScreen> createState() => _P2PMyTradesScreenState();
}

class _P2PMyTradesScreenState extends ConsumerState<P2PMyTradesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final formatter = NumberFormat('#,###');

  // Active trades - real trades will come from provider
  final List<_MockTrade> _activeTrades = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use NIP-99 user offers instead of local storage
    final userOffersAsync = ref.watch(userNip99OffersProvider);
    final userOffers = userOffersAsync.asData?.value ?? [];
    final isLoading = userOffersAsync.isLoading;

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
          'My Trades',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(48.h),
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 16.w),
            decoration: BoxDecoration(
              color: const Color(0xFF111128),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: const Color(0xFFF7931A),
                borderRadius: BorderRadius.circular(12.r),
              ),
              labelColor: AppColors.surface,
              indicatorPadding: EdgeInsets.symmetric(horizontal: 4.w),
              indicatorSize: TabBarIndicatorSize.tab,
              unselectedLabelColor: const Color(0xFFA1A1B2),
              dividerColor: Colors.transparent,
              labelStyle: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
              tabs: [
                Tab(text: 'Active (${_activeTrades.length})'),
                Tab(
                  text: 'My Offers (${isLoading ? '...' : userOffers.length})',
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildActiveTradesTab(), _buildMyOffersTab(userOffers)],
      ),
    );
  }

  Widget _buildActiveTradesTab() {
    if (_activeTrades.isEmpty) {
      return _buildEmptyState(
        icon: Icons.swap_horiz,
        title: 'No active trades',
        subtitle: 'Your ongoing trades will appear here',
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: _activeTrades.length,
      itemBuilder: (context, index) {
        final trade = _activeTrades[index];
        return Padding(
          padding: EdgeInsets.only(bottom: 12.h),
          child: _ActiveTradeCard(trade: trade),
        );
      },
    );
  }

  Widget _buildMyOffersTab(List<P2POfferModel> offers) {
    if (offers.isEmpty) {
      return _buildEmptyState(
        icon: Icons.storefront,
        title: 'No active offers',
        subtitle: 'Create an offer to start trading',
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: offers.length,
      itemBuilder: (context, index) {
        final offer = offers[index];
        return Padding(
          padding: EdgeInsets.only(bottom: 12.h),
          child: _RealOfferCard(
            offer: offer,
            onEdit: () {
              // TODO: Navigate to edit screen
            },
            onDelete: () => _showDeleteOfferConfirmation(offer),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64.sp, color: const Color(0xFF6B6B80)),
          SizedBox(height: 16.h),
          Text(
            title,
            style: TextStyle(
              color: const Color(0xFFA1A1B2),
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            subtitle,
            style: TextStyle(color: const Color(0xFF6B6B80), fontSize: 14.sp),
          ),
        ],
      ),
    );
  }

  void _showDeleteOfferConfirmation(P2POfferModel offer) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF111128),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.r),
            ),
            title: Text(
              'Delete Offer?',
              style: TextStyle(color: Colors.white, fontSize: 18.sp),
            ),
            content: Text(
              'Are you sure you want to delete this offer? This action cannot be undone.',
              style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 14.sp),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: const Color(0xFFA1A1B2)),
                ),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  // Delete via NIP-99 (publishes deletion event to relays)
                  final success = await ref
                      .read(nip99OfferNotifierProvider.notifier)
                      .deleteOffer(offer.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success ? 'Offer deleted' : 'Failed to delete offer',
                        ),
                        backgroundColor:
                            success
                                ? const Color(0xFF00FFB2)
                                : const Color(0xFFFF6B6B),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                    // Refresh the offers list
                    if (success) {
                      ref.invalidate(userNip99OffersProvider);
                    }
                  }
                },
                child: Text(
                  'Delete',
                  style: TextStyle(color: const Color(0xFFFF6B6B)),
                ),
              ),
            ],
          ),
    );
  }
}

/// Active Trade Card
class _ActiveTradeCard extends StatelessWidget {
  final _MockTrade trade;

  const _ActiveTradeCard({required this.trade});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,###');

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF111128),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: _getStatusColor(trade.status).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          // Header
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
                    Text(
                      'Trading with ${trade.merchantName}',
                      style: TextStyle(
                        color: AppColors.textPrimary.withValues(alpha: 0.75),
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Row(
                      children: [
                        Container(
                          width: 8.w,
                          height: 8.h,
                          decoration: BoxDecoration(
                            color: _getStatusColor(trade.status),
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          _getStatusText(trade.status),
                          style: TextStyle(
                            color: _getStatusColor(trade.status),
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // Trade Info
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: const Color(0xFF0C0C1A),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You Pay',
                        style: TextStyle(
                          color: const Color(0xFFA1A1B2),
                          fontSize: 11.sp,
                        ),
                      ),
                      Text(
                        '₦${formatter.format(trade.amount.toInt())}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward,
                  color: const Color(0xFFA1A1B2),
                  size: 20.sp,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'You Receive',
                        style: TextStyle(
                          color: const Color(0xFFA1A1B2),
                          fontSize: 11.sp,
                        ),
                      ),
                      Text(
                        '${formatter.format(trade.sats.toInt())} sats',
                        style: TextStyle(
                          color: const Color(0xFF00FFB2),
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12.h),

          // Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // TODO: Navigate to trade chat
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF7931A),
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(
                'Continue Trade',
                style: TextStyle(
                  color: AppColors.surface,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
      case TradeStatus.awaitingPayment:
        return const Color(0xFFF7931A);
      case TradeStatus.paid:
        return const Color(0xFF00FFB2);
      case TradeStatus.disputed:
        return const Color(0xFFFF6B6B);
      default:
        return const Color(0xFFA1A1B2);
    }
  }

  String _getStatusText(TradeStatus status) {
    switch (status) {
      case TradeStatus.awaitingPayment:
        return 'Awaiting your payment';
      case TradeStatus.paid:
        return 'Waiting for release';
      case TradeStatus.disputed:
        return 'Under dispute';
      default:
        return 'In progress';
    }
  }
}

/// Real Offer Card - Uses P2POfferModel from provider
class _RealOfferCard extends StatelessWidget {
  final P2POfferModel offer;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RealOfferCard({
    required this.offer,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,###');
    final isSellOffer = offer.type == OfferType.sell;
    final availableSats = offer.availableSats ?? 0;
    final lockedSats = offer.lockedSats ?? 0;
    final effectiveAvailable = offer.effectiveAvailableSats;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF111128),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: (isSellOffer
                          ? const Color(0xFFFF6B6B)
                          : const Color(0xFF00FFB2))
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  isSellOffer ? 'SELL OFFER' : 'BUY OFFER',
                  style: TextStyle(
                    color:
                        isSellOffer
                            ? const Color(0xFFFF6B6B)
                            : const Color(0xFF00FFB2),
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 8.w,
                    height: 8.h,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00FFB2),
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    'Active',
                    style: TextStyle(
                      color: const Color(0xFF00FFB2),
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 16.h),
          // Sats available and locked info
          if (isSellOffer && availableSats > 0) ...[
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
                        'Available',
                        style: TextStyle(
                          color: const Color(0xFFA1A1B2),
                          fontSize: 11.sp,
                        ),
                      ),
                      Text(
                        '${formatter.format(effectiveAvailable.toInt())} sats',
                        style: TextStyle(
                          color: const Color(0xFF00FFB2),
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (lockedSats > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Locked in trades',
                          style: TextStyle(
                            color: const Color(0xFFA1A1B2),
                            fontSize: 11.sp,
                          ),
                        ),
                        Text(
                          '${formatter.format(lockedSats.toInt())} sats',
                          style: TextStyle(
                            color: const Color(0xFFF7931A),
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Total',
                          style: TextStyle(
                            color: const Color(0xFFA1A1B2),
                            fontSize: 11.sp,
                          ),
                        ),
                        Text(
                          '${formatter.format(availableSats.toInt())} sats',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            SizedBox(height: 12.h),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Limits',
                    style: TextStyle(
                      color: const Color(0xFFA1A1B2),
                      fontSize: 11.sp,
                    ),
                  ),
                  Text(
                    '₦${formatter.format(offer.minLimit)} - ₦${formatter.format(offer.maxLimit)}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Margin',
                    style: TextStyle(
                      color: const Color(0xFFA1A1B2),
                      fontSize: 11.sp,
                    ),
                  ),
                  Text(
                    '+${offer.marginPercent?.toStringAsFixed(1) ?? '0'}%',
                    style: TextStyle(
                      color: const Color(0xFF00FFB2),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Icon(Icons.payment, size: 14.sp, color: const Color(0xFFA1A1B2)),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  offer.paymentMethod,
                  style: TextStyle(color: Colors.white, fontSize: 12.sp),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onEdit,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF2A2A3E)),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text('Edit', style: TextStyle(fontSize: 14.sp)),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: OutlinedButton(
                  onPressed: onDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF6B6B),
                    side: const BorderSide(color: Color(0xFFFF6B6B)),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text('Delete', style: TextStyle(fontSize: 14.sp)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Mock Trade Model
class _MockTrade {
  final String id;
  final String merchantName;
  final double amount;
  final double sats;
  final TradeStatus status;
  final String paymentMethod;
  final DateTime createdAt;
  final bool isBuying;

  _MockTrade({
    required this.id,
    required this.merchantName,
    required this.amount,
    required this.sats,
    required this.status,
    required this.paymentMethod,
    required this.createdAt,
    required this.isBuying,
  });
}
