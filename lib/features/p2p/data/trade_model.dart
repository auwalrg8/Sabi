import 'p2p_offer_model.dart';

enum TradeStatus { created, paid, released, blocked }

class TradeModel {
  final String id;
  final P2POfferModel offer;
  final double payAmount;
  final TradeStatus status;
  final List<String> proofs; // file paths or urls
  final DateTime createdAt;

  TradeModel({
    required this.id,
    required this.offer,
    required this.payAmount,
    this.status = TradeStatus.created,
    List<String>? proofs,
    DateTime? createdAt,
  })  : proofs = proofs ?? [],
        createdAt = createdAt ?? DateTime.now();

  TradeModel copyWith({
    String? id,
    P2POfferModel? offer,
    double? payAmount,
    TradeStatus? status,
    List<String>? proofs,
  }) {
    return TradeModel(
      id: id ?? this.id,
      offer: offer ?? this.offer,
      payAmount: payAmount ?? this.payAmount,
      status: status ?? this.status,
      proofs: proofs ?? this.proofs,
      createdAt: createdAt,
    );
  }
}
