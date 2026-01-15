// lib/features/onboarding/presentation/screens/social_recovery_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/features/recovery/presentation/screens/social_recovery_setup_screen.dart';
import 'package:sabi_wallet/core/services/secure_storage_service.dart';

class SocialRecoveryScreen extends ConsumerStatefulWidget {
  const SocialRecoveryScreen({super.key});

  @override
  ConsumerState<SocialRecoveryScreen> createState() =>
      _SocialRecoveryScreenState();
}

class _SocialRecoveryScreenState extends ConsumerState<SocialRecoveryScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToSetup();
  }

  Future<void> _navigateToSetup() async {
    try {
      final storage = ref.read(secureStorageServiceProvider);
      final masterSeed = await storage.getMnemonic() ?? '';

      if (masterSeed.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Master seed not found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => SocialRecoverySetupScreen(masterSeed: masterSeed),
          ),
          (route) => route.isFirst,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading master seed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
