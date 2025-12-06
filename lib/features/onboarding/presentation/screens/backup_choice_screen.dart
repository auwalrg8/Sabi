import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
          padding: const EdgeInsets.symmetric(horizontal: 31, vertical: 29),
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
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Choose your backup method',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      height: 1.78,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _BackupOptionCard(
                        recommended: true,
                        icon: Icons.people_outline,
                        iconColor: AppColors.primary,
                        iconBackgroundColor: AppColors.primary.withValues(alpha: 0.2),
                        title: 'Pick 3 trusted guys',
                        description: 'No seed phrase. Your guys wey dey use \nBitcoin/Nostr go help you recover.',
                        featureText: 'Most secure for Nigerian users',
                        featureIcon: Icons.check_circle_outline,
                        featureIconColor: AppColors.accentGreen,
                        buttonText: 'Choose my guys',
                        buttonColor: AppColors.primary,
                        buttonTextColor: AppColors.textPrimary,
                        borderColor: AppColors.primary,
                        onTap: () async {
                          ref.read(onboardingNotifierProvider.notifier).setBackupMethod(BackupMethod.socialRecovery);
                          
                            // Create wallet with backup_type='social' (handles errors silently)
                            await WalletCreationHelper.createWalletWithBackupType(
                              ref: ref,
                              backupType: 'social',
                            );
                          
                          if (context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SocialRecoveryScreen()),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 30),
                      _BackupOptionCard(
                        icon: Icons.vpn_key_outlined,
                        iconColor: AppColors.textTertiary,
                        iconBackgroundColor: AppColors.borderColor.withValues(alpha: 0.5),
                        title: 'Classic 12-word backup',
                        description: 'Old-school seed phrase. You go write am \ndown yourself.',
                        featureText: 'You must keep the paper safe',
                        featureIcon: Icons.warning_amber_outlined,
                        featureIconColor: AppColors.accentYellow,
                        buttonText: 'Show me the 12 words',
                        buttonColor: AppColors.surface,
                        buttonTextColor: AppColors.textPrimary,
                        onTap: () async {
                          ref.read(onboardingNotifierProvider.notifier).setBackupMethod(BackupMethod.seedPhrase);
                          
                            // Create wallet with backup_type='seed' (handles errors silently)
                            await WalletCreationHelper.createWalletWithBackupType(
                              ref: ref,
                              backupType: 'seed',
                            );
                          
                          if (context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SeedPhraseScreen()),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 30),
                      _BackupOptionCard(
                        icon: Icons.warning_amber_outlined,
                        iconColor: AppColors.accentRed,
                        iconBackgroundColor: AppColors.accentRed.withValues(alpha: 0.2),
                        title: 'Skip for now',
                        description: 'You fit set am later for Settings. But if phone \nloss, money go loss forever o.',
                        featureText: 'Very dangerous - not recommended',
                        featureIcon: Icons.warning_amber_outlined,
                        featureIconColor: AppColors.accentRed,
                        featureTextColor: AppColors.accentRed,
                        buttonText: 'Skip (I understand)',
                        buttonColor: Colors.transparent,
                        buttonTextColor: AppColors.primary,
                        borderColor: AppColors.primary,
                        onTap: () async {
                          ref.read(onboardingNotifierProvider.notifier).setBackupMethod(BackupMethod.skip);

                          // Create wallet with backup_type=none
                          await WalletCreationHelper.createWalletWithBackupType(
                            ref: ref,
                            backupType: 'none',
                          );

                          // Show wallet creation animation, then navigate to home
                          if (context.mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const WalletCreationAnimationScreen()),
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
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: borderColor != null
            ? Border.all(color: borderColor!)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBackgroundColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 24,
                ),
              ),
              if (recommended)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: const Text(
                    'RECOMMENDED',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      height: 1.6,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1.65,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            description,
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.83,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                featureIcon,
                color: featureIconColor,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                featureText,
                style: TextStyle(
                  color: featureTextColor ?? AppColors.textTertiary,
                  fontSize: 10,
                  fontWeight: featureTextColor != null ? FontWeight.w500 : FontWeight.w400,
                  height: 1.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: buttonTextColor,
                elevation: 0,
                side: buttonColor == Colors.transparent && borderColor != null
                    ? BorderSide(color: borderColor!)
                    : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                buttonText,
                style: TextStyle(
                  fontSize: 14,
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
