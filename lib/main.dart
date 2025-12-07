import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:breez_sdk_spark_flutter/breez_sdk_spark.dart';
import 'services/secure_storage.dart';
import 'services/breez_spark_service.dart';
import 'services/contact_service.dart';
import 'services/notification_service.dart';
import 'services/profile_service.dart';
import 'core/services/secure_storage_service.dart';
import 'features/wallet/presentation/screens/home_screen.dart';
import 'features/onboarding/presentation/screens/onboarding_carousel_screen.dart';
import 'features/auth/presentation/screens/pin_login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // CRITICAL: Initialize flutter_rust_bridge FIRST, before any SDK calls
  await BreezSdkSparkLib.init();
  debugPrint('✅ BreezSdkSparkLib.init() called - Bridge initialized');
  
  await SecureStorage.init();
  await BreezSparkService.initPersistence();
  
  // BULLETPROOF: Auto-recover wallet and skip onboarding forever
  final hasOnboarded = BreezSparkService.hasCompletedOnboarding;
  final savedMnemonic = await BreezSparkService.getMnemonic();
  
  if (hasOnboarded && savedMnemonic != null) {
    // Auto-login: skip onboarding forever
    try {
      await BreezSparkService.initializeSparkSDK(mnemonic: savedMnemonic);
      debugPrint('🔓 Auto-recovered wallet from storage - SKIPPING ONBOARDING');
    } catch (e) {
      debugPrint('⚠️ Failed to auto-recover wallet: $e');
    }
  }
  // If not onboarded, SDK will be initialized during onboarding flow
  
  await ContactService.init();
  await NotificationService.init();
  await ProfileService.init();
  runApp(const ProviderScope(child: SabiWalletApp()));
}

class SabiWalletApp extends StatelessWidget {
  const SabiWalletApp({super.key});

  @override
  Widget build(BuildContext buildContext) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
      theme: ThemeData(
        fontFamily: 'Inter',
        scaffoldBackgroundColor: const Color(0xFF0C0C1A),
      ),
    );
  }
}

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

    // Check if user has completed onboarding AND has mnemonic (wallet exists)
    final hasOnboarded = BreezSparkService.hasCompletedOnboarding;
    final mnemonic = await BreezSparkService.getMnemonic();
    
    if (hasOnboarded && mnemonic != null) {
      // Wallet exists - reinitialize SDK on app restart
      try {
        if (!BreezSparkService.isInitialized) {
          await BreezSparkService.initializeSparkSDK(mnemonic: mnemonic);
          debugPrint('✅ SDK reinitialized on app restart');
        }
      } catch (e) {
        debugPrint('⚠️ Failed to reinitialize SDK: $e');
      }
      
      // Check if PIN is set up
      final storage = ref.read(secureStorageServiceProvider);
      final pin = await storage.getPinCode();

      if (!mounted) return;

      if (pin != null) {
        // PIN exists, show PIN login screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PinLoginScreen()),
        );
      } else {
        // No PIN, go directly to home (user can create PIN in settings)
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } else {
      // Not onboarded, show onboarding
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingCarouselScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C1A),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.currency_bitcoin, color: Color(0xFFF7931A), size: 200),
            SizedBox(height: 32),
            Text(
              'Sabi Wallet',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'Bitcoin for Naija',
              style: TextStyle(fontSize: 16, color: Color(0xFFA1A1B2)),
            ),
          ],
        ),
      ),
    );
  }
}
