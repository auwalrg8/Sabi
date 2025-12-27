import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sabi_wallet/features/p2p/data/p2p_offer_model.dart';
import 'package:sabi_wallet/features/p2p/providers/p2p_providers.dart';
import 'package:sabi_wallet/features/p2p/presentation/screens/p2p_offer_detail_screen.dart';
import 'package:sabi_wallet/features/p2p/presentation/screens/p2p_create_offer_screen.dart';
import 'package:sabi_wallet/features/p2p/presentation/screens/p2p_trade_history_screen.dart';
import 'package:sabi_wallet/features/p2p/presentation/screens/p2p_my_trades_screen.dart';
import 'package:sabi_wallet/features/p2p/presentation/screens/p2p_merchant_profile_screen.dart';
import 'package:sabi_wallet/features/p2p/presentation/screens/p2p_escrow_info_screen.dart';
import 'package:sabi_wallet/features/p2p/utils/p2p_logger.dart';
import 'package:sabi_wallet/features/wallet/presentation/providers/rate_provider.dart';
import 'package:sabi_wallet/services/rate_service.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// P2P Home Screen - Differentiated Buy/Sell UX
/// 
/// BUY BTC Tab: Browse sellers' offers, filter by payment method
/// SELL BTC Tab: Create your own offer, manage active sales
class P2PHomeScreen extends ConsumerStatefulWidget {
  const P2PHomeScreen({super.key});

  @override
  ConsumerState<P2PHomeScreen> createState() => _P2PHomeScreenState();
}

class _P2PHomeScreenState extends ConsumerState<P2PHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPaymentFilter = 'All';
  bool _isLoading = true;

  // Popular payment methods for quick filter
  final List<String> _paymentFilters = [
    'All',
    'Bank Transfer',
    'Mobile Money',
    'Wise',
    'PayPal',
    'Cash App',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadData();
    P2PLogger.info('Home', 'P2P Home Screen initialized');
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      setState(() {});
      P2PLogger.debug('Home', 'Tab changed to: ${_tabController.index == 0 ? "Buy" : "Sell"}');
    }
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) setState(() => _isLoading = false);
    } catch (e, stack) {
      P2PLogger.error(
        'Home',
        'Failed to load P2P data',
        metadata: {'error': e.toString()},
        stackTrace: stack,
        errorCode: P2PErrorCodes.networkError,
      );
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exchangeRates = ref.watch(exchangeRatesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C1A),
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
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
                              icon: Icons.help_outline,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const P2PEscrowInfoScreen(),
                                ),
                              ),
                              tooltip: 'How it works',
                            ),
                            SizedBox(width: 8.w),
                            _IconButton(
                              icon: Icons.history,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const P2PTradeHistoryScreen(),
                                ),
                              ),
                              tooltip: 'Trade History',
                            ),
                            SizedBox(width: 8.w),
                            _IconButton(
                              icon: Icons.list_alt,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const P2PMyTradesScreen(),
                                ),
                              ),
                              tooltip: 'My Trades',
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

                    // Tab Bar - Buy BTC / Sell BTC
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF111128),
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      padding: EdgeInsets.all(4.w),
                      child: TabBar(
                        controller: _tabController,
                        indicator: BoxDecoration(
                          borderRadius: BorderRadius.circular(12.r),
                          color: _tabController.index == 0
                              ? const Color(0xFF00C853)
                              : const Color(0xFFF7931A),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white54,
                        labelStyle: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                        tabs: const [
                          Tab(text: 'Buy BTC'),
                          Tab(text: 'Sell BTC'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              // Buy BTC Tab
              _BuyBtcTab(
                isLoading: _isLoading,
                selectedPaymentFilter: _selectedPaymentFilter,
                paymentFilters: _paymentFilters,
                onFilterChanged: (filter) =>
                    setState(() => _selectedPaymentFilter = filter),
                onRefresh: _loadData,
              ),
              // Sell BTC Tab
              _SellBtcTab(
                isLoading: _isLoading,
                onRefresh: _loadData,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Buy BTC Tab - Browse sellers' offers
class _BuyBtcTab extends ConsumerWidget {
  final bool isLoading;
  final String selectedPaymentFilter;
  final List<String> paymentFilters;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback onRefresh;

  const _BuyBtcTab({
    required this.isLoading,
    required this.selectedPaymentFilter,
    required this.paymentFilters,
    required this.onFilterChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get sell offers (offers from sellers who want to sell BTC)
    final allOffers = ref.watch(p2pOffersProvider);
    final sellOffers = allOffers.where((o) => o.type == OfferType.sell).toList();
    
    // Apply payment filter
    final filteredOffers = selectedPaymentFilter == 'All'
        ? sellOffers
        : sellOffers.where((o) => 
            o.paymentMethod.toLowerCase().contains(selectedPaymentFilter.toLowerCase()) ||
            (o.acceptedMethods?.any((pm) => 
              pm.name.toLowerCase().contains(selectedPaymentFilter.toLowerCase())
            ) ?? false)
          ).toList();

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      backgroundColor: const Color(0xFF111128),
      color: const Color(0xFF00C853),
      child: CustomScrollView(
        slivers: [
          // Explainer Card
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
              child: _ExplainerCard(
                icon: Icons.shopping_cart,
                iconColor: const Color(0xFF00C853),
                title: 'Buy Bitcoin',
                description: 'Browse offers from sellers. Pay with your preferred method and receive BTC directly to your wallet.',
              ),
            ),
          ),

          // Payment Filter Chips
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: paymentFilters.map((filter) {
                    final isSelected = selectedPaymentFilter == filter;
                    return Padding(
                      padding: EdgeInsets.only(right: 8.w),
                      child: _FilterChip(
                        label: filter,
                        isSelected: isSelected,
                        selectedColor: const Color(0xFF00C853),
                        onTap: () => onFilterChanged(filter),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(child: SizedBox(height: 12.h)),

          // Offers List
          isLoading
              ? SliverToBoxAdapter(child: _buildSkeletonLoader())
              : filteredOffers.isEmpty
                  ? SliverToBoxAdapter(child: _buildEmptyState())
                  : SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final offer = filteredOffers[index];
                            return Padding(
                              padding: EdgeInsets.only(bottom: 12.h),
                              child: _BuyOfferCard(
                                offer: offer,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => P2POfferDetailScreen(offer: offer),
                                  ),
                                ),
                                onMerchantTap: () {
                                  if (offer.merchant != null) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => P2PMerchantProfileScreen(
                                          merchant: offer.merchant!,
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            );
                          },
                          childCount: filteredOffers.length,
                        ),
                      ),
                    ),

          // Bottom padding
          SliverToBoxAdapter(child: SizedBox(height: 24.h)),
        ],
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
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(radius: 20.r),
                    SizedBox(width: 12.w),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(width: 100.w, height: 16.h, color: Colors.white),
                        SizedBox(height: 4.h),
                        Container(width: 60.w, height: 12.h, color: Colors.white),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                Container(width: double.infinity, height: 40.h, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 48.h),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64.sp,
            color: Colors.white24,
          ),
          SizedBox(height: 16.h),
          Text(
            'No offers available',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Try changing your payment filter or check back later',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sell BTC Tab - Create your own offer
class _SellBtcTab extends ConsumerWidget {
  final bool isLoading;
  final VoidCallback onRefresh;

  const _SellBtcTab({
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userOffers = ref.watch(userOffersProvider);

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      backgroundColor: const Color(0xFF111128),
      color: const Color(0xFFF7931A),
      child: CustomScrollView(
        slivers: [
          // Explainer Card
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
              child: _ExplainerCard(
                icon: Icons.sell,
                iconColor: const Color(0xFFF7931A),
                title: 'Sell Bitcoin',
                description: 'Create an offer to sell your BTC. Buyers will pay you via your preferred payment method.',
              ),
            ),
          ),

          // Create Offer Card
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: _CreateOfferCard(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const P2PCreateOfferScreen(),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(child: SizedBox(height: 16.h)),

          // Important Info Card
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: _ImportantInfoCard(),
            ),
          ),

          SliverToBoxAdapter(child: SizedBox(height: 16.h)),

          // Your Active Offers Section
          if (userOffers.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Your Offers',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${userOffers.length} offer${userOffers.length > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: 8.h)),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final offer = userOffers[index];
                    return Padding(
                      padding: EdgeInsets.only(bottom: 12.h),
                      child: _SellOfferCard(
                        offer: offer,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => P2POfferDetailScreen(offer: offer),
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: userOffers.length,
                ),
              ),
            ),
          ],

          // Empty state for no offers
          if (userOffers.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 24.h),
                child: Column(
                  children: [
                    Icon(
                      Icons.storefront_outlined,
                      size: 48.sp,
                      color: Colors.white24,
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      'No offers yet',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Create your first offer to start selling',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom padding
          SliverToBoxAdapter(child: SizedBox(height: 24.h)),
        ],
      ),
    );
  }
}

/// Explainer Card Widget
class _ExplainerCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  const _ExplainerCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: iconColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, color: iconColor, size: 24.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.white70,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Create Offer Card
class _CreateOfferCard extends StatelessWidget {
  final VoidCallback onTap;

  const _CreateOfferCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFF7931A),
              const Color(0xFFE8820F),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF7931A).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                Icons.add,
                color: Colors.white,
                size: 28.sp,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create New Offer',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Set your price and payment methods',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withOpacity(0.8),
              size: 20.sp,
            ),
          ],
        ),
      ),
    );
  }
}

/// Important Info Card for sellers
class _ImportantInfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF111128),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: const Color(0xFF4FC3F7),
                size: 20.sp,
              ),
              SizedBox(width: 8.w),
              Text(
                'Important for Sellers',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF4FC3F7),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          _InfoPoint(
            icon: Icons.timer,
            text: '4-minute payment window to protect against price volatility',
          ),
          SizedBox(height: 8.h),
          _InfoPoint(
            icon: Icons.lock,
            text: 'Your BTC is held in escrow until payment is confirmed',
          ),
          SizedBox(height: 8.h),
          _InfoPoint(
            icon: Icons.verified_user,
            text: 'Optional Trade Code adds extra verification security',
          ),
          SizedBox(height: 12.h),
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const P2PEscrowInfoScreen()),
            ),
            child: Row(
              children: [
                Text(
                  'Learn more about P2P trading',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: const Color(0xFFF7931A),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(width: 4.w),
                Icon(
                  Icons.arrow_forward,
                  color: const Color(0xFFF7931A),
                  size: 14.sp,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPoint extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoPoint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white54, size: 16.sp),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13.sp,
              color: Colors.white70,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

/// Offer Card for Buy Tab (shows seller info prominently)
class _BuyOfferCard extends StatelessWidget {
  final P2POfferModel offer;
  final VoidCallback onTap;
  final VoidCallback onMerchantTap;

  const _BuyOfferCard({
    required this.offer,
    required this.onTap,
    required this.onMerchantTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: const Color(0xFF111128),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Seller Info Row
            Row(
              children: [
                GestureDetector(
                  onTap: onMerchantTap,
                  child: CircleAvatar(
                    radius: 22.r,
                    backgroundColor: const Color(0xFF1A1A3E),
                    backgroundImage: offer.merchant?.avatarUrl != null
                        ? CachedNetworkImageProvider(offer.merchant!.avatarUrl!)
                        : null,
                    child: offer.merchant?.avatarUrl == null
                        ? Icon(Icons.person, color: Colors.white54, size: 22.sp)
                        : null,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              offer.merchant?.name ?? offer.name,
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (offer.merchant?.isVerified == true) ...[
                            SizedBox(width: 4.w),
                            Icon(
                              Icons.verified,
                              color: const Color(0xFF4FC3F7),
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
                            color: const Color(0xFFFFD700),
                            size: 14.sp,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            '${offer.ratingPercent}%',
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: Colors.white70,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            '${offer.trades} trades',
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Response time badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C853).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    offer.eta,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: const Color(0xFF00C853),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 12.h),
            Divider(color: Colors.white12, height: 1),
            SizedBox(height: 12.h),

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
                        fontSize: 12.sp,
                        color: Colors.white54,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '₦${_formatNumber(offer.pricePerBtc)}',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF00C853),
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
                        fontSize: 12.sp,
                        color: Colors.white54,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '₦${_formatCompact(offer.minLimit.toDouble())} - ₦${_formatCompact(offer.maxLimit.toDouble())}',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            SizedBox(height: 12.h),

            // Payment Method
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A3E),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                offer.paymentMethod,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.white70,
                ),
              ),
            ),

            SizedBox(height: 12.h),

            // Buy Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C853),
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  'Buy BTC',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(double number) {
    return number.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  String _formatCompact(double number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(0)}K';
    }
    return number.toStringAsFixed(0);
  }
}

/// Offer Card for Sell Tab (shows your offer details)
class _SellOfferCard extends StatelessWidget {
  final P2POfferModel offer;
  final VoidCallback onTap;

  const _SellOfferCard({
    required this.offer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: const Color(0xFF111128),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: const Color(0xFFF7931A).withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type and margin
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: offer.type == OfferType.sell
                        ? const Color(0xFFF7931A).withOpacity(0.2)
                        : const Color(0xFF00C853).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    offer.type == OfferType.sell ? 'Selling' : 'Buying',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: offer.type == OfferType.sell
                          ? const Color(0xFFF7931A)
                          : const Color(0xFF00C853),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (offer.marginPercent != null)
                  Text(
                    '${offer.marginPercent! >= 0 ? '+' : ''}${offer.marginPercent!.toStringAsFixed(1)}% margin',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.white54,
                    ),
                  ),
              ],
            ),

            SizedBox(height: 12.h),

            // Price
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Price',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.white54,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '₦${_formatNumber(offer.pricePerBtc)}/BTC',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFF7931A),
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
                        fontSize: 12.sp,
                        color: Colors.white54,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '₦${_formatCompact(offer.minLimit.toDouble())} - ₦${_formatCompact(offer.maxLimit.toDouble())}',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            SizedBox(height: 12.h),

            // Payment Method
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A3E),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                offer.paymentMethod,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(double number) {
    return number.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  String _formatCompact(double number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(0)}K';
    }
    return number.toStringAsFixed(0);
  }
}

/// Live Rates Card - Displays BTC rates in user's selected currency
class _LiveRatesCard extends ConsumerWidget {
  final double btcNgnRate;
  final double usdNgnRate;

  const _LiveRatesCard({
    required this.btcNgnRate,
    required this.usdNgnRate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCurrency = ref.watch(selectedFiatCurrencyProvider);
    
    // For display purposes:
    // - If user prefers USD, show BTC/USD and USD/NGN
    // - If user prefers NGN, show BTC/NGN and USD/NGN
    final showBtcUsd = selectedCurrency == FiatCurrency.usd;
    
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A1A3E),
            const Color(0xFF111128),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white12),
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
                      padding: EdgeInsets.all(6.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7931A).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Icon(
                        Icons.currency_bitcoin,
                        color: const Color(0xFFF7931A),
                        size: 14.sp,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      showBtcUsd ? 'BTC/USD' : 'BTC/NGN',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Text(
                  showBtcUsd 
                      ? '\$${_formatNumber(btcNgnRate / usdNgnRate)}'
                      : '₦${_formatNumber(btcNgnRate)}',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 50.h,
            color: Colors.white12,
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: 16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(6.w),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00C853).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Icon(
                          Icons.attach_money,
                          color: const Color(0xFF00C853),
                          size: 14.sp,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'USD/NGN',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    '₦${_formatNumber(usdNgnRate)}',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(double number) {
    return number.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}

/// Filter Chip Widget
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color selectedColor;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.selectedColor = const Color(0xFFF7931A),
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : const Color(0xFF111128),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected ? selectedColor : Colors.white24,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// Icon Button Widget
class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  const _IconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: const Color(0xFF111128),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(icon, color: Colors.white70, size: 20.sp),
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: button,
      );
    }
    return button;
  }
}
