/// NIP-99 Classified Listing Model for P2P Offers
/// Kind: 30402 (Classified Listing)

enum P2POfferType { buy, sell }

enum P2POfferStatus { active, paused, completed, cancelled }

class NostrP2POffer {
  final String id; // Event 'd' tag identifier
  final String eventId; // Actual Nostr event ID
  final String pubkey;
  final String? npub;
  final String title;
  final String description;
  final double pricePerBtc; // In local currency
  final String currency; // e.g., 'NGN'
  final int? minAmountSats;
  final int? maxAmountSats;
  final P2POfferType type;
  final P2POfferStatus status;
  final List<String> paymentMethods;
  final String? location;
  final String? terms;
  final int? minTradeMinutes;
  final int? maxTradeMinutes;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final Map<String, String>? paymentAccountDetails;

  // Seller profile info (enriched)
  String? sellerName;
  String? sellerAvatar;
  int sellerTradeCount;
  double sellerCompletionRate;

  NostrP2POffer({
    required this.id,
    required this.eventId,
    required this.pubkey,
    this.npub,
    required this.title,
    required this.description,
    required this.pricePerBtc,
    required this.currency,
    this.minAmountSats,
    this.maxAmountSats,
    required this.type,
    this.status = P2POfferStatus.active,
    required this.paymentMethods,
    this.location,
    this.terms,
    this.minTradeMinutes,
    this.maxTradeMinutes,
    required this.createdAt,
    this.expiresAt,
    this.paymentAccountDetails,
    this.sellerName,
    this.sellerAvatar,
    this.sellerTradeCount = 0,
    this.sellerCompletionRate = 0.0,
  });

  /// Format price for display
  String get formattedPrice {
    if (currency == 'NGN') {
      if (pricePerBtc >= 1000000) {
        return '₦${(pricePerBtc / 1000000).toStringAsFixed(2)}M/BTC';
      }
      return '₦${pricePerBtc.toStringAsFixed(0)}/BTC';
    }
    return '$pricePerBtc $currency/BTC';
  }

  /// Format amount range for display
  String get amountRange {
    final min = minAmountSats ?? 0;
    final max = maxAmountSats ?? 0;

    String formatSats(int sats) {
      if (sats >= 1000000) return '${(sats / 1000000).toStringAsFixed(1)}M';
      if (sats >= 1000) return '${(sats / 1000).toStringAsFixed(0)}k';
      return sats.toString();
    }

    if (min > 0 && max > 0) {
      return '${formatSats(min)} - ${formatSats(max)} sats';
    } else if (max > 0) {
      return 'Up to ${formatSats(max)} sats';
    } else if (min > 0) {
      return 'Min ${formatSats(min)} sats';
    }
    return 'Any amount';
  }

  /// Create from NIP-99 event tags and content
  factory NostrP2POffer.fromNip99Event({
    required String eventId,
    required String pubkey,
    required List<List<String>> tags,
    required String content,
    required DateTime createdAt,
  }) {
    String? id;
    String? title;
    double pricePerBtc = 0;
    String currency = 'NGN';
    int? minAmount;
    int? maxAmount;
    P2POfferType type = P2POfferType.sell;
    final paymentMethods = <String>[];
    final accountDetails = <String, String>{};
    String? location;
    DateTime? expiresAt;

    for (final tag in tags) {
      if (tag.isEmpty) continue;
      final tagName = tag[0];
      if (tag.length < 2) continue;
      final tagValue = tag[1];

      switch (tagName) {
        case 'd':
          id = tagValue;
          break;
        case 'title':
          title = tagValue;
          break;
        case 'price':
          // Format: ["price", "amount", "currency", "sats_amount", "sats"]
          pricePerBtc = double.tryParse(tagValue) ?? 0;
          if (tag.length > 2) currency = tag[2];
          if (tag.length > 3) {
            final sats = int.tryParse(tag[3]);
            if (sats != null) {
              minAmount = sats;
              maxAmount = sats;
            }
          }
          break;
        case 'location':
          location = tagValue;
          break;
        case 't':
          if (tagValue == 'buy') type = P2POfferType.buy;
          if (tagValue == 'sell') type = P2POfferType.sell;
          break;
        case 'payment_method':
          paymentMethods.add(tagValue);
          break;
        case 'payment_details':
          // Format: ["payment_details", "method_id", "account_info"]
          if (tag.length > 2) {
            accountDetails[tagValue] = tag[2];
          }
          break;
        case 'min_amount':
          minAmount = int.tryParse(tagValue);
          break;
        case 'max_amount':
          maxAmount = int.tryParse(tagValue);
          break;
        case 'expiration':
          final exp = int.tryParse(tagValue);
          if (exp != null) {
            expiresAt = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
          }
          break;
      }
    }

    return NostrP2POffer(
      id: id ?? eventId,
      eventId: eventId,
      pubkey: pubkey,
      title: title ?? 'P2P Offer',
      description: content,
      pricePerBtc: pricePerBtc,
      currency: currency,
      minAmountSats: minAmount,
      maxAmountSats: maxAmount,
      type: type,
      paymentMethods: paymentMethods,
      paymentAccountDetails: accountDetails.isNotEmpty ? accountDetails : null,
      location: location,
      createdAt: createdAt,
      expiresAt: expiresAt,
    );
  }

  /// Build NIP-99 event tags
  List<List<String>> toNip99Tags() {
    final tags = <List<String>>[
      ['d', id],
      ['title', title],
      ['t', 'p2p'],
      ['t', 'bitcoin'],
      ['t', type == P2POfferType.buy ? 'buy' : 'sell'],
    ];

    // Price tag
    if (minAmountSats != null) {
      tags.add([
        'price',
        pricePerBtc.toString(),
        currency,
        minAmountSats.toString(),
        'sats',
      ]);
    } else {
      tags.add(['price', pricePerBtc.toString(), currency]);
    }

    // Amount limits
    if (minAmountSats != null)
      tags.add(['min_amount', minAmountSats.toString()]);
    if (maxAmountSats != null)
      tags.add(['max_amount', maxAmountSats.toString()]);

    // Location
    if (location != null) tags.add(['location', location!]);

    // Payment methods
    for (final pm in paymentMethods) {
      tags.add(['payment_method', pm]);
    }

    // Payment account details
    if (paymentAccountDetails != null) {
      for (final entry in paymentAccountDetails!.entries) {
        tags.add(['payment_details', entry.key, entry.value]);
      }
    }

    // Expiration
    if (expiresAt != null) {
      tags.add([
        'expiration',
        (expiresAt!.millisecondsSinceEpoch ~/ 1000).toString(),
      ]);
    }

    return tags;
  }

  /// Convert to JSON for caching/local storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'pubkey': pubkey,
      'npub': npub,
      'title': title,
      'description': description,
      'price_per_btc': pricePerBtc,
      'currency': currency,
      'min_amount_sats': minAmountSats,
      'max_amount_sats': maxAmountSats,
      'type': type == P2POfferType.buy ? 'buy' : 'sell',
      'status': status.name,
      'payment_methods': paymentMethods,
      'payment_account_details': paymentAccountDetails,
      'location': location,
      'terms': terms,
      'min_trade_minutes': minTradeMinutes,
      'max_trade_minutes': maxTradeMinutes,
      'created_at': createdAt.millisecondsSinceEpoch,
      'expires_at': expiresAt?.millisecondsSinceEpoch,
      'seller_name': sellerName,
      'seller_avatar': sellerAvatar,
      'seller_trade_count': sellerTradeCount,
      'seller_completion_rate': sellerCompletionRate,
    };
  }

  factory NostrP2POffer.fromJson(Map<String, dynamic> json) {
    // Parse payment account details
    Map<String, String>? accountDetails;
    if (json['payment_account_details'] != null) {
      accountDetails = (json['payment_account_details'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v.toString()));
    }

    return NostrP2POffer(
      id: json['id'] as String? ?? '',
      eventId: json['event_id'] as String? ?? '',
      pubkey: json['pubkey'] as String? ?? '',
      npub: json['npub'] as String?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      pricePerBtc: (json['price_per_btc'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'NGN',
      minAmountSats: json['min_amount_sats'] as int?,
      maxAmountSats: json['max_amount_sats'] as int?,
      type: json['type'] == 'buy' ? P2POfferType.buy : P2POfferType.sell,
      status: P2POfferStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => P2POfferStatus.active,
      ),
      paymentMethods:
          (json['payment_methods'] as List<dynamic>?)?.cast<String>() ?? [],
      paymentAccountDetails: accountDetails,
      location: json['location'] as String?,
      terms: json['terms'] as String?,
      minTradeMinutes: json['min_trade_minutes'] as int?,
      maxTradeMinutes: json['max_trade_minutes'] as int?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        json['created_at'] as int? ?? 0,
      ),
      expiresAt:
          json['expires_at'] != null
              ? DateTime.fromMillisecondsSinceEpoch(json['expires_at'] as int)
              : null,
      sellerName: json['seller_name'] as String?,
      sellerAvatar: json['seller_avatar'] as String?,
      sellerTradeCount: json['seller_trade_count'] as int? ?? 0,
      sellerCompletionRate:
          (json['seller_completion_rate'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  String toString() =>
      'NostrP2POffer(id: $id, type: $type, price: $formattedPrice)';
}
