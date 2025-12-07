import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class BreezConfig {
  // Cloudflare Worker URL (100% safe to commit - key encrypted in Cloudflare)
  static const String _configUrl =
      "https://sabi-breez-config.sabibwallet.workers.dev";
  static const String _cacheKey = 'breez_api_key_cached';
  static const _secureStorage = FlutterSecureStorage();

  /// Enable Regtest network for testing (no API key required)
  /// Set to true for development/testing, false for production
  static const bool useRegtest = false; // Mainnet by default

  // Local override API key (kept in codebase per user instruction)
  // NOTE: Do not commit real secrets publicly. This is for internal builds.
  static const String localOverrideApiKey =
      'MIIBczCCASWgAwIBAgIHPq+GoWjQ1zAFBgMrZXAwEDEOMAwGA1UEAxMFQnJlZXowHhcNMjUxMTI5MTkyMjEyWhcNMzUxMTI3MTkyMjEyWjAvMRQwEgYDVQQKEwtTYWJpIFdhbGxldDEXMBUGA1UEAxMOQXV3YWwgQWJ1YmFrYXIwKjAFBgMrZXADIQDQg/XL3yA8HKIgyimHU/Qbpxy0tvzris1fDUtEs6ldd6N/MH0wDgYDVR0PAQH/BAQDAgWgMAwGA1UdEwEB/wQCMAAwHQYDVR0OBBYEFNo5o+5ea0sNMlW/75VgGJCv2AcJMB8GA1UdIwQYMBaAFN6q1pJW843ndJIW/Ey2ILJrKJhrMB0GA1UdEQQWMBSBEmF1d2Fscmc4QGdtYWlsLmNvbTAFBgMrZXADQQCInVRb1DyioxmjSLOhYLggfLiO1wXyTWRMEh5PhU5a8M0lWteV7hmQvjJr9SN3I+JVutSWGlnu5tgz3bRQJHAN';

  /// Get network type based on useRegtest flag
  static String get networkType => useRegtest ? 'regtest' : 'mainnet';

  /// Fetches Breez API key from Cloudflare Worker with offline caching
  ///
  /// Strategy:
  /// 1. If useRegtest is true, return empty string (no API key needed)
  /// 2. Try to fetch from Cloudflare (online)
  /// 3. Cache successfully fetched key in secure storage
  /// 4. If offline/error, use cached key as fallback
  static Future<String> get apiKey async {
    // If local override is set, use it immediately
    if (localOverrideApiKey.isNotEmpty) {
      debugPrint('🔑 Using local override Breez API key');
      return localOverrideApiKey;
    }

    // Regtest doesn't require API key
    if (useRegtest) {
      debugPrint('🧪 Using Regtest network - no API key required');
      return '';
    }
    try {
      // Attempt online fetch with 5-second timeout
      final res = await http
          .get(Uri.parse(_configUrl))
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        final key = json['breezApiKey'] as String;

        // Cache successfully fetched key
        await _secureStorage.write(key: _cacheKey, value: key);
        debugPrint('✅ Breez API key fetched from Cloudflare');
        return key;
      } else {
        debugPrint('⚠️ Cloudflare returned ${res.statusCode}, using cache');
      }
    } catch (e) {
      debugPrint('⚠️ Network error fetching API key: $e - using cached key');
    }

    // Fallback to cached key
    final cachedKey = await _secureStorage.read(key: _cacheKey);
    if (cachedKey != null && cachedKey.isNotEmpty) {
      debugPrint('📦 Using cached Breez API key (offline mode)');
      return cachedKey;
    }

    throw Exception(
      'No Breez API key available. '
      'Ensure you have internet connection on first app launch.',
    );
  }

  static const String environment = 'production';
  static const String appName = 'Sabi Wallet Naija';
}
