import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../hodl_hodl_service.dart';
import '../models/hodl_hodl_models.dart';

/// Provider for the HodlHodl service singleton
final hodlHodlServiceProvider = Provider<HodlHodlService>((ref) {
  return HodlHodlService();
});

/// Provider to check if HodlHodl API is configured
final hodlHodlConfiguredProvider = FutureProvider<bool>((ref) async {
  final service = ref.read(hodlHodlServiceProvider);
  return service.isConfigured();
});

/// Current trade mode for the Trade tab
enum TradeMode {
  ramp,       // Fiat on/off ramp
  p2pBeta,    // Hodl Hodl P2P Beta
  decentralized, // NIP-99 (coming soon)
}

/// Provider for the current trade mode
final tradeModeProvider = StateProvider<TradeMode>((ref) => TradeMode.ramp);

/// Filter state for offers
class HodlHodlOfferFilter {
  final String? side; // 'buy' or 'sell'
  final String currencyCode;
  final String? paymentMethodName;
  final double? minAmount;
  final double? maxAmount;

  const HodlHodlOfferFilter({
    this.side,
    this.currencyCode = 'NGN',
    this.paymentMethodName,
    this.minAmount,
    this.maxAmount,
  });

  HodlHodlOfferFilter copyWith({
    String? side,
    String? currencyCode,
    String? paymentMethodName,
    double? minAmount,
    double? maxAmount,
  }) {
    return HodlHodlOfferFilter(
      side: side ?? this.side,
      currencyCode: currencyCode ?? this.currencyCode,
      paymentMethodName: paymentMethodName ?? this.paymentMethodName,
      minAmount: minAmount ?? this.minAmount,
      maxAmount: maxAmount ?? this.maxAmount,
    );
  }
}

/// Provider for offer filters
final hodlHodlFilterProvider = StateProvider<HodlHodlOfferFilter>((ref) {
  return const HodlHodlOfferFilter();
});

/// Provider for fetching offers
final hodlHodlOffersProvider = FutureProvider<List<HodlHodlOffer>>((ref) async {
  final service = ref.read(hodlHodlServiceProvider);
  final filter = ref.watch(hodlHodlFilterProvider);
  
  try {
    return await service.getOffers(
      side: filter.side,
      currencyCode: filter.currencyCode,
      paymentMethodName: filter.paymentMethodName,
      amount: filter.minAmount,
    );
  } catch (e) {
    // Return empty list on error but log it
    print('Error fetching HodlHodl offers: $e');
    return [];
  }
});

/// Provider for a specific offer
final hodlHodlOfferProvider = FutureProvider.family<HodlHodlOffer?, String>((ref, offerId) async {
  final service = ref.read(hodlHodlServiceProvider);
  
  try {
    return await service.getOffer(offerId);
  } catch (e) {
    print('Error fetching HodlHodl offer $offerId: $e');
    return null;
  }
});

/// Provider for user's contracts
final hodlHodlContractsProvider = FutureProvider<List<HodlHodlContract>>((ref) async {
  final service = ref.read(hodlHodlServiceProvider);
  final isConfigured = await ref.watch(hodlHodlConfiguredProvider.future);
  
  if (!isConfigured) return [];
  
  try {
    return await service.getMyContracts();
  } catch (e) {
    print('Error fetching HodlHodl contracts: $e');
    return [];
  }
});

/// Provider for active contracts only
final hodlHodlActiveContractsProvider = FutureProvider<List<HodlHodlContract>>((ref) async {
  final service = ref.read(hodlHodlServiceProvider);
  final isConfigured = await ref.watch(hodlHodlConfiguredProvider.future);
  
  if (!isConfigured) return [];
  
  try {
    return await service.getActiveContracts();
  } catch (e) {
    print('Error fetching active HodlHodl contracts: $e');
    return [];
  }
});

/// Provider for a specific contract
final hodlHodlContractProvider = FutureProvider.family<HodlHodlContract?, String>((ref, contractId) async {
  final service = ref.read(hodlHodlServiceProvider);
  
  try {
    return await service.getContract(contractId);
  } catch (e) {
    print('Error fetching HodlHodl contract $contractId: $e');
    return null;
  }
});

/// Provider for chat messages in a contract
final hodlHodlChatMessagesProvider = FutureProvider.family<List<HodlHodlChatMessage>, String>((ref, contractId) async {
  final service = ref.read(hodlHodlServiceProvider);
  
  try {
    return await service.getChatMessages(contractId);
  } catch (e) {
    print('Error fetching chat messages for contract $contractId: $e');
    return [];
  }
});

/// Provider for available currencies
final hodlHodlCurrenciesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = ref.read(hodlHodlServiceProvider);
  
  try {
    return await service.getCurrencies();
  } catch (e) {
    print('Error fetching currencies: $e');
    return [];
  }
});

/// Provider for available payment methods
final hodlHodlPaymentMethodsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = ref.read(hodlHodlServiceProvider);
  
  try {
    return await service.getPaymentMethods(country: 'Nigeria');
  } catch (e) {
    print('Error fetching payment methods: $e');
    return [];
  }
});

/// Notifier for contract actions
class HodlHodlContractNotifier extends StateNotifier<AsyncValue<HodlHodlContract?>> {
  final HodlHodlService _service;
  
  HodlHodlContractNotifier(this._service) : super(const AsyncValue.data(null));

  Future<HodlHodlContract?> acceptOffer({
    required HodlHodlOffer offer,
    required String paymentMethodInstructionId,
    required String paymentMethodInstructionVersion,
    double? fiatAmount,
    double? btcAmount,
    String? comment,
  }) async {
    state = const AsyncValue.loading();
    try {
      final contract = await _service.createContract(
        offerId: offer.id,
        offerVersion: offer.version,
        paymentMethodInstructionId: paymentMethodInstructionId,
        paymentMethodInstructionVersion: paymentMethodInstructionVersion,
        value: fiatAmount,
        volume: btcAmount,
        comment: comment,
      );
      state = AsyncValue.data(contract);
      return contract;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> confirmEscrow(String contractId) async {
    try {
      final contract = await _service.confirmEscrow(contractId);
      state = AsyncValue.data(contract);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> markAsPaid(String contractId) async {
    try {
      final contract = await _service.markAsPaid(contractId);
      state = AsyncValue.data(contract);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> cancelContract(String contractId) async {
    try {
      final contract = await _service.cancelContract(contractId);
      state = AsyncValue.data(contract);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> startDispute(String contractId) async {
    try {
      final contract = await _service.startDispute(contractId);
      state = AsyncValue.data(contract);
      return true;
    } catch (e) {
      return false;
    }
  }

  void refresh(String contractId) async {
    state = const AsyncValue.loading();
    try {
      final contract = await _service.getContract(contractId);
      state = AsyncValue.data(contract);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// Provider for contract actions
final hodlHodlContractNotifierProvider = StateNotifierProvider<HodlHodlContractNotifier, AsyncValue<HodlHodlContract?>>((ref) {
  final service = ref.read(hodlHodlServiceProvider);
  return HodlHodlContractNotifier(service);
});
