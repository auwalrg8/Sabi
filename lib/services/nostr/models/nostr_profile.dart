import 'dart:convert';

/// Nostr Profile Model (Kind 0 metadata)
class NostrProfile {
  final String pubkey;
  final String npub;
  final String? name;
  final String? displayName;
  final String? about;
  final String? picture;
  final String? banner;
  final String? nip05;
  final String? lud16; // Lightning address for zaps
  final String? lud06; // LNURL fallback
  final String? website;
  final int? createdAt;
  
  // Stats (fetched separately)
  int followerCount;
  int followingCount;
  int zapsSentSats;
  int zapsReceivedSats;

  NostrProfile({
    required this.pubkey,
    required this.npub,
    this.name,
    this.displayName,
    this.about,
    this.picture,
    this.banner,
    this.nip05,
    this.lud16,
    this.lud06,
    this.website,
    this.createdAt,
    this.followerCount = 0,
    this.followingCount = 0,
    this.zapsSentSats = 0,
    this.zapsReceivedSats = 0,
  });

  /// Display name with fallbacks
  String get displayNameOrFallback {
    if (displayName != null && displayName!.isNotEmpty) return displayName!;
    if (name != null && name!.isNotEmpty) return name!;
    return npub.length > 12 ? '${npub.substring(0, 12)}...' : npub;
  }

  /// Short npub for display
  String get shortNpub {
    if (npub.length > 16) {
      return '${npub.substring(0, 8)}...${npub.substring(npub.length - 4)}';
    }
    return npub;
  }

  /// Check if profile has lightning address for zaps
  bool get canReceiveZaps => lud16 != null || lud06 != null;

  /// Get lightning address (lud16 preferred)
  String? get lightningAddress => lud16 ?? lud06;

  /// Create from Kind 0 event content
  factory NostrProfile.fromEventContent(String pubkey, String npub, String content, {int? createdAt}) {
    try {
      final json = jsonDecode(content) as Map<String, dynamic>;
      return NostrProfile.fromJson(pubkey, npub, json, createdAt: createdAt);
    } catch (e) {
      return NostrProfile(pubkey: pubkey, npub: npub);
    }
  }

  factory NostrProfile.fromJson(String pubkey, String npub, Map<String, dynamic> json, {int? createdAt}) {
    return NostrProfile(
      pubkey: pubkey,
      npub: npub,
      name: json['name'] as String?,
      displayName: json['display_name'] as String? ?? json['displayName'] as String?,
      about: json['about'] as String?,
      picture: json['picture'] as String?,
      banner: json['banner'] as String?,
      nip05: json['nip05'] as String?,
      lud16: json['lud16'] as String?,
      lud06: json['lud06'] as String?,
      website: json['website'] as String?,
      createdAt: createdAt,
    );
  }

  /// Convert to Kind 0 event content
  Map<String, dynamic> toEventContent() {
    final content = <String, dynamic>{};
    if (name != null) content['name'] = name;
    if (displayName != null) content['display_name'] = displayName;
    if (about != null) content['about'] = about;
    if (picture != null) content['picture'] = picture;
    if (banner != null) content['banner'] = banner;
    if (nip05 != null) content['nip05'] = nip05;
    if (lud16 != null) content['lud16'] = lud16;
    if (lud06 != null) content['lud06'] = lud06;
    if (website != null) content['website'] = website;
    return content;
  }

  /// Convert to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'pubkey': pubkey,
      'npub': npub,
      'name': name,
      'display_name': displayName,
      'about': about,
      'picture': picture,
      'banner': banner,
      'nip05': nip05,
      'lud16': lud16,
      'lud06': lud06,
      'website': website,
      'created_at': createdAt,
      'follower_count': followerCount,
      'following_count': followingCount,
      'zaps_sent_sats': zapsSentSats,
      'zaps_received_sats': zapsReceivedSats,
    };
  }

  factory NostrProfile.fromCacheJson(Map<String, dynamic> json) {
    return NostrProfile(
      pubkey: json['pubkey'] as String? ?? '',
      npub: json['npub'] as String? ?? '',
      name: json['name'] as String?,
      displayName: json['display_name'] as String?,
      about: json['about'] as String?,
      picture: json['picture'] as String?,
      banner: json['banner'] as String?,
      nip05: json['nip05'] as String?,
      lud16: json['lud16'] as String?,
      lud06: json['lud06'] as String?,
      website: json['website'] as String?,
      createdAt: json['created_at'] as int?,
      followerCount: json['follower_count'] as int? ?? 0,
      followingCount: json['following_count'] as int? ?? 0,
      zapsSentSats: json['zaps_sent_sats'] as int? ?? 0,
      zapsReceivedSats: json['zaps_received_sats'] as int? ?? 0,
    );
  }

  NostrProfile copyWith({
    String? name,
    String? displayName,
    String? about,
    String? picture,
    String? banner,
    String? nip05,
    String? lud16,
    String? lud06,
    String? website,
    int? followerCount,
    int? followingCount,
    int? zapsSentSats,
    int? zapsReceivedSats,
  }) {
    return NostrProfile(
      pubkey: pubkey,
      npub: npub,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      about: about ?? this.about,
      picture: picture ?? this.picture,
      banner: banner ?? this.banner,
      nip05: nip05 ?? this.nip05,
      lud16: lud16 ?? this.lud16,
      lud06: lud06 ?? this.lud06,
      website: website ?? this.website,
      createdAt: createdAt,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount ?? this.followingCount,
      zapsSentSats: zapsSentSats ?? this.zapsSentSats,
      zapsReceivedSats: zapsReceivedSats ?? this.zapsReceivedSats,
    );
  }

  @override
  String toString() => 'NostrProfile(npub: $shortNpub, name: $displayNameOrFallback)';
}
