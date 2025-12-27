/// Social Profile Model - Trust-based profile sharing for P2P trades
///
/// Enables optional, consent-based social profile sharing between traders
/// to build trust without requiring KYC.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supported social platforms
enum SocialPlatform {
  x,           // Twitter/X
  facebook,
  nostr,
  telegram,
  whatsapp,
  instagram,
  phone,
  email,
}

/// Extension for platform metadata
extension SocialPlatformX on SocialPlatform {
  String get displayName {
    switch (this) {
      case SocialPlatform.x:
        return 'X (Twitter)';
      case SocialPlatform.facebook:
        return 'Facebook';
      case SocialPlatform.nostr:
        return 'Nostr';
      case SocialPlatform.telegram:
        return 'Telegram';
      case SocialPlatform.whatsapp:
        return 'WhatsApp';
      case SocialPlatform.instagram:
        return 'Instagram';
      case SocialPlatform.phone:
        return 'Phone';
      case SocialPlatform.email:
        return 'Email';
    }
  }

  String get emoji {
    switch (this) {
      case SocialPlatform.x:
        return '𝕏';
      case SocialPlatform.facebook:
        return '📘';
      case SocialPlatform.nostr:
        return '🔮';
      case SocialPlatform.telegram:
        return '✈️';
      case SocialPlatform.whatsapp:
        return '💬';
      case SocialPlatform.instagram:
        return '📷';
      case SocialPlatform.phone:
        return '📞';
      case SocialPlatform.email:
        return '📧';
    }
  }

  String get placeholder {
    switch (this) {
      case SocialPlatform.x:
        return '@username';
      case SocialPlatform.facebook:
        return 'facebook.com/username';
      case SocialPlatform.nostr:
        return 'npub1...';
      case SocialPlatform.telegram:
        return '@username';
      case SocialPlatform.whatsapp:
        return '+234 XXX XXX XXXX';
      case SocialPlatform.instagram:
        return '@username';
      case SocialPlatform.phone:
        return '+234 XXX XXX XXXX';
      case SocialPlatform.email:
        return 'email@example.com';
    }
  }

  String? getProfileUrl(String handle) {
    switch (this) {
      case SocialPlatform.x:
        final clean = handle.replaceFirst('@', '');
        return 'https://x.com/$clean';
      case SocialPlatform.facebook:
        if (handle.startsWith('http')) return handle;
        return 'https://facebook.com/$handle';
      case SocialPlatform.nostr:
        return null; // Handled by nostr clients
      case SocialPlatform.telegram:
        final clean = handle.replaceFirst('@', '');
        return 'https://t.me/$clean';
      case SocialPlatform.whatsapp:
        final clean = handle.replaceAll(RegExp(r'[^\d+]'), '');
        return 'https://wa.me/$clean';
      case SocialPlatform.instagram:
        final clean = handle.replaceFirst('@', '');
        return 'https://instagram.com/$clean';
      case SocialPlatform.phone:
        return 'tel:$handle';
      case SocialPlatform.email:
        return 'mailto:$handle';
    }
  }

  /// Validate handle format
  bool isValidHandle(String handle) {
    if (handle.isEmpty) return false;
    switch (this) {
      case SocialPlatform.x:
      case SocialPlatform.telegram:
      case SocialPlatform.instagram:
        // @username or just username
        return RegExp(r'^@?[a-zA-Z0-9_]{1,30}$').hasMatch(handle);
      case SocialPlatform.facebook:
        // URL or username
        return handle.isNotEmpty;
      case SocialPlatform.nostr:
        // npub format
        return handle.startsWith('npub1') && handle.length >= 60;
      case SocialPlatform.whatsapp:
      case SocialPlatform.phone:
        // Phone number
        return RegExp(r'^\+?[\d\s-]{8,20}$').hasMatch(handle);
      case SocialPlatform.email:
        return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(handle);
    }
  }
}

/// A user's social profile on a specific platform
class SocialProfile {
  final String id;
  final SocialPlatform platform;
  final String handle;
  final bool isVerified;
  final DateTime addedAt;

  const SocialProfile({
    required this.id,
    required this.platform,
    required this.handle,
    this.isVerified = false,
    required this.addedAt,
  });

  String get displayHandle {
    if (platform == SocialPlatform.x ||
        platform == SocialPlatform.telegram ||
        platform == SocialPlatform.instagram) {
      if (!handle.startsWith('@')) return '@$handle';
    }
    return handle;
  }

  String? get profileUrl => platform.getProfileUrl(handle);

  Map<String, dynamic> toJson() => {
    'id': id,
    'platform': platform.name,
    'handle': handle,
    'isVerified': isVerified,
    'addedAt': addedAt.millisecondsSinceEpoch,
  };

  factory SocialProfile.fromJson(Map<String, dynamic> json) {
    return SocialProfile(
      id: json['id'] as String,
      platform: SocialPlatform.values.firstWhere(
        (p) => p.name == json['platform'],
        orElse: () => SocialPlatform.x,
      ),
      handle: json['handle'] as String,
      isVerified: json['isVerified'] as bool? ?? false,
      addedAt: DateTime.fromMillisecondsSinceEpoch(json['addedAt'] as int),
    );
  }

  SocialProfile copyWith({
    String? id,
    SocialPlatform? platform,
    String? handle,
    bool? isVerified,
    DateTime? addedAt,
  }) {
    return SocialProfile(
      id: id ?? this.id,
      platform: platform ?? this.platform,
      handle: handle ?? this.handle,
      isVerified: isVerified ?? this.isVerified,
      addedAt: addedAt ?? this.addedAt,
    );
  }
}

/// Status of a profile share request
enum ProfileShareStatus {
  pending,
  accepted,
  declined,
  expired,
}

/// Type of share consent
enum ShareConsent {
  /// Share my profiles and view theirs
  mutual,
  /// Only view their profiles (don't share mine)
  viewOnly,
  /// Declined to share
  declined,
}

/// A request to share profiles during a trade
class ProfileShareRequest {
  final String id;
  final String tradeId;
  final String requesterId;
  final String requesterName;
  final List<SocialPlatform> offeredPlatforms;
  final ProfileShareStatus status;
  final ShareConsent? response;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final List<SocialProfile>? sharedProfiles;

  const ProfileShareRequest({
    required this.id,
    required this.tradeId,
    required this.requesterId,
    required this.requesterName,
    required this.offeredPlatforms,
    this.status = ProfileShareStatus.pending,
    this.response,
    required this.createdAt,
    this.respondedAt,
    this.sharedProfiles,
  });

  bool get isPending => status == ProfileShareStatus.pending;
  bool get isAccepted => status == ProfileShareStatus.accepted;
  bool get isDeclined => status == ProfileShareStatus.declined;

  Map<String, dynamic> toJson() => {
    'id': id,
    'tradeId': tradeId,
    'requesterId': requesterId,
    'requesterName': requesterName,
    'offeredPlatforms': offeredPlatforms.map((p) => p.name).toList(),
    'status': status.name,
    'response': response?.name,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'respondedAt': respondedAt?.millisecondsSinceEpoch,
    'sharedProfiles': sharedProfiles?.map((p) => p.toJson()).toList(),
  };

  factory ProfileShareRequest.fromJson(Map<String, dynamic> json) {
    return ProfileShareRequest(
      id: json['id'] as String,
      tradeId: json['tradeId'] as String,
      requesterId: json['requesterId'] as String,
      requesterName: json['requesterName'] as String,
      offeredPlatforms: (json['offeredPlatforms'] as List<dynamic>)
          .map((p) => SocialPlatform.values.firstWhere(
                (sp) => sp.name == p,
                orElse: () => SocialPlatform.x,
              ))
          .toList(),
      status: ProfileShareStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => ProfileShareStatus.pending,
      ),
      response: json['response'] != null
          ? ShareConsent.values.firstWhere(
              (c) => c.name == json['response'],
              orElse: () => ShareConsent.declined,
            )
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      respondedAt: json['respondedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['respondedAt'] as int)
          : null,
      sharedProfiles: json['sharedProfiles'] != null
          ? (json['sharedProfiles'] as List<dynamic>)
              .map((p) => SocialProfile.fromJson(Map<String, dynamic>.from(p as Map)))
              .toList()
          : null,
    );
  }

  ProfileShareRequest copyWith({
    String? id,
    String? tradeId,
    String? requesterId,
    String? requesterName,
    List<SocialPlatform>? offeredPlatforms,
    ProfileShareStatus? status,
    ShareConsent? response,
    DateTime? createdAt,
    DateTime? respondedAt,
    List<SocialProfile>? sharedProfiles,
  }) {
    return ProfileShareRequest(
      id: id ?? this.id,
      tradeId: tradeId ?? this.tradeId,
      requesterId: requesterId ?? this.requesterId,
      requesterName: requesterName ?? this.requesterName,
      offeredPlatforms: offeredPlatforms ?? this.offeredPlatforms,
      status: status ?? this.status,
      response: response ?? this.response,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
      sharedProfiles: sharedProfiles ?? this.sharedProfiles,
    );
  }
}

/// Service to manage social profiles locally
class SocialProfileService {
  SocialProfileService._();

  static const _profilesKey = 'user_social_profiles';
  static const _sharingEnabledKey = 'profile_sharing_enabled';
  static List<SocialProfile> _profiles = [];
  static bool _sharingEnabled = true;
  static bool _initialized = false;

  /// Initialize and load profiles from storage
  static Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load profiles
      final raw = prefs.getString(_profilesKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        _profiles = list
            .map((e) => SocialProfile.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      
      // Load sharing preference
      _sharingEnabled = prefs.getBool(_sharingEnabledKey) ?? true;
      
      _initialized = true;
      debugPrint('✅ SocialProfileService initialized with ${_profiles.length} profiles');
    } catch (e) {
      debugPrint('⚠️ Failed to initialize SocialProfileService: $e');
    }
  }

  /// Save profiles to storage
  static Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_profiles.map((p) => p.toJson()).toList());
      await prefs.setString(_profilesKey, json);
    } catch (e) {
      debugPrint('⚠️ Failed to persist social profiles: $e');
    }
  }

  /// Get all user's profiles
  static List<SocialProfile> getProfiles() => List.unmodifiable(_profiles);

  /// Check if sharing is enabled globally
  static bool get isSharingEnabled => _sharingEnabled;

  /// Get number of linked platforms (for public display)
  static int get linkedPlatformsCount => _profiles.length;

  /// Get profile for a specific platform
  static SocialProfile? getProfile(SocialPlatform platform) {
    try {
      return _profiles.firstWhere((p) => p.platform == platform);
    } catch (_) {
      return null;
    }
  }

  /// Add or update a profile
  static Future<void> setProfile(SocialProfile profile) async {
    await init();
    
    // Remove existing profile for this platform
    _profiles.removeWhere((p) => p.platform == profile.platform);
    _profiles.add(profile);
    
    await _persist();
    debugPrint('✅ Added/updated ${profile.platform.displayName} profile');
  }

  /// Remove a profile
  static Future<void> removeProfile(SocialPlatform platform) async {
    await init();
    _profiles.removeWhere((p) => p.platform == platform);
    await _persist();
    debugPrint('✅ Removed ${platform.displayName} profile');
  }

  /// Toggle global sharing preference
  static Future<void> setSharingEnabled(bool enabled) async {
    _sharingEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sharingEnabledKey, enabled);
  }

  /// Get profiles for selected platforms (for sharing)
  static List<SocialProfile> getProfilesForPlatforms(List<SocialPlatform> platforms) {
    return _profiles.where((p) => platforms.contains(p.platform)).toList();
  }

  /// Check if user has any profiles to share
  static bool get hasProfilesToShare => _profiles.isNotEmpty && _sharingEnabled;
}
