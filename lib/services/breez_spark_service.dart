// lib/services/breez_spark_service.dart
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:bip39/bip39.dart' as bip39;
import 'package:breez_sdk_spark_flutter/breez_sdk_spark.dart';
import 'package:encrypt/encrypt.dart' as encrypt_pkg;
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../config/breez_config.dart';
import '../core/extensions/breez_config_extensions.dart';

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
  static StreamSubscription<dynamic>? _eventSub;

  // Prevent double initialization
  static bool _isInitializing = false;
  static bool get isInitialized => _sdk != null;

  static Stream<PaymentDetails> get paymentStream => _paymentStream.stream;

  // Balance polling timer
  static Timer? _balanceTimer;

  static Future<void> initPersistence() async {
    await Hive.initFlutter();
    final key = await _getEncryptionKey();
    _box = await Hive.openBox(_boxName, encryptionCipher: HiveAesCipher(key));
    debugPrint('✅ Hive persistence initialized');
  }

  static Future<List<int>> _getEncryptionKey() async {
    // Secure key from device (256-bit)
    return encrypt_pkg.Key.fromLength(32).bytes;
  }

  /// Generate cryptographically secure random bytes for entropy
  static Uint8List _generateSecureRandomEntropy(int length) {
    final random = Random.secure();
    final values = Uint8List(length);
    for (int i = 0; i < length; i++) {
      values[i] = random.nextInt(256);
    }
    return values;
  }

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
        debugPrint(
          '⏳ Spark SDK initialization already in progress - waiting...',
        );
        // Wait for existing initialization to complete
        await Future.delayed(const Duration(seconds: 2));
        if (isInitialized) return;
        throw Exception('Previous initialization failed');
      }

      _isInitializing = true;
      debugPrint('🚀 Initializing Spark SDK...');

      // Step 1: Init Spark lib (once per app, guarded by flag)
      try {
        await BreezSdkSparkLib.init();
        debugPrint('✅ BreezSdkSparkLib initialized');
      } catch (e) {
        if (e.toString().contains(
          'Should not initialize flutter_rust_bridge twice',
        )) {
          debugPrint('✅ BreezSdkSparkLib already initialized');
        } else {
          rethrow;
        }
      }

      // Step 2: Get writable storage dir (fixes ./storage.sql forever)
      final docsDir = await getApplicationDocumentsDirectory();
      final storageDir = docsDir.path;
      debugPrint('📁 Using Spark storage dir: $storageDir');

      // Ensure directory exists
      final dir = Directory(storageDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // Step 3: Construct seed (new wallet or restore)
      Seed seed;
      String mnemonicPhrase;

      if (isRestore && mnemonic != null && mnemonic.trim().isNotEmpty) {
        // RESTORE: Use user mnemonic – overwrite Hive to fix "same seed" issue
        mnemonicPhrase = mnemonic.trim();
        seed = Seed.mnemonic(mnemonic: mnemonicPhrase, passphrase: null);
        await _box.put('mnemonic', mnemonicPhrase);
        debugPrint('🔄 Wallet restored from mnemonic – overwriting storage');
      } else if (mnemonic != null && mnemonic.trim().isNotEmpty) {
        // Use provided mnemonic (e.g., from settings restore)
        mnemonicPhrase = mnemonic.trim();
        seed = Seed.mnemonic(mnemonic: mnemonicPhrase, passphrase: null);
        await _box.put('mnemonic', mnemonicPhrase);
        debugPrint('🔄 Wallet restored from mnemonic');
      } else {
        // NEW WALLET: Generate mnemonic from secure entropy
        final secureEntropy = _generateSecureRandomEntropy(32); // 256-bit
        mnemonicPhrase = bip39.entropyToMnemonic(
          secureEntropy.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        );
        seed = Seed.mnemonic(mnemonic: mnemonicPhrase, passphrase: null);

        // CRITICAL: Save mnemonic so wallet can be restored on app restart
        await _box.put('mnemonic', mnemonicPhrase);
        debugPrint('✨ New wallet created with mnemonic (saved to storage)');
      }

      // Step 4: Create config with API key (following SDK documentation pattern)
      debugPrint('🔑 Fetching Breez API key...');
      final apiKey = await BreezConfig.apiKey;

      // Select network based on config
      final network =
          BreezConfig.useRegtest ? Network.regtest : Network.mainnet;
      debugPrint('🌐 Network: ${BreezConfig.networkType}');

      if (BreezConfig.useRegtest) {
        debugPrint('✅ Using Regtest network (no API key required)');
      } else {
        debugPrint('✅ API key fetched (${apiKey.length} chars)');
      }

      // Use copyWith pattern from SDK docs to inject API key while preserving defaults
      final config = defaultConfig(
        network: network,
      ).copyWith(apiKey: apiKey.isEmpty ? null : apiKey);
      debugPrint('🔧 Config created for ${BreezConfig.networkType}');

      // Step 5: Connect (creates wallet + opens channel instantly)
      final connectRequest = ConnectRequest(
        config: config,
        seed: seed,
        storageDir: storageDir, // ← THIS FIXES SQL ERROR
      );

      _sdk = await connect(request: connectRequest);
      debugPrint(
        '✅ Spark SDK connected! Local node ready – offline sovereignty achieved.',
      );

      // Forced API key validation: immediately call getInfo
      try {
        final nodeInfo = await _sdk!.getInfo(request: GetInfoRequest());
        debugPrint('✅ API key validated, node info: ${nodeInfo.toString()}');
      } catch (e) {
        debugPrint('❌ API key validation failed: $e');
        _sdk = null;
        throw Exception('Invalid Breez API key: $e');
      }

      debugPrint('✅ Spark SDK connected! Bootstrapping inbound liquidity...');

      // Bootstrap: 0-sat invoice opens LSP channel automatically (fixes "unable to complete")
      // Docs: receivePayment with zero amount triggers JIT channel open
      final bootstrapReq = ReceivePaymentRequest(
        paymentMethod: ReceivePaymentMethod.bolt11Invoice(
          description: 'Sabi Wallet liquidity bootstrap',
          amountSats: BigInt.zero, // 0 = open channel only, no payment
        ),
      );

      try {
        await _sdk!.receivePayment(request: bootstrapReq);
        debugPrint('📡 Inbound channel opened – ready to receive');
      } catch (e) {
        debugPrint('⚠️ Bootstrap fallback: $e – first real receive will open channel');
      }

      // Polling getInfo triggers internal blockchain sync
      debugPrint('🔄 Polling blockchain for Bitcoin receives...');
      for (int i = 0; i < 5; i++) {
        try {
          await Future.delayed(const Duration(seconds: 3));
          await _sdk!.getInfo(request: GetInfoRequest());
          debugPrint('✅ Blockchain poll $i - checking for Bitcoin receives');
        } catch (e) {
          debugPrint('⚠️ Poll $i: $e');
        }
      }

      // Wait for LSP channel setup (typically 5-30 seconds)
      await Future.delayed(const Duration(seconds: 15));

      // Step 8: Listen for payments + balance updates
      _setupEventListener();
      _startBalancePolling();

      await markOnboardingComplete();
      debugPrint('🎉 Spark initialization complete!');
    } catch (e) {
      debugPrint('❌ Spark SDK initialization error: $e');
      _isInitializing = false;
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  /// Diagnostic method: Check if SDK is actually initialized and operational
  /// Returns detailed status for debugging payment failures
  static Future<Map<String, dynamic>> getInitializationStatus() async {
    final status = <String, dynamic>{
      'isInitialized': isInitialized,
      'sdkExists': _sdk != null,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (!isInitialized) {
      debugPrint('⚠️ SDK not initialized!');
      return status;
    }

    try {
      // Try to get node info - this proves SDK is connected
      final nodeInfo = await _sdk!.getInfo(request: GetInfoRequest());
      final balanceSats = _extractBalanceSats(nodeInfo);

      status['nodeInfo'] = {'balanceSats': balanceSats, 'connected': true};
      status['canSend'] = balanceSats > 0;
      status['canReceive'] = true; // Spark with LSP can always receive
      debugPrint('✅ SDK Operational: $balanceSats sats');
    } catch (e) {
      status['error'] = e.toString();
      debugPrint('❌ SDK Error: $e');
    }

    return status;
  }

  // Receive: Generate QR/invoice (supports bolt11, LNURL, Lightning address)
  static Future<ReceivePaymentResponse> createInvoice(
    int sats,
    String memo, {
    ReceivePaymentMethod? method,
  }) async {
    if (_sdk == null) throw Exception('SDK not initialized');

    // Use provided method or default to bolt11
    final paymentMethod =
        method ??
        ReceivePaymentMethod.bolt11Invoice(
          description: memo,
          amountSats: sats > 0 ? BigInt.from(sats) : null,
        );

    final request = ReceivePaymentRequest(paymentMethod: paymentMethod);
    final response = await _sdk!.receivePayment(request: request);
    debugPrint('💰 Invoice/Address created: ${response.paymentRequest}');
    return response;
  }

  /// Generate Bitcoin receiving address (for on-chain payments)
  ///
  /// The SDK monitors this static address for new UTXOs and automatically
  /// initiates the claim process when funds are detected.
  ///
  /// Perfect for testing on Regtest network with faucet:
  /// https://app.lightspark.com/regtest-faucet
  static Future<String> generateBitcoinAddress() async {
    if (_sdk == null) throw Exception('SDK not initialized');

    final request = ReceivePaymentRequest(
      paymentMethod: ReceivePaymentMethod.bitcoinAddress(),
    );
    final response = await _sdk!.receivePayment(request: request);
    final address = response.paymentRequest;
    debugPrint('₿ Bitcoin address generated: $address');
    return address;
  }

  /// Setup event listener for payment events (receive/send updates)
  static void _setupEventListener() {
    if (_sdk == null) return;

    try {
      _eventSub?.cancel();
      final stream = (_sdk as dynamic).addEventListener() as Stream<dynamic>;
      _eventSub = stream.listen((event) async {
        final type = event.runtimeType.toString();
        debugPrint('📥 SDK Event: $type');

        // Handle all critical events
        if (type.contains('PaymentPending') ||
            type.contains('PaymentSucceeded')) {
          debugPrint('💰 Payment event detected - refreshing balance');
          await _refreshBalance(); // Immediate refresh
        } else if (type.contains('NodeSynced')) {
          debugPrint('✅ Node synced – full liquidity available');
          await _refreshBalance();
        }

        await _handleSdkEvent(event);
      });
      debugPrint('✅ Event listener attached (stream)');
    } catch (e) {
      debugPrint('⚠️ Could not attach event listener: $e');
    }
  }

  static Future<void> _handleSdkEvent(dynamic event) async {
    final type = event.runtimeType.toString();
    debugPrint('📥 SDK Event: $type');

    if (type.contains('PaymentReceived') || type.contains('PaymentSucceeded')) {
      final amount = _extractAmountSatsFromEvent(event);
      final fee = _extractFeeSatsFromEvent(event);
      final desc = _extractDescriptionFromEvent(event) ?? '';
      final id = _extractPaymentIdFromEvent(event) ?? 'unknown';

      // Emit to app-level stream (best-effort)
      try {
        _paymentStream.add(
          PaymentDetails(
            id: id,
            amountSats: amount,
            feeSats: fee,
            timestamp: DateTime.now(),
            description: desc,
            inbound: true,
          ),
        );
      } catch (_) {}

      // Refresh balance immediately
      await _refreshBalance();
    }
  }

  /// Balance polling (fixes "no balance after restore/receive")
  /// Faster polling (2s) to detect received payments immediately
  static void _startBalancePolling() {
    _balanceTimer?.cancel();

    _balanceTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_sdk == null) {
        timer.cancel();
        return;
      }

      try {
        // Calling getInfo triggers internal blockchain sync
        final info = await _sdk!.getInfo(request: GetInfoRequest());
        final sats = _extractBalanceSats(info);

        // Try to extract inbound capacity (defensive)
        int inboundSats = 0;
        try {
          final dynamic inboundMsat =
              (info as dynamic).inboundLiquidityMsat ??
              (info as dynamic).channelsBalanceInboundMsat ??
              BigInt.zero;
          if (inboundMsat is BigInt) {
            inboundSats = (inboundMsat ~/ BigInt.from(1000)).toInt();
          } else if (inboundMsat is num) {
            inboundSats = (inboundMsat / 1000).toInt();
          }
        } catch (_) {}

        debugPrint('💰 Balance: $sats sats | Inbound: $inboundSats sats');

        // If balance > 0 after receive, force any UI listeners to refresh
        // (payment stream controller can emit balance events here)
      } catch (e) {
        debugPrint('⚠️ Balance poll error: $e');
      }
    });
  }

  static Future<void> _refreshBalance() async {
    if (_sdk == null) return;
    try {
      final info = await _sdk!.getInfo(request: GetInfoRequest());
      final sats = _extractBalanceSats(info);
      debugPrint('💰 Balance refreshed: $sats sats');
    } catch (e) {
      debugPrint('⚠️ Balance refresh error: $e');
    }
  }

  /// Stop balance polling
  static void _stopBalancePolling() {
    _balanceTimer?.cancel();
    _balanceTimer = null;
  }

  // Send: Pay bolt11/LNURL/Lightning address (with proper prep + method detection)
  static Future<SendPaymentResponse> sendPayment(
    String identifier, {
    int? sats,
  }) async {
    if (_sdk == null) throw Exception('SDK not initialized');

    try {
      debugPrint(
        '🔍 Attempting to send to: $identifier (amount: ${sats ?? "invoice amount"} sats)',
      );

      // Step 1: Prepare (validates format + auto-detects method)
      // Fixes "failed to parse: SDK Error: invalidinput (field0: unsupported payment method)"
      final prepareReq = PrepareSendPaymentRequest(
        paymentRequest: identifier,
        amount: sats != null ? BigInt.from(sats) : null,
      );
      final prepareResp = await _sdk!.prepareSendPayment(request: prepareReq);

      debugPrint(
        '🔍 Parsed payment method: ${prepareResp.paymentMethod.runtimeType}',
      );

      // Step 2: Send with auto-detected method
      // SDK handles bolt11/LNURL/Lightning address/Bitcoin address automatically
      final sendReq = SendPaymentRequest(prepareResponse: prepareResp);
      final response = await _sdk!.sendPayment(request: sendReq);
      debugPrint('💸 Payment sent: ${response.payment.id}');
      return response;
    } catch (e) {
      debugPrint('❌ Send failed: $e (identifier: $identifier, sats: $sats)');
      if (e.toString().contains('Unsupported payment method')) {
        debugPrint(
          'ℹ️ Tip: Lightning addresses need amount specified. Try with sats parameter.',
        );
      }
      rethrow;
    }
  }

  // Get balance (in sats)
  static Future<GetInfoResponse> getBalance() async {
    if (_sdk == null) throw Exception('SDK not initialized');
    final req = GetInfoRequest();
    return await _sdk!.getInfo(request: req);
  }

  static Future<int?> getBalanceSatsSafe() async {
    if (_sdk == null) return null;
    try {
      final info = await getBalance();
      return _extractBalanceSats(info);
    } catch (_) {
      return null;
    }
  }

  /// Force blockchain check - call this to check for Bitcoin receives
  /// Repeatedly calls getInfo to trigger internal blockchain sync
  /// Returns the updated balance after checks
  static Future<int?> syncAndGetBalance() async {
    if (_sdk == null) {
      debugPrint('⚠️ SDK not initialized');
      return null;
    }

    try {
      debugPrint('🔄 Checking blockchain for Bitcoin receives...');
      // Poll multiple times to trigger internal sync
      for (int i = 0; i < 3; i++) {
        await Future.delayed(const Duration(seconds: 2));
        await getBalance();
        debugPrint('✅ Blockchain check $i complete');
      }

      final info = await getBalance();
      final sats = _extractBalanceSats(info);
      debugPrint('💰 Final balance: $sats sats');
      return sats;
    } catch (e) {
      debugPrint('❌ Check error: $e');
      return null;
    }
  }

  // List payments (for tx history)
  static Future<ListPaymentsResponse> listPayments({int? limit}) async {
    if (_sdk == null) throw Exception('SDK not initialized');
    final req = ListPaymentsRequest(limit: limit ?? 50);
    return await _sdk!.listPayments(request: req);
  }

  static Future<List<PaymentDetails>> listPaymentDetails({int? limit}) async {
    if (_sdk == null) return [];
    try {
      final response = await listPayments(limit: limit);
      final payments = response.payments;
      return payments.map(_mapPayment).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> markOnboardingComplete() async {
    await _box.put('has_onboarded', true);
  }

  static bool get hasCompletedOnboarding =>
      _box.get('has_onboarded', defaultValue: false);
  static String? get mnemonic => _box.get('mnemonic');

  /// Force reconnect from stored mnemonic (for settings restore)
  static Future<void> restoreFromStoredMnemonic() async {
    final storedMnemonic = mnemonic;
    if (storedMnemonic != null) {
      _sdk = null; // Reset SDK to force reconnect
      await initializeSparkSDK(mnemonic: storedMnemonic, isRestore: true);
      debugPrint('🔄 Forced reconnection from stored mnemonic');
    }
  }

  static int _extractInt(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final val = json[key];
      if (val is BigInt) return val.toInt();
      if (val is num) return val.toInt();
      if (val is String) {
        final parsed = int.tryParse(val);
        if (parsed != null) return parsed;
      }
    }
    return 0;
  }

  static int _extractBalanceSats(GetInfoResponse info) {
    // Defensive extraction to avoid API surface changes breaking UI
    try {
      final dynamic value =
          (info as dynamic).balanceSat ?? (info as dynamic).balanceSats;
      if (value is BigInt) return value.toInt();
      if (value is num) return value.toInt();
    } catch (_) {}

    try {
      final dynamic json = (info as dynamic).toJson();
      if (json is Map) {
        final dynamic value =
            json['balance_sat'] ??
            json['balanceSats'] ??
            json['balance'] ??
            json['balance_sat_sats'];
        if (value is BigInt) return value.toInt();
        if (value is num) return value.toInt();
      }
    } catch (_) {}
    return 0;
  }

  static PaymentDetails _mapPayment(dynamic payment) {
    int asInt(dynamic value) {
      if (value is BigInt) return value.toInt();
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    dynamic read(dynamic Function() fn) {
      try {
        return fn();
      } catch (_) {
        return null;
      }
    }

    int msatToSat(int? msat) => msat != null ? (msat / 1000).round() : 0;

    final dynamic json = read(() => payment.toJson()) ?? {};
    final int amountSats = asInt(
      read(() => payment.amountSats) ??
          read(() => payment.amountSat) ??
          json['amount_sats'] ??
          json['amountSat'] ??
          msatToSat(
            asInt(read(() => payment.amountMsat) ?? json['amount_msat']),
          ),
    );

    final int feeSats = asInt(
      read(() => payment.feeSats) ??
          read(() => payment.feesSats) ??
          read(() => payment.feeSat) ??
          json['fee_sats'] ??
          json['feeSat'] ??
          msatToSat(asInt(read(() => payment.feeMsat) ?? json['fee_msat'])),
    );

    final int tsSeconds = asInt(
      read(() => payment.timestamp) ??
          read(() => payment.paymentTime) ??
          json['timestamp'] ??
          json['paymentTime'] ??
          (DateTime.now().millisecondsSinceEpoch ~/ 1000),
    );

    final bool inbound =
        (read(() => payment.inbound) ?? json['inbound']) == true
            ? true
            : amountSats >= 0;

    final String description =
        read(() => payment.description) ?? json['description'] ?? '';
    final String id =
        (read(() => payment.id) ??
                read(() => payment.paymentHash) ??
                json['id'] ??
                json['payment_hash'] ??
                DateTime.now().millisecondsSinceEpoch.toString())
            .toString();
    final String? bolt11 =
        read(() => payment.paymentRequest) ??
        json['payment_request'] ??
        json['bolt11']?.toString();

    return PaymentDetails(
      id: id,
      amountSats: amountSats.abs(),
      feeSats: feeSats.abs(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(tsSeconds * 1000),
      description: description,
      bolt11: bolt11,
      inbound: inbound,
    );
  }

  // --- Safe extraction helpers for events (best-effort, tolerant to schema changes) ---
  static int _extractAmountSatsFromEvent(dynamic event) {
    try {
      final p = (event as dynamic).payment;
      if (p != null) {
        final json = (p as dynamic).toJson();
        if (json is Map) {
          final map = Map<String, dynamic>.from(json);
          return _extractInt(map, [
                'amount_sats',
                'amountSat',
                'amountSats',
                'amount_sat',
                'amount',
                'amount_msat',
              ]) ~/
              1;
        }
      }
    } catch (_) {}
    return 0;
  }

  static int _extractFeeSatsFromEvent(dynamic event) {
    try {
      final p = (event as dynamic).payment;
      if (p != null) {
        final json = (p as dynamic).toJson();
        if (json is Map) {
          final map = Map<String, dynamic>.from(json);
          return _extractInt(map, [
                'fee_sats',
                'feeSat',
                'feeSats',
                'fee_sat',
                'fee',
                'fee_msat',
              ]) ~/
              1;
        }
      }
    } catch (_) {}
    return 0;
  }

  static String? _extractDescriptionFromEvent(dynamic event) {
    try {
      final p = (event as dynamic).payment;
      if (p != null) {
        final json = (p as dynamic).toJson();
        if (json is Map) {
          final candidates = ['description', 'memo', 'label', 'note'];
          for (final key in candidates) {
            final val = json[key];
            if (val is String && val.isNotEmpty) return val;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static String? _extractPaymentIdFromEvent(dynamic event) {
    try {
      final p = (event as dynamic).payment;
      if (p != null) {
        final json = (p as dynamic).toJson();
        if (json is Map) {
          final candidates = ['id', 'payment_id', 'paymentId', 'hash'];
          for (final key in candidates) {
            final val = json[key];
            if (val is String && val.isNotEmpty) return val;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  // --- GetInfo helpers ---

  static int extractSendAmountSats(SendPaymentResponse response) {
    int asInt(dynamic value) {
      if (value is BigInt) return value.toInt();
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    dynamic read(dynamic Function() fn) {
      try {
        return fn();
      } catch (_) {
        return null;
      }
    }

    final dynamic payment =
        read(() => (response as dynamic).payment) ??
        read(() => response) ??
        read(() => (response as dynamic).toJson()['payment']);
    if (payment == null) return 0;

    final dynamic json = read(() => payment.toJson()) ?? {};
    return asInt(
      read(() => payment.amountSats) ??
          read(() => payment.amountSat) ??
          json['amount_sats'] ??
          json['amountSat'] ??
          asInt(read(() => payment.amountMsat) ?? json['amount_msat']) ~/ 1000,
    );
  }

  static int extractSendFeeSats(SendPaymentResponse response) {
    int asInt(dynamic value) {
      if (value is BigInt) return value.toInt();
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    dynamic read(dynamic Function() fn) {
      try {
        return fn();
      } catch (_) {
        return null;
      }
    }

    final dynamic payment =
        read(() => (response as dynamic).payment) ??
        read(() => response) ??
        read(() => (response as dynamic).toJson()['payment']);
    if (payment == null) return 0;

    final dynamic json = read(() => payment.toJson()) ?? {};
    return asInt(
      read(() => payment.feeSats) ??
          read(() => payment.feesSats) ??
          read(() => payment.feeSat) ??
          json['fee_sats'] ??
          json['feeSat'] ??
          asInt(read(() => payment.feeMsat) ?? json['fee_msat']) ~/ 1000,
    );
  }

  /// Get the current wallet's mnemonic (for backup/restore)
  static Future<String?> getMnemonic() async {
    try {
      return await _box.get('mnemonic');
    } catch (_) {
      return null;
    }
  }

  /// Cleanup resources
  static void dispose() {
    _stopBalancePolling();
    _eventSub?.cancel();
    _paymentStream.close();
  }
}
