class ConnectionDetails {
  final String walletId;
  final String userId;
  final String lightningNodeId;
  final String nodeAddress;
  final bool synced;
  final DateTime? initializedAt;

  ConnectionDetails({
    required this.walletId,
    required this.userId,
    required this.lightningNodeId,
    required this.nodeAddress,
    required this.synced,
    this.initializedAt,
  });

  factory ConnectionDetails.fromJson(Map<String, dynamic> json) {
    return ConnectionDetails(
      walletId: json['wallet_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      lightningNodeId: json['lightning_node_id'] as String? ?? '',
      nodeAddress: json['node_address'] as String? ?? '',
      synced: json['synced'] == true,
      initializedAt:
          json['initialized_at'] != null
              ? DateTime.parse(json['initialized_at'] as String)
              : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'wallet_id': walletId,
    'user_id': userId,
    'lightning_node_id': lightningNodeId,
    'node_address': nodeAddress,
    'synced': synced,
    'initialized_at': initializedAt?.toIso8601String(),
  };
}

class WalletModel {
  final String id;
  final String userId;
  final String? breezWalletId;
  final String? nostrNpub;
  final String? inviteCode; // Nodeless Spark invite code
  final String? nodeId; // Lightning node public key
  final int balanceSats;
  final double? balanceNgn;
  final ConnectionDetails? connectionDetails;
  final DateTime? createdAt;

  WalletModel({
    required this.id,
    required this.userId,
    this.breezWalletId,
    this.nostrNpub,
    this.inviteCode,
    this.nodeId,
    required this.balanceSats,
    this.balanceNgn,
    this.connectionDetails,
    this.createdAt,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    final conn = json['connection_details'];
    return WalletModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      breezWalletId: json['breez_wallet_id'] as String?,
      nostrNpub: json['nostr_npub'] as String?,
      inviteCode: json['invite_code'] as String?,
      nodeId: json['node_id'] as String?,
      balanceSats:
          (json['balance_sats'] is int)
              ? json['balance_sats'] as int
              : int.tryParse((json['balance_sats'] ?? '0').toString()) ?? 0,
      balanceNgn:
          json['balance_ngn'] != null
              ? (json['balance_ngn'] is num
                  ? (json['balance_ngn'] as num).toDouble()
                  : double.tryParse(json['balance_ngn'].toString()))
              : null,
      connectionDetails:
          conn is Map<String, dynamic>
              ? ConnectionDetails.fromJson(conn)
              : null,
      createdAt:
          json['created_at'] != null
              ? DateTime.tryParse(json['created_at'] as String)
              : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'breez_wallet_id': breezWalletId,
    'nostr_npub': nostrNpub,
    'invite_code': inviteCode,
    'node_id': nodeId,
    'balance_sats': balanceSats,
    'balance_ngn': balanceNgn,
    'connection_details': connectionDetails?.toJson(),
    'created_at': createdAt?.toIso8601String(),
  };
}
