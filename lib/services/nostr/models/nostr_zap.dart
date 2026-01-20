/// Nostr Zap Models for NIP-57
/// Includes zap request (kind 9734) and zap receipt (kind 9735)
library;

/// Zap Request (Kind 9734) - Created by sender, included in LNURL callback
class NostrZapRequest {
  final String id;
  final String senderPubkey;
  final String recipientPubkey;
  final int amountMsats;
  final List<String> relays;
  final String content; // Optional comment
  final String? eventId; // If zapping a specific note
  final DateTime timestamp;

  NostrZapRequest({
    required this.id,
    required this.senderPubkey,
    required this.recipientPubkey,
    required this.amountMsats,
    required this.relays,
    this.content = '',
    this.eventId,
    required this.timestamp,
  });

  int get amountSats => amountMsats ~/ 1000;

  /// Build tags for zap request event
  List<List<String>> toTags() {
    final tags = <List<String>>[
      ['p', recipientPubkey],
      ['amount', amountMsats.toString()],
      ['relays', ...relays],
    ];
    if (eventId != null) {
      tags.add(['e', eventId!]);
    }
    return tags;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_pubkey': senderPubkey,
      'recipient_pubkey': recipientPubkey,
      'amount_msats': amountMsats,
      'relays': relays,
      'content': content,
      'event_id': eventId,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}

/// Zap Receipt (Kind 9735) - Published by LNURL server after payment
class NostrZapReceipt {
  final String id;
  final String senderPubkey;
  final String recipientPubkey;
  final int amountMsats;
  final String bolt11Invoice;
  final String? preimage;
  final String? zapRequestEventJson;
  final String? eventId; // If zapping a specific note
  final DateTime timestamp;

  NostrZapReceipt({
    required this.id,
    required this.senderPubkey,
    required this.recipientPubkey,
    required this.amountMsats,
    required this.bolt11Invoice,
    this.preimage,
    this.zapRequestEventJson,
    this.eventId,
    required this.timestamp,
  });

  int get amountSats => amountMsats ~/ 1000;

  factory NostrZapReceipt.fromEventTags(
    String id,
    List<List<String>> tags,
    DateTime timestamp,
  ) {
    String? senderPubkey;
    String? recipientPubkey;
    int amountMsats = 0;
    String bolt11 = '';
    String? preimage;
    String? zapRequest;
    String? eventId;

    for (final tag in tags) {
      if (tag.isEmpty) continue;
      final tagName = tag[0];
      if (tag.length < 2) continue;
      final tagValue = tag[1];

      switch (tagName) {
        case 'p':
          recipientPubkey ??= tagValue;
          break;
        case 'P':
          senderPubkey = tagValue;
          break;
        case 'e':
          eventId = tagValue;
          break;
        case 'bolt11':
          bolt11 = tagValue;
          break;
        case 'preimage':
          preimage = tagValue;
          break;
        case 'description':
          zapRequest = tagValue;
          break;
        case 'amount':
          amountMsats = int.tryParse(tagValue) ?? 0;
          break;
      }
    }

    return NostrZapReceipt(
      id: id,
      senderPubkey: senderPubkey ?? '',
      recipientPubkey: recipientPubkey ?? '',
      amountMsats: amountMsats,
      bolt11Invoice: bolt11,
      preimage: preimage,
      zapRequestEventJson: zapRequest,
      eventId: eventId,
      timestamp: timestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_pubkey': senderPubkey,
      'recipient_pubkey': recipientPubkey,
      'amount_msats': amountMsats,
      'bolt11_invoice': bolt11Invoice,
      'preimage': preimage,
      'zap_request_event_json': zapRequestEventJson,
      'event_id': eventId,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}

/// Result of a zap operation

/// Error types for zap failures
enum ZapErrorType {
  insufficientBalance,
  noLightningAddress,
  networkError,
  paymentFailed,
  other,
}

class ZapResult {
  final bool success;
  final int? amountSats;
  final String? error;
  final String? paymentHash;
  final String? preimage;
  final ZapErrorType? errorType;

  ZapResult._({
    required this.success,
    this.amountSats,
    this.error,
    this.paymentHash,
    this.preimage,
    this.errorType,
  });

  /// Convenience getters for status checking
  bool get isSuccess => success;
  bool get isInsufficientBalance =>
      errorType == ZapErrorType.insufficientBalance;
  bool get isNoLightningAddress => errorType == ZapErrorType.noLightningAddress;
  String? get message => error;

  factory ZapResult.success(
    int amountSats, {
    String? paymentHash,
    String? preimage,
  }) {
    return ZapResult._(
      success: true,
      amountSats: amountSats,
      paymentHash: paymentHash,
      preimage: preimage,
    );
  }

  factory ZapResult.failure(String error) {
    return ZapResult._(
      success: false,
      error: error,
      errorType: ZapErrorType.other,
    );
  }

  factory ZapResult.insufficientBalance(int required, int available) {
    return ZapResult._(
      success: false,
      error:
          'Insufficient balance. Need $required sats but only have $available sats.',
      errorType: ZapErrorType.insufficientBalance,
    );
  }

  factory ZapResult.noLightningAddress() {
    return ZapResult._(
      success: false,
      error: 'This user has no Lightning address configured for zaps.',
      errorType: ZapErrorType.noLightningAddress,
    );
  }

  @override
  String toString() =>
      success
          ? 'ZapResult.success($amountSats sats)'
          : 'ZapResult.failure($error)';
}

/// Simple Zap model for tracking received zaps
class NostrZap {
  final String id;
  final String senderPubkey;
  final String recipientPubkey;
  final int amountSats;
  final String? comment;
  final DateTime timestamp;
  final String? eventId;

  NostrZap({
    required this.id,
    required this.senderPubkey,
    required this.recipientPubkey,
    required this.amountSats,
    this.comment,
    required this.timestamp,
    this.eventId,
  });

  factory NostrZap.fromReceipt(NostrZapReceipt receipt) {
    return NostrZap(
      id: receipt.id,
      senderPubkey: receipt.senderPubkey,
      recipientPubkey: receipt.recipientPubkey,
      amountSats: receipt.amountMsats ~/ 1000,
      comment: null, // Comment is extracted from zapRequestEventJson if needed
      timestamp: receipt.timestamp,
      eventId: receipt.eventId,
    );
  }
}
