import 'merchant_model.dart';
import 'payment_method_model.dart';

enum OfferType { buy, sell }

class P2POfferModel {
  final String id;
  final String name;
  final double pricePerBtc;
  final String paymentMethod;
  final String eta;
  final int ratingPercent;
  final int trades;
  final int minLimit;
  final int maxLimit;
  final OfferType type;
  final MerchantModel? merchant;
  final List<PaymentMethodModel>? acceptedMethods;
  final double? marginPercent;
  final bool requiresKyc;
  final String? paymentInstructions;
  final double? availableSats;
  final double? lockedSats; // Sats locked in active trades
  final String? responseTime;
  final double? volume;

  P2POfferModel({
    required this.id,
    required this.name,
    required this.pricePerBtc,
    required this.paymentMethod,
    required this.eta,
    required this.ratingPercent,
    required this.trades,
    required this.minLimit,
    required this.maxLimit,
    this.type = OfferType.sell,
    this.merchant,
    this.acceptedMethods,
    this.marginPercent,
    this.requiresKyc = false,
    this.paymentInstructions,
    this.availableSats,
    this.lockedSats,
    this.responseTime,
    this.volume,
  });

  /// Returns the effective available sats (total minus locked)
  double get effectiveAvailableSats => (availableSats ?? 0) - (lockedSats ?? 0);

  P2POfferModel copyWith({
    String? id,
    String? name,
    double? pricePerBtc,
    String? paymentMethod,
    String? eta,
    int? ratingPercent,
    int? trades,
    int? minLimit,
    int? maxLimit,
    OfferType? type,
    MerchantModel? merchant,
    List<PaymentMethodModel>? acceptedMethods,
    double? marginPercent,
    bool? requiresKyc,
    String? paymentInstructions,
    double? availableSats,
    double? lockedSats,
    String? responseTime,
    double? volume,
  }) {
    return P2POfferModel(
      id: id ?? this.id,
      name: name ?? this.name,
      pricePerBtc: pricePerBtc ?? this.pricePerBtc,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      eta: eta ?? this.eta,
      ratingPercent: ratingPercent ?? this.ratingPercent,
      trades: trades ?? this.trades,
      minLimit: minLimit ?? this.minLimit,
      maxLimit: maxLimit ?? this.maxLimit,
      type: type ?? this.type,
      merchant: merchant ?? this.merchant,
      acceptedMethods: acceptedMethods ?? this.acceptedMethods,
      marginPercent: marginPercent ?? this.marginPercent,
      requiresKyc: requiresKyc ?? this.requiresKyc,
      paymentInstructions: paymentInstructions ?? this.paymentInstructions,
      availableSats: availableSats ?? this.availableSats,
      lockedSats: lockedSats ?? this.lockedSats,
      responseTime: responseTime ?? this.responseTime,
      volume: volume ?? this.volume,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'pricePerBtc': pricePerBtc,
      'paymentMethod': paymentMethod,
      'eta': eta,
      'ratingPercent': ratingPercent,
      'trades': trades,
      'minLimit': minLimit,
      'maxLimit': maxLimit,
      'type': type.index,
      'merchantId': merchant?.id,
      'marginPercent': marginPercent,
      'requiresKyc': requiresKyc,
      'paymentInstructions': paymentInstructions,
      'availableSats': availableSats,
      'lockedSats': lockedSats,
      'responseTime': responseTime,
      'volume': volume,
    };
  }

  factory P2POfferModel.fromJson(
    Map<String, dynamic> json, {
    MerchantModel? merchant,
    List<PaymentMethodModel>? acceptedMethods,
  }) {
    return P2POfferModel(
      id: json['id'] as String,
      name: json['name'] as String,
      pricePerBtc: (json['pricePerBtc'] as num).toDouble(),
      paymentMethod: json['paymentMethod'] as String? ?? 'Unknown',
      eta: json['eta'] as String? ?? '-',
      ratingPercent: json['ratingPercent'] as int? ?? 100,
      trades: json['trades'] as int? ?? 0,
      minLimit: json['minLimit'] as int? ?? 0,
      maxLimit: json['maxLimit'] as int? ?? 0,
      type: OfferType.values[(json['type'] as int?) ?? OfferType.sell.index],
      merchant: merchant,
      acceptedMethods: acceptedMethods,
      marginPercent: (json['marginPercent'] as num?)?.toDouble(),
      requiresKyc: json['requiresKyc'] as bool? ?? false,
      paymentInstructions: json['paymentInstructions'] as String?,
      availableSats: (json['availableSats'] as num?)?.toDouble(),
      lockedSats: (json['lockedSats'] as num?)?.toDouble(),
      responseTime: json['responseTime'] as String?,
      volume: (json['volume'] as num?)?.toDouble(),
    );
  }
}
