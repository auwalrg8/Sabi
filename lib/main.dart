import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  await SecureStorage.init();
  await BreezSparkService.initPersistence();
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

    // Check if user has completed onboarding with Spark SDK
    if (BreezSparkService.hasCompletedOnboarding) {
      // Restore SDK from stored mnemonic before showing home screen
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

      if (!mounted) return;

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
