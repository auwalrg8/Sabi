import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../breez_spark_service.dart';
import '../nostr/nostr_profile_service.dart';
import '../rate_service.dart';

/// Push notification API base URL
/// Change this to your deployed Vercel URL after deployment
const String _pushApiBaseUrl = String.fromEnvironment(
  'PUSH_API_URL',
  defaultValue: 'https://vercel-api-one-sigma.vercel.app/api',
);

/// Service that bridges Breez SDK payments with Firebase push notifications
///
/// This service:
/// 1. Listens to the payment stream from BreezSparkService
/// 2. When a payment is received, sends a webhook to Cloud Functions
/// 3. Cloud Functions then sends push notifications to the user's devices
///
/// Note: For true offline notifications, you need to configure Breez SDK
/// to send webhooks directly to your Cloud Functions. This service handles
/// the foreground case where the app detects the payment.
class BreezWebhookBridgeService {
  static final BreezWebhookBridgeService _instance =
      BreezWebhookBridgeService._internal();
  factory BreezWebhookBridgeService() => _instance;
  BreezWebhookBridgeService._internal();

  final NostrProfileService _nostrProfile = NostrProfileService();
  StreamSubscription<PaymentRecord>? _paymentSubscription;
  bool _isListening = false;

  /// Start listening to payment events and forwarding to webhook
  void startListening() {
    if (_isListening) {
      debugPrint('ℹ️ BreezWebhookBridge already listening');
      return;
    }

    _paymentSubscription = BreezSparkService.paymentStream.listen(
      _onPaymentReceived,
      onError: (e) => debugPrint('❌ Payment stream error: $e'),
    );

    _isListening = true;
    debugPrint('✅ BreezWebhookBridge started listening to payments');
  }

  /// Stop listening to payment events
  void stopListening() {
    _paymentSubscription?.cancel();
    _paymentSubscription = null;
    _isListening = false;
    debugPrint('🛑 BreezWebhookBridge stopped listening');
  }

  /// Handle incoming payment and forward to webhook
  Future<void> _onPaymentReceived(PaymentRecord payment) async {
    debugPrint('🎯 _onPaymentReceived CALLED!');
    debugPrint('   Payment ID: ${payment.id}');
    debugPrint('   Amount: ${payment.amountSats} sats');
    debugPrint('   IsIncoming: ${payment.isIncoming}');

    debugPrint(
      '⚡ Processing payment: ${payment.amountSats} sats (${payment.isIncoming ? "incoming" : "outgoing"})',
    );

    try {
      final pubkey = _nostrProfile.currentPubkey;
      debugPrint('   Pubkey: ${pubkey ?? "NULL"}');
      if (pubkey == null) {
        debugPrint('⚠️ No pubkey, cannot send webhook');
        return;
      }

      // Convert sats to Naira using current rate
      double? amountNaira;
      try {
        final rate = RateService.getCachedRate();
        if (rate != null) {
          // rate is NGN per BTC, so: sats * rate / 100,000,000
          amountNaira = (payment.amountSats * rate) / 100000000;
        }
      } catch (e) {
        debugPrint('⚠️ Could not get rate for Naira conversion');
      }

      // Send webhook to Cloud Functions
      final response = await http.post(
        Uri.parse('$_pushApiBaseUrl/webhook/payment'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nostrPubkey': pubkey,
          'amountSats': payment.amountSats,
          'amountNaira': amountNaira?.toStringAsFixed(2),
          'paymentHash': payment.id,
          'description': payment.description,
          'timestamp':
              DateTime.fromMillisecondsSinceEpoch(
                payment.paymentTime,
              ).toIso8601String(),
          'isIncoming': payment.isIncoming,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Payment webhook sent successfully');
      } else {
        debugPrint(
          '⚠️ Webhook failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('❌ Error sending payment webhook: $e');
    }
  }

  /// Send notification for successful outgoing payment
  Future<bool> sendOutgoingPaymentNotification({
    required int amountSats,
    String? recipientName,
    String? description,
    String? paymentHash,
  }) async {
    try {
      final pubkey = _nostrProfile.currentPubkey;
      if (pubkey == null) {
        debugPrint('⚠️ No pubkey for outgoing payment notification');
        return false;
      }

      // Convert sats to Naira using current rate
      double? amountNaira;
      try {
        final rate = RateService.getCachedRate();
        if (rate != null) {
          amountNaira = (amountSats * rate) / 100000000;
        }
      } catch (e) {
        debugPrint('⚠️ Could not get rate for Naira conversion');
      }

      final response = await http.post(
        Uri.parse('$_pushApiBaseUrl/webhook/payment'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nostrPubkey': pubkey,
          'amountSats': amountSats,
          'amountNaira': amountNaira?.toStringAsFixed(2),
          'paymentHash': paymentHash,
          'description':
              description ??
              (recipientName != null
                  ? 'Payment to $recipientName'
                  : 'Outgoing payment'),
          'timestamp': DateTime.now().toIso8601String(),
          'isIncoming': false,
          'recipientName': recipientName,
        }),
      );

      debugPrint('📤 Outgoing payment notification: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Error sending outgoing payment notification: $e');
      return false;
    }
  }

  /// Send notification for failed payment
  Future<bool> sendPaymentFailedNotification({
    required int amountSats,
    required String errorMessage,
    String? recipientName,
  }) async {
    try {
      final pubkey = _nostrProfile.currentPubkey;
      if (pubkey == null) {
        debugPrint('⚠️ No pubkey for payment failure notification');
        return false;
      }

      // Convert sats to Naira using current rate
      double? amountNaira;
      try {
        final rate = RateService.getCachedRate();
        if (rate != null) {
          amountNaira = (amountSats * rate) / 100000000;
        }
      } catch (e) {
        debugPrint('⚠️ Could not get rate for Naira conversion');
      }

      final response = await http.post(
        Uri.parse('$_pushApiBaseUrl/webhook/payment-failed'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nostrPubkey': pubkey,
          'amountSats': amountSats,
          'amountNaira': amountNaira?.toStringAsFixed(2),
          'errorMessage': errorMessage,
          'recipientName': recipientName,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      debugPrint('❌ Payment failed notification: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Error sending payment failed notification: $e');
      return false;
    }
  }

  /// Manually trigger a payment notification (for testing)
  Future<bool> sendTestPaymentNotification({
    required int amountSats,
    String description = 'Test payment',
  }) async {
    try {
      final pubkey = _nostrProfile.currentPubkey;
      if (pubkey == null) {
        debugPrint('⚠️ No pubkey for test notification');
        return false;
      }

      final response = await http.post(
        Uri.parse('$_pushApiBaseUrl/webhook/payment'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nostrPubkey': pubkey,
          'amountSats': amountSats,
          'description': description,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Error sending test notification: $e');
      return false;
    }
  }

  /// Send a generic test notification
  Future<bool> sendTestNotification({
    String? title,
    String? body,
    String type = 'general',
  }) async {
    try {
      final pubkey = _nostrProfile.currentPubkey;
      if (pubkey == null) {
        debugPrint('⚠️ No pubkey for test notification');
        return false;
      }

      final response = await http.post(
        Uri.parse('$_pushApiBaseUrl/test-notification'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nostrPubkey': pubkey,
          'title': title,
          'body': body,
          'type': type,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Test notification sent');
        return true;
      } else {
        debugPrint('⚠️ Test notification failed: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error sending test notification: $e');
      return false;
    }
  }

  /// Health check for the Cloud Functions
  Future<bool> checkCloudFunctionsHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$_pushApiBaseUrl/health'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Cloud Functions healthy: ${data['version']}');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Cloud Functions health check failed: $e');
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    stopListening();
  }
}

/// P2P Trade Webhook Service
/// Sends P2P trade events to Cloud Functions for push notifications
class P2PWebhookService {
  static final P2PWebhookService _instance = P2PWebhookService._internal();
  factory P2PWebhookService() => _instance;
  P2PWebhookService._internal();

  /// Send P2P trade event notification
  Future<bool> sendTradeEvent({
    required String recipientPubkey,
    required String tradeId,
    required String eventType,
    String? amount,
    String? counterpartyName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_pushApiBaseUrl/webhook/p2p'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nostrPubkey': recipientPubkey,
          'tradeId': tradeId,
          'eventType': eventType,
          'amount': amount,
          'counterpartyName': counterpartyName,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ P2P webhook sent: $eventType');
        return true;
      } else {
        debugPrint('⚠️ P2P webhook failed: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error sending P2P webhook: $e');
      return false;
    }
  }

  /// Notify when trade is started
  Future<bool> notifyTradeStarted({
    required String recipientPubkey,
    required String tradeId,
    required String counterpartyName,
    String? amount,
  }) => sendTradeEvent(
    recipientPubkey: recipientPubkey,
    tradeId: tradeId,
    eventType: 'trade_started',
    amount: amount,
    counterpartyName: counterpartyName,
  );

  /// Notify when payment is marked as sent
  Future<bool> notifyPaymentMarked({
    required String recipientPubkey,
    required String tradeId,
    String? amount,
  }) => sendTradeEvent(
    recipientPubkey: recipientPubkey,
    tradeId: tradeId,
    eventType: 'payment_marked',
    amount: amount,
  );

  /// Notify when payment is confirmed
  Future<bool> notifyPaymentConfirmed({
    required String recipientPubkey,
    required String tradeId,
  }) => sendTradeEvent(
    recipientPubkey: recipientPubkey,
    tradeId: tradeId,
    eventType: 'payment_confirmed',
  );

  /// Notify when funds are released
  Future<bool> notifyFundsReleased({
    required String recipientPubkey,
    required String tradeId,
    String? amount,
  }) => sendTradeEvent(
    recipientPubkey: recipientPubkey,
    tradeId: tradeId,
    eventType: 'funds_released',
    amount: amount,
  );

  /// Notify when trade is cancelled
  Future<bool> notifyTradeCancelled({
    required String recipientPubkey,
    required String tradeId,
  }) => sendTradeEvent(
    recipientPubkey: recipientPubkey,
    tradeId: tradeId,
    eventType: 'trade_cancelled',
  );

  /// Notify when trade is disputed
  Future<bool> notifyTradeDisputed({
    required String recipientPubkey,
    required String tradeId,
  }) => sendTradeEvent(
    recipientPubkey: recipientPubkey,
    tradeId: tradeId,
    eventType: 'trade_disputed',
  );

  /// Notify of new trade message
  Future<bool> notifyNewMessage({
    required String recipientPubkey,
    required String tradeId,
    required String senderName,
  }) => sendTradeEvent(
    recipientPubkey: recipientPubkey,
    tradeId: tradeId,
    eventType: 'new_message',
    counterpartyName: senderName,
  );

  /// Notify of new inquiry on offer
  Future<bool> notifyNewInquiry({
    required String recipientPubkey,
    required String tradeId,
    required String inquirerName,
  }) => sendTradeEvent(
    recipientPubkey: recipientPubkey,
    tradeId: tradeId,
    eventType: 'new_inquiry',
    counterpartyName: inquirerName,
  );
}

/// Zap Webhook Service
/// Sends zap notifications to Cloud Functions
class ZapWebhookService {
  static final ZapWebhookService _instance = ZapWebhookService._internal();
  factory ZapWebhookService() => _instance;
  ZapWebhookService._internal();

  /// Send zap notification
  Future<bool> notifyZapReceived({
    required String recipientPubkey,
    required int amountSats,
    String? senderName,
    String? senderPubkey,
    String? message,
    String? eventId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_pushApiBaseUrl/webhook/zap'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nostrPubkey': recipientPubkey,
          'amountSats': amountSats,
          'senderName': senderName,
          'senderPubkey': senderPubkey,
          'message': message,
          'eventId': eventId,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Zap webhook sent');
        return true;
      } else {
        debugPrint('⚠️ Zap webhook failed: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error sending zap webhook: $e');
      return false;
    }
  }
}

/// DM Webhook Service
/// Sends DM notifications to Cloud Functions
class DMWebhookService {
  static final DMWebhookService _instance = DMWebhookService._internal();
  factory DMWebhookService() => _instance;
  DMWebhookService._internal();

  /// Send DM notification
  Future<bool> notifyDMReceived({
    required String recipientPubkey,
    String? senderName,
    String? senderPubkey,
    String? preview,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_pushApiBaseUrl/webhook/dm'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nostrPubkey': recipientPubkey,
          'senderName': senderName,
          'senderPubkey': senderPubkey,
          'preview': preview,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ DM webhook sent');
        return true;
      } else {
        debugPrint('⚠️ DM webhook failed: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error sending DM webhook: $e');
      return false;
    }
  }
}

/// VTU Webhook Service
/// Sends VTU order status notifications
class VTUWebhookService {
  static final VTUWebhookService _instance = VTUWebhookService._internal();
  factory VTUWebhookService() => _instance;
  VTUWebhookService._internal();

  /// Send VTU order status notification
  Future<bool> notifyOrderStatus({
    required String recipientPubkey,
    required String orderId,
    required String orderType, // 'airtime', 'data', 'electricity'
    required String status, // 'complete', 'failed'
    String? amount,
    String? phoneNumber,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_pushApiBaseUrl/webhook/vtu'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nostrPubkey': recipientPubkey,
          'orderId': orderId,
          'orderType': orderType,
          'status': status,
          'amount': amount,
          'phoneNumber': phoneNumber,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ VTU webhook sent');
        return true;
      } else {
        debugPrint('⚠️ VTU webhook failed: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error sending VTU webhook: $e');
      return false;
    }
  }
}
