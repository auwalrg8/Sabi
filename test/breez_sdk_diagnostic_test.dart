// test/breez_sdk_diagnostic_test.dart
// Diagnostic test to verify Breez Spark SDK initialization and payment capability
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';

const bool _skipBreezSdkDiagnostics = bool.fromEnvironment('SKIP_BREEZ_SDK_DIAGNOSTICS', defaultValue: true);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final tempDir = Directory.systemTemp.createTempSync('sabi_test');
  PathProviderPlatform.instance = _FakePathProvider(tempDir.path);

  group(
    'Breez Spark SDK Diagnostics',
    () {
    setUpAll(() async {
      // Initialize Hive with a temp path for testing
      Hive.init(tempDir.path);
      // Initialize persistence layer
      await BreezSparkService.initPersistence();
    });

    test('SDK initialization succeeds', () async {
      // Initialize SDK with fresh wallet
      await BreezSparkService.initializeSparkSDK();

      // Verify SDK is actually initialized
      expect(
        BreezSparkService.isInitialized,
        true,
        reason: 'SDK should be initialized',
      );
    });

    test('SDK operational status check', () async {
      final balance = await BreezSparkService.getBalance();

      expect(balance, isNotNull, reason: 'SDK should return balance');

      // Print diagnostic info
      print('');
      print('========== SPARK SDK DIAGNOSTIC REPORT ==========');
      print('Status: ✅ READY');
      print('Balance: $balance sats');
      print('==============================================');
      print('');
    });

    test('Can create invoice for receiving', () async {
      final response = await BreezSparkService.createInvoice(
        sats: 1000,
        memo: 'Test invoice',
      );

      expect(response, isNotEmpty,
          reason: 'Should generate invoice');
      print('Generated invoice (first 80 chars): ${response.substring(0, 80)}...');
    });

    test('SDK initialization with restore', () async {
      // Get existing mnemonic if available
      final mnemonic = await BreezSparkService.getMnemonic();

      if (mnemonic != null) {
        // Try restore
        await BreezSparkService.initializeSparkSDK(
          mnemonic: mnemonic,
          isRestore: true,
        );

        final balance = await BreezSparkService.getBalance();
        expect(balance, isNotNull,
            reason: 'SDK should be initialized on restore');
        print('✅ Wallet restored successfully');
      } else {
        print('ℹ️  No mnemonic found - skipping restore test');
      }
    });
  }, skip: _skipBreezSdkDiagnostics);
}

class _FakePathProvider extends PathProviderPlatform {
  final String path;

  _FakePathProvider(this.path);

  @override
  Future<String> getApplicationDocumentsPath() async => path;

  @override
  Future<String> getApplicationSupportPath() async => path;

  @override
  Future<String> getTemporaryPath() async => path;
}
