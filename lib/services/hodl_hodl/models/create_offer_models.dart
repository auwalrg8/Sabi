/// Models for Hodl Hodl offer creation flow

/// Offer side (buy or sell BTC)
enum OfferSide {
  buy,
  sell;

  String get value => name;
  
  String get displayName {
    switch (this) {
      case OfferSide.buy:
        return 'Buy BTC';
      case OfferSide.sell:
        return 'Sell BTC';
    }
  }

  String get description {
    switch (this) {
      case OfferSide.buy:
        return 'I want to buy Bitcoin';
      case OfferSide.sell:
        return 'I want to sell Bitcoin';
    }
  }
}

/// Rate type for offer pricing
enum RateType {
  floating,
  fixed;

  String get displayName {
    switch (this) {
      case RateType.floating:
        return 'Floating rate';
      case RateType.fixed:
        return 'Fixed rate';
    }
  }

  String get description {
    switch (this) {
      case RateType.floating:
        return 'Price tracks exchange rate';
      case RateType.fixed:
        return 'Price stays constant';
    }
  }
}

/// Amount type for offer
enum AmountType {
  fixed,
  range;

  String get displayName {
    switch (this) {
      case AmountType.fixed:
        return 'Fixed amount';
      case AmountType.range:
        return 'Amount range';
    }
  }
}

/// Exchange source for rate
class ExchangeSource {
  final String id;
  final String name;
  final String? iconUrl;

  const ExchangeSource({
    required this.id,
    required this.name,
    this.iconUrl,
  });

  // Common exchange sources
  static const ExchangeSource binance = ExchangeSource(id: 'binance', name: 'Binance');
  static const ExchangeSource kraken = ExchangeSource(id: 'kraken', name: 'Kraken');
  static const ExchangeSource coinbase = ExchangeSource(id: 'coinbase', name: 'Coinbase');
  static const ExchangeSource bitstamp = ExchangeSource(id: 'bitstamp', name: 'Bitstamp');
  static const ExchangeSource bitfinex = ExchangeSource(id: 'bitfinex', name: 'Bitfinex');

  static const List<ExchangeSource> all = [
    binance,
    kraken,
    coinbase,
    bitstamp,
    bitfinex,
  ];
}

/// Currency option
class CurrencyOption {
  final String code;
  final String name;
  final String symbol;
  final String? flagEmoji;

  const CurrencyOption({
    required this.code,
    required this.name,
    required this.symbol,
    this.flagEmoji,
  });

  // Common currencies
  static const CurrencyOption usd = CurrencyOption(
    code: 'USD',
    name: 'US Dollar',
    symbol: '\$',
    flagEmoji: '🇺🇸',
  );
  static const CurrencyOption ngn = CurrencyOption(
    code: 'NGN',
    name: 'Nigerian Naira',
    symbol: '₦',
    flagEmoji: '🇳🇬',
  );
  static const CurrencyOption eur = CurrencyOption(
    code: 'EUR',
    name: 'Euro',
    symbol: '€',
    flagEmoji: '🇪🇺',
  );
  static const CurrencyOption gbp = CurrencyOption(
    code: 'GBP',
    name: 'British Pound',
    symbol: '£',
    flagEmoji: '🇬🇧',
  );
  static const CurrencyOption usdt = CurrencyOption(
    code: 'USDT',
    name: 'Tether USD',
    symbol: '\$',
  );

  static const List<CurrencyOption> popular = [usd, ngn, eur, gbp, usdt];
}

/// Payment method for offers
class PaymentMethodOption {
  final String id;
  final String type;
  final String name;
  final String? description;
  final String? iconName;

  const PaymentMethodOption({
    required this.id,
    required this.type,
    required this.name,
    this.description,
    this.iconName,
  });

  factory PaymentMethodOption.fromJson(Map<String, dynamic> json) {
    return PaymentMethodOption(
      id: json['id']?.toString() ?? '',
      type: json['type'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PaymentMethodOption && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// User's saved payment instruction
class UserPaymentInstruction {
  final String id;
  final String version;
  final String paymentMethodId;
  final String paymentMethodType;
  final String paymentMethodName;
  final String name;
  final String details;

  const UserPaymentInstruction({
    required this.id,
    required this.version,
    required this.paymentMethodId,
    required this.paymentMethodType,
    required this.paymentMethodName,
    required this.name,
    required this.details,
  });

  factory UserPaymentInstruction.fromJson(Map<String, dynamic> json) {
    return UserPaymentInstruction(
      id: json['id']?.toString() ?? '',
      version: json['version'] ?? '',
      paymentMethodId: json['payment_method_id']?.toString() ?? '',
      paymentMethodType: json['payment_method_type'] ?? '',
      paymentMethodName: json['payment_method_name'] ?? '',
      name: json['name'] ?? '',
      details: json['details'] ?? '',
    );
  }
}

/// State for offer creation form
class CreateOfferFormState {
  final OfferSide side;
  final RateType rateType;
  final ExchangeSource exchangeSource;
  final CurrencyOption currency;
  final double margin; // percentage margin on exchange rate
  final AmountType amountType;
  final double? fixedAmount;
  final double? minAmount;
  final double? maxAmount;
  final double? firstTradeLimit;
  final List<String> selectedPaymentInstructionIds;
  final String? countryCode;
  final bool is24Hours;
  final String? workingHoursFrom;
  final String? workingHoursTo;
  final bool workdaysOnly;
  final int paymentWindowMinutes;
  final int confirmations;
  final String? title;
  final String? description;
  final bool enabledAfterCreation;
  final bool isPrivate;

  const CreateOfferFormState({
    this.side = OfferSide.buy,
    this.rateType = RateType.floating,
    this.exchangeSource = ExchangeSource.binance,
    this.currency = CurrencyOption.usd,
    this.margin = 0,
    this.amountType = AmountType.range,
    this.fixedAmount,
    this.minAmount,
    this.maxAmount,
    this.firstTradeLimit,
    this.selectedPaymentInstructionIds = const [],
    this.countryCode,
    this.is24Hours = true,
    this.workingHoursFrom,
    this.workingHoursTo,
    this.workdaysOnly = false,
    this.paymentWindowMinutes = 90,
    this.confirmations = 1,
    this.title,
    this.description,
    this.enabledAfterCreation = true,
    this.isPrivate = false,
  });

  CreateOfferFormState copyWith({
    OfferSide? side,
    RateType? rateType,
    ExchangeSource? exchangeSource,
    CurrencyOption? currency,
    double? margin,
    AmountType? amountType,
    double? fixedAmount,
    double? minAmount,
    double? maxAmount,
    double? firstTradeLimit,
    List<String>? selectedPaymentInstructionIds,
    String? countryCode,
    bool? is24Hours,
    String? workingHoursFrom,
    String? workingHoursTo,
    bool? workdaysOnly,
    int? paymentWindowMinutes,
    int? confirmations,
    String? title,
    String? description,
    bool? enabledAfterCreation,
    bool? isPrivate,
  }) {
    return CreateOfferFormState(
      side: side ?? this.side,
      rateType: rateType ?? this.rateType,
      exchangeSource: exchangeSource ?? this.exchangeSource,
      currency: currency ?? this.currency,
      margin: margin ?? this.margin,
      amountType: amountType ?? this.amountType,
      fixedAmount: fixedAmount ?? this.fixedAmount,
      minAmount: minAmount ?? this.minAmount,
      maxAmount: maxAmount ?? this.maxAmount,
      firstTradeLimit: firstTradeLimit ?? this.firstTradeLimit,
      selectedPaymentInstructionIds: selectedPaymentInstructionIds ?? this.selectedPaymentInstructionIds,
      countryCode: countryCode ?? this.countryCode,
      is24Hours: is24Hours ?? this.is24Hours,
      workingHoursFrom: workingHoursFrom ?? this.workingHoursFrom,
      workingHoursTo: workingHoursTo ?? this.workingHoursTo,
      workdaysOnly: workdaysOnly ?? this.workdaysOnly,
      paymentWindowMinutes: paymentWindowMinutes ?? this.paymentWindowMinutes,
      confirmations: confirmations ?? this.confirmations,
      title: title ?? this.title,
      description: description ?? this.description,
      enabledAfterCreation: enabledAfterCreation ?? this.enabledAfterCreation,
      isPrivate: isPrivate ?? this.isPrivate,
    );
  }

  /// Check if form is valid for submission
  bool get isValid {
    if (selectedPaymentInstructionIds.isEmpty) return false;
    
    if (amountType == AmountType.fixed) {
      if (fixedAmount == null || fixedAmount! <= 0) return false;
    } else {
      // Range requires at least min or max
      if ((minAmount == null || minAmount! <= 0) && (maxAmount == null || maxAmount! <= 0)) {
        return false;
      }
    }
    
    return true;
  }

  /// Validation error message
  String? get validationError {
    if (selectedPaymentInstructionIds.isEmpty) {
      return 'Please select at least one payment method';
    }
    
    if (amountType == AmountType.fixed) {
      if (fixedAmount == null || fixedAmount! <= 0) {
        return 'Please enter a fixed amount';
      }
    } else {
      if ((minAmount == null || minAmount! <= 0) && (maxAmount == null || maxAmount! <= 0)) {
        return 'Please enter min or max amount';
      }
    }
    
    return null;
  }
}
