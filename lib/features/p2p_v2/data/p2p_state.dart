/// P2P V2 - Single Source of Truth State Model
/// 
/// This replaces the fragmented state across multiple providers
/// with a unified, cacheable state model.
library;

import 'package:flutter/foundation.dart';
import 'package:sabi_wallet/services/nostr/models/nostr_offer.dart';

/// Connection status to Nostr relays
enum RelayConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// Trade status - clear linear flow
enum TradeStatus {
  /// Trade requested, waiting for seller to accept
  requested,
  
  /// Trade created, waiting for buyer to pay fiat
  awaitingPayment,
  
  /// Buyer marked payment as sent
  paymentSent,
  
  /// Seller confirmed payment received
  paymentConfirmed,
  
  /// BTC being released via Lightning
  releasing,
  
  /// Trade completed successfully
  completed,
  
  /// Trade cancelled by either party
  cancelled,
  
  /// Trade expired (timeout)
  expired,
  
  /// Trade in dispute
  disputed,
}

/// Trade role
enum TradeRole { buyer, seller }

/// A single P2P trade
@immutable
class P2PTrade {
  final String id;
  final String offerId;
  final String offerTitle;
  final String sellerPubkey;
  final String buyerPubkey;
  final String? buyerLightningInvoice;
  final TradeRole myRole;
  final double fiatAmount;
  final String fiatCurrency;
  final int satsAmount;
  final double pricePerBtc;
  final String paymentMethod;
  final Map<String, String>? paymentDetails;
  final TradeStatus status;
  final DateTime createdAt;
  final DateTime? paidAt;
  final DateTime? confirmedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancelReason;
  final List<String> receiptImages;
  final String? paymentNote;
  final List<TradeMessage> messages;

  const P2PTrade({
    required this.id,
    required this.offerId,
    required this.offerTitle,
    required this.sellerPubkey,
    required this.buyerPubkey,
    this.buyerLightningInvoice,
    required this.myRole,
    required this.fiatAmount,
    required this.fiatCurrency,
    required this.satsAmount,
    required this.pricePerBtc,
    required this.paymentMethod,
    this.paymentDetails,
    this.status = TradeStatus.awaitingPayment,
    required this.createdAt,
    this.paidAt,
    this.confirmedAt,
    this.completedAt,
    this.cancelledAt,
    this.cancelReason,
    this.receiptImages = const [],
    this.paymentNote,
    this.messages = const [],
  });

  bool get isBuyer => myRole == TradeRole.buyer;
  bool get isSeller => myRole == TradeRole.seller;
  bool get isActive => status == TradeStatus.requested ||
                       status == TradeStatus.awaitingPayment || 
                       status == TradeStatus.paymentSent ||
                       status == TradeStatus.paymentConfirmed ||
                       status == TradeStatus.releasing;
  bool get isCompleted => status == TradeStatus.completed;
  bool get isCancelled => status == TradeStatus.cancelled || status == TradeStatus.expired;
  
  /// Alias for satsAmount for cleaner API
  int get amountSats => satsAmount;
  
  /// Alias for fiatCurrency
  String get currency => fiatCurrency;
  
  /// Last update timestamp
  DateTime get updatedAt => completedAt ?? cancelledAt ?? confirmedAt ?? paidAt ?? createdAt;
  
  /// Receipt URL (first image if available)
  String? get receiptUrl => receiptImages.isNotEmpty ? receiptImages.first : null;
  
  /// Human-readable status label
  String get statusLabel {
    switch (status) {
      case TradeStatus.requested:
        return 'Requested';
      case TradeStatus.awaitingPayment:
        return 'Awaiting Payment';
      case TradeStatus.paymentSent:
        return 'Payment Sent';
      case TradeStatus.paymentConfirmed:
        return 'Payment Confirmed';
      case TradeStatus.releasing:
        return 'Releasing';
      case TradeStatus.completed:
        return 'Completed';
      case TradeStatus.cancelled:
        return 'Cancelled';
      case TradeStatus.expired:
        return 'Expired';
      case TradeStatus.disputed:
        return 'Disputed';
    }
  }
  
  /// Formatted amount string
  String get formattedAmount {
    if (satsAmount >= 1000000) {
      return '${(satsAmount / 1000000).toStringAsFixed(2)}M sats';
    }
    if (satsAmount >= 1000) {
      return '${(satsAmount / 1000).toStringAsFixed(0)}k sats';
    }
    return '$satsAmount sats';
  }
  
  String get counterpartyPubkey => isBuyer ? sellerPubkey : buyerPubkey;
  
  /// Time remaining before trade expires (4 min window)
  Duration get timeRemaining {
    final expiry = createdAt.add(const Duration(minutes: 4));
    final remaining = expiry.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
  
  bool get isExpired => timeRemaining == Duration.zero && 
                        status == TradeStatus.awaitingPayment;

  P2PTrade copyWith({
    String? id,
    String? offerId,
    String? offerTitle,
    String? sellerPubkey,
    String? buyerPubkey,
    String? buyerLightningInvoice,
    TradeRole? myRole,
    double? fiatAmount,
    String? fiatCurrency,
    int? satsAmount,
    double? pricePerBtc,
    String? paymentMethod,
    Map<String, String>? paymentDetails,
    TradeStatus? status,
    DateTime? createdAt,
    DateTime? paidAt,
    DateTime? confirmedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    String? cancelReason,
    List<String>? receiptImages,
    String? paymentNote,
    List<TradeMessage>? messages,
  }) {
    return P2PTrade(
      id: id ?? this.id,
      offerId: offerId ?? this.offerId,
      offerTitle: offerTitle ?? this.offerTitle,
      sellerPubkey: sellerPubkey ?? this.sellerPubkey,
      buyerPubkey: buyerPubkey ?? this.buyerPubkey,
      buyerLightningInvoice: buyerLightningInvoice ?? this.buyerLightningInvoice,
      myRole: myRole ?? this.myRole,
      fiatAmount: fiatAmount ?? this.fiatAmount,
      fiatCurrency: fiatCurrency ?? this.fiatCurrency,
      satsAmount: satsAmount ?? this.satsAmount,
      pricePerBtc: pricePerBtc ?? this.pricePerBtc,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentDetails: paymentDetails ?? this.paymentDetails,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      paidAt: paidAt ?? this.paidAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelReason: cancelReason ?? this.cancelReason,
      receiptImages: receiptImages ?? this.receiptImages,
      paymentNote: paymentNote ?? this.paymentNote,
      messages: messages ?? this.messages,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'offerId': offerId,
    'offerTitle': offerTitle,
    'sellerPubkey': sellerPubkey,
    'buyerPubkey': buyerPubkey,
    'buyerLightningInvoice': buyerLightningInvoice,
    'myRole': myRole.name,
    'fiatAmount': fiatAmount,
    'fiatCurrency': fiatCurrency,
    'satsAmount': satsAmount,
    'pricePerBtc': pricePerBtc,
    'paymentMethod': paymentMethod,
    'paymentDetails': paymentDetails,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'paidAt': paidAt?.toIso8601String(),
    'confirmedAt': confirmedAt?.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'cancelledAt': cancelledAt?.toIso8601String(),
    'cancelReason': cancelReason,
    'receiptImages': receiptImages,
    'paymentNote': paymentNote,
    'messages': messages.map((m) => m.toJson()).toList(),
  };

  factory P2PTrade.fromJson(Map<String, dynamic> json) => P2PTrade(
    id: json['id'] as String,
    offerId: json['offerId'] as String,
    offerTitle: json['offerTitle'] as String? ?? 'P2P Trade',
    sellerPubkey: json['sellerPubkey'] as String,
    buyerPubkey: json['buyerPubkey'] as String,
    buyerLightningInvoice: json['buyerLightningInvoice'] as String?,
    myRole: TradeRole.values.byName(json['myRole'] as String),
    fiatAmount: (json['fiatAmount'] as num).toDouble(),
    fiatCurrency: json['fiatCurrency'] as String? ?? 'NGN',
    satsAmount: json['satsAmount'] as int,
    pricePerBtc: (json['pricePerBtc'] as num).toDouble(),
    paymentMethod: json['paymentMethod'] as String,
    paymentDetails: json['paymentDetails'] != null 
        ? Map<String, String>.from(json['paymentDetails'] as Map)
        : null,
    status: TradeStatus.values.byName(json['status'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
    paidAt: json['paidAt'] != null ? DateTime.parse(json['paidAt'] as String) : null,
    confirmedAt: json['confirmedAt'] != null ? DateTime.parse(json['confirmedAt'] as String) : null,
    completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt'] as String) : null,
    cancelledAt: json['cancelledAt'] != null ? DateTime.parse(json['cancelledAt'] as String) : null,
    cancelReason: json['cancelReason'] as String?,
    receiptImages: (json['receiptImages'] as List?)?.cast<String>() ?? [],
    paymentNote: json['paymentNote'] as String?,
    messages: (json['messages'] as List?)
        ?.map((m) => TradeMessage.fromJson(m as Map<String, dynamic>))
        .toList() ?? [],
  );
}

/// A message in a trade chat
@immutable
class TradeMessage {
  final String id;
  final String senderPubkey;
  final String content;
  final DateTime timestamp;
  final MessageType type;
  final String? imageUrl;
  final bool isSystemMessage;

  const TradeMessage({
    required this.id,
    required this.senderPubkey,
    required this.content,
    required this.timestamp,
    this.type = MessageType.text,
    this.imageUrl,
    this.isSystemMessage = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderPubkey': senderPubkey,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
    'type': type.name,
    'imageUrl': imageUrl,
    'isSystemMessage': isSystemMessage,
  };

  factory TradeMessage.fromJson(Map<String, dynamic> json) => TradeMessage(
    id: json['id'] as String,
    senderPubkey: json['senderPubkey'] as String,
    content: json['content'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    type: MessageType.values.byName(json['type'] as String? ?? 'text'),
    imageUrl: json['imageUrl'] as String?,
    isSystemMessage: json['isSystemMessage'] as bool? ?? false,
  );
}

enum MessageType {
  text,
  system,
  receipt,
  tradeUpdate,
}

/// Main P2P State - Single Source of Truth
@immutable
class P2PState {
  /// All offers from Nostr relays (keyed by offer ID)
  final Map<String, NostrP2POffer> offers;
  
  /// Current user's offers (subset of offers)
  final Set<String> myOfferIds;
  
  /// Active and recent trades
  final Map<String, P2PTrade> trades;
  
  /// Loading states
  final bool isLoadingOffers;
  final bool isLoadingTrades;
  final bool isPublishing;
  
  /// Pagination - whether more offers are available
  final bool hasMoreOffers;
  
  /// Relay connection status
  final RelayConnectionStatus connectionStatus;
  
  /// Error message if any
  final String? error;
  
  /// Offers-specific error
  final String? offersError;
  
  /// Current user's pubkey
  final String? myPubkey;
  
  /// Last refresh timestamp
  final DateTime? lastRefresh;

  const P2PState({
    this.offers = const {},
    this.myOfferIds = const {},
    this.trades = const {},
    this.isLoadingOffers = false,
    this.isLoadingTrades = false,
    this.isPublishing = false,
    this.hasMoreOffers = true,
    this.connectionStatus = RelayConnectionStatus.disconnected,
    this.error,
    this.offersError,
    this.myPubkey,
    this.lastRefresh,
  });

  /// Get offers sorted by creation date (newest first)
  List<NostrP2POffer> get sortedOffers {
    final list = offers.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Get sell offers (for buyers to browse)
  List<NostrP2POffer> get sellOffers => sortedOffers
      .where((o) => o.type == P2POfferType.sell && o.status == P2POfferStatus.active)
      .toList();

  /// Get buy offers (for sellers to browse)
  List<NostrP2POffer> get buyOffers => sortedOffers
      .where((o) => o.type == P2POfferType.buy && o.status == P2POfferStatus.active)
      .toList();

  /// Get my offers
  List<NostrP2POffer> get myOffers => myOfferIds
      .map((id) => offers[id])
      .whereType<NostrP2POffer>()
      .toList();

  /// Get active trades
  List<P2PTrade> get activeTrades => trades.values
      .where((t) => t.isActive)
      .toList();

  /// Get completed trades
  List<P2PTrade> get completedTrades => trades.values
      .where((t) => t.status == TradeStatus.completed)
      .toList();

  /// Check if connected to relays
  bool get isConnected => connectionStatus == RelayConnectionStatus.connected;

  P2PState copyWith({
    Map<String, NostrP2POffer>? offers,
    Set<String>? myOfferIds,
    Map<String, P2PTrade>? trades,
    bool? isLoadingOffers,
    bool? isLoadingTrades,
    bool? isPublishing,
    bool? hasMoreOffers,
    RelayConnectionStatus? connectionStatus,
    String? error,
    String? offersError,
    String? myPubkey,
    DateTime? lastRefresh,
  }) {
    return P2PState(
      offers: offers ?? this.offers,
      myOfferIds: myOfferIds ?? this.myOfferIds,
      trades: trades ?? this.trades,
      isLoadingOffers: isLoadingOffers ?? this.isLoadingOffers,
      isLoadingTrades: isLoadingTrades ?? this.isLoadingTrades,
      isPublishing: isPublishing ?? this.isPublishing,
      hasMoreOffers: hasMoreOffers ?? this.hasMoreOffers,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      error: error,
      offersError: offersError,
      myPubkey: myPubkey ?? this.myPubkey,
      lastRefresh: lastRefresh ?? this.lastRefresh,
    );
  }
}
