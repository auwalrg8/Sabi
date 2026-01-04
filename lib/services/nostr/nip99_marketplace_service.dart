import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:nostr_dart/nostr_dart.dart';
import 'package:bech32/bech32.dart';
import 'models/models.dart';
import 'relay_pool_manager.dart';
import 'nostr_profile_service.dart';

/// NIP-99 Marketplace Service for P2P Offers
/// Uses kind 30402 (Classified Listing) for interoperability
class NIP99MarketplaceService {
  static final NIP99MarketplaceService _instance =
      NIP99MarketplaceService._internal();
  factory NIP99MarketplaceService() => _instance;
  NIP99MarketplaceService._internal();

  static const int classifiedListingKind = 30402;

  final RelayPoolManager _relayPool = RelayPoolManager();
  final NostrProfileService _profileService = NostrProfileService();

  // Cache of known offers
  final Map<String, NostrP2POffer> _offersCache = {};

  /// Publish a P2P offer as NIP-99 classified listing
  Future<String?> publishOffer(NostrP2POffer offer) async {
    final pubkey = _profileService.currentPubkey;
    if (pubkey == null) {
      throw Exception(
        'No Nostr identity - please set up your Nostr keys first',
      );
    }

    // Ensure relay pool is initialized
    if (!_relayPool.isInitialized) {
      debugPrint('📡 Initializing relay pool for publishing offer...');
      await _relayPool.init();
    }

    debugPrint('📢 Publishing P2P offer: ${offer.title}');

    try {
      // Get nsec for signing
      final nsec = await _profileService.getNsec();
      if (nsec == null) {
        throw Exception('No private key available');
      }

      final hexPrivKey = _nsecToHex(nsec);
      if (hexPrivKey == null) {
        throw Exception('Invalid private key');
      }

      // Build NIP-99 tags
      final tags = offer.toNip99Tags();

      // Create Nostr instance for signing and sending
      final nostr = Nostr(privateKey: hexPrivKey);

      // Create signed event
      final event = Event(
        pubkey,
        classifiedListingKind,
        tags,
        offer.description,
      );

      // Send via nostr_dart (signs automatically)
      nostr.sendEvent(event);

      final eventJson = {
        'id': event.id,
        'pubkey': pubkey,
        'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'kind': classifiedListingKind,
        'tags': tags,
        'content': offer.description,
        'sig': event.sig,
      };

      // Publish to relays
      final successCount = await _relayPool.publish(eventJson);

      if (successCount > 0) {
        debugPrint('✅ Offer published to $successCount relays');

        // Cache the offer
        _offersCache[offer.id] = offer;

        return event.id;
      }

      debugPrint('❌ Failed to publish offer');
      return null;
    } catch (e) {
      debugPrint('❌ Error publishing offer: $e');
      rethrow;
    }
  }

  /// Update an existing offer
  Future<bool> updateOffer(NostrP2POffer offer) async {
    // Publishing with same 'd' tag replaces the old event
    final eventId = await publishOffer(offer);
    return eventId != null;
  }

  /// Delete/cancel an offer
  /// NIP-99 uses deletion by publishing empty content or using NIP-09 deletion
  Future<bool> deleteOffer(String offerId) async {
    final pubkey = _profileService.currentPubkey;
    if (pubkey == null) return false;

    debugPrint('🗑️ Deleting offer: $offerId');

    try {
      final nsec = await _profileService.getNsec();
      if (nsec == null) return false;

      final hexPrivKey = _nsecToHex(nsec);
      if (hexPrivKey == null) return false;

      // Find the original event ID
      final offer = _offersCache[offerId];
      if (offer == null) {
        debugPrint('⚠️ Offer not in cache, cannot delete');
        return false;
      }

      // Create NIP-09 deletion event (kind 5)
      final tags = [
        ['e', offer.eventId],
        ['a', '$classifiedListingKind:$pubkey:$offerId'],
      ];

      // ignore: unused_local_variable
      final nostrSigner = Nostr(privateKey: hexPrivKey);
      final event = Event(pubkey, 5, tags, 'Offer cancelled');

      final eventJson = {
        'id': event.id,
        'pubkey': pubkey,
        'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'kind': 5,
        'tags': tags,
        'content': 'Offer cancelled',
        'sig': event.sig,
      };

      final successCount = await _relayPool.publish(eventJson);

      if (successCount > 0) {
        _offersCache.remove(offerId);
        debugPrint('✅ Offer deleted');
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error deleting offer: $e');
      return false;
    }
  }

  /// Fetch P2P offers from relays
  Future<List<NostrP2POffer>> fetchOffers({
    String? location,
    P2POfferType? type,
    String? paymentMethod,
    int limit = 50,
  }) async {
    debugPrint('🔍 Fetching P2P offers...');

    // Ensure relay pool is initialized
    if (!_relayPool.isInitialized) {
      debugPrint('📡 Initializing relay pool for P2P offers...');
      await _relayPool.init();
    }

    // Build filter
    final filter = <String, dynamic>{
      'kinds': [classifiedListingKind],
      'limit': limit,
    };

    // Add tag filters
    final tagFilters = <String>['p2p', 'bitcoin'];
    if (type != null) {
      tagFilters.add(type == P2POfferType.buy ? 'buy' : 'sell');
    }

    // Note: Nostr filtering by multiple tags requires relay support
    // We'll filter client-side for maximum compatibility

    final events = await _relayPool.fetch(
      filter: filter,
      timeoutSeconds: 10,
      maxEvents: limit * 2, // Fetch more for filtering
    );

    debugPrint('📦 Received ${events.length} events');

    // Parse and filter offers
    final offers = <NostrP2POffer>[];
    final seenIds = <String>{};

    for (final event in events) {
      try {
        // Check if it's a P2P offer (has 'p2p' tag)
        final hasP2pTag = event.tags.any(
          (tag) =>
              tag.isNotEmpty &&
              tag[0] == 't' &&
              tag.length > 1 &&
              tag[1] == 'p2p',
        );
        if (!hasP2pTag) continue;

        final offer = NostrP2POffer.fromNip99Event(
          eventId: event.id,
          pubkey: event.pubkey,
          tags: event.tags,
          content: event.content,
          createdAt: event.timestamp,
        );

        // Deduplicate by 'd' tag (offer ID)
        if (seenIds.contains(offer.id)) continue;
        seenIds.add(offer.id);

        // Apply filters
        if (location != null &&
            offer.location?.toLowerCase() != location.toLowerCase()) {
          continue;
        }
        if (type != null && offer.type != type) {
          continue;
        }
        if (paymentMethod != null &&
            !offer.paymentMethods.contains(paymentMethod)) {
          continue;
        }

        offers.add(offer);
        _offersCache[offer.id] = offer;
      } catch (e) {
        debugPrint('⚠️ Failed to parse offer: $e');
      }
    }

    // Sort by creation date (newest first)
    offers.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    debugPrint('✅ Parsed ${offers.length} valid P2P offers');
    return offers.take(limit).toList();
  }

  /// Subscribe to real-time P2P offers
  Stream<NostrP2POffer> subscribeToOffers({
    String? location,
    P2POfferType? type,
  }) {
    final controller = StreamController<NostrP2POffer>();

    // Ensure relay pool is initialized before subscribing
    _ensureInitializedAndSubscribe(controller, location, type);

    return controller.stream;
  }

  Future<void> _ensureInitializedAndSubscribe(
    StreamController<NostrP2POffer> controller,
    String? location,
    P2POfferType? type,
  ) async {
    if (!_relayPool.isInitialized) {
      debugPrint('📡 Initializing relay pool for P2P subscription...');
      await _relayPool.init();
    }

    final filter = {
      'kinds': [classifiedListingKind],
      'since': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };

    // ignore: unused_local_variable
    final subs = _relayPool.subscribe(filter, (event) {
      try {
        // Check if it's a P2P offer
        final hasP2pTag = event.tags.any(
          (tag) =>
              tag.isNotEmpty &&
              tag[0] == 't' &&
              tag.length > 1 &&
              tag[1] == 'p2p',
        );
        if (!hasP2pTag) return;

        final offer = NostrP2POffer.fromNip99Event(
          eventId: event.id,
          pubkey: event.pubkey,
          tags: event.tags,
          content: event.content,
          createdAt: event.timestamp,
        );

        // Apply filters
        if (location != null &&
            offer.location?.toLowerCase() != location.toLowerCase()) {
          return;
        }
        if (type != null && offer.type != type) {
          return;
        }

        _offersCache[offer.id] = offer;
        controller.add(offer);
      } catch (e) {
        debugPrint('⚠️ Failed to parse offer event: $e');
      }
    });

    controller.onCancel = () {
      _relayPool.unsubscribeAll(subs);
    };
  }

  /// Fetch offers by a specific user
  Future<List<NostrP2POffer>> fetchUserOffers(String pubkey) async {
    debugPrint(
      '🔍 Fetching user offers for pubkey: ${pubkey.substring(0, 8)}...',
    );

    // Ensure relay pool is initialized
    if (!_relayPool.isInitialized) {
      debugPrint('📡 Initializing relay pool for user offers...');
      await _relayPool.init();
    }

    debugPrint('📡 Connected relays: ${_relayPool.connectedRelays.length}');

    final events = await _relayPool.fetch(
      filter: {
        'kinds': [classifiedListingKind],
        'authors': [pubkey],
        'limit': 50,
      },
      timeoutSeconds: 10,
      maxEvents: 50,
      earlyComplete: false, // Wait for all relays to respond
    );

    debugPrint('📨 Received ${events.length} events from relays');

    final offers = <NostrP2POffer>[];
    final seenIds = <String>{};
    final seenEventIds = <String>{}; // Track by event ID as backup

    for (final event in events) {
      try {
        // Skip if we've seen this exact event
        if (seenEventIds.contains(event.id)) {
          debugPrint(
            '⏭️ Skipping duplicate event: ${event.id.substring(0, 8)}',
          );
          continue;
        }
        seenEventIds.add(event.id);

        final hasP2pTag = event.tags.any(
          (tag) =>
              tag.isNotEmpty &&
              tag[0] == 't' &&
              tag.length > 1 &&
              tag[1] == 'p2p',
        );
        if (!hasP2pTag) {
          debugPrint('⏭️ Skipping non-P2P event: ${event.id.substring(0, 8)}');
          continue;
        }

        final offer = NostrP2POffer.fromNip99Event(
          eventId: event.id,
          pubkey: event.pubkey,
          tags: event.tags,
          content: event.content,
          createdAt: event.timestamp,
        );

        debugPrint(
          '📦 Parsed offer: id=${offer.id}, title=${offer.title}, eventId=${event.id.substring(0, 8)}',
        );

        // Deduplicate by offer 'd' tag ID
        // For legacy offers with empty 'd' tag, use eventId instead
        final dedupeKey = offer.id.isNotEmpty ? offer.id : event.id;
        if (seenIds.contains(dedupeKey)) {
          debugPrint('⏭️ Skipping duplicate offer by ID: $dedupeKey');
          continue;
        }
        seenIds.add(dedupeKey);

        offers.add(offer);
        debugPrint('✅ Added offer: ${offer.title} (${offer.id})');
      } catch (e) {
        debugPrint('❌ Error parsing offer event: $e');
      }
    }

    debugPrint('📊 Total unique offers found: ${offers.length}');
    offers.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return offers;
  }

  /// Enrich offers with seller profile data
  Future<void> enrichOffersWithProfiles(List<NostrP2POffer> offers) async {
    final pubkeys = offers.map((o) => o.pubkey).toSet().toList();

    for (final pubkey in pubkeys) {
      try {
        final profile = await _profileService.fetchProfile(pubkey);
        if (profile != null) {
          for (final offer in offers.where((o) => o.pubkey == pubkey)) {
            offer.sellerName = profile.displayNameOrFallback;
            offer.sellerAvatar = profile.picture;
            // Note: npub is set in fromNip99Event or from profile.npub
          }
        }
      } catch (e) {
        // Skip if profile fetch fails
      }
    }
  }

  /// Get cached offer by ID
  NostrP2POffer? getCachedOffer(String offerId) => _offersCache[offerId];

  /// Clear offers cache
  void clearCache() => _offersCache.clear();

  // ==================== Utilities ====================

  /// Convert nsec to hex private key
  String? _nsecToHex(String nsec) {
    try {
      if (!nsec.startsWith('nsec1')) return null;

      final decoded = const Bech32Codec().decode(nsec);
      final data = _convertBits(decoded.data, 5, 8, false);
      if (data == null) return null;

      return data.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
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
      if (value < 0 || (value >> fromBits) != 0) return null;
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
