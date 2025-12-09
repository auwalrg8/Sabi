import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/services/rate_service.dart';

/// Provider for BTC to NGN exchange rate
final btcToNgnRateProvider = FutureProvider<double>((ref) async {
  return await RateService.getBtcToNgnRate();
});

/// Provider that refreshes the rate
final rateRefreshProvider = StateProvider<int>((ref) => 0);

/// Auto-refreshing rate provider (refreshes every 5 minutes)
final autoRefreshRateProvider = StreamProvider<double>((ref) async* {
  while (true) {
    yield await RateService.getBtcToNgnRate();
    await Future.delayed(const Duration(minutes: 5));
  }
});
