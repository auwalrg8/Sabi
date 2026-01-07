import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/constants/lightning_address.dart';
import 'lightning_address_manager.dart';

/// Represents a registered Lightning Address from Breez SDK.
class StoredLightningAddress {
  final String address;
  final String username;
  final String description;
  final String lnurl;

  const StoredLightningAddress({
    required this.address,
    required this.username,
    required this.description,
    required this.lnurl,
  });

  Map<String, dynamic> toMap() => {
        'address': address,
        'username': username,
        'description': description,
        'lnurl': lnurl,
      };

  static StoredLightningAddress? fromMap(Map? map) {
    if (map == null) return null;
    final casted = Map<String, dynamic>.from(map);
    final address = casted['address'] as String?;
    final username = casted['username'] as String?;
    final description = casted['description'] as String?;
    final lnurl = casted['lnurl'] as String?;
    if (address == null || username == null || description == null || lnurl == null) {
      return null;
    }
    return StoredLightningAddress(
      address: address,
      username: username,
      description: description,
      lnurl: lnurl,
    );
  }
  
  @override
  String toString() => 'StoredLightningAddress($address)';
}

/// User profile model for local storage.
class UserProfile {
  final String fullName;
  final String username;
  final String? profilePicturePath;
  final StoredLightningAddress? lightningAddress;

  const UserProfile({
    required this.fullName,
    required this.username,
    this.profilePicturePath,
    this.lightningAddress,
  });

  /// Get first letter of name for avatar display.
  String get initial => fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U';
  
  /// Get formatted lightning address (fallback to generated one).
  String get lightningUsername => formatLightningAddress(username);
  
  /// Get the actual registered lightning address, or fallback.
  String get sabiUsername => lightningAddress?.address ?? lightningUsername;
  
  /// Check if user has a registered lightning address.
  bool get hasLightningAddress => lightningAddress != null;
  
  /// Get description for lightning address.
  String get lightningAddressDescription =>
      lightningAddress?.description ?? 'Receive sats directly via $lightningUsername';

  Map<String, dynamic> toMap() => {
    'fullName': fullName,
    'username': username,
    'profilePicturePath': profilePicturePath,
    'lightningAddress': lightningAddress?.toMap(),
  };

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
    fullName: map['fullName'] as String? ?? 'Sabi User',
    username: map['username'] as String? ?? 'sabiuser',
    profilePicturePath: map['profilePicturePath'] as String?,
    lightningAddress: StoredLightningAddress.fromMap(
      map['lightningAddress'] as Map?,
    ),
  );

  UserProfile copyWith({
    String? fullName,
    String? username,
    String? profilePicturePath,
    StoredLightningAddress? lightningAddress,
    bool clearLightningAddress = false,
  }) {
    return UserProfile(
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      profilePicturePath: profilePicturePath ?? this.profilePicturePath,
      lightningAddress: clearLightningAddress ? null : (lightningAddress ?? this.lightningAddress),
    );
  }
  
  @override
  String toString() => 'UserProfile($fullName, $username)';
}

/// Service for managing user profile in local storage.
class ProfileService {
  static const _profileBox = 'user_profile';
  static const _profileKey = 'current_user';
  static Box? _box;
  
  /// Check if service is initialized.
  static bool get isInitialized => _box != null && _box!.isOpen;

  /// Initialize the profile service.
  static Future<void> init() async {
    if (isInitialized) return;
    
    try {
      _box = await Hive.openBox(_profileBox);
      debugPrint('✅ ProfileService initialized');

      // Generate random profile for new users
      if (!_box!.containsKey(_profileKey)) {
        final randomProfile = _generateRandomProfile();
        await saveProfile(randomProfile);
        debugPrint('✅ Generated random profile for new user: ${randomProfile.username}');
      }
    } catch (e) {
      debugPrint('❌ ProfileService init error: $e');
      rethrow;
    }
  }

  /// Generate a random profile using LightningAddressManager.
  static UserProfile _generateRandomProfile() {
    final username = LightningAddressManager.generateRandomUsername();
    // Convert username to display name (capitalize first letters)
    final displayName = username
        .replaceAll(RegExp(r'\d+$'), '') // Remove trailing numbers
        .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (m) => '${m[1]} ${m[2]}',
        )
        .split(RegExp(r'(?=[A-Z])'))
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ')
        .trim();
    
    // Fallback display name
    final finalDisplayName = displayName.isNotEmpty ? displayName : 'Sabi User';

    return UserProfile(
      fullName: finalDisplayName,
      username: username,
    );
  }

  /// Get current user profile.
  static Future<UserProfile> getProfile() async {
    if (!isInitialized) {
      await init();
    }
    
    try {
      final data = _box!.get(_profileKey);
      if (data != null) {
        return UserProfile.fromMap(Map<String, dynamic>.from(data));
      }
      // Return default if not found
      return _generateRandomProfile();
    } catch (e) {
      debugPrint('❌ Get profile error: $e');
      return _generateRandomProfile();
    }
  }

  /// Save user profile.
  static Future<void> saveProfile(UserProfile profile) async {
    if (!isInitialized) {
      await init();
    }
    
    try {
      await _box!.put(_profileKey, profile.toMap());
      debugPrint('✅ Profile saved: ${profile.fullName}');
    } catch (e) {
      debugPrint('❌ Save profile error: $e');
      rethrow;
    }
  }

  /// Update profile picture path.
  static Future<void> updateProfilePicture(String path) async {
    final currentProfile = await getProfile();
    final updatedProfile = currentProfile.copyWith(profilePicturePath: path);
    await saveProfile(updatedProfile);
  }

  /// Update profile name and username.
  static Future<void> updateProfile({
    required String fullName,
    required String username,
  }) async {
    final currentProfile = await getProfile();
    final updatedProfile = currentProfile.copyWith(
      fullName: fullName,
      username: username,
    );
    await saveProfile(updatedProfile);
  }

  /// Update lightning address.
  static Future<void> updateLightningAddress(
    StoredLightningAddress? lightningAddress,
  ) async {
    final currentProfile = await getProfile();
    final updatedProfile = lightningAddress == null
        ? currentProfile.copyWith(clearLightningAddress: true)
        : currentProfile.copyWith(lightningAddress: lightningAddress);
    await saveProfile(updatedProfile);
    debugPrint('✅ Lightning address updated: ${lightningAddress?.address ?? "cleared"}');
  }

  /// Validate username format.
  static String? validateUsername(String username) {
    return LightningAddressManager.validateUsername(username);
  }
}
