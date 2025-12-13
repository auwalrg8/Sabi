import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/core/services/secure_storage_service.dart';
import 'package:sabi_wallet/features/onboarding/presentation/providers/wallet_creation_provider.dart';
import 'package:sabi_wallet/features/onboarding/presentation/screens/backup_choice_screen.dart';

import '../providers/onboarding_provider.dart';
import 'import_nostr_screen.dart';
import 'recover_with_guys_screen.dart';
import 'seed_recovery_screen.dart';

class EntryChoiceScreen extends ConsumerStatefulWidget {
  const EntryChoiceScreen({super.key});

  @override
  ConsumerState<EntryChoiceScreen> createState() => _EntryChoiceScreenState();
}

class _EntryChoiceScreenState extends ConsumerState<EntryChoiceScreen> {
  Future<void> _prepareAndProceed() async {
    final walletCreationNotifier = ref.read(walletCreationProvider.notifier);
    walletCreationNotifier.setLoading(true);
    walletCreationNotifier.setError(null);

    try {
      // Ensure we have a user id stored (generate if missing)
      final storage = ref.read(secureStorageServiceProvider);
      String? userId = await storage.getUserId();
      if (userId == null) {
        userId = _generateUuidV4();
        await storage.saveUserId(userId);
      }

      if (!mounted) return;

      // Backend manages Breez; frontend proceeds to backup flow without creating wallet yet
      ref
          .read(onboardingNotifierProvider.notifier)
          .setPath(OnboardingPath.createNew);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BackupChoiceScreen()),
      );
    } catch (e) {
      walletCreationNotifier.setError('Error preparing wallet: $e');
    } finally {
      walletCreationNotifier.setLoading(false);
    }
  }

  // Simple UUID v4 generator (no external package) — good enough for client-side id
  String _generateUuidV4() {
    // Generate a simple UUID v4-style string (not cryptographically secure, but sufficient for client-side)
    final now = DateTime.now();
    final random = now.microsecond ^ now.millisecond;
    final hex1 = now.year.toRadixString(16).padLeft(8, '0');
    final hex2 =
        now.month.toRadixString(16).padLeft(2, '0') +
        now.day.toRadixString(16).padLeft(2, '0');
    final hex3 =
        now.hour.toRadixString(16).padLeft(2, '0') +
        now.minute.toRadixString(16).padLeft(2, '0');
    final hex4 =
        now.second.toRadixString(16).padLeft(2, '0') +
        random.toRadixString(16).padLeft(6, '0');
    final hex5 = now.microsecond.toRadixString(16).padLeft(12, '0');

    return '$hex1-$hex2-4$hex3-a$hex4-$hex5';
  }

  @override
  Widget build(BuildContext context) {
    final walletCreationState = ref.watch(walletCreationProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 29),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Image.asset(
                'assets/images/sabi_logo.png',
                width: 165.w,
                height: 120.h,
              ),
              const SizedBox(height: 30),

              const Text(
                'Choose how to start',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              _CreateWalletCard(
                onTap:
                    walletCreationState.isLoading ? null : _prepareAndProceed,
                isLoading: walletCreationState.isLoading,
              ),
              const SizedBox(height: 20),
              _RecoverWalletCard(
                onTap: () {
                  ref
                      .read(onboardingNotifierProvider.notifier)
                      .setPath(OnboardingPath.recoverWithGuys);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RecoverWithGuysScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed:
                    walletCreationState.isLoading
                        ? null
                        : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SeedRecoveryScreen(),
                            ),
                          );
                        },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.key_outlined,
                      size: 16,
                      color: AppColors.borderColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Restore from seed phrase',
                      style: TextStyle(
                        color: AppColors.borderColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed:
                    walletCreationState.isLoading
                        ? null
                        : () {
                          ref
                              .read(onboardingNotifierProvider.notifier)
                              .setPath(OnboardingPath.importNostr);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ImportNostrScreen(),
                            ),
                          );
                        },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.vpn_key_outlined,
                      size: 16,
                      color: AppColors.borderColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'I already get Nostr keys',
                      style: TextStyle(
                        color: AppColors.borderColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              if (walletCreationState.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(
                    walletCreationState.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateWalletCard extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isLoading;

  const _CreateWalletCard({required this.onTap, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
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
          Container(
            width: 56,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.add_circle_outline,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Create new wallet',
            style: TextStyle(
              color: AppColors.background,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Start fresh with your own Bitcoin wallet. E go \ntake less than 2 minutes.',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.83,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: isLoading ? null : onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child:
                  isLoading
                      ? const CircularProgressIndicator(
                        color: AppColors.textPrimary,
                      )
                      : const Text(
                        'Get Started',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          height: 1.87,
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecoverWalletCard extends StatelessWidget {
  final VoidCallback onTap;

  const _RecoverWalletCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
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
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.accentGreen.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people_outline,
              color: AppColors.accentGreen,
              size: 28,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Recover with your guys',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Lost your phone? Your trusted contacts go \nhelp you get your wallet back.',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.83,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.textPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Start Recovery',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
