import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:breez_sdk_spark_flutter/breez_sdk_spark.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sabi_wallet/core/widgets/connectivity_banner.dart';
import 'package:sabi_wallet/features/auth/presentation/screens/biometric_auth_screen.dart';
import 'package:sabi_wallet/features/nostr/services/nostr_service.dart';
import 'package:sabi_wallet/services/nostr/nostr_service.dart' as nostr_v2;
import 'package:sabi_wallet/services/nostr/nostr_profile_service.dart';
import 'package:sabi_wallet/services/nostr/feed_aggregator.dart';
import 'package:sabi_wallet/services/firebase_notification_service.dart';
import 'package:sabi_wallet/services/firebase/fcm_token_registration_service.dart';
import 'package:sabi_wallet/services/firebase/webhook_bridge_services.dart';
import 'package:sabi_wallet/services/background_payment_sync_service.dart';
import 'package:sabi_wallet/firebase_options.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'l10n/localization.dart';
import 'l10n/language_provider.dart';
import 'services/secure_storage.dart';
import 'services/breez_spark_service.dart';
import 'services/payment_retry_service.dart';
import 'services/contact_service.dart';
import 'services/notification_service.dart';
import 'services/profile_service.dart';
import 'services/app_state_service.dart';
import 'features/wallet/presentation/screens/home_screen.dart';
import 'features/onboarding/presentation/screens/splash_screen.dart';
import 'features/onboarding/presentation/screens/entry_screen.dart';
// ...existing code...

/// Register FCM token with retry logic
/// This handles cases where the token or pubkey isn't available immediately
Future<void> _registerFCMWithRetry({int maxRetries = 3}) async {
  for (int attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      debugPrint('🔔 FCM registration attempt $attempt/$maxRetries');
      await FCMTokenRegistrationService().registerToken();

      // Check if registration succeeded
      final status = await FCMTokenRegistrationService().debugStatus();
      if (status['isRegistered'] == true) {
        debugPrint('✅ FCM token registered successfully on attempt $attempt');
        return;
      }

      // If not registered, wait and retry
      if (attempt < maxRetries) {
        debugPrint('⚠️ FCM registration incomplete, retrying in 3s...');
        await Future.delayed(const Duration(seconds: 3));
      }
    } catch (e) {
      debugPrint('⚠️ FCM registration attempt $attempt failed: $e');
      if (attempt < maxRetries) {
        await Future.delayed(const Duration(seconds: 3));
      }
    }
  }
  debugPrint('⚠️ FCM registration failed after $maxRetries attempts');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ═══════════════════════════════════════════════════════════════════════════
  // FAST STARTUP: Only essential, fast initializations before runApp()
  // Everything else is deferred to run AFTER the UI is displayed
  // ═══════════════════════════════════════════════════════════════════════════

  // 1. Hive - Required for AppStateService (fast: ~50-100ms)
  try {
    await Hive.initFlutter();
    debugPrint('✅ Hive.initFlutter() initialized globally');
  } catch (e) {
    debugPrint('⚠️ Hive.initFlutter() error: $e');
  }

  // 2. SecureStorage - Required to check wallet existence (fast: ~50ms)
  try {
    await SecureStorage.init();
    debugPrint('✅ SecureStorage initialized');
  } catch (e) {
    debugPrint('⚠️ SecureStorage error: $e');
  }

  // 3. AppStateService - Required to determine initial route (fast: ~20ms)
  try {
    await AppStateService.init();
    debugPrint('✅ AppStateService initialized');
  } catch (e) {
    debugPrint('⚠️ AppStateService error: $e');
  }

  // 4. Quick cache for instant profile display (fast: ~20ms)
  try {
    await NostrProfileService.loadQuickCache();
    debugPrint('✅ NostrProfileService quick cache loaded');
  } catch (e) {
    debugPrint('⚠️ NostrProfileService quick cache error: $e');
  }

    runApp(
    const ProviderScope(
      child: ScreenUtilInit(
        designSize: Size(412, 917),
        minTextAdapt: true,
        splitScreenMode: true,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: ConnectivityBanner(child: SabiWalletApp()),
        ),
      ),
    ),
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // DEFERRED INITIALIZATION - Runs in background while UI is already visible
  // ═══════════════════════════════════════════════════════════════════════════
  _initializeServicesInBackground();
}

/// Background initialization of all heavy services
/// This runs AFTER the UI is displayed, so user sees instant startup
Future<void> _initializeServicesInBackground() async {
  debugPrint('🚀 Starting background initialization...');

  // Firebase - Initialize in parallel (non-blocking)
  _initializeFirebaseServices();

  // Rust bridge - Critical for wallet but can init while UI shows loading
  _initializeWalletServices();

  // Nostr services - Can be fully deferred
  _initializeNostrServices();

  // Other services - Low priority, fully deferred
  _initializeOtherServices();
}

/// Firebase initialization (non-blocking, runs in parallel)
Future<void> _initializeFirebaseServices() async {
  try {
    // Firebase core - don't await, let it run in background
    Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).then((_) {
      debugPrint('✅ Firebase initialized');

      // Chain FCM init after Firebase is ready
      FirebaseNotificationService().init().then((_) {
        debugPrint('✅ FirebaseNotificationService initialized');
      }).catchError((e) {
        debugPrint('⚠️ FirebaseNotificationService error: $e');
      });
    }).catchError((e) {
      debugPrint('⚠️ Firebase initialization error: $e');
    });
  } catch (e) {
    debugPrint('⚠️ Firebase setup error: $e');
  }
}

/// Wallet SDK initialization (heavy but runs after UI is shown)
Future<void> _initializeWalletServices() async {
  // Initialize Rust bridge
  bool rustBridgeInitialized = false;
  try {
    await BreezSdkSparkLib.init();
    rustBridgeInitialized = true;
    debugPrint('✅ BreezSdkSparkLib.init() called - Bridge initialized');
  } catch (e, stackTrace) {
    debugPrint('❌ CRITICAL: BreezSdkSparkLib.init() FAILED: $e');
    debugPrint('Stack trace: $stackTrace');
  }
  BreezSparkService.rustBridgeInitialized = rustBridgeInitialized;

  // Initialize persistence
  try {
    await BreezSparkService.initPersistence();
    debugPrint('✅ BreezSparkService persistence initialized');
  } catch (e) {
    debugPrint('⚠️ BreezSparkService.initPersistence error: $e');
  }

  // Auto-recover wallet if exists
  try {
    final savedMnemonic = await BreezSparkService.getMnemonic();
    if (savedMnemonic != null && savedMnemonic.isNotEmpty) {
      try {
        await BreezSparkService.initializeSparkSDK(mnemonic: savedMnemonic);
        debugPrint('🔓 Auto-recovered wallet from storage');

        // Register FCM token after wallet is recovered (with retry)
        _registerFCMWithRetry();

        // Start listening for payments (non-blocking)
        try {
          BreezWebhookBridgeService().startListening();
          debugPrint('✅ BreezWebhookBridgeService started');
        } catch (e) {
          debugPrint('⚠️ BreezWebhookBridgeService error: $e');
        }

        // Background payment sync (non-blocking)
        _initializeBackgroundPaymentSync();
      } catch (e) {
        debugPrint('⚠️ Failed to auto-recover wallet: $e');
      }
    }
  } catch (e) {
    debugPrint('⚠️ Wallet recovery error: $e');
  }

  // Start payment retry service
  try {
    await PaymentRetryService.start();
    debugPrint('✅ PaymentRetryService started');
  } catch (e) {
    debugPrint('⚠️ PaymentRetryService start error: $e');
  }
}

/// Background payment sync initialization
Future<void> _initializeBackgroundPaymentSync() async {
  try {
    await BackgroundPaymentSyncService().initialize();
    await BackgroundPaymentSyncService().startPeriodicSync();

    final pubkey = NostrProfileService().currentPubkey;
    if (pubkey != null) {
      await BackgroundPaymentSyncService().saveNostrPubkey(pubkey);
    }
    debugPrint('✅ BackgroundPaymentSyncService started');
  } catch (e) {
    debugPrint('⚠️ BackgroundPaymentSyncService error: $e');
  }
}

/// Nostr services initialization (fully deferred, non-critical for startup)
Future<void> _initializeNostrServices() async {
  // Legacy NostrService
  try {
    await NostrService.init();
    debugPrint('✅ NostrService (legacy) initialized');
  } catch (e) {
    debugPrint('⚠️ NostrService error: $e');
  }

  // NostrProfileService
  try {
    await NostrProfileService().init();
    debugPrint('✅ NostrProfileService initialized');
  } catch (e) {
    debugPrint('⚠️ NostrProfileService error: $e');
  }

  // Event cache service
  try {
    await nostr_v2.EventCacheService().initialize();
    debugPrint('✅ Nostr EventCacheService initialized');
  } catch (e) {
    debugPrint('⚠️ Nostr EventCacheService error: $e');
  }

  // Relay pool manager (already non-blocking pattern)
  try {
    nostr_v2.RelayPoolManager()
        .init()
        .then((_) {
          debugPrint('✅ Nostr RelayPoolManager connected');

          FeedAggregator()
              .init(NostrProfileService().currentPubkey)
              .then((_) {
                FeedAggregator()
                    .fetchFeed(type: FeedType.global, limit: 30)
                    .then((posts) {
                      debugPrint(
                        '✅ Pre-fetched ${posts.length} global feed posts',
                      );
                    })
                    .catchError((e) {
                      debugPrint('⚠️ Pre-fetch global feed error: $e');
                    });
              })
              .catchError((e) {
                debugPrint('⚠️ FeedAggregator init error: $e');
              });
        })
        .catchError((e) {
          debugPrint('⚠️ Nostr RelayPoolManager error: $e');
        });
  } catch (e) {
    debugPrint('⚠️ Nostr RelayPoolManager init error: $e');
  }
}

/// Other services initialization (lowest priority)
Future<void> _initializeOtherServices() async {
  // ContactService
  try {
    await ContactService.init();
    debugPrint('✅ ContactService initialized');
  } catch (e) {
    debugPrint('⚠️ ContactService error: $e');
  }

  // NotificationService
  try {
    await NotificationService.init();
    debugPrint('✅ NotificationService initialized');
  } catch (e) {
    debugPrint('⚠️ NotificationService error: $e');
  }

  // ProfileService
  try {
    await ProfileService.init();
    debugPrint('✅ ProfileService initialized');
  } catch (e) {
    debugPrint('⚠️ ProfileService error: $e');
  }

  // Mark app as opened
  try {
    await AppStateService.markAppOpened();
    debugPrint('✅ App marked as opened');
  } catch (e) {
    debugPrint('⚠️ markAppOpened error: $e');
  }

  debugPrint('🎉 Background initialization complete!');
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
              ? BiometricAuthScreen(
                child: const HomeScreen(),
              ) // Wallet exists → authenticate with pin/biometrics → go to home
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
