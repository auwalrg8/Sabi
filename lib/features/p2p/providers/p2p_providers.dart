import 'dart:convert';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sabi_wallet/services/profile_service.dart';
import 'package:sabi_wallet/services/rate_service.dart';
import 'package:sabi_wallet/services/nostr_service.dart';
import 'package:sabi_wallet/features/p2p/data/p2p_offer_model.dart';
import 'package:sabi_wallet/features/p2p/data/merchant_model.dart';
import 'package:sabi_wallet/features/p2p/data/payment_method_model.dart';
import 'package:sabi_wallet/features/p2p/data/models/p2p_models.dart';

// Real-time exchange rates provider (fetches from API)
final liveExchangeRatesProvider = FutureProvider<Map<String, double>>((
  ref,
) async {
  final btcNgn = await RateService.getBtcToNgnRate();
  final btcUsd = await RateService.getBtcToUsdRate();
  final usdNgn = await RateService.getUsdToNgnRate();
  return {'BTC_NGN': btcNgn, 'BTC_USD': btcUsd, 'USD_NGN': usdNgn};
});

// Legacy provider for compatibility (now returns default values, use liveExchangeRatesProvider instead)
final exchangeRatesProvider = Provider<Map<String, double>>((ref) {
  // Try to get live rates, fallback to defaults
  final liveRates = ref.watch(liveExchangeRatesProvider);
  return liveRates.maybeWhen(
    data: (rates) => rates,
    orElse:
        () => {'BTC_NGN': 150000000.0, 'BTC_USD': 95000.0, 'USD_NGN': 1580.0},
  );
});

// Payment methods provider
final paymentMethodsProvider = Provider<List<PaymentMethodModel>>((ref) {
  return [
    PaymentMethodModel(
      id: 'gtbank',
      name: 'GTBank',
      type: PaymentMethodType.bankTransfer,
      accountDetails: 'GTBank 0123456789 – Auwal Abubakar',
    ),
    PaymentMethodModel(
      id: 'opay',
      name: 'Opay',
      type: PaymentMethodType.mobileMoney,
    ),
    PaymentMethodModel(
      id: 'palmpay',
      name: 'PalmPay',
      type: PaymentMethodType.mobileMoney,
    ),
    PaymentMethodModel(
      id: 'moniepoint',
      name: 'Moniepoint',
      type: PaymentMethodType.bankTransfer,
    ),
    PaymentMethodModel(
      id: 'cash_lagos',
      name: 'Cash (Lagos only)',
      type: PaymentMethodType.cash,
    ),
    PaymentMethodModel(
      id: 'amazon',
      name: 'Amazon Gift Card',
      type: PaymentMethodType.giftCard,
    ),
  ];
});

// Merchants provider - empty for real trading (no mock data)
// Real merchant profiles will be loaded from trade counterparties
final merchantsProvider = Provider<List<MerchantModel>>((ref) {
  return [];
});

// P2P offers provider - returns empty list (no mock data)
// Real offers come from user-created offers via userOffersProvider
final p2pOffersProvider = Provider<List<P2POfferModel>>((ref) {
  return [];
});

// Fetch P2P offers from Nostr relays (one-shot query, refreshable)
final fetchedNostrOffersProvider =
    FutureProvider.autoDispose<List<P2POfferModel>>((ref) async {
      // Ensure Nostr is initialized
      final isReady = await NostrService.ensureInitialized();
      if (!isReady) return [];

      final rawOffers = await NostrService.fetchOffers(limit: 100);
      final offers = <P2POfferModel>[];

      for (final map in rawOffers) {
        try {
          final action = map['action'] as String?;
          if (action == 'cancel') continue; // Skip cancelled offers

          offers.add(P2POfferModel.fromJson(map));
        } catch (e) {
          // Skip malformed offers
        }
      }

      return offers;
    });

// Nostr-published P2P offers (real-time, decentralized)
final nostrOffersProvider = StreamProvider.autoDispose<List<P2POfferModel>>((
  ref,
) {
  final controller = StreamController<List<P2POfferModel>>();
  final offers = <String, P2POfferModel>{};

  // Check if Nostr is initialized before subscribing
  if (!NostrService.isInitialized) {
    // Try to initialize, then start subscription
    NostrService.ensureInitialized().then((ok) {
      if (!ok) {
        controller.add([]);
        return;
      }
      _startSubscription(controller, offers);
    });
  } else {
    _startSubscription(controller, offers);
  }

  ref.onDispose(() async {
    await controller.close();
  });

  return controller.stream;
});

void _startSubscription(
  StreamController<List<P2POfferModel>> controller,
  Map<String, P2POfferModel> offers,
) {
  NostrService.subscribeToOffers().listen((event) {
    try {
      final content = event.content;
      final map = jsonDecode(content) as Map<String, dynamic>;
      final action = map['action'] as String?;
      if (action == 'cancel') {
        final id = map['id'] as String? ?? event.id;
        offers.remove(id);
        controller.add(offers.values.toList());
        return;
      }

      // Update or create
      final id = map['id'] as String? ?? event.id;
      map['id'] = id;
      final model = P2POfferModel.fromJson(map);
      offers[id] = model;
      controller.add(offers.values.toList());
    } catch (e) {
      // ignore malformed events
    }
  });
}

// User-created offers persisted locally
class UserOffersNotifier extends StateNotifier<List<P2POfferModel>> {
  UserOffersNotifier(this.ref) : super([]) {
    _load();
  }

  final Ref ref;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('p2p_user_offers');
      if (raw == null || raw.isEmpty) return;
      final list = jsonDecode(raw) as List<dynamic>;
      final merchants = ref.read(merchantsProvider);
      final offers =
          list.map((e) {
            final map = Map<String, dynamic>.from(e as Map);
            final merchantId = map['merchantId'] as String?;
            final merchant =
                merchantId == null
                    ? null
                    : merchants.firstWhere(
                      (m) => m.id == merchantId,
                      orElse:
                          () => MerchantModel(
                            id: merchantId,
                            name: map['name'] as String? ?? 'You',
                            trades30d: 0,
                            completionRate: 100.0,
                            avgReleaseMinutes: 15,
                            totalVolume: 0,
                            joinedDate: DateTime.now(),
                          ),
                    );
            return P2POfferModel.fromJson(map, merchant: merchant);
          }).toList();
      state = offers;
    } catch (e) {
      // ignore
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(state.map((e) => e.toJson()).toList());
    await prefs.setString('p2p_user_offers', raw);
  }

  Future<void> addOffer(P2POfferModel offer) async {
    state = [offer, ...state];
    await _save();
  }

  Future<void> updateOffer(P2POfferModel updated) async {
    state = state.map((o) => o.id == updated.id ? updated : o).toList();
    await _save();
    // Publish update to Nostr
    try {
      await NostrService.publishOfferUpdate(updated.toJson());
    } catch (_) {
      // non-fatal
    }
  }

  Future<void> removeOffer(String id) async {
    state = state.where((o) => o.id != id).toList();
    await _save();
    // Publish cancel to Nostr so remote clients can remove the offer
    try {
      await NostrService.publishOfferCancel(id);
    } catch (_) {
      // non-fatal if Nostr not initialized
    }
  }

  /// Lock sats when a trade starts - prevents overselling
  /// Returns true if lock was successful, false if insufficient available sats
  Future<bool> lockSats(String offerId, double amount) async {
    final index = state.indexWhere((o) => o.id == offerId);
    if (index == -1) return false;

    final offer = state[index];
    final available = offer.effectiveAvailableSats;

    // Check if we have enough unlocked sats
    if (amount > available) {
      return false;
    }

    // Lock the sats
    final updatedOffer = offer.copyWith(
      lockedSats: (offer.lockedSats ?? 0) + amount,
    );
    state = [...state];
    state[index] = updatedOffer;
    await _save();
    return true;
  }

  /// Unlock sats when a trade is cancelled - makes sats available again
  Future<void> unlockSats(String offerId, double amount) async {
    final index = state.indexWhere((o) => o.id == offerId);
    if (index == -1) return;

    final offer = state[index];
    final newLockedSats = ((offer.lockedSats ?? 0) - amount).clamp(
      0.0,
      double.infinity,
    );

    final updatedOffer = offer.copyWith(lockedSats: newLockedSats);
    state = [...state];
    state[index] = updatedOffer;
    await _save();
  }

  /// Deduct sats permanently after a trade completes
  /// Reduces both availableSats and lockedSats
  Future<void> deductSats(String offerId, double amount) async {
    final index = state.indexWhere((o) => o.id == offerId);
    if (index == -1) return;

    final offer = state[index];
    final newAvailable = ((offer.availableSats ?? 0) - amount).clamp(
      0.0,
      double.infinity,
    );
    final newLocked = ((offer.lockedSats ?? 0) - amount).clamp(
      0.0,
      double.infinity,
    );

    final updatedOffer = offer.copyWith(
      availableSats: newAvailable,
      lockedSats: newLocked,
    );
    state = [...state];
    state[index] = updatedOffer;
    await _save();

    // Publish updated availability to Nostr
    try {
      await NostrService.publishOfferUpdate(updatedOffer.toJson());
    } catch (_) {
      // non-fatal
    }
  }
}

final userOffersProvider =
    StateNotifierProvider<UserOffersNotifier, List<P2POfferModel>>((ref) {
      return UserOffersNotifier(ref);
    });

// Filter state provider
class P2PFilterState {
  final OfferType offerType;
  final String paymentFilter;
  final String sortBy;

  P2PFilterState({
    this.offerType = OfferType.sell,
    this.paymentFilter = 'All Payments',
    this.sortBy = 'Best Price',
  });

  P2PFilterState copyWith({
    OfferType? offerType,
    String? paymentFilter,
    String? sortBy,
  }) {
    return P2PFilterState(
      offerType: offerType ?? this.offerType,
      paymentFilter: paymentFilter ?? this.paymentFilter,
      sortBy: sortBy ?? this.sortBy,
    );
  }
}

class P2PFilterNotifier extends StateNotifier<P2PFilterState> {
  P2PFilterNotifier() : super(P2PFilterState());

  void setOfferType(OfferType type) {
    state = state.copyWith(offerType: type);
  }

  void setPaymentFilter(String filter) {
    state = state.copyWith(paymentFilter: filter);
  }

  void setSortBy(String sortBy) {
    state = state.copyWith(sortBy: sortBy);
  }
}

final p2pFilterProvider =
    StateNotifierProvider<P2PFilterNotifier, P2PFilterState>((ref) {
      return P2PFilterNotifier();
    });

// Filtered and sorted offers
final filteredP2POffersProvider = Provider<List<P2POfferModel>>((ref) {
  final seedOffers = ref.watch(p2pOffersProvider);
  final userOffers = ref.watch(userOffersProvider);
  final nostrOffersAsync = ref.watch(nostrOffersProvider);
  final nostrOffers = nostrOffersAsync.asData?.value ?? [];
  final offers = [...seedOffers, ...userOffers, ...nostrOffers];
  final filter = ref.watch(p2pFilterProvider);

  var filtered =
      offers.where((offer) {
        if (offer.type != filter.offerType) return false;
        if (filter.paymentFilter != 'All Payments' &&
            offer.paymentMethod != filter.paymentFilter) {
          return false;
        }
        return true;
      }).toList();

  // Sort
  if (filter.sortBy == 'Best Price') {
    filtered.sort((a, b) => a.pricePerBtc.compareTo(b.pricePerBtc));
  } else if (filter.sortBy == 'Highest Rated') {
    filtered.sort((a, b) => b.ratingPercent.compareTo(a.ratingPercent));
  } else if (filter.sortBy == 'Fastest') {
    filtered.sort((a, b) {
      final aMinutes =
          int.tryParse(
            a.eta.split('–').first.replaceAll(RegExp(r'[^0-9]'), ''),
          ) ??
          999;
      final bMinutes =
          int.tryParse(
            b.eta.split('–').first.replaceAll(RegExp(r'[^0-9]'), ''),
          ) ??
          999;
      return aMinutes.compareTo(bMinutes);
    });
  }

  return filtered;
});

// Merchant profile tab selection
final merchantProfileTabProvider = StateProvider<MerchantProfileTab>(
  (ref) => MerchantProfileTab.info,
);

// Merchant profile provider (mocked from merchants list)
final merchantProfileProvider = FutureProvider.family<MerchantProfile, String>((
  ref,
  merchantId,
) async {
  final merchants = ref.read(merchantsProvider);
  final match = merchants.firstWhere(
    (m) => m.id == merchantId,
    orElse: () => merchants.first,
  );

  // Check if merchantId refers to the current user; if so, surface the real user profile
  try {
    final userProfile = await ProfileService.getProfile();
    final isCurrentUser =
        (merchantId == userProfile.username ||
            merchantId == userProfile.fullName);
    if (isCurrentUser) {
      // Build MerchantProfile from real user profile
      final userAds =
          ref
              .read(userOffersProvider)
              .where(
                (o) =>
                    (o.merchant?.id == userProfile.username) ||
                    (o.name == userProfile.fullName) ||
                    (o.name == userProfile.username),
              )
              .map(
                (o) => MerchantAd(
                  id: o.id,
                  merchantName: o.name,
                  merchantAvatar: userProfile.profilePicturePath,
                  pricePerBtc: o.pricePerBtc,
                  minAmount: o.minLimit.toDouble(),
                  maxAmount: o.maxLimit.toDouble(),
                  merchantRating: o.ratingPercent.toDouble(),
                  merchantTrades: o.trades,
                  paymentMethod: o.paymentMethod,
                  paymentWindow: const Duration(minutes: 15),
                  satsPerFiat: o.availableSats ?? 0,
                ),
              )
              .toList();

      return MerchantProfile(
        id: userProfile.username,
        name: userProfile.fullName,
        avatar: userProfile.profilePicturePath,
        verifications: [MerchantVerification(name: 'ID')],
        stats: MerchantStats(
          trades30d: 0,
          completionRate: 100.0,
          avgReleaseTime: const Duration(minutes: 15),
          totalVolume: 0,
          volumeCurrency: 'NGN',
          positiveFeedback: 0,
          negativeFeedback: 0,
          rating: 100,
        ),
        ads: userAds,
        feedbacks: [],
        joinedAt: DateTime.now(),
        daysToFirstTrade: 0,
      );
    }
  } catch (_) {}

  final profile = MerchantProfile(
    id: match.id,
    name: match.name,
    avatar: match.avatarUrl,
    verifications: [MerchantVerification(name: 'ID')],
    stats: MerchantStats(
      trades30d: match.trades30d,
      completionRate: match.completionRate,
      avgReleaseTime: Duration(minutes: match.avgReleaseMinutes),
      totalVolume: match.totalVolume,
      volumeCurrency: 'NGN',
      positiveFeedback: match.positiveFeedback,
      negativeFeedback: match.negativeFeedback,
      rating: match.rating,
    ),
    ads: [],
    feedbacks: [],
    joinedAt: match.joinedDate,
    daysToFirstTrade:
        match.firstTradeDate != null
            ? match.firstTradeDate!.difference(match.joinedDate).inDays
            : 0,
  );

  // include user-created offers as ads if they belong to this merchantId
  try {
    final userOffers = ref.read(userOffersProvider);
    final ads =
        userOffers
            .where(
              (o) => (o.merchant?.id == merchantId) || (o.name == merchantId),
            )
            .map(
              (o) => MerchantAd(
                id: o.id,
                merchantName: o.name,
                merchantAvatar: o.merchant?.avatarUrl,
                pricePerBtc: o.pricePerBtc,
                minAmount: o.minLimit.toDouble(),
                maxAmount: o.maxLimit.toDouble(),
                merchantRating: o.ratingPercent.toDouble(),
                merchantTrades: o.trades,
                paymentMethod: o.paymentMethod,
                paymentWindow: const Duration(minutes: 15),
                satsPerFiat: o.availableSats ?? 0,
              ),
            )
            .toList();
    return MerchantProfile(
      id: profile.id,
      name: profile.name,
      avatar: profile.avatar,
      verifications: profile.verifications,
      stats: profile.stats,
      ads: ads.isNotEmpty ? ads : profile.ads,
      feedbacks: profile.feedbacks,
      joinedAt: profile.joinedAt,
      daysToFirstTrade: profile.daysToFirstTrade,
    );
  } catch (_) {}

  await Future.delayed(const Duration(milliseconds: 150));
  return profile;
});

// Active trades notifier/provider
class ActiveTradesNotifier extends StateNotifier<AsyncValue<List<Trade>>> {
  ActiveTradesNotifier(this.ref) : super(const AsyncValue.loading()) {
    _load();
  }

  final Ref ref;

  Future<void> _load() async {
    try {
      final offers = ref.read(p2pOffersProvider);
      final trades =
          offers
              .map(
                (o) => Trade(
                  id: 'trade_${o.id}',
                  counterpartyId: o.merchant?.id ?? o.id,
                  counterpartyName: o.name,
                  counterpartyAvatar: o.merchant?.avatarUrl,
                  fiatAmount: ((o.minLimit + o.maxLimit) / 2).toDouble(),
                  satsAmount:
                      (((o.minLimit + o.maxLimit) / 2) /
                              (o.pricePerBtc == 0 ? 1 : o.pricePerBtc) *
                              100000000)
                          .toDouble(),
                  status: TradeStatus.awaitingPayment,
                  createdAt: DateTime.now().subtract(const Duration(hours: 1)),
                  timeLeft: const Duration(minutes: 30),
                  type: TradeType.buy,
                ),
              )
              .toList();

      final unique = {for (var t in trades) t.id: t}.values.toList();
      state = AsyncValue.data(unique);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async => await _load();
}

final activeTradesNotifierProvider =
    StateNotifierProvider<ActiveTradesNotifier, AsyncValue<List<Trade>>>((ref) {
      return ActiveTradesNotifier(ref);
    });

// Trade history notifier/provider
class TradeHistoryNotifier extends StateNotifier<AsyncValue<List<Trade>>> {
  TradeHistoryNotifier(this.ref) : super(const AsyncValue.loading()) {
    _load();
  }

  final Ref ref;

  Future<void> _load() async {
    try {
      final offers = ref.read(p2pOffersProvider);
      final trades =
          offers
              .map(
                (o) => Trade(
                  id: 'hist_${o.id}',
                  counterpartyId: o.merchant?.id ?? o.id,
                  counterpartyName: o.name,
                  counterpartyAvatar: o.merchant?.avatarUrl,
                  fiatAmount: ((o.minLimit + o.maxLimit) / 2).toDouble(),
                  satsAmount:
                      (((o.minLimit + o.maxLimit) / 2) /
                              (o.pricePerBtc == 0 ? 1 : o.pricePerBtc) *
                              100000000)
                          .toDouble(),
                  status: TradeStatus.completed,
                  createdAt: DateTime.now().subtract(const Duration(days: 2)),
                  timeLeft: null,
                  type: TradeType.sell,
                ),
              )
              .toList();

      final unique = {for (var t in trades) t.id: t}.values.toList();
      state = AsyncValue.data(unique);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async => await _load();
}

final tradeHistoryNotifierProvider =
    StateNotifierProvider<TradeHistoryNotifier, AsyncValue<List<Trade>>>((ref) {
      return TradeHistoryNotifier(ref);
    });

final tradeHistoryFilterProvider = StateProvider<TradeHistoryFilter>(
  (ref) => TradeHistoryFilter.all,
);
