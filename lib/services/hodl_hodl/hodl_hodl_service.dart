import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'models/hodl_hodl_models.dart';

/// Hodl Hodl API Service
/// Implements key API calls for P2P trading integration
class HodlHodlService {
  static const String _baseUrl = 'https://hodlhodl.com/api/v1';
  static const String _apiKeyStorageKey = 'hodl_hodl_api_key';
  static const String _signatureKeyStorageKey = 'hodl_hodl_signature_key';
  
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  
  // Singleton pattern
  static final HodlHodlService _instance = HodlHodlService._internal();
  factory HodlHodlService() => _instance;
  HodlHodlService._internal();

  String? _cachedApiKey;
  String? _cachedSignatureKey;

  /// Get stored API key
  Future<String?> getApiKey() async {
    _cachedApiKey ??= await _secureStorage.read(key: _apiKeyStorageKey);
    return _cachedApiKey;
  }

  /// Store API key securely
  Future<void> setApiKey(String apiKey) async {
    await _secureStorage.write(key: _apiKeyStorageKey, value: apiKey);
    _cachedApiKey = apiKey;
  }

  /// Remove API key
  Future<void> clearApiKey() async {
    await _secureStorage.delete(key: _apiKeyStorageKey);
    _cachedApiKey = null;
  }

  /// Get stored signature key (for signed requests)
  Future<String?> getSignatureKey() async {
    _cachedSignatureKey ??= await _secureStorage.read(key: _signatureKeyStorageKey);
    return _cachedSignatureKey;
  }

  /// Store signature key securely
  Future<void> setSignatureKey(String signatureKey) async {
    await _secureStorage.write(key: _signatureKeyStorageKey, value: signatureKey);
    _cachedSignatureKey = signatureKey;
  }

  /// Check if user has configured API access
  Future<bool> isConfigured() async {
    final apiKey = await getApiKey();
    return apiKey != null && apiKey.isNotEmpty;
  }

  /// Debug method to test API connection and return raw response details
  /// This can be used to diagnose API connection issues
  Future<Map<String, dynamic>> debugApiConnection() async {
    final apiKey = await getApiKey();
    final uri = Uri.parse('$_baseUrl/users/me');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (apiKey != null) 'Authorization': 'Bearer $apiKey',
    };
    
    developer.log('debugApiConnection() - URL: $uri', name: 'HodlHodlService');
    developer.log('debugApiConnection() - Has API key: ${apiKey != null}', name: 'HodlHodlService');
    if (apiKey != null) {
      developer.log('debugApiConnection() - API key length: ${apiKey.length}', name: 'HodlHodlService');
      developer.log('debugApiConnection() - API key preview: ${apiKey.length > 10 ? '${apiKey.substring(0, 5)}...${apiKey.substring(apiKey.length - 5)}' : apiKey}', name: 'HodlHodlService');
    }
    
    try {
      final response = await http.get(uri, headers: headers);
      
      developer.log('debugApiConnection() - Status: ${response.statusCode}', name: 'HodlHodlService');
      developer.log('debugApiConnection() - Headers: ${response.headers}', name: 'HodlHodlService');
      developer.log('debugApiConnection() - Body: ${response.body}', name: 'HodlHodlService');
      
      return {
        'success': response.statusCode >= 200 && response.statusCode < 300,
        'statusCode': response.statusCode,
        'contentType': response.headers['content-type'],
        'bodyPreview': response.body.length > 200 ? '${response.body.substring(0, 200)}...' : response.body,
        'bodyLength': response.body.length,
        'isHtml': response.body.trim().startsWith('<!DOCTYPE') || response.body.trim().startsWith('<html'),
        'apiKeyConfigured': apiKey != null,
        'apiKeyLength': apiKey?.length,
      };
    } catch (e) {
      developer.log('debugApiConnection() - Error: $e', name: 'HodlHodlService');
      return {
        'success': false,
        'error': e.toString(),
        'apiKeyConfigured': apiKey != null,
        'apiKeyLength': apiKey?.length,
      };
    }
  }

  /// Validate an API key by testing it against the HodlHodl API
  /// Returns the user data if valid, throws an exception if invalid
  Future<Map<String, dynamic>> validateApiKey(String apiKey) async {
    final uri = Uri.parse('$_baseUrl/users/me');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };
    
    developer.log('validateApiKey() - URL: $uri', name: 'HodlHodlService');
    developer.log('validateApiKey() - API key length: ${apiKey.length}', name: 'HodlHodlService');
    developer.log('validateApiKey() - API key first 8 chars: ${apiKey.length > 8 ? apiKey.substring(0, 8) : apiKey}...', name: 'HodlHodlService');
    
    final response = await http.get(uri, headers: headers);
    
    developer.log('validateApiKey() - Status: ${response.statusCode}', name: 'HodlHodlService');
    developer.log('validateApiKey() - Content-Type: ${response.headers['content-type']}', name: 'HodlHodlService');
    developer.log('validateApiKey() - Body (first 500): ${response.body.length > 500 ? response.body.substring(0, 500) : response.body}', name: 'HodlHodlService');
    
    // Check for HTML response (invalid key or API not enabled)
    final bodyStr = response.body.trim();
    if (bodyStr.startsWith('<!DOCTYPE') || bodyStr.startsWith('<html') || bodyStr.startsWith('<HTML')) {
      if (response.statusCode == 404) {
        throw HodlHodlApiException(
          'invalid_api_key',
          'Invalid API key or API access not enabled. Go to HodlHodl.com → Account Settings → API Access tab and ensure API access is enabled.',
          response.statusCode,
        );
      }
      throw HodlHodlApiException(
        'authentication_failed',
        'Authentication failed. Please verify your API key and ensure API access is enabled in Account Settings → API Access on HodlHodl.com.',
        response.statusCode,
      );
    }
    
    // Check for non-JSON response
    final contentType = response.headers['content-type'] ?? '';
    if (!contentType.contains('application/json') && bodyStr.isNotEmpty) {
      throw HodlHodlApiException(
        'invalid_response',
        'Server returned an unexpected response. Please try again.',
        response.statusCode,
      );
    }
    
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      
      if (response.statusCode >= 200 && response.statusCode < 300 && body['status'] == 'success') {
        return body['user'] as Map<String, dynamic>;
      }
      
      final errorCode = body['error_code'] ?? 'unknown_error';
      final message = body['message'] ?? 'API key validation failed';
      throw HodlHodlApiException(errorCode, message, response.statusCode);
    } on FormatException {
      throw HodlHodlApiException(
        'parse_error',
        'Failed to validate API key. Server response was invalid.',
        response.statusCode,
      );
    }
  }

  /// Build authorization headers
  Future<Map<String, String>> _getHeaders() async {
    final apiKey = await getApiKey();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (apiKey != null) 'Authorization': 'Bearer $apiKey',
    };
  }

  /// Handle API response
  T _handleResponse<T>(http.Response response, T Function(Map<String, dynamic>) parser) {
    // Debug logging
    developer.log(
      'HodlHodl API Response: ${response.statusCode}',
      name: 'HodlHodlService',
    );
    developer.log(
      'Response body (first 500 chars): ${response.body.length > 500 ? response.body.substring(0, 500) : response.body}',
      name: 'HodlHodlService',
    );
    
    // First check if the response body looks like HTML (server error page)
    final bodyStr = response.body.trim();
    if (bodyStr.startsWith('<!DOCTYPE') || bodyStr.startsWith('<html') || bodyStr.startsWith('<HTML')) {
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw HodlHodlApiException('unauthorized', 'Authentication failed. Please reconnect your HodlHodl account.', response.statusCode);
      } else if (response.statusCode == 404) {
        // 404 with HTML likely means API key is invalid or API access is not enabled
        throw HodlHodlApiException(
          'api_key_invalid',
          'API key is invalid or API access is not enabled. Please check your HodlHodl API settings and ensure API access is enabled.',
          response.statusCode,
        );
      } else if (response.statusCode == 429) {
        throw HodlHodlApiException('rate_limited', 'Too many requests. Please try again later.', response.statusCode);
      } else if (response.statusCode >= 500) {
        throw HodlHodlApiException('server_error', 'HodlHodl server is temporarily unavailable. Please try again later.', response.statusCode);
      }
      throw HodlHodlApiException('invalid_response', 'HodlHodl service returned an unexpected response. Please try again.', response.statusCode);
    }
    
    // Check for non-JSON responses (e.g., HTML error pages)
    final contentType = response.headers['content-type'] ?? '';
    if (!contentType.contains('application/json') && bodyStr.isNotEmpty) {
      if (response.statusCode == 404) {
        throw HodlHodlApiException('not_found', 'Endpoint not found', response.statusCode);
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw HodlHodlApiException('unauthorized', 'Authentication failed. Please reconnect your HodlHodl account.', response.statusCode);
      }
      throw HodlHodlApiException('invalid_response', 'Server returned invalid response', response.statusCode);
    }
    
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (body['status'] == 'success') {
          return parser(body);
        }
      }
      
      final errorCode = body['error_code'] ?? 'unknown_error';
      var message = body['message'] ?? 'An error occurred';
      
      // Handle validation errors with detailed field info
      if (response.statusCode == 422 || errorCode == 'validation_error') {
        final errors = body['errors'];
        if (errors is Map) {
          final errorMessages = <String>[];
          errors.forEach((field, messages) {
            if (messages is List) {
              for (final msg in messages) {
                errorMessages.add('$field: $msg');
              }
            } else {
              errorMessages.add('$field: $messages');
            }
          });
          if (errorMessages.isNotEmpty) {
            message = errorMessages.join('; ');
          }
        }
      }
      
      throw HodlHodlApiException(errorCode, message, response.statusCode);
    } on FormatException {
      throw HodlHodlApiException('parse_error', 'Failed to parse server response', response.statusCode);
    }
  }

  // ============ PUBLIC API ENDPOINTS (No auth required) ============

  /// Fetch offers from the marketplace
  /// Supports filtering by currency, country, payment method, etc.
  Future<List<HodlHodlOffer>> getOffers({
    String? side, // 'buy' or 'sell'
    String? currencyCode, // e.g., 'NGN', 'USD', 'USDT'
    String? country,
    String? paymentMethodId,
    String? paymentMethodName,
    double? amount,
    bool includeGlobal = true,
    bool onlyWorkingNow = false,
    int limit = 50,
    int offset = 0,
  }) async {
    final queryParams = <String, String>{
      'pagination[limit]': limit.toString(),
      'pagination[offset]': offset.toString(),
    };

    if (side != null) queryParams['filters[side]'] = side;
    if (currencyCode != null) queryParams['filters[currency_code]'] = currencyCode;
    if (country != null) queryParams['filters[country]'] = country;
    if (paymentMethodId != null) queryParams['filters[payment_method_id]'] = paymentMethodId;
    if (paymentMethodName != null) queryParams['filters[payment_method_name]'] = paymentMethodName;
    if (amount != null) queryParams['filters[amount]'] = amount.toString();
    queryParams['filters[include_global]'] = includeGlobal.toString();
    queryParams['filters[only_working_now]'] = onlyWorkingNow.toString();

    final uri = Uri.parse('$_baseUrl/offers').replace(queryParameters: queryParams);
    final headers = await _getHeaders();
    
    final response = await http.get(uri, headers: headers);
    
    return _handleResponse(response, (body) {
      final offers = body['offers'] as List<dynamic>? ?? [];
      return offers.map((e) => HodlHodlOffer.fromJson(e)).toList();
    });
  }

  /// Get a specific offer by ID
  Future<HodlHodlOffer> getOffer(String offerId) async {
    final uri = Uri.parse('$_baseUrl/offers/$offerId');
    final headers = await _getHeaders();
    
    final response = await http.get(uri, headers: headers);
    
    return _handleResponse(response, (body) {
      return HodlHodlOffer.fromJson(body['offer']);
    });
  }

  /// Get available currencies
  Future<List<Map<String, dynamic>>> getCurrencies() async {
    final uri = Uri.parse('$_baseUrl/currencies');
    
    final response = await http.get(uri);
    
    return _handleResponse(response, (body) {
      final currencies = body['currencies'] as List<dynamic>? ?? [];
      return currencies.cast<Map<String, dynamic>>();
    });
  }

  /// Get available payment methods
  Future<List<Map<String, dynamic>>> getPaymentMethods({String? country}) async {
    final queryParams = <String, String>{};
    if (country != null) queryParams['filters[country]'] = country;
    
    final uri = Uri.parse('$_baseUrl/payment_methods').replace(queryParameters: queryParams);
    final headers = await _getHeaders();
    
    developer.log('getPaymentMethods() - URL: $uri', name: 'HodlHodlService');
    
    final response = await http.get(uri, headers: headers);
    
    developer.log('getPaymentMethods() - Status: ${response.statusCode}', name: 'HodlHodlService');
    developer.log('getPaymentMethods() - Response (first 1000): ${response.body.length > 1000 ? response.body.substring(0, 1000) : response.body}', name: 'HodlHodlService');
    
    return _handleResponse(response, (body) {
      final methods = body['payment_methods'] as List<dynamic>? ?? [];
      developer.log('getPaymentMethods() - Found ${methods.length} methods', name: 'HodlHodlService');
      if (methods.isNotEmpty) {
        developer.log('getPaymentMethods() - First method: ${methods.first}', name: 'HodlHodlService');
      }
      return methods.cast<Map<String, dynamic>>();
    });
  }

  /// Get available countries
  Future<List<Map<String, dynamic>>> getCountries() async {
    final uri = Uri.parse('$_baseUrl/countries');
    
    final response = await http.get(uri);
    
    return _handleResponse(response, (body) {
      final countries = body['countries'] as List<dynamic>? ?? [];
      return countries.cast<Map<String, dynamic>>();
    });
  }

  // ============ AUTHENTICATED API ENDPOINTS ============

  /// Get current user information
  Future<Map<String, dynamic>> getMe() async {
    final uri = Uri.parse('$_baseUrl/users/me');
    final headers = await _getHeaders();
    
    developer.log('getMe() - URL: $uri', name: 'HodlHodlService');
    developer.log('getMe() - Headers: $headers', name: 'HodlHodlService');
    
    final response = await http.get(uri, headers: headers);
    
    return _handleResponse(response, (body) {
      return body['user'] as Map<String, dynamic>;
    });
  }

  /// Update current user profile
  Future<Map<String, dynamic>> updateMe({
    String? nickname,
    String? description,
    bool? verifiedOnly,
    bool? willSendFirst,
    String? countryCode,
    String? currencyCode,
  }) async {
    final uri = Uri.parse('$_baseUrl/users/me');
    final headers = await _getHeaders();
    
    final userUpdate = <String, dynamic>{};
    if (nickname != null) userUpdate['nickname'] = nickname;
    if (description != null) userUpdate['description'] = description;
    if (verifiedOnly != null) userUpdate['verified_only'] = verifiedOnly;
    if (willSendFirst != null) userUpdate['will_send_first'] = willSendFirst;
    if (countryCode != null) userUpdate['country_code'] = countryCode;
    if (currencyCode != null) userUpdate['currency_code'] = currencyCode;
    
    final body = {'user': userUpdate};
    
    developer.log('updateMe() - URL: $uri', name: 'HodlHodlService');
    developer.log('updateMe() - Body: $body', name: 'HodlHodlService');
    
    final response = await http.patch(
      uri,
      headers: headers,
      body: jsonEncode(body),
    );
    
    return _handleResponse(response, (body) {
      return body['user'] as Map<String, dynamic>;
    });
  }

  /// Create a new contract (accept an offer)
  Future<HodlHodlContract> createContract({
    required String offerId,
    required String offerVersion,
    required String paymentMethodInstructionId,
    required String paymentMethodInstructionVersion,
    double? value, // fiat amount
    double? volume, // BTC amount
    String? comment,
  }) async {
    if (value == null && volume == null) {
      throw ArgumentError('Either value or volume must be provided');
    }

    final uri = Uri.parse('$_baseUrl/contracts');
    final headers = await _getHeaders();
    
    final body = {
      'contract': {
        'offer_id': offerId,
        'offer_version': offerVersion,
        'payment_method_instruction_id': paymentMethodInstructionId,
        'payment_method_instruction_version': paymentMethodInstructionVersion,
        if (value != null) 'value': value,
        if (volume != null) 'volume': volume,
        if (comment != null) 'comment': comment,
      },
    };
    
    developer.log('createContract() - URL: $uri', name: 'HodlHodlService');
    developer.log('createContract() - Body: ${jsonEncode(body)}', name: 'HodlHodlService');
    
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(body),
    );
    
    developer.log('createContract() - Status: ${response.statusCode}', name: 'HodlHodlService');
    developer.log('createContract() - Response: ${response.body}', name: 'HodlHodlService');
    
    return _handleResponse(response, (body) {
      return HodlHodlContract.fromJson(body['contract']);
    });
  }

  /// Get a contract by ID
  Future<HodlHodlContract> getContract(String contractId) async {
    final uri = Uri.parse('$_baseUrl/contracts/$contractId');
    final headers = await _getHeaders();
    
    final response = await http.get(uri, headers: headers);
    
    return _handleResponse(response, (body) {
      return HodlHodlContract.fromJson(body['contract']);
    });
  }

  /// Get all user's contracts
  Future<List<HodlHodlContract>> getMyContracts({
    String? side, // 'buy' or 'sell'
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    final queryParams = <String, String>{
      'pagination[limit]': limit.toString(),
      'pagination[offset]': offset.toString(),
    };

    if (side != null) queryParams['filters[side]'] = side;
    if (status != null) queryParams['filters[status]'] = status;

    final uri = Uri.parse('$_baseUrl/contracts/my').replace(queryParameters: queryParams);
    final headers = await _getHeaders();
    
    final response = await http.get(uri, headers: headers);
    
    return _handleResponse(response, (body) {
      final contracts = body['contracts'] as List<dynamic>? ?? [];
      return contracts.map((e) => HodlHodlContract.fromJson(e)).toList();
    });
  }

  /// Confirm escrow validity
  Future<HodlHodlContract> confirmEscrow(String contractId) async {
    final uri = Uri.parse('$_baseUrl/contracts/$contractId/confirm');
    final headers = await _getHeaders();
    
    developer.log('confirmEscrow() - URL: $uri', name: 'HodlHodlService');
    
    final response = await http.post(uri, headers: headers);
    
    developer.log('confirmEscrow() - Status: ${response.statusCode}', name: 'HodlHodlService');
    developer.log('confirmEscrow() - Response: ${response.body.length > 500 ? response.body.substring(0, 500) : response.body}', name: 'HodlHodlService');
    
    return _handleResponse(response, (body) {
      return HodlHodlContract.fromJson(body['contract']);
    });
  }

  /// Mark contract as paid (buyer action)
  Future<HodlHodlContract> markAsPaid(String contractId) async {
    final uri = Uri.parse('$_baseUrl/contracts/$contractId/mark_as_paid');
    final headers = await _getHeaders();
    
    developer.log('markAsPaid() - URL: $uri', name: 'HodlHodlService');
    
    final response = await http.post(uri, headers: headers);
    
    developer.log('markAsPaid() - Status: ${response.statusCode}', name: 'HodlHodlService');
    developer.log('markAsPaid() - Response: ${response.body.length > 500 ? response.body.substring(0, 500) : response.body}', name: 'HodlHodlService');
    
    return _handleResponse(response, (body) {
      return HodlHodlContract.fromJson(body['contract']);
    });
  }

  /// Cancel a contract
  Future<HodlHodlContract> cancelContract(String contractId) async {
    final uri = Uri.parse('$_baseUrl/contracts/$contractId/cancel');
    final headers = await _getHeaders();
    
    final response = await http.post(uri, headers: headers);
    
    return _handleResponse(response, (body) {
      return HodlHodlContract.fromJson(body['contract']);
    });
  }

  /// Get release transaction (for seller to sign)
  Future<Map<String, dynamic>> getReleaseTransaction(String contractId) async {
    final uri = Uri.parse('$_baseUrl/contracts/$contractId/release_transaction');
    final headers = await _getHeaders();
    
    final response = await http.get(uri, headers: headers);
    
    return _handleResponse(response, (body) {
      return body['transaction'] as Map<String, dynamic>;
    });
  }

  /// Sign and submit release transaction
  /// NOTE: This requires client-side transaction signing which is complex
  /// For the beta, we'll show instructions to complete on hodlhodl.com
  Future<HodlHodlContract> signReleaseTransaction(String contractId, String signedHex) async {
    final uri = Uri.parse('$_baseUrl/contracts/$contractId/release_transaction');
    final headers = await _getHeaders();
    
    final body = {'hex': signedHex};
    
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(body),
    );
    
    return _handleResponse(response, (body) {
      return HodlHodlContract.fromJson(body['contract']);
    });
  }

  /// Get chat messages for a contract
  Future<List<HodlHodlChatMessage>> getChatMessages(String contractId) async {
    final uri = Uri.parse('$_baseUrl/contracts/$contractId/chat_messages');
    final headers = await _getHeaders();
    
    final response = await http.get(uri, headers: headers);
    
    return _handleResponse(response, (body) {
      final messages = body['chat_messages'] as List<dynamic>? ?? [];
      return messages.map((e) => HodlHodlChatMessage.fromJson(e)).toList();
    });
  }

  /// Send a chat message in a contract
  Future<HodlHodlChatMessage> sendChatMessage(String contractId, String message) async {
    final uri = Uri.parse('$_baseUrl/contracts/$contractId/chat_messages');
    final headers = await _getHeaders();
    
    // HodlHodl API expects the message with 'text' parameter
    final body = {
      'chat_message': {
        'text': message,
      }
    };
    
    developer.log('sendChatMessage() - URL: $uri', name: 'HodlHodlService');
    developer.log('sendChatMessage() - contractId: $contractId, body: $body', name: 'HodlHodlService');
    
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(body),
    );
    
    developer.log('sendChatMessage() - Status: ${response.statusCode}', name: 'HodlHodlService');
    developer.log('sendChatMessage() - Response: ${response.body.length > 500 ? response.body.substring(0, 500) : response.body}', name: 'HodlHodlService');
    
    return _handleResponse(response, (body) {
      return HodlHodlChatMessage.fromJson(body['chat_message']);
    });
  }

  /// Start a dispute on a contract
  Future<HodlHodlContract> startDispute(String contractId) async {
    final uri = Uri.parse('$_baseUrl/contracts/$contractId/dispute');
    final headers = await _getHeaders();
    
    developer.log('startDispute() - URL: $uri', name: 'HodlHodlService');
    
    final response = await http.post(uri, headers: headers);
    
    developer.log('startDispute() - Status: ${response.statusCode}', name: 'HodlHodlService');
    developer.log('startDispute() - Response: ${response.body.length > 500 ? response.body.substring(0, 500) : response.body}', name: 'HodlHodlService');
    
    return _handleResponse(response, (body) {
      return HodlHodlContract.fromJson(body['contract']);
    });
  }

  // ============ HELPER METHODS ============

  /// Get offers filtered for Nigerian Naira
  Future<List<HodlHodlOffer>> getNgnOffers({
    String? side,
    String? paymentMethodName,
    double? amount,
  }) async {
    return getOffers(
      side: side,
      currencyCode: 'NGN',
      country: 'Nigeria',
      paymentMethodName: paymentMethodName,
      amount: amount,
      includeGlobal: false,
    );
  }

  /// Get offers filtered for USDT
  Future<List<HodlHodlOffer>> getUsdtOffers({
    String? side,
    String? paymentMethodName,
    double? amount,
  }) async {
    return getOffers(
      side: side,
      currencyCode: 'USDT',
      paymentMethodName: paymentMethodName,
      amount: amount,
    );
  }

  /// Get active contracts (not completed or canceled)
  Future<List<HodlHodlContract>> getActiveContracts() async {
    final all = await getMyContracts();
    return all.where((c) => 
      c.status != 'completed' && 
      c.status != 'canceled' && 
      c.status != 'resolved'
    ).toList();
  }

  // ============ OFFER CREATION API ENDPOINTS ============

  /// Get user's payment instructions
  Future<List<Map<String, dynamic>>> getMyPaymentInstructions() async {
    final uri = Uri.parse('$_baseUrl/payment_method_instructions');
    final headers = await _getHeaders();
    
    final response = await http.get(uri, headers: headers);
    
    return _handleResponse(response, (body) {
      final instructions = body['payment_method_instructions'] as List<dynamic>? ?? [];
      return instructions.cast<Map<String, dynamic>>();
    });
  }

  /// Create a new payment instruction
  Future<Map<String, dynamic>> createPaymentInstruction({
    required String paymentMethodId,
    required String name,
    required String details,
  }) async {
    final uri = Uri.parse('$_baseUrl/payment_method_instructions');
    final headers = await _getHeaders();
    
    // payment_method_id must be an integer per HodlHodl API
    final paymentMethodIdInt = int.tryParse(paymentMethodId);
    
    // Validate that we have a valid payment method ID
    if (paymentMethodIdInt == null || paymentMethodIdInt <= 0) {
      developer.log(
        'createPaymentInstruction() - Invalid payment_method_id: $paymentMethodId (parsed as $paymentMethodIdInt)',
        name: 'HodlHodlService',
      );
      throw HodlHodlApiException(
        'validation',
        'Invalid payment method. Please select a valid payment method from the list.',
        422,
      );
    }
    
    final body = {
      'payment_method_instruction': {
        'payment_method_id': paymentMethodIdInt,
        'name': name,
        'details': details,
      },
    };
    
    developer.log('createPaymentInstruction() - URL: $uri', name: 'HodlHodlService');
    developer.log('createPaymentInstruction() - Body: $body', name: 'HodlHodlService');
    
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(body),
    );
    
    developer.log('createPaymentInstruction() - Status: ${response.statusCode}', name: 'HodlHodlService');
    developer.log('createPaymentInstruction() - Response: ${response.body}', name: 'HodlHodlService');
    
    return _handleResponse(response, (body) {
      return body['payment_method_instruction'] as Map<String, dynamic>;
    });
  }

  /// Get user's offers
  Future<List<HodlHodlOffer>> getMyOffers({
    String? side,
    bool? enabled,
    int limit = 50,
    int offset = 0,
  }) async {
    final queryParams = <String, String>{
      'pagination[limit]': limit.toString(),
      'pagination[offset]': offset.toString(),
    };

    if (side != null) queryParams['filters[side]'] = side;
    if (enabled != null) queryParams['filters[enabled]'] = enabled.toString();

    final uri = Uri.parse('$_baseUrl/offers/my').replace(queryParameters: queryParams);
    final headers = await _getHeaders();
    
    final response = await http.get(uri, headers: headers);
    
    return _handleResponse(response, (body) {
      final offers = body['offers'] as List<dynamic>? ?? [];
      return offers.map((e) => HodlHodlOffer.fromJson(e)).toList();
    });
  }

  /// Create a new offer
  Future<HodlHodlOffer> createOffer({
    required String side, // 'buy' or 'sell'
    required String currencyCode,
    required List<String> paymentMethodInstructionIds,
    String? countryCode,
    String rateSource = 'binance', // 'binance', 'kraken', etc.
    String marginType = 'fixed', // 'fixed' or 'percentage'
    double margin = 0, // Price margin (0 = exchange rate)
    double? minAmount,
    double? maxAmount,
    double? fixedAmount,
    double? firstTradeLimit,
    int paymentWindowMinutes = 90,
    int confirmations = 1,
    String? title,
    String? description,
    bool enabled = true,
    bool isPrivate = false,
    bool is24Hours = true,
    String? workingHoursFrom,
    String? workingHoursTo,
    bool workdaysOnly = false,
  }) async {
    final uri = Uri.parse('$_baseUrl/offers');
    final headers = await _getHeaders();
    
    final offerData = <String, dynamic>{
      'side': side,
      'currency_code': currencyCode,
      'payment_method_instruction_ids': paymentMethodInstructionIds,
      'rate_source': rateSource,
      'margin_type': marginType,
      'margin': margin.toString(),
      'payment_window_minutes': paymentWindowMinutes,
      'confirmations': confirmations,
      'enabled': enabled,
      'private': isPrivate,
    };

    if (countryCode != null) offerData['country_code'] = countryCode;
    if (minAmount != null) offerData['min_amount'] = minAmount.toString();
    if (maxAmount != null) offerData['max_amount'] = maxAmount.toString();
    if (fixedAmount != null) offerData['fixed_amount'] = fixedAmount.toString();
    if (firstTradeLimit != null) offerData['first_trade_limit'] = firstTradeLimit.toString();
    if (title != null) offerData['title'] = title;
    if (description != null) offerData['description'] = description;
    
    // Working hours
    if (is24Hours) {
      offerData['is_24_hours'] = true;
    } else if (workingHoursFrom != null && workingHoursTo != null) {
      offerData['working_hours_from'] = workingHoursFrom;
      offerData['working_hours_to'] = workingHoursTo;
    }
    offerData['workdays_only'] = workdaysOnly;
    
    final body = {'offer': offerData};
    
    developer.log('createOffer() - URL: $uri', name: 'HodlHodlService');
    developer.log('createOffer() - Body: ${jsonEncode(body)}', name: 'HodlHodlService');
    
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(body),
    );
    
    developer.log('createOffer() - Status: ${response.statusCode}', name: 'HodlHodlService');
    developer.log('createOffer() - Response: ${response.body}', name: 'HodlHodlService');
    
    return _handleResponse(response, (body) {
      return HodlHodlOffer.fromJson(body['offer']);
    });
  }

  /// Update an existing offer
  Future<HodlHodlOffer> updateOffer({
    required String offerId,
    String? currencyCode,
    List<String>? paymentMethodInstructionIds,
    String? countryCode,
    String? rateSource,
    String? marginType,
    double? margin,
    double? minAmount,
    double? maxAmount,
    double? fixedAmount,
    int? paymentWindowMinutes,
    int? confirmations,
    String? title,
    String? description,
    bool? enabled,
    bool? isPrivate,
  }) async {
    final uri = Uri.parse('$_baseUrl/offers/$offerId');
    final headers = await _getHeaders();
    
    final offerData = <String, dynamic>{};
    
    if (currencyCode != null) offerData['currency_code'] = currencyCode;
    if (paymentMethodInstructionIds != null) offerData['payment_method_instruction_ids'] = paymentMethodInstructionIds;
    if (countryCode != null) offerData['country_code'] = countryCode;
    if (rateSource != null) offerData['rate_source'] = rateSource;
    if (marginType != null) offerData['margin_type'] = marginType;
    if (margin != null) offerData['margin'] = margin.toString();
    if (minAmount != null) offerData['min_amount'] = minAmount.toString();
    if (maxAmount != null) offerData['max_amount'] = maxAmount.toString();
    if (fixedAmount != null) offerData['fixed_amount'] = fixedAmount.toString();
    if (paymentWindowMinutes != null) offerData['payment_window_minutes'] = paymentWindowMinutes;
    if (confirmations != null) offerData['confirmations'] = confirmations;
    if (title != null) offerData['title'] = title;
    if (description != null) offerData['description'] = description;
    if (enabled != null) offerData['enabled'] = enabled;
    if (isPrivate != null) offerData['private'] = isPrivate;
    
    final body = {'offer': offerData};
    
    final response = await http.patch(
      uri,
      headers: headers,
      body: jsonEncode(body),
    );
    
    return _handleResponse(response, (body) {
      return HodlHodlOffer.fromJson(body['offer']);
    });
  }

  /// Delete an offer
  Future<void> deleteOffer(String offerId) async {
    final uri = Uri.parse('$_baseUrl/offers/$offerId');
    final headers = await _getHeaders();
    
    final response = await http.delete(uri, headers: headers);
    
    _handleResponse(response, (_) => null);
  }

  /// Toggle offer enabled/disabled
  Future<HodlHodlOffer> toggleOfferEnabled(String offerId, bool enabled) async {
    return updateOffer(offerId: offerId, enabled: enabled);
  }
}

/// Custom exception for Hodl Hodl API errors
class HodlHodlApiException implements Exception {
  final String errorCode;
  final String message;
  final int statusCode;

  HodlHodlApiException(this.errorCode, this.message, this.statusCode);

  @override
  String toString() => 'HodlHodlApiException: [$errorCode] $message (HTTP $statusCode)';

  /// Get user-friendly error message
  String get userMessage {
    switch (errorCode) {
      case 'not_found':
        return 'The requested resource was not found.';
      case 'rate_limit_exceeded':
        return 'Too many requests. Please try again later.';
      case 'not_available':
        return 'Service temporarily unavailable. Please try again.';
      case 'validation':
        return message;
      case 'missing_parameter':
        return 'Missing required information.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
}
