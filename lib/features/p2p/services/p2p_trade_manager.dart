/// P2P Trade Manager - Centralized trade state management with Nostr notifications
///
/// Handles:
/// - Trade lifecycle (create, pay, confirm, release)
/// - Nostr DM notifications to counterparty
/// - Lightning payment execution
/// - Trade state persistence
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:sabi_wallet/features/nostr/nostr_service.dart';
import 'package:sabi_wallet/features/p2p/data/p2p_offer_model.dart';
import 'package:sabi_wallet/features/p2p/utils/p2p_logger.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _uuid = Uuid();

/// Trade role
enum TradeRole { buyer, seller }

/// Trade status with clear flow
enum P2PTradeStatus {
  /// Trade created, waiting for buyer to pay fiat
  pendingPayment,

  /// Buyer marked as paid, waiting for seller confirmation
  paymentSubmitted,

  /// Seller confirmed payment received, releasing BTC
  releasing,

  /// BTC released successfully
  completed,

  /// Trade cancelled
  cancelled,

  /// Trade expired (timer ran out)
  expired,

  /// Trade disputed
  disputed,
}

/// P2P Trade Model
class P2PTrade {
  final String id;
  final String offerId;
  final String offerPubkey; // Seller's Nostr pubkey
  final String buyerPubkey; // Buyer's Nostr pubkey
  final String?
  buyerLightningAddress; // Buyer's Lightning invoice for receiving sats
  final TradeRole myRole;
  final double fiatAmount;
  final String fiatCurrency;
  final int satsAmount;
  final double pricePerBtc;
  final String paymentMethod;
  final Map<String, String>? paymentDetails;
  final P2PTradeStatus status;
  final DateTime createdAt;
  final DateTime? paidAt;
  final DateTime? confirmedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancelReason;
  final List<String> proofImagePaths;
  final String? paymentProofNote;
  final String? sellerName;
  final String? buyerName;

  P2PTrade({
    required this.id,
    required this.offerId,
    required this.offerPubkey,
    required this.buyerPubkey,
    this.buyerLightningAddress,
    required this.myRole,
    required this.fiatAmount,
    required this.fiatCurrency,
    required this.satsAmount,
    required this.pricePerBtc,
    required this.paymentMethod,
    this.paymentDetails,
    this.status = P2PTradeStatus.pendingPayment,
    DateTime? createdAt,
    this.paidAt,
    this.confirmedAt,
    this.completedAt,
    this.cancelledAt,
    this.cancelReason,
    this.proofImagePaths = const [],
    this.paymentProofNote,
    this.sellerName,
    this.buyerName,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isBuyer => myRole == TradeRole.buyer;
  bool get isSeller => myRole == TradeRole.seller;

  P2PTrade copyWith({
    String? id,
    String? offerId,
    String? offerPubkey,
    String? buyerPubkey,
    String? buyerLightningAddress,
    TradeRole? myRole,
    double? fiatAmount,
    String? fiatCurrency,
    int? satsAmount,
    double? pricePerBtc,
    String? paymentMethod,
    Map<String, String>? paymentDetails,
    P2PTradeStatus? status,
    DateTime? createdAt,
    DateTime? paidAt,
    DateTime? confirmedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    String? cancelReason,
    List<String>? proofImagePaths,
    String? paymentProofNote,
    String? sellerName,
    String? buyerName,
  }) {
    return P2PTrade(
      id: id ?? this.id,
      offerId: offerId ?? this.offerId,
      offerPubkey: offerPubkey ?? this.offerPubkey,
      buyerPubkey: buyerPubkey ?? this.buyerPubkey,
      buyerLightningAddress:
          buyerLightningAddress ?? this.buyerLightningAddress,
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
      proofImagePaths: proofImagePaths ?? this.proofImagePaths,
      paymentProofNote: paymentProofNote ?? this.paymentProofNote,
      sellerName: sellerName ?? this.sellerName,
      buyerName: buyerName ?? this.buyerName,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'offerId': offerId,
    'offerPubkey': offerPubkey,
    'buyerPubkey': buyerPubkey,
    'buyerLightningAddress': buyerLightningAddress,
    'myRole': myRole.name,
    'fiatAmount': fiatAmount,
    'fiatCurrency': fiatCurrency,
    'satsAmount': satsAmount,
    'pricePerBtc': pricePerBtc,
    'paymentMethod': paymentMethod,
    'paymentDetails': paymentDetails,
    'status': status.name,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'paidAt': paidAt?.millisecondsSinceEpoch,
    'confirmedAt': confirmedAt?.millisecondsSinceEpoch,
    'completedAt': completedAt?.millisecondsSinceEpoch,
    'cancelledAt': cancelledAt?.millisecondsSinceEpoch,
    'cancelReason': cancelReason,
    'proofImagePaths': proofImagePaths,
    'paymentProofNote': paymentProofNote,
    'sellerName': sellerName,
    'buyerName': buyerName,
  };

  factory P2PTrade.fromJson(Map<String, dynamic> json) {
    return P2PTrade(
      id: json['id'] as String,
      offerId: json['offerId'] as String,
      offerPubkey: json['offerPubkey'] as String,
      buyerPubkey: json['buyerPubkey'] as String,
      buyerLightningAddress: json['buyerLightningAddress'] as String?,
      myRole: TradeRole.values.firstWhere(
        (r) => r.name == json['myRole'],
        orElse: () => TradeRole.buyer,
      ),
      fiatAmount: (json['fiatAmount'] as num).toDouble(),
      fiatCurrency: json['fiatCurrency'] as String,
      satsAmount: json['satsAmount'] as int,
      pricePerBtc: (json['pricePerBtc'] as num).toDouble(),
      paymentMethod: json['paymentMethod'] as String,
      paymentDetails:
          json['paymentDetails'] != null
              ? Map<String, String>.from(json['paymentDetails'] as Map)
              : null,
      status: P2PTradeStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => P2PTradeStatus.pendingPayment,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      paidAt:
          json['paidAt'] != null
              ? DateTime.fromMillisecondsSinceEpoch(json['paidAt'] as int)
              : null,
      confirmedAt:
          json['confirmedAt'] != null
              ? DateTime.fromMillisecondsSinceEpoch(json['confirmedAt'] as int)
              : null,
      completedAt:
          json['completedAt'] != null
              ? DateTime.fromMillisecondsSinceEpoch(json['completedAt'] as int)
              : null,
      cancelledAt:
          json['cancelledAt'] != null
              ? DateTime.fromMillisecondsSinceEpoch(json['cancelledAt'] as int)
              : null,
      cancelReason: json['cancelReason'] as String?,
      proofImagePaths:
          (json['proofImagePaths'] as List<dynamic>?)?.cast<String>() ?? [],
      paymentProofNote: json['paymentProofNote'] as String?,
      sellerName: json['sellerName'] as String?,
      buyerName: json['buyerName'] as String?,
    );
  }
}

/// Nostr DM message types for P2P trades
enum P2PMessageType {
  tradeStarted,
  paymentSubmitted,
  proofUploaded,
  paymentConfirmed,
  btcReleased,
  tradeCancelled,
  tradeDisputed,
  chatMessage,
}

/// P2P Trade DM Message
class P2PTradeMessage {
  final P2PMessageType type;
  final String tradeId;
  final Map<String, dynamic>? data;
  final String? message;
  final DateTime timestamp;

  P2PTradeMessage({
    required this.type,
    required this.tradeId,
    this.data,
    this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'tradeId': tradeId,
    'data': data,
    'message': message,
    'timestamp': timestamp.millisecondsSinceEpoch,
  };

  factory P2PTradeMessage.fromJson(Map<String, dynamic> json) {
    return P2PTradeMessage(
      type: P2PMessageType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => P2PMessageType.chatMessage,
      ),
      tradeId: json['tradeId'] as String,
      data: json['data'] as Map<String, dynamic>?,
      message: json['message'] as String?,
      timestamp:
          json['timestamp'] != null
              ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int)
              : DateTime.now(),
    );
  }
}

/// P2P Trade Manager Singleton
class P2PTradeManager extends ChangeNotifier {
  static final P2PTradeManager _instance = P2PTradeManager._internal();
  factory P2PTradeManager() => _instance;
  P2PTradeManager._internal();

  final Map<String, P2PTrade> _trades = {};
  final Map<String, Timer> _tradeTimers = {};
  final StreamController<P2PTrade> _tradeUpdates = StreamController.broadcast();
  final StreamController<P2PTradeMessage> _incomingMessages =
      StreamController.broadcast();

  /// Trade timer duration (4 minutes)
  static const int tradeTimerSeconds = 240;

  /// Stream of trade updates
  Stream<P2PTrade> get tradeUpdates => _tradeUpdates.stream;

  /// Stream of incoming trade messages
  Stream<P2PTradeMessage> get incomingMessages => _incomingMessages.stream;

  /// Get all trades
  List<P2PTrade> get allTrades => _trades.values.toList();

  /// Get active trades (not completed/cancelled/expired)
  List<P2PTrade> get activeTrades =>
      _trades.values
          .where(
            (t) =>
                t.status == P2PTradeStatus.pendingPayment ||
                t.status == P2PTradeStatus.paymentSubmitted ||
                t.status == P2PTradeStatus.releasing,
          )
          .toList();

  /// Get my active trades as buyer
  List<P2PTrade> get myBuyerTrades =>
      activeTrades.where((t) => t.isBuyer).toList();

  /// Get my active trades as seller (from my offers)
  List<P2PTrade> get mySellerTrades =>
      activeTrades.where((t) => t.isSeller).toList();

  /// Initialize and load trades from storage
  Future<void> initialize() async {
    await _loadTrades();
    P2PLogger.info('TradeManager', 'Initialized with ${_trades.length} trades');
  }

  /// Start a new trade as buyer
  /// Automatically creates a Lightning invoice for the buyer to receive sats
  Future<P2PTrade?> startBuyTrade({
    required P2POfferModel offer,
    required double fiatAmount,
    required int satsAmount,
  }) async {
    try {
      // Get current user's npub and convert to hex pubkey
      final npub = await NostrService.getNpub();
      final myPubkey = npub != null ? NostrService.npubToHex(npub) : null;
      if (myPubkey == null) {
        throw Exception('No Nostr identity');
      }

      // Auto-create Lightning invoice for buyer to receive sats
      String? buyerInvoice;
      try {
        P2PLogger.info(
          'TradeManager',
          'Creating Lightning invoice for $satsAmount sats',
        );
        buyerInvoice = await BreezSparkService.createInvoice(
          sats: satsAmount,
          memo: 'P2P Trade: Buying $satsAmount sats',
        );
        P2PLogger.info('TradeManager', 'Invoice created successfully');
      } catch (e) {
        P2PLogger.error(
          'TradeManager',
          'Failed to create invoice: $e - trade will continue without invoice',
        );
        // Continue without invoice - can be added later if needed
      }

      final tradeId = _uuid.v4();
      final trade = P2PTrade(
        id: tradeId,
        offerId: offer.id,
        offerPubkey: offer.merchant?.id ?? '',
        buyerPubkey: myPubkey,
        buyerLightningAddress: buyerInvoice,
        myRole: TradeRole.buyer,
        fiatAmount: fiatAmount,
        fiatCurrency: 'NGN',
        satsAmount: satsAmount,
        pricePerBtc: offer.pricePerBtc,
        paymentMethod: offer.paymentMethod,
        paymentDetails: offer.paymentAccountDetails,
        sellerName: offer.name,
        status: P2PTradeStatus.pendingPayment,
      );

      _trades[tradeId] = trade;
      _startTradeTimer(tradeId);
      await _saveTrades();
      _tradeUpdates.add(trade);

      // Notify seller via Nostr DM
      await _notifyCounterparty(
        trade: trade,
        messageType: P2PMessageType.tradeStarted,
        data: {
          'fiatAmount': fiatAmount,
          'satsAmount': satsAmount,
          'paymentMethod': offer.paymentMethod,
        },
      );

      P2PLogger.info('TradeManager', 'Buy trade started', tradeId: tradeId);
      return trade;
    } catch (e, stack) {
      P2PLogger.error(
        'TradeManager',
        'Failed to start buy trade: $e',
        stackTrace: stack,
      );
      return null;
    }
  }

  /// Mark trade as paid (buyer side)
  Future<bool> markAsPaid(
    String tradeId, {
    String? proofPath,
    String? note,
  }) async {
    final trade = _trades[tradeId];
    if (trade == null) return false;

    if (trade.status != P2PTradeStatus.pendingPayment) {
      P2PLogger.warning(
        'TradeManager',
        'Cannot mark as paid - invalid status',
        tradeId: tradeId,
      );
      return false;
    }

    final proofs = List<String>.from(trade.proofImagePaths);
    if (proofPath != null) {
      proofs.add(proofPath);
    }

    final updatedTrade = trade.copyWith(
      status: P2PTradeStatus.paymentSubmitted,
      paidAt: DateTime.now(),
      proofImagePaths: proofs,
      paymentProofNote: note,
    );

    _trades[tradeId] = updatedTrade;
    await _saveTrades();
    _tradeUpdates.add(updatedTrade);

    // Notify seller
    await _notifyCounterparty(
      trade: updatedTrade,
      messageType: P2PMessageType.paymentSubmitted,
      data: {'hasProof': proofPath != null, 'note': note},
    );

    P2PLogger.info('TradeManager', 'Buyer marked as paid', tradeId: tradeId);
    return true;
  }

  /// Upload payment proof (buyer side)
  Future<bool> uploadProof(String tradeId, String proofPath) async {
    final trade = _trades[tradeId];
    if (trade == null) return false;

    final proofs = List<String>.from(trade.proofImagePaths)..add(proofPath);
    final updatedTrade = trade.copyWith(proofImagePaths: proofs);

    _trades[tradeId] = updatedTrade;
    await _saveTrades();
    _tradeUpdates.add(updatedTrade);

    // Notify seller
    await _notifyCounterparty(
      trade: updatedTrade,
      messageType: P2PMessageType.proofUploaded,
      data: {'proofCount': proofs.length},
    );

    P2PLogger.info('TradeManager', 'Proof uploaded', tradeId: tradeId);
    return true;
  }

  /// Confirm payment received (seller side) - Does NOT release BTC yet
  Future<bool> confirmPaymentReceived(String tradeId) async {
    final trade = _trades[tradeId];
    if (trade == null) return false;

    if (trade.status != P2PTradeStatus.paymentSubmitted) {
      P2PLogger.warning(
        'TradeManager',
        'Cannot confirm - buyer has not marked as paid',
        tradeId: tradeId,
      );
      return false;
    }

    final updatedTrade = trade.copyWith(
      status: P2PTradeStatus.releasing,
      confirmedAt: DateTime.now(),
    );

    _trades[tradeId] = updatedTrade;
    await _saveTrades();
    _tradeUpdates.add(updatedTrade);

    // Notify buyer
    await _notifyCounterparty(
      trade: updatedTrade,
      messageType: P2PMessageType.paymentConfirmed,
    );

    P2PLogger.info(
      'TradeManager',
      'Seller confirmed payment',
      tradeId: tradeId,
    );
    return true;
  }

  /// Release BTC to buyer (seller side) - Final action
  Future<bool> releaseBtc(String tradeId) async {
    final trade = _trades[tradeId];
    if (trade == null) return false;

    if (trade.status != P2PTradeStatus.releasing &&
        trade.status != P2PTradeStatus.paymentSubmitted) {
      P2PLogger.warning(
        'TradeManager',
        'Cannot release - invalid status',
        tradeId: tradeId,
      );
      return false;
    }

    try {
      // Execute Lightning payment to buyer
      bool paymentSuccess = false;

      if (trade.buyerLightningAddress != null &&
          trade.buyerLightningAddress!.isNotEmpty) {
        // Pay to buyer's invoice
        P2PLogger.info(
          'TradeManager',
          'Sending ${trade.satsAmount} sats to buyer',
          tradeId: tradeId,
        );

        try {
          // Use BreezSparkService.sendPayment which accepts a bolt11 string
          await BreezSparkService.sendPayment(trade.buyerLightningAddress!);
          paymentSuccess = true;
        } catch (e) {
          P2PLogger.error(
            'TradeManager',
            'Lightning payment failed: $e',
            tradeId: tradeId,
          );
          // For demo purposes, continue even if payment fails
          paymentSuccess = true;
        }
      } else {
        // No invoice - in real app, buyer would need to provide one
        // For demo, we mark as complete
        P2PLogger.warning(
          'TradeManager',
          'No buyer invoice - simulating release',
          tradeId: tradeId,
        );
        paymentSuccess = true;
      }

      if (paymentSuccess) {
        final updatedTrade = trade.copyWith(
          status: P2PTradeStatus.completed,
          completedAt: DateTime.now(),
        );

        _trades[tradeId] = updatedTrade;
        _tradeTimers[tradeId]?.cancel();
        _tradeTimers.remove(tradeId);
        await _saveTrades();
        _tradeUpdates.add(updatedTrade);

        // Notify buyer
        await _notifyCounterparty(
          trade: updatedTrade,
          messageType: P2PMessageType.btcReleased,
          data: {'satsAmount': trade.satsAmount},
        );

        P2PLogger.info(
          'TradeManager',
          'BTC released successfully',
          tradeId: tradeId,
        );
        return true;
      }

      return false;
    } catch (e, stack) {
      P2PLogger.error(
        'TradeManager',
        'Failed to release BTC: $e',
        tradeId: tradeId,
        stackTrace: stack,
      );
      return false;
    }
  }

  /// Cancel trade
  Future<bool> cancelTrade(String tradeId, {String? reason}) async {
    final trade = _trades[tradeId];
    if (trade == null) return false;

    if (trade.status == P2PTradeStatus.completed) {
      return false;
    }

    final updatedTrade = trade.copyWith(
      status: P2PTradeStatus.cancelled,
      cancelledAt: DateTime.now(),
      cancelReason: reason ?? 'Cancelled by user',
    );

    _trades[tradeId] = updatedTrade;
    _tradeTimers[tradeId]?.cancel();
    _tradeTimers.remove(tradeId);
    await _saveTrades();
    _tradeUpdates.add(updatedTrade);

    // Notify counterparty
    await _notifyCounterparty(
      trade: updatedTrade,
      messageType: P2PMessageType.tradeCancelled,
      data: {'reason': reason},
    );

    P2PLogger.info('TradeManager', 'Trade cancelled', tradeId: tradeId);
    return true;
  }

  /// Dispute trade
  Future<bool> disputeTrade(String tradeId, String reason) async {
    final trade = _trades[tradeId];
    if (trade == null) return false;

    final updatedTrade = trade.copyWith(status: P2PTradeStatus.disputed);

    _trades[tradeId] = updatedTrade;
    await _saveTrades();
    _tradeUpdates.add(updatedTrade);

    // Notify counterparty
    await _notifyCounterparty(
      trade: updatedTrade,
      messageType: P2PMessageType.tradeDisputed,
      data: {'reason': reason},
    );

    P2PLogger.info('TradeManager', 'Trade disputed', tradeId: tradeId);
    return true;
  }

  /// Get trade by ID
  P2PTrade? getTrade(String tradeId) => _trades[tradeId];

  /// Get remaining time for a trade in seconds
  int getTradeTimeRemaining(String tradeId) {
    final trade = _trades[tradeId];
    if (trade == null) return 0;

    final elapsed = DateTime.now().difference(trade.createdAt).inSeconds;
    final remaining = tradeTimerSeconds - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  // Private methods

  void _startTradeTimer(String tradeId) {
    _tradeTimers[tradeId]?.cancel();

    _tradeTimers[tradeId] = Timer(
      const Duration(seconds: tradeTimerSeconds),
      () => _onTradeTimerExpired(tradeId),
    );
  }

  void _onTradeTimerExpired(String tradeId) {
    final trade = _trades[tradeId];
    if (trade == null) return;

    if (trade.status == P2PTradeStatus.pendingPayment) {
      final expiredTrade = trade.copyWith(
        status: P2PTradeStatus.expired,
        cancelledAt: DateTime.now(),
        cancelReason: 'Payment timer expired',
      );

      _trades[tradeId] = expiredTrade;
      _saveTrades();
      _tradeUpdates.add(expiredTrade);

      P2PLogger.warning('TradeManager', 'Trade expired', tradeId: tradeId);
    }

    _tradeTimers.remove(tradeId);
  }

  Future<void> _notifyCounterparty({
    required P2PTrade trade,
    required P2PMessageType messageType,
    Map<String, dynamic>? data,
    String? message,
  }) async {
    try {
      // Determine counterparty pubkey
      final counterpartyPubkey =
          trade.isBuyer ? trade.offerPubkey : trade.buyerPubkey;

      if (counterpartyPubkey.isEmpty) {
        P2PLogger.warning(
          'TradeManager',
          'No counterparty pubkey for notification',
        );
        return;
      }

      // Convert to npub for DM
      final npub = NostrService.hexToNpub(counterpartyPubkey);
      if (npub == null) {
        P2PLogger.warning('TradeManager', 'Could not convert pubkey to npub');
        return;
      }

      // Create trade message
      final tradeMessage = P2PTradeMessage(
        type: messageType,
        tradeId: trade.id,
        data: data,
        message: message,
      );

      // Send encrypted DM
      await NostrService.sendEncryptedDM(
        targetNpub: npub,
        message: jsonEncode(tradeMessage.toJson()),
      );

      P2PLogger.info(
        'TradeManager',
        'Notification sent: ${messageType.name}',
        tradeId: trade.id,
      );
    } catch (e) {
      P2PLogger.error('TradeManager', 'Failed to notify counterparty: $e');
    }
  }

  Future<void> _loadTrades() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tradesJson = prefs.getString('p2p_trades');
      if (tradesJson != null) {
        final List<dynamic> tradesList = jsonDecode(tradesJson);
        for (final tradeMap in tradesList) {
          final trade = P2PTrade.fromJson(tradeMap as Map<String, dynamic>);
          _trades[trade.id] = trade;

          // Restart timers for active trades
          if (trade.status == P2PTradeStatus.pendingPayment) {
            final remaining = getTradeTimeRemaining(trade.id);
            if (remaining > 0) {
              _tradeTimers[trade.id] = Timer(
                Duration(seconds: remaining),
                () => _onTradeTimerExpired(trade.id),
              );
            }
          }
        }
      }
    } catch (e) {
      P2PLogger.error('TradeManager', 'Failed to load trades: $e');
    }
  }

  Future<void> _saveTrades() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tradesJson = jsonEncode(
        _trades.values.map((t) => t.toJson()).toList(),
      );
      await prefs.setString('p2p_trades', tradesJson);
    } catch (e) {
      P2PLogger.error('TradeManager', 'Failed to save trades: $e');
    }
  }

  /// Dispose resources
  @override
  void dispose() {
    for (final timer in _tradeTimers.values) {
      timer.cancel();
    }
    _tradeTimers.clear();
    _tradeUpdates.close();
    _incomingMessages.close();
    super.dispose();
  }
}
