import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:breez_sdk_spark_flutter/breez_sdk_spark.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'l10n/localization.dart';
import 'l10n/language_provider.dart';
import 'services/secure_storage.dart';
import 'services/breez_spark_service.dart';
import 'services/contact_service.dart';
import 'services/notification_service.dart';
import 'services/profile_service.dart';
import 'services/app_state_service.dart';
import 'features/wallet/presentation/screens/home_screen.dart';
import 'features/onboarding/presentation/screens/splash_screen.dart';
import 'features/onboarding/presentation/screens/entry_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // CRITICAL: Initialize flutter_rust_bridge FIRST
  await BreezSdkSparkLib.init();
  debugPrint('✅ BreezSdkSparkLib.init() called - Bridge initialized');

  // Initialize services
  await SecureStorage.init();
  await AppStateService.init(); // Initialize app state first
  await BreezSparkService.initPersistence();

  // Auto-recover wallet if exists
  final savedMnemonic = await BreezSparkService.getMnemonic();
  if (savedMnemonic != null && savedMnemonic.isNotEmpty) {
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

  // Mark app as opened
  await AppStateService.markAppOpened();

  runApp(
    const ProviderScope(
      child: ScreenUtilInit(
        designSize: Size(412, 917),
        minTextAdapt: true,
        splitScreenMode: true,
        child: SabiWalletApp(),
      ),
    ),
  );
}

class SabiWalletApp extends ConsumerWidget {
  const SabiWalletApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check if user has created/restored a wallet using app state service
    final hasWallet = AppStateService.hasWallet;

    // Watch the current locale
    final locale = ref.watch(languageProvider);

    debugPrint('🔍 App State Check - hasWallet: $hasWallet');
    debugPrint('🌍 Current locale: ${locale.languageCode}');

    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // Localization setup
      localizationsDelegates: Localization.delegates,
      supportedLocales: Localization.supportedLocales,
      locale: locale,

      home:
          hasWallet
              ? const HomeScreen() // Wallet exists → go to home
              : const SplashScreen(), // No wallet → show onboarding
      routes: {
        '/home': (context) => const HomeScreen(),
        '/splash': (context) => const EntryScreen(),
        '/entry': (context) => const EntryScreen(),
      },
      theme: ThemeData(
        fontFamily: 'Inter',
        scaffoldBackgroundColor: const Color(0xFF0C0C1A),
      ),
    );
  }
}
