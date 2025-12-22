import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sabi_wallet/services/profile_service.dart';
import 'package:sabi_wallet/features/p2p/data/p2p_offer_model.dart';
import 'package:sabi_wallet/features/p2p/data/merchant_model.dart';
import 'package:sabi_wallet/features/p2p/data/payment_method_model.dart';
import 'package:sabi_wallet/features/p2p/data/models/p2p_models.dart';

// Exchange rates provider
final exchangeRatesProvider = Provider<Map<String, double>>((ref) {
  return {'BTC_NGN': 131448939.22, 'USD_NGN': 1614.0};
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

// Mock merchants
final merchantsProvider = Provider<List<MerchantModel>>((ref) {
  return [
    MerchantModel(
      id: 'merchant_1',
      name: 'Mubarak',
      isVerified: true,
      isNostrVerified: true,
      trades30d: 160,
      completionRate: 100.0,
      avgReleaseMinutes: 17,
      totalVolume: 85000000,
      positiveFeedback: 526,
      negativeFeedback: 0,
      joinedDate: DateTime(2023, 3, 1),
      firstTradeDate: DateTime(2023, 3, 13),
    ),
    MerchantModel(
      id: 'merchant_2',
      name: 'Almohad',
      isVerified: true,
      isNostrVerified: true,
      trades30d: 180,
      completionRate: 100.0,
      avgReleaseMinutes: 15,
      totalVolume: 95000000,
      positiveFeedback: 612,
      negativeFeedback: 0,
      joinedDate: DateTime(2023, 2, 15),
      firstTradeDate: DateTime(2023, 2, 20),
    ),
  ];
});

// P2P offers provider with enhanced data
final p2pOffersProvider = Provider<List<P2POfferModel>>((ref) {
  final merchants = ref.watch(merchantsProvider);
  final paymentMethods = ref.watch(paymentMethodsProvider);

  return [
    P2POfferModel(
      id: 'offer_1',
      name: 'Mubarak',
      pricePerBtc: 131448939.22,
      paymentMethod: 'GTBank',
      eta: '5–15 min',
      ratingPercent: 98,
      trades: 1247,
      minLimit: 50000,
      maxLimit: 8000000,
      type: OfferType.sell,
      merchant: merchants[0],
      acceptedMethods: [paymentMethods[0]],
      marginPercent: 1.5,
      requiresKyc: true,
      paymentInstructions:
          'Send to GTBank 0123456789 – Auwal Abubakar. Use your full name as narration.',
      availableSats: 5000,
      responseTime: '<3 min',
      volume: 45000000,
    ),
    P2POfferModel(
      id: 'offer_2',
      name: 'Almohad',
      pricePerBtc: 131448939.22,
      paymentMethod: 'Moniepoint',
      eta: '3–15 min',
      ratingPercent: 99,
      trades: 2156,
      minLimit: 100000,
      maxLimit: 5000000,
      type: OfferType.sell,
      merchant: merchants[1],
      acceptedMethods: [paymentMethods[3]],
      marginPercent: 1.2,
      requiresKyc: false,
      paymentInstructions:
          'Send to Moniepoint account details will be shared in chat.',
      availableSats: 8000,
      responseTime: '<5 min',
      volume: 52000000,
    ),
    P2POfferModel(
      id: 'offer_3',
      name: 'Mubarak',
      pricePerBtc: 131450000.00,
      paymentMethod: 'GTBank',
      eta: '5–15 min',
      ratingPercent: 98,
      trades: 1247,
      minLimit: 50000,
      maxLimit: 8000000,
      type: OfferType.sell,
      merchant: merchants[0],
      acceptedMethods: [paymentMethods[0]],
      marginPercent: 1.5,
      requiresKyc: true,
      availableSats: 5000,
      responseTime: '<3 min',
      volume: 45000000,
    ),
  ];
});

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

  Future<void> removeOffer(String id) async {
    state = state.where((o) => o.id != id).toList();
    await _save();
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
  final offers = [...seedOffers, ...userOffers];
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
