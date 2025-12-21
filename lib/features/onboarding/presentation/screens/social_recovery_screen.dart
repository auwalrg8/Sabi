// lib/features/onboarding/presentation/screens/social_recovery_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/features/recovery/social_recovery_setup_screen.dart';
import '../providers/onboarding_provider.dart';

class SocialRecoveryScreen extends ConsumerWidget {
  const SocialRecoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingState = ref.watch(onboardingNotifierProvider);
    final masterSeed = onboardingState.wallet?.mnemonic ?? '';

    // Navigate directly to setup screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => SocialRecoverySetupScreen(
            masterSeed: masterSeed,
          ),
        ),
        (route) => route.isFirst,
      );
    });

    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(AppColors.primary),
        ),
      ),
    );
  }
}