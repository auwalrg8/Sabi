import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:math';

import '../core/constants/lightning_address.dart';

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
}

class UserProfile {
  final String fullName;
  final String username;
  final String? profilePicturePath;
  final StoredLightningAddress? lightningAddress;

  UserProfile({
    required this.fullName,
    required this.username,
    this.profilePicturePath,
    this.lightningAddress,
  });

  String get initial => fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U';
  String get lightningUsername => formatLightningAddress(username);
  String get sabiUsername => lightningAddress?.address ?? lightningUsername;
  bool get hasLightningAddress => lightningAddress != null;
  String get lightningAddressDescription =>
      lightningAddress?.description ?? 'Receive sats directly via $lightningUsername';

  Map<String, dynamic> toMap() => {
    'fullName': fullName,
    'username': username,
    'profilePicturePath': profilePicturePath,
    'lightningAddress': lightningAddress?.toMap(),
  };

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
    fullName: map['fullName'] as String,
    username: map['username'] as String,
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
  }) {
    return UserProfile(
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      profilePicturePath: profilePicturePath ?? this.profilePicturePath,
      lightningAddress: lightningAddress ?? this.lightningAddress,
    );
  }
}

class ProfileService {
  static const _profileBox = 'user_profile';
  static const _profileKey = 'current_user';
  static late Box _box;

  static Future<void> init() async {
    try {
      _box = await Hive.openBox(_profileBox);
      debugPrint('✅ Profile service initialized');

      // Generate random profile for new users
      if (!_box.containsKey(_profileKey)) {
        final randomProfile = _generateRandomProfile();
        await saveProfile(randomProfile);
        debugPrint('✅ Generated random profile for new user');
      }
    } catch (e) {
      debugPrint('❌ Profile service init error: $e');
    }
  }

  /// Generate a random profile for new users
  static UserProfile _generateRandomProfile() {
    final random = Random();
    final adjectives = [
      'Happy',
      'Lucky',
      'Swift',
      'Bold',
      'Wise',
      'Brave',
      'Cool',
      'Smart',
      'Quick',
      'Bright',
    ];
    final nouns = [
      'Lion',
      'Eagle',
      'Tiger',
      'Falcon',
      'Wolf',
      'Panda',
      'Phoenix',
      'Dragon',
      'Bear',
      'Hawk',
    ];
    final numbers = random.nextInt(9999);

    final adjective = adjectives[random.nextInt(adjectives.length)];
    final noun = nouns[random.nextInt(nouns.length)];

    return UserProfile(
      fullName: '$adjective $noun',
      username: '${adjective.toLowerCase()}${noun.toLowerCase()}$numbers',
    );
  }

  /// Get current user profile
  static Future<UserProfile> getProfile() async {
    try {
      final data = _box.get(_profileKey) as Map?;
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

  /// Save user profile
  static Future<void> saveProfile(UserProfile profile) async {
    try {
      await _box.put(_profileKey, profile.toMap());
      debugPrint('✅ Profile saved: ${profile.fullName}');
    } catch (e) {
      debugPrint('❌ Save profile error: $e');
    }
  }

  /// Update profile picture path
  static Future<void> updateProfilePicture(String path) async {
    try {
      final currentProfile = await getProfile();
      final updatedProfile = currentProfile.copyWith(profilePicturePath: path);
      await saveProfile(updatedProfile);
      debugPrint('✅ Profile picture updated');
    } catch (e) {
      debugPrint('❌ Update profile picture error: $e');
    }
  }

  /// Update profile name and username
  static Future<void> updateProfile({
    required String fullName,
    required String username,
  }) async {
    try {
      final currentProfile = await getProfile();
      final updatedProfile = currentProfile.copyWith(
        fullName: fullName,
        username: username,
        lightningAddress: currentProfile.lightningAddress,
      );
      await saveProfile(updatedProfile);
      debugPrint('✅ Profile updated');
    } catch (e) {
      debugPrint('❌ Update profile error: $e');
    }
  }

  static Future<void> updateLightningAddress(
    StoredLightningAddress? lightningAddress,
  ) async {
    try {
      final currentProfile = await getProfile();
      final updatedProfile = currentProfile.copyWith(
        lightningAddress: lightningAddress,
      );
      await saveProfile(updatedProfile);
      debugPrint('✅ Lightning address updated');
    } catch (e) {
      debugPrint('❌ Update lightning address error: $e');
    }
  }

  /// Check if username is available (for future use)
  static Future<bool> isUsernameAvailable(String username) async {
    // For now, just check if it's not empty and valid format
    if (username.isEmpty) return false;
    if (username.length < 3) return false;
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) return false;
    return true;
  }
}
