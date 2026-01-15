import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sabi_wallet/core/constants/api_config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => 'ApiException(${statusCode ?? 'unknown'}): $message';
}

/// Simple HTTP client wrapper used across the app.
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();

  final String baseUrl;

  ApiClient._internal([String? base]) : baseUrl = base ?? ApiConfig.baseUrl;

  factory ApiClient() => _instance;

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, String>? headers,
    Object? body,
    int expectedStatus = 200,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final uri = Uri.parse(baseUrl + path);
    final defaultHeaders = <String, String>{'Content-Type': 'application/json'};
    if (headers != null) defaultHeaders.addAll(headers);

    final response = await http
        .post(
          uri,
          headers: defaultHeaders,
          body: body == null ? null : json.encode(body),
        )
        .timeout(timeout);

    final status = response.statusCode;
    if (status == expectedStatus || (expectedStatus == 200 && status == 201)) {
      if (response.body.isEmpty) return <String, dynamic>{};
      return json.decode(response.body) as Map<String, dynamic>;
    }

    // parse error body if available
    try {
      final Map<String, dynamic> err =
          response.body.isNotEmpty
              ? json.decode(response.body) as Map<String, dynamic>
              : {'error': response.reasonPhrase ?? 'Unknown error'};
      final String msg =
          err['error']?.toString() ?? response.reasonPhrase ?? 'Unknown error';
      throw ApiException(msg, status);
    } catch (_) {
      throw ApiException('HTTP $status: ${response.reasonPhrase}', status);
    }
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? headers,
    int expectedStatus = 200,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final uri = Uri.parse(baseUrl + path);
    final defaultHeaders = <String, String>{'Content-Type': 'application/json'};
    if (headers != null) defaultHeaders.addAll(headers);

    final response = await http
        .get(uri, headers: defaultHeaders)
        .timeout(timeout);
    final status = response.statusCode;

    if (status == expectedStatus) {
      if (response.body.isEmpty) return <String, dynamic>{};
      return json.decode(response.body) as Map<String, dynamic>;
    }

    try {
      final Map<String, dynamic> err =
          response.body.isNotEmpty
              ? json.decode(response.body) as Map<String, dynamic>
              : {'error': response.reasonPhrase ?? 'Unknown error'};
      final String msg =
          err['error']?.toString() ?? response.reasonPhrase ?? 'Unknown error';
      throw ApiException(msg, status);
    } catch (_) {
      throw ApiException('HTTP $status: ${response.reasonPhrase}', status);
    }
  }
}
