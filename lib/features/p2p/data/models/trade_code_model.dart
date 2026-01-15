/// Trade Code Model - Split verification system for P2P trades
///
/// The trade code is a 6-digit code split between buyer and seller:
/// - Buyer sees first 3 digits
/// - Seller sees last 3 digits
/// - Both must share to verify the trade
library;

import 'dart:math';

/// Generates and manages trade verification codes
class TradeCode {
  final String fullCode;
  final DateTime generatedAt;
  final DateTime expiresAt;

  TradeCode._({
    required this.fullCode,
    required this.generatedAt,
    required this.expiresAt,
  });

  /// Generate a new 6-digit trade code
  factory TradeCode.generate({
    Duration validity = const Duration(minutes: 10),
  }) {
    final random = Random.secure();
    final code = List.generate(6, (_) => random.nextInt(10)).join();
    final now = DateTime.now();
    return TradeCode._(
      fullCode: code,
      generatedAt: now,
      expiresAt: now.add(validity),
    );
  }

  /// Restore from stored data
  factory TradeCode.fromJson(Map<String, dynamic> json) {
    return TradeCode._(
      fullCode: json['fullCode'] as String,
      generatedAt: DateTime.fromMillisecondsSinceEpoch(
        json['generatedAt'] as int,
      ),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(json['expiresAt'] as int),
    );
  }

  Map<String, dynamic> toJson() => {
    'fullCode': fullCode,
    'generatedAt': generatedAt.millisecondsSinceEpoch,
    'expiresAt': expiresAt.millisecondsSinceEpoch,
  };

  /// First 3 digits shown to buyer
  String get buyerPart => fullCode.substring(0, 3);

  /// Last 3 digits shown to seller
  String get sellerPart => fullCode.substring(3, 6);

  /// Check if the code has expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Check if the code is valid
  bool get isValid => !isExpired && fullCode.length == 6;

  /// Verify a combined code from buyer + seller
  bool verify(String buyerInput, String sellerInput) {
    if (isExpired) return false;
    return buyerInput == buyerPart && sellerInput == sellerPart;
  }

  /// Verify the full code (for seller after receiving buyer's part)
  bool verifyFull(String combinedCode) {
    if (isExpired) return false;
    return combinedCode == fullCode;
  }

  @override
  String toString() => 'TradeCode($fullCode, expires: $expiresAt)';
}

/// Trade code verification status
enum TradeCodeStatus {
  /// Code not yet generated
  notGenerated,

  /// Waiting for buyer to share their part
  awaitingBuyerPart,

  /// Waiting for seller to share their part
  awaitingSellerPart,

  /// Both parts received, pending verification
  pendingVerification,

  /// Code verified successfully
  verified,

  /// Code verification failed
  failed,

  /// Code expired
  expired,
}

/// Tracks the state of trade code verification
class TradeCodeState {
  final TradeCode? code;
  final TradeCodeStatus status;
  final String? buyerPartReceived;
  final String? sellerPartReceived;
  final DateTime? verifiedAt;
  final String? errorMessage;

  const TradeCodeState({
    this.code,
    this.status = TradeCodeStatus.notGenerated,
    this.buyerPartReceived,
    this.sellerPartReceived,
    this.verifiedAt,
    this.errorMessage,
  });

  TradeCodeState copyWith({
    TradeCode? code,
    TradeCodeStatus? status,
    String? buyerPartReceived,
    String? sellerPartReceived,
    DateTime? verifiedAt,
    String? errorMessage,
  }) {
    return TradeCodeState(
      code: code ?? this.code,
      status: status ?? this.status,
      buyerPartReceived: buyerPartReceived ?? this.buyerPartReceived,
      sellerPartReceived: sellerPartReceived ?? this.sellerPartReceived,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get isVerified => status == TradeCodeStatus.verified;
  bool get hasFailed =>
      status == TradeCodeStatus.failed || status == TradeCodeStatus.expired;
}
