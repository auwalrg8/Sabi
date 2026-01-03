import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/services/rate_service.dart';
import 'package:sabi_wallet/features/profile/presentation/providers/settings_provider.dart';

/// Provider for BTC to NGN exchange rate
final btcToNgnRateProvider = FutureProvider<double>((ref) async {
  return await RateService.getBtcToNgnRate();
});

/// Provider for BTC to USD exchange rate
final btcToUsdRateProvider = FutureProvider<double>((ref) async {
  return await RateService.getBtcToUsdRate();
});

/// Provider for USD to NGN exchange rate
final usdToNgnRateProvider = FutureProvider<double>((ref) async {
  return await RateService.getUsdToNgnRate();
});

/// Provider that refreshes the rate
final rateRefreshProvider = StateProvider<int>((ref) => 0);

/// Provider for the current fiat currency setting
final selectedFiatCurrencyProvider = Provider<FiatCurrency>((ref) {
  final settings = ref.watch(settingsNotifierProvider);
  return FiatCurrency.fromCode(settings.currency);
});

/// Provider for BTC to current fiat currency rate
final btcToFiatRateProvider = FutureProvider<double>((ref) async {
  final currency = ref.watch(selectedFiatCurrencyProvider);
  return await RateService.getBtcToFiatRate(currency);
});

/// Convert sats to fiat in the user's selected currency
final satsToFiatProvider = FutureProvider.family<double, int>((ref, sats) async {
  final currency = ref.watch(selectedFiatCurrencyProvider);
  return await RateService.satsToFiat(sats, currency);
});

/// Format sats as fiat string in user's selected currency
final formattedFiatProvider = FutureProvider.family<String, int>((ref, sats) async {
  final currency = ref.watch(selectedFiatCurrencyProvider);
  final fiatAmount = await RateService.satsToFiat(sats, currency);
  return RateService.formatFiat(fiatAmount, currency);
});

/// Auto-refreshing rate provider (refreshes every 5 minutes)
final autoRefreshRateProvider = StreamProvider<double>((ref) async* {
  while (true) {
    yield await RateService.getBtcToNgnRate();
    await Future.delayed(const Duration(minutes: 5));
  }
});

/// Auto-refreshing fiat rate provider based on selected currency
final autoRefreshFiatRateProvider = StreamProvider<double>((ref) async* {
  final currency = ref.watch(selectedFiatCurrencyProvider);
  while (true) {
    yield await RateService.getBtcToFiatRate(currency);
    await Future.delayed(const Duration(minutes: 5));
  }
});
