import 'package:flutter_test/flutter_test.dart';
import 'package:sabi_wallet/features/p2p/data/p2p_offer_model.dart';

void main() {
  group('P2P Offer Types', () {
    test('sell offer has OfferType.sell', () {
      final sellOffer = P2POfferModel(
        id: 'sell-1',
        name: 'BTC Seller',
        pricePerBtc: 95000000,
        paymentMethod: 'Bank Transfer',
        eta: '15 min',
        ratingPercent: 98,
        trades: 500,
        minLimit: 50000,
        maxLimit: 5000000,
        type: OfferType.sell,
      );

      expect(sellOffer.type, equals(OfferType.sell));
      expect(sellOffer.name, equals('BTC Seller'));
    });

    test('buy offer has OfferType.buy', () {
      final buyOffer = P2POfferModel(
        id: 'buy-1',
        name: 'BTC Buyer',
        pricePerBtc: 94000000,
        paymentMethod: 'Bank Transfer',
        eta: '10 min',
        ratingPercent: 95,
        trades: 300,
        minLimit: 10000,
        maxLimit: 2000000,
        type: OfferType.buy,
      );

      expect(buyOffer.type, equals(OfferType.buy));
      expect(buyOffer.pricePerBtc, equals(94000000));
    });

    test('can filter offers by type', () {
      final offers = [
        P2POfferModel(
          id: 's1',
          name: 'Seller 1',
          pricePerBtc: 95000000,
          paymentMethod: 'Bank',
          eta: '15 min',
          ratingPercent: 98,
          trades: 500,
          minLimit: 10000,
          maxLimit: 1000000,
          type: OfferType.sell,
        ),
        P2POfferModel(
          id: 'b1',
          name: 'Buyer 1',
          pricePerBtc: 94000000,
          paymentMethod: 'Cash',
          eta: '10 min',
          ratingPercent: 90,
          trades: 200,
          minLimit: 5000,
          maxLimit: 500000,
          type: OfferType.buy,
        ),
        P2POfferModel(
          id: 's2',
          name: 'Seller 2',
          pricePerBtc: 96000000,
          paymentMethod: 'Mobile',
          eta: '20 min',
          ratingPercent: 99,
          trades: 1000,
          minLimit: 20000,
          maxLimit: 2000000,
          type: OfferType.sell,
        ),
      ];

      final sellOffers = offers.where((o) => o.type == OfferType.sell).toList();
      final buyOffers = offers.where((o) => o.type == OfferType.buy).toList();

      expect(sellOffers.length, equals(2));
      expect(buyOffers.length, equals(1));
    });
  });

  group('P2P Offer limits', () {
    test('minLimit and maxLimit are correct', () {
      final offer = P2POfferModel(
        id: 'test',
        name: 'Test',
        pricePerBtc: 100000,
        paymentMethod: 'PayPal',
        eta: '5 min',
        ratingPercent: 100,
        trades: 1000,
        minLimit: 100,
        maxLimit: 10000,
      );

      expect(offer.minLimit, equals(100));
      expect(offer.maxLimit, equals(10000));
      expect(offer.maxLimit > offer.minLimit, isTrue);
    });
  });
}
