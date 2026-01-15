import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/core/services/secure_storage_service.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';
import 'package:sabi_wallet/services/firebase/webhook_bridge_services.dart';
import 'package:sabi_wallet/services/firebase/fcm_token_registration_service.dart';

/// Provider that initializes the Spark SDK on app startup if wallet exists
/// This ensures the SDK is connected before any payment operations
final breezInitProvider = FutureProvider<bool>((ref) async {
  try {
    final storage = ref.read(secureStorageServiceProvider);

    // Check if wallet has a seed phrase stored
    final mnemonic = await storage.getWalletSeed();

    if (mnemonic != null && mnemonic.isNotEmpty) {
      // Initialize Spark SDK with the stored mnemonic
      await BreezSparkService.initializeSparkSDK(mnemonic: mnemonic);

      // Start webhook bridge for push notifications
      BreezWebhookBridgeService().startListening();
      debugPrint(
        '✅ BreezWebhookBridgeService started from breez_init_provider',
      );

      // Register FCM token for push notifications
      FCMTokenRegistrationService().registerToken();

      return true;
    }

    return false;
  } catch (e) {
    debugPrint('Failed to initialize Spark SDK: $e');
    return false;
  }
});
