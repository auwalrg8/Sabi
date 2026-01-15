import 'package:flutter_test/flutter_test.dart';
import 'package:sabi_wallet/features/onboarding/data/remote/wallet_remote.dart';
// model import not required directly here; WalletRemote returns WalletModel which we assert on

/// Simple Fake ApiClient that matches the public surface of ApiClient used by WalletRemote.
class FakeApiClient {
  final Map<String, dynamic> postResponse;
  final Map<String, dynamic> getResponse;

  FakeApiClient({required this.postResponse, required this.getResponse});

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, String>? headers,
    Object? body,
    int expectedStatus = 200,
    Duration? timeout,
  }) async {
    return postResponse;
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? headers,
    int expectedStatus = 200,
    Duration? timeout,
  }) async {
    return getResponse;
  }
}

void main() {
  test('WalletRemote.createWallet parses WalletModel', () async {
    final fakeResp = {
      'success': true,
      'data': {
        'id': '11111111-1111-1111-1111-111111111111',
        'user_id': '00000000-0000-0000-0000-000000000000',
        'breez_wallet_id': 'breez_11111',
        'nostr_npub': 'npub1example',
        'balance_sats': 50000,
        'connection_details': {
          'wallet_id': '11111111-1111-1111-1111-111111111111',
          'user_id': '00000000-0000-0000-0000-000000000000',
          'lightning_node_id': 'node_abc',
          'node_address': 'node@127.0.0.1:9735',
          'synced': false,
          'initialized_at': '2025-11-30T12:34:56+00:00',
        },
        'created_at': '2025-11-30T12:34:56+00:00',
      },
    };

    final fakeClient = FakeApiClient(postResponse: fakeResp, getResponse: {});
    // WalletRemote's constructor accepts an ApiClient; we pass our fake that implements same methods.
    final remote = WalletRemote(fakeClient as dynamic);

    final model = await remote.createWallet(
      userId: '00000000-0000-0000-0000-000000000000',
      phoneNumber: '+2348012345678',
    );

    expect(model.id, '11111111-1111-1111-1111-111111111111');
    expect(model.balanceSats, 50000);
    expect(model.nostrNpub, 'npub1example');
    expect(model.connectionDetails, isNotNull);
    expect(model.connectionDetails!.nodeAddress, 'node@127.0.0.1:9735');
  });

  test(
    'WalletRemote.getWallet returns WalletModel when data at top-level',
    () async {
      final topLevel = {
        'id': '22222222-2222-2222-2222-222222222222',
        'user_id': '00000000-0000-0000-0000-000000000000',
        'balance_sats': 25000,
      };

      final fakeClient = FakeApiClient(postResponse: {}, getResponse: topLevel);
      final remote = WalletRemote(fakeClient as dynamic);

      final model = await remote.getWallet(
        '00000000-0000-0000-0000-000000000000',
      );

      expect(model.id, '22222222-2222-2222-2222-222222222222');
      expect(model.balanceSats, 25000);
    },
  );
}
