import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../nostr/nostr_profile_service.dart';
import '../firebase_notification_service.dart';

/// Push notification API base URL
/// Change this to your deployed Vercel URL after deployment
const String _pushApiBaseUrl = String.fromEnvironment(
  'PUSH_API_URL',
  defaultValue: 'https://vercel-api-one-sigma.vercel.app/api',
);

/// Service for registering FCM tokens with your backend/Nostr profile
/// This enables the server to send push notifications to this device
class FCMTokenRegistrationService {
  static final FCMTokenRegistrationService _instance = FCMTokenRegistrationService._internal();
  factory FCMTokenRegistrationService() => _instance;
  FCMTokenRegistrationService._internal();

  final FirebaseNotificationService _fcmService = FirebaseNotificationService();
  final NostrProfileService _nostrProfile = NostrProfileService();

  static const String _tokenSentKey = 'fcm_token_sent_to_backend';
  static const String _lastTokenKey = 'fcm_last_registered_token';

  /// Register the FCM token with your backend
  /// Call this after user logs in or creates wallet
  Future<void> registerToken() async {
    debugPrint('🔔 FCMTokenRegistrationService.registerToken() called');
    
    try {
      // Wait for FCM token if not immediately available
      String? token = _fcmService.fcmToken;
      if (token == null) {
        debugPrint('🔔 FCM token not ready, waiting up to 5s...');
        for (int i = 0; i < 10; i++) {
          await Future.delayed(const Duration(milliseconds: 500));
          token = _fcmService.fcmToken;
          if (token != null) break;
        }
      }
      
      debugPrint('🔔 FCM token: ${token != null ? "${token.substring(0, 20)}..." : "NULL"}');
      
      if (token == null) {
        debugPrint('⚠️ No FCM token available after waiting');
        return;
      }

      // Check if we already registered this token
      final prefs = await SharedPreferences.getInstance();
      final lastToken = prefs.getString(_lastTokenKey);
      
      if (lastToken == token) {
        debugPrint('ℹ️ FCM token already registered');
        return;
      }

      // Get user's Nostr pubkey for association
      String? pubkey = _nostrProfile.currentPubkey;
      
      // If no pubkey, try initializing NostrProfileService
      if (pubkey == null) {
        debugPrint('🔔 Nostr pubkey not ready, re-initializing...');
        await _nostrProfile.init(force: true);
        pubkey = _nostrProfile.currentPubkey;
      }
      
      debugPrint('🔔 Nostr pubkey: ${pubkey != null ? "${pubkey.substring(0, 16)}..." : "NULL"}');
      
      if (pubkey == null) {
        debugPrint('⚠️ No Nostr pubkey available - user may need to create/import keys');
        return;
      }

      // Send token to Firebase Cloud Functions backend
      final response = await http.post(
        Uri.parse('$_pushApiBaseUrl/register-device'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fcmToken': token,
          'nostrPubkey': pubkey,
          'platform': Platform.isIOS ? 'ios' : 'android',
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ FCM token registered with backend');
        
        // Mark as sent
        await prefs.setString(_lastTokenKey, token);
        await prefs.setBool(_tokenSentKey, true);
        
        // Also store locally for backup
        await _storeTokenLocally(token, pubkey);
        
        debugPrint('✅ FCM token registered for pubkey: ${pubkey.substring(0, 8)}...');
      } else {
        debugPrint('❌ Backend registration failed: ${response.statusCode} - ${response.body}');
        // Still store locally as fallback
        await _storeTokenLocally(token, pubkey);
      }
    } catch (e) {
      debugPrint('❌ Error registering FCM token: $e');
      // Try to store locally as fallback
      try {
        final token = _fcmService.fcmToken;
        final pubkey = _nostrProfile.currentPubkey;
        if (token != null && pubkey != null) {
          await _storeTokenLocally(token, pubkey);
        }
      } catch (_) {}
    }
  }

  /// Store FCM token locally as backup
  Future<void> _storeTokenLocally(String token, String pubkey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceInfo = {
        'fcmToken': token,
        'pubkey': pubkey,
        'registeredAt': DateTime.now().toIso8601String(),
        'platform': Platform.isIOS ? 'ios' : 'android',
      };
      await prefs.setString('device_registration', jsonEncode(deviceInfo));
      debugPrint('📝 Token stored locally');
    } catch (e) {
      debugPrint('❌ Error storing token locally: $e');
    }
  }

  /// Unregister token (on logout)
  Future<void> unregisterToken() async {
    try {
      final token = _fcmService.fcmToken;
      final pubkey = _nostrProfile.currentPubkey;
      
      // Call backend to remove this device's token
      if (token != null) {
        try {
          await http.post(
            Uri.parse('$_pushApiBaseUrl/unregister-device'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'fcmToken': token,
              'nostrPubkey': pubkey,
            }),
          );
          debugPrint('✅ Token unregistered from backend');
        } catch (e) {
          debugPrint('⚠️ Could not unregister from backend: $e');
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenSentKey);
      await prefs.remove(_lastTokenKey);
      await prefs.remove('device_registration');

      // Delete the FCM token itself
      await _fcmService.deleteToken();

      debugPrint('✅ FCM token unregistered');
    } catch (e) {
      debugPrint('❌ Error unregistering FCM token: $e');
    }
  }

  /// Check if token is registered
  Future<bool> isTokenRegistered() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_tokenSentKey) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get the registered device info
  Future<Map<String, dynamic>?> getDeviceRegistration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('device_registration');
      if (json != null) {
        return jsonDecode(json) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting device registration: $e');
      return null;
    }
  }

  /// Force re-register the token (clears cached state)
  Future<void> forceRegisterToken() async {
    debugPrint('🔔 Forcing FCM token re-registration...');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastTokenKey);
      await prefs.remove(_tokenSentKey);
      await registerToken();
    } catch (e) {
      debugPrint('❌ Error forcing token registration: $e');
    }
  }

  /// Debug function to test the registration flow
  Future<Map<String, dynamic>> debugStatus() async {
    final token = _fcmService.fcmToken;
    final pubkey = _nostrProfile.currentPubkey;
    final prefs = await SharedPreferences.getInstance();
    
    return {
      'fcmToken': token != null ? '${token.substring(0, 20)}...' : null,
      'fcmTokenFull': token,
      'nostrPubkey': pubkey,
      'isRegistered': prefs.getBool(_tokenSentKey) ?? false,
      'lastToken': prefs.getString(_lastTokenKey)?.substring(0, 20),
      'apiUrl': _pushApiBaseUrl,
    };
  }
}
