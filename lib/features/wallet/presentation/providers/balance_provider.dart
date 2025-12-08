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

/// Provider to manually refresh balance
final balanceNotifierProvider = StateNotifierProvider<BalanceNotifier, int>((ref) {
  return BalanceNotifier();
});

class BalanceNotifier extends StateNotifier<int> {
  BalanceNotifier() : super(0) {
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    try {
      final balance = await BreezSparkService.getBalance();
      state = balance;
    } catch (e) {
      state = 0;
    }
  }

  Future<void> refresh() async {
    await _loadBalance();
  }
}
