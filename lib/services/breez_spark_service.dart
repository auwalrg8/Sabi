// lib/services/breez_spark_service.dart
// Production-ready Breez SDK Spark (Nodeless) - Aligned with Official Docs
// https://sdk-doc-spark.breez.technology/

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:bip39/bip39.dart' as bip39;
import 'package:breez_sdk_spark_flutter/breez_sdk_spark.dart';
import 'package:encrypt/encrypt.dart' as encrypt_pkg;
import 'package:flutter/foundation.dart';
import 'package:sabi_wallet/services/rate_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../config/breez_config.dart';
import '../core/constants/lightning_address.dart';
import 'app_state_service.dart';
import 'lightning_address_manager.dart';
import 'profile_service.dart';

/// Local wrapper class for payment history display
class PaymentRecord {
  final String id;
  final int amountSats;
  final int feeSats;
  final int paymentTime; // Unix timestamp in milliseconds from Breez SDK
  final String description;
  final String? bolt11;
  final bool isIncoming;

  PaymentRecord({
    required this.id,
    required this.amountSats,
    this.feeSats = 0,
    required this.paymentTime,
    this.description = '',
    this.bolt11,
    this.isIncoming = true,
  });
}

enum PendingPaymentStatus { pending, completed, failed }

class PendingPaymentRecord {
  final String id;
  final String recipientName;
  final String recipientIdentifier;
  final int amountSats;
  final DateTime startedAt;
  final PendingPaymentStatus status;
  final String? memo;

  const PendingPaymentRecord({
    required this.id,
    required this.recipientName,
    required this.recipientIdentifier,
    required this.amountSats,
    required this.startedAt,
    this.status = PendingPaymentStatus.pending,
    this.memo,
  });
}

class BreezSparkService {
  static const _boxName = 'breez_spark_data';
  static late Box _box;
  static BreezSdk? _sdk;
  static final StreamController<PaymentRecord> _paymentStream =
      StreamController.broadcast();
  static final Map<String, PendingPaymentRecord> _pendingPayments = {};
  static StoredLightningAddress? _lightningAddressDetails;
  static StoredLightningAddress? get lightningAddressDetails =>
      _lightningAddressDetails;
  static final StreamController<List<PendingPaymentRecord>>
  _pendingPaymentsController =
      StreamController<List<PendingPaymentRecord>>.broadcast();
  static final Stream<List<PendingPaymentRecord>> _pendingPaymentsStream =
      Stream.multi((controller) {
        controller.add(_pendingPayments.values.toList());
        final sub = _pendingPaymentsController.stream.listen(controller.add);
        controller.onCancel = sub.cancel;
      }, isBroadcast: true);

  static Stream<List<PendingPaymentRecord>> get pendingPaymentsStream =>
      _pendingPaymentsStream;

  // DEBUG: Flag to allow app to work without SDK for development
  static bool _useMockSDK = false;

  // CRITICAL: Track if the Rust bridge was successfully initialized
  // This is set from main.dart during app startup
  static bool rustBridgeInitialized = false;

  static void _emitPendingPayments() {
    if (_pendingPaymentsController.isClosed) return;
    _pendingPaymentsController.add(_pendingPayments.values.toList());
  }

  static void _registerPendingPayment(PendingPaymentRecord record) {
    _pendingPayments[record.id] = record;
    _emitPendingPayments();
  }

  static void _removePendingPayment(String id) {
    if (_pendingPayments.remove(id) != null) {
      _emitPendingPayments();
    }
  }

  static final BigInt _msatThreshold = BigInt.from(999999);
  static final BigInt _msatPerSat = BigInt.from(1000);

  // Prevent double initialization
  static bool _isInitializing = false;
  static bool _persistenceInitialized = false;
  static bool get isInitialized => _sdk != null || _useMockSDK;

  static Stream<PaymentRecord> get paymentStream => _paymentStream.stream;

  // Balance polling
  static final StreamController<int> _balanceStream =
      StreamController.broadcast();
  static Stream<int> get balanceStream => _balanceStream.stream;
  static Timer? _balancePollingTimer;

  // Payment polling to detect new payments
  static Timer? _paymentPollingTimer;
  static String? _lastPaymentId;

  // Start balance polling
  static void _startBalancePolling() {
    _balancePollingTimer?.cancel();
    _balancePollingTimer = Timer.periodic(const Duration(seconds: 3), (
      _,
    ) async {
      try {
        final balance = await getBalance();
        _balanceStream.add(balance);
      } catch (e) {
        debugPrint('⚠️ Balance polling error: $e');
      }
    });
  }

  // Start payment polling to detect new payments
  static void _startPaymentPolling() {
    _paymentPollingTimer?.cancel();

    // Initialize _lastPaymentId with current latest payment to avoid
    // triggering notification for existing payments
    listPayments(limit: 1).then((payments) {
      if (payments.isNotEmpty) {
        _lastPaymentId = payments.first.id;
        debugPrint('📋 Initial lastPaymentId set to: $_lastPaymentId');
      }
    });

    _paymentPollingTimer = Timer.periodic(const Duration(seconds: 2), (
      _,
    ) async {
      try {
        final payments = await listPayments(limit: 1);
        if (payments.isNotEmpty) {
          final latestPayment = payments.first;
          if (_lastPaymentId != null && _lastPaymentId != latestPayment.id) {
            debugPrint('🔔 NEW PAYMENT DETECTED!');
            debugPrint('   Previous ID: $_lastPaymentId');
            debugPrint('   New ID: ${latestPayment.id}');
            debugPrint('   Amount: ${latestPayment.amountSats} sats');
            debugPrint('   IsIncoming: ${latestPayment.isIncoming}');
            _lastPaymentId = latestPayment.id;
            _paymentStream.add(latestPayment);
            debugPrint('📢 Payment added to stream');
          } else if (_lastPaymentId == null) {
            // First poll - just set the ID without triggering notification
            _lastPaymentId = latestPayment.id;
            debugPrint('📋 First poll - lastPaymentId set to: $_lastPaymentId');
          }
        }
      } catch (e) {
        debugPrint('⚠️ Payment polling error: $e');
      }
    });
  }

  // Stop balance polling
  static void stopBalancePolling() {
    _balancePollingTimer?.cancel();
  }

  // Stop payment polling
  static void stopPaymentPolling() {
    _paymentPollingTimer?.cancel();
  }

  // Key for storing Hive encryption key in secure storage
  static const _hiveEncryptionKeyName = 'breez_spark_hive_encryption_key';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _stableBalanceStorageKey = 'stable_balance_active';
  // Known token identifiers used by the app (kept in sync with SDK config)
  static const String usdbTokenIdentifier =
      'btkn1xgrvjwey5ngcagvap2dzzvsy4uk8ua9x69k82dwvt5e7ef9drm9qztux87';

  // ============================================================================
  // STEP 1: Initialize Hive persistence
  // ============================================================================
  static Future<void> initPersistence() async {
    if (_persistenceInitialized) {
      return;
    }
    // Hive.initFlutter() is now called globally in main() to avoid race conditions
    final key = await _getEncryptionKey();
    _box = await Hive.openBox(_boxName, encryptionCipher: HiveAesCipher(key));
    _persistenceInitialized = true;
    debugPrint('✅ Breez Spark persistence initialized');
  }

  /// Get the Hive encryption key, generating and persisting it if needed.
  /// CRITICAL: The key must be stored in secure storage to persist across app restarts.
  /// Without this, the mnemonic stored in Hive would be unreadable after app restart.
  static Future<List<int>> _getEncryptionKey() async {
    try {
      // Try to read existing key from secure storage
      final existingKey = await _secureStorage.read(
        key: _hiveEncryptionKeyName,
      );
      if (existingKey != null && existingKey.isNotEmpty) {
        // Decode the stored key (stored as base64)
        final bytes = base64Decode(existingKey);
        if (bytes.length == 32) {
          debugPrint(
            '🔑 Using existing Hive encryption key from secure storage',
          );
          return bytes;
        }
      }

      // No existing key found - generate a new one
      debugPrint('🔑 Generating new Hive encryption key...');
      final newKey = encrypt_pkg.Key.fromLength(32).bytes;

      // Store the key in secure storage for future use
      final keyBase64 = base64Encode(newKey);
      await _secureStorage.write(key: _hiveEncryptionKeyName, value: keyBase64);
      debugPrint('✅ Hive encryption key saved to secure storage');

      return newKey;
    } catch (e) {
      debugPrint('❌ Error getting encryption key: $e');
      // Fallback to generating a new key (will cause data loss if previous data exists)
      return encrypt_pkg.Key.fromLength(32).bytes;
    }
  }

  /// Persist and (if possible) apply Stable Balance user preference.
  /// Writes to secure storage and attempts to update the SDK user settings.
  static Future<void> setStableBalanceActive(bool active) async {
    await _secureStorage.write(key: _stableBalanceStorageKey, value: active.toString());

    // If SDK initialized, we may apply the preference via SDK APIs later.
    // For now, persist to secure storage and log; SDK initialization path
    // should read this key and apply the preference when available.
    if (_sdk != null) {
      debugPrint('ℹ️ SDK initialized — stable balance pref saved: $active (SDK update deferred)');
    } else {
      debugPrint('ℹ️ SDK not initialized; stable balance pref saved for later: $active');
    }
  }

  // ============================================================================
  // STEP 2: Initialize Spark SDK
  // ============================================================================
  static Future<void> initializeSparkSDK({
    String? mnemonic,
    bool isRestore = false,
  }) async {
    try {
      // CRITICAL: Check if Rust bridge was initialized successfully
      if (!rustBridgeInitialized) {
        throw StateError(
          'Error creating wallet: Rust bridge not initialized. '
          'The native library failed to load. This is usually caused by:\n'
          '1. Missing native library in the build\n'
          '2. Architecture mismatch (e.g., x86 vs ARM)\n'
          '3. Build configuration issues\n\n'
          'Please try reinstalling the app or contact support.',
        );
      }

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
              optimizationConfig: OptimizationConfig(
                autoEnabled: true,
                multiplicity: 1,
              ),
              lnurlDomain: lightningAddressDomain,
              // Stable Balance configuration (USDB for USD stability against BTC volatility)
              stableBalanceConfig: StableBalanceConfig(
                tokens: [
                  StableBalanceToken(
                    label: 'USDB',
                    tokenIdentifier: usdbTokenIdentifier,
                  ),
                ],
                defaultActiveLabel: null, // Opt-in via UI toggle for clean UX
                thresholdSats: null, // Use protocol minimum
                maxSlippageBps: null, // Use default 10 bps (0.1%)
              ),
              // Required by SDK: limit concurrent claim operations (default 4)
              maxConcurrentClaims: 4,
            ),
            seed: Seed.mnemonic(mnemonic: seedMnemonic),
            storageDir: storageDir,
          ),
        );
        debugPrint('✅ Connected to Breez Spark SDK successfully');
      } catch (e) {
        if (e.toString().contains('libbreez_sdk_spark_flutter.so') ||
            e.toString().contains('dynamic library') ||
            e.toString().contains('Failed to load')) {
          // Native library missing - use mock SDK for development/testing
          debugPrint('⚠️ Native library not found, using mock SDK: $e');
          _useMockSDK = true;
          _sdk = null; // Don't set SDK, but mark as using mock
          // Continue with mock SDK initialization
        } else {
          _sdk = null;
          debugPrint('❌ SDK connect() failed: $e');
          rethrow;
        }
      }

      // VALIDATE API KEY: Call getInfo() immediately to ensure SDK is working (if not using mock)
      if (!_useMockSDK) {
        try {
          debugPrint('🔍 Validating SDK connection with getInfo()...');
          final info = await _sdk!.getInfo(request: GetInfoRequest());
          debugPrint(
            '✅ API validation SUCCESS - Balance: ${info.balanceSats} sats',
          );
        } catch (e) {
          _sdk = null;
          debugPrint('❌ API validation FAILED: $e');
          rethrow;
        }
      } else {
        debugPrint('✅ Using mock SDK - skipping API validation');
      }

      // Bootstrap liquidity
      try {
        await bootstrap();
      } catch (e) {
        debugPrint('⚠️ Bootstrap failed (non-critical): $e');
      }

      // Mark onboarding as complete and save wallet initialization timestamp
      await _box.put('has_completed_onboarding', true);
      await _box.put(
        'wallet_initialized_at',
        DateTime.now().millisecondsSinceEpoch,
      );

      // Mark wallet as created in app state
      await AppStateService.markWalletCreated();

      debugPrint('🔒 ONBOARDING FLAG SAVED — WILL NEVER SHOW AGAIN');
      debugPrint('✅ Wallet state saved to AppStateService');

      // Start payment polling to detect new incoming/outgoing payments
      _startPaymentPolling();
      debugPrint('🔔 Payment polling started');

      _isInitializing = false;

      // Start balance polling immediately
      _startBalancePolling();

      await _syncLightningAddress();

      debugPrint('✅✅✅ SPARK SDK INITIALIZED ✅✅✅');
    } catch (e) {
      _isInitializing = false;
      _sdk = null;
      debugPrint('❌ SDK init failed: $e');
      rethrow;
    }
      // Apply saved Stable Balance preference (if any) to the SDK user settings.
      try {
        final saved = await _secureStorage.read(key: _stableBalanceStorageKey);
        if (saved == 'true' && !_useMockSDK && _sdk != null) {
          try {
            final req = UpdateUserSettingsRequest(
              stableBalanceActiveLabel: StableBalanceActiveLabel.set_(label: 'USDB'),
            );
            await _sdk!.updateUserSettings(request: req);
            debugPrint('✅ Applied saved stable-balance preference to SDK (USDB)');
          } catch (e) {
            debugPrint('⚠️ Failed to apply stable-balance pref to SDK: $e');
          }
        } else if (saved == 'true') {
          debugPrint('ℹ️ Stable-balance pref present but SDK unavailable; will apply later');
        }
      } catch (e) {
        debugPrint('⚠️ Could not read stable-balance pref from storage: $e');
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
    // Guard: ensure SDK is initialized or using mock
    if (_sdk == null && !_useMockSDK) {
      debugPrint('⏳ SDK not initialized yet - returning 0 balance');
      return 0; // Return safe default instead of throwing
    }

    // Return mock balance if using mock SDK
    if (_useMockSDK) {
      debugPrint('💰 Balance: 100000 sats (mock)');
      return 100000;
    }

    try {
      // First try with ensureSynced: true for fresh balance
      // If network fails, fall back to cached balance
      GetInfoResponse info;
      try {
        info = await _sdk!
            .getInfo(request: GetInfoRequest(ensureSynced: true))
            .timeout(const Duration(seconds: 5));
      } catch (syncError) {
        debugPrint('⚠️ Synced balance fetch failed, using cached: $syncError');
        // Fall back to cached balance (ensureSynced: false)
        info = await _sdk!
            .getInfo(request: GetInfoRequest(ensureSynced: false))
            .timeout(const Duration(seconds: 5));
      }

      // balanceSats is already in sats (not msat)
      final balanceSats = info.balanceSats.toInt();

      debugPrint('💰 Balance: $balanceSats sats (raw: ${info.balanceSats})');
      return balanceSats;
    } catch (e) {
      debugPrint('❌ Get balance error: $e');
      return 0;
    }
  }

  // ============================================================================
  // Lightning address helpers
  // ============================================================================

  /// Sync lightning address - fetches existing or auto-registers new one.
  /// This is called during SDK initialization to ensure user always has an address.
  static Future<void> _syncLightningAddress() async {
    try {
      // First, try to fetch existing lightning address from SDK
      final existingAddress = await fetchLightningAddress();

      if (existingAddress != null) {
        debugPrint(
          '✅ Lightning address already registered: ${existingAddress.address}',
        );
        return;
      }

      // No address registered - auto-register a new one
      debugPrint('🔄 No lightning address found, auto-registering...');
      await _autoRegisterLightningAddress();
    } catch (e) {
      debugPrint('⚠️ Lightning address sync failed: $e');
      // Try auto-registration as fallback
      try {
        await _autoRegisterLightningAddress();
      } catch (regError) {
        debugPrint('⚠️ Auto-registration also failed: $regError');
      }
    }
  }

  /// Automatically register a lightning address with a random username.
  /// Retries with alternative usernames if the first one is taken.
  static Future<StoredLightningAddress?> _autoRegisterLightningAddress() async {
    if (_sdk == null) {
      debugPrint('⚠️ Cannot auto-register: SDK not initialized');
      return null;
    }

    // Generate initial random username
    String username = LightningAddressManager.generateRandomUsername();
    debugPrint('🎲 Generated username: $username');

    // Try to register with retries for taken usernames
    const maxAttempts = 5;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        // Check availability first
        final isAvailable = await checkLightningAddressAvailability(username);

        if (!isAvailable) {
          debugPrint(
            '⚠️ Username "$username" is taken, generating alternative...',
          );
          username = LightningAddressManager.generateRandomUsername();
          continue;
        }

        // Register the address
        final address = await registerLightningAddress(
          username: username,
          description: 'Receive sats via Sabi Wallet',
        );

        // Save to secure storage
        await LightningAddressManager.saveRegisteredAddress(
          username: username,
          fullAddress: address.address,
        );

        debugPrint('✅ Auto-registered lightning address: ${address.address}');
        return address;
      } catch (e) {
        debugPrint('⚠️ Registration attempt $attempt failed: $e');
        if (attempt < maxAttempts) {
          username = LightningAddressManager.generateRandomUsername();
        }
      }
    }

    debugPrint(
      '❌ Failed to auto-register lightning address after $maxAttempts attempts',
    );
    return null;
  }

  static Future<StoredLightningAddress?> fetchLightningAddress() async {
    if (_sdk == null) {
      debugPrint('❌ SDK not initialized - cannot fetch Lightning address');
      throw Exception('SDK not initialized');
    }
    try {
      final info = await _sdk!.getLightningAddress();
      final details = info == null ? null : _buildLightningAddressDetails(info);
      await _cacheLightningAddress(details);
      return details;
    } catch (e) {
      debugPrint('❌ Fetch Lightning address failed: $e');
      rethrow;
    }
  }

  static Future<bool> checkLightningAddressAvailability(String username) async {
    if (_sdk == null) {
      debugPrint('❌ SDK not initialized - cannot check Lightning address');
      throw Exception('SDK not initialized');
    }
    final request = CheckLightningAddressRequest(username: username);
    final available = await _sdk!.checkLightningAddressAvailable(
      request: request,
    );
    debugPrint('ℹ️ Lightning username "$username" available: $available');
    return available;
  }

  static Future<StoredLightningAddress> registerLightningAddress({
    required String username,
    String? description,
  }) async {
    if (_sdk == null) {
      debugPrint('❌ SDK not initialized - cannot register Lightning address');
      throw Exception('SDK not initialized');
    }
    final desc =
        description ?? 'Receive payments via Sabi wallet for $username';
    final request = RegisterLightningAddressRequest(
      username: username,
      description: desc,
    );
    final info = await _sdk!.registerLightningAddress(request: request);
    final details = _buildLightningAddressDetails(info);
    await _cacheLightningAddress(details);
    debugPrint('✅ Lightning address registered: ${details.address}');
    return details;
  }

  static Future<void> deleteLightningAddress() async {
    if (_sdk == null) {
      debugPrint('❌ SDK not initialized - cannot delete Lightning address');
      throw Exception('SDK not initialized');
    }
    await _sdk!.deleteLightningAddress();
    await _cacheLightningAddress(null);
    debugPrint('🗑️ Lightning address deleted');
  }

  static Future<LnurlReceiveMetadata?> fetchLnurlReceiveMetadata(
    String paymentId,
  ) async {
    if (_sdk == null) {
      debugPrint('❌ SDK not initialized - cannot fetch LNURL metadata');
      throw Exception('SDK not initialized');
    }
    final response = await _sdk!.getPayment(
      request: GetPaymentRequest(paymentId: paymentId),
    );
    final details = response.payment.details;
    if (details case PaymentDetails_Lightning lightningDetails) {
      return lightningDetails.lnurlReceiveMetadata;
    }
    return null;
  }

  static StoredLightningAddress _buildLightningAddressDetails(
    LightningAddressInfo info,
  ) {
    return StoredLightningAddress(
      address: info.lightningAddress,
      username: info.username,
      description: info.description,
      // SDK lnurl is a structured object; store its string representation
      lnurl: info.lnurl.toString(),
    );
  }

  static Future<void> _cacheLightningAddress(
    StoredLightningAddress? details,
  ) async {
    _lightningAddressDetails = details;
    await ProfileService.updateLightningAddress(details);
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
        if (timer.tick > 30) {
          // Stop after 60 seconds
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

  /// Create a token (e.g., USDB) receive invoice using Spark invoices.
  /// Converts sats -> token fractional amount using live BTC->USD rate and token decimals.
  static Future<String> createTokenInvoice({
    required int sats,
    required String tokenIdentifier,
    String memo = '',
  }) async {
    if (_sdk == null) {
      debugPrint('❌ SDK not initialized - cannot create token invoice');
      throw Exception('SDK not initialized');
    }

    try {
      // Convert sats -> BTC -> USD
      final usd = await RateService.satsToUsd(sats);

      // Fetch token metadata to get decimals
      final metaResp = await _sdk!.getTokensMetadata(
        request: GetTokensMetadataRequest(tokenIdentifiers: [tokenIdentifier]),
      );
      final meta = metaResp.tokensMetadata.isNotEmpty ? metaResp.tokensMetadata.first : null;
      final decimals = meta?.decimals ?? 2;

      // Convert USD amount to token fractional units
      final fractionalAmount = BigInt.from((usd * pow(10, decimals)).round());

      final method = ReceivePaymentMethod.sparkInvoice(
        amount: fractionalAmount,
        tokenIdentifier: tokenIdentifier,
        description: memo,
      );

      final req = ReceivePaymentRequest(paymentMethod: method);
      final response = await _sdk!.receivePayment(request: req);

      debugPrint('✅ Token invoice created: ${response.paymentRequest}');
      return response.paymentRequest;
    } catch (e) {
      debugPrint('❌ Token invoice creation failed: $e');
      rethrow;
    }
  }

  // ============================================================================
  // Prepare Send Payment (for showing confirmation before sending)
  // ============================================================================
  static Future<PrepareSendPaymentResponse> prepareSendPayment(
    String identifier,
  ) async {
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
    String? recipientName,
  }) async {
    // Guard: ensure SDK is initialized
    if (_sdk == null) {
      debugPrint('❌ SDK not initialized - cannot send payment');
      throw Exception('SDK not initialized');
    }
    final pendingId = const Uuid().v4();
    final pendingAmountSats = sats ?? 0;
    _registerPendingPayment(
      PendingPaymentRecord(
        id: pendingId,
        recipientName: recipientName ?? identifier,
        recipientIdentifier: identifier,
        amountSats: pendingAmountSats,
        startedAt: DateTime.now(),
        memo: comment.isEmpty ? null : comment,
      ),
    );
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
    } finally {
      _removePendingPayment(pendingId);
    }
  }

  // ============================================================================
  // List Payments
  // ============================================================================
  static Future<List<PaymentRecord>> listPayments({int limit = 50}) async {
    // Guard: ensure SDK is initialized or using mock
    if (_sdk == null && !_useMockSDK) {
      debugPrint('⏳ SDK not initialized yet - returning empty payments list');
      return []; // Return safe default instead of throwing
    }

    // Return empty list if using mock SDK
    if (_useMockSDK) {
      debugPrint('📋 Total payments: 0 (mock)');
      return [];
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
        final amountSats =
            p.amount > BigInt.zero
                ? _toSats(p.amount)
                : _extractAmountFromDetails(p.details, p.amount);
        final feeSats = _toSats(p.fees);

        debugPrint('   Final: amountSats=$amountSats, feeSats=$feeSats');

        records.add(
          PaymentRecord(
            id: p.id,
            amountSats: amountSats,
            feeSats: feeSats,
            paymentTime: _timestampToMillis(p.timestamp),
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
      return _toSats(amount);
    }

    // If amount is 0, try to extract from details if available
    // For now, return 0 - we'd need to parse the invoice from details
    return 0;
  }

  static int _timestampToMillis(BigInt timestamp) {
    return timestamp.toInt() * 1000;
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
    final payment = result['payment'];
    if (payment is Payment) {
      return _toSats(payment.amount);
    }
    final amount = result['amount'];
    if (amount is BigInt) return _toSats(amount);
    if (amount is int) return amount;
    return 0;
  }

  static int extractSendFeeSats(Map<String, dynamic> result) {
    final payment = result['payment'];
    if (payment is Payment) {
      return _toSats(payment.fees);
    }
    final fees = result['fees'];
    if (fees is BigInt) return _toSats(fees);
    if (fees is int) return fees;
    return 0;
  }

  static int _toSats(BigInt value) {
    if (value <= BigInt.zero) return 0;
    if (value > _msatThreshold) {
      return (value ~/ _msatPerSat).toInt();
    }
    return value.toInt();
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
    await _box.put(
      'wallet_initialized_at',
      DateTime.now().millisecondsSinceEpoch,
    );
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
  static Future<List<PaymentRecord>> listPaymentDetails({
    int limit = 50,
  }) async {
    return await listPayments(limit: limit);
  }

  // ============================================================================
  // On-chain Bitcoin Address (Static)
  // ============================================================================
  
  /// Cached static Bitcoin address
  static String? _cachedBitcoinAddress;
  
  /// Get the static on-chain Bitcoin address for receiving deposits.
  /// This is a static address that can be reused for multiple deposits.
  /// The SDK monitors it and automatically claims deposits when detected.
  static Future<String> getBitcoinAddress() async {
    // Return cached address if available
    if (_cachedBitcoinAddress != null) {
      return _cachedBitcoinAddress!;
    }
    
    if (_sdk == null) {
      debugPrint('❌ SDK not initialized - cannot get Bitcoin address');
      throw Exception('SDK not initialized');
    }
    
    try {
      debugPrint('🔗 Requesting static Bitcoin address...');
      final response = await _sdk!.receivePayment(
        request: ReceivePaymentRequest(
          paymentMethod: ReceivePaymentMethod.bitcoinAddress(),
        ),
      );
      
      _cachedBitcoinAddress = response.paymentRequest;
      debugPrint('✅ Bitcoin address: ${response.paymentRequest}');
      debugPrint('   Claim fee: ${response.fee} sats');
      
      return response.paymentRequest;
    } catch (e) {
      debugPrint('❌ Failed to get Bitcoin address: $e');
      rethrow;
    }
  }
  
  /// Get recommended on-chain fees for claims/refunds
  static Future<RecommendedFees> getRecommendedFees() async {
    if (_sdk == null) {
      throw Exception('SDK not initialized');
    }
    
    try {
      final fees = await _sdk!.recommendedFees();
      debugPrint('💰 Recommended fees:');
      debugPrint('   Fastest: ${fees.fastestFee} sat/vB');
      debugPrint('   Half-hour: ${fees.halfHourFee} sat/vB');
      debugPrint('   Hour: ${fees.hourFee} sat/vB');
      debugPrint('   Economy: ${fees.economyFee} sat/vB');
      debugPrint('   Minimum: ${fees.minimumFee} sat/vB');
      return fees;
    } catch (e) {
      debugPrint('❌ Failed to get recommended fees: $e');
      rethrow;
    }
  }

  /// Record an on-chain claim as a local PaymentRecord and persist it.
  /// This allows the UI to surface claimed funds in history and trigger
  /// notifications via the existing `paymentStream`.
  static Future<void> recordOnchainClaim({
    required String txid,
    required int vout,
    required int amountSats,
    int feeSats = 0,
  }) async {
    try {
      final id = 'claim:$txid:$vout';
      final rec = PaymentRecord(
        id: id,
        amountSats: amountSats,
        feeSats: feeSats,
        paymentTime: DateTime.now().millisecondsSinceEpoch,
        description: 'Auto-claimed on-chain deposit $txid:$vout',
        bolt11: null,
        isIncoming: true,
      );

      // Emit to payment stream for UI listeners
      try {
        _paymentStream.add(rec);
      } catch (e) {
        debugPrint('Failed to emit paymentStream for claim: $e');
      }

      // Persist to Hive payments list if box available
      try {
        if (!_persistenceInitialized) await initPersistence();
        final list = (_box.get('payments', defaultValue: []) as List).toList();
        list.insert(0, {
          'id': rec.id,
          'amountSats': rec.amountSats,
          'feeSats': rec.feeSats,
          'paymentTime': rec.paymentTime,
          'description': rec.description,
          'bolt11': rec.bolt11,
          'isIncoming': rec.isIncoming,
        });
        await _box.put('payments', list);
      } catch (e) {
        debugPrint('Failed to persist claim payment record: $e');
      }
    } catch (e) {
      debugPrint('recordOnchainClaim error: $e');
    }
  }

  // ============================================================================
  // Unclaimed Deposits Management
  // ============================================================================
  
  /// List all unclaimed on-chain deposits
  static Future<List<DepositInfo>> listUnclaimedDeposits() async {
    if (_sdk == null) {
      throw Exception('SDK not initialized');
    }
    
    try {
      final response = await _sdk!.listUnclaimedDeposits(
        request: ListUnclaimedDepositsRequest(),
      );
      debugPrint('📋 Unclaimed deposits: ${response.deposits.length}');
      return response.deposits;
    } catch (e) {
      debugPrint('❌ Failed to list unclaimed deposits: $e');
      rethrow;
    }
  }
  
  /// Manually claim an on-chain deposit with specified max fee
  static Future<void> claimDeposit({
    required String txid,
    required int vout,
    required int maxFeeSats,
  }) async {
    if (_sdk == null) {
      throw Exception('SDK not initialized');
    }
    
    try {
      debugPrint('📥 Claiming deposit $txid:$vout with max fee $maxFeeSats sats');
      await _sdk!.claimDeposit(
        request: ClaimDepositRequest(
          txid: txid,
          vout: vout,
          maxFee: MaxFee.fixed(amount: BigInt.from(maxFeeSats)),
        ),
      );
      debugPrint('✅ Deposit claimed successfully');
    } catch (e) {
      debugPrint('❌ Failed to claim deposit: $e');
      rethrow;
    }
  }
  
  /// Refund an unclaimed deposit to an external Bitcoin address
  static Future<RefundDepositResponse> refundDeposit({
    required String txid,
    required int vout,
    required String destinationAddress,
    required int feeSatPerVbyte,
  }) async {
    if (_sdk == null) {
      throw Exception('SDK not initialized');
    }
    
    try {
      debugPrint('💸 Refunding deposit $txid:$vout to $destinationAddress');
      final response = await _sdk!.refundDeposit(
        request: RefundDepositRequest(
          txid: txid,
          vout: vout,
          destinationAddress: destinationAddress,
          fee: Fee.rate(satPerVbyte: BigInt.from(feeSatPerVbyte)),
        ),
      );
      debugPrint('✅ Refund tx: ${response.txId}');
      return response;
    } catch (e) {
      debugPrint('❌ Failed to refund deposit: $e');
      rethrow;
    }
  }

  // ============================================================================
  // Send to On-chain Bitcoin Address
  // ============================================================================
  
  /// Prepare payment to a Bitcoin address - returns fee quotes for different speeds
  static Future<PrepareSendPaymentResponse> prepareBitcoinPayment({
    required String bitcoinAddress,
    required int amountSats,
  }) async {
    if (_sdk == null) {
      throw Exception('SDK not initialized');
    }
    
    try {
      debugPrint('🔍 Preparing Bitcoin payment: $amountSats sats to $bitcoinAddress');
      final response = await _sdk!.prepareSendPayment(
        request: PrepareSendPaymentRequest(
          paymentRequest: bitcoinAddress,
          amount: BigInt.from(amountSats),
        ),
      );
      
      // Extract fee quotes if it's a Bitcoin address payment
      if (response.paymentMethod case SendPaymentMethod_BitcoinAddress btcMethod) {
        final quote = btcMethod.feeQuote;
        debugPrint('💰 Fee quotes:');
        debugPrint('   Slow: ${quote.speedSlow.userFeeSat} sats');
        debugPrint('   Medium: ${quote.speedMedium.userFeeSat} sats');
        debugPrint('   Fast: ${quote.speedFast.userFeeSat} sats');
      }
      
      return response;
    } catch (e) {
      debugPrint('❌ Failed to prepare Bitcoin payment: $e');
      rethrow;
    }
  }
  
  /// Send payment to a Bitcoin address
  static Future<Map<String, dynamic>> sendBitcoinPayment({
    required PrepareSendPaymentResponse prepareResponse,
    OnchainConfirmationSpeed speed = OnchainConfirmationSpeed.medium,
    String? recipientName,
  }) async {
    if (_sdk == null) {
      throw Exception('SDK not initialized');
    }
    
    final pendingId = const Uuid().v4();
    String addressDesc = 'Bitcoin address';
    if (prepareResponse.paymentMethod case SendPaymentMethod_BitcoinAddress btcMethod) {
      addressDesc = btcMethod.address.address;
    }
    
    _registerPendingPayment(
      PendingPaymentRecord(
        id: pendingId,
        recipientName: recipientName ?? 'Bitcoin Address',
        recipientIdentifier: addressDesc,
        amountSats: prepareResponse.amount.toInt(),
        startedAt: DateTime.now(),
      ),
    );
    
    try {
      debugPrint('💸 Sending Bitcoin payment with speed: $speed');
      final response = await _sdk!.sendPayment(
        request: SendPaymentRequest(
          prepareResponse: prepareResponse,
          options: SendPaymentOptions.bitcoinAddress(
            confirmationSpeed: speed,
          ),
          idempotencyKey: pendingId,
        ),
      );
      
      debugPrint('✅ Bitcoin payment sent: ${response.payment.id}');
      
      // Update balance
      final balance = await getBalance();
      _balanceStream.add(balance);
      
      return {
        'payment': response.payment,
        'amount': response.payment.amount,
        'fees': response.payment.fees,
      };
    } catch (e) {
      debugPrint('❌ Bitcoin payment failed: $e');
      rethrow;
    } finally {
      _removePendingPayment(pendingId);
    }
  }
  
  /// Parse an input string to determine its type (Bitcoin address, Lightning invoice, etc.)
  static Future<InputType> parseInput(String input) async {
    if (_sdk == null) {
      throw Exception('SDK not initialized');
    }
    
    try {
      final result = await _sdk!.parse(input: input);
      debugPrint('🔍 Parsed input type: ${result.runtimeType}');
      return result;
    } catch (e) {
      debugPrint('❌ Failed to parse input: $e');
      rethrow;
    }
  }
  
  /// Check if a string looks like a Bitcoin address (quick check without SDK)
  static bool looksLikeBitcoinAddress(String input) {
    final trimmed = input.trim().toLowerCase();
    // Mainnet: starts with 1, 3, or bc1
    // Testnet: starts with m, n, 2, or tb1
    return trimmed.startsWith('bc1') || 
           trimmed.startsWith('1') || 
           trimmed.startsWith('3') ||
           trimmed.startsWith('tb1') ||
           trimmed.startsWith('m') ||
           trimmed.startsWith('n') ||
           trimmed.startsWith('2');
  }

  @Deprecated('Use getBitcoinAddress() instead')
  static Future<String> generateBitcoinAddress() async {
    return getBitcoinAddress();
  }

  static Future<int> getBalanceSatsSafe() async {
    try {
      return await getBalance();
    } catch (e) {
      return 0;
    }
  }

  // ============================================================================
  // User-Friendly Error Messages
  // ============================================================================
  
  /// Converts SDK errors into user-friendly messages
  static String getUserFriendlyErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    // Spark internal validation errors (signing/leaf issues)
    if (errorString.contains('signing jobs') || 
        errorString.contains('leaf id') ||
        errorString.contains('identical transfer')) {
      return 'Payment service is temporarily busy. Please wait a moment and try again.';
    }
    
    // Connection/network errors
    if (errorString.contains('connection error') || 
        errorString.contains('service connection') ||
        errorString.contains('timeout') ||
        errorString.contains('network')) {
      return 'Unable to connect to payment network. Please check your internet connection and try again.';
    }
    
    // Insufficient balance
    if (errorString.contains('insufficient') || 
        errorString.contains('not enough') ||
        errorString.contains('balance')) {
      return 'Insufficient balance to complete this payment.';
    }
    
    // Invalid destination
    if (errorString.contains('invalid') && 
        (errorString.contains('address') || 
         errorString.contains('invoice') ||
         errorString.contains('destination'))) {
      return 'Invalid payment destination. Please check the address or invoice and try again.';
    }
    
    // Invoice expired
    if (errorString.contains('expired') || errorString.contains('expiry')) {
      return 'This invoice has expired. Please request a new one from the recipient.';
    }
    
    // Route not found
    if (errorString.contains('route') || errorString.contains('path')) {
      return 'Could not find a payment route. The recipient may be offline or unreachable.';
    }
    
    // SDK not initialized
    if (errorString.contains('not initialized')) {
      return 'Wallet is still loading. Please wait a moment and try again.';
    }
    
    // gRPC/server errors
    if (errorString.contains('grpc') || 
        errorString.contains('internal') ||
        errorString.contains('service error')) {
      return 'Payment service encountered an error. Please try again in a few moments.';
    }
    
    // Default message - truncate if too long
    final rawMessage = error.toString();
    if (rawMessage.length > 150) {
      return 'Payment failed. Please try again or contact support if the issue persists.';
    }
    return rawMessage;
  }
  
  /// Check if the error is retryable
  static bool isRetryableError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    // These errors are likely temporary and worth retrying
    return errorString.contains('signing jobs') ||
           errorString.contains('leaf id') ||
           errorString.contains('connection') ||
           errorString.contains('timeout') ||
           errorString.contains('service error') ||
           errorString.contains('grpc') ||
           errorString.contains('internal');
  }
}
