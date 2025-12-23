import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/features/p2p/data/p2p_offer_model.dart';
import 'package:sabi_wallet/features/p2p/providers/p2p_providers.dart';
import 'package:sabi_wallet/features/p2p/presentation/screens/p2p_offer_detail_screen.dart';
import 'package:sabi_wallet/features/p2p/presentation/screens/p2p_create_offer_screen.dart';
import 'package:sabi_wallet/features/p2p/presentation/screens/p2p_trade_history_screen.dart';
import 'package:sabi_wallet/features/p2p/presentation/screens/p2p_my_trades_screen.dart';
import 'package:sabi_wallet/features/p2p/presentation/screens/p2p_merchant_profile_screen.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// P2P Home Screen - Binance/NoOnes inspired
class P2PHomeScreen extends ConsumerStatefulWidget {
  const P2PHomeScreen({super.key});

  @override
  ConsumerState<P2PHomeScreen> createState() => _P2PHomeScreenState();
}

class _P2PHomeScreenState extends ConsumerState<P2PHomeScreen> {
  bool _isBuyMode = true;
  String _selectedPaymentFilter = 'All';
  bool _isLoading = true;

  final List<String> _paymentFilters = [
    'All',
    'Bank Transfer',
    'Mobile Money',
    'Opay',
    'Palmpay',
    'Kuda',
  ];

  @override
  void initState() {
    super.initState();
    _simulateLoading();
  }

  Future<void> _simulateLoading() async {
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final exchangeRates = ref.watch(exchangeRatesProvider);
    final offers = ref.watch(filteredP2POffersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C1A),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() => _isLoading = true);
            await _simulateLoading();
          },
          backgroundColor: const Color(0xFF111128),
          color: const Color(0xFFF7931A),
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top bar with title and actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'P2P Trading',
                            style: TextStyle(
                              fontSize: 24.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Row(
                            children: [
                              _IconButton(
                                icon: Icons.history,
                                onTap:
                                    () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) =>
                                                const P2PTradeHistoryScreen(),
                                      ),
                                    ),
                              ),
                              SizedBox(width: 8.w),
                              _IconButton(
                                icon: Icons.list_alt,
                                onTap:
                                    () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) => const P2PMyTradesScreen(),
                                      ),
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),

                      // Live Rates Card
                      _LiveRatesCard(
                        btcNgnRate: exchangeRates['BTC_NGN'] ?? 150000000,
                        usdNgnRate: exchangeRates['USD_NGN'] ?? 1650,
                      ),
                      SizedBox(height: 16.h),

                      // Buy/Sell Toggle
                      _BuySellToggle(
                        isBuyMode: _isBuyMode,
                        onToggle: (isBuy) => setState(() => _isBuyMode = isBuy),
                      ),
                      SizedBox(height: 16.h),

                      // Payment Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children:
                              _paymentFilters.map((filter) {
                                final isSelected =
                                    _selectedPaymentFilter == filter;
                                return Padding(
                                  padding: EdgeInsets.only(right: 8.w),
                                  child: _FilterChip(
                                    label: filter,
                                    isSelected: isSelected,
                                    onTap:
                                        () => setState(
                                          () => _selectedPaymentFilter = filter,
                                        ),
                                  ),
                                );
                              }).toList(),
                        ),
                      ),
                      SizedBox(height: 8.h),
                    ],
                  ),
                ),
              ),

              // Offers List
              _isLoading
                  ? SliverToBoxAdapter(child: _buildSkeletonLoader())
                  : offers.isEmpty
                  ? SliverToBoxAdapter(child: _buildEmptyState())
                  : SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final offer = offers[index];
                        return Padding(
                          padding: EdgeInsets.only(bottom: 12.h),
                          child: _OfferCard(
                            offer: offer,
                            isBuyMode: _isBuyMode,
                            onTap:
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) =>
                                            P2POfferDetailScreen(offer: offer),
                                  ),
                                ),
                            onMerchantTap: () {
                              if (offer.merchant != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => P2PMerchantProfileScreen(
                                          merchant: offer.merchant!,
                                        ),
                                  ),
                                );
                              }
                            },
                          ),
                        );
                      }, childCount: offers.length),
                    ),
                  ),

              // Bottom padding
              SliverToBoxAdapter(child: SizedBox(height: 80.h)),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const P2PCreateOfferScreen()),
            ),
        backgroundColor: const Color(0xFFF7931A),
        icon: Icon(Icons.add, color: AppColors.surface, size: 20.sp),
        label: Text(
          'Create Offer',
          style: TextStyle(
            color: AppColors.surface,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return Skeletonizer(
      enabled: true,
      child: Column(
        children: List.generate(
          4,
          (index) => Container(
            margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: const Color(0xFF111128),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48.w,
                      height: 48.h,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2A2A3E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 100.w,
                            height: 14.h,
                            color: const Color(0xFF2A2A3E),
                          ),
                          SizedBox(height: 4.h),
                          Container(
                            width: 150.w,
                            height: 12.h,
                            color: const Color(0xFF2A2A3E),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Container(
                  width: double.infinity,
                  height: 16.h,
                  color: const Color(0xFF2A2A3E),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 60.h),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.swap_horiz, size: 64.sp, color: const Color(0xFFA1A1B2)),
          SizedBox(height: 16.h),
          Text(
            'No offers available',
            style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 16.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            'Be the first to create an offer!',
            style: TextStyle(color: const Color(0xFF6B6B80), fontSize: 14.sp),
          ),
        ],
      ),
    );
  }
}

/// Live Rates Card
class _LiveRatesCard extends StatelessWidget {
  final double btcNgnRate;
  final double usdNgnRate;

  const _LiveRatesCard({required this.btcNgnRate, required this.usdNgnRate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
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
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7931A).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Icon(
                        Icons.currency_bitcoin,
                        color: const Color(0xFFF7931A),
                        size: 20.sp,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Live Rates',
                      style: TextStyle(
                        color: const Color(0xFFA1A1B2),
                        fontSize: 12.sp,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00FFB2).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6.w,
                            height: 6.h,
                            decoration: const BoxDecoration(
                              color: Color(0xFF00FFB2),
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            'LIVE',
                            style: TextStyle(
                              color: const Color(0xFF00FFB2),
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BTC/NGN',
                            style: TextStyle(
                              color: const Color(0xFFA1A1B2),
                              fontSize: 11.sp,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            '₦${_formatRate(btcNgnRate)}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 30.h,
                      color: const Color(0xFF2A2A3E),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: 16.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'USD/NGN',
                              style: TextStyle(
                                color: const Color(0xFFA1A1B2),
                                fontSize: 11.sp,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              '₦${usdNgnRate.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
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

  String _formatRate(double rate) {
    if (rate >= 1000000000) {
      return '${(rate / 1000000000).toStringAsFixed(2)}B';
    } else if (rate >= 1000000) {
      return '${(rate / 1000000).toStringAsFixed(2)}M';
    } else if (rate >= 1000) {
      return '${(rate / 1000).toStringAsFixed(0)}K';
    }
    return rate.toStringAsFixed(0);
  }
}

/// Buy/Sell Toggle
class _BuySellToggle extends StatelessWidget {
  final bool isBuyMode;
  final Function(bool) onToggle;

  const _BuySellToggle({required this.isBuyMode, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: const Color(0xFF111128),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onToggle(true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(vertical: 14.h),
                decoration: BoxDecoration(
                  color:
                      isBuyMode ? const Color(0xFF00FFB2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Center(
                  child: Text(
                    'Buy BTC',
                    style: TextStyle(
                      color:
                          isBuyMode
                              ? const Color(0xFF0C0C1A)
                              : const Color(0xFFA1A1B2),
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onToggle(false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(vertical: 14.h),
                decoration: BoxDecoration(
                  color:
                      !isBuyMode ? const Color(0xFFFF6B6B) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Center(
                  child: Text(
                    'Sell BTC',
                    style: TextStyle(
                      color:
                          !isBuyMode ? Colors.white : const Color(0xFFA1A1B2),
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Filter Chip
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF7931A) : const Color(0xFF111128),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color:
                isSelected ? const Color(0xFFF7931A) : const Color(0xFF2A2A3E),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.surface : const Color(0xFFA1A1B2),
            fontSize: 13.sp,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Icon Button
class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: const Color(0xFF111128),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Icon(icon, color: const Color(0xFFA1A1B2), size: 20.sp),
      ),
    );
  }
}

/// Offer Card
class _OfferCard extends StatelessWidget {
  final P2POfferModel offer;
  final bool isBuyMode;
  final VoidCallback onTap;
  final VoidCallback onMerchantTap;

  const _OfferCard({
    required this.offer,
    required this.isBuyMode,
    required this.onTap,
    required this.onMerchantTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: const Color(0xFF111128),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Merchant Row
            Row(
              children: [
                GestureDetector(
                  onTap: onMerchantTap,
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 44.w,
                        height: 44.h,
                        decoration: BoxDecoration(
                          color: _getAvatarColor(offer.name),
                          shape: BoxShape.circle,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child:
                            offer.merchant?.avatarUrl != null
                                ? CachedNetworkImage(
                                  imageUrl: offer.merchant!.avatarUrl!,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => _buildInitial(),
                                )
                                : _buildInitial(),
                      ),
                      SizedBox(width: 12.w),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                offer.name,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (offer.merchant?.isVerified == true) ...[
                                SizedBox(width: 4.w),
                                Icon(
                                  Icons.verified,
                                  color: const Color(0xFF00FFB2),
                                  size: 16.sp,
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: 2.h),
                          Row(
                            children: [
                              Icon(
                                Icons.star,
                                color: const Color(0xFFF7931A),
                                size: 12.sp,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                '${offer.ratingPercent}%',
                                style: TextStyle(
                                  color: const Color(0xFFA1A1B2),
                                  fontSize: 12.sp,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                '${offer.trades} trades',
                                style: TextStyle(
                                  color: const Color(0xFFA1A1B2),
                                  fontSize: 12.sp,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Response time badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FFB2).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    offer.eta,
                    style: TextStyle(
                      color: const Color(0xFF00FFB2),
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),

            // Price and Limits
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Price',
                      style: TextStyle(
                        color: const Color(0xFFA1A1B2),
                        fontSize: 11.sp,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '₦${_formatPrice(offer.pricePerBtc)}',
                      style: TextStyle(
                        color:
                            isBuyMode
                                ? const Color(0xFF00FFB2)
                                : const Color(0xFFFF6B6B),
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Limits',
                      style: TextStyle(
                        color: const Color(0xFFA1A1B2),
                        fontSize: 11.sp,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '₦${_formatLimit(offer.minLimit)} - ₦${_formatLimit(offer.maxLimit)}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12.h),

            // Payment methods
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                _PaymentMethodBadge(method: offer.paymentMethod),
                if (offer.acceptedMethods != null)
                  ...offer.acceptedMethods!
                      .take(2)
                      .map((m) => _PaymentMethodBadge(method: m.name)),
              ],
            ),
            SizedBox(height: 12.h),

            // Trade button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isBuyMode
                          ? const Color(0xFF00FFB2)
                          : const Color(0xFFFF6B6B),
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  isBuyMode ? 'Buy BTC' : 'Sell BTC',
                  style: TextStyle(
                    color: isBuyMode ? const Color(0xFF0C0C1A) : Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitial() {
    return Center(
      child: Text(
        offer.name.isNotEmpty ? offer.name[0].toUpperCase() : '?',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18.sp,
          fontWeight: FontWeight.bold,
        ),
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

  String _formatPrice(double price) {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(2)}M';
    }
    return price.toStringAsFixed(0);
  }

  String _formatLimit(int limit) {
    if (limit >= 1000000) {
      return '${(limit / 1000000).toStringAsFixed(1)}M';
    } else if (limit >= 1000) {
      return '${(limit / 1000).toStringAsFixed(0)}K';
    }
    return limit.toString();
  }
}

/// Payment Method Badge
class _PaymentMethodBadge extends StatelessWidget {
  final String method;

  const _PaymentMethodBadge({required this.method});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: const Color(0xFF2A2A3E)),
      ),
      child: Text(
        method,
        style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 11.sp),
      ),
    );
  }
}
