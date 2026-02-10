import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/services/hodl_hodl/hodl_hodl.dart';
import 'package:sabi_wallet/features/p2p/presentation/screens/p2p_dashboard_screen.dart';

import 'hodl_hodl_offer_detail_screen.dart';
import 'hodl_hodl_webview_setup_screen.dart';
import 'create_offer_screen.dart';

/// P2P Beta Marketplace Screen
/// Displays Hodl Hodl offers in a clean card-based layout
class HodlHodlMarketplaceScreen extends ConsumerStatefulWidget {
  const HodlHodlMarketplaceScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HodlHodlMarketplaceScreen> createState() => _HodlHodlMarketplaceScreenState();
}

class _HodlHodlMarketplaceScreenState extends ConsumerState<HodlHodlMarketplaceScreen> {
  String _selectedSide = 'sell'; // Default to showing sell offers (user wants to buy)
  String _selectedCurrency = 'NGN';
  
  @override
  Widget build(BuildContext context) {
    final offersAsync = ref.watch(hodlHodlOffersProvider);
    final isConfigured = ref.watch(hodlHodlConfiguredProvider);
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white, size: 24.sp),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'P2P Beta',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.account_circle_outlined, color: Colors.white70, size: 24.sp),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const P2PDashboardScreen()),
            ),
            tooltip: 'Dashboard',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Beta banner
            _buildBetaBanner(),
            SizedBox(height: 12.h),
            
            // Filter row
            _buildFilterRow(),
            SizedBox(height: 16.h),
            
            // API Setup prompt if not configured
            isConfigured.when(
              data: (configured) {
                if (!configured) {
                  return _buildApiSetupPrompt();
                }
                return const SizedBox.shrink();
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            
            // Offers list
            Expanded(
              child: offersAsync.when(
                data: (offers) {
                  // Filter offers by selected side
                  final filteredOffers = offers.where((o) => o.side == _selectedSide).toList();
                  
                  if (filteredOffers.isEmpty) {
                    return _buildEmptyState();
                  }
                  
                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () async {
                      ref.invalidate(hodlHodlOffersProvider);
                    },
                    child: ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      itemCount: filteredOffers.length,
                      itemBuilder: (context, index) {
                        return _buildOfferCard(filteredOffers[index]);
                      },
                    ),
                  );
                },
                loading: () => _buildLoadingState(),
                error: (error, _) => _buildErrorState(error),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          HapticFeedback.mediumImpact();
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const CreateOfferScreen()),
          );
          if (result == true) {
            // Refresh offers if an offer was created
            ref.invalidate(hodlHodlOffersProvider);
          }
        },
        backgroundColor: AppColors.primary,
        icon: Icon(Icons.add, color: Colors.white, size: 20.sp),
        label: Text(
          'Create Offer',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildBetaBanner() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.15),
            AppColors.primary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Text(
              'BETA',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'Powered by Hodl Hodl • Non-custodial P2P',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12.sp,
              ),
            ),
          ),
          Icon(Icons.verified_user, color: AppColors.accentGreen, size: 16.sp),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: [
          // Buy/Sell toggle
          Expanded(
            child: Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedSide = 'sell');
                        _updateFilter();
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 10.h),
                        decoration: BoxDecoration(
                          color: _selectedSide == 'sell' ? AppColors.accentGreen : Colors.transparent,
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Center(
                          child: Text(
                            'Buy BTC',
                            style: TextStyle(
                              color: _selectedSide == 'sell' ? Colors.black : Colors.white70,
                              fontWeight: FontWeight.w600,
                              fontSize: 13.sp,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedSide = 'buy');
                        _updateFilter();
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 10.h),
                        decoration: BoxDecoration(
                          color: _selectedSide == 'buy' ? AppColors.accentRed : Colors.transparent,
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Center(
                          child: Text(
                            'Sell BTC',
                            style: TextStyle(
                              color: _selectedSide == 'buy' ? Colors.white : Colors.white70,
                              fontWeight: FontWeight.w600,
                              fontSize: 13.sp,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 12.w),
          // Currency selector
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCurrency,
                icon: Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 18.sp),
                dropdownColor: AppColors.surface,
                style: TextStyle(color: Colors.white, fontSize: 13.sp),
                items: ['NGN', 'USD', 'USDT'].map((currency) {
                  return DropdownMenuItem(
                    value: currency,
                    child: Text(currency),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCurrency = value);
                    _updateFilter();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApiSetupPrompt() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surface,
            AppColors.surface.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Icon with glow effect
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.link, color: AppColors.primary, size: 32.sp),
          ),
          SizedBox(height: 16.h),
          Text(
            'Connect Hodl Hodl',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Sign up or log in to Hodl Hodl to start trading P2P',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13.sp,
            ),
          ),
          SizedBox(height: 20.h),
          
          // Main connect button
          SizedBox(
            width: double.infinity,
            height: 52.h,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
                elevation: 0,
              ),
              onPressed: _navigateToApiSetup,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.login, color: Colors.white, size: 20.sp),
                  SizedBox(width: 8.w),
                  Text(
                    'Connect Account',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
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

  Widget _buildOfferCard(HodlHodlOffer offer) {
    final isBuyOffer = offer.side == 'sell'; // If seller is selling, user is buying
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HodlHodlOfferDetailScreen(offer: offer),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Trader info
            Row(
              children: [
                // Avatar
                Container(
                  width: 40.w,
                  height: 40.h,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Center(
                    child: Text(
                      offer.trader.login.isNotEmpty 
                          ? offer.trader.login[0].toUpperCase() 
                          : '?',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                // Trader details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            offer.trader.login,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (offer.trader.verified) ...[
                            SizedBox(width: 4.w),
                            Icon(Icons.verified, color: AppColors.accentGreen, size: 14.sp),
                          ],
                        ],
                      ),
                      SizedBox(height: 2.h),
                      Row(
                        children: [
                          Text(
                            '${offer.trader.tradesCount} trades',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12.sp,
                            ),
                          ),
                          if (offer.trader.rating != null) ...[
                            SizedBox(width: 8.w),
                            Icon(Icons.star, color: AppColors.accentYellow, size: 12.sp),
                            SizedBox(width: 2.w),
                            Text(
                              '${(offer.trader.rating! * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12.sp,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Online status
                Container(
                  width: 8.w,
                  height: 8.h,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: offer.trader.onlineStatus == 'online'
                        ? AppColors.accentGreen
                        : offer.trader.onlineStatus == 'recently_online'
                            ? AppColors.accentYellow
                            : Colors.grey,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            
            // Price and limits
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Price',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11.sp,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '${_getCurrencySymbol(offer.currencyCode)}${_formatNumber(double.tryParse(offer.price) ?? 0)}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
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
                        color: Colors.white54,
                        fontSize: 11.sp,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '${_getCurrencySymbol(offer.currencyCode)}${_formatNumber(double.tryParse(offer.minAmount) ?? 0)} - ${_getCurrencySymbol(offer.currencyCode)}${_formatNumber(double.tryParse(offer.maxAmount) ?? 0)}',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13.sp,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12.h),
            
            // Payment method & Action
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.payment, color: Colors.white54, size: 14.sp),
                      SizedBox(width: 6.w),
                      Text(
                        offer.primaryPaymentMethod,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: isBuyOffer ? AppColors.accentGreen : AppColors.accentRed,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    isBuyOffer ? 'Buy' : 'Sell',
                    style: TextStyle(
                      color: isBuyOffer ? Colors.black : Colors.white,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, color: Colors.white24, size: 64.sp),
          SizedBox(height: 16.h),
          Text(
            'No offers found',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Try adjusting your filters',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14.sp,
            ),
          ),
          SizedBox(height: 24.h),
          TextButton.icon(
            onPressed: () => ref.invalidate(hodlHodlOffersProvider),
            icon: Icon(Icons.refresh, color: AppColors.primary, size: 18.sp),
            label: Text(
              'Refresh',
              style: TextStyle(color: AppColors.primary, fontSize: 14.sp),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40.w,
            height: 40.h,
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'Loading offers...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: AppColors.accentRed, size: 48.sp),
            SizedBox(height: 16.h),
            Text(
              'Failed to load offers',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13.sp,
              ),
            ),
            SizedBox(height: 24.h),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              onPressed: () => ref.invalidate(hodlHodlOffersProvider),
              child: Text(
                'Try Again',
                style: TextStyle(color: Colors.white, fontSize: 14.sp),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateFilter() {
    ref.read(hodlHodlFilterProvider.notifier).state = HodlHodlOfferFilter(
      side: _selectedSide,
      currencyCode: _selectedCurrency,
    );
  }

  Future<void> _navigateToApiSetup() async {
    HapticFeedback.lightImpact();
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const HodlHodlWebViewSetupScreen()),
    );
    
    // Refresh if setup was successful
    if (result == true) {
      ref.invalidate(hodlHodlConfiguredProvider);
      ref.invalidate(hodlHodlOffersProvider);
    }
  }

  String _getCurrencySymbol(String code) {
    switch (code) {
      case 'NGN':
        return '₦';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      default:
        return code;
    }
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
