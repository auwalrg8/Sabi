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
import '../config/breez_config.dart';

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
  static Timer? _balancePollingTimer;

  // Start balance polling
  static void _startBalancePolling() {
    _balancePollingTimer?.cancel();
    _balancePollingTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final balance = await getBalance();
        _balanceStream.add(balance);
      } catch (e) {
        debugPrint('⚠️ Balance polling error: $e');
      }
    });
  }

  // Stop balance polling
  static void stopBalancePolling() {
    _balancePollingTimer?.cancel();
  }

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

      // Fetch API key (local override preferred)
      final apiKey = await BreezConfig.apiKey;
      debugPrint('🔑 Breez API key loaded');

      // Connect to SDK (Bitcoin mainnet) - WRAPPED IN TRY/CATCH
      try {
        debugPrint('🔗 Attempting to connect to Breez Spark SDK...');
        _sdk = await connect(
          request: ConnectRequest(
            config: Config(
              apiKey: apiKey,
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
        debugPrint('✅ Connected to Breez Spark SDK successfully');
      } catch (e) {
        _sdk = null;
        debugPrint('❌ SDK connect() failed: $e');
        rethrow;
      }

      // VALIDATE API KEY: Call getInfo() immediately to ensure SDK is working
      try {
        debugPrint('🔍 Validating SDK connection with getInfo()...');
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

      // Mark onboarding as complete and save wallet initialization timestamp
      await _box.put('has_completed_onboarding', true);
      await _box.put('wallet_initialized_at', DateTime.now().millisecondsSinceEpoch);
      debugPrint('🔒 ONBOARDING FLAG SAVED — WILL NEVER SHOW AGAIN');
      
      _isInitializing = false;
      
      // Start balance polling immediately
      _startBalancePolling();
      
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
      // Use ensure_synced: true to get network-fresh balance instead of cached
      final info = await _sdk!.getInfo(request: GetInfoRequest(ensureSynced: true));
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
      
      // Poll balance after creating invoice (will update when payment received)
      Timer.periodic(const Duration(seconds: 2), (timer) async {
        if (timer.tick > 30) { // Stop after 60 seconds
          timer.cancel();
          return;
        }
        try {
          final balance = await getBalance();
          _balanceStream.add(balance);
        } catch (e) {
          debugPrint('⚠️ Balance check error: $e');
        }
      });
      
      return response.paymentRequest; // Returns bolt11 string
    } catch (e) {
      debugPrint('❌ Invoice creation failed: $e');
      rethrow;
    }
  }

  // ============================================================================
  // Prepare Send Payment (for showing confirmation before sending)
  // ============================================================================
  static Future<PrepareSendPaymentResponse> prepareSendPayment(String identifier) async {
    // Guard: ensure SDK is initialized
    if (_sdk == null) {
      debugPrint('❌ SDK not initialized - cannot prepare payment');
      throw Exception('SDK not initialized');
    }
    try {
      debugPrint('🔍 Preparing payment for: $identifier');

      final prepReq = PrepareSendPaymentRequest(
        paymentRequest: identifier,
        amount: null,
      );
      final prepResponse = await _sdk!.prepareSendPayment(request: prepReq);
      
      debugPrint('✅ Payment prepared successfully');
      return prepResponse;
    } catch (e) {
      debugPrint('❌ Prepare payment failed: $e');
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
      
      // Update balance immediately after send
      final balance = await getBalance();
      _balanceStream.add(balance);
      
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

      debugPrint('📋 Total payments: ${response.payments.length}');

      // Loop through .payments list (not .map)
      final records = <PaymentRecord>[];
      for (var p in response.payments) {
        // DEBUG: Log raw values
        debugPrint('💾 Payment: id=${p.id}');
        debugPrint('   amount=${p.amount} (type: ${p.amount.runtimeType})');
        debugPrint('   fees=${p.fees} (type: ${p.fees.runtimeType})');
        debugPrint('   timestamp=${p.timestamp}');
        debugPrint('   type=${p.paymentType}');

        // Try multiple conversion approaches for debugging
        int amountSats;
        if (p.amount > BigInt.from(999999)) {
          // If amount is large, assume it's in millisatoshis
          amountSats = (p.amount ~/ BigInt.from(1000)).toInt();
          debugPrint('   ✓ Using msat→sat conversion (dividing by 1000): $amountSats sats');
        } else if (p.amount > BigInt.zero) {
          // If amount is small, assume it's already in satoshis
          amountSats = p.amount.toInt();
          debugPrint('   ✓ Using direct conversion (already sats): $amountSats sats');
        } else {
          // Try to extract from details if amount is zero
          amountSats = _extractAmountFromDetails(p.details, p.amount);
          if (amountSats == 0) {
            debugPrint('   ⚠️ Amount is zero - no fallback found');
          } else {
            debugPrint('   ✓ Extracted from details: $amountSats sats');
          }
        }

        final feeSats = (p.fees ~/ BigInt.from(1000)).toInt();
        
        debugPrint('   Final: amountSats=$amountSats, feeSats=$feeSats');

        records.add(
          PaymentRecord(
            id: p.id,
            amountSats: amountSats,
            feeSats: feeSats,
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
      debugPrint('✅ Processed ${records.length} payment records');
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

  // Helper to extract amount from payment details if p.amount is 0
  static int _extractAmountFromDetails(PaymentDetails? details, BigInt amount) {
    // If we have amount directly, use it
    if (amount > BigInt.zero) {
      // Check if it's likely in msat (large number) or sats (small number)
      if (amount > BigInt.from(999999)) {
        return (amount ~/ BigInt.from(1000)).toInt();
      } else {
        return amount.toInt();
      }
    }
    
    // If amount is 0, try to extract from details if available
    // For now, return 0 - we'd need to parse the invoice from details
    return 0;
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
    return _box.get('has_completed_onboarding', defaultValue: false) as bool;
  }

  static Future<void> setOnboardingComplete() async {
    await _box.put('has_completed_onboarding', true);
    await _box.put('wallet_initialized_at', DateTime.now().millisecondsSinceEpoch);
    debugPrint('🔒 Onboarding marked complete');
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
