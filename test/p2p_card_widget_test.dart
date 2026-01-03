import 'package:flutter_test/flutter_test.dart';
import 'package:sabi_wallet/features/p2p/data/p2p_offer_model.dart';

void main() {
  group('P2POfferModel', () {
    test('creates sell offer with correct properties', () {
      final offer = P2POfferModel(
        id: 'test-1',
        name: 'Test Merchant',
        pricePerBtc: 95000000,
        paymentMethod: 'Bank Transfer',
        eta: '15 min',
        ratingPercent: 98,
        trades: 500,
        minLimit: 10000,
        maxLimit: 1000000,
        type: OfferType.sell,
      );

      expect(offer.id, equals('test-1'));
      expect(offer.name, equals('Test Merchant'));
      expect(offer.pricePerBtc, equals(95000000));
      expect(offer.type, equals(OfferType.sell));
      expect(offer.ratingPercent, equals(98));
      expect(offer.trades, equals(500));
    });

    test('creates buy offer with correct type', () {
      final offer = P2POfferModel(
        id: 'buy-1',
        name: 'BTC Buyer',
        pricePerBtc: 94000000,
        paymentMethod: 'Mobile Money',
        eta: '10 min',
        ratingPercent: 95,
        trades: 300,
        minLimit: 5000,
        maxLimit: 500000,
        type: OfferType.buy,
      );

      expect(offer.type, equals(OfferType.buy));
      expect(offer.paymentMethod, equals('Mobile Money'));
    });

    test('effectiveAvailableSats calculates correctly', () {
      final offer = P2POfferModel(
        id: 'test-2',
        name: 'Trader',
        pricePerBtc: 90000000,
        paymentMethod: 'Bank',
        eta: '5 min',
        ratingPercent: 100,
        trades: 1000,
        minLimit: 1000,
        maxLimit: 100000,
        availableSats: 1000000,
        lockedSats: 250000,
      );

      expect(offer.effectiveAvailableSats, equals(750000));
    });

    test('copyWith creates correct copy', () {
      final original = P2POfferModel(
        id: 'orig',
        name: 'Original',
        pricePerBtc: 80000000,
        paymentMethod: 'Wire',
        eta: '30 min',
        ratingPercent: 90,
        trades: 100,
        minLimit: 10000,
        maxLimit: 1000000,
      );

      final copy = original.copyWith(name: 'Updated Name', ratingPercent: 99);

      expect(copy.id, equals('orig'));
      expect(copy.name, equals('Updated Name'));
      expect(copy.ratingPercent, equals(99));
      expect(copy.pricePerBtc, equals(80000000)); // unchanged
    });
  });
}
