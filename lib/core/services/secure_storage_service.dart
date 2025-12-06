import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Provider for SecureStorageService
final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

/// Service for secure storage operations using flutter_secure_storage
///
/// This service provides a type-safe wrapper around flutter_secure_storage
/// with common operations for storing sensitive data like:
/// - Authentication tokens
/// - Private keys
/// - User credentials
/// - Wallet seeds/mnemonics
///
/// Usage:
/// ```dart
/// final storage = ref.read(secureStorageServiceProvider);
///
/// // Write
/// await storage.write(key: 'auth_token', value: 'token123');
///
/// // Read
/// final token = await storage.read(key: 'auth_token');
///
/// // Delete
/// await storage.delete(key: 'auth_token');
///
/// // Clear all
/// await storage.deleteAll();
/// ```
class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  // ==================== Common Storage Keys ====================

  /// Authentication token key
  static const String keyAuthToken = 'auth_token';

  /// Refresh token key
  static const String keyRefreshToken = 'refresh_token';

  /// User ID key
  static const String keyUserId = 'user_id';

  /// Wallet mnemonic/seed phrase key
  static const String keyWalletSeed = 'wallet_seed';

  /// Private key
  static const String keyPrivateKey = 'private_key';

  /// Nostr private key (nsec)
  static const String keyNostrPrivateKey = 'nostr_private_key';

  /// Nostr public key (npub)
  static const String keyNostrPublicKey = 'nostr_public_key';

  /// Backup status key (e.g., 'skipped', 'seed', 'social')
  static const String keyBackupStatus = 'backup_status';

  /// PIN code key
  static const String keyPinCode = 'pin_code';

  /// Biometric enabled flag
  static const String keyBiometricEnabled = 'biometric_enabled';

  /// Greenlight device key
  static const String keyGreenlightDeviceKey = 'greenlight_device_key';

  /// Greenlight device cert
  static const String keyGreenlightDeviceCert = 'greenlight_device_cert';

  /// First payment confetti flags
  static const String keyFirstPaymentConfettiShown = 'first_payment_confetti_shown';
  static const String keyFirstPaymentConfettiPending = 'first_payment_confetti_pending';

  // ==================== Core Operations ====================

  /// Write a value to secure storage
  Future<void> write({required String key, required String value}) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      throw SecureStorageException('Failed to write to secure storage: $e');
    }
  }

  /// Read a value from secure storage
  /// Returns null if key doesn't exist
  Future<String?> read({required String key}) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      throw SecureStorageException('Failed to read from secure storage: $e');
    }
  }

  /// Delete a specific key from secure storage
  Future<void> delete({required String key}) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      throw SecureStorageException('Failed to delete from secure storage: $e');
    }
  }

  /// Delete all keys from secure storage
  Future<void> deleteAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      throw SecureStorageException('Failed to clear secure storage: $e');
    }
  }

  /// Check if a key exists in secure storage
  Future<bool> containsKey({required String key}) async {
    try {
      return await _storage.containsKey(key: key);
    } catch (e) {
      throw SecureStorageException('Failed to check key existence: $e');
    }
  }

  /// Get all keys from secure storage
  Future<Map<String, String>> readAll() async {
    try {
      return await _storage.readAll();
    } catch (e) {
      throw SecureStorageException(
        'Failed to read all from secure storage: $e',
      );
    }
  }

  // ==================== Convenience Methods ====================

  /// Save authentication tokens
  Future<void> saveAuthTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    await write(key: keyAuthToken, value: accessToken);
    if (refreshToken != null) {
      await write(key: keyRefreshToken, value: refreshToken);
    }
  }

  /// Get authentication token
  Future<String?> getAuthToken() async {
    return await read(key: keyAuthToken);
  }

  /// Get refresh token
  Future<String?> getRefreshToken() async {
    return await read(key: keyRefreshToken);
  }

  /// Clear authentication tokens
  Future<void> clearAuthTokens() async {
    await delete(key: keyAuthToken);
    await delete(key: keyRefreshToken);
  }

  /// Save wallet seed/mnemonic phrase
  Future<void> saveWalletSeed(String seed) async {
    await write(key: keyWalletSeed, value: seed);
  }

  /// Save mnemonic (alias for saveWalletSeed)
  Future<void> saveMnemonic(String mnemonic) async {
    await saveWalletSeed(mnemonic);
  }

  /// Get wallet seed/mnemonic phrase
  Future<String?> getWalletSeed() async {
    return await read(key: keyWalletSeed);
  }

  /// Get mnemonic (alias for getWalletSeed)
  Future<String?> getMnemonic() async {
    return await getWalletSeed();
  }

  /// Delete wallet seed
  Future<void> deleteWalletSeed() async {
    await delete(key: keyWalletSeed);
  }

  /// Save Nostr keys
  Future<void> saveNostrKeys({
    required String privateKey,
    required String publicKey,
  }) async {
    await write(key: keyNostrPrivateKey, value: privateKey);
    await write(key: keyNostrPublicKey, value: publicKey);
  }

  /// Get Nostr private key
  Future<String?> getNostrPrivateKey() async {
    return await read(key: keyNostrPrivateKey);
  }

  /// Get Nostr public key
  Future<String?> getNostrPublicKey() async {
    return await read(key: keyNostrPublicKey);
  }

  /// Delete Nostr keys
  Future<void> deleteNostrKeys() async {
    await delete(key: keyNostrPrivateKey);
    await delete(key: keyNostrPublicKey);
  }

  /// Save PIN code
  Future<void> savePinCode(String pin) async {
    await write(key: keyPinCode, value: pin);
  }

  /// Get PIN code
  Future<String?> getPinCode() async {
    return await read(key: keyPinCode);
  }

  /// Verify PIN code
  Future<bool> verifyPinCode(String pin) async {
    final storedPin = await getPinCode();
    return storedPin == pin;
  }

  /// Delete PIN code
  Future<void> deletePinCode() async {
    await delete(key: keyPinCode);
  }

  /// Enable/disable biometric authentication
  Future<void> setBiometricEnabled(bool enabled) async {
    await write(key: keyBiometricEnabled, value: enabled.toString());
  }

  /// Check if biometric authentication is enabled
  Future<bool> isBiometricEnabled() async {
    final value = await read(key: keyBiometricEnabled);
    return value == 'true';
  }

  /// Save user ID
  Future<void> saveUserId(String userId) async {
    await write(key: keyUserId, value: userId);
  }

  /// Get user ID
  Future<String?> getUserId() async {
    return await read(key: keyUserId);
  }

  /// Save backup status (e.g., 'skipped', 'seed', 'social')
  Future<void> saveBackupStatus(String status) async {
    await write(key: keyBackupStatus, value: status);
  }

  /// Get backup status. Returns null when not set.
  Future<String?> getBackupStatus() async {
    return await read(key: keyBackupStatus);
  }

  /// Clear all user data (logout)
  Future<void> clearUserData() async {
    await clearAuthTokens();
    await delete(key: keyUserId);
    // Note: Wallet seed and keys are NOT deleted on logout for safety
  }

  /// Complete wipe (use with caution!)
  /// This deletes EVERYTHING including wallet seeds and private keys
  Future<void> completeWipe() async {
    await deleteAll();
  }

  /// Mark confetti as pending (to be shown on next home load)
  Future<void> setFirstPaymentConfettiPending(bool pending) async {
    await write(key: keyFirstPaymentConfettiPending, value: pending ? 'true' : 'false');
  }

  /// Check if confetti is pending
  Future<bool> isFirstPaymentConfettiPending() async {
    final v = await read(key: keyFirstPaymentConfettiPending);
    return v == 'true';
  }

  /// Mark confetti as shown
  Future<void> setFirstPaymentConfettiShown() async {
    await write(key: keyFirstPaymentConfettiShown, value: 'true');
    await write(key: keyFirstPaymentConfettiPending, value: 'false');
  }

  /// Has confetti been shown already?
  Future<bool> hasFirstPaymentConfettiShown() async {
    final v = await read(key: keyFirstPaymentConfettiShown);
    return v == 'true';
  }

  /// Save Greenlight credentials
  /// Note: Commented out as breez_sdk is no longer a frontend dependency.
  /// Greenlight management is handled by the backend.
  // Future<void> saveGreenlightCredentials(GreenlightCredentials credentials) async {
  //   await write(key: keyGreenlightDeviceKey, value: base64Encode(credentials.deviceKey));
  //   await write(key: keyGreenlightDeviceCert, value: base64Encode(credentials.deviceCert));
  // }

  /// Get Greenlight credentials
  /// Note: Commented out as breez_sdk is no longer a frontend dependency.
  /// Greenlight management is handled by the backend.
  // Future<GreenlightCredentials?> getGreenlightCredentials() async {
  //   final deviceKeyBase64 = await read(key: keyGreenlightDeviceKey);
  //   final deviceCertBase64 = await read(key: keyGreenlightDeviceCert);
  //
  //   if (deviceKeyBase64 != null && deviceCertBase64 != null) {
  //     return GreenlightCredentials(
  //       deviceKey: base64Decode(deviceKeyBase64),
  //       deviceCert: base64Decode(deviceCertBase64),
  //     );
  //   }
  //   return null;
  // }
}

/// Custom exception for secure storage errors
class SecureStorageException implements Exception {
  final String message;

  SecureStorageException(this.message);

  @override
  String toString() => 'SecureStorageException: $message';
}

