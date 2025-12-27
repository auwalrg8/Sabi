import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sabi_wallet/config/vtu_config.dart';
import '../data/models/models.dart';

/// VTU.ng API v2 Service with JWT Authentication
///
/// Key changes from v1:
/// - Uses JWT Bearer token authentication
/// - Token expires after 7 days (auto-refresh implemented)
/// - POST requests for purchases with JSON body
/// - Public endpoints for data/tv variations (no auth required)
/// - Better error codes and messages
class VtuApiService {
  static final http.Client _client = http.Client();

  // Token storage keys
  static const String _tokenKey = 'vtu_jwt_token';
  static const String _tokenExpiryKey = 'vtu_token_expiry';

  // Cached token
  static String? _cachedToken;
  static DateTime? _tokenExpiry;

  /// Get or refresh JWT token
  ///
  /// Token automation strategy:
  /// 1. Check if cached token exists and is not near expiry
  /// 2. If expired or near expiry (within 6 hours), refresh
  /// 3. Store new token in SharedPreferences for persistence
  /// 4. Token is refreshed automatically before each API call
  static Future<String> getToken({bool forceRefresh = false}) async {
    // Load cached token if needed
    if (_cachedToken == null) {
      await _loadStoredToken();
    }

    // Check if we need to refresh
    final now = DateTime.now();
    final needsRefresh =
        forceRefresh ||
        _cachedToken == null ||
        _tokenExpiry == null ||
        now.isAfter(_tokenExpiry!.subtract(VtuConfig.tokenRefreshBuffer));

    if (needsRefresh) {
      await _refreshToken();
    }

    if (_cachedToken == null) {
      throw VtuApiException(
        code: 'auth_failed',
        message: 'Failed to authenticate with VTU.ng',
      );
    }

    return _cachedToken!;
  }

  /// Load stored token from SharedPreferences
  static Future<void> _loadStoredToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedToken = prefs.getString(_tokenKey);
      final expiryMs = prefs.getInt(_tokenExpiryKey);
      if (expiryMs != null) {
        _tokenExpiry = DateTime.fromMillisecondsSinceEpoch(expiryMs);
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load stored token: $e');
    }
  }

  /// Refresh JWT token from VTU.ng
  static Future<void> _refreshToken() async {
    try {
      debugPrint('🔐 Refreshing VTU.ng JWT token...');

      final response = await _client.post(
        Uri.parse(VtuConfig.authUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': VtuConfig.email, // Can use email or username
          'password': VtuConfig.password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['token'] != null) {
        _cachedToken = data['token'];
        _tokenExpiry = DateTime.now().add(VtuConfig.tokenExpiry);

        // Store token persistently
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, _cachedToken!);
        await prefs.setInt(
          _tokenExpiryKey,
          _tokenExpiry!.millisecondsSinceEpoch,
        );

        debugPrint('✅ Token refreshed successfully');
        debugPrint('📧 User: ${data['user_email']}');
      } else {
        final errorCode = data['code'] ?? 'unknown';
        final errorMessage = data['message'] ?? 'Authentication failed';

        debugPrint('❌ Token refresh failed: $errorCode - $errorMessage');

        throw VtuApiException(
          code: errorCode,
          message: errorMessage,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is VtuApiException) rethrow;
      debugPrint('❌ Token refresh error: $e');
      throw VtuApiException(
        code: 'network_error',
        message: 'Failed to connect to VTU.ng: ${e.toString()}',
      );
    }
  }

  /// Get authorization headers
  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = await getToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// Generate unique request ID
  static String _generateRequestId(String prefix) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return '${prefix}_${timestamp}_$random';
  }

  // ==================== BALANCE ====================

  /// Check VTU.ng wallet balance
  static Future<VtuBalanceInfo> getBalance() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await _client.get(
        Uri.parse('${VtuConfig.apiV2Url}/balance'),
        headers: headers,
      );

      final data = jsonDecode(response.body);

      if (data['code'] == 'success') {
        return VtuBalanceInfo(
          balance: double.tryParse(data['data']['balance'].toString()) ?? 0.0,
          currency: data['data']['currency'] ?? 'NGN',
        );
      } else {
        throw VtuApiException(
          code: data['code'] ?? 'unknown',
          message: data['message'] ?? 'Failed to get balance',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is VtuApiException) rethrow;
      throw VtuApiException(
        code: 'network_error',
        message: 'Failed to connect to VTU.ng: ${e.toString()}',
      );
    }
  }

  // ==================== AIRTIME ====================

  /// Purchase airtime (API v2)
  static Future<VtuApiResponse> buyAirtime({
    required String phone,
    required String networkCode,
    required int amount,
  }) async {
    try {
      debugPrint(
        '📱 [API v2] Buying airtime: ₦$amount for $phone on $networkCode',
      );

      final requestId = _generateRequestId('airtime');
      final headers = await _getAuthHeaders();

      final response = await _client.post(
        Uri.parse('${VtuConfig.apiV2Url}/airtime'),
        headers: headers,
        body: jsonEncode({
          'request_id': requestId,
          'phone': phone,
          'service_id': networkCode.toLowerCase(), // mtn, airtel, glo, 9mobile
          'amount': amount,
        }),
      );

      return _parseOrderResponse(response, 'Airtime');
    } catch (e) {
      if (e is VtuApiException) rethrow;
      return VtuApiResponse(
        success: false,
        message: e.toString(),
        errorCode: 'network_error',
      );
    }
  }

  // ==================== DATA ====================

  /// Get data plan variations (public endpoint - no auth required)
  static Future<List<VtuDataPlan>> getDataPlans(String? networkCode) async {
    try {
      var url = '${VtuConfig.apiV2Url}/variations/data';
      if (networkCode != null && networkCode.isNotEmpty) {
        url += '?service_id=${networkCode.toLowerCase()}';
      }

      final response = await _client.get(Uri.parse(url));
      final data = jsonDecode(response.body);

      if (data['code'] != 'success') {
        debugPrint('⚠️ Data plans error: ${data['message']}');
        return [];
      }

      final plans = <VtuDataPlan>[];
      final variations = data['data'] as List? ?? [];

      for (final variation in variations) {
        // Only include available plans
        if (variation['availability'] == 'Available') {
          final price =
              double.tryParse(variation['price']?.toString() ?? '0') ?? 0;
          final resellerPrice =
              double.tryParse(variation['reseller_price']?.toString() ?? '0') ??
              price;

          plans.add(
            VtuDataPlan(
              variationId: variation['variation_id']?.toString() ?? '',
              name: variation['data_plan']?.toString() ?? '',
              price: price,
              resellerPrice: resellerPrice,
              networkCode:
                  variation['service_id']?.toString() ?? networkCode ?? '',
              serviceName: variation['service_name']?.toString() ?? '',
              isAvailable: true,
            ),
          );
        }
      }

      // Sort by reseller price ascending
      plans.sort((a, b) => a.resellerPrice.compareTo(b.resellerPrice));

      debugPrint('📊 Loaded ${plans.length} data plans for $networkCode');
      return plans;
    } catch (e) {
      debugPrint('❌ VTU Data plans error: $e');
      return [];
    }
  }

  /// Purchase data bundle (API v2)
  static Future<VtuApiResponse> buyData({
    required String phone,
    required String networkCode,
    required String variationId,
  }) async {
    try {
      debugPrint('📊 [API v2] Buying data: $variationId for $phone');

      final requestId = _generateRequestId('data');
      final headers = await _getAuthHeaders();

      final response = await _client.post(
        Uri.parse('${VtuConfig.apiV2Url}/data'),
        headers: headers,
        body: jsonEncode({
          'request_id': requestId,
          'phone': phone,
          'service_id': networkCode.toLowerCase(),
          'variation_id': variationId,
        }),
      );

      return _parseOrderResponse(response, 'Data');
    } catch (e) {
      if (e is VtuApiException) rethrow;
      return VtuApiResponse(
        success: false,
        message: e.toString(),
        errorCode: 'network_error',
      );
    }
  }

  // ==================== ELECTRICITY ====================

  /// Get service ID for electricity provider
  static String _getElectricityServiceId(String providerCode) {
    switch (providerCode.toLowerCase()) {
      case 'ikeja':
      case 'ikedc':
        return 'ikeja-electric';
      case 'eko':
      case 'ekedc':
        return 'eko-electric';
      case 'abuja':
      case 'aedc':
        return 'abuja-electric';
      case 'kano':
      case 'kedco':
        return 'kano-electric';
      case 'portharcourt':
      case 'phed':
        return 'portharcourt-electric';
      case 'ibadan':
      case 'ibedc':
        return 'ibadan-electric';
      case 'kaduna':
      case 'kaedco':
        return 'kaduna-electric';
      case 'jos':
      case 'jedc':
        return 'jos-electric';
      case 'enugu':
      case 'eedc':
        return 'enugu-electric';
      case 'benin':
      case 'bedc':
        return 'benin-electric';
      case 'aba':
        return 'aba-electric';
      case 'yola':
        return 'yola-electric';
      default:
        return providerCode.toLowerCase();
    }
  }

  /// Verify customer (meter number, etc) - API v2
  static Future<VtuMeterInfo?> verifyMeter({
    required String meterNumber,
    required String discoCode,
    required String meterType,
  }) async {
    try {
      final headers = await _getAuthHeaders();

      final response = await _client.post(
        Uri.parse('${VtuConfig.apiV2Url}/verify-customer'),
        headers: headers,
        body: jsonEncode({
          'customer_id': meterNumber,
          'service_id': _getElectricityServiceId(discoCode),
          'variation_id': meterType.toLowerCase(), // prepaid or postpaid
        }),
      );

      final data = jsonDecode(response.body);

      if (data['code'] == 'success' && data['data'] != null) {
        final d = data['data'];
        return VtuMeterInfo(
          customerName: d['customer_name']?.toString() ?? '',
          meterNumber: d['meter_number']?.toString() ?? meterNumber,
          address: d['customer_address']?.toString() ?? '',
          minAmount:
              double.tryParse(d['min_purchase_amount']?.toString() ?? '1000') ??
              1000,
          maxAmount:
              double.tryParse(
                d['max_purchase_amount']?.toString() ?? '100000',
              ) ??
              100000,
          arrears:
              double.tryParse(d['customer_arrears']?.toString() ?? '0') ?? 0,
          isValid: true,
        );
      }

      debugPrint('⚠️ Meter verification failed: ${data['message']}');
      return null;
    } catch (e) {
      debugPrint('❌ Meter verify error: $e');
      return null;
    }
  }

  /// Purchase electricity token (API v2)
  static Future<VtuApiResponse> buyElectricity({
    required String meterNumber,
    required String discoCode,
    required String meterType,
    required int amount,
    required String phone,
  }) async {
    try {
      debugPrint('⚡ [API v2] Buying electricity: ₦$amount for $meterNumber');

      final requestId = _generateRequestId('electricity');
      final headers = await _getAuthHeaders();

      final response = await _client.post(
        Uri.parse('${VtuConfig.apiV2Url}/electricity'),
        headers: headers,
        body: jsonEncode({
          'request_id': requestId,
          'customer_id': meterNumber,
          'service_id': _getElectricityServiceId(discoCode),
          'variation_id': meterType.toLowerCase(),
          'amount': amount,
        }),
      );

      return _parseOrderResponse(response, 'Electricity', isElectricity: true);
    } catch (e) {
      if (e is VtuApiException) rethrow;
      return VtuApiResponse(
        success: false,
        message: e.toString(),
        errorCode: 'network_error',
      );
    }
  }

  // ==================== ORDER REQUERY ====================

  /// Requery order status
  static Future<VtuApiResponse> requeryOrder(String requestId) async {
    try {
      final headers = await _getAuthHeaders();

      final response = await _client.post(
        Uri.parse('${VtuConfig.apiV2Url}/requery'),
        headers: headers,
        body: jsonEncode({'request_id': requestId}),
      );

      return _parseOrderResponse(response, 'Requery');
    } catch (e) {
      return VtuApiResponse(
        success: false,
        message: e.toString(),
        errorCode: 'network_error',
      );
    }
  }

  // ==================== CABLE TV ====================

  /// Get service ID for cable TV provider
  static String _getCableTvServiceId(String providerCode) {
    switch (providerCode.toLowerCase()) {
      case 'dstv':
        return 'dstv';
      case 'gotv':
        return 'gotv';
      case 'startimes':
        return 'startimes';
      default:
        return providerCode.toLowerCase();
    }
  }

  /// Get cable TV plan variations (public endpoint - no auth required)
  static Future<List<VtuCableTvPlan>> getCableTvPlans(
    String providerCode,
  ) async {
    try {
      final serviceId = _getCableTvServiceId(providerCode);
      final url = '${VtuConfig.apiV2Url}/variations/tv?service_id=$serviceId';

      debugPrint('📺 Fetching Cable TV plans for $providerCode from: $url');

      final response = await _client.get(Uri.parse(url));
      final data = jsonDecode(response.body);

      if (data['code'] != 'success') {
        debugPrint('⚠️ Cable TV plans error: ${data['message']}');
        return [];
      }

      final plans = <VtuCableTvPlan>[];
      final variations = data['data'] as List? ?? [];

      for (final variation in variations) {
        // Only include available plans
        if (variation['availability'] == 'Available') {
          final price =
              double.tryParse(variation['price']?.toString() ?? '0') ?? 0;
          final resellerPrice =
              double.tryParse(variation['reseller_price']?.toString() ?? '0') ??
              price;

          plans.add(
            VtuCableTvPlan(
              variationId: variation['variation_id']?.toString() ?? '',
              name: variation['plan_name']?.toString() ??
                  variation['name']?.toString() ??
                  '',
              price: price,
              resellerPrice: resellerPrice,
              providerCode: providerCode.toLowerCase(),
              serviceName:
                  variation['service_name']?.toString() ?? providerCode,
              isAvailable: true,
            ),
          );
        }
      }

      // Sort by reseller price ascending
      plans.sort((a, b) => a.resellerPrice.compareTo(b.resellerPrice));

      debugPrint('📺 Loaded ${plans.length} cable TV plans for $providerCode');
      return plans;
    } catch (e) {
      debugPrint('❌ VTU Cable TV plans error: $e');
      return [];
    }
  }

  /// Verify cable TV customer (smartcard number)
  static Future<VtuCableTvCustomerInfo?> verifyCableTvCustomer({
    required String smartcardNumber,
    required String providerCode,
  }) async {
    try {
      debugPrint(
        '📺 Verifying Cable TV customer: $smartcardNumber for $providerCode',
      );

      final headers = await _getAuthHeaders();
      final serviceId = _getCableTvServiceId(providerCode);

      final response = await _client.post(
        Uri.parse('${VtuConfig.apiV2Url}/verify-customer'),
        headers: headers,
        body: jsonEncode({
          'customer_id': smartcardNumber,
          'service_id': serviceId,
        }),
      );

      final data = jsonDecode(response.body);

      if (data['code'] == 'success' && data['data'] != null) {
        final d = data['data'];
        return VtuCableTvCustomerInfo(
          customerName: d['customer_name']?.toString() ?? '',
          smartcardNumber: d['customer_id']?.toString() ?? smartcardNumber,
          currentBouquet: d['current_bouquet']?.toString() ?? '',
          dueDate: d['due_date']?.toString() ?? '',
          isValid: true,
        );
      }

      debugPrint('⚠️ Cable TV verification failed: ${data['message']}');
      return null;
    } catch (e) {
      debugPrint('❌ Cable TV verify error: $e');
      return null;
    }
  }

  /// Purchase cable TV subscription
  static Future<VtuApiResponse> buyCableTv({
    required String smartcardNumber,
    required String providerCode,
    required String variationId,
    required String phone,
  }) async {
    try {
      debugPrint(
        '📺 [API v2] Buying Cable TV: $variationId for $smartcardNumber',
      );

      final requestId = _generateRequestId('cabletv');
      final headers = await _getAuthHeaders();
      final serviceId = _getCableTvServiceId(providerCode);

      final response = await _client.post(
        Uri.parse('${VtuConfig.apiV2Url}/tv'),
        headers: headers,
        body: jsonEncode({
          'request_id': requestId,
          'customer_id': smartcardNumber,
          'service_id': serviceId,
          'variation_id': variationId,
          'phone': phone,
        }),
      );

      return _parseOrderResponse(response, 'Cable TV');
    } catch (e) {
      if (e is VtuApiException) rethrow;
      return VtuApiResponse(
        success: false,
        message: e.toString(),
        errorCode: 'network_error',
      );
    }
  }

  // ==================== RESPONSE PARSING ====================

  /// Parse order response from VTU.ng API v2
  static VtuApiResponse _parseOrderResponse(
    http.Response response,
    String productType, {
    bool isElectricity = false,
  }) {
    final data = jsonDecode(response.body);

    debugPrint('📥 VTU $productType response: $data');

    final code = data['code']?.toString() ?? '';
    final message = data['message']?.toString() ?? '';
    final orderData = data['data'] as Map<String, dynamic>?;

    // Success cases: ORDER COMPLETED, ORDER PROCESSING
    if (code == 'success') {
      final status = orderData?['status']?.toString() ?? '';
      final isCompleted =
          status == 'completed-api' || message.contains('COMPLETED');
      final isProcessing =
          status == 'processing-api' || message.contains('PROCESSING');

      if (isCompleted || isProcessing) {
        return VtuApiResponse(
          success: true,
          message: message,
          transactionId: orderData?['order_id']?.toString(),
          requestId: orderData?['request_id']?.toString(),
          status: status,
          phone: orderData?['phone']?.toString(),
          amount: double.tryParse(orderData?['amount']?.toString() ?? '0'),
          amountCharged: double.tryParse(
            orderData?['amount_charged']?.toString() ?? '0',
          ),
          discount: double.tryParse(orderData?['discount']?.toString() ?? '0'),
          // Electricity specific
          token: isElectricity ? (orderData?['token']?.toString()) : null,
          units: isElectricity ? (orderData?['units']?.toString()) : null,
        );
      }

      // Order was refunded
      if (status == 'refunded' || message.contains('REFUNDED')) {
        return VtuApiResponse(
          success: false,
          message: 'Order was refunded: $message',
          errorCode: 'refunded',
          transactionId: orderData?['order_id']?.toString(),
        );
      }
    }

    // Error cases
    return _parseErrorResponse(response, data);
  }

  /// Parse error response with detailed error codes
  static VtuApiResponse _parseErrorResponse(
    http.Response response,
    Map<String, dynamic> data,
  ) {
    final code = data['code']?.toString() ?? 'unknown';
    final message = data['message']?.toString() ?? 'Unknown error';
    final statusCode = response.statusCode;

    // Map error codes to user-friendly messages
    String userMessage = message;
    VtuErrorType errorType = VtuErrorType.unknown;

    switch (code) {
      case 'insufficient_funds':
        userMessage =
            'VTU.ng wallet has insufficient balance. Please contact support.';
        errorType = VtuErrorType.vtuInsufficientFunds;
        break;
      case 'wallet_busy':
        userMessage =
            'VTU.ng is processing another transaction. Please wait and try again.';
        errorType = VtuErrorType.vtuBusy;
        break;
      case 'wallet_error':
        userMessage = 'Unable to access VTU.ng wallet. Please try again later.';
        errorType = VtuErrorType.vtuWalletError;
        break;
      case 'duplicate_request_id':
      case 'duplicate_order':
        userMessage =
            'This order was already processed. Please wait 3 minutes before retrying.';
        errorType = VtuErrorType.duplicateOrder;
        break;
      case 'invalid_service':
      case 'invalid_service_id':
        userMessage = 'Invalid network or service provider selected.';
        errorType = VtuErrorType.invalidService;
        break;
      case 'invalid_variation_id':
        userMessage = 'Selected data plan is no longer available.';
        errorType = VtuErrorType.invalidVariation;
        break;
      case 'below_minimum_amount':
        userMessage = 'Amount is below the minimum allowed.';
        errorType = VtuErrorType.belowMinimum;
        break;
      case 'above_maximum_amount':
        userMessage = 'Amount is above the maximum allowed.';
        errorType = VtuErrorType.aboveMaximum;
        break;
      case 'rest_forbidden':
      case 'jwt_auth_invalid_token':
      case 'jwt_auth_failed':
        userMessage = 'Authentication failed. Please try again.';
        errorType = VtuErrorType.authFailed;
        // Clear cached token to force refresh
        _cachedToken = null;
        _tokenExpiry = null;
        break;
      case 'rate_limit_exceeded':
        userMessage = 'Too many requests. Please wait a moment and try again.';
        errorType = VtuErrorType.rateLimited;
        break;
      case 'product_unavailable':
        userMessage =
            'This service is temporarily unavailable. Please try again later.';
        errorType = VtuErrorType.serviceUnavailable;
        break;
      case 'failure':
        // Verification failure
        userMessage =
            'Verification failed. Please check the details and try again.';
        errorType = VtuErrorType.verificationFailed;
        break;
      case 'network_error':
        userMessage =
            'Network connection error. Please check your internet connection.';
        errorType = VtuErrorType.networkError;
        break;
    }

    // HTTP status code based errors
    if (statusCode == 500 || statusCode == 502 || statusCode == 503) {
      userMessage =
          'VTU.ng service is temporarily unavailable. Please try again later.';
      errorType = VtuErrorType.serviceUnavailable;
    }

    return VtuApiResponse(
      success: false,
      message: userMessage,
      errorCode: code,
      errorType: errorType,
      statusCode: statusCode,
    );
  }

  /// Clear stored token (for logout or error recovery)
  static Future<void> clearToken() async {
    _cachedToken = null;
    _tokenExpiry = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_tokenExpiryKey);
    } catch (e) {
      debugPrint('⚠️ Failed to clear token: $e');
    }
  }
}

// ==================== MODELS ====================

/// Error types for VTU API
enum VtuErrorType {
  unknown,
  networkError,
  authFailed,
  vtuInsufficientFunds,
  vtuBusy,
  vtuWalletError,
  duplicateOrder,
  invalidService,
  invalidVariation,
  belowMinimum,
  aboveMaximum,
  rateLimited,
  serviceUnavailable,
  verificationFailed,
}

/// VTU API Exception
class VtuApiException implements Exception {
  final String code;
  final String message;
  final int? statusCode;
  final VtuErrorType errorType;

  VtuApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.errorType = VtuErrorType.unknown,
  });

  @override
  String toString() => 'VtuApiException: [$code] $message';
}

/// Response from VTU.ng API v2
class VtuApiResponse {
  final bool success;
  final String message;
  final String? transactionId;
  final String? requestId;
  final String? errorCode;
  final VtuErrorType? errorType;
  final int? statusCode;
  final String? status;
  final String? phone;
  final double? amount;
  final double? amountCharged;
  final double? discount;
  final String? token; // For electricity
  final String? units; // For electricity

  const VtuApiResponse({
    required this.success,
    required this.message,
    this.transactionId,
    this.requestId,
    this.errorCode,
    this.errorType,
    this.statusCode,
    this.status,
    this.phone,
    this.amount,
    this.amountCharged,
    this.discount,
    this.token,
    this.units,
  });

  /// Check if error is recoverable (user can retry)
  bool get isRecoverable {
    return errorType == VtuErrorType.networkError ||
        errorType == VtuErrorType.vtuBusy ||
        errorType == VtuErrorType.rateLimited ||
        errorType == VtuErrorType.authFailed;
  }

  /// Check if error is due to VTU.ng liquidity issues
  bool get isVtuLiquidityIssue {
    return errorType == VtuErrorType.vtuInsufficientFunds ||
        errorType == VtuErrorType.vtuWalletError;
  }
}

/// VTU.ng wallet balance info
class VtuBalanceInfo {
  final double balance;
  final String currency;

  const VtuBalanceInfo({required this.balance, required this.currency});

  bool get hasLowBalance => balance < 5000; // Less than ₦5,000
}

/// Data plan from VTU.ng API v2
class VtuDataPlan {
  final String variationId;
  final String name;
  final double price; // Customer price (retail)
  final double resellerPrice; // Reseller price (our cost)
  final String networkCode;
  final String serviceName;
  final bool isAvailable;

  const VtuDataPlan({
    required this.variationId,
    required this.name,
    required this.price,
    required this.resellerPrice,
    required this.networkCode,
    this.serviceName = '',
    this.isAvailable = true,
  });

  /// Profit margin per transaction
  double get profitMargin => price - resellerPrice;

  /// Convert to local DataPlan model
  DataPlan toDataPlan(NetworkProvider network) {
    return DataPlan(
      id: variationId,
      network: network,
      name: name,
      description: name,
      priceNaira: resellerPrice, // Use reseller price for customer
      retailPrice: price, // Keep retail for reference
      validity: _extractValidity(name),
      dataAmount: _extractDataAmount(name),
      serviceName: serviceName, // e.g., "MTN SME", "MTN Gifting"
    );
  }

  String _extractValidity(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('1 day') ||
        lower.contains('daily') ||
        lower.contains('- 1 '))
      return '1 day';
    if (lower.contains('2 day')) return '2 days';
    if (lower.contains('3 day')) return '3 days';
    if (lower.contains('7 day') ||
        lower.contains('weekly') ||
        lower.contains('1 week'))
      return '7 days';
    if (lower.contains('14 day') || lower.contains('2 week')) return '14 days';
    if (lower.contains('30 day') ||
        lower.contains('monthly') ||
        lower.contains('1 month'))
      return '30 days';
    if (lower.contains('60 day') || lower.contains('2 month')) return '60 days';
    if (lower.contains('90 day') || lower.contains('3 month')) return '90 days';
    if (lower.contains('sunday')) return 'Sunday';
    return '30 days';
  }

  String _extractDataAmount(String name) {
    final regex = RegExp(r'(\d+(?:\.\d+)?)\s*(MB|GB|TB)', caseSensitive: false);
    final match = regex.firstMatch(name);
    if (match != null) {
      return '${match.group(1)}${match.group(2)!.toUpperCase()}';
    }
    return name;
  }
}

/// Meter verification info (API v2)
class VtuMeterInfo {
  final String customerName;
  final String meterNumber;
  final String address;
  final double minAmount;
  final double maxAmount;
  final double arrears;
  final bool isValid;

  const VtuMeterInfo({
    required this.customerName,
    required this.meterNumber,
    required this.address,
    this.minAmount = 1000,
    this.maxAmount = 100000,
    this.arrears = 0,
    required this.isValid,
  });
}

/// Cable TV plan from VTU.ng API v2
class VtuCableTvPlan {
  final String variationId;
  final String name;
  final double price; // Customer price (retail)
  final double resellerPrice; // Reseller price (our cost)
  final String providerCode; // dstv, gotv, startimes
  final String serviceName;
  final bool isAvailable;

  const VtuCableTvPlan({
    required this.variationId,
    required this.name,
    required this.price,
    required this.resellerPrice,
    required this.providerCode,
    this.serviceName = '',
    this.isAvailable = true,
  });

  /// Profit margin per transaction
  double get profitMargin => price - resellerPrice;

  /// Get display price (use reseller price for customer)
  double get displayPrice => resellerPrice;

  /// Extract validity/duration from plan name
  String get validity {
    final lower = name.toLowerCase();
    if (lower.contains('weekly') || lower.contains('1 week')) return '7 days';
    if (lower.contains('monthly') ||
        lower.contains('1 month') ||
        lower.contains('30 day'))
      return '30 days';
    if (lower.contains('3 month') || lower.contains('quarterly'))
      return '90 days';
    if (lower.contains('6 month')) return '180 days';
    if (lower.contains('annual') || lower.contains('12 month'))
      return '365 days';
    return '30 days'; // Default to monthly
  }
}

/// Cable TV customer verification info (API v2)
class VtuCableTvCustomerInfo {
  final String customerName;
  final String smartcardNumber;
  final String currentBouquet;
  final String dueDate;
  final bool isValid;

  const VtuCableTvCustomerInfo({
    required this.customerName,
    required this.smartcardNumber,
    this.currentBouquet = '',
    this.dueDate = '',
    required this.isValid,
  });
}
