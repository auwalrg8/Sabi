import 'dart:convert';

import 'package:http/http.dart' as http;

class LnAddressService {
  static final http.Client _client = http.Client();

  /// Resolves a Lightning address (e.g., user@example.com) into a Bolt11 invoice
  /// that already encodes the desired amount in sats.
  static Future<String> fetchInvoice({
    required String lnAddress,
    required int sats,
    String? memo,
  }) async {
    final trimmed = lnAddress.trim();
    final atIndex = trimmed.indexOf('@');
    if (atIndex <= 0 || atIndex == trimmed.length - 1) {
      throw FormatException('Invalid Lightning address: $lnAddress');
    }

    final username = trimmed.substring(0, atIndex);
    final host = trimmed.substring(atIndex + 1);
    if (username.isEmpty || host.isEmpty) {
      throw FormatException('Invalid Lightning address: $lnAddress');
    }

    final wellKnownUri = _buildLnAddressUri(host, username);
    final metadata = await _fetchJson(wellKnownUri);

    final callback = metadata['callback'] as String?;
    if (callback == null || callback.isEmpty) {
      throw Exception('Lightning address lookup missing callback URL');
    }

    final amountMsats = sats * 1000;
    final minSendable = _toInt(metadata['minSendable']);
    final maxSendable = _toInt(metadata['maxSendable']);
    if (minSendable > 0 && amountMsats < minSendable) {
      throw Exception('Amount lower than minimum allowed by LN address');
    }
    if (maxSendable > 0 && amountMsats > maxSendable) {
      throw Exception('Amount exceeds maximum allowed by LN address');
    }

    final callbackUri = Uri.parse(callback);
    final query = {...callbackUri.queryParameters};
    query['amount'] = amountMsats.toString();

    final commentAllowed = _toInt(metadata['commentAllowed']);
    if (memo != null && memo.isNotEmpty && commentAllowed > 0) {
      final comment =
          memo.length <= commentAllowed
              ? memo
              : memo.substring(0, commentAllowed);
      query['comment'] = comment;
    }

    final invoiceResponse = await _fetchJson(
      callbackUri.replace(queryParameters: query),
    );

    final invoice = invoiceResponse['pr'] as String?;
    if (invoice == null || invoice.isEmpty) {
      throw Exception('Lightning address callback did not return an invoice');
    }

    return invoice;
  }

  static Uri _buildLnAddressUri(String host, String username) {
    final sanitizedHost = host.toLowerCase();
    final base = Uri.parse('https://$sanitizedHost');
    return base.replace(
      path: '/.well-known/lnurlp/$username',
      queryParameters: {},
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static Future<Map<String, dynamic>> _fetchJson(Uri uri) async {
    final response = await _client.get(
      uri,
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception('LN address lookup failed (${response.statusCode})');
    }

    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) {
      throw Exception('Invalid response from LN address lookup');
    }

    final status = (payload['status'] as String?)?.toUpperCase();
    if (status == 'ERROR') {
      throw Exception(payload['reason'] ?? 'Lightning address error');
    }

    return payload;
  }
}
