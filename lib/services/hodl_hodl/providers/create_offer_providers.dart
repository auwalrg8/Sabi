import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../hodl_hodl_service.dart';
import '../models/create_offer_models.dart';
import 'hodl_hodl_providers.dart';

/// Provider for user's payment instructions
final userPaymentInstructionsProvider = FutureProvider<List<UserPaymentInstruction>>((ref) async {
  final service = ref.watch(hodlHodlServiceProvider);
  final data = await service.getMyPaymentInstructions();
  return data.map((e) => UserPaymentInstruction.fromJson(e)).toList();
});

/// Provider for available payment methods
final availablePaymentMethodsProvider = FutureProvider<List<PaymentMethodOption>>((ref) async {
  final service = ref.watch(hodlHodlServiceProvider);
  final data = await service.getPaymentMethods();
  return data.map((e) => PaymentMethodOption.fromJson(e)).toList();
});

/// Provider for user's offers
final userOffersProvider = FutureProvider<List<dynamic>>((ref) async {
  final service = ref.watch(hodlHodlServiceProvider);
  return service.getMyOffers();
});

/// Create offer form state notifier
class CreateOfferFormNotifier extends StateNotifier<CreateOfferFormState> {
  final HodlHodlService _service;

  CreateOfferFormNotifier(this._service) : super(const CreateOfferFormState());

  void setSide(OfferSide side) {
    state = state.copyWith(side: side);
  }

  void setRateType(RateType rateType) {
    state = state.copyWith(rateType: rateType);
  }

  void setExchangeSource(ExchangeSource source) {
    state = state.copyWith(exchangeSource: source);
  }

  void setCurrency(CurrencyOption currency) {
    state = state.copyWith(currency: currency);
  }

  void setMargin(double margin) {
    state = state.copyWith(margin: margin);
  }

  void setAmountType(AmountType type) {
    state = state.copyWith(amountType: type);
  }

  void setFixedAmount(double? amount) {
    state = state.copyWith(fixedAmount: amount);
  }

  void setMinAmount(double? amount) {
    state = state.copyWith(minAmount: amount);
  }

  void setMaxAmount(double? amount) {
    state = state.copyWith(maxAmount: amount);
  }

  void setFirstTradeLimit(double? limit) {
    state = state.copyWith(firstTradeLimit: limit);
  }

  void addPaymentInstruction(String instructionId) {
    if (!state.selectedPaymentInstructionIds.contains(instructionId)) {
      state = state.copyWith(
        selectedPaymentInstructionIds: [...state.selectedPaymentInstructionIds, instructionId],
      );
    }
  }

  void removePaymentInstruction(String instructionId) {
    state = state.copyWith(
      selectedPaymentInstructionIds: state.selectedPaymentInstructionIds
          .where((id) => id != instructionId)
          .toList(),
    );
  }

  void setCountryCode(String? code) {
    state = state.copyWith(countryCode: code);
  }

  void setIs24Hours(bool is24Hours) {
    state = state.copyWith(is24Hours: is24Hours);
  }

  void setWorkingHours(String? from, String? to) {
    state = state.copyWith(
      workingHoursFrom: from,
      workingHoursTo: to,
      is24Hours: false,
    );
  }

  void setWorkdaysOnly(bool workdaysOnly) {
    state = state.copyWith(workdaysOnly: workdaysOnly);
  }

  void setPaymentWindowMinutes(int minutes) {
    state = state.copyWith(paymentWindowMinutes: minutes);
  }

  void setConfirmations(int confirmations) {
    state = state.copyWith(confirmations: confirmations);
  }

  void setTitle(String? title) {
    state = state.copyWith(title: title);
  }

  void setDescription(String? description) {
    state = state.copyWith(description: description);
  }

  void setEnabledAfterCreation(bool enabled) {
    state = state.copyWith(enabledAfterCreation: enabled);
  }

  void setIsPrivate(bool isPrivate) {
    state = state.copyWith(isPrivate: isPrivate);
  }

  void reset() {
    state = const CreateOfferFormState();
  }

  /// Submit the offer to Hodl Hodl
  Future<dynamic> submitOffer() async {
    if (!state.isValid) {
      throw Exception(state.validationError);
    }

    return _service.createOffer(
      side: state.side.value,
      currencyCode: state.currency.code,
      paymentMethodInstructionIds: state.selectedPaymentInstructionIds,
      countryCode: state.countryCode,
      rateSource: state.exchangeSource.id,
      marginType: state.rateType == RateType.fixed ? 'fixed' : 'percentage',
      margin: state.margin,
      minAmount: state.amountType == AmountType.range ? state.minAmount : null,
      maxAmount: state.amountType == AmountType.range ? state.maxAmount : null,
      fixedAmount: state.amountType == AmountType.fixed ? state.fixedAmount : null,
      firstTradeLimit: state.firstTradeLimit,
      paymentWindowMinutes: state.paymentWindowMinutes,
      confirmations: state.confirmations,
      title: state.title,
      description: state.description,
      enabled: state.enabledAfterCreation,
      isPrivate: state.isPrivate,
      is24Hours: state.is24Hours,
      workingHoursFrom: state.workingHoursFrom,
      workingHoursTo: state.workingHoursTo,
      workdaysOnly: state.workdaysOnly,
    );
  }
}

/// Provider for the create offer form
final createOfferFormProvider = StateNotifierProvider<CreateOfferFormNotifier, CreateOfferFormState>((ref) {
  final service = ref.watch(hodlHodlServiceProvider);
  return CreateOfferFormNotifier(service);
});

/// Provider for creating a new payment instruction
final createPaymentInstructionProvider = FutureProvider.family<Map<String, dynamic>, CreatePaymentInstructionParams>(
  (ref, params) async {
    final service = ref.watch(hodlHodlServiceProvider);
    return service.createPaymentInstruction(
      paymentMethodId: params.paymentMethodId,
      name: params.name,
      details: params.details,
    );
  },
);

/// Parameters for creating payment instruction
class CreatePaymentInstructionParams {
  final String paymentMethodId;
  final String name;
  final String details;

  const CreatePaymentInstructionParams({
    required this.paymentMethodId,
    required this.name,
    required this.details,
  });
}
