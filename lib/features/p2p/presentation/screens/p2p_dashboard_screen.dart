import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/features/p2p/data/payment_method_model.dart';
import 'package:sabi_wallet/features/p2p/services/payment_method_service.dart';
import 'package:sabi_wallet/features/p2p/services/p2p_trade_manager.dart';
import 'package:sabi_wallet/features/p2p/presentation/screens/p2p_payment_methods_screen.dart';
import 'package:sabi_wallet/features/p2p/presentation/screens/p2p_trade_history_screen.dart';
import 'package:sabi_wallet/features/p2p/presentation/screens/p2p_my_trades_screen.dart';
import 'package:sabi_wallet/features/p2p/presentation/screens/social_profile_settings_screen.dart';
import 'package:sabi_wallet/features/p2p/providers/nip99_p2p_providers.dart';
import 'package:sabi_wallet/services/nostr/nostr_profile_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// P2P Dashboard - User's trading profile and settings
class P2PDashboardScreen extends ConsumerStatefulWidget {
  const P2PDashboardScreen({super.key});

  @override
  ConsumerState<P2PDashboardScreen> createState() => _P2PDashboardScreenState();
}

class _P2PDashboardScreenState extends ConsumerState<P2PDashboardScreen> {
  // Stats
  int _completedTrades = 0;
  int _totalTrades = 0;
  int _activeTrades = 0;
  int _myOffers = 0;
  List<PaymentMethodModel> _paymentMethods = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);

    try {
      final tradeManager = ref.read(p2pTradeManagerProvider);
      final paymentService = ref.read(paymentMethodServiceProvider);

      final allTrades = tradeManager.allTrades;
      final methods = await paymentService.getPaymentMethods();

      // Count trades
      int completed = 0;
      int active = 0;
      for (final trade in allTrades) {
        if (trade.status == P2PTradeStatus.completed) {
          completed++;
        } else if (trade.status != P2PTradeStatus.cancelled &&
            trade.status != P2PTradeStatus.expired) {
          active++;
        }
      }

      // Count user's offers
      final userOffers = await ref.read(userNip99OffersProvider.future);

      if (mounted) {
        setState(() {
          _completedTrades = completed;
          _totalTrades = allTrades.length;
          _activeTrades = active;
          _myOffers = userOffers.length;
          _paymentMethods = methods;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  double get _successRate {
    if (_totalTrades == 0) return 100;
    return (_completedTrades / _totalTrades) * 100;
  }

  @override
  Widget build(BuildContext context) {
    final nostrProfile = NostrProfileService().currentProfile;
    final displayName = nostrProfile?.displayNameOrFallback ?? 'Trader';
    final picture = nostrProfile?.picture;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20.sp),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'P2P Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppColors.primary, size: 24.sp),
            onPressed: _loadStats,
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2.w,
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadStats,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(20.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Header
                    _buildProfileHeader(displayName, picture),
                    SizedBox(height: 24.h),

                    // Stats Grid
                    _buildStatsGrid(),
                    SizedBox(height: 24.h),

                    // Quick Actions
                    Text(
                      'Quick Actions',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    _buildQuickActions(),
                    SizedBox(height: 24.h),

                    // Payment Methods Preview
                    _buildPaymentMethodsSection(),
                    SizedBox(height: 24.h),

                    // Settings
                    Text(
                      'Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    _buildSettingsList(),
                    SizedBox(height: 40.h),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileHeader(String displayName, String? picture) {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.2),
            AppColors.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 32.r,
            backgroundColor: AppColors.primary,
            backgroundImage: (picture != null && picture.isNotEmpty)
                ? CachedNetworkImageProvider(picture)
                : null,
            child: (picture == null || picture.isEmpty)
                ? Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : 'T',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          SizedBox(width: 16.w),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      color: AppColors.accentGreen,
                      size: 16.sp,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      '${_successRate.toStringAsFixed(0)}% Success Rate',
                      style: TextStyle(
                        color: AppColors.accentGreen,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  '$_completedTrades trades completed',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),

          // Edit button
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SocialProfileSettingsScreen(),
                ),
              ).then((_) => _loadStats());
            },
            icon: Icon(
              Icons.edit_rounded,
              color: AppColors.primary,
              size: 20.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.check_circle_outline_rounded,
            iconColor: AppColors.accentGreen,
            label: 'Completed',
            value: '$_completedTrades',
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _buildStatCard(
            icon: Icons.hourglass_empty_rounded,
            iconColor: Colors.orange,
            label: 'Active',
            value: '$_activeTrades',
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _buildStatCard(
            icon: Icons.local_offer_outlined,
            iconColor: AppColors.primary,
            label: 'My Offers',
            value: '$_myOffers',
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 12.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 24.sp),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11.sp,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            icon: Icons.history_rounded,
            label: 'Trade History',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const P2PTradeHistoryScreen()),
              );
            },
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _buildActionButton(
            icon: Icons.swap_horiz_rounded,
            label: 'My Trades',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const P2PMyTradesScreen()),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primary, size: 20.sp),
            SizedBox(width: 8.w),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodsSection() {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Payment Methods',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const P2PPaymentMethodsScreen(),
                    ),
                  ).then((_) => _loadStats());
                },
                child: Text(
                  _paymentMethods.isEmpty ? 'Add' : 'Manage',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),

          if (_paymentMethods.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.textSecondary,
                    size: 20.sp,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      'Add payment methods to receive payments from trades',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13.sp,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: _paymentMethods.take(3).map((method) {
                return Padding(
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: Row(
                    children: [
                      Text(method.type.icon, style: TextStyle(fontSize: 18.sp)),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  method.name,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13.sp,
                                  ),
                                ),
                                if (method.isDefault) ...[
                                  SizedBox(width: 6.w),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6.w,
                                      vertical: 1.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4.r),
                                    ),
                                    child: Text(
                                      'Default',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 9.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              method.displayDetails,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

          if (_paymentMethods.length > 3) ...[
            SizedBox(height: 8.h),
            Text(
              '+${_paymentMethods.length - 3} more',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.sp,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSettingsList() {
    return Column(
      children: [
        _buildSettingsTile(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Payment Methods',
          subtitle: '${_paymentMethods.length} saved',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const P2PPaymentMethodsScreen(),
              ),
            ).then((_) => _loadStats());
          },
        ),
        SizedBox(height: 8.h),
        _buildSettingsTile(
          icon: Icons.person_outline_rounded,
          title: 'Profile Settings',
          subtitle: 'Name, bio, picture',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SocialProfileSettingsScreen(),
              ),
            ).then((_) => _loadStats());
          },
        ),
      ],
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20.sp),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
              size: 24.sp,
            ),
          ],
        ),
      ),
    );
  }
}
