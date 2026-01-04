import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sabi_wallet/features/p2p/data/p2p_offer_model.dart';
import 'package:sabi_wallet/features/p2p/providers/p2p_providers.dart';
import 'package:sabi_wallet/features/p2p/providers/nip99_p2p_providers.dart';
import 'package:sabi_wallet/features/p2p/presentation/screens/p2p_offer_detail_screen.dart';
import 'package:sabi_wallet/features/p2p/presentation/screens/p2p_seller_offer_detail_screen.dart';
import 'package:sabi_wallet/features/p2p/presentation/screens/p2p_notification_screen.dart';
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

  // Popular payment methods for quick filter (including Nigerian methods)
  final List<String> _paymentFilters = [
    'All',
    'GTBank',
    'Opay',
    'PalmPay',
    'Moniepoint',
    'Bank Transfer',
    'Mobile Money',
    'Cash',
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
      P2PLogger.debug(
        'Home',
        'Tab changed to: ${_tabController.index == 0 ? "Buy" : "Sell"}',
      );
    }
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      // Invalidate fetched offers to trigger a fresh fetch from relays
      ref.invalidate(fetchedNostrOffersProvider);

      // Give relays time to respond
      await Future.delayed(const Duration(milliseconds: 1500));
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
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C1A),
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder:
              (context, innerBoxIsScrolled) => [
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
                                // Notification Bell
                                Consumer(
                                  builder: (context, ref, _) {
                                    final unreadCountAsync = ref.watch(
                                      p2pUnreadCountProvider,
                                    );
                                    final unreadCount =
                                        unreadCountAsync.asData?.value ?? 0;
                                    return Stack(
                                      children: [
                                        _IconButton(
                                          icon: Icons.notifications_outlined,
                                          onTap:
                                              () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder:
                                                      (_) =>
                                                          const P2PNotificationScreen(),
                                                ),
                                              ),
                                          tooltip: 'Notifications',
                                        ),
                                        if (unreadCount > 0)
                                          Positioned(
                                            right: 0,
                                            top: 0,
                                            child: Container(
                                              padding: EdgeInsets.all(4.w),
                                              decoration: const BoxDecoration(
                                                color: Colors.orange,
                                                shape: BoxShape.circle,
                                              ),
                                              constraints: BoxConstraints(
                                                minWidth: 16.w,
                                                minHeight: 16.w,
                                              ),
                                              child: Center(
                                                child: Text(
                                                  unreadCount > 9
                                                      ? '9+'
                                                      : '$unreadCount',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10.sp,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                                SizedBox(width: 8.w),
                                _IconButton(
                                  icon: Icons.help_outline,
                                  onTap:
                                      () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (_) =>
                                                  const P2PEscrowInfoScreen(),
                                        ),
                                      ),
                                  tooltip: 'How it works',
                                ),
                                SizedBox(width: 8.w),
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
                                  tooltip: 'Trade History',
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
                                  tooltip: 'My Trades',
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),

                        // NIP-99 Relay Status Indicator
                        const _Nip99StatusBanner(),
                        SizedBox(height: 12.h),

                        // Live Rates Card - Real rates from API
                        const _LiveRatesCard(),
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
                              color:
                                  _tabController.index == 0
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
                onFilterChanged:
                    (filter) => setState(() => _selectedPaymentFilter = filter),
                onRefresh: _loadData,
              ),
              // Sell BTC Tab
              _SellBtcTab(isLoading: _isLoading, onRefresh: _loadData),
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
    // Use NIP-99 offers (kind 30402) as primary source
    final nip99OffersAsync = ref.watch(nip99P2POffersStreamProvider);
    final nip99FetchedAsync = ref.watch(nip99P2POffersProvider);

    // Fallback to legacy fetched offers if NIP-99 stream is empty
    final legacyFetchedAsync = ref.watch(fetchedNostrOffersProvider);

    // Combine NIP-99 streamed and fetched offers, deduplicating by ID
    final nip99Offers = nip99OffersAsync.asData?.value ?? [];
    final nip99Fetched = nip99FetchedAsync.asData?.value ?? [];
    final legacyOffers = legacyFetchedAsync.asData?.value ?? [];

    final offerMap = <String, P2POfferModel>{};

    // Priority: NIP-99 fetched -> NIP-99 streamed -> Legacy fallback
    for (final o in legacyOffers) {
      offerMap[o.id] = o;
    }
    for (final o in nip99Fetched) {
      offerMap[o.id] = o;
    }
    for (final o in nip99Offers) {
      offerMap[o.id] = o; // Streamed offers override fetched
    }

    final dedupedOffers = offerMap.values.toList();

    // Get sell offers (offers from sellers who want to sell BTC)
    final sellOffers =
        dedupedOffers.where((o) => o.type == OfferType.sell).toList();

    // Apply payment filter
    final filteredOffers =
        selectedPaymentFilter == 'All'
            ? sellOffers
            : sellOffers
                .where(
                  (o) =>
                      o.paymentMethod.toLowerCase().contains(
                        selectedPaymentFilter.toLowerCase(),
                      ) ||
                      (o.acceptedMethods?.any(
                            (pm) => pm.name.toLowerCase().contains(
                              selectedPaymentFilter.toLowerCase(),
                            ),
                          ) ??
                          false),
                )
                .toList();

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
                description:
                    'Browse offers from sellers. Pay with your preferred method and receive BTC directly to your wallet.',
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
                  children:
                      paymentFilters.map((filter) {
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
                sliver: Consumer(
                  builder: (context, ref, _) {
                    // Get user's offers to check ownership
                    final userOffersAsync = ref.watch(userNip99OffersProvider);
                    final userOfferIds =
                        userOffersAsync.asData?.value
                            .map((o) => o.id)
                            .toSet() ??
                        <String>{};

                    return SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final offer = filteredOffers[index];
                        // Check if this is user's own offer
                        final isOwner = userOfferIds.contains(offer.id);
                        // All offers are now from NIP-99 (remote)
                        const isRemote = true;
                        return Padding(
                          padding: EdgeInsets.only(bottom: 12.h),
                          child: _BuyOfferCard(
                            offer: offer,
                            isRemote: isRemote,
                            isOwner: isOwner,
                            onTap: () {
                              // Route to seller screen for owner, buyer screen otherwise
                              if (isOwner) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => P2PSellerOfferDetailScreen(
                                          offer: offer,
                                        ),
                                  ),
                                );
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) =>
                                            P2POfferDetailScreen(offer: offer),
                                  ),
                                );
                              }
                            },
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
                      }, childCount: filteredOffers.length),
                    );
                  },
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
                        Container(
                          width: 100.w,
                          height: 16.h,
                          color: Colors.white,
                        ),
                        SizedBox(height: 4.h),
                        Container(
                          width: 60.w,
                          height: 12.h,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                Container(
                  width: double.infinity,
                  height: 40.h,
                  color: Colors.white,
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
      padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 48.h),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64.sp, color: Colors.white24),
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
            style: TextStyle(fontSize: 14.sp, color: Colors.white54),
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

  const _SellBtcTab({required this.isLoading, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use NIP-99 user offers instead of local storage
    final userOffersAsync = ref.watch(userNip99OffersProvider);
    final userOffers = userOffersAsync.asData?.value ?? [];
    final nip99OffersAsync = ref.watch(nip99P2POffersStreamProvider);
    final nostrOffers = nip99OffersAsync.asData?.value ?? [];
    final nip99FetchedAsync = ref.watch(nip99P2POffersProvider);
    final nip99Fetched = nip99FetchedAsync.asData?.value ?? [];

    // Combine all offers and get BUY offers (buyers looking to buy BTC)
    final offerMap = <String, P2POfferModel>{};
    for (final o in nip99Fetched) {
      offerMap[o.id] = o;
    }
    for (final o in nostrOffers) {
      offerMap[o.id] = o;
    }
    final allOffers = offerMap.values.toList();

    // Get buy offers (offers from buyers who want to buy BTC) - excluding user's own
    final userOfferIds = userOffers.map((o) => o.id).toSet();
    final buyOffers =
        allOffers
            .where(
              (o) => o.type == OfferType.buy && !userOfferIds.contains(o.id),
            )
            .toList();

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
                description:
                    'Create your own offer OR respond to buyers looking to purchase BTC.',
              ),
            ),
          ),

          // Create Offer Card
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: _CreateOfferCard(
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const P2PCreateOfferScreen(),
                      ),
                    ),
              ),
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
                      style: TextStyle(fontSize: 14.sp, color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: 8.h)),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final offer = userOffers[index];
                  return Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: _SellOfferCard(
                      offer: offer,
                      isRemote: nostrOffers.any((o) => o.id == offer.id),
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) =>
                                      P2PSellerOfferDetailScreen(offer: offer),
                            ),
                          ),
                    ),
                  );
                }, childCount: userOffers.length),
              ),
            ),
          ],

          SliverToBoxAdapter(child: SizedBox(height: 16.h)),

          // Buy Requests Section - Buyers looking to buy BTC
          if (buyOffers.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00C853).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        'HOT',
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF00C853),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Buyers Looking for BTC',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${buyOffers.length} request${buyOffers.length > 1 ? 's' : ''}',
                      style: TextStyle(fontSize: 14.sp, color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: 8.h)),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Text(
                  'Respond to these buyers to sell your BTC quickly',
                  style: TextStyle(fontSize: 12.sp, color: Colors.white54),
                ),
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: 12.h)),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final offer = buyOffers[index];
                  return Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: _BuyRequestCard(
                      offer: offer,
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => P2POfferDetailScreen(offer: offer),
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
                }, childCount: buyOffers.length),
              ),
            ),
          ],

          // Empty state for no offers
          if (userOffers.isEmpty && buyOffers.isEmpty)
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
                      style: TextStyle(fontSize: 14.sp, color: Colors.white54),
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
            colors: [const Color(0xFFF7931A), const Color(0xFFE8820F)],
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
              child: Icon(Icons.add, color: Colors.white, size: 28.sp),
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

/// Offer Card for Buy Tab (shows seller info prominently)
class _BuyOfferCard extends StatelessWidget {
  final P2POfferModel offer;
  final bool isRemote;
  final bool isOwner;
  final VoidCallback onTap;
  final VoidCallback onMerchantTap;

  const _BuyOfferCard({
    required this.offer,
    this.isRemote = false,
    this.isOwner = false,
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
                    backgroundColor: _getAvatarColor(
                      offer.merchant?.name ?? offer.name,
                    ),
                    backgroundImage:
                        offer.merchant?.avatarUrl != null
                            ? CachedNetworkImageProvider(
                              offer.merchant!.avatarUrl!,
                            )
                            : null,
                    child:
                        offer.merchant?.avatarUrl == null
                            ? Text(
                              _getInitials(offer.merchant?.name ?? offer.name),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            )
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
                          if (isOwner) ...[
                            SizedBox(width: 6.w),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: Text(
                                'Your Offer',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                          if (isRemote && !isOwner) ...[
                            SizedBox(width: 6.w),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF9333EA),
                                    Color(0xFF7C3AED),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.bolt,
                                    color: Colors.white,
                                    size: 10.sp,
                                  ),
                                  SizedBox(width: 2.w),
                                  Text(
                                    'NIP-99',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
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
                      style: TextStyle(fontSize: 12.sp, color: Colors.white54),
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
                      style: TextStyle(fontSize: 12.sp, color: Colors.white54),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '₦${_formatCompact(offer.minLimit.toDouble())} - ₦${_formatCompact(offer.maxLimit.toDouble())}',
                      style: TextStyle(fontSize: 14.sp, color: Colors.white),
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
                style: TextStyle(fontSize: 12.sp, color: Colors.white70),
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
    return number
        .toStringAsFixed(0)
        .replaceAllMapped(
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

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFF9C27B0), // Purple
      const Color(0xFF2196F3), // Blue
      const Color(0xFF00BCD4), // Cyan
      const Color(0xFF4CAF50), // Green
      const Color(0xFFFF9800), // Orange
      const Color(0xFFE91E63), // Pink
      const Color(0xFF673AB7), // Deep Purple
      const Color(0xFF009688), // Teal
    ];
    return colors[name.hashCode.abs() % colors.length];
  }
}

/// Offer Card for Sell Tab (shows your offer details)
class _SellOfferCard extends StatelessWidget {
  final P2POfferModel offer;
  final bool isRemote;
  final VoidCallback onTap;

  const _SellOfferCard({
    required this.offer,
    this.isRemote = false,
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
          border: Border.all(color: const Color(0xFFF7931A).withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type and margin
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color:
                        offer.type == OfferType.sell
                            ? const Color(0xFFF7931A).withOpacity(0.2)
                            : const Color(0xFF00C853).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    offer.type == OfferType.sell ? 'Selling' : 'Buying',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color:
                          offer.type == OfferType.sell
                              ? const Color(0xFFF7931A)
                              : const Color(0xFF00C853),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (offer.marginPercent != null)
                  Row(
                    children: [
                      Text(
                        '${offer.marginPercent! >= 0 ? '+' : ''}${offer.marginPercent!.toStringAsFixed(1)}% margin',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.white54,
                        ),
                      ),
                      if (isRemote) ...[
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF9333EA), Color(0xFF7C3AED)],
                            ),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.bolt,
                                color: Colors.white,
                                size: 11.sp,
                              ),
                              SizedBox(width: 2.w),
                              Text(
                                'NIP-99',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
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
                      style: TextStyle(fontSize: 12.sp, color: Colors.white54),
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
                      style: TextStyle(fontSize: 12.sp, color: Colors.white54),
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
                style: TextStyle(fontSize: 12.sp, color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(double number) {
    return number
        .toStringAsFixed(0)
        .replaceAllMapped(
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

/// Live Rates Card - Displays REAL BTC rates from API
class _LiveRatesCard extends ConsumerStatefulWidget {
  const _LiveRatesCard();

  @override
  ConsumerState<_LiveRatesCard> createState() => _LiveRatesCardState();
}

class _LiveRatesCardState extends ConsumerState<_LiveRatesCard> {
  double? _btcNgnRate;
  double? _btcUsdRate;
  double? _usdNgnRate;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRates();
  }

  Future<void> _loadRates() async {
    setState(() => _isLoading = true);
    try {
      final btcNgn = await RateService.getBtcToNgnRate();
      final btcUsd = await RateService.getBtcToUsdRate();
      final usdNgn = await RateService.getUsdToNgnRate();
      if (mounted) {
        setState(() {
          _btcNgnRate = btcNgn;
          _btcUsdRate = btcUsd;
          _usdNgnRate = usdNgn;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCurrency = ref.watch(selectedFiatCurrencyProvider);
    final showBtcUsd = selectedCurrency == FiatCurrency.usd;

    final btcRate = showBtcUsd ? (_btcUsdRate ?? 0) : (_btcNgnRate ?? 0);
    final usdRate = _usdNgnRate ?? 0;

    return GestureDetector(
      onTap: _loadRates,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF1A1A3E), const Color(0xFF111128)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.white12),
        ),
        child:
            _isLoading
                ? Center(
                  child: SizedBox(
                    width: 20.w,
                    height: 20.h,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFF7931A),
                    ),
                  ),
                )
                : Row(
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
                                  color: const Color(
                                    0xFFF7931A,
                                  ).withOpacity(0.2),
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
                              SizedBox(width: 4.w),
                              Icon(
                                Icons.refresh,
                                color: Colors.white24,
                                size: 12.sp,
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            showBtcUsd
                                ? '\$${_formatNumber(btcRate)}'
                                : '₦${_formatNumber(btcRate)}',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 50.h, color: Colors.white12),
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
                                    color: const Color(
                                      0xFF00C853,
                                    ).withOpacity(0.2),
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
                              '₦${_formatNumber(usdRate)}',
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
      ),
    );
  }

  String _formatNumber(double number) {
    return number
        .toStringAsFixed(0)
        .replaceAllMapped(
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

  const _IconButton({required this.icon, required this.onTap, this.tooltip});

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
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

/// Buy Request Card - Shows buyers looking for BTC (for Sell BTC tab)
class _BuyRequestCard extends StatelessWidget {
  final P2POfferModel offer;
  final VoidCallback onTap;
  final VoidCallback onMerchantTap;

  const _BuyRequestCard({
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
          border: Border.all(color: const Color(0xFF00C853).withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Buyer Info Row
            Row(
              children: [
                GestureDetector(
                  onTap: onMerchantTap,
                  child: CircleAvatar(
                    radius: 22.r,
                    backgroundColor: const Color(0xFF1A1A3E),
                    backgroundImage:
                        offer.merchant?.avatarUrl != null
                            ? CachedNetworkImageProvider(
                              offer.merchant!.avatarUrl!,
                            )
                            : null,
                    child:
                        offer.merchant?.avatarUrl == null
                            ? Icon(
                              Icons.person,
                              color: Colors.white54,
                              size: 22.sp,
                            )
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
                          SizedBox(width: 6.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00C853),
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Text(
                              'BUYING',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
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
                            '${offer.merchant?.rating.toStringAsFixed(1) ?? '5.0'}',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.white70,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            '${offer.merchant?.totalTrades ?? 0} trades',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),

            // Rate and Limits
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Wants to pay',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: Colors.white54,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        '₦${_formatAmount(offer.pricePerBtc.toInt())}',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF00C853),
                        ),
                      ),
                      Text(
                        'per BTC',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Amount range',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: Colors.white54,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        '₦${_formatAmount(offer.minLimit)} - ₦${_formatAmount(offer.maxLimit)}',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),

            // Payment Methods and CTA
            Row(
              children: [
                // Payment Method
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.account_balance_wallet,
                        size: 14.sp,
                        color: Colors.white70,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        offer.paymentMethod,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Sell Button
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7931A),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sell, size: 14.sp, color: Colors.white),
                      SizedBox(width: 4.w),
                      Text(
                        'Sell',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatAmount(int amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return amount.toString();
  }
}

/// NIP-99 Relay Status Banner
class _Nip99StatusBanner extends ConsumerWidget {
  const _Nip99StatusBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nip99Offers = ref.watch(nip99P2POffersProvider);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF9333EA).withOpacity(0.15),
            const Color(0xFF7C3AED).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFF9333EA).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 8.w,
            height: 8.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: nip99Offers.when(
                data: (_) => const Color(0xFF00C853),
                loading: () => const Color(0xFFFFA726),
                error: (_, __) => Colors.red,
              ),
              boxShadow: [
                BoxShadow(
                  color: nip99Offers.when(
                    data: (_) => const Color(0xFF00C853).withOpacity(0.5),
                    loading: () => const Color(0xFFFFA726).withOpacity(0.5),
                    error: (_, __) => Colors.red.withOpacity(0.5),
                  ),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Icon(Icons.bolt, color: const Color(0xFF9333EA), size: 14.sp),
          SizedBox(width: 4.w),
          Text(
            'NIP-99 Marketplace',
            style: TextStyle(
              color: const Color(0xFF9333EA),
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          nip99Offers.when(
            data:
                (offers) => Text(
                  '${offers.length} offers',
                  style: TextStyle(color: Colors.white54, fontSize: 11.sp),
                ),
            loading:
                () => SizedBox(
                  width: 12.w,
                  height: 12.h,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: const Color(0xFF9333EA),
                  ),
                ),
            error:
                (_, __) => Text(
                  'Offline',
                  style: TextStyle(color: Colors.red, fontSize: 11.sp),
                ),
          ),
        ],
      ),
    );
  }
}
