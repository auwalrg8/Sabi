import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sabi_wallet/core/services/secure_storage_service.dart';
import 'package:sabi_wallet/features/wallet/presentation/providers/wallet_info_provider.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';
import 'package:sabi_wallet/services/firebase/webhook_bridge_services.dart';
import 'package:sabi_wallet/services/firebase/fcm_token_registration_service.dart';

/// Helper to create wallet with a specific backup type and store locally
class WalletCreationHelper {
  /// Create wallet with 2025 architecture (Spark SDK on device)
  /// Saves wallet data immediately to device
  static Future<bool> createWalletWithBackupType({
    required dynamic ref,
    required String backupType,
    String phoneNumber = '+2348012345678',
  }) async {
    final storage = ref.read(secureStorageServiceProvider);

    try {
      // Initialize Spark SDK (2025 Nodeless/Spark)
      await BreezSparkService.initializeSparkSDK();

      final mnemonic = await BreezSparkService.getMnemonic() ?? '';
      await BreezSparkService.getBalance();

      // CRITICAL: Always save mnemonic to secure storage (for SDK re-init on app restart)
      await storage.saveMnemonic(mnemonic);
      debugPrint('✅ Mnemonic saved to secure storage');

      // CRITICAL: Mark onboarding complete so app never loops back
      await BreezSparkService.setOnboardingComplete();
      debugPrint('✅ Onboarding marked complete');

      // Start webhook bridge for push notifications
      BreezWebhookBridgeService().startListening();
      debugPrint('✅ BreezWebhookBridgeService started after wallet creation');

      // Register FCM token for push notifications
      FCMTokenRegistrationService().registerToken();

      // Optional: Notify backend for recovery metadata (can fail silently)
      try {
        await http
            .post(
              Uri.parse('http://localhost:3000/api/v1/wallets/create'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'phone': phoneNumber,
                'backup_type': backupType,
                'node_id':
                    'local-spark-node', // TODO: Get correct node ID from GetInfoResponse
              }),
            )
            .timeout(const Duration(seconds: 3));
      } catch (e) {
        // OK if this fails; app works offline
      }

      // Save backup status locally
      await storage.saveBackupStatus(
        backupType == 'none' ? 'skipped' : backupType,
      );

      // Refresh global wallet info provider (best-effort)
      try {
        await ref.read(walletInfoProvider.notifier).refresh();
      } catch (_) {}

      return true;
    } catch (e) {
      return false;
    }
  }
}
