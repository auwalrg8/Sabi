// Merchant Profile Screen
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/services/profile_service.dart';
import 'dart:io';
import '../../data/models/p2p_models.dart';
import '../../providers/p2p_providers.dart';
import '../theme/p2p_theme.dart';
import '../widgets/p2p_widgets.dart';

class MerchantProfileScreen extends ConsumerWidget {
  final String merchantId;

  const MerchantProfileScreen({
    super.key,
    required this.merchantId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(merchantProfileProvider(merchantId));
    final selectedTab = ref.watch(merchantProfileTabProvider);

    return Scaffold(
      backgroundColor: P2PColors.background,
      appBar: P2PAppBar(title: 'Merchant Profile'),
      body: profileAsync.when(
        data: (profile) => _MerchantProfileContent(
          profile: profile,
          selectedTab: selectedTab,
          onTabChanged: (tab) {
            ref.read(merchantProfileTabProvider.notifier).state = tab;
          },
        ),
        loading: () => const P2PLoadingState(),
        error: (error, _) => P2PErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(merchantProfileProvider(merchantId)),
        ),
      ),
    );
  }
}

class _MerchantProfileContent extends StatelessWidget {
  final MerchantProfile profile;
  final MerchantProfileTab selectedTab;
  final ValueChanged<MerchantProfileTab> onTabChanged;

  const _MerchantProfileContent({
    required this.profile,
    required this.selectedTab,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Profile header
                FutureBuilder(
                  future: ProfileService.getProfile(),
                  builder: (ctx, snap) {
                    final user = snap.data;
                    final isCurrentUser = user != null && (profile.id == user.username || profile.name == user.fullName || profile.name == user.username);
                    if (isCurrentUser && user!.profilePicturePath != null && user.profilePicturePath!.isNotEmpty) {
                      // Build a header that uses the user's uploaded picture but keeps the existing layout
                      return Column(children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            image: DecorationImage(image: FileImage(File(user.profilePicturePath!)), fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(user.fullName, style: P2PTextStyles.heading2),
                        const SizedBox(height: 4),
                        Text('@${user.username}', style: P2PTextStyles.bodySmall),
                      ]);
                    }
                    return _ProfileHeader(profile: profile);
                  },
                ),
                const SizedBox(height: 24),
                // Stats grid
                _StatsGrid(stats: profile.stats),
                const SizedBox(height: 16),
                // Feedback row
                _FeedbackRow(stats: profile.stats),
                const SizedBox(height: 24),
                // Tab bar
                _ProfileTabBar(
                  selectedTab: selectedTab,
                  onTabChanged: onTabChanged,
                ),
                // Tab content
                _TabContent(
                  selectedTab: selectedTab,
                  profile: profile,
                ),
              ],
            ),
          ),
        ),
        // Start Trade button
        Padding(
          padding: const EdgeInsets.all(16),
          child: P2PPrimaryButton(
            label: 'Start Trade',
            onPressed: () {
              // TODO: Navigate to create trade screen
            },
          ),
        ),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final MerchantProfile profile;

  const _ProfileHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        // Avatar with verification
        Stack(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: P2PColors.cardBackgroundLight,
                border: Border.all(
                  color: P2PColors.cardBackgroundLight,
                  width: 4,
                ),
                image: profile.avatar != null
                    ? DecorationImage(
                        image: NetworkImage(profile.avatar!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: profile.avatar == null
                  ? Center(
                      child: Text(
                        profile.name[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: P2PColors.textPrimary,
                        ),
                      ),
                    )
                  : null,
            ),
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: P2PColors.success,
                ),
                child: const Icon(
                  Icons.check,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Name with verification badge
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              profile.name,
              style: P2PTextStyles.heading2,
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: P2PColors.success,
              ),
              child: const Icon(
                Icons.check,
                size: 14,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Verification type
        Text(
          profile.verifications.isNotEmpty
              ? '${profile.verifications.first.name.capitalize()} Verified'
              : 'Not Verified',
          style: P2PTextStyles.bodySmall,
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final MerchantStats stats;

  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: P2PStatCard(
                  label: '30d Trades',
                  value: stats.trades30d.toString(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: P2PStatCard(
                  label: 'Completion Rate',
                  value: stats.completionRate.toStringAsFixed(0),
                  valueColor: P2PColors.success,
                  showPercentage: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: P2PStatCard(
                  label: 'Avg Release',
                  value: '${stats.avgReleaseTime.inMinutes} min',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: P2PStatCard(
                  label: 'Total Volume',
                  value: _formatVolume(stats.totalVolume, stats.volumeCurrency),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatVolume(double volume, String currency) {
    final symbol = currency == 'NGN' ? '₦' : currency;
    if (volume >= 1000000000) {
      return '$symbol${(volume / 1000000000).toStringAsFixed(0)}B';
    } else if (volume >= 1000000) {
      return '$symbol${(volume / 1000000).toStringAsFixed(0)}M';
    } else if (volume >= 1000) {
      return '$symbol${(volume / 1000).toStringAsFixed(0)}K';
    }
    return '$symbol${volume.toStringAsFixed(0)}';
  }
}

class _FeedbackRow extends StatelessWidget {
  final MerchantStats stats;

  const _FeedbackRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: P2PDecorations.statCardDecoration,
        child: Row(
          children: [
            const Text(
              'Feedback',
              style: P2PTextStyles.statLabel,
            ),
            const SizedBox(width: 16),
            P2PFeedbackThumbs(
              positive: stats.positiveFeedback,
              negative: stats.negativeFeedback,
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Rating',
                  style: P2PTextStyles.statLabel,
                ),
                Text(
                  '${stats.rating.toStringAsFixed(0)} %',
                  style: P2PTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTabBar extends StatelessWidget {
  final MerchantProfileTab selectedTab;
  final ValueChanged<MerchantProfileTab> onTabChanged;

  const _ProfileTabBar({
    required this.selectedTab,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: P2PColors.divider,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: MerchantProfileTab.values.map((tab) {
          final isSelected = tab == selectedTab;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTabChanged(tab),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected
                          ? P2PColors.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  tab.name.capitalize(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? P2PColors.primary
                        : P2PColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TabContent extends StatelessWidget {
  final MerchantProfileTab selectedTab;
  final MerchantProfile profile;

  const _TabContent({
    required this.selectedTab,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    return switch (selectedTab) {
      MerchantProfileTab.info => _InfoTab(profile: profile),
      MerchantProfileTab.ads => _AdsTab(ads: profile.ads),
      MerchantProfileTab.feedback => _FeedbackTab(feedbacks: profile.feedbacks),
    };
  }
}

class _InfoTab extends StatelessWidget {
  final MerchantProfile profile;

  const _InfoTab({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Verification section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: P2PDecorations.cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verification',
                  style: P2PTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                ...profile.verifications.map((v) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: P2PVerificationBadge(
                        type: v.name.capitalize(),
                        isVerified: true,
                      ),
                    )),
                if (profile.verifications.isEmpty)
                  const Text(
                    'No verifications yet',
                    style: P2PTextStyles.bodySmall,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Account info section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: P2PDecorations.cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account Info',
                  style: P2PTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                _InfoRow(
                  label: 'Joined',
                  value: _formatJoinDate(profile.joinedAt),
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  label: 'First Trade',
                  value: '${profile.daysToFirstTrade} days after joining',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatJoinDate(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: P2PTextStyles.bodySmall,
        ),
        Text(
          value,
          style: P2PTextStyles.bodyMedium,
        ),
      ],
    );
  }
}

class _AdsTab extends StatelessWidget {
  final List<MerchantAd> ads;

  const _AdsTab({required this.ads});

  @override
  Widget build(BuildContext context) {
    if (ads.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: P2PEmptyState(
          message: 'No ads yet',
          icon: Icons.campaign_outlined,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: ads.map((ad) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _AdCard(ad: ad),
        )).toList(),
      ),
    );
  }
}

class _AdCard extends StatelessWidget {
  final MerchantAd ad;

  const _AdCard({required this.ad});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: P2PDecorations.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Merchant info row
          Row(
            children: [
              P2PAvatar(
                imageUrl: ad.merchantAvatar,
                name: ad.merchantName,
                size: 40,
                showVerificationBadge: true,
                isVerified: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          ad.merchantName,
                          style: P2PTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: P2PColors.success,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 10,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${ad.merchantRating.toStringAsFixed(0)}% (${ad.merchantTrades} trades)',
                      style: P2PTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Price per BTC
          Text(
            '₦${_formatPrice(ad.pricePerBtc)}',
            style: P2PTextStyles.priceText,
          ),
          const Text(
            'per 1 BTC',
            style: P2PTextStyles.bodySmall,
          ),
          const SizedBox(height: 16),
          // Pay and receive row
          Row(
            children: [
              _PriceColumn(
                label: 'Pay',
                value: formatFiat(ad.minAmount),
              ),
              const SizedBox(width: 24),
              _PriceColumn(
                label: 'Receive BTC',
                value: '₦${ad.satsPerFiat.toStringAsFixed(2)}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Payment method and limits
          Row(
            children: [
              const Text(
                'Payment',
                style: P2PTextStyles.bodySmall,
              ),
              const SizedBox(width: 8),
              Text(
                ad.paymentMethod,
                style: P2PTextStyles.bodySmall,
              ),
              const SizedBox(width: 4),
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: P2PColors.textMuted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${ad.paymentWindow.inMinutes}-${ad.paymentWindow.inMinutes} min',
                style: P2PTextStyles.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Limits and trade button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Limits',
                    style: P2PTextStyles.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatFiat(ad.minAmount)}  -  ${formatFiat(ad.maxAmount)}',
                    style: P2PTextStyles.bodySmall,
                  ),
                ],
              ),
              // Trade button
              SizedBox(
                width: 80,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: Start trade with this ad
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: P2PColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Trade',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: P2PColors.background,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatPrice(double price) {
    return price.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}

class _PriceColumn extends StatelessWidget {
  final String label;
  final String value;

  const _PriceColumn({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: P2PTextStyles.caption,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: P2PTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _FeedbackTab extends StatelessWidget {
  final List<MerchantFeedback> feedbacks;

  const _FeedbackTab({required this.feedbacks});

  @override
  Widget build(BuildContext context) {
    if (feedbacks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: P2PEmptyState(
          message: 'No feedback yet',
          icon: Icons.rate_review_outlined,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: feedbacks.map((feedback) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: P2PDecorations.cardDecoration,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                P2PAvatar(
                  imageUrl: feedback.fromUserAvatar,
                  name: feedback.fromUserName,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            feedback.fromUserName,
                            style: P2PTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            feedback.isPositive
                                ? Icons.thumb_up
                                : Icons.thumb_down,
                            size: 16,
                            color: feedback.isPositive
                                ? P2PColors.success
                                : P2PColors.error,
                          ),
                        ],
                      ),
                      if (feedback.comment != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          feedback.comment!,
                          style: P2PTextStyles.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        formatDate(feedback.createdAt, includeYear: true),
                        style: P2PTextStyles.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )).toList(),
      ),
    );
  }
}

// Extension for string capitalization
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
