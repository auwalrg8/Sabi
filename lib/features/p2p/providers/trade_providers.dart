import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:sabi_wallet/features/p2p/data/trade_model.dart';
import 'package:sabi_wallet/features/p2p/data/p2p_offer_model.dart';
import 'p2p_providers.dart';

const _uuid = Uuid();

// My trades provider
class MyTradesNotifier extends StateNotifier<List<TradeModel>> {
  MyTradesNotifier() : super([]);

  void addTrade(TradeModel trade) {
    state = [trade, ...state];
  }

  void updateTrade(String id, TradeModel updatedTrade) {
    state = state.map((t) => t.id == id ? updatedTrade : t).toList();
  }

  void removeTrade(String id) {
    state = state.where((t) => t.id != id).toList();
  }

  TradeModel? getTrade(String id) {
    try {
      return state.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }
}

final myTradesProvider =
    StateNotifierProvider<MyTradesNotifier, List<TradeModel>>((ref) {
      return MyTradesNotifier();
    });

// Current trade state
class TradeNotifier extends StateNotifier<TradeModel> {
  final Ref ref;

  TradeNotifier(super.initial, this.ref);

  void updatePayAmount(double amount) {
    final receiveSats = amount / state.offer.pricePerBtc * 100000000;
    state = state.copyWith(payAmount: amount, receiveSats: receiveSats);
  }

  void addProof(String path) {
    final newProofs = List<String>.from(state.proofs)..add(path);
    state = state.copyWith(
      proofs: newProofs,
      status: TradeStatus.paid,
      paidAt: DateTime.now(),
    );
  }

  void confirmPaymentWithProof(String path) {
    addProof(path);
  }

  void startTrade() {
    state = state.copyWith(
      status: TradeStatus.awaitingPayment,
      timeLeftSeconds: 900, // 15 minutes
    );
    ref.read(myTradesProvider.notifier).addTrade(state);
  }

  void markPaid() {
    state = state.copyWith(status: TradeStatus.paid, paidAt: DateTime.now());
    ref.read(myTradesProvider.notifier).updateTrade(state.id, state);
  }

  void release() {
    if (state.status == TradeStatus.paid) {
      state = state.copyWith(
        status: TradeStatus.released,
        releasedAt: DateTime.now(),
      );
      ref.read(myTradesProvider.notifier).updateTrade(state.id, state);
    }
  }

  void dispute(String reason) {
    state = state.copyWith(status: TradeStatus.disputed);
    ref.read(myTradesProvider.notifier).updateTrade(state.id, state);
  }

  void cancel() {
    state = state.copyWith(status: TradeStatus.cancelled);
    ref.read(myTradesProvider.notifier).updateTrade(state.id, state);
  }
}

final tradeProvider =
    StateNotifierProvider.family<TradeNotifier, TradeModel, String>((
      ref,
      offerId,
    ) {
      final offers = ref.read(p2pOffersProvider);
      final offer = offers.firstWhere(
        (o) => o.id == offerId,
        orElse:
            () => P2POfferModel(
              id: offerId,
              name: 'Unknown',
              pricePerBtc: 131448939.22,
              paymentMethod: 'Unknown',
              eta: '-',
              ratingPercent: 0,
              trades: 0,
              minLimit: 0,
              maxLimit: 0,
            ),
      );

      final trade = TradeModel(
        id: _uuid.v4(),
        offer: offer,
        payAmount: 0,
        receiveSats: 0,
      );

      return TradeNotifier(trade, ref);
    });

// Create offer state
class CreateOfferState {
  final OfferType type;
  final double marginPercent;
  final double availableSats;
  final List<String> selectedPaymentMethods;
  final bool requiresKyc;

  CreateOfferState({
    this.type = OfferType.sell,
    this.marginPercent = 0.0,
    this.availableSats = 0.0,
    this.selectedPaymentMethods = const [],
    this.requiresKyc = false,
  });

  CreateOfferState copyWith({
    OfferType? type,
    double? marginPercent,
    double? availableSats,
    List<String>? selectedPaymentMethods,
    bool? requiresKyc,
  }) {
    return CreateOfferState(
      type: type ?? this.type,
      marginPercent: marginPercent ?? this.marginPercent,
      availableSats: availableSats ?? this.availableSats,
      selectedPaymentMethods:
          selectedPaymentMethods ?? this.selectedPaymentMethods,
      requiresKyc: requiresKyc ?? this.requiresKyc,
    );
  }

  double calculateRate(double marketRate) {
    return marketRate * (1 + (marginPercent / 100));
  }
}

class CreateOfferNotifier extends StateNotifier<CreateOfferState> {
  CreateOfferNotifier() : super(CreateOfferState());

  void setType(OfferType type) {
    state = state.copyWith(type: type);
  }

  void setMargin(double margin) {
    state = state.copyWith(marginPercent: margin);
  }

  void setAvailableSats(double sats) {
    state = state.copyWith(availableSats: sats);
  }

  void togglePaymentMethod(String methodId) {
    final methods = List<String>.from(state.selectedPaymentMethods);
    if (methods.contains(methodId)) {
      methods.remove(methodId);
    } else {
      methods.add(methodId);
    }
    state = state.copyWith(selectedPaymentMethods: methods);
  }

  void setRequiresKyc(bool value) {
    state = state.copyWith(requiresKyc: value);
  }

  void reset() {
    state = CreateOfferState();
  }
}

final createOfferProvider =
    StateNotifierProvider<CreateOfferNotifier, CreateOfferState>((ref) {
      return CreateOfferNotifier();
    });
