import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/features/p2p/data/p2p_offer_model.dart';

final p2pOffersProvider = Provider<List<P2POfferModel>>((ref) {
  // Simple mocked list for tests and UI preview
  return List.generate(
    6,
    (i) => P2POfferModel(
      id: 'offer_$i',
      name: i % 2 == 0 ? 'Mubarak' : 'Almohad',
      pricePerBtc: 131448939.22 + i * 1500,
      paymentMethod: i % 2 == 0 ? 'GTBank' : 'Moniepoint',
      eta: i % 2 == 0 ? '5–15 min' : '3–10 min',
      ratingPercent: i % 2 == 0 ? 98 : 99,
      trades: i % 2 == 0 ? 1247 : 2156,
      minLimit: i % 2 == 0 ? 50000 : 100000,
      maxLimit: i % 2 == 0 ? 8000000 : 5000000,
    ),
  );
});
