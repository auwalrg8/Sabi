import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import 'breez_spark_service.dart';
import '../config/vtu_config.dart';
import '../features/vtu/data/models/vtu_order.dart';
import '../features/vtu/services/vtu_service.dart';
import 'ln_address_service.dart';
import 'firebase/webhook_bridge_services.dart';

/// Persistent retry queue for outgoing payments that failed after delivery.
class PaymentRetryService {
  static const _boxName = 'payment_retries';
  static const int _maxAttempts = 6;
  static const Duration _pollInterval = Duration(seconds: 30);

  static Box? _box;
  static Timer? _timer;
  static bool _running = false;

  static Future<void> _ensureBox() async {
    if (_box != null) return;
    _box = await Hive.openBox(_boxName);
  }

  /// Enqueue a payment retry
  static Future<void> enqueue({
    required String orderId,
    required int sats,
    required String memo,
    String? lnAddress,
  }) async {
    await _ensureBox();
    final id = const Uuid().v4();
    final entry = {
      'id': id,
      'orderId': orderId,
      'sats': sats,
      'memo': memo,
      'lnAddress': lnAddress ?? VtuConfig.lightningAddress,
      'attempts': 0,
      'nextAttemptAt': DateTime.now().toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
      'lastError': null,
    };
    await _box!.put(id, jsonEncode(entry));
    debugPrint('🔁 Enqueued payment retry: $id for order $orderId');
    // Ensure processing is running
    start();
  }

  /// Start background processing loop
  static Future<void> start() async {
    if (_running) return;
    await _ensureBox();
    _running = true;
    _timer?.cancel();
    _timer = Timer.periodic(_pollInterval, (_) => _processDue());
    // Kick off immediate run
    _processDue();
    debugPrint('🔁 PaymentRetryService started');
  }

  /// Stop processing
  static Future<void> stop() async {
    _timer?.cancel();
    _running = false;
    debugPrint('🔁 PaymentRetryService stopped');
  }

  static Future<void> _processDue() async {
    if (_box == null) return;
    try {
      final now = DateTime.now();
      final keys = _box!.keys.toList();
      for (final key in keys) {
        final raw = _box!.get(key) as String?;
        if (raw == null) continue;
        final entry = jsonDecode(raw) as Map<String, dynamic>;
        final nextAttempt = DateTime.parse(entry['nextAttemptAt'] as String);
        if (nextAttempt.isAfter(now)) continue;

        await _attempt(entry);
      }
    } catch (e) {
      debugPrint('🔁 Retry processing error: $e');
    }
  }

  static Future<void> _attempt(Map<String, dynamic> entry) async {
    final id = entry['id'] as String;
    final orderId = entry['orderId'] as String;
    final sats = entry['sats'] as int;
    final memo = entry['memo'] as String;
    final lnAddress = entry['lnAddress'] as String?;
    var attempts = (entry['attempts'] as num).toInt();

    try {
      debugPrint('🔁 Attempting payment retry $id (attempt ${attempts + 1})');

      // Resolve invoice for lnAddress each attempt
      final invoice = await LnAddressService.fetchInvoice(
        lnAddress: lnAddress ?? VtuConfig.lightningAddress,
        sats: sats,
        memo: memo,
      );

      // Send via Breez
      await BreezSparkService.sendPayment(
        invoice,
        sats: sats,
        comment: memo,
        recipientName: 'VTU Agent',
      );

      // On success, remove entry and update order (clear error)
      await _box!.delete(id);
      debugPrint('✅ Retry $id succeeded for order $orderId');

      // Mark order as completed/paid (clear errorMessage if present)
      final order = await VtuService.getOrder(orderId);
      if (order != null) {
        await VtuService.updateOrderStatus(
          orderId,
          VtuOrderStatus.completed,
          token: order.token,
          errorMessage: null,
        );
      }

      // Notify webhook
      BreezWebhookBridgeService().sendOutgoingPaymentNotification(
        amountSats: sats,
        recipientName: 'VTU Agent',
        description: memo,
      );
    } catch (e) {
      attempts++;
      debugPrint('❌ Retry $id failed (attempt $attempts): $e');

      if (attempts >= _maxAttempts) {
        // Give up - mark order with error and remove
        await _box!.delete(id);
        await VtuService.updateOrderStatus(
          orderId,
          VtuOrderStatus.failed,
          errorMessage: 'Payment retry failed after $attempts attempts: $e',
        );
        // Send failed notification
        BreezWebhookBridgeService().sendPaymentFailedNotification(
          amountSats: sats,
          errorMessage: e.toString(),
          recipientName: 'VTU Agent',
        );
        debugPrint('⚠️ Retry $id exhausted - marked order failed: $orderId');
        return;
      }

      // Exponential backoff (minutes)
      final delayMinutes = (1 << attempts) * 1; // 1,2,4,8...
      final next = DateTime.now().add(Duration(minutes: delayMinutes));
      entry['attempts'] = attempts;
      entry['lastError'] = e.toString();
      entry['nextAttemptAt'] = next.toIso8601String();
      await _box!.put(id, jsonEncode(entry));
      debugPrint('🔁 Retry $id rescheduled for $next');
    }
  }
}
