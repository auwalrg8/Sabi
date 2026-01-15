import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:sabi_wallet/services/secure_storage.dart';
import 'package:sabi_wallet/core/services/secure_storage_service.dart';

final eventStreamServiceProvider = Provider<EventStreamService>((ref) {
  final storage = ref.read(secureStorageServiceProvider);
  return EventStreamService(storage: storage);
});

/// Service for real-time balance updates and payment notifications via Server-Sent Events (SSE)
class EventStreamService {
  final SecureStorageService storage;
  StreamSubscription? _subscription;
  final _balanceController = StreamController<BalanceUpdate>.broadcast();
  final _paymentController = StreamController<PaymentNotification>.broadcast();
  final _healthController = StreamController<bool>.broadcast();

  bool _isConnected = false;
  Timer? _reconnectTimer;

  EventStreamService({required this.storage});

  /// Stream of balance updates
  Stream<BalanceUpdate> get balanceUpdates => _balanceController.stream;

  /// Stream of payment notifications
  Stream<PaymentNotification> get paymentNotifications =>
      _paymentController.stream;

  /// Stream of health status (true = online, false = offline)
  Stream<bool> get healthStatus => _healthController.stream;

  /// Current connection status
  bool get isConnected => _isConnected;

  /// Start listening to /events stream
  Future<void> start() async {
    final inviteCode = SecureStorage.inviteCode;
    if (inviteCode == null ||
        inviteCode.isEmpty ||
        inviteCode == 'device_local_wallet') {
      // For local-only wallets, simulate connected status
      _isConnected = true;
      _healthController.add(true);
      return;
    }

    await _connect();
  }

  Future<void> _connect() async {
    try {
      final inviteCode = SecureStorage.inviteCode;
      if (inviteCode == null) return;

      final request = http.Request(
        'GET',
        Uri.parse('https://api.breez.technology/v1/nodeless/events'),
      );
      request.headers['Authorization'] = 'Bearer $inviteCode';
      request.headers['Accept'] = 'text/event-stream';
      request.headers['Cache-Control'] = 'no-cache';

      final client = http.Client();
      final response = await client.send(request);

      if (response.statusCode == 200) {
        _isConnected = true;
        _healthController.add(true);

        _subscription = response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
              _handleEvent,
              onError: (error) {
                _handleDisconnect();
              },
              onDone: () {
                _handleDisconnect();
              },
              cancelOnError: false,
            );
      } else {
        _handleDisconnect();
      }
    } catch (e) {
      _handleDisconnect();
    }
  }

  void _handleEvent(String line) {
    if (line.isEmpty) return;

    if (line.startsWith('data: ')) {
      final data = line.substring(6);
      try {
        final json = jsonDecode(data) as Map<String, dynamic>;
        final eventType = json['type'] as String?;

        switch (eventType) {
          case 'balance_update':
            _balanceController.add(BalanceUpdate.fromJson(json));
            break;
          case 'payment':
            final payment = PaymentNotification.fromJson(json);
            _paymentController.add(payment);
            // Check for first payment > 1000 sats for confetti
            if (payment.inbound && payment.amountSats > 1000) {
              _checkFirstPaymentConfetti(payment.amountSats);
            }
            break;
          case 'health':
            final isOnline = json['online'] == true;
            _isConnected = isOnline;
            _healthController.add(isOnline);
            break;
        }
      } catch (e) {
        // Ignore malformed events
      }
    } else if (line.startsWith('event: ')) {
      // SSE event type
    } else if (line.startsWith('id: ')) {
      // SSE event ID
    } else if (line.startsWith('retry: ')) {
      // SSE retry interval
    }
  }

  void _handleDisconnect() {
    _isConnected = false;
    _healthController.add(false);

    // Attempt to reconnect after 5 seconds
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _connect();
    });
  }

  Future<void> _checkFirstPaymentConfetti(int amountSats) async {
    final alreadyShown = await storage.hasFirstPaymentConfettiShown();
    if (!alreadyShown && amountSats > 1000) {
      await storage.setFirstPaymentConfettiPending(true);
    }
  }

  /// Stop listening and clean up
  void dispose() {
    _subscription?.cancel();
    _reconnectTimer?.cancel();
    _balanceController.close();
    _paymentController.close();
    _healthController.close();
  }
}

class BalanceUpdate {
  final int balanceSats;
  final double? balanceNgn;
  final DateTime timestamp;

  BalanceUpdate({
    required this.balanceSats,
    this.balanceNgn,
    required this.timestamp,
  });

  factory BalanceUpdate.fromJson(Map<String, dynamic> json) {
    return BalanceUpdate(
      balanceSats: (json['balance_sats'] as num?)?.toInt() ?? 0,
      balanceNgn: (json['balance_ngn'] as num?)?.toDouble(),
      timestamp:
          json['timestamp'] != null
              ? DateTime.tryParse(json['timestamp'].toString()) ??
                  DateTime.now()
              : DateTime.now(),
    );
  }
}

class PaymentNotification {
  final String id;
  final bool inbound;
  final int amountSats;
  final String? description;
  final DateTime timestamp;
  final String status;

  PaymentNotification({
    required this.id,
    required this.inbound,
    required this.amountSats,
    this.description,
    required this.timestamp,
    required this.status,
  });

  factory PaymentNotification.fromJson(Map<String, dynamic> json) {
    return PaymentNotification(
      id: json['id']?.toString() ?? json['payment_hash']?.toString() ?? '',
      inbound: json['inbound'] == true || json['direction'] == 'inbound',
      amountSats: (json['amount_sats'] as num?)?.toInt() ?? 0,
      description: json['description'] as String?,
      timestamp:
          json['timestamp'] != null
              ? DateTime.tryParse(json['timestamp'].toString()) ??
                  DateTime.now()
              : DateTime.now(),
      status: json['status']?.toString() ?? 'unknown',
    );
  }
}
