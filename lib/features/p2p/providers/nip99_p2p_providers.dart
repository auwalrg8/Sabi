import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/services/nostr/nostr_service.dart';
import 'package:sabi_wallet/features/p2p/services/p2p_trade_manager.dart';
import 'package:sabi_wallet/features/p2p/services/p2p_notification_service.dart';
import '../data/p2p_offer_model.dart';
import '../data/merchant_model.dart';

/// Provider for NIP-99 marketplace service
final nip99ServiceProvider = Provider<NIP99MarketplaceService>((ref) {
  return NIP99MarketplaceService();
});

/// Provider for Nostr profile service (for user identity)
final nostrP2PProfileProvider = Provider<NostrProfileService>((ref) {
  return NostrProfileService();
});

/// NIP-99 P2P Offers - Fetched from Nostr relays (kind 30402)
/// This replaces the legacy kind 38383 implementation
final nip99P2POffersProvider = FutureProvider.autoDispose<List<P2POfferModel>>((
  ref,
) async {
  final marketplace = ref.watch(nip99ServiceProvider);

  debugPrint('🔍 NIP99 FutureProvider: Fetching P2P offers...');

  // Fetch offers from relays
  final nostrOffers = await marketplace.fetchOffers(limit: 100);
  debugPrint('📦 NIP99 FutureProvider: Got ${nostrOffers.length} raw offers');

  // Enrich with seller profiles
  await marketplace.enrichOffersWithProfiles(nostrOffers);

  // Convert to P2POfferModel for compatibility with existing UI
  // Filter out expired/cancelled offers (null values)
  final converted =
      nostrOffers
          .map((offer) => _convertToP2POfferModel(offer))
          .whereType<P2POfferModel>()
          .toList();

  debugPrint(
    '✅ NIP99 FutureProvider: Returning ${converted.length} valid offers',
  );
  return converted;
});

/// Stream of real-time NIP-99 offers
final nip99P2POffersStreamProvider = StreamProvider.autoDispose<
  List<P2POfferModel>
>((ref) {
  final marketplace = ref.watch(nip99ServiceProvider);
  final controller = StreamController<List<P2POfferModel>>();
  final offers = <String, P2POfferModel>{};

  // Emit initial empty state immediately so UI doesn't hang
  controller.add([]);

  // First, load existing offers
  marketplace
      .fetchOffers(limit: 100)
      .then((nostrOffers) async {
        debugPrint(
          '📦 NIP99 Provider: Fetched ${nostrOffers.length} offers from relays',
        );
        await marketplace.enrichOffersWithProfiles(nostrOffers);
        for (final offer in nostrOffers) {
          final converted = _convertToP2POfferModel(offer);
          if (converted != null) {
            offers[offer.id] = converted;
          }
        }
        debugPrint(
          '📦 NIP99 Provider: ${offers.length} valid offers after conversion',
        );
        controller.add(offers.values.toList());
      })
      .catchError((e) {
        debugPrint('❌ NIP99 Provider: Error fetching offers: $e');
        controller.addError(e);
      });

  // Then subscribe to real-time updates
  final subscription = marketplace.subscribeToOffers().listen(
    (nostrOffer) {
      final converted = _convertToP2POfferModel(nostrOffer);
      if (converted != null) {
        offers[nostrOffer.id] = converted;
      } else {
        // Remove expired/cancelled offers from cache
        offers.remove(nostrOffer.id);
      }
      controller.add(offers.values.toList());
    },
    onError: (e) {
      debugPrint('❌ NIP99 Provider: Stream error: $e');
    },
  );

  ref.onDispose(() {
    subscription.cancel();
    controller.close();
  });

  return controller.stream;
});

/// Current user's P2P offers (NIP-99)
final userNip99OffersProvider = FutureProvider.autoDispose<List<P2POfferModel>>(
  (ref) async {
    final marketplace = ref.watch(nip99ServiceProvider);
    final profileService = ref.watch(nostrP2PProfileProvider);

    final pubkey = profileService.currentPubkey;
    if (pubkey == null) return [];

    final nostrOffers = await marketplace.fetchUserOffers(pubkey);
    return nostrOffers
        .map((offer) => _convertToP2POfferModel(offer))
        .whereType<P2POfferModel>()
        .toList();
  },
);

/// Notifier for publishing/managing NIP-99 offers
class Nip99OfferNotifier extends StateNotifier<AsyncValue<void>> {
  final NIP99MarketplaceService _marketplace;
  final NostrProfileService _profileService;

  Nip99OfferNotifier(this._marketplace, this._profileService)
    : super(const AsyncValue.data(null));

  /// Publish a new P2P offer
  Future<String?> publishOffer({
    required P2POfferType type,
    required String title,
    required String description,
    required double pricePerBtc,
    required String currency,
    required int minSats,
    required int maxSats,
    required List<String> paymentMethods,
    String? location,
    Map<String, String>? paymentDetails,
  }) async {
    state = const AsyncValue.loading();

    try {
      final pubkey = _profileService.currentPubkey;
      if (pubkey == null) {
        throw Exception('No Nostr identity - please set up your keys first');
      }

      // Generate unique ID for NIP-99 'd' tag (replaceable event identifier)
      final uniqueId =
          'p2p_${DateTime.now().millisecondsSinceEpoch}_${pubkey.substring(0, 8)}';

      final offer = NostrP2POffer(
        id: uniqueId,
        eventId: '', // Will be set after publishing
        pubkey: pubkey,
        type: type,
        title: title,
        description: description,
        pricePerBtc: pricePerBtc,
        currency: currency,
        minAmountSats: minSats,
        maxAmountSats: maxSats,
        paymentMethods: paymentMethods,
        paymentAccountDetails: paymentDetails,
        location: location,
        createdAt: DateTime.now(),
        status: P2POfferStatus.active,
      );

      final eventId = await _marketplace.publishOffer(offer);

      state = const AsyncValue.data(null);
      return eventId;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Update an existing offer
  Future<bool> updateOffer(NostrP2POffer offer) async {
    state = const AsyncValue.loading();

    try {
      final success = await _marketplace.updateOffer(offer);
      state = const AsyncValue.data(null);
      return success;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Delete/cancel an offer
  Future<bool> deleteOffer(String offerId) async {
    state = const AsyncValue.loading();

    try {
      final success = await _marketplace.deleteOffer(offerId);
      state = const AsyncValue.data(null);
      return success;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

/// Provider for offer management
final nip99OfferNotifierProvider =
    StateNotifierProvider<Nip99OfferNotifier, AsyncValue<void>>((ref) {
      final marketplace = ref.watch(nip99ServiceProvider);
      final profileService = ref.watch(nostrP2PProfileProvider);
      return Nip99OfferNotifier(marketplace, profileService);
    });

/// Filter providers for P2P offers
final p2pLocationFilterProvider = StateProvider<String?>((ref) => null);
final p2pTypeFilterProvider = StateProvider<P2POfferType?>((ref) => null);
final p2pPaymentMethodFilterProvider = StateProvider<String?>((ref) => null);

/// Filtered NIP-99 offers based on current filters
final filteredNip99OffersProvider =
    FutureProvider.autoDispose<List<P2POfferModel>>((ref) async {
      final marketplace = ref.watch(nip99ServiceProvider);
      final location = ref.watch(p2pLocationFilterProvider);
      final type = ref.watch(p2pTypeFilterProvider);
      final paymentMethod = ref.watch(p2pPaymentMethodFilterProvider);

      final nostrOffers = await marketplace.fetchOffers(
        location: location,
        type: type,
        paymentMethod: paymentMethod,
        limit: 50,
      );

      await marketplace.enrichOffersWithProfiles(nostrOffers);

      return nostrOffers
          .map((offer) => _convertToP2POfferModel(offer))
          .whereType<P2POfferModel>()
          .toList();
    });

/// Helper to convert NostrP2POffer to P2POfferModel for UI compatibility
/// Returns null if the offer has expired
P2POfferModel? _convertToP2POfferModel(NostrP2POffer offer) {
  // Filter out expired offers
  if (offer.expiresAt != null && offer.expiresAt!.isBefore(DateTime.now())) {
    return null; // Expired offer
  }

  // Filter out cancelled/completed offers
  if (offer.status == P2POfferStatus.cancelled ||
      offer.status == P2POfferStatus.completed) {
    return null;
  }

  return P2POfferModel(
    id: offer.id,
    name: offer.sellerName ?? offer.npub?.substring(0, 12) ?? 'Anonymous',
    pricePerBtc: offer.pricePerBtc,
    paymentMethod:
        offer.paymentMethods.isNotEmpty
            ? offer.paymentMethods.first
            : 'Unknown',
    eta: '< 15 min', // Default ETA
    ratingPercent: 100, // Default rating for new system
    trades: 0, // Will be tracked separately
    minLimit: offer.minAmountSats ?? 0,
    maxLimit: offer.maxAmountSats ?? 0,
    type: offer.type == P2POfferType.buy ? OfferType.buy : OfferType.sell,
    merchant: MerchantModel(
      id: offer.pubkey,
      name: offer.sellerName ?? 'Anonymous',
      trades30d: 0,
      completionRate: 100.0,
      avgReleaseMinutes: 15,
      totalVolume: 0.0,
      joinedDate: offer.createdAt,
      avatarUrl: offer.sellerAvatar,
      isVerified: false,
    ),
    requiresKyc: false,
    paymentInstructions: offer.description,
    paymentAccountDetails: offer.paymentAccountDetails,
    availableSats: (offer.maxAmountSats ?? 0).toDouble(),
  );
}

/// Provider for P2PTradeManager singleton
final p2pTradeManagerProvider = Provider<P2PTradeManager>((ref) {
  return P2PTradeManager();
});

// Note: p2pNotificationServiceProvider is defined in p2p_providers.dart

/// Stats for a specific offer
class OfferStats {
  final int views;
  final int inquiries;
  final int totalTrades;
  final int activeTrades;
  final int completedTrades;

  const OfferStats({
    this.views = 0,
    this.inquiries = 0,
    this.totalTrades = 0,
    this.activeTrades = 0,
    this.completedTrades = 0,
  });
}

/// Provider for offer stats (views, inquiries, trades)
/// Uses p2pNotificationServiceProvider from p2p_providers.dart
/// View tracking uses NIP99MarketplaceService
final offerStatsProvider = Provider.family<OfferStats, String>((ref, offerId) {
  final tradeManager = ref.watch(p2pTradeManagerProvider);
  final notificationService = P2PNotificationService();
  final marketplace = ref.watch(nip99ServiceProvider);

  // Get view count from marketplace service (now with view tracking)
  final viewCount = marketplace.getOfferViewCount(offerId);

  // Get trades for this offer
  final allTradesForOffer = tradeManager.getTradesForOffer(offerId);
  final activeTradesForOffer = tradeManager.getActiveTradesForOffer(offerId);
  final completedTradesForOffer = tradeManager.getCompletedTradesCountForOffer(
    offerId,
  );

  // Get inquiries (notifications tagged with this offer)
  final notifications = notificationService.getNotificationsForOffer(offerId);
  final inquiryCount =
      notifications
          .where(
            (n) =>
                n.type == P2PNotificationType.inquiry ||
                n.type == P2PNotificationType.tradeMessage,
          )
          .length;

  return OfferStats(
    views: viewCount,
    inquiries: inquiryCount,
    totalTrades: allTradesForOffer.length,
    activeTrades: activeTradesForOffer.length,
    completedTrades: completedTradesForOffer,
  );
});

/// Provider for active trades for a specific offer
final activeTradesForOfferProvider = Provider.family<List<P2PTrade>, String>((
  ref,
  offerId,
) {
  final tradeManager = ref.watch(p2pTradeManagerProvider);
  return tradeManager.getActiveTradesForOffer(offerId);
});

/// Provider for all trades for a specific offer
final allTradesForOfferProvider = Provider.family<List<P2PTrade>, String>((
  ref,
  offerId,
) {
  final tradeManager = ref.watch(p2pTradeManagerProvider);
  return tradeManager.getTradesForOffer(offerId);
});
