import 'package:sabi_wallet/core/constants/api_config.dart';
import 'package:sabi_wallet/core/services/api_client.dart';
import '../models/wallet_model.dart';

class WalletRemote {
  final dynamic _client;

  WalletRemote([dynamic client]) : _client = client ?? ApiClient();

  /// Create a new wallet with [deviceId] and [phone].
  /// Returns decoded JSON response on success.
  Future<WalletModel> createWallet({required String userId, required String phoneNumber, String? backupType}) async {
    final body = {
      'device_id': userId,  // Using userId as device_id for now
      'phone': phoneNumber,
    };

    if (backupType != null) {
      body['backup_type'] = backupType;
    }

    // Backend returns 200 OK on success
    final resp = await _client.post(ApiEndpoints.walletCreate, body: body, expectedStatus: 200);

    // New backend returns: {"wallet_id":"<uuid>","invite_code":"SABI-XXX","node_id":"<pubkey>"}
    if (resp.containsKey('wallet_id') && resp.containsKey('invite_code')) {
      // Map new response format to WalletModel
      return WalletModel.fromJson({
        'id': resp['wallet_id'],
        'user_id': userId,
        'invite_code': resp['invite_code'],
        'node_id': resp['node_id'],
        'balance_sats': 0,
      });
    }

    // Fallback: old format
    if (resp['success'] == true && resp['data'] is Map<String, dynamic>) {
      return WalletModel.fromJson(resp['data'] as Map<String, dynamic>);
    }

    if (resp.containsKey('id') || resp.containsKey('balance_sats')) {
      return WalletModel.fromJson(resp);
    }

    throw Exception(resp['error'] ?? 'Unexpected response from wallet create');
  }

  /// Fetch wallet info by [userId].
  /// Returns the `data` object when backend responds with `{ success: true, data: {...} }`.
  Future<WalletModel> getWallet(String userId) async {
    final resp = await _client.get(ApiEndpoints.walletByUser(userId));

    if (resp['success'] == true && resp['data'] is Map<String, dynamic>) {
      return WalletModel.fromJson(resp['data'] as Map<String, dynamic>);
    }

    if (resp.containsKey('id') || resp.containsKey('balance_sats')) {
      return WalletModel.fromJson(resp);
    }

    throw Exception(resp['error'] ?? 'Failed to fetch wallet info');
  }
}
