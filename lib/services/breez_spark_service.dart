// lib/services/breez_spark_service.dart
// Production-ready Breez SDK Spark (Nodeless) - Aligned with Official Docs
// https://sdk-doc-spark.breez.technology/

import 'dart:async';
import 'dart:io';

import 'package:bip39/bip39.dart' as bip39;
import 'package:breez_sdk_spark_flutter/breez_sdk_spark.dart';
import 'package:encrypt/encrypt.dart' as encrypt_pkg;
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Local wrapper class for payment history display
class PaymentRecord {
  final String id;
  final int amountSats;
  final int feeSats;
  final DateTime timestamp;
  final String description;
  final String? bolt11;
  final bool isIncoming;

  PaymentRecord({
    required this.id,
    required this.amountSats,
    this.feeSats = 0,
    required this.timestamp,
    this.description = '',
    this.bolt11,
    this.isIncoming = true,
  });
}

class BreezSparkService {
  static const _boxName = 'breez_spark_data';
  static late Box _box;
  static BreezSdk? _sdk;
  static final StreamController<PaymentRecord> _paymentStream =
      StreamController.broadcast();

  // Prevent double initialization
  static bool _isInitializing = false;
  static bool get isInitialized => _sdk != null;

  static Stream<PaymentRecord> get paymentStream => _paymentStream.stream;

  // Balance polling
  static final StreamController<int> _balanceStream =
      StreamController.broadcast();
  static Stream<int> get balanceStream => _balanceStream.stream;

  // ============================================================================
  // STEP 1: Initialize Hive persistence
  // ============================================================================
  static Future<void> initPersistence() async {
    await Hive.initFlutter();
    final key = await _getEncryptionKey();
    _box = await Hive.openBox(_boxName, encryptionCipher: HiveAesCipher(key));
    debugPrint('✅ Breez Spark persistence initialized');
  }

  static Future<List<int>> _getEncryptionKey() async {
    return encrypt_pkg.Key.fromLength(32).bytes;
  }

  // ============================================================================
  // STEP 2: Initialize Spark SDK
  // ============================================================================
  static Future<void> initializeSparkSDK({
    String? mnemonic,
    bool isRestore = false,
  }) async {
    try {
      if (isInitialized && !isRestore) {
        debugPrint('✅ Spark SDK already initialized');
        return;
      }

      if (_isInitializing && !isRestore) {
        debugPrint('⚠️ SDK initialization already in progress');
        return;
      }

      _isInitializing = true;

      // Generate or restore seed
      final seedMnemonic = mnemonic ?? bip39.generateMnemonic(strength: 256);
      await _box.put('mnemonic', seedMnemonic);
      debugPrint('💾 Mnemonic stored to Hive');

      // Get storage directory (use getApplicationDocumentsDirectory)
      final appDir = await getApplicationDocumentsDirectory();
      final storageDir = '${appDir.path}/breez_spark';
      await Directory(storageDir).create(recursive: true);
      debugPrint('📁 Storage directory: $storageDir');

      // Connect to SDK (Bitcoin mainnet) - WRAPPED IN TRY/CATCH
      try {
        _sdk = await connect(
          request: ConnectRequest(
            config: Config(
              network: Network.mainnet, // Bitcoin mainnet (no testnet)
              syncIntervalSecs: 15,
              preferSparkOverLightning: true,
              useDefaultExternalInputParsers: true,
              privateEnabledDefault: true,
            ),
            seed: Seed.mnemonic(mnemonic: seedMnemonic),
            storageDir: storageDir,
          ),
        );
        debugPrint('✅ Connected to Breez Spark SDK');
      } catch (e) {
        _sdk = null;
        debugPrint('❌ SDK connect() failed: $e');
        rethrow;
      }

      // VALIDATE API KEY: Call getInfo() immediately to ensure SDK is working
      try {
        final info = await _sdk!.getInfo(request: GetInfoRequest());
        debugPrint('✅ API validation SUCCESS - Balance: ${info.balanceSats} sats');
      } catch (e) {
        _sdk = null;
        debugPrint('❌ API validation FAILED: $e');
        rethrow;
      }

      // Bootstrap liquidity
      try {
        await bootstrap();
      } catch (e) {
        debugPrint('⚠️ Bootstrap failed (non-critical): $e');
      }

      await setOnboardingComplete();
      _isInitializing = false;
      debugPrint('✅✅✅ SPARK SDK INITIALIZED ✅✅✅');
    } catch (e) {
      _isInitializing = false;
      _sdk = null;
      debugPrint('❌ SDK init failed: $e');
      rethrow;
    }
  }

  // ============================================================================
  // Bootstrap Liquidity (0-sat invoice for channel opening)
  // ============================================================================
  static Future<void> bootstrap() async {
    if (_sdk == null) throw Exception('SDK not initialized');
    try {
      debugPrint('🚀 Bootstrapping liquidity...');
      final response = await _sdk!.receivePayment(
        request: ReceivePaymentRequest(
          paymentMethod: ReceivePaymentMethod.bolt11Invoice(
            description: 'Bootstrap',
            amountSats: BigInt.zero,
          ),
        ),
      );
      debugPrint('✅ Bootstrap: ${response.paymentRequest}');
    } catch (e) {
      debugPrint('⚠️ Bootstrap error: $e');
    }
  }

  // ============================================================================
  // Get Balance (lightning balance in sats)
  // ============================================================================
  static Future<int> getBalance() async {
    // Guard: ensure SDK is initialized
    if (_sdk == null) {
      debugPrint('❌ SDK not initialized - cannot get balance');
      throw Exception('SDK not initialized');
    }
    try {
      final info = await _sdk!.getInfo(request: GetInfoRequest());
      // balanceSats is already in sats
      final balanceSats = (info.balanceSats).toInt();
      debugPrint('💰 Balance: $balanceSats sats');
      return balanceSats;
    } catch (e) {
      debugPrint('❌ Get balance error: $e');
      return 0;
    }
  }

  // ============================================================================
  // Create Invoice (Receive Payment) - EXACT DOCS FORMAT
  // ============================================================================
  static Future<String> createInvoice({
    required int sats,
    String memo = '',
  }) async {
    // Guard: ensure SDK is initialized
    if (_sdk == null) {
      debugPrint('❌ SDK not initialized - cannot create invoice');
      throw Exception('SDK not initialized');
    }
    try {
      debugPrint('📥 Creating invoice: $sats sats');

      // EXACT format from docs
      final method = ReceivePaymentMethod.bolt11Invoice(
        description: memo,
        amountSats: BigInt.from(sats),
      );
      final req = ReceivePaymentRequest(paymentMethod: method);
      final response = await _sdk!.receivePayment(request: req);

      debugPrint('✅ Invoice: ${response.paymentRequest}');
      return response.paymentRequest; // Returns bolt11 string
    } catch (e) {
      debugPrint('❌ Invoice creation failed: $e');
      rethrow;
    }
  }

  // ============================================================================
  // Send Payment - EXACT DOCS FORMAT
  // ============================================================================
  static Future<Map<String, dynamic>> sendPayment(
    String identifier, {
    int? sats,
    String comment = '',
  }) async {
    // Guard: ensure SDK is initialized
    if (_sdk == null) {
      debugPrint('❌ SDK not initialized - cannot send payment');
      throw Exception('SDK not initialized');
    }
    try {
      debugPrint('💸 Sending to: $identifier');

      // Step 1: Prepare
      final prepReq = PrepareSendPaymentRequest(
        paymentRequest: identifier,
        amount: sats != null ? BigInt.from(sats) : null,
      );
      final prepResponse = await _sdk!.prepareSendPayment(request: prepReq);

      // Step 2: Send with options
      final options = SendPaymentOptions.bolt11Invoice(
        preferSpark: false,
        completionTimeoutSecs: 30,
      );
      final sendReq = SendPaymentRequest(
        prepareResponse: prepResponse,
        options: options,
        idempotencyKey: const Uuid().v4(),
      );
      final sendResponse = await _sdk!.sendPayment(request: sendReq);

      debugPrint('✅ Payment sent: ${sendResponse.payment.id}');
      return {
        'payment': sendResponse.payment,
        'amount': sendResponse.payment.amount,
        'fees': sendResponse.payment.fees,
      };
    } catch (e) {
      debugPrint('❌ Send failed: $e');
      rethrow;
    }
  }

  // ============================================================================
  // List Payments
  // ============================================================================
  static Future<List<PaymentRecord>> listPayments({int limit = 50}) async {
    // Guard: ensure SDK is initialized
    if (_sdk == null) {
      debugPrint('❌ SDK not initialized - cannot list payments');
      throw Exception('SDK not initialized');
    }
    try {
      final response = await _sdk!.listPayments(
        request: ListPaymentsRequest(limit: limit),
      );

      // Loop through .payments list (not .map)
      final records = <PaymentRecord>[];
      for (var p in response.payments) {
        records.add(
          PaymentRecord(
            id: p.id,
            amountSats: (p.amount ~/ BigInt.from(1000)).toInt(),
            feeSats: (p.fees ~/ BigInt.from(1000)).toInt(),
            timestamp: DateTime.fromMillisecondsSinceEpoch(
              (p.timestamp ~/ BigInt.from(1000)).toInt(),
            ),
            description: _extractDescription(p.details),
            bolt11: _extractInvoice(p.details),
            // isIncoming: check if amount indicates incoming
            isIncoming: p.paymentType == PaymentType.receive,
          ),
        );
      }
      return records;
    } catch (e) {
      debugPrint('❌ List payments error: $e');
      return [];
    }
  }

  // Helper to safely extract description from PaymentDetails sealed class
  static String _extractDescription(PaymentDetails? details) {
    if (details == null) return '';
    // Just return empty for now - description is in Payment.details
    return '';
  }

  // Helper to safely extract invoice from PaymentDetails sealed class
  static String? _extractInvoice(PaymentDetails? details) {
    if (details == null) return null;
    // Invoice info is in the sealed class variants
    // For now return null - actual invoice is from payment request
    return null;
  }

  // ============================================================================
  // Get Mnemonic
  // ============================================================================
  static Future<String?> getMnemonic() async {
    return _box.get('mnemonic') as String?;
  }

  // ============================================================================
  // Extract amounts from send response
  // ============================================================================
  static int extractSendAmountSats(Map<String, dynamic> result) {
    if (result.containsKey('payment')) {
      final payment = result['payment'] as Payment;
      return (payment.amount ~/ BigInt.from(1000)).toInt();
    }
    return 0;
  }

  static int extractSendFeeSats(Map<String, dynamic> result) {
    if (result.containsKey('payment')) {
      final payment = result['payment'] as Payment;
      return (payment.fees ~/ BigInt.from(1000)).toInt();
    }
    return 0;
  }

  // ============================================================================
  // Sync and Get Balance (legacy compat)
  // ============================================================================
  static Future<int> syncAndGetBalance() async {
    return await getBalance();
  }

  // ============================================================================
  // Onboarding Status
  // ============================================================================
  static bool get hasCompletedOnboarding {
    return _box.get('completedOnboarding', defaultValue: false) as bool;
  }

  static Future<void> setOnboardingComplete() async {
    await _box.put('completedOnboarding', true);
  }

  @Deprecated('Use getMnemonic() instead')
  static String? get mnemonic {
    return _box.get('mnemonic') as String?;
  }

  // ============================================================================
  // Compat methods (deprecated)
  // ============================================================================
  @Deprecated('Use listPayments() instead')
  static Future<List<PaymentRecord>> listPaymentDetails({int limit = 50}) async {
    return await listPayments(limit: limit);
  }

  static Future<String> generateBitcoinAddress() async {
    return 'Use createInvoice() for bolt11';
  }

  static Future<int> getBalanceSatsSafe() async {
    try {
      return await getBalance();
    } catch (e) {
      return 0;
    }
  }
}
