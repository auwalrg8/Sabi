import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';

/// Direct balance provider that fetches from Breez SDK
final balanceProvider = FutureProvider<int>((ref) async {
  // Wait for SDK to be initialized before fetching balance
  if (!BreezSparkService.isInitialized) {
    return 0;
  }
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
  Timer? _autoRefreshTimer;
  StreamSubscription? _balanceStreamSubscription;
  
  BalanceNotifier() : super(const AsyncValue.data(0)) {
    // Start listening to balance stream for real-time updates
    _balanceStreamSubscription = BreezSparkService.balanceStream.listen((balance) {
      if (mounted) {
        state = AsyncValue.data(balance);
      }
    });
    
    // Start auto-refresh timer to poll balance when SDK is ready
    _startAutoRefresh();
  }
  
  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (BreezSparkService.isInitialized) {
        _loadBalance();
      }
    });
    // Also try immediately
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    // Only fetch if SDK is initialized
    if (!BreezSparkService.isInitialized) {
      return; // Don't update state if SDK not ready
    }
    try {
      final balance = await BreezSparkService.getBalance();
      if (mounted) {
        state = AsyncValue.data(balance);
        debugPrint('💰 Balance provider updated: $balance sats');
      }
    } catch (e) {
      debugPrint('⚠️ Balance provider error: $e');
      // Don't update state on error - keep last known value
    }
  }

  Future<void> refresh() async {
    await _loadBalance();
  }
  
  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _balanceStreamSubscription?.cancel();
    super.dispose();
  }
}
