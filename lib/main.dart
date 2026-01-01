import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:breez_sdk_spark_flutter/breez_sdk_spark.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sabi_wallet/core/widgets/connectivity_banner.dart';
import 'package:sabi_wallet/features/auth/presentation/screens/biometric_auth_screen.dart';
import 'package:sabi_wallet/features/nostr/nostr_service.dart';
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

/// Initialize non-critical services in background (after UI is showing)
Future<void> _initBackgroundServices() async {
  debugPrint('🔄 Starting background service initialization...');

  // Run independent services in parallel
  await Future.wait([
    // Nostr services (non-blocking)
    Future(() async {
      try {
        await NostrService.init();
        debugPrint('✅ NostrService (legacy) initialized');
      } catch (e) {
        debugPrint('⚠️ NostrService error: $e');
      }
    }),

    // Nostr Profile Service
    Future(() async {
      try {
        await NostrProfileService().init();
        debugPrint('✅ NostrProfileService initialized');
      } catch (e) {
        debugPrint('⚠️ NostrProfileService error: $e');
      }
    }),

    // Event cache
    Future(() async {
      try {
        await nostr_v2.EventCacheService().initialize();
        debugPrint('✅ Nostr EventCacheService initialized');
      } catch (e) {
        debugPrint('⚠️ Nostr EventCacheService error: $e');
      }
    }),

    // Contact service
    Future(() async {
      try {
        await ContactService.init();
        debugPrint('✅ ContactService initialized');
      } catch (e) {
        debugPrint('⚠️ ContactService error: $e');
      }
    }),

    // Profile service
    Future(() async {
      try {
        await ProfileService.init();
        debugPrint('✅ ProfileService initialized');
      } catch (e) {
        debugPrint('⚠️ ProfileService error: $e');
      }
    }),

    // Notification service
    Future(() async {
      try {
        await NotificationService.init();
        debugPrint('✅ NotificationService initialized');
      } catch (e) {
        debugPrint('⚠️ NotificationService error: $e');
      }
    }),
  ], eagerError: false);

  // Connect to Nostr relays (fire and forget)
  nostr_v2.RelayPoolManager()
      .init()
      .then((_) {
        debugPrint('✅ Nostr RelayPoolManager connected');

        // Pre-fetch global feed after relay connection
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

  debugPrint('✅ Background services initialization complete');
}

/// Initialize wallet if it exists (called after splash shows)
Future<bool> initializeWalletIfExists() async {
  try {
    final savedMnemonic = await BreezSparkService.getMnemonic();
    if (savedMnemonic != null && savedMnemonic.isNotEmpty) {
      debugPrint('🔓 Auto-recovering wallet from storage...');
      await BreezSparkService.initializeSparkSDK(mnemonic: savedMnemonic);
      debugPrint('✅ Wallet auto-recovered');

      // Start webhook bridge for push notifications (fire and forget)
      Future(() async {
        try {
          BreezWebhookBridgeService().startListening();
          debugPrint('✅ BreezWebhookBridgeService started');
        } catch (e) {
          debugPrint('⚠️ BreezWebhookBridgeService error: $e');
        }

        // Register FCM token
        _registerFCMWithRetry();

        // Initialize background payment sync
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
      });

      return true;
    }
  } catch (e) {
    debugPrint('⚠️ Wallet recovery error: $e');
  }
  return false;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ===== CRITICAL PATH - Minimum blocking initialization =====
  // Only what's absolutely required before showing UI

  try {
    // Hive - needed for storage
    await Hive.initFlutter();
    debugPrint('✅ Hive initialized');
  } catch (e) {
    debugPrint('⚠️ Hive error: $e');
  }

  // Run these critical services in parallel
  await Future.wait([
    // Firebase - needed for notifications
    Future(() async {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        await FirebaseNotificationService().init();
        debugPrint('✅ Firebase initialized');
      } catch (e) {
        debugPrint('⚠️ Firebase error: $e');
      }
    }),

    // Rust bridge - required before any SDK calls
    Future(() async {
      try {
        await BreezSdkSparkLib.init();
        debugPrint('✅ BreezSdkSparkLib bridge initialized');
      } catch (e) {
        debugPrint('⚠️ BreezSdkSparkLib error: $e');
      }
    }),

    // Secure storage - needed to check wallet state
    Future(() async {
      try {
        await SecureStorage.init();
        debugPrint('✅ SecureStorage initialized');
      } catch (e) {
        debugPrint('⚠️ SecureStorage error: $e');
      }
    }),

    // App state - needed for routing
    Future(() async {
      try {
        await AppStateService.init();
        await BreezSparkService.initPersistence();
        debugPrint('✅ AppStateService initialized');
      } catch (e) {
        debugPrint('⚠️ AppStateService error: $e');
      }
    }),
  ], eagerError: false);

  // Mark app as opened
  try {
    await AppStateService.markAppOpened();
  } catch (e) {
    debugPrint('⚠️ markAppOpened error: $e');
  }

  // ===== START UI IMMEDIATELY =====
  // Background services will initialize after UI is showing
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

  // ===== DEFERRED INITIALIZATION =====
  // Start background services after UI is showing
  _initBackgroundServices();
}

class SabiWalletApp extends ConsumerWidget {
  const SabiWalletApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the current locale
    final locale = ref.watch(languageProvider);
    debugPrint('🌍 Current locale: ${locale.languageCode}');

    // Always show SplashScreen first - it handles wallet detection and navigation
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // Localization setup
      localizationsDelegates: Localization.delegates,
      supportedLocales: Localization.supportedLocales,
      locale: locale,

      // SplashScreen now handles:
      // - Checking if wallet exists
      // - Lazy-loading Lightning SDK
      // - Navigating to appropriate screen
      home: const SplashScreen(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/splash': (context) => const SplashScreen(),
        '/entry': (context) => const EntryScreen(),
      },
      theme: ThemeData(
        fontFamily: 'Inter',
        scaffoldBackgroundColor: const Color(0xFF0C0C1A),
      ),
    );
  }
}
