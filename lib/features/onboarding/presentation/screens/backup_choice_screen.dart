import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/features/onboarding/presentation/screens/wallet_creation_animation_screen.dart';
import '../providers/onboarding_provider.dart';
import '../providers/wallet_creation_helper.dart';
import 'social_recovery_screen.dart';
import 'seed_phrase_screen.dart';

class BackupChoiceScreen extends ConsumerWidget {
  const BackupChoiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 31.w, vertical: 29.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.arrow_back,
                      color: AppColors.textPrimary,
                      size: 24.w,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    'Choose your backup method',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w500,
                      height: 1.78,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 28.h),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _BackupOptionCard(
                        recommended: true,
                        icon: Icons.people_outline,
                        iconColor: AppColors.primary,
                        iconBackgroundColor: AppColors.primary.withValues(
                          alpha: 0.2,
                        ),
                        title: 'Pick 3 trusted guys',
                        description:
                            'No seed phrase. Your guys wey dey use \nBitcoin/Nostr go help you recover.',
                        featureText: 'Most secure for Nigerian users',
                        featureIcon: Icons.check_circle_outline,
                        featureIconColor: AppColors.accentGreen,
                        buttonText: 'Choose my guys',
                        buttonColor: AppColors.primary,
                        buttonTextColor: AppColors.textPrimary,
                        borderColor: AppColors.primary,
                        onTap: () async {
                          ref
                              .read(onboardingNotifierProvider.notifier)
                              .setBackupMethod(BackupMethod.socialRecovery);

                          await WalletCreationHelper.createWalletWithBackupType(
                            ref: ref,
                            backupType: 'social',
                          );

                          if (context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SocialRecoveryScreen(),
                              ),
                            );
                          }
                        },
                      ),
                      SizedBox(height: 30.h),
                      _BackupOptionCard(
                        icon: Icons.vpn_key_outlined,
                        iconColor: AppColors.textTertiary,
                        iconBackgroundColor: AppColors.borderColor.withValues(
                          alpha: 0.5,
                        ),
                        title: 'Classic 12-word backup',
                        description:
                            'Old-school seed phrase. You go write am \ndown yourself.',
                        featureText: 'You must keep the paper safe',
                        featureIcon: Icons.warning_amber_outlined,
                        featureIconColor: AppColors.accentYellow,
                        buttonText: 'Show me the 12 words',
                        buttonColor: AppColors.surface,
                        buttonTextColor: AppColors.textPrimary,
                        onTap: () async {
                          ref
                              .read(onboardingNotifierProvider.notifier)
                              .setBackupMethod(BackupMethod.seedPhrase);

                          await WalletCreationHelper.createWalletWithBackupType(
                            ref: ref,
                            backupType: 'seed',
                          );

                          if (context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SeedPhraseScreen(),
                              ),
                            );
                          }
                        },
                      ),
                      SizedBox(height: 30.h),
                      _BackupOptionCard(
                        icon: Icons.warning_amber_outlined,
                        iconColor: AppColors.accentRed,
                        iconBackgroundColor: AppColors.accentRed.withValues(
                          alpha: 0.2,
                        ),
                        title: 'Skip for now',
                        description:
                            'You fit set am later for Settings. But if phone \nloss, money go loss forever o.',
                        featureText: 'Very dangerous - not recommended',
                        featureIcon: Icons.warning_amber_outlined,
                        featureIconColor: AppColors.accentRed,
                        featureTextColor: AppColors.accentRed,
                        buttonText: 'Skip (I understand)',
                        buttonColor: Colors.transparent,
                        buttonTextColor: AppColors.primary,
                        borderColor: AppColors.primary,
                        onTap: () async {
                          ref
                              .read(onboardingNotifierProvider.notifier)
                              .setBackupMethod(BackupMethod.skip);

                          await WalletCreationHelper.createWalletWithBackupType(
                            ref: ref,
                            backupType: 'none',
                          );

                          if (context.mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder:
                                    (_) =>
                                        const WalletCreationAnimationScreen(),
                              ),
                              (route) => false,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackupOptionCard extends StatelessWidget {
  final bool recommended;
  final IconData icon;
  final Color iconColor;
  final Color iconBackgroundColor;
  final String title;
  final String description;
  final String featureText;
  final IconData featureIcon;
  final Color featureIconColor;
  final Color? featureTextColor;
  final String buttonText;
  final Color buttonColor;
  final Color buttonTextColor;
  final Color? borderColor;
  final VoidCallback onTap;

  const _BackupOptionCard({
    this.recommended = false,
    required this.icon,
    required this.iconColor,
    required this.iconBackgroundColor,
    required this.title,
    required this.description,
    required this.featureText,
    required this.featureIcon,
    required this.featureIconColor,
    this.featureTextColor,
    required this.buttonText,
    required this.buttonColor,
    required this.buttonTextColor,
    this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(25.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20.r),
        border: borderColor != null ? Border.all(color: borderColor!) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48.w,
                height: 48.w,
                decoration: BoxDecoration(
                  color: iconBackgroundColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24.sp),
              ),
              if (recommended)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(9999.r),
                  ),
                  child: Text(
                    'RECOMMENDED',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      height: 1.6,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 14.h),
          Text(
            title,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              height: 1.65,
            ),
          ),
          SizedBox(height: 14.h),
          Text(
            description,
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12.sp,
              fontWeight: FontWeight.w400,
              height: 1.83,
            ),
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              Icon(featureIcon, color: featureIconColor, size: 16.sp),
              SizedBox(width: 8.w),
              Text(
                featureText,
                style: TextStyle(
                  color: featureTextColor ?? AppColors.textTertiary,
                  fontSize: 10.sp,
                  fontWeight:
                      featureTextColor != null
                          ? FontWeight.w500
                          : FontWeight.w400,
                  height: 1.6,
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          SizedBox(
            width: double.infinity,
            height: 50.h,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: buttonTextColor,
                elevation: 0,
                side:
                    buttonColor == Colors.transparent && borderColor != null
                        ? BorderSide(color: borderColor!)
                        : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
              child: Text(
                buttonText,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  height: 1.71,
                  color: buttonTextColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
