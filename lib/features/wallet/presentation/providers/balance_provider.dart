import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';

/// Direct balance provider that fetches from Breez SDK
final balanceProvider = FutureProvider<int>((ref) async {
  try {
    return await BreezSparkService.getBalance();
  } catch (e) {
    return 0;
  }
});

/// Provider to manually refresh balance with loading state
final balanceNotifierProvider = StateNotifierProvider<BalanceNotifier, AsyncValue<int>>((ref) {
  return BalanceNotifier();
});

class BalanceNotifier extends StateNotifier<AsyncValue<int>> {
  BalanceNotifier() : super(const AsyncValue.loading()) {
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    try {
      final balance = await BreezSparkService.getBalance();
      state = AsyncValue.data(balance);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> refresh() async {
    await _loadBalance();
  }
}
