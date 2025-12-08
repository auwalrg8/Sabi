import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';

/// StateNotifier for recent transactions that can be manually refreshed
class RecentTransactionsNotifier extends StateNotifier<AsyncValue<List<PaymentRecord>>> {
  RecentTransactionsNotifier() : super(const AsyncValue.loading()) {
    refresh();
  }

  /// Fetch recent transactions directly from Breez SDK
  Future<void> refresh() async {
    try {
      state = const AsyncValue.loading();
      final payments = await BreezSparkService.listPayments(limit: 10);
      state = AsyncValue.data(payments);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

/// StateNotifier for all transactions that can be manually refreshed
class AllTransactionsNotifier extends StateNotifier<AsyncValue<List<PaymentRecord>>> {
  AllTransactionsNotifier() : super(const AsyncValue.loading()) {
    refresh();
  }

  /// Fetch all transactions directly from Breez SDK
  Future<void> refresh() async {
    try {
      state = const AsyncValue.loading();
      final payments = await BreezSparkService.listPayments();
      state = AsyncValue.data(payments);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

/// Provider for recent transactions with manual refresh capability
final recentTransactionsProvider = StateNotifierProvider<RecentTransactionsNotifier, AsyncValue<List<PaymentRecord>>>((ref) {
  return RecentTransactionsNotifier();
});

/// Provider for all transactions with manual refresh capability
final allTransactionsNotifierProvider = StateNotifierProvider<AllTransactionsNotifier, AsyncValue<List<PaymentRecord>>>((ref) {
  return AllTransactionsNotifier();
});
