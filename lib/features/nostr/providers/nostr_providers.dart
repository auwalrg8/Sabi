import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/services/nostr/nostr_service.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';

/// Provider for RelayPoolManager singleton
final relayPoolProvider = Provider<RelayPoolManager>((ref) {
  return RelayPoolManager();
});

/// Provider for NostrProfileService singleton
final nostrProfileServiceProvider = Provider<NostrProfileService>((ref) {
  return NostrProfileService();
});

/// Provider for ZapService singleton
final zapServiceProvider = Provider<ZapService>((ref) {
  return ZapService();
});

/// Provider for FeedAggregator singleton
final feedAggregatorProvider = Provider<FeedAggregator>((ref) {
  return FeedAggregator();
});

/// Provider for NIP99MarketplaceService singleton
final nip99MarketplaceProvider = Provider<NIP99MarketplaceService>((ref) {
  return NIP99MarketplaceService();
});

/// Provider for EventCacheService singleton
final eventCacheProvider = Provider<EventCacheService>((ref) {
  return EventCacheService();
});

/// Current user's Nostr profile (async)
final currentNostrProfileProvider = FutureProvider<NostrProfile?>((ref) async {
  final profileService = ref.watch(nostrProfileServiceProvider);
  final pubkey = profileService.currentPubkey;
  if (pubkey == null) return null;
  return await profileService.fetchProfile(pubkey);
});

/// Current user's follows list (async)
final followsListProvider = FutureProvider<List<String>>((ref) async {
  final cache = ref.watch(eventCacheProvider);
  final profileService = ref.watch(nostrProfileServiceProvider);
  final pubkey = profileService.currentPubkey;
  if (pubkey == null) return [];
  return await cache.getCachedFollows(pubkey);
});

/// Check if user follows a specific pubkey
final isFollowingProvider = FutureProvider.family<bool, String>((ref, pubkey) async {
  final profileService = ref.watch(nostrProfileServiceProvider);
  return await profileService.isFollowing(pubkey);
});

/// Feed state notifier for managing feed loading/refreshing
class FeedNotifier extends StateNotifier<AsyncValue<List<NostrFeedPost>>> {
  final FeedAggregator _feedAggregator;
  final FeedType _feedType;
  StreamSubscription<NostrFeedPost>? _subscription;

  FeedNotifier(this._feedAggregator, this._feedType)
      : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    await refresh();
    _subscribeToUpdates();
  }

  Future<void> refresh() async {
    try {
      state = const AsyncValue.loading();
      final posts = await _feedAggregator.fetchFeed(type: _feedType);
      state = AsyncValue.data(posts);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _subscribeToUpdates() {
    _subscription?.cancel();
    _subscription = _feedAggregator.subscribeToFeed(type: _feedType).listen((post) {
      // Add new post to existing list
      final current = state.valueOrNull ?? [];
      if (!current.any((p) => p.id == post.id)) {
        final updated = [post, ...current];
        updated.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        state = AsyncValue.data(updated.take(100).toList());
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Following feed provider
final followingFeedProvider = StateNotifierProvider<FeedNotifier, AsyncValue<List<NostrFeedPost>>>((ref) {
  final feedAggregator = ref.watch(feedAggregatorProvider);
  return FeedNotifier(feedAggregator, FeedType.following);
});

/// Global feed provider
final globalFeedProvider = StateNotifierProvider<FeedNotifier, AsyncValue<List<NostrFeedPost>>>((ref) {
  final feedAggregator = ref.watch(feedAggregatorProvider);
  return FeedNotifier(feedAggregator, FeedType.global);
});

/// Zap state for tracking zap operations
class ZapState {
  final bool isLoading;
  final String? error;
  final ZapResult? lastResult;

  const ZapState({
    this.isLoading = false,
    this.error,
    this.lastResult,
  });

  ZapState copyWith({
    bool? isLoading,
    String? error,
    ZapResult? lastResult,
  }) {
    return ZapState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastResult: lastResult ?? this.lastResult,
    );
  }
}

/// Zap notifier for sending zaps
class ZapNotifier extends StateNotifier<ZapState> {
  final ZapService _zapService;

  ZapNotifier(this._zapService) : super(const ZapState());

  /// Send a zap to a pubkey
  Future<ZapResult> sendZap({
    required String recipientPubkey,
    required int amountSats,
    String? comment,
    String? eventId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _zapService.sendZap(
        recipientPubkey: recipientPubkey,
        amountSats: amountSats,
        comment: comment,
        eventId: eventId,
        getBalance: _getBreezBalance,
        payInvoice: _payWithBreezSdk,
      );

      state = state.copyWith(isLoading: false, lastResult: result);
      return result;
    } catch (e) {
      final error = e.toString();
      state = state.copyWith(isLoading: false, error: error);
      return ZapResult.failure(error);
    }
  }

  /// Get balance from Breez SDK
  Future<int> _getBreezBalance() async {
    try {
      final balance = await BreezSparkService.getBalance();
      return balance.toInt();
    } catch (e) {
      return 0;
    }
  }

  /// Payment function using Breez SDK
  Future<String?> _payWithBreezSdk(String invoice) async {
    try {
      await BreezSparkService.sendPayment(invoice);
      return null; // Success - no error
    } catch (e) {
      return e.toString(); // Return error message
    }
  }

  /// Reset zap state
  void reset() {
    state = const ZapState();
  }
}

/// Zap provider
final zapNotifierProvider = StateNotifierProvider<ZapNotifier, ZapState>((ref) {
  final zapService = ref.watch(zapServiceProvider);
  return ZapNotifier(zapService);
});

/// NIP-99 P2P offers provider (one-shot fetch)
final nip99OffersProvider = FutureProvider.autoDispose<List<NostrP2POffer>>((ref) async {
  final marketplace = ref.watch(nip99MarketplaceProvider);
  final offers = await marketplace.fetchOffers(limit: 50);
  await marketplace.enrichOffersWithProfiles(offers);
  return offers;
});

/// NIP-99 P2P offers stream provider (real-time)
final nip99OffersStreamProvider = StreamProvider.autoDispose<NostrP2POffer>((ref) {
  final marketplace = ref.watch(nip99MarketplaceProvider);
  return marketplace.subscribeToOffers();
});

/// Current user's P2P offers
final userP2POffersProvider = FutureProvider.autoDispose<List<NostrP2POffer>>((ref) async {
  final marketplace = ref.watch(nip99MarketplaceProvider);
  final profileService = ref.watch(nostrProfileServiceProvider);
  
  final pubkey = profileService.currentPubkey;
  if (pubkey == null) return [];
  
  return await marketplace.fetchUserOffers(pubkey);
});

/// Profile fetch provider (by pubkey)
final profileByPubkeyProvider = FutureProvider.family<NostrProfile?, String>((ref, pubkey) async {
  final profileService = ref.watch(nostrProfileServiceProvider);
  return await profileService.fetchProfile(pubkey);
});

/// Initialize all Nostr services
Future<void> initializeNostrServices() async {
  final relayPool = RelayPoolManager();
  final cache = EventCacheService();
  
  // Initialize cache first
  await cache.initialize();
  
  // Initialize relay pool and connect
  await relayPool.init();
}
