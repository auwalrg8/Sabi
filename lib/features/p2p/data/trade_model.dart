import 'p2p_offer_model.dart';

enum TradeStatus {
  created,
  awaitingPayment,
  paid,
  releasing,
  released,
  disputed,
  cancelled,
  blocked
}

class TradeModel {
  final String id;
  final P2POfferModel offer;
  final double payAmount;
  final TradeStatus status;
  final List<String> proofs;
  final DateTime createdAt;
  final DateTime? paidAt;
  final DateTime? releasedAt;
  final int? timeLeftSeconds;
  final double? receiveSats;

  TradeModel({
    required this.id,
    required this.offer,
    required this.payAmount,
    this.status = TradeStatus.created,
    List<String>? proofs,
    DateTime? createdAt,
    this.paidAt,
    this.releasedAt,
    this.timeLeftSeconds,
    this.receiveSats,
  })  : proofs = proofs ?? [],
        createdAt = createdAt ?? DateTime.now();

  TradeModel copyWith({
    String? id,
    P2POfferModel? offer,
    double? payAmount,
    TradeStatus? status,
    List<String>? proofs,
    DateTime? paidAt,
    DateTime? releasedAt,
    int? timeLeftSeconds,
    double? receiveSats,
  }) {
    return TradeModel(
      id: id ?? this.id,
      offer: offer ?? this.offer,
      payAmount: payAmount ?? this.payAmount,
      status: status ?? this.status,
      proofs: proofs ?? this.proofs,
      createdAt: createdAt,
      paidAt: paidAt ?? this.paidAt,
      releasedAt: releasedAt ?? this.releasedAt,
      timeLeftSeconds: timeLeftSeconds ?? this.timeLeftSeconds,
      receiveSats: receiveSats ?? this.receiveSats,
    );
  }

  String get statusText {
    switch (status) {
      case TradeStatus.created:
        return 'Created';
      case TradeStatus.awaitingPayment:
        return 'Awaiting Payment';
      case TradeStatus.paid:
        return 'Paid';
      case TradeStatus.releasing:
        return 'Releasing soon';
      case TradeStatus.released:
        return 'Released';
      case TradeStatus.disputed:
        return 'Disputed';
      case TradeStatus.cancelled:
        return 'Cancelled';
      case TradeStatus.blocked:
        return 'Blocked';
    }
  }
}
