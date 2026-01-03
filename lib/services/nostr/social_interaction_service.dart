import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:nostr_dart/nostr_dart.dart';
import 'package:bech32/bech32.dart';
import 'relay_pool_manager.dart';
import 'nostr_profile_service.dart';

/// Service for handling Nostr social interactions
/// - NIP-25 Reactions (likes)
/// - NIP-10 Replies (threading)
/// - Kind 6 Reposts
/// - Engagement data fetching
class SocialInteractionService {
  static final SocialInteractionService _instance =
      SocialInteractionService._internal();
  factory SocialInteractionService() => _instance;
  SocialInteractionService._internal();

  final RelayPoolManager _relayPool = RelayPoolManager();
  final NostrProfileService _profileService = NostrProfileService();

  // Cache for engagement counts
  final Map<String, EngagementData> _engagementCache = {};

  /// Get cached engagement data for an event
  EngagementData? getCachedEngagement(String eventId) =>
      _engagementCache[eventId];

  /// Create a NIP-25 reaction (like) for an event
  /// Returns true if successful
  Future<bool> likeEvent({
    required String eventId,
    required String eventPubkey,
    String reaction = '+',
  }) async {
    final pubkey = _profileService.currentPubkey;
    if (pubkey == null) {
      throw Exception('No Nostr identity - please set up your keys first');
    }

    debugPrint('❤️ Liking event: $eventId');

    try {
      // Ensure relay pool is initialized
      if (!_relayPool.isInitialized) {
        await _relayPool.init();
      }

      final nsec = await _profileService.getNsec();
      if (nsec == null) {
        throw Exception('No private key available');
      }

      final hexPrivKey = _nsecToHex(nsec);
      if (hexPrivKey == null) {
        throw Exception('Invalid private key');
      }

      // NIP-25: Reaction event (kind 7)
      final tags = [
        ['e', eventId],
        ['p', eventPubkey],
      ];

      final nostr = Nostr(privateKey: hexPrivKey);
      final event = Event(pubkey, 7, tags, reaction);
      nostr.sendEvent(event);

      final eventJson = {
        'id': event.id,
        'pubkey': pubkey,
        'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'kind': 7,
        'tags': tags,
        'content': reaction,
        'sig': event.sig,
      };

      final successCount = await _relayPool.publish(eventJson);

      if (successCount > 0) {
        debugPrint('✅ Liked event successfully ($successCount relays)');
        return true;
      }

      debugPrint('❌ Failed to publish like');
      return false;
    } catch (e) {
      debugPrint('❌ Error liking event: $e');
      return false;
    }
  }

  /// Unlike an event (by publishing a NIP-09 deletion of the reaction)
  Future<bool> unlikeEvent({required String reactionEventId}) async {
    final pubkey = _profileService.currentPubkey;
    if (pubkey == null) return false;

    try {
      // Ensure relay pool is initialized
      if (!_relayPool.isInitialized) {
        await _relayPool.init();
      }

      final nsec = await _profileService.getNsec();
      if (nsec == null) return false;

      final hexPrivKey = _nsecToHex(nsec);
      if (hexPrivKey == null) return false;

      // NIP-09: Event deletion (kind 5)
      final tags = [
        ['e', reactionEventId],
      ];

      final nostr = Nostr(privateKey: hexPrivKey);
      final event = Event(pubkey, 5, tags, 'Unliked');
      nostr.sendEvent(event);

      final eventJson = {
        'id': event.id,
        'pubkey': pubkey,
        'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'kind': 5,
        'tags': tags,
        'content': 'Unliked',
        'sig': event.sig,
      };

      final successCount = await _relayPool.publish(eventJson);
      return successCount > 0;
    } catch (e) {
      debugPrint('❌ Error unliking event: $e');
      return false;
    }
  }

  /// Create a repost (kind 6) for an event
  Future<bool> repostEvent({
    required String eventId,
    required String eventPubkey,
    required String eventContent,
    List<String>? relayHints,
  }) async {
    final pubkey = _profileService.currentPubkey;
    if (pubkey == null) {
      throw Exception('No Nostr identity');
    }

    debugPrint('🔄 Reposting event: $eventId');

    try {
      // Ensure relay pool is initialized
      if (!_relayPool.isInitialized) {
        await _relayPool.init();
      }

      final nsec = await _profileService.getNsec();
      if (nsec == null) {
        throw Exception('No private key available');
      }

      final hexPrivKey = _nsecToHex(nsec);
      if (hexPrivKey == null) {
        throw Exception('Invalid private key');
      }

      // Kind 6: Repost
      final relayHint =
          relayHints?.isNotEmpty == true
              ? relayHints!.first
              : 'wss://relay.damus.io';

      final tags = [
        ['e', eventId, relayHint],
        ['p', eventPubkey],
      ];

      final nostr = Nostr(privateKey: hexPrivKey);
      final event = Event(pubkey, 6, tags, eventContent);
      nostr.sendEvent(event);

      final eventJson = {
        'id': event.id,
        'pubkey': pubkey,
        'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'kind': 6,
        'tags': tags,
        'content': eventContent,
        'sig': event.sig,
      };

      final successCount = await _relayPool.publish(eventJson);

      if (successCount > 0) {
        debugPrint('✅ Reposted successfully ($successCount relays)');
        return true;
      }

      debugPrint('❌ Failed to repost');
      return false;
    } catch (e) {
      debugPrint('❌ Error reposting: $e');
      return false;
    }
  }

  /// Create a reply to an event using NIP-10 threading
  Future<String?> replyToEvent({
    required String eventId,
    required String eventPubkey,
    required String content,
    String? rootEventId,
    String? rootEventPubkey,
  }) async {
    final pubkey = _profileService.currentPubkey;
    if (pubkey == null) {
      throw Exception('No Nostr identity');
    }

    debugPrint('💬 Replying to event: $eventId');

    try {
      // Ensure relay pool is initialized
      if (!_relayPool.isInitialized) {
        await _relayPool.init();
      }

      final nsec = await _profileService.getNsec();
      if (nsec == null) {
        throw Exception('No private key available');
      }

      final hexPrivKey = _nsecToHex(nsec);
      if (hexPrivKey == null) {
        throw Exception('Invalid private key');
      }

      // NIP-10: Threading markers
      final tags = <List<String>>[];

      // If this is a reply to a reply, include root
      if (rootEventId != null && rootEventId != eventId) {
        tags.add(['e', rootEventId, '', 'root']);
        tags.add(['e', eventId, '', 'reply']);
        if (rootEventPubkey != null) {
          tags.add(['p', rootEventPubkey]);
        }
      } else {
        // Direct reply to root
        tags.add(['e', eventId, '', 'root']);
      }

      tags.add(['p', eventPubkey]);

      final nostr = Nostr(privateKey: hexPrivKey);
      final event = Event(pubkey, 1, tags, content);
      nostr.sendEvent(event);

      final eventJson = {
        'id': event.id,
        'pubkey': pubkey,
        'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'kind': 1,
        'tags': tags,
        'content': content,
        'sig': event.sig,
      };

      final successCount = await _relayPool.publish(eventJson);

      if (successCount > 0) {
        debugPrint('✅ Reply sent successfully ($successCount relays)');
        return event.id;
      }

      debugPrint('❌ Failed to send reply');
      return null;
    } catch (e) {
      debugPrint('❌ Error sending reply: $e');
      return null;
    }
  }

  /// Fetch engagement data for an event (likes, reposts, replies, zaps)
  Future<EngagementData> fetchEngagement(String eventId) async {
    debugPrint('📊 Fetching engagement for: ${eventId.substring(0, 8)}...');

    // Check cache first
    if (_engagementCache.containsKey(eventId)) {
      final cached = _engagementCache[eventId]!;
      // If cached less than 30 seconds ago, use it
      if (DateTime.now().difference(cached.fetchedAt).inSeconds < 30) {
        return cached;
      }
    }

    int likeCount = 0;
    int repostCount = 0;
    int replyCount = 0;
    int zapCount = 0;
    int zapTotal = 0;
    bool userLiked = false;
    bool userReposted = false;

    final userPubkey = _profileService.currentPubkey;

    try {
      // Fetch reactions (kind 7)
      final reactions = await _relayPool.fetch(
        filter: {
          'kinds': [7],
          '#e': [eventId],
          'limit': 100,
        },
        timeoutSeconds: 5,
        maxEvents: 100,
      );

      // Count likes (+ or ❤️)
      for (final reaction in reactions) {
        final content = reaction.content;
        if (content == '+' ||
            content == '❤️' ||
            content == '🤙' ||
            content.isEmpty) {
          likeCount++;
          if (reaction.pubkey == userPubkey) {
            userLiked = true;
          }
        }
      }

      // Fetch reposts (kind 6)
      final reposts = await _relayPool.fetch(
        filter: {
          'kinds': [6],
          '#e': [eventId],
          'limit': 50,
        },
        timeoutSeconds: 3,
        maxEvents: 50,
      );

      repostCount = reposts.length;
      if (userPubkey != null) {
        userReposted = reposts.any((r) => r.pubkey == userPubkey);
      }

      // Fetch replies (kind 1 with #e tag)
      final replies = await _relayPool.fetch(
        filter: {
          'kinds': [1],
          '#e': [eventId],
          'limit': 50,
        },
        timeoutSeconds: 3,
        maxEvents: 50,
      );

      replyCount = replies.length;

      // Fetch zaps (kind 9735)
      final zaps = await _relayPool.fetch(
        filter: {
          'kinds': [9735],
          '#e': [eventId],
          'limit': 50,
        },
        timeoutSeconds: 3,
        maxEvents: 50,
      );

      zapCount = zaps.length;
      // Parse zap amounts from bolt11 in content or description tag
      for (final zap in zaps) {
        // Simple heuristic - parse amount from tags
        for (final tag in zap.tags) {
          if (tag.isNotEmpty && tag[0] == 'amount' && tag.length > 1) {
            final msats = int.tryParse(tag[1]);
            if (msats != null) {
              zapTotal += msats ~/ 1000; // Convert msats to sats
            }
          }
        }
      }

      debugPrint(
        '📊 Engagement: $likeCount likes, $repostCount reposts, $replyCount replies, $zapCount zaps ($zapTotal sats)',
      );
    } catch (e) {
      debugPrint('⚠️ Error fetching engagement: $e');
    }

    final data = EngagementData(
      eventId: eventId,
      likeCount: likeCount,
      repostCount: repostCount,
      replyCount: replyCount,
      zapCount: zapCount,
      zapTotalSats: zapTotal,
      userLiked: userLiked,
      userReposted: userReposted,
      fetchedAt: DateTime.now(),
    );

    _engagementCache[eventId] = data;
    return data;
  }

  /// Batch fetch engagement for multiple events
  Future<Map<String, EngagementData>> fetchBatchEngagement(
    List<String> eventIds,
  ) async {
    final results = <String, EngagementData>{};

    // Process in batches of 5 to avoid overwhelming relays
    for (var i = 0; i < eventIds.length; i += 5) {
      final batch = eventIds.skip(i).take(5).toList();
      final futures = batch.map((id) => fetchEngagement(id));
      final batchResults = await Future.wait(futures);

      for (var j = 0; j < batch.length; j++) {
        results[batch[j]] = batchResults[j];
      }
    }

    return results;
  }

  /// Generate a nostr: URI for an event (for sharing)
  String getShareUri(String eventId) {
    // Convert hex event ID to nevent bech32
    // For simplicity, just return nostr: prefix with event ID
    return 'nostr:$eventId';
  }

  /// Generate web link for sharing
  String getWebLink(String eventId) {
    // Use popular web clients
    return 'https://primal.net/e/$eventId';
  }

  // Helper: Convert nsec to hex
  String? _nsecToHex(String nsec) {
    try {
      if (!nsec.startsWith('nsec1')) return null;

      final decoded = bech32Decode(nsec);
      if (decoded == null) return null;

      final data = _convertBits(decoded.data, 5, 8, false);
      if (data == null) return null;

      return data.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    } catch (e) {
      return null;
    }
  }

  Bech32? bech32Decode(String str) {
    try {
      final codec = Bech32Codec();
      return codec.decode(str);
    } catch (e) {
      return null;
    }
  }

  List<int>? _convertBits(List<int> data, int fromBits, int toBits, bool pad) {
    var acc = 0;
    var bits = 0;
    final result = <int>[];
    final maxv = (1 << toBits) - 1;

    for (final value in data) {
      if (value < 0 || (value >> fromBits) != 0) {
        return null;
      }
      acc = (acc << fromBits) | value;
      bits += fromBits;
      while (bits >= toBits) {
        bits -= toBits;
        result.add((acc >> bits) & maxv);
      }
    }

    if (pad) {
      if (bits > 0) {
        result.add((acc << (toBits - bits)) & maxv);
      }
    } else if (bits >= fromBits || ((acc << (toBits - bits)) & maxv) != 0) {
      return null;
    }

    return result;
  }
}

/// Data class for engagement counts
class EngagementData {
  final String eventId;
  final int likeCount;
  final int repostCount;
  final int replyCount;
  final int zapCount;
  final int zapTotalSats;
  final bool userLiked;
  final bool userReposted;
  final DateTime fetchedAt;

  const EngagementData({
    required this.eventId,
    required this.likeCount,
    required this.repostCount,
    required this.replyCount,
    required this.zapCount,
    required this.zapTotalSats,
    required this.userLiked,
    required this.userReposted,
    required this.fetchedAt,
  });

  @override
  String toString() =>
      'EngagementData(likes: $likeCount, reposts: $repostCount, replies: $replyCount, zaps: $zapCount/$zapTotalSats sats)';
}
