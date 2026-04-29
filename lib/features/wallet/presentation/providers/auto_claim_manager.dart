import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sabi_wallet/features/wallet/presentation/providers/onchain_deposits_provider.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';
import 'package:sabi_wallet/services/notification_service.dart';
import 'package:sabi_wallet/services/payment_notification_service.dart';

/// Auto-claim manager: listens to incoming unclaimed deposits and attempts
/// to claim them automatically once they reach [confirmationsThreshold].
final autoClaimManagerProvider = Provider<AutoClaimManager>((ref) {
  final mgr = AutoClaimManager(ref);
  ref.onDispose(mgr.dispose);
  return mgr;
});

/// Event emitted when an auto-claim succeeds (or fails). UI can listen
/// to `autoClaimEventProvider` to surface notifications to the user.
class AutoClaimEvent {
  final String id;
  final String txid;
  final int vout;
  final int amountSats;
  final int timestampMs;

  AutoClaimEvent({required this.id, required this.txid, required this.vout, required this.amountSats, required this.timestampMs});
}

final autoClaimEventProvider = StateProvider<AutoClaimEvent?>((ref) => null);

class AutoClaimManager {
  final Ref ref;
  final Set<String> _inProgress = {};
  Box? _claimsBox;

  /// Minimum confirmations required to attempt auto-claim
  final int confirmationsThreshold;

  AutoClaimManager(this.ref, {this.confirmationsThreshold = 2}) {
    _init();
  }

  Future<void> _init() async {
    try {
      await Hive.initFlutter();
      _claimsBox = await Hive.openBox('onchain_claims');
    } catch (e) {
      debugPrint('AutoClaim: Hive init/open failed: $e');
    }

    // Listen to deposits provider changes
    ref.listen<List<OnchainDeposit>>(onchainDepositsListProvider, (prev, next) async {
      try {
        for (final d in next) {
          final key = '${d.txid}:${d.vout}';
          final existing = _claimsBox?.get(key);
          if (existing != null) {
            try {
              if (existing is Map && existing['state'] == 'claimed') {
                continue; // already claimed
              }
              if (existing is Map && existing['attempts'] != null && (existing['attempts'] as int) >= 5) {
                continue; // exhausted attempts
              }
            } catch (_) {}
          }
          if (d.confirmations < confirmationsThreshold) continue;
          if (_inProgress.contains(key)) continue;
          _inProgress.add(key);

          // Resolve the notifier (may not be ready yet)
          try {
            final notifier = await ref.read(onchainDepositsProvider.future);

            // Compute dynamic max fee using recommended fees
            int maxFeeSats = 1000;
            try {
              final fees = await BreezSparkService.getRecommendedFees();
              // Prefer halfHourFee, fallback to fastest/hour/economy/minimum
                final BigInt perVbyte = fees.halfHourFee != BigInt.zero
                  ? fees.halfHourFee
                  : (fees.fastestFee != BigInt.zero
                    ? fees.fastestFee
                    : (fees.hourFee != BigInt.zero
                      ? fees.hourFee
                      : (fees.economyFee != BigInt.zero ? fees.economyFee : fees.minimumFee)));

                final perV = perVbyte.toInt();
              // Estimate tx vsize more conservatively for small deposits
              final estimatedVsize = d.amountSats < 10000 ? 200 : 150;
              final candidate = perV * estimatedVsize;

              // Cap fee to a percentage of deposit (2%) to avoid excessive fees on tiny deposits
              int pctCap = (d.amountSats * 2) ~/ 100; // 2% of amount
              if (pctCap < 200) pctCap = 200; // minimum cap

              int finalFee = candidate;
              if (finalFee > pctCap) finalFee = pctCap;
              if (finalFee > 20000) finalFee = 20000;
              if (finalFee < 100) finalFee = 100;

              maxFeeSats = finalFee;
            } catch (e) {
              debugPrint('AutoClaim: fee estimation failed, using default: $e');
              maxFeeSats = 1000;
            }

            // Attempt claim with retries and exponential backoff (persisting attempts)
            unawaited(_attemptClaimWithRetries(
              notifier: notifier,
              deposit: d,
              key: key,
              maxFeeSats: maxFeeSats,
              claimsBox: _claimsBox,
              onSuccess: (fee) async {
                try {
                  await BreezSparkService.recordOnchainClaim(txid: d.txid, vout: d.vout, amountSats: d.amountSats, feeSats: fee);
                  await NotificationService.addPaymentNotification(
                    isInbound: true,
                    amountSats: d.amountSats,
                    description: 'Auto-claimed on‑chain deposit',
                  );
                  try {
                    await LocalNotificationService.showPaymentNotification(
                      title: 'Auto-claimed deposit',
                      body: 'Claimed ${d.amountSats} sats from ${d.txid.substring(0, 8)}...',
                      notificationId: key,
                      payload: null,
                    );
                  } catch (e) {
                    debugPrint('AutoClaim: failed to show local notification: $e');
                  }
                  final event = AutoClaimEvent(
                    id: key,
                    txid: d.txid,
                    vout: d.vout,
                    amountSats: d.amountSats,
                    timestampMs: DateTime.now().millisecondsSinceEpoch,
                  );
                  ref.read(autoClaimEventProvider.notifier).state = event;
                } catch (e) {
                  debugPrint('AutoClaim: post-claim handling failed: $e');
                }
              },
            ));
          } catch (e) {
            debugPrint('AutoClaim: notifier not ready: $e');
            _inProgress.remove(key);
          }
        }
      } catch (e) {
        debugPrint('AutoClaim: listener error: $e');
      }
    });
  }

  Future<void> _attemptClaimWithRetries({
    required OnchainDepositsNotifier notifier,
    required OnchainDeposit deposit,
    required String key,
    required int maxFeeSats,
    required Box? claimsBox,
    required Future<void> Function(int fee) onSuccess,
    int maxAttempts = 5,
  }) async {
    int attempt = 0;
    // Start with a longer base delay to avoid immediate repeated claims
    int currentDelayMs = 2000;
    while (attempt < maxAttempts) {
      attempt++;
      // Persist attempt increment
      try {
        final meta = (claimsBox?.get(key) is Map) ? Map<String, dynamic>.from(claimsBox!.get(key)) : <String, dynamic>{};
        meta['state'] = 'in_progress';
        meta['attempts'] = (meta['attempts'] ?? 0) + 1;
        meta['lastAttemptMs'] = DateTime.now().millisecondsSinceEpoch;
        await claimsBox?.put(key, meta);
      } catch (e) {
        debugPrint('AutoClaim: failed to persist attempt meta: $e');
      }
      try {
        debugPrint('AutoClaim: attempting claim $key attempt $attempt/$maxAttempts (maxFee=$maxFeeSats)');
        await notifier.claim(deposit, maxFeeSats: maxFeeSats);
        // mark persisted
        try {
          await claimsBox?.put(key, {
            'state': 'claimed',
            'attempts': attempt,
            'claimedAtMs': DateTime.now().millisecondsSinceEpoch,
            'feeSats': maxFeeSats,
          });
        } catch (e) {
          debugPrint('AutoClaim: failed to write claim marker: $e');
        }
        await onSuccess(maxFeeSats);
        return;
      } catch (e) {
        debugPrint('AutoClaim: claim attempt $attempt failed for $key: $e');
        // persist last error for UI visibility
        try {
          final existing = (claimsBox?.get(key) is Map) ? Map<String, dynamic>.from(claimsBox!.get(key)) : <String, dynamic>{};
          existing['lastError'] = e.toString();
          existing['lastErrorMs'] = DateTime.now().millisecondsSinceEpoch;
          existing['attempts'] = (existing['attempts'] ?? attempt);
          await claimsBox?.put(key, existing);
        } catch (_) {}
        // If not retryable, break
        try {
          if (!BreezSparkService.isRetryableError(e)) {
            debugPrint('AutoClaim: error not retryable, aborting claims for $key');
            // mark failed
            try {
              await claimsBox?.put(key, {
                'state': 'failed',
                'attempts': attempt,
                'lastError': e.toString(),
                'lastAttemptMs': DateTime.now().millisecondsSinceEpoch,
              });
            } catch (_) {}
            break;
          }
        } catch (_) {}

        if (attempt < maxAttempts) {
          // add jitter to avoid thundering herd
          final jitter = Random().nextInt(300); // 0-299ms
          await Future.delayed(Duration(milliseconds: currentDelayMs + jitter));
          currentDelayMs = (currentDelayMs * 2).clamp(200, 60000);
          continue;
        }
      } finally {
        // ensure removal from in-progress even if we continue
        if (attempt >= maxAttempts) _inProgress.remove(key);
      }
    }
    // Final failure
    try {
      final existing = (claimsBox?.get(key) is Map) ? Map<String, dynamic>.from(claimsBox!.get(key)) : <String, dynamic>{};
      existing['state'] = 'failed';
      existing['attempts'] = (existing['attempts'] ?? 0);
      existing['lastAttemptMs'] = DateTime.now().millisecondsSinceEpoch;
      await claimsBox?.put(key, existing);
    } catch (_) {}
    debugPrint('AutoClaim: all attempts failed for $key');
  }

  void dispose() {
    _claimsBox?.close();
  }
}
