import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:sabi_wallet/features/p2p/data/trade_model.dart';
import 'package:sabi_wallet/features/p2p/data/p2p_offer_model.dart';
import 'p2p_providers.dart';

class TradeNotifier extends StateNotifier<TradeModel> {
  TradeNotifier(super.initial);

  void addProof(String path) {
    final newProofs = List<String>.from(state.proofs)..add(path);
    state = state.copyWith(proofs: newProofs, status: TradeStatus.paid);
  }

  void confirmPaymentWithProof(String path) {
    addProof(path);
  }

  void release() {
    if (state.status == TradeStatus.paid) {
      state = state.copyWith(status: TradeStatus.released);
    }
  }

  void block(String reason) {
    state = state.copyWith(status: TradeStatus.blocked);
  }
}

final _uuid = const Uuid();

final tradeProvider = StateNotifierProvider.family<TradeNotifier, TradeModel, String>((ref, offerId) {
  // Find offer from provider list
  final offers = ref.read(p2pOffersProvider);
  final offer = offers.firstWhere((o) => o.id == offerId, orElse: () => P2POfferModel(
        id: offerId,
        name: 'Unknown',
        pricePerBtc: 1.0,
        paymentMethod: 'Unknown',
        eta: '-',
        ratingPercent: 0,
        trades: 0,
        minLimit: 0,
        maxLimit: 0,
      ));

  final trade = TradeModel(id: _uuid.v4(), offer: offer, payAmount: offer.minLimit.toDouble());
  return TradeNotifier(trade);
});
