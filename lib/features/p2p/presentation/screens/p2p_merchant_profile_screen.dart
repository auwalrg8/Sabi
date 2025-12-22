import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:sabi_wallet/features/p2p/data/merchant_model.dart';
import 'package:sabi_wallet/features/p2p/data/p2p_offer_model.dart';
import 'package:sabi_wallet/features/p2p/providers/p2p_providers.dart';
import 'package:sabi_wallet/features/p2p/presentation/screens/p2p_offer_detail_screen.dart';

/// P2P Merchant Profile Screen - NoOnes inspired
class P2PMerchantProfileScreen extends ConsumerWidget {
  final MerchantModel merchant;

  const P2PMerchantProfileScreen({super.key, required this.merchant});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offers = ref.watch(p2pOffersProvider)
        .where((o) => o.merchant?.id == merchant.id)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C1A),
      body: CustomScrollView(
        slivers: [
          // App Bar with Profile Header
          SliverAppBar(
            backgroundColor: const Color(0xFF111128),
            expandedHeight: 200.h,
            pinned: true,
            leading: IconButton(
              icon: Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C0C1A).withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18.sp),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _getAvatarColor(merchant.name).withOpacity(0.3),
                      const Color(0xFF111128),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: 40.h),
                      // Avatar
                      Container(
                        width: 80.w,
                        height: 80.h,
                        decoration: BoxDecoration(
                          color: _getAvatarColor(merchant.name),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 3,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: merchant.avatarUrl != null
                            ? CachedNetworkImage(
                                imageUrl: merchant.avatarUrl!,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => _buildInitial(),
                              )
                            : _buildInitial(),
                      ),
                      SizedBox(height: 12.h),
                      // Name and verification
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            merchant.name,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (merchant.isVerified) ...[
                            SizedBox(width: 6.w),
                            Icon(
                              Icons.verified,
                              color: const Color(0xFF00FFB2),
                              size: 20.sp,
                            ),
                          ],
                          if (merchant.isNostrVerified) ...[
                            SizedBox(width: 6.w),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.key,
                                    color: const Color(0xFF8B5CF6),
                                    size: 12.sp,
                                  ),
                                  SizedBox(width: 2.w),
                                  Text(
                                    'Nostr',
                                    style: TextStyle(
                                      color: const Color(0xFF8B5CF6),
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w600,
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
                ),
              ),
            ),
          ),

          // Stats Cards
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                children: [
                  // Stats Row
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.check_circle,
                          value: '${merchant.completionRate.toStringAsFixed(0)}%',
                          label: 'Completion',
                          color: const Color(0xFF00FFB2),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.swap_horiz,
                          value: '${merchant.trades30d}',
                          label: '30d Trades',
                          color: const Color(0xFFF7931A),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.timer,
                          value: '${merchant.avgReleaseMinutes}m',
                          label: 'Avg. Release',
                          color: const Color(0xFF6366F1),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),

                  // Detailed Stats
                  Container(
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111128),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Column(
                      children: [
                        _DetailRow(
                          icon: Icons.thumb_up,
                          label: 'Positive Reviews',
                          value: '${merchant.positiveFeedback}',
                          color: const Color(0xFF00FFB2),
                        ),
                        SizedBox(height: 16.h),
                        _DetailRow(
                          icon: Icons.thumb_down,
                          label: 'Negative Reviews',
                          value: '${merchant.negativeFeedback}',
                          color: merchant.negativeFeedback == 0
                              ? const Color(0xFFA1A1B2)
                              : const Color(0xFFFF6B6B),
                        ),
                        SizedBox(height: 16.h),
                        _DetailRow(
                          icon: Icons.account_balance_wallet,
                          label: 'Total Volume',
                          value: '₦${_formatVolume(merchant.totalVolume)}',
                          color: const Color(0xFFF7931A),
                        ),
                        SizedBox(height: 16.h),
                        _DetailRow(
                          icon: Icons.calendar_today,
                          label: 'Member Since',
                          value: _formatDate(merchant.joinedDate),
                          color: const Color(0xFFA1A1B2),
                        ),
                        if (merchant.firstTradeDate != null) ...[
                          SizedBox(height: 16.h),
                          _DetailRow(
                            icon: Icons.history,
                            label: 'First Trade',
                            value: _formatDate(merchant.firstTradeDate!),
                            color: const Color(0xFFA1A1B2),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // Trust Score
                  Container(
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00FFB2).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: const Color(0xFF00FFB2).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00FFB2).withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.security,
                            color: const Color(0xFF00FFB2),
                            size: 32.sp,
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Trust Score',
                                style: TextStyle(
                                  color: const Color(0xFFA1A1B2),
                                  fontSize: 12.sp,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Row(
                                children: [
                                  Text(
                                    _calculateTrustScore().toString(),
                                    style: TextStyle(
                                      color: const Color(0xFF00FFB2),
                                      fontSize: 28.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '/100',
                                    style: TextStyle(
                                      color: const Color(0xFFA1A1B2),
                                      fontSize: 16.sp,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        _buildTrustBadge(),
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // Active Offers Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Active Offers',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${offers.length} offers',
                        style: TextStyle(
                          color: const Color(0xFFA1A1B2),
                          fontSize: 14.sp,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                ],
              ),
            ),
          ),

          // Offers List
          offers.isEmpty
              ? SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40.h),
                    child: Column(
                      children: [
                        Icon(
                          Icons.inbox,
                          size: 48.sp,
                          color: const Color(0xFF6B6B80),
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          'No active offers',
                          style: TextStyle(
                            color: const Color(0xFFA1A1B2),
                            fontSize: 14.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final offer = offers[index];
                        return Padding(
                          padding: EdgeInsets.only(bottom: 12.h),
                          child: _MerchantOfferCard(
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
                      childCount: offers.length,
                    ),
                  ),
                ),

          // Bottom padding
          SliverToBoxAdapter(child: SizedBox(height: 40.h)),
        ],
      ),
    );
  }

  Widget _buildInitial() {
    return Center(
      child: Text(
        merchant.name.isNotEmpty ? merchant.name[0].toUpperCase() : '?',
        style: TextStyle(
          color: Colors.white,
          fontSize: 32.sp,
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

  String _formatVolume(double volume) {
    if (volume >= 1000000000) {
      return '${(volume / 1000000000).toStringAsFixed(1)}B';
    } else if (volume >= 1000000) {
      return '${(volume / 1000000).toStringAsFixed(1)}M';
    } else if (volume >= 1000) {
      return '${(volume / 1000).toStringAsFixed(0)}K';
    }
    return volume.toStringAsFixed(0);
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  int _calculateTrustScore() {
    double score = 50.0;
    
    // Completion rate (max 30 points)
    score += merchant.completionRate * 0.3;
    
    // Trades in 30 days (max 10 points)
    score += (merchant.trades30d / 20).clamp(0, 10);
    
    // Verification bonus (5 points each)
    if (merchant.isVerified) score += 5;
    if (merchant.isNostrVerified) score += 5;
    
    // No negative feedback bonus
    if (merchant.negativeFeedback == 0) score += 5;
    
    return score.round().clamp(0, 100);
  }

  Widget _buildTrustBadge() {
    final score = _calculateTrustScore();
    String label;
    Color color;

    if (score >= 90) {
      label = 'Excellent';
      color = const Color(0xFF00FFB2);
    } else if (score >= 70) {
      label = 'Good';
      color = const Color(0xFFF7931A);
    } else if (score >= 50) {
      label = 'Fair';
      color = const Color(0xFFFFC107);
    } else {
      label = 'New';
      color = const Color(0xFFA1A1B2);
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Stat Card
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF111128),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24.sp),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              color: const Color(0xFFA1A1B2),
              fontSize: 11.sp,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Detail Row
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFA1A1B2), size: 20.sp),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: const Color(0xFFA1A1B2),
              fontSize: 14.sp,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Merchant Offer Card
class _MerchantOfferCard extends StatelessWidget {
  final P2POfferModel offer;
  final VoidCallback onTap;

  const _MerchantOfferCard({
    required this.offer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,###');
    final isSell = offer.type == OfferType.sell;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: const Color(0xFF111128),
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: (isSell ? const Color(0xFFFF6B6B) : const Color(0xFF00FFB2))
                        .withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    isSell ? 'SELL' : 'BUY',
                    style: TextStyle(
                      color: isSell ? const Color(0xFFFF6B6B) : const Color(0xFF00FFB2),
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  offer.paymentMethod,
                  style: TextStyle(
                    color: const Color(0xFFA1A1B2),
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
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
                    Text(
                      '₦${formatter.format(offer.pricePerBtc.toInt())}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
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
                    Text(
                      '₦${_formatLimit(offer.minLimit)} - ₦${_formatLimit(offer.maxLimit)}',
                      style: TextStyle(
                        color: const Color(0xFFA1A1B2),
                        fontSize: 13.sp,
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

  String _formatLimit(int limit) {
    if (limit >= 1000000) {
      return '${(limit / 1000000).toStringAsFixed(1)}M';
    } else if (limit >= 1000) {
      return '${(limit / 1000).toStringAsFixed(0)}K';
    }
    return limit.toString();
  }
}
