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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // CRITICAL: Initialize Hive ONCE at the very start, before all other services
  try {
    await Hive.initFlutter();
    debugPrint('✅ Hive.initFlutter() initialized globally');
  } catch (e) {
    debugPrint('⚠️ Hive.initFlutter() error: $e');
  }

  // Initialize Firebase for push notifications
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialized');
  } catch (e) {
    debugPrint('⚠️ Firebase initialization error: $e');
  }

  // Initialize Firebase Cloud Messaging service
  try {
    await FirebaseNotificationService().init();
    debugPrint('✅ FirebaseNotificationService initialized');
  } catch (e) {
    debugPrint('⚠️ FirebaseNotificationService error: $e');
  }

  try {
    // CRITICAL: Initialize flutter_rust_bridge FIRST
    await BreezSdkSparkLib.init();
    debugPrint('✅ BreezSdkSparkLib.init() called - Bridge initialized');
  } catch (e) {
    debugPrint('⚠️ BreezSdkSparkLib.init() error: $e');
  }

  try {
    // Initialize services
    await SecureStorage.init();
    debugPrint('✅ SecureStorage initialized');
  } catch (e) {
    debugPrint('⚠️ SecureStorage error: $e');
  }

  // Load quick cache for instant profile display on home screen
  try {
    await NostrProfileService.loadQuickCache();
    debugPrint('✅ NostrProfileService quick cache loaded');
  } catch (e) {
    debugPrint('⚠️ NostrProfileService quick cache error: $e');
  }

  try {
    await AppStateService.init();
    debugPrint('✅ AppStateService initialized');
  } catch (e) {
    debugPrint('⚠️ AppStateService error: $e');
  }

  try {
    await BreezSparkService.initPersistence();
    debugPrint('✅ BreezSparkService persistence initialized');
  } catch (e) {
    debugPrint('⚠️ BreezSparkService.initPersistence error: $e');
  }

  try {
    await NostrService.init();
    debugPrint('✅ NostrService (legacy) initialized');
  } catch (e) {
    debugPrint('⚠️ NostrService error: $e');
  }

  // Initialize NostrProfileService (required for P2P and profile features)
  try {
    await NostrProfileService().init();
    debugPrint('✅ NostrProfileService initialized');
  } catch (e) {
    debugPrint('⚠️ NostrProfileService error: $e');
  }

  // Initialize new high-performance Nostr services (v2)
  try {
    await nostr_v2.EventCacheService().initialize();
    debugPrint('✅ Nostr EventCacheService initialized');
  } catch (e) {
    debugPrint('⚠️ Nostr EventCacheService error: $e');
  }

  try {
    // Connect to relays in background (non-blocking)
    nostr_v2.RelayPoolManager()
        .init()
        .then((_) {
          debugPrint('✅ Nostr RelayPoolManager connected');

          // Pre-fetch global feed immediately after relay connection
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

  try {
    // Auto-recover wallet if exists
    final savedMnemonic = await BreezSparkService.getMnemonic();
    if (savedMnemonic != null && savedMnemonic.isNotEmpty) {
      try {
        await BreezSparkService.initializeSparkSDK(mnemonic: savedMnemonic);
        debugPrint('🔓 Auto-recovered wallet from storage');

        // Register FCM token after wallet is recovered (with retry)
        _registerFCMWithRetry();

        // Start listening for payments to send push notifications
        try {
          BreezWebhookBridgeService().startListening();
          debugPrint('✅ BreezWebhookBridgeService started');
        } catch (e) {
          debugPrint('⚠️ BreezWebhookBridgeService error: $e');
        }

        // Initialize background payment sync for offline notifications
        try {
          await BackgroundPaymentSyncService().initialize();
          await BackgroundPaymentSyncService().startPeriodicSync();

          // Save nostr pubkey for background sync
          final pubkey = NostrProfileService().currentPubkey;
          if (pubkey != null) {
            await BackgroundPaymentSyncService().saveNostrPubkey(pubkey);
          }
          debugPrint('✅ BackgroundPaymentSyncService started');
        } catch (e) {
          debugPrint('⚠️ BackgroundPaymentSyncService error: $e');
        }
      } catch (e) {
        debugPrint('⚠️ Failed to auto-recover wallet: $e');
      }
    }
  } catch (e) {
    debugPrint('⚠️ Wallet recovery error: $e');
  }

  try {
    await ContactService.init();
    debugPrint('✅ ContactService initialized');
  } catch (e) {
    debugPrint('⚠️ ContactService error: $e');
  }

  try {
    await NotificationService.init();
    debugPrint('✅ NotificationService initialized');
  } catch (e) {
    debugPrint('⚠️ NotificationService error: $e');
  }

  try {
    await ProfileService.init();
    debugPrint('✅ ProfileService initialized');
  } catch (e) {
    debugPrint('⚠️ ProfileService error: $e');
  }

  try {
    // Mark app as opened
    await AppStateService.markAppOpened();
    debugPrint('✅ App marked as opened');
  } catch (e) {
    debugPrint('⚠️ markAppOpened error: $e');
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
