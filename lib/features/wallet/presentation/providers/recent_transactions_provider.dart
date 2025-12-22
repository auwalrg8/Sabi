import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';

/// StateNotifier for recent transactions that can be manually refreshed
class RecentTransactionsNotifier
    extends StateNotifier<AsyncValue<List<PaymentRecord>>> {
  Timer? _autoRefreshTimer;

  RecentTransactionsNotifier() : super(const AsyncValue.data([])) {
    // Start auto-refresh timer
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (BreezSparkService.isInitialized) {
        _loadSilently();
      }
    });
    // Also try immediately
    refresh();
  }

  /// Fetch recent transactions directly from Breez SDK
  Future<void> refresh() async {
    // Only fetch if SDK is initialized
    if (!BreezSparkService.isInitialized) {
      return; // Don't update state if SDK not ready
    }
    try {
      final payments = await BreezSparkService.listPayments(limit: 10);
      if (mounted) {
        state = AsyncValue.data(payments);
        debugPrint('📋 Recent transactions updated: ${payments.length} items');
      }
    } catch (e) {
      debugPrint('⚠️ Recent transactions error: $e');
      // Don't update state on error - keep last known value
    }
  }

  /// Load silently without debug prints
  Future<void> _loadSilently() async {
    if (!BreezSparkService.isInitialized) return;
    try {
      final payments = await BreezSparkService.listPayments(limit: 10);
      if (mounted) {
        state = AsyncValue.data(payments);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }
}

/// StateNotifier for all transactions that can be manually refreshed
class AllTransactionsNotifier
    extends StateNotifier<AsyncValue<List<PaymentRecord>>> {
  Timer? _autoRefreshTimer;

  AllTransactionsNotifier() : super(const AsyncValue.data([])) {
    // Start auto-refresh timer
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (BreezSparkService.isInitialized) {
        _loadSilently();
      }
    });
    // Also try immediately
    refresh();
  }

  /// Fetch all transactions directly from Breez SDK
  Future<void> refresh() async {
    // Only fetch if SDK is initialized
    if (!BreezSparkService.isInitialized) {
      return; // Don't update state if SDK not ready
    }
    try {
      final payments = await BreezSparkService.listPayments();
      if (mounted) {
        state = AsyncValue.data(payments);
        debugPrint('📋 All transactions updated: ${payments.length} items');
      }
    } catch (e) {
      debugPrint('⚠️ All transactions error: $e');
      // Don't update state on error - keep last known value
    }
  }

  /// Load silently without debug prints
  Future<void> _loadSilently() async {
    if (!BreezSparkService.isInitialized) return;
    try {
      final payments = await BreezSparkService.listPayments();
      if (mounted) {
        state = AsyncValue.data(payments);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }
}

/// Provider for recent transactions with manual refresh capability
final recentTransactionsProvider = StateNotifierProvider<
  RecentTransactionsNotifier,
  AsyncValue<List<PaymentRecord>>
>((ref) {
  return RecentTransactionsNotifier();
});

/// Provider for all transactions with manual refresh capability
final allTransactionsNotifierProvider = StateNotifierProvider<
  AllTransactionsNotifier,
  AsyncValue<List<PaymentRecord>>
>((ref) {
  return AllTransactionsNotifier();
});
