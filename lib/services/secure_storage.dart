import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SecureStorage {
  static late Box _box;
  static const _boxName = 'sabi_secure';
  static const _hiveEncryptionKeyName = 'sabi_secure_hive_encryption_key';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) {
      return;
    }
    // Hive.initFlutter() is now called globally in main() to avoid race conditions
    // HiveAesCipher requires a 32-byte key. Persist the key in secure storage.
    final key = await _getEncryptionKey();
    _box = await Hive.openBox(
      _boxName,
      encryptionCipher: HiveAesCipher(key),
    );
    _initialized = true;
  }

  /// Get the Hive encryption key, generating and persisting it if needed.
  /// CRITICAL: The key must be stored in secure storage to persist across app restarts.
  static Future<List<int>> _getEncryptionKey() async {
    try {
      // Try to read existing key from secure storage
      final existingKey = await _secureStorage.read(key: _hiveEncryptionKeyName);
      if (existingKey != null && existingKey.isNotEmpty) {
        // Decode the stored key (stored as base64)
        final bytes = base64Decode(existingKey);
        if (bytes.length == 32) {
          return bytes;
        }
      }
      
      // No existing key found - generate a new one
      final newKey = Hive.generateSecureKey();
      
      // Store the key in secure storage for future use
      final keyBase64 = base64Encode(newKey);
      await _secureStorage.write(key: _hiveEncryptionKeyName, value: keyBase64);
      
      return newKey;
    } catch (e) {
      // Fallback to generating a new key (will cause data loss if previous data exists)
      return Hive.generateSecureKey();
    }
  }

  static String? get inviteCode => _box.get('invite_code');
  static String? get nodeId => _box.get('node_id');
  static bool get hasWallet => inviteCode != null;
  static bool get initialChannelOpened => _box.get('initial_channel_opened', defaultValue: false);

  static Future<void> saveWalletData({
    required String inviteCode,
    required String nodeId,
    required bool initialChannelOpened,
  }) async {
    await _box.put('invite_code', inviteCode);
    await _box.put('node_id', nodeId);
    await _box.put('initial_channel_opened', initialChannelOpened);
    await _box.put('has_onboarded', true);
  }

  static Future<void> clearAll() async => _box.clear();
}
