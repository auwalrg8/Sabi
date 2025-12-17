class P2POfferModel {
  final String id;
  final String name;
  final double pricePerBtc; // in fiat (NGN)
  final String paymentMethod;
  final String eta;
  final int ratingPercent;
  final int trades;
  final int minLimit;
  final int maxLimit;

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
  });
}
