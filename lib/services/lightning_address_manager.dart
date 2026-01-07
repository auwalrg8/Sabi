// lib/services/lightning_address_manager.dart
// Centralized Lightning Address management service
// Handles auto-registration, editing, and syncing with Nostr profile

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'profile_service.dart';

/// Centralized manager for Lightning Address operations.
/// Handles auto-generation, registration, and persistence.
class LightningAddressManager {
  static const _storage = FlutterSecureStorage();
  static const _lightningAddressKey = 'registered_lightning_address';
  static const _lightningUsernameKey = 'registered_lightning_username';
  
  /// Default domain for Sabi wallet lightning addresses
  static const String domain = 'sabiwallet.xyz';
  
  // Word lists for generating memorable usernames
  static const List<String> _adjectives = [
    'happy', 'swift', 'bold', 'wise', 'brave', 'cool', 'smart', 'quick',
    'bright', 'calm', 'eager', 'fair', 'grand', 'keen', 'noble', 'proud',
    'rapid', 'sharp', 'warm', 'vivid', 'lucky', 'great', 'super', 'mega',
    'ultra', 'prime', 'alpha', 'epic', 'royal', 'sonic', 'turbo', 'vital',
  ];
  
  static const List<String> _nouns = [
    'lion', 'eagle', 'tiger', 'falcon', 'wolf', 'panda', 'phoenix', 'dragon',
    'bear', 'hawk', 'fox', 'owl', 'shark', 'whale', 'cobra', 'panther',
    'jaguar', 'leopard', 'raven', 'viper', 'storm', 'blaze', 'frost', 'spark',
    'flash', 'thunder', 'rocket', 'comet', 'titan', 'ninja', 'samurai', 'knight',
  ];

  /// Generate a random memorable username.
  /// Format: adjective + noun + 2-4 digits (e.g., swiftfalcon42)
  static String generateRandomUsername() {
    final random = Random();
    final adjective = _adjectives[random.nextInt(_adjectives.length)];
    final noun = _nouns[random.nextInt(_nouns.length)];
    final number = random.nextInt(9000) + 1000; // 1000-9999
    
    return '$adjective$noun$number';
  }
  
  /// Generate alternative usernames if the first one is taken.
  /// Returns a list of 5 alternative options.
  static List<String> generateAlternativeUsernames(String baseUsername) {
    final random = Random();
    final alternatives = <String>[];
    
    for (int i = 0; i < 5; i++) {
      final suffix = random.nextInt(9000) + 1000;
      // Try with different number suffix
      alternatives.add('${baseUsername.replaceAll(RegExp(r'\d+$'), '')}$suffix');
    }
    
    // Also add completely new usernames
    for (int i = 0; i < 3; i++) {
      alternatives.add(generateRandomUsername());
    }
    
    return alternatives;
  }

  /// Format a username into a full lightning address.
  static String formatAddress(String username) {
    return '$username@$domain';
  }
  
  /// Validate username format.
  /// Returns null if valid, error message if invalid.
  static String? validateUsername(String username) {
    if (username.isEmpty) {
      return 'Username cannot be empty';
    }
    if (username.length < 3) {
      return 'Username must be at least 3 characters';
    }
    if (username.length > 30) {
      return 'Username must be less than 30 characters';
    }
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(username.toLowerCase())) {
      return 'Only letters, numbers, and underscores allowed';
    }
    return null; // Valid
  }
  
  /// Save registered lightning address to secure storage.
  static Future<void> saveRegisteredAddress({
    required String username,
    required String fullAddress,
  }) async {
    await _storage.write(key: _lightningUsernameKey, value: username);
    await _storage.write(key: _lightningAddressKey, value: fullAddress);
    debugPrint('💾 Lightning address saved: $fullAddress');
  }
  
  /// Get the stored lightning address.
  static Future<String?> getStoredAddress() async {
    return await _storage.read(key: _lightningAddressKey);
  }
  
  /// Get the stored username.
  static Future<String?> getStoredUsername() async {
    return await _storage.read(key: _lightningUsernameKey);
  }
  
  /// Check if user has a registered lightning address.
  static Future<bool> hasRegisteredAddress() async {
    final address = await getStoredAddress();
    return address != null && address.isNotEmpty;
  }
  
  /// Clear stored lightning address (for account reset).
  static Future<void> clearStoredAddress() async {
    await _storage.delete(key: _lightningAddressKey);
    await _storage.delete(key: _lightningUsernameKey);
    debugPrint('🗑️ Lightning address cleared from storage');
  }
  
  /// Sync lightning address to local profile.
  static Future<void> syncToLocalProfile(StoredLightningAddress address) async {
    await ProfileService.updateLightningAddress(address);
    debugPrint('🔄 Lightning address synced to local profile');
  }
}
