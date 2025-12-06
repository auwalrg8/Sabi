// test/breez_sdk_diagnostic_test.dart
// Diagnostic test to verify Breez Spark SDK initialization and payment capability
import 'package:flutter_test/flutter_test.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';

void main() {
  group('Breez Spark SDK Diagnostics', () {
    setUpAll(() async {
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
      final status = await BreezSparkService.getInitializationStatus();

      expect(status['isInitialized'], true, reason: 'SDK should be initialized');
      expect(
        status['sdkExists'],
        true,
        reason: 'SDK singleton should exist',
      );

      // Print diagnostic info
      print('');
      print('========== SPARK SDK DIAGNOSTIC REPORT ==========');
      print('Status: ${status['isInitialized'] ? '✅ READY' : '❌ FAILED'}');

      if (status.containsKey('nodeInfo')) {
        final nodeInfo = status['nodeInfo'] as Map;
        print('Node ID: ${nodeInfo['nodeId']}');
        print(
          'Balance: ${nodeInfo['balanceSats']} sats (${nodeInfo['channelsBalanceMsat']} msat)',
        );
        print('Can Send: ${status['canSend'] ? '✅ YES' : '❌ NO'}');
        print('Can Receive: ${status['canReceive'] ? '✅ YES' : '❌ NO'}');
      }

      if (status.containsKey('error')) {
        print('ERROR: ${status['error']}');
      }
      print('==============================================');
      print('');
    });

    test('Can create invoice for receiving', () async {
      final response = await BreezSparkService.createInvoice(
        1000, // 1000 sats
        'Test invoice',
      );

      expect(response.paymentRequest, isNotEmpty,
          reason: 'Should generate invoice');
      print('Generated invoice (first 80 chars): ${response.paymentRequest.substring(0, 80)}...');
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

        final status = await BreezSparkService.getInitializationStatus();
        expect(status['isInitialized'], true,
            reason: 'SDK should be initialized on restore');
        print('✅ Wallet restored successfully');
      } else {
        print('ℹ️  No mnemonic found - skipping restore test');
      }
    });
  });
}
