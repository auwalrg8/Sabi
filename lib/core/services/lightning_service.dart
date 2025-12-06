import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/core/services/secure_storage_service.dart';

final lightningServiceProvider = Provider<LightningService>((ref) {
  final storage = ref.read(secureStorageServiceProvider);
  return LightningService(storage: storage);
});

class LightningService {
  final SecureStorageService storage;
  String? _inviteCode;
  String? _nodeId;

  LightningService({required this.storage});

  Future<void> init() async {
    _inviteCode = await storage.read(key: 'invite_code');
    _nodeId = await storage.read(key: 'node_id');
  }

  String? get inviteCode => _inviteCode;
  String? get nodeId => _nodeId;
  bool get hasWallet => _inviteCode != null && _inviteCode!.isNotEmpty;

  Future<LnInvoice> createInvoice(int sats, String memo) async {
    if (inviteCode == null) {
      throw Exception('No invite_code stored');
    }
    final uri = Uri.parse('https://api.breez.technology/v1/nodeless/receive');
    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $inviteCode',
      },
      body: json.encode({
        'amount_sats': sats,
        'description': memo,
      }),
    );

    if (resp.statusCode != 200) {
      throw Exception('Invoice error ${resp.statusCode}: ${resp.body}');
    }
    final decoded = json.decode(resp.body) as Map<String, dynamic>;
    return LnInvoice.fromJson(decoded);
  }

  // Additional endpoints can follow the same pattern:
  // sendPayment(), listPayments(), etc.
  Future<List<LnPayment>> listPayments({int limit = 20}) async {
    if (inviteCode == null) {
      throw Exception('No invite_code stored');
    }
    final uri = Uri.parse('https://api.breez.technology/v1/nodeless/payments?limit=$limit');
    final resp = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $inviteCode',
      },
    );
    if (resp.statusCode != 200) {
      throw Exception('List payments error ${resp.statusCode}: ${resp.body}');
    }
    final decoded = json.decode(resp.body);
    final list = (decoded is List ? decoded : (decoded['payments'] as List? ?? const []))
        .cast<Map<String, dynamic>>();
    return list.map(LnPayment.fromJson).toList();
  }

  /// Call this after fetching a new incoming payment.
  /// If amount > 1000 sats and confetti not yet shown, mark pending.
  Future<void> markFirstPaymentIf(int amountSats) async {
    final alreadyShown = await storage.hasFirstPaymentConfettiShown();
    if (!alreadyShown && amountSats > 1000) {
      await storage.setFirstPaymentConfettiPending(true);
    }
  }
}

class LnInvoice {
  final String bolt11;
  final String paymentHash;
  final int amountSats;
  final String? description;

  LnInvoice({
    required this.bolt11,
    required this.paymentHash,
    required this.amountSats,
    this.description,
  });

  factory LnInvoice.fromJson(Map<String, dynamic> json) {
    return LnInvoice(
      bolt11: json['bolt11'] as String? ?? json['invoice'] as String? ?? '',
      paymentHash: json['payment_hash'] as String? ?? '',
      amountSats: (json['amount_sats'] as num?)?.toInt() ?? 0,
      description: json['description'] as String?,
    );
  }
}

class LnPayment {
  final String id;
  final bool inbound;
  final int amountSats;
  final String? description;
  final DateTime? timestamp;

  LnPayment({
    required this.id,
    required this.inbound,
    required this.amountSats,
    this.description,
    this.timestamp,
  });

  factory LnPayment.fromJson(Map<String, dynamic> json) {
    return LnPayment(
      id: json['id']?.toString() ?? json['payment_hash']?.toString() ?? '',
      inbound: json['inbound'] == true || json['direction'] == 'inbound',
      amountSats: (json['amount_sats'] as num?)?.toInt() ??
          (json['amount'] as num?)?.toInt() ?? 0,
      description: json['description'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString())
          : null,
    );
  }
}
