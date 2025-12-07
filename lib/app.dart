import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/features/onboarding/presentation/screens/onboarding_carousel_screen.dart';
import 'package:sabi_wallet/features/wallet/presentation/screens/home_screen.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';

import 'core/theme/app_theme.dart';

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Sabi Wallet',
      debugShowCheckedModeBanner: kDebugMode,
      theme: AppTheme.light,
      home: const _StartupRouter(),
    );
  }
}

class _StartupRouter extends StatefulWidget {
  const _StartupRouter();

  @override
  State<_StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<_StartupRouter> {
  bool _ready = false;
  bool _hasWallet = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Initialize Breez Spark SDK persistence to check onboarding status
    await BreezSparkService.initPersistence();
    
    // If user has completed onboarding, restore SDK from stored mnemonic
    if (BreezSparkService.hasCompletedOnboarding) {
      final mnemonic = BreezSparkService.mnemonic;
      if (mnemonic != null && mnemonic.isNotEmpty) {
        try {
          // Restore SDK connection from stored mnemonic
          await BreezSparkService.initializeSparkSDK(
            mnemonic: mnemonic,
            isRestore: true,
          );
        } catch (e) {
          // If SDK restoration fails, log but don't block app startup
          // User can still access the app and try again
          debugPrint('⚠️ Failed to restore SDK on startup: $e');
        }
      }
    }
    
    setState(() {
      _hasWallet = BreezSparkService.hasCompletedOnboarding;
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return _hasWallet ? const HomeScreen() : const OnboardingCarouselScreen();
  }
}
