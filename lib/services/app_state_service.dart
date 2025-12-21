// lib/services/app_state_service.dart
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Manages app-wide state persistence for user session and wallet status
class AppStateService {
  static const _boxName = 'app_state';
  static late Box _box;
  static bool _isInitialized = false;

  /// Initialize the app state service
  static Future<void> init() async {
    if (_isInitialized) return;

    // Hive.initFlutter() is now called globally in main() to avoid race conditions
    _box = await Hive.openBox(_boxName);
    _isInitialized = true;
    debugPrint('✅ AppStateService initialized');
  }

  /// Check if this is a first-time user (never created/restored a wallet)
  static bool get isFirstTimeUser {
    return !_box.get('has_wallet', defaultValue: false);
  }

  /// Mark that user has created or restored a wallet
  static Future<void> markWalletCreated() async {
    await _box.put('has_wallet', true);
    await _box.put('wallet_created_at', DateTime.now().toIso8601String());
    debugPrint('✅ Wallet creation state saved');
  }

  /// Check if user has a wallet (created or restored)
  static bool get hasWallet {
    return _box.get('has_wallet', defaultValue: false);
  }

  /// Save last app state (for resuming)
  static Future<void> saveLastScreen(String screenRoute) async {
    await _box.put('last_screen', screenRoute);
  }

  /// Get last screen user was on
  static String? get lastScreen {
    return _box.get('last_screen') as String?;
  }

  /// Clear all app state (for logout/wallet switch)
  static Future<void> clearState() async {
    await _box.clear();
    debugPrint('🗑️ App state cleared');
  }

  /// Get wallet creation timestamp
  static DateTime? get walletCreatedAt {
    final timestamp = _box.get('wallet_created_at') as String?;
    if (timestamp == null) return null;
    return DateTime.parse(timestamp);
  }

  /// Save user session data
  static Future<void> saveSessionData(Map<String, dynamic> data) async {
    await _box.put('session_data', data);
  }

  /// Get user session data
  static Map<String, dynamic>? get sessionData {
    return _box.get('session_data') as Map<String, dynamic>?;
  }

  /// Check if app has been opened before
  static bool get hasOpenedBefore {
    return _box.get('has_opened_before', defaultValue: false);
  }

  /// Mark app as opened
  static Future<void> markAppOpened() async {
    await _box.put('has_opened_before', true);
    await _box.put('last_opened_at', DateTime.now().toIso8601String());
  }
}
