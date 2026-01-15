import 'package:flutter_test/flutter_test.dart';
import 'package:sabi_wallet/features/onboarding/data/models/wallet_model.dart';

void main() {
  test('WalletModel.fromJson parses full payload', () {
    final payload = {
      "id": "11111111-1111-1111-1111-111111111111",
      "user_id": "00000000-0000-0000-0000-000000000000",
      "breez_wallet_id": "breez_111111111111111111111111111",
      "nostr_npub": "npub1example",
      "balance_sats": 123456,
      "balance_ngn": 15000.5,
      "connection_details": {
        "wallet_id": "11111111-1111-1111-1111-111111111111",
        "user_id": "00000000-0000-0000-0000-000000000000",
        "lightning_node_id": "node_abc123",
        "node_address": "lnd_node_abc123@127.0.0.1:9735",
        "synced": false,
        "initialized_at": "2025-11-30T12:34:56+00:00",
      },
      "created_at": "2025-11-30T12:34:56+00:00",
    };

    final model = WalletModel.fromJson(payload);

    expect(model.id, '11111111-1111-1111-1111-111111111111');
    expect(model.userId, '00000000-0000-0000-0000-000000000000');
    expect(model.breezWalletId, 'breez_111111111111111111111111111');
    expect(model.nostrNpub, 'npub1example');
    expect(model.balanceSats, 123456);
    expect(model.balanceNgn, 15000.5);
    expect(model.connectionDetails, isNotNull);
    expect(
      model.connectionDetails!.walletId,
      '11111111-1111-1111-1111-111111111111',
    );
  });
}
