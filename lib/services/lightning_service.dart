import 'dart:convert';
import 'package:http/http.dart' as http;
import 'secure_storage.dart';

class LightningService {
  static String? get inviteCode => SecureStorage.inviteCode;

  static Future<Map<String, dynamic>> createInvoice({
    required int sats,
    required String memo,
  }) async {
    final response = await http.post(
      Uri.parse('https://api.breez.technology/v1/nodeless/receive'),
      headers: {
        'Authorization': 'Bearer $inviteCode',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'amount_sats': sats,
        'description': memo,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Invoice failed: ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
