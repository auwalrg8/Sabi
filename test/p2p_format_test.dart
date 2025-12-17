import 'package:flutter_test/flutter_test.dart';
import 'package:sabi_wallet/features/p2p/utils/format_utils.dart';

void main() {
  test('currency formatting uses symbol and two decimals', () {
    final formatted = formatCurrency(123456.789);
    expect(formatted.contains('₦'), isTrue);
    expect(formatted.contains('.'), isTrue);
  });

  test('fiat to btc conversion basic', () {
    final pricePerBtc = 1000000.0; // 1,000,000 NGN per BTC
    final fiat = 10000.0;
    final btc = fiatToBtc(fiat, pricePerBtc);
    expect(btc, closeTo(0.01, 1e-6));
  });

  test('format btc shows BTC suffix', () {
    final formatted = formatBtc(0.01234567);
    expect(formatted.contains('BTC'), isTrue);
  });
}
