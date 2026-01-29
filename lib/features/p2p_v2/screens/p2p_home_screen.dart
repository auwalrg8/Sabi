import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/services/nostr/nostr_service.dart';
import '../providers/p2p_provider.dart';
import '../data/p2p_state.dart';
import '../widgets/offer_card.dart';
import 'p2p_offer_detail_screen.dart';
import 'p2p_create_offer_screen.dart';
import 'p2p_trade_screen.dart';

/// P2P v2 Home Screen
/// 
/// Clean, simple interface with two tabs:
/// - Browse: View and filter offers from other users
/// - My Offers: Manage your own offers and active trades
class P2PV2HomeScreen extends ConsumerStatefulWidget {
  const P2PV2HomeScreen({super.key});

  @override
  ConsumerState<P2PV2HomeScreen> createState() => _P2PV2HomeScreenState();
}

class _P2PV2HomeScreenState extends ConsumerState<P2PV2HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ScrollController _scrollController;
  String _selectedFilter = 'All';
  String _selectedCurrency = 'NGN'; // Default to Nigerian Naira
  P2POfferType? _typeFilter;
  bool _isLoadingMore = false;

  final List<String> _paymentFilters = [
    'All',
    'Bank Transfer',
    'GTBank',
    'Opay',
    'PalmPay',
    'Mobile Money',
  ];
  
  final List<String> _currencyFilters = [
    'NGN', // Nigerian Naira
    'GHS', // Ghanaian Cedi
    'KES', // Kenyan Shilling
    'ZAR', // South African Rand
    'USD', // US Dollar
    'All', // Show all currencies
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  void _onScroll() {
    if (_isLoadingMore) return;
    
    // Load more when user is near the bottom (80% scrolled)
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent * 0.8) {
      _loadMore();
    }
  }
  
  Future<void> _loadMore() async {
    final state = ref.read(p2pV2Provider);
    if (!state.hasMoreOffers || state.isLoadingOffers) return;
    
    setState(() => _isLoadingMore = true);
    
    final notifier = ref.read(p2pV2Provider.notifier);
    await notifier.loadMoreOffers(
      currency: _selectedCurrency == 'All' ? null : _selectedCurrency,
      type: _typeFilter,
      paymentMethod: _selectedFilter == 'All' ? null : _selectedFilter,
    );
    
    setState(() => _isLoadingMore = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(p2pV2Provider);
    final notifier = ref.read(p2pV2Provider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context, state),
            
            // Tab Bar
            _buildTabBar(),
            
            // Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Browse Tab
                  _buildBrowseTab(state, notifier),
                  
                  // My Offers Tab
                  _buildMyOffersTab(state, notifier),
                  
                  // My Trades Tab
                  _buildMyTradesTab(state, notifier),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton.extended(
              onPressed: () => _navigateToCreateOffer(context),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                'Create Offer',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : _tabController.index == 2 && state.trades.isEmpty
              ? null  // No FAB on empty trades tab
              : null,
    );
  }

  Widget _buildHeader(BuildContext context, P2PState state) {
    return Container(
      padding: EdgeInsets.all(16.w),
      child: Row(
        children: [
          if (Navigator.canPop(context))
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40.w,
                height: 40.h,
                margin: EdgeInsets.only(right: 12.w),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(Icons.arrow_back, color: Colors.white, size: 20.sp),
              ),
            ),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'P2P Trading',
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4.h),
                _buildConnectionStatus(state.connectionStatus),
              ],
            ),
          ),
          
          // Active trades badge
          if (state.trades.isNotEmpty)
            GestureDetector(
              onTap: () => _showActiveTrades(context),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: AppColors.primary, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sync, color: AppColors.primary, size: 16.sp),
                    SizedBox(width: 4.w),
                    Text(
                      '${state.trades.values.where((t) => !t.isCompleted && !t.isCancelled).length} Active',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
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

  Widget _buildConnectionStatus(RelayConnectionStatus status) {
    Color color;
    String text;
    IconData icon;

    switch (status) {
      case RelayConnectionStatus.connected:
        color = AppColors.accentGreen;
        text = 'Connected';
        icon = Icons.wifi;
        break;
      case RelayConnectionStatus.connecting:
        color = AppColors.accentYellow;
        text = 'Connecting...';
        icon = Icons.wifi_find;
        break;
      case RelayConnectionStatus.reconnecting:
        color = AppColors.accentYellow;
        text = 'Reconnecting...';
        icon = Icons.wifi_find;
        break;
      case RelayConnectionStatus.error:
        color = AppColors.accentRed;
        text = 'Connection Error';
        icon = Icons.wifi_off;
        break;
      case RelayConnectionStatus.disconnected:
        color = AppColors.textTertiary;
        text = 'Disconnected';
        icon = Icons.wifi_off;
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 12.sp),
        SizedBox(width: 4.w),
        Text(
          text,
          style: TextStyle(color: color, fontSize: 12.sp),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    final state = ref.watch(p2pV2Provider);
    final activeTrades = state.trades.values
        .where((t) => !t.isCompleted && !t.isCancelled)
        .length;
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(10.r),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
        tabs: [
          const Tab(text: 'Browse'),
          const Tab(text: 'My Offers'),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Trades'),
                if (activeTrades > 0) ...[
                  SizedBox(width: 4.w),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: AppColors.accentRed,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Text(
                      '$activeTrades',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        onTap: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildBrowseTab(P2PState state, P2PStateNotifier notifier) {
    // Get all active offers for browsing
    final myPubkey = notifier.myPubkey;
    final allOffers = state.offers.values
        .where((o) => o.status == P2POfferStatus.active)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    // Separate into own and others' offers
    final othersOffers = allOffers.where((o) => o.pubkey != myPubkey).toList();
    final ownOffers = allOffers.where((o) => o.pubkey == myPubkey).toList();
    
    debugPrint('🔍 Browse tab: ${state.offers.length} total, ${othersOffers.length} from others, ${ownOffers.length} own');
    
    // Show others' offers first, then own offers if none from others
    final offers = othersOffers.isNotEmpty ? othersOffers : allOffers;
    
    // Apply filters
    var filteredOffers = offers.where((o) {
      if (_typeFilter != null && o.type != _typeFilter) return false;
      if (_selectedCurrency != 'All' && o.currency != _selectedCurrency) return false;
      if (_selectedFilter != 'All' && 
          !o.paymentMethods.any((pm) => pm.toLowerCase().contains(_selectedFilter.toLowerCase()))) {
        return false;
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Filters
        _buildFilters(),
        
        // Info banner when showing own offers
        if (othersOffers.isEmpty && ownOffers.isNotEmpty)
          _buildInfoBanner('Showing your own offers. Other users\' offers will appear here when available.'),
        
        // Error state
        if (state.offersError != null)
          _buildErrorState(state.offersError!),
        
        // Offers list with pagination
        Expanded(
          child: state.isLoadingOffers && filteredOffers.isEmpty
              ? _buildLoadingState()
              : filteredOffers.isEmpty
                  ? _buildEmptyState('No offers found', 'Try adjusting your filters or pull down to refresh')
                  : RefreshIndicator(
                      onRefresh: () => notifier.refreshOffers(
                        currency: _selectedCurrency == 'All' ? null : _selectedCurrency,
                        type: _typeFilter,
                        paymentMethod: _selectedFilter == 'All' ? null : _selectedFilter,
                      ),
                      color: AppColors.primary,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.all(16.w),
                        itemCount: filteredOffers.length + (state.hasMoreOffers ? 1 : 0),
                        itemBuilder: (context, index) {
                          // Show loading indicator at the end
                          if (index == filteredOffers.length) {
                            return _buildLoadMoreIndicator();
                          }
                          
                          final offer = filteredOffers[index];
                          final isOwnOffer = offer.pubkey == myPubkey;
                          return P2POfferCard(
                            offer: offer,
                            isMyOffer: isOwnOffer,
                            onTap: () => _navigateToOfferDetail(context, offer, isMyOffer: isOwnOffer),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
  
  Widget _buildLoadMoreIndicator() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      child: Center(
        child: _isLoadingMore
            ? SizedBox(
                width: 24.w,
                height: 24.h,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            : Text(
                'Scroll for more',
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 12.sp,
                ),
              ),
      ),
    );
  }
  
  Widget _buildInfoBanner(String message) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.primary, size: 20.sp),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type filter (Buy/Sell) and Currency filter in same row
          Row(
            children: [
              // Type filters
              _buildTypeChip('All', null),
              SizedBox(width: 8.w),
              _buildTypeChip('Buy', P2POfferType.buy),
              SizedBox(width: 8.w),
              _buildTypeChip('Sell', P2POfferType.sell),
              
              const Spacer(),
              
              // Currency dropdown
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCurrency,
                    isDense: true,
                    dropdownColor: AppColors.surface,
                    icon: Icon(Icons.keyboard_arrow_down, color: AppColors.primary, size: 18.sp),
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                    items: _currencyFilters.map((currency) {
                      return DropdownMenuItem(
                        value: currency,
                        child: Text(currency),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedCurrency = value);
                        // Refresh with new currency filter
                        ref.read(p2pV2Provider.notifier).refreshOffers(
                          currency: value == 'All' ? null : value,
                          type: _typeFilter,
                        );
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 12.h),
          
          // Payment method filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _paymentFilters.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: EdgeInsets.only(right: 8.w),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedFilter = filter),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary.withValues(alpha: 0.2) : AppColors.surface,
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        filter,
                        style: TextStyle(
                          color: isSelected ? AppColors.primary : AppColors.textSecondary,
                          fontSize: 12.sp,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String label, P2POfferType? type) {
    final isSelected = _typeFilter == type;
    return GestureDetector(
      onTap: () => setState(() => _typeFilter = type),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontSize: 13.sp,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildMyOffersTab(P2PState state, P2PStateNotifier notifier) {
    // Get my offers from watched state
    final myPubkey = notifier.myPubkey;
    final myOffers = state.offers.values
        .where((o) => o.pubkey == myPubkey)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    // Get active trades from watched state
    final activeTrades = state.trades.values
        .where((t) => !t.isCompleted && !t.isCancelled)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return RefreshIndicator(
      onRefresh: () => notifier.refreshOffers(),
      color: AppColors.primary,
      child: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          // Active trades section
          if (activeTrades.isNotEmpty) ...[
            _buildSectionHeader('Active Trades', activeTrades.length),
            SizedBox(height: 8.h),
            ...activeTrades.map((trade) => _buildTradeCard(trade)),
            SizedBox(height: 24.h),
          ],
          
          // My offers section
          _buildSectionHeader('My Offers', myOffers.length),
          SizedBox(height: 8.h),
          
          if (state.isLoadingOffers)
            _buildLoadingState()
          else if (myOffers.isEmpty)
            _buildEmptyState(
              'No offers yet',
              'Tap the button below to create your first offer',
            )
          else
            ...myOffers.map((offer) => P2POfferCard(
              offer: offer,
              isMyOffer: true,
              onTap: () => _navigateToOfferDetail(context, offer, isMyOffer: true),
              onEdit: () => _navigateToEditOffer(context, offer),
              onDelete: () => _confirmDeleteOffer(context, offer.id, notifier),
            )),
            
          // Add padding at bottom for FAB
          SizedBox(height: 80.h),
        ],
      ),
    );
  }

  /// Build the My Trades tab showing all user's trades
  Widget _buildMyTradesTab(P2PState state, P2PStateNotifier notifier) {
    final allTrades = state.trades.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    
    // Separate into active and completed
    final activeTrades = allTrades.where((t) => !t.isCompleted && !t.isCancelled).toList();
    final completedTrades = allTrades.where((t) => t.isCompleted || t.isCancelled).toList();

    // Check for trades that need attention (buyer or seller action required)
    final needsMyAction = activeTrades.where((t) {
      final isBuyer = t.buyerPubkey == notifier.myPubkey;
      final isSeller = t.sellerPubkey == notifier.myPubkey;
      
      // Buyer needs to pay or upload receipt
      if (isBuyer && t.status == TradeStatus.awaitingPayment) return true;
      // Seller needs to accept, confirm, or release
      if (isSeller && t.status == TradeStatus.requested) return true;
      if (isSeller && t.status == TradeStatus.paymentSent) return true;
      if (isSeller && t.status == TradeStatus.paymentConfirmed) return true;
      
      return false;
    }).toList();

    return RefreshIndicator(
      onRefresh: () => notifier.refreshOffers(), // This also refreshes trades
      color: AppColors.primary,
      child: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          // Action needed section
          if (needsMyAction.isNotEmpty) ...[
            _buildSectionHeader('⚡ Action Needed', needsMyAction.length),
            SizedBox(height: 8.h),
            ...needsMyAction.map((trade) => _buildTradeCard(trade, highlight: true)),
            SizedBox(height: 24.h),
          ],
          
          // Active trades section
          if (activeTrades.isNotEmpty) ...[
            _buildSectionHeader('Active Trades', activeTrades.length),
            SizedBox(height: 8.h),
            ...activeTrades
                .where((t) => !needsMyAction.contains(t))
                .map((trade) => _buildTradeCard(trade)),
            SizedBox(height: 24.h),
          ],
          
          // Completed trades section
          if (completedTrades.isNotEmpty) ...[
            _buildSectionHeader('Completed', completedTrades.length),
            SizedBox(height: 8.h),
            ...completedTrades.take(10).map((trade) => _buildTradeCard(trade)),
            
            if (completedTrades.length > 10)
              TextButton(
                onPressed: () {
                  // Could show full history
                },
                child: Text(
                  'Show ${completedTrades.length - 10} more...',
                  style: TextStyle(color: AppColors.primary, fontSize: 14.sp),
                ),
              ),
          ],
          
          // Empty state
          if (allTrades.isEmpty) ...[
            SizedBox(height: 60.h),
            _buildEmptyState(
              'No trades yet',
              'When you buy or sell Bitcoin, your trades will appear here',
            ),
          ],
          
          // Info card about notifications
          if (activeTrades.isNotEmpty)
            Container(
              margin: EdgeInsets.only(top: 16.h),
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.notifications_active, color: AppColors.primary, size: 20.sp),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      'You\'ll receive notifications when your trades need attention',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          SizedBox(height: 40.h),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        SizedBox(width: 8.w),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.sp,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTradeCard(P2PTrade trade, {bool highlight = false}) {
    return GestureDetector(
      onTap: () => _navigateToTrade(context, trade.id),
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: highlight 
              ? AppColors.primary.withValues(alpha: 0.1) 
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: highlight 
                ? AppColors.primary 
                : _getTradeStatusColor(trade.status).withValues(alpha: 0.5),
            width: highlight ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: _getTradeStatusColor(trade.status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    trade.statusLabel,
                    style: TextStyle(
                      color: _getTradeStatusColor(trade.status),
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  trade.formattedAmount,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              'Trade ID: ${trade.id.substring(0, 16)}...',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 12.sp,
              ),
            ),
            SizedBox(height: 4.h),
            Row(
              children: [
                Icon(Icons.access_time, color: AppColors.textTertiary, size: 14.sp),
                SizedBox(width: 4.w),
                Text(
                  _formatTimeAgo(trade.updatedAt),
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16.h),
            Text(
              'Loading offers...',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64.sp,
              color: AppColors.textTertiary,
            ),
            SizedBox(height: 16.h),
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              subtitle,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14.sp,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.accentRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.accentRed.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.accentRed, size: 24.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              error,
              style: TextStyle(
                color: AppColors.accentRed,
                fontSize: 13.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getTradeStatusColor(TradeStatus status) {
    switch (status) {
      case TradeStatus.requested:
        return AppColors.accentYellow;
      case TradeStatus.awaitingPayment:
        return AppColors.accentYellow;
      case TradeStatus.paymentSent:
        return AppColors.primary;
      case TradeStatus.paymentConfirmed:
        return AppColors.accentGreen;
      case TradeStatus.releasing:
        return AppColors.primary;
      case TradeStatus.completed:
        return AppColors.accentGreen;
      case TradeStatus.cancelled:
        return AppColors.accentRed;
      case TradeStatus.disputed:
        return AppColors.accentRed;
      case TradeStatus.expired:
        return AppColors.textTertiary;
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // Navigation methods
  void _navigateToOfferDetail(BuildContext context, NostrP2POffer offer, {bool isMyOffer = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => P2PV2OfferDetailScreen(
          offerId: offer.id,
          isMyOffer: isMyOffer,
        ),
      ),
    );
  }

  void _navigateToCreateOffer(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const P2PV2CreateOfferScreen()),
    );
  }

  void _navigateToEditOffer(BuildContext context, NostrP2POffer offer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => P2PV2CreateOfferScreen(editOffer: offer),
      ),
    );
  }

  void _navigateToTrade(BuildContext context, String tradeId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => P2PV2TradeScreen(tradeId: tradeId),
      ),
    );
  }

  void _showActiveTrades(BuildContext context) {
    // Switch to Trades tab
    _tabController.animateTo(2);
  }

  Future<void> _confirmDeleteOffer(
    BuildContext context,
    String offerId,
    P2PStateNotifier notifier,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Delete Offer',
          style: TextStyle(color: Colors.white, fontSize: 18.sp),
        ),
        content: Text(
          'Are you sure you want to delete this offer? This action cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: TextStyle(color: AppColors.accentRed),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await notifier.deleteOffer(offerId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Offer deleted' : 'Failed to delete offer'),
            backgroundColor: success ? AppColors.accentGreen : AppColors.accentRed,
          ),
        );
      }
    }
  }
}
