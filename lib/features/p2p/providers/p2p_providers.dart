import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/features/p2p/data/p2p_offer_model.dart';
import 'package:sabi_wallet/features/p2p/data/merchant_model.dart';
import 'package:sabi_wallet/features/p2p/data/payment_method_model.dart';

// Exchange rates provider
final exchangeRatesProvider = Provider<Map<String, double>>((ref) {
  return {
    'BTC_NGN': 131448939.22,
    'USD_NGN': 1614.0,
  };
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
      paymentInstructions: 'Send to GTBank 0123456789 – Auwal Abubakar. Use your full name as narration.',
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
      paymentInstructions: 'Send to Moniepoint account details will be shared in chat.',
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

final p2pFilterProvider = StateNotifierProvider<P2PFilterNotifier, P2PFilterState>((ref) {
  return P2PFilterNotifier();
});

// Filtered and sorted offers
final filteredP2POffersProvider = Provider<List<P2POfferModel>>((ref) {
  final offers = ref.watch(p2pOffersProvider);
  final filter = ref.watch(p2pFilterProvider);

  var filtered = offers.where((offer) {
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
      final aMinutes = int.tryParse(a.eta.split('–').first.replaceAll(RegExp(r'[^0-9]'), '')) ?? 999;
      final bMinutes = int.tryParse(b.eta.split('–').first.replaceAll(RegExp(r'[^0-9]'), '')) ?? 999;
      return aMinutes.compareTo(bMinutes);
    });
  }

  return filtered;
});
