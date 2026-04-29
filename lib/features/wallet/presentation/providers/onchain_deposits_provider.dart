import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';

class OnchainDeposit {
  final String txid;
  final int vout;
  final int amountSats;
  final int confirmations;
  final int firstSeenMs;

  OnchainDeposit({
    required this.txid,
    required this.vout,
    required this.amountSats,
    required this.confirmations,
    required this.firstSeenMs,
  });

  factory OnchainDeposit.fromDynamic(dynamic d) {
    try {
      final txid = (d as dynamic).txid ?? (d as dynamic).txHash ?? '';
      final vout = (d as dynamic).vout ?? 0;
      final amount = (d as dynamic).amountSats ?? (d as dynamic).amount ?? 0;
      final confs = (d as dynamic).confirmations ?? 0;
      return OnchainDeposit(
        txid: txid.toString(),
        vout: (vout is int) ? vout : int.tryParse(vout.toString()) ?? 0,
        amountSats: (amount is int) ? amount : (int.tryParse(amount.toString()) ?? 0),
        confirmations: (confs is int) ? confs : (int.tryParse(confs.toString()) ?? 0),
        firstSeenMs: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      debugPrint('Failed to parse deposit: $e');
      return OnchainDeposit(
        txid: '',
        vout: 0,
        amountSats: 0,
        confirmations: 0,
        firstSeenMs: DateTime.now().millisecondsSinceEpoch,
      );
    }
  }

  Map<String, dynamic> toMap() => {
        'txid': txid,
        'vout': vout,
        'amountSats': amountSats,
        'confirmations': confirmations,
        'firstSeenMs': firstSeenMs,
      };

  static OnchainDeposit fromMap(Map m) => OnchainDeposit(
        txid: m['txid'] ?? '',
        vout: m['vout'] ?? 0,
        amountSats: m['amountSats'] ?? 0,
        confirmations: m['confirmations'] ?? 0,
        firstSeenMs: m['firstSeenMs'] ?? 0,
      );
}

class OnchainDepositsNotifier extends StateNotifier<List<OnchainDeposit>> {
  Timer? _pollTimer;
  final Box _box;

  OnchainDepositsNotifier._(this._box) : super([]) {
    _loadFromBox();
    _startPolling();
  }

  /// Public accessor to deposits to avoid accessing protected `state`.
  List<OnchainDeposit> get deposits => state;

  static Future<OnchainDepositsNotifier> create() async {
    await Hive.initFlutter();
    final box = await Hive.openBox('onchain_deposits');
    return OnchainDepositsNotifier._(box);
  }

  Future<void> _loadFromBox() async {
    try {
      final items = _box.get('deposits', defaultValue: []) as List;
      state = items.map((e) => OnchainDeposit.fromMap(Map.from(e))).toList();
    } catch (e) {
      debugPrint('Failed to load deposits from box: $e');
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await pollOnce();
    });
    // initial
    pollOnce();
  }

  Future<void> pollOnce() async {
    try {
      final deposits = await BreezSparkService.listUnclaimedDeposits();
      final parsed = deposits.map((d) => OnchainDeposit.fromDynamic(d)).toList();
      state = parsed;
      await _box.put('deposits', parsed.map((e) => e.toMap()).toList());
    } catch (e) {
      debugPrint('Failed to poll unclaimed deposits: $e');
    }
  }

  Future<void> claim(OnchainDeposit dep, {int maxFeeSats = 1000}) async {
    try {
      await BreezSparkService.claimDeposit(
        txid: dep.txid,
        vout: dep.vout,
        maxFeeSats: maxFeeSats,
      );
      // After claim, refresh
      await pollOnce();
    } catch (e) {
      debugPrint('Claim failed: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

final onchainDepositsProvider = FutureProvider<OnchainDepositsNotifier>((ref) async {
  final notifier = await OnchainDepositsNotifier.create();
  ref.onDispose(() => notifier.dispose());
  return notifier;
});

final onchainDepositsListProvider = Provider<List<OnchainDeposit>>((ref) {
  final asyncNotifier = ref.watch(onchainDepositsProvider);
  return asyncNotifier.when(
    data: (notifier) => notifier.deposits,
    loading: () => [],
    error: (_, __) => [],
  );
});
