import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/core/services/secure_storage_service.dart';
import 'package:sabi_wallet/features/onboarding/data/remote/wallet_remote.dart';
import 'package:sabi_wallet/features/onboarding/data/models/wallet_model.dart';
import 'package:sabi_wallet/core/services/api_client.dart';
import 'package:sabi_wallet/core/constants/api_config.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';

/// Provider exposing the current wallet info as `AsyncValue<Map<String, dynamic>>`.
///
/// Usage:
/// final walletInfo = ref.watch(walletInfoProvider);
/// ref.read(walletInfoProvider.notifier).refresh();
final walletInfoProvider = StateNotifierProvider<WalletInfoNotifier, AsyncValue<WalletModel?>>((ref) {
  return WalletInfoNotifier(ref);
});

class WalletInfoNotifier extends StateNotifier<AsyncValue<WalletModel?>> {
  final Ref _ref;
  Timer? _periodicTimer;

  WalletInfoNotifier(this._ref) : super(const AsyncValue.loading()) {
    _load();
    _startPeriodicRefresh();
  }

  /// Start periodic refresh every 30 seconds for real-time updates
  void _startPeriodicRefresh() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadSilently();
    });
  }

  /// Load wallet data silently without showing loading state
  Future<void> _loadSilently() async {
    try {
      final storage = _ref.read(secureStorageServiceProvider);
      final String? userId = await storage.getUserId();

      if (userId == null) {
        state = AsyncValue.data(null);
        return;
      }

      final walletRemote = WalletRemote();
      WalletModel model = await walletRemote.getWallet(userId);

      model = await _maybeAttachSparkBalance(model);
      model = await _maybeAttachNairaBalance(model);

      state = AsyncValue.data(model);
    } catch (_) {
      // Silently fail on background refresh
    }
  }

  Future<void> _load() async {
    try {
      final storage = _ref.read(secureStorageServiceProvider);
      final String? userId = await storage.getUserId();

      if (userId == null) {
        state = AsyncValue.data(null);
        return;
      }

      final walletRemote = WalletRemote();
      WalletModel model = await walletRemote.getWallet(userId);

      model = await _maybeAttachSparkBalance(model);
      model = await _maybeAttachNairaBalance(model);

      state = AsyncValue.data(model);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<WalletModel> _maybeAttachSparkBalance(WalletModel model) async {
    try {
      final sparkBalance = await BreezSparkService.getBalanceSatsSafe();
      if (sparkBalance != null && sparkBalance >= 0) {
        return WalletModel(
          id: model.id,
          userId: model.userId,
          breezWalletId: model.breezWalletId,
          nostrNpub: model.nostrNpub,
          inviteCode: model.inviteCode,
          nodeId: model.nodeId,
          balanceSats: sparkBalance,
          balanceNgn: model.balanceNgn,
          connectionDetails: model.connectionDetails,
          createdAt: model.createdAt,
        );
      }
    } catch (_) {}
    return model;
  }

  Future<WalletModel> _maybeAttachNairaBalance(WalletModel model) async {
    if (model.balanceNgn != null) return model;

    try {
      final api = ApiClient();
      final rates = await api.get(ApiEndpoints.rates);
      final nairaToBtc = rates['naira_to_btc'];
      if (nairaToBtc != null) {
        // naira_to_btc: 1 NGN = x BTC. To compute NGN from BTC: NGN = BTC / x
        final btc = model.balanceSats / 100000000;
        final nairaPerBtc = (nairaToBtc is num)
            ? (1 / nairaToBtc)
            : (1 / double.parse(nairaToBtc.toString()));
        final computedNgn = btc * nairaPerBtc;
        return WalletModel(
          id: model.id,
          userId: model.userId,
          breezWalletId: model.breezWalletId,
          nostrNpub: model.nostrNpub,
          inviteCode: model.inviteCode,
          nodeId: model.nodeId,
          balanceSats: model.balanceSats,
          balanceNgn: computedNgn,
          connectionDetails: model.connectionDetails,
          createdAt: model.createdAt,
        );
      }
    } catch (_) {
      // ignore rates failure; leave balanceNgn null
    }
    return model;
  }

  /// Force refresh wallet info from backend
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    await _load();
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    super.dispose();
  }
}
