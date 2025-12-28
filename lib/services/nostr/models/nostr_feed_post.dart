import 'nostr_event.dart';
import 'nostr_profile.dart';

/// Nostr Feed Post Model
/// Enriched version of a Kind 1 note for display in feed
class NostrFeedPost {
  final String id;
  final String authorPubkey;
  String authorName;
  String? authorNpub;
  String? authorAvatar;
  String? authorLud16;
  bool authorNip05Verified;
  final String content;
  final DateTime timestamp;
  int zapAmountSats;
  int likeCount;
  int replyCount;
  int repostCount;
  final List<String> hashtags;
  final List<String> mentionedPubkeys;
  final String? replyToEventId;
  final String? relayUrl;
  
  // Parsed content
  List<String>? _imageUrls;
  List<String>? _videoUrls;
  List<String>? _linkUrls;

  NostrFeedPost({
    required this.id,
    required this.authorPubkey,
    this.authorName = 'Anon',
    this.authorNpub,
    this.authorAvatar,
    this.authorLud16,
    this.authorNip05Verified = false,
    required this.content,
    required this.timestamp,
    this.zapAmountSats = 0,
    this.likeCount = 0,
    this.replyCount = 0,
    this.repostCount = 0,
    this.hashtags = const [],
    this.mentionedPubkeys = const [],
    this.replyToEventId,
    this.relayUrl,
  });

  /// Short pubkey for display
  String get shortPubkey {
    if (authorPubkey.length > 16) {
      return '${authorPubkey.substring(0, 8)}...${authorPubkey.substring(authorPubkey.length - 4)}';
    }
    return authorPubkey;
  }

  /// Time ago string
  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo';
    return '${(diff.inDays / 365).floor()}y';
  }

  /// Format zap amount for display
  String get formattedZapAmount {
    if (zapAmountSats >= 1000000) {
      return '${(zapAmountSats / 1000000).toStringAsFixed(1)}M';
    }
    if (zapAmountSats >= 1000) {
      return '${(zapAmountSats / 1000).toStringAsFixed(1)}k';
    }
    return zapAmountSats.toString();
  }

  /// Extract image URLs from content
  List<String> get imageUrls {
    if (_imageUrls != null) return _imageUrls!;
    final regex = RegExp(r'https?://[^\s]+\.(?:jpg|jpeg|png|gif|webp)', caseSensitive: false);
    _imageUrls = regex.allMatches(content).map((m) => m.group(0)!).toList();
    return _imageUrls!;
  }

  /// Extract video URLs from content
  List<String> get videoUrls {
    if (_videoUrls != null) return _videoUrls!;
    final regex = RegExp(r'https?://[^\s]+\.(?:mp4|webm|mov)', caseSensitive: false);
    _videoUrls = regex.allMatches(content).map((m) => m.group(0)!).toList();
    return _videoUrls!;
  }

  /// Extract regular URLs from content
  List<String> get linkUrls {
    if (_linkUrls != null) return _linkUrls!;
    final regex = RegExp(r'https?://[^\s]+');
    final allUrls = regex.allMatches(content).map((m) => m.group(0)!).toList();
    // Filter out image and video URLs
    _linkUrls = allUrls.where((url) {
      final lower = url.toLowerCase();
      return !lower.endsWith('.jpg') &&
          !lower.endsWith('.jpeg') &&
          !lower.endsWith('.png') &&
          !lower.endsWith('.gif') &&
          !lower.endsWith('.webp') &&
          !lower.endsWith('.mp4') &&
          !lower.endsWith('.webm') &&
          !lower.endsWith('.mov');
    }).toList();
    return _linkUrls!;
  }

  /// Content without media URLs (for cleaner display)
  String get cleanContent {
    var clean = content;
    for (final url in [...imageUrls, ...videoUrls]) {
      clean = clean.replaceAll(url, '');
    }
    return clean.trim();
  }

  /// Check if post has media
  bool get hasMedia => imageUrls.isNotEmpty || videoUrls.isNotEmpty;

  /// Create from NostrEvent
  factory NostrFeedPost.fromEvent(NostrEvent event) {
    // Extract hashtags from tags
    final hashtags = <String>[];
    for (final tag in event.tags) {
      if (tag.isNotEmpty && tag[0] == 't' && tag.length > 1) {
        hashtags.add(tag[1]);
      }
    }

    return NostrFeedPost(
      id: event.id,
      authorPubkey: event.pubkey,
      authorName: event.pubkey.length > 8 ? event.pubkey.substring(0, 8) : event.pubkey,
      content: event.content,
      timestamp: event.timestamp,
      hashtags: hashtags,
      mentionedPubkeys: event.mentionedPubkeys,
      replyToEventId: event.replyToEventId,
      relayUrl: event.relayUrl,
    );
  }

  /// Create from raw event JSON
  factory NostrFeedPost.fromRawEvent(Map<String, dynamic> json, {String? relay}) {
    final event = NostrEvent.fromJson(json, relay: relay);
    return NostrFeedPost.fromEvent(event);
  }

  /// Apply profile data to post
  void applyProfile(NostrProfile profile) {
    authorName = profile.displayNameOrFallback;
    authorNpub = profile.npub;
    authorAvatar = profile.picture;
    authorLud16 = profile.lud16;
    authorNip05Verified = profile.nip05 != null;
  }

  /// Convert to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'author_pubkey': authorPubkey,
      'author_name': authorName,
      'author_npub': authorNpub,
      'author_avatar': authorAvatar,
      'author_lud16': authorLud16,
      'author_nip05_verified': authorNip05Verified,
      'content': content,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'zap_amount_sats': zapAmountSats,
      'like_count': likeCount,
      'reply_count': replyCount,
      'repost_count': repostCount,
      'hashtags': hashtags,
      'mentioned_pubkeys': mentionedPubkeys,
      'reply_to_event_id': replyToEventId,
      'relay_url': relayUrl,
    };
  }

  factory NostrFeedPost.fromCacheJson(Map<String, dynamic> json) {
    return NostrFeedPost(
      id: json['id'] as String? ?? '',
      authorPubkey: json['author_pubkey'] as String? ?? '',
      authorName: json['author_name'] as String? ?? 'Anon',
      authorNpub: json['author_npub'] as String?,
      authorAvatar: json['author_avatar'] as String?,
      authorLud16: json['author_lud16'] as String?,
      authorNip05Verified: json['author_nip05_verified'] as bool? ?? false,
      content: json['content'] as String? ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int? ?? 0),
      zapAmountSats: json['zap_amount_sats'] as int? ?? 0,
      likeCount: json['like_count'] as int? ?? 0,
      replyCount: json['reply_count'] as int? ?? 0,
      repostCount: json['repost_count'] as int? ?? 0,
      hashtags: (json['hashtags'] as List<dynamic>?)?.cast<String>() ?? [],
      mentionedPubkeys: (json['mentioned_pubkeys'] as List<dynamic>?)?.cast<String>() ?? [],
      replyToEventId: json['reply_to_event_id'] as String?,
      relayUrl: json['relay_url'] as String?,
    );
  }

  @override
  String toString() => 'NostrFeedPost(id: ${id.substring(0, 8)}..., author: $authorName)';
}
