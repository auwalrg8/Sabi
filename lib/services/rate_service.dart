import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';

class RateService {
  // Best free API in 2025 — no key needed, unlimited calls
  static const String _url =
      'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/btc.json';
  static const String _boxName = 'app_box';

  static Future<Box> _openAppBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box(_boxName);
    }
    return await Hive.openBox(_boxName);
  }

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
          .get(Uri.parse(_url))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rate = data['btc']['ngn'] as double;
        await box.put('btc_ngn_rate', rate);
        await box.put('rate_timestamp', DateTime.now().millisecondsSinceEpoch);
        return rate;
      }
    } catch (e) {
      print('Rate fetch failed: $e');
    }

    // Fallback rate (today's rate)
    return 130401317.0;
  }

  static const String _usdUrl =
      'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json';

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

    return 1614.0;
  }

  static String formatNaira(double naira) {
    return "₦${naira.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}";
  }

  /// Convert satoshis to BTC
  static double satsToBtc(int sats) {
    return sats / 100000000;
  }

  /// Convert satoshis to NGN using live rate
  static Future<double> satsToNgn(int sats) async {
    final btc = satsToBtc(sats);
    final rate = await getBtcToNgnRate();
    return btc * rate;
  }

  /// Get cached rate synchronously (returns null if not cached)
  static double? getCachedRate() {
    try {
      if (!Hive.isBoxOpen(_boxName)) return null;
      final box = Hive.box(_boxName);
      return box.get('btc_ngn_rate');
    } catch (e) {
      return null;
    }
  }
}
