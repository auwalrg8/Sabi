import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';

/// Supported fiat currencies for conversion
enum FiatCurrency {
  ngn('NGN', '₦', 'Nigerian Naira'),
  usd('USD', '\$', 'US Dollar');

  final String code;
  final String symbol;
  final String name;
  const FiatCurrency(this.code, this.symbol, this.name);

  static FiatCurrency fromCode(String code) {
    return FiatCurrency.values.firstWhere(
      (c) => c.code == code,
      orElse: () => FiatCurrency.ngn,
    );
  }
}

class RateService {
  // Best free API in 2025 — no key needed, unlimited calls
  static const String _btcUrl =
      'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/btc.json';
  static const String _boxName = 'app_box';

  // Fallback rates (updated periodically)
  static const double _fallbackBtcNgn = 156000000.0; // ~$100k * 1560 NGN/USD
  static const double _fallbackBtcUsd = 100000.0;
  static const double _fallbackUsdNgn = 1560.0;

  static Future<Box> _openAppBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box(_boxName);
    }
    return await Hive.openBox(_boxName);
  }

  /// Get BTC to NGN rate with 5-minute caching
  static Future<double> getBtcToNgnRate() async {
    final box = await _openAppBox();
    final cached = box.get('btc_ngn_rate');
    final lastUpdate = box.get('rate_timestamp');

    // Use cached rate if less than 5 minutes old
    if (cached != null && lastUpdate != null) {
      final minutesAgo =
          DateTime.now()
              .difference(DateTime.fromMillisecondsSinceEpoch(lastUpdate))
              .inMinutes;
      if (minutesAgo < 5) return cached;
    }

    try {
      final response = await http
          .get(Uri.parse(_btcUrl))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rate = (data['btc']['ngn'] as num).toDouble();
        await box.put('btc_ngn_rate', rate);
        await box.put('rate_timestamp', DateTime.now().millisecondsSinceEpoch);
        return rate;
      }
    } catch (e) {
      print('Rate fetch failed: $e');
    }

    return cached ?? _fallbackBtcNgn;
  }

  /// Get BTC to USD rate with 5-minute caching
  static Future<double> getBtcToUsdRate() async {
    final box = await _openAppBox();
    final cached = box.get('btc_usd_rate');
    final lastUpdate = box.get('rate_timestamp_btc_usd');

    if (cached != null && lastUpdate != null) {
      final minutesAgo = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(lastUpdate))
          .inMinutes;
      if (minutesAgo < 5) return cached;
    }

    try {
      final response = await http
          .get(Uri.parse(_btcUrl))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rate = (data['btc']['usd'] as num).toDouble();
        await box.put('btc_usd_rate', rate);
        await box.put('rate_timestamp_btc_usd', DateTime.now().millisecondsSinceEpoch);
        return rate;
      }
    } catch (e) {
      print('BTC/USD rate fetch failed: $e');
    }

    return cached ?? _fallbackBtcUsd;
  }

  static const String _usdUrl =
      'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json';

  /// Get USD to NGN rate with 5-minute caching
  static Future<double> getUsdToNgnRate() async {
    final box = await _openAppBox();
    final cached = box.get('usd_ngn_rate');
    final lastUpdate = box.get('rate_timestamp_usd');

    if (cached != null && lastUpdate != null) {
      final minutesAgo =
          DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastUpdate)).inMinutes;
      if (minutesAgo < 5) return cached;
    }

    try {
      final response = await http.get(Uri.parse(_usdUrl)).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rate = (data['usd']['ngn'] as num).toDouble();
        await box.put('usd_ngn_rate', rate);
        await box.put('rate_timestamp_usd', DateTime.now().millisecondsSinceEpoch);
        return rate;
      }
    } catch (e) {
      print('USD rate fetch failed: $e');
    }

    return cached ?? _fallbackUsdNgn;
  }

  /// Get BTC rate for the specified fiat currency
  static Future<double> getBtcToFiatRate(FiatCurrency currency) async {
    switch (currency) {
      case FiatCurrency.ngn:
        return getBtcToNgnRate();
      case FiatCurrency.usd:
        return getBtcToUsdRate();
    }
  }

  /// Format amount in the specified fiat currency
  static String formatFiat(double amount, FiatCurrency currency) {
    final formatted = amount.toStringAsFixed(currency == FiatCurrency.usd ? 2 : 0)
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return '${currency.symbol}$formatted';
  }

  /// Format Naira amount
  static String formatNaira(double naira) {
    return "₦${naira.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}";
  }

  /// Format USD amount
  static String formatUsd(double usd) {
    return "\$${usd.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}";
  }

  /// Convert satoshis to BTC
  static double satsToBtc(int sats) {
    return sats / 100000000;
  }

  /// Convert satoshis to fiat using the specified currency
  static Future<double> satsToFiat(int sats, FiatCurrency currency) async {
    final btc = satsToBtc(sats);
    final rate = await getBtcToFiatRate(currency);
    return btc * rate;
  }

  /// Convert satoshis to NGN using live rate
  static Future<double> satsToNgn(int sats) async {
    final btc = satsToBtc(sats);
    final rate = await getBtcToNgnRate();
    return btc * rate;
  }

  /// Convert satoshis to USD using live rate
  static Future<double> satsToUsd(int sats) async {
    final btc = satsToBtc(sats);
    final rate = await getBtcToUsdRate();
    return btc * rate;
  }

  /// Get cached BTC/NGN rate synchronously (returns null if not cached)
  static double? getCachedRate() {
    try {
      if (!Hive.isBoxOpen(_boxName)) return null;
      final box = Hive.box(_boxName);
      return box.get('btc_ngn_rate');
    } catch (e) {
      return null;
    }
  }

  /// Get cached BTC/USD rate synchronously (returns null if not cached)
  static double? getCachedUsdRate() {
    try {
      if (!Hive.isBoxOpen(_boxName)) return null;
      final box = Hive.box(_boxName);
      return box.get('btc_usd_rate');
    } catch (e) {
      return null;
    }
  }

  /// Get cached rate for specified currency
  static double? getCachedFiatRate(FiatCurrency currency) {
    switch (currency) {
      case FiatCurrency.ngn:
        return getCachedRate();
      case FiatCurrency.usd:
        return getCachedUsdRate();
    }
  }
}
