import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:breez_sdk_spark_flutter/breez_sdk_spark.dart';
import 'services/secure_storage.dart';
import 'services/breez_spark_service.dart';
import 'services/contact_service.dart';
import 'services/notification_service.dart';
import 'services/profile_service.dart';
import 'features/wallet/presentation/screens/home_screen.dart';
import 'features/onboarding/presentation/screens/onboarding_carousel_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // CRITICAL: Initialize flutter_rust_bridge FIRST, before any SDK calls
  await BreezSdkSparkLib.init();
  debugPrint('✅ BreezSdkSparkLib.init() called - Bridge initialized');
  
  await SecureStorage.init();
  await BreezSparkService.initPersistence();
  
  // Auto-recover wallet if exists
  final savedMnemonic = await BreezSparkService.getMnemonic();
  if (BreezSparkService.hasCompletedOnboarding && savedMnemonic != null) {
    try {
      await BreezSparkService.initializeSparkSDK(mnemonic: savedMnemonic);
      debugPrint('🔓 Auto-recovered wallet from storage');
    } catch (e) {
      debugPrint('⚠️ Failed to auto-recover wallet: $e');
    }
  }
  
  await ContactService.init();
  await NotificationService.init();
  await ProfileService.init();
  runApp(const ProviderScope(child: SabiWalletApp()));
}

class SabiWalletApp extends StatelessWidget {
  const SabiWalletApp({super.key});

  @override
  Widget build(BuildContext buildContext) {
    // Get mnemonic synchronously from static getter (deprecated but works for initial check)
    final hasMnemonic = BreezSparkService.mnemonic != null;
    
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // THIS IS THE NUCLEAR FIX
      home: BreezSparkService.hasCompletedOnboarding && hasMnemonic
          ? const HomeScreen()
          : const OnboardingCarouselScreen(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/onboarding': (context) => const OnboardingCarouselScreen(),
      },
      theme: ThemeData(
        fontFamily: 'Inter',
        scaffoldBackgroundColor: const Color(0xFF0C0C1A),
      ),
    );
  }
}
