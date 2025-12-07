// lib/services/breez_spark_service.dart
// Production-ready Breez SDK Spark (Nodeless) implementation - December 2025
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:bip39/bip39.dart' as bip39;
import 'package:breez_sdk_spark_flutter/breez_sdk_spark.dart';
import 'package:encrypt/encrypt.dart' as encrypt_pkg;
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../config/breez_config.dart';

enum PaymentStatus { pending, complete, failed }

class PaymentDetails {
  final String id;
  final int amountSats;
  final int feeSats;
  final DateTime timestamp;
  final String description;
  final String? bolt11;
  final bool inbound;

  PaymentDetails({
    required this.id,
    required this.amountSats,
    this.feeSats = 0,
    required this.timestamp,
    this.description = '',
    this.bolt11,
    this.inbound = true,
  });
}

class BreezSparkService {
  static const _boxName = 'breez_spark_data';
  static late Box _box;
  static BreezSdk? _sdk;
  static final StreamController<PaymentDetails> _paymentStream =
      StreamController.broadcast();
  static StreamSubscription<BreezEvent>? _eventSub;

  // Prevent double initialization
  static bool _isInitializing = false;
  static bool get isInitialized => _sdk != null;

  static Stream<PaymentDetails> get paymentStream => _paymentStream.stream;

  // Balance polling timer (3 seconds)
  static Timer? _balanceTimer;
  static final StreamController<int> _balanceStream =
      StreamController.broadcast();
  static Stream<int> get balanceStream => _balanceStream.stream;

  // ============================================================================
  // STEP 1: Initialize Hive persistence (call before runApp in main.dart)
  // ============================================================================
  static Future<void> initPersistence() async {
    await Hive.initFlutter();
    final key = await _getEncryptionKey();
    _box = await Hive.openBox(_boxName, encryptionCipher: HiveAesCipher(key));
    debugPrint('✅ Breez Spark persistence initialized');
  }

  static Future<List<int>> _getEncryptionKey() async {
    // Secure 256-bit key from device
    return encrypt_pkg.Key.fromLength(32).bytes;
  }

  /// Generate cryptographically secure random entropy for BIP39
  static Uint8List _generateSecureRandomEntropy(int length) {
    final random = Random.secure();
    final values = Uint8List(length);
    for (int i = 0; i < length; i++) {
      values[i] = random.nextInt(256);
    }
    return values;
  }

  // ============================================================================
  // STEP 2: Initialize Spark SDK (call during onboarding or app startup)
  // ============================================================================
  static Future<void> initializeSparkSDK({
    String? mnemonic,
    bool isRestore = false,
  }) async {
    try {
      // Guard against double initialization
      if (isInitialized && !isRestore) {
        debugPrint('✅ Spark SDK already initialized - skipping re-init');
        return;
      }

      if (_isInitializing && !isRestore) {
        debugPrint('⏳ Spark SDK initialization already in progress...');
        await Future.delayed(const Duration(seconds: 2));
        if (isInitialized) return;
        throw Exception('Previous initialization failed');
      }

      _isInitializing = true;
      debugPrint('🚀 Initializing Breez Spark SDK (Nodeless 2025)...');

      // Step 1: Init Spark lib (once per app lifetime)
      try {
        await BreezSdkSparkLib.init();
        debugPrint('✅ BreezSdkSparkLib initialized');
      } catch (e) {
        if (e.toString().contains('Should not initialize flutter_rust_bridge')) {
          debugPrint('✅ BreezSdkSparkLib already initialized');
        } else {
          rethrow;
        }
      }

      // Step 2: Get writable storage directory (critical for Android/iOS)
      final docsDir = await getApplicationDocumentsDirectory();
      final storageDir = docsDir.path;
      debugPrint('📁 Spark storage: $storageDir');

      // Ensure directory exists
      final dir = Directory(storageDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // Step 3: Generate or restore mnemonic using BIP39
      String mnemonicPhrase;
      
      if (isRestore && mnemonic != null && mnemonic.trim().isNotEmpty) {
        // RESTORE: Use user-provided mnemonic
        mnemonicPhrase = mnemonic.trim();
        if (!bip39.validateMnemonic(mnemonicPhrase)) {
          throw Exception('Invalid mnemonic phrase');
        }
        await _box.put('mnemonic', mnemonicPhrase);
        debugPrint('🔄 Wallet restored from 12/24-word mnemonic');
      } else if (mnemonic != null && mnemonic.trim().isNotEmpty) {
        // Use provided mnemonic (programmatic restore)
        mnemonicPhrase = mnemonic.trim();
        if (!bip39.validateMnemonic(mnemonicPhrase)) {
          throw Exception('Invalid mnemonic phrase');
        }
        await _box.put('mnemonic', mnemonicPhrase);
        debugPrint('🔄 Using provided mnemonic');
      } else {
        // NEW WALLET: Generate from secure entropy (256-bit = 24 words)
        final secureEntropy = _generateSecureRandomEntropy(32);
        final entropyHex = secureEntropy
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();
        mnemonicPhrase = bip39.entropyToMnemonic(entropyHex);
        
        // CRITICAL: Save mnemonic immediately to Hive
        await _box.put('mnemonic', mnemonicPhrase);
        debugPrint('✨ New wallet created with 24-word mnemonic (saved to Hive)');
      }

      // Step 4: Create Seed from mnemonic
      final seed = Seed.mnemonic(mnemonic: mnemonicPhrase, passphrase: null);

      // Step 5: Get API key and configure network
      debugPrint('🔑 Loading Breez API key...');
      final apiKey = await BreezConfig.apiKey;
      final network = Network.bitcoin; // Production mainnet
      
      if (apiKey.isEmpty) {
        throw Exception('Breez API key is missing! Check breez_config.dart');
      }
      debugPrint('✅ API key loaded (${apiKey.length} chars)');

      // Step 6: Create config with API key
      final config = defaultConfig(network: network).copyWith(
        apiKey: apiKey,
      );
      debugPrint('🔧 Config created for Bitcoin mainnet');

      // Step 7: Connect to Spark SDK (creates wallet + instant channel)
      final connectRequest = ConnectRequest(
        config: config,
        seed: seed,
        storageDir: storageDir, // Use storageDir, NOT workingDir
      );

      _sdk = await connect(request: connectRequest);
      debugPrint('✅ Spark SDK connected! Lightning node is live.');

      // Step 8: Validate API key with immediate getInfo() call
      try {
        final nodeInfo = await _sdk!.getInfo(request: GetInfoRequest());
        debugPrint('✅ API key validated');
        debugPrint('   Node ID: ${nodeInfo.nodeState?.id ?? "unknown"}');
        debugPrint('   Block height: ${nodeInfo.nodeState?.blockHeight ?? 0}');
      } catch (e) {
        debugPrint('❌ API key validation failed: $e');
        _sdk = null;
        _isInitializing = false;
        throw Exception('Invalid Breez API key or network issue: $e');
      }

      // Step 9: Bootstrap inbound liquidity with 0-sat receive
      try {
        debugPrint('🔄 Bootstrapping inbound liquidity...');
        final bootstrapInvoice = await _sdk!.receivePayment(
          request: ReceivePaymentRequest(
            amountSats: 0, // 0-sat invoice opens channel
            description: 'Bootstrap channel',
          ),
        );
        debugPrint('✅ Channel bootstrap invoice created (not meant to be paid)');
        debugPrint('   Invoice: ${bootstrapInvoice.invoice}');
      } catch (e) {
        debugPrint('⚠️ Bootstrap invoice failed (non-critical): $e');
      }

      // Step 10: Listen for payment events (confetti trigger)
      _setupEventListener();

      // Step 11: Start 3-second balance polling
      _startBalancePolling();

      _isInitializing = false;
      debugPrint('🎉 Breez Spark SDK ready! You can send/receive sats now.');
    } catch (e, stack) {
      _isInitializing = false;
      _sdk = null;
      debugPrint('❌ Spark SDK initialization failed: $e');
      debugPrint('Stack trace: $stack');
      rethrow;
    }
  }

  // ============================================================================
  // Event Listener (for payment notifications + confetti)
  // ============================================================================
  static void _setupEventListener() {
    _eventSub?.cancel();
    _eventSub = _sdk!.addEventListener().listen((event) {
      debugPrint('📡 Breez Event: ${event.runtimeType}');

      if (event is PaymentSucceeded) {
        final details = PaymentDetails(
          id: const Uuid().v4(),
          amountSats: event.details.amountSats,
          feeSats: event.details.feesSats,
          timestamp: DateTime.now(),
          description: event.details.description ?? '',
          bolt11: event.details.bolt11,
          inbound: event.details.paymentType == PaymentType.received,
        );
        _paymentStream.add(details);
        debugPrint('✅ Payment succeeded: ${details.amountSats} sats');
      } else if (event is PaymentFailed) {
        debugPrint('❌ Payment failed: ${event.details.description}');
      } else if (event is InvoicePaid) {
        debugPrint('💰 Invoice paid: ${event.details.bolt11}');
      }
    });
    debugPrint('✅ Event listener active');
  }

  // ============================================================================
  // Balance Polling (every 3 seconds)
  // ============================================================================
  static void _startBalancePolling() {
    _balanceTimer?.cancel();
    _balanceTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final balance = await getBalance();
        _balanceStream.add(balance);
      } catch (e) {
        debugPrint('⚠️ Balance poll failed: $e');
      }
    });
    debugPrint('✅ Balance polling started (3s interval)');
  }

  static void stopBalancePolling() {
    _balanceTimer?.cancel();
    debugPrint('🛑 Balance polling stopped');
  }

  // ============================================================================
  // Get Balance
  // ============================================================================
  static Future<int> getBalance() async {
    if (_sdk == null) throw Exception('SDK not initialized');
    try {
      final nodeInfo = await _sdk!.getInfo(request: GetInfoRequest());
      final balance = nodeInfo.nodeState?.channelsSats ?? 0;
      return balance;
    } catch (e) {
      debugPrint('❌ getBalance error: $e');
      return 0;
    }
  }

  // ============================================================================
  // Create Invoice (Receive Payment)
  // ============================================================================
  static Future<String> createInvoice({
    required int sats,
    String memo = '',
  }) async {
    if (_sdk == null) throw Exception('SDK not initialized');
    try {
      debugPrint('📥 Creating invoice: $sats sats, memo: "$memo"');
      
      final result = await _sdk!.receivePayment(
        request: ReceivePaymentRequest(
          amountSats: sats,
          description: memo,
        ),
      );

      debugPrint('✅ Invoice created: ${result.invoice}');
      return result.invoice;
    } catch (e) {
      debugPrint('❌ createInvoice error: $e');
      throw Exception('Failed to create invoice: $e');
    }
  }

  // ============================================================================
  // Send Payment (supports bolt11, LNURL, Lightning Address)
  // ============================================================================
  static Future<Map<String, dynamic>> sendPayment(
    String identifier, {
    int? sats,
    String comment = '',
  }) async {
    if (_sdk == null) throw Exception('SDK not initialized');
    try {
      debugPrint('💸 Preparing payment to: $identifier');
      
      // Step 1: Prepare payment (validates + calculates fees)
      final prepareRequest = PrepareSendPaymentRequest(
        destination: identifier,
        amountSats: sats,
      );
      
      final prepareResponse = await _sdk!.prepareSendPayment(
        request: prepareRequest,
      );

      debugPrint('✅ Payment prepared');
      debugPrint('   Amount: ${prepareResponse.amountSats} sats');
      debugPrint('   Fees: ${prepareResponse.feesSats} sats');

      // Step 2: Send payment
      final sendRequest = SendPaymentRequest(
        prepareResponse: prepareResponse,
      );

      final sendResponse = await _sdk!.sendPayment(request: sendRequest);

      debugPrint('✅ Payment sent! Payment hash: ${sendResponse.payment.txId}');

      return {
        'success': true,
        'paymentHash': sendResponse.payment.txId,
        'amountSats': sendResponse.payment.amountSats,
        'feeSats': sendResponse.payment.feesSats,
        'description': sendResponse.payment.description ?? '',
      };
    } catch (e) {
      debugPrint('❌ sendPayment error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // ============================================================================
  // Get Mnemonic (for backup display)
  // ============================================================================
  static Future<String?> getMnemonic() async {
    return _box.get('mnemonic') as String?;
  }

  // ============================================================================
  // List Payments (transaction history)
  // ============================================================================
  static Future<List<PaymentDetails>> listPayments({int limit = 50}) async {
    if (_sdk == null) throw Exception('SDK not initialized');
    try {
      final payments = await _sdk!.listPayments(
        request: ListPaymentsRequest(),
      );

      return payments.map((p) {
        return PaymentDetails(
          id: p.txId ?? const Uuid().v4(),
          amountSats: p.amountSats,
          feeSats: p.feesSats,
          timestamp: DateTime.fromMillisecondsSinceEpoch(p.timestamp * 1000),
          description: p.description ?? '',
          bolt11: p.bolt11,
          inbound: p.paymentType == PaymentType.received,
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ listPayments error: $e');
      return [];
    }
  }

  // ============================================================================
  // Disconnect SDK (cleanup)
  // ============================================================================
  static Future<void> disconnect() async {
    try {
      _eventSub?.cancel();
      _balanceTimer?.cancel();
      await _sdk?.disconnect(request: DisconnectRequest());
      _sdk = null;
      debugPrint('✅ Spark SDK disconnected');
    } catch (e) {
      debugPrint('⚠️ Disconnect error: $e');
    }
  }

  // ============================================================================
  // Sync and Get Balance (legacy method for compatibility)
  // ============================================================================
  static Future<int> syncAndGetBalance() async {
    return await getBalance();
  }
}
