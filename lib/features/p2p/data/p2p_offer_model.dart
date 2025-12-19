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
    this.responseTime,
    this.volume,
  });

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
      responseTime: responseTime ?? this.responseTime,
      volume: volume ?? this.volume,
    );
  }
}
