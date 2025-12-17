import 'package:intl/intl.dart';

String formatCurrency(double amount, {String locale = 'en_NG', String symbol = '₦'}) {
  final formatter = NumberFormat.currency(locale: locale, symbol: symbol, decimalDigits: 2);
  return formatter.format(amount);
}

String formatBtc(double btc, {int decimals = 8}) {
  final formatter = NumberFormat('###,##0.${List.filled(decimals, '0').join()}');
  return '${formatter.format(btc)} BTC';
}

double fiatToBtc(double fiatAmount, double pricePerBtc) {
  if (pricePerBtc == 0) return 0.0;
  return fiatAmount / pricePerBtc;
}
