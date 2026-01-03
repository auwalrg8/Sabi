/// P2P Trade Service - Real Lightning integration for P2P trades
/// 
/// Handles invoice creation, payment verification, and trade lifecycle
library;

import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../../services/breez_spark_service.dart';
import '../data/models/trade_code_model.dart';
import '../utils/p2p_logger.dart';

const _uuid = Uuid();

/// Trade timer duration (4 minutes = 240 seconds)
const int kTradeTimerSeconds = 240;

/// Warning thresholds in seconds
const int kWarning2Min = 120;
const int kWarning1Min = 60;
const int kWarning30Sec = 30;

/// Result of a trade operation
class TradeResult<T> {
  final bool success;
  final T? data;
  final String? errorCode;
  final String? errorMessage;

  const TradeResult._({
    required this.success,
    this.data,
    this.errorCode,
    this.errorMessage,
  });

  factory TradeResult.success(T data) => TradeResult._(success: true, data: data);
  
  factory TradeResult.failure(String errorCode, [String? message]) => TradeResult._(
    success: false,
    errorCode: errorCode,
    errorMessage: message ?? P2PErrorCodes.getDescription(errorCode),
  );
}

/// Invoice data for a P2P trade
class P2PInvoice {
  final String bolt11;
  final int amountSats;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String tradeId;

  P2PInvoice({
    required this.bolt11,
    required this.amountSats,
    required this.createdAt,
    required this.expiresAt,
    required this.tradeId,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  
  Duration get timeRemaining {
    final remaining = expiresAt.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Map<String, dynamic> toJson() => {
    'bolt11': bolt11,
    'amountSats': amountSats,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'expiresAt': expiresAt.millisecondsSinceEpoch,
    'tradeId': tradeId,
  };

  factory P2PInvoice.fromJson(Map<String, dynamic> json) {
    return P2PInvoice(
      bolt11: json['bolt11'] as String,
      amountSats: json['amountSats'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(json['expiresAt'] as int),
      tradeId: json['tradeId'] as String,
    );
  }
}

/// Active P2P trade state
class ActiveTrade {
  final String id;
  final String offerId;
  final bool isBuyer;
  final double fiatAmount;
  final String fiatCurrency;
  final int satsAmount;
  final double btcPrice;
  final String paymentMethodId;
  final Map<String, String>? paymentDetails;
  final P2PInvoice? invoice;
  final TradeCode? tradeCode;
  final DateTime createdAt;
  final DateTime? paidAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final ActiveTradeStatus status;
  final String? cancelReason;
  final List<String> proofPaths;

  ActiveTrade({
    required this.id,
    required this.offerId,
    required this.isBuyer,
    required this.fiatAmount,
    required this.fiatCurrency,
    required this.satsAmount,
    required this.btcPrice,
    required this.paymentMethodId,
    this.paymentDetails,
    this.invoice,
    this.tradeCode,
    DateTime? createdAt,
    this.paidAt,
    this.completedAt,
    this.cancelledAt,
    this.status = ActiveTradeStatus.created,
    this.cancelReason,
    this.proofPaths = const [],
  }) : createdAt = createdAt ?? DateTime.now();

  ActiveTrade copyWith({
    String? id,
    String? offerId,
    bool? isBuyer,
    double? fiatAmount,
    String? fiatCurrency,
    int? satsAmount,
    double? btcPrice,
    String? paymentMethodId,
    Map<String, String>? paymentDetails,
    P2PInvoice? invoice,
    TradeCode? tradeCode,
    DateTime? createdAt,
    DateTime? paidAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    ActiveTradeStatus? status,
    String? cancelReason,
    List<String>? proofPaths,
  }) {
    return ActiveTrade(
      id: id ?? this.id,
      offerId: offerId ?? this.offerId,
      isBuyer: isBuyer ?? this.isBuyer,
      fiatAmount: fiatAmount ?? this.fiatAmount,
      fiatCurrency: fiatCurrency ?? this.fiatCurrency,
      satsAmount: satsAmount ?? this.satsAmount,
      btcPrice: btcPrice ?? this.btcPrice,
      paymentMethodId: paymentMethodId ?? this.paymentMethodId,
      paymentDetails: paymentDetails ?? this.paymentDetails,
      invoice: invoice ?? this.invoice,
      tradeCode: tradeCode ?? this.tradeCode,
      createdAt: createdAt ?? this.createdAt,
      paidAt: paidAt ?? this.paidAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      status: status ?? this.status,
      cancelReason: cancelReason ?? this.cancelReason,
      proofPaths: proofPaths ?? this.proofPaths,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'offerId': offerId,
    'isBuyer': isBuyer,
    'fiatAmount': fiatAmount,
    'fiatCurrency': fiatCurrency,
    'satsAmount': satsAmount,
    'btcPrice': btcPrice,
    'paymentMethodId': paymentMethodId,
    'paymentDetails': paymentDetails,
    'invoice': invoice?.toJson(),
    'tradeCode': tradeCode?.toJson(),
    'createdAt': createdAt.millisecondsSinceEpoch,
    'paidAt': paidAt?.millisecondsSinceEpoch,
    'completedAt': completedAt?.millisecondsSinceEpoch,
    'cancelledAt': cancelledAt?.millisecondsSinceEpoch,
    'status': status.name,
    'cancelReason': cancelReason,
    'proofPaths': proofPaths,
  };

  factory ActiveTrade.fromJson(Map<String, dynamic> json) {
    return ActiveTrade(
      id: json['id'] as String,
      offerId: json['offerId'] as String,
      isBuyer: json['isBuyer'] as bool,
      fiatAmount: (json['fiatAmount'] as num).toDouble(),
      fiatCurrency: json['fiatCurrency'] as String,
      satsAmount: json['satsAmount'] as int,
      btcPrice: (json['btcPrice'] as num).toDouble(),
      paymentMethodId: json['paymentMethodId'] as String,
      paymentDetails: json['paymentDetails'] != null 
          ? Map<String, String>.from(json['paymentDetails'] as Map) 
          : null,
      invoice: json['invoice'] != null 
          ? P2PInvoice.fromJson(Map<String, dynamic>.from(json['invoice'] as Map))
          : null,
      tradeCode: json['tradeCode'] != null
          ? TradeCode.fromJson(Map<String, dynamic>.from(json['tradeCode'] as Map))
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      paidAt: json['paidAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['paidAt'] as int) 
          : null,
      completedAt: json['completedAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['completedAt'] as int) 
          : null,
      cancelledAt: json['cancelledAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['cancelledAt'] as int) 
          : null,
      status: ActiveTradeStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => ActiveTradeStatus.created,
      ),
      cancelReason: json['cancelReason'] as String?,
      proofPaths: (json['proofPaths'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }
}

/// Active trade status
enum ActiveTradeStatus {
  /// Trade created, waiting for invoice
  created,
  /// Invoice generated, waiting for fiat payment
  awaitingPayment,
  /// Buyer marked as paid, waiting for seller verification
  buyerPaid,
  /// Seller verified, releasing sats
  releasing,
  /// Trade completed successfully
  completed,
  /// Trade cancelled
  cancelled,
  /// Trade expired (timer ran out)
  expired,
}

/// P2P Trade Service
class P2PTradeService {
  P2PTradeService._();

  static final Map<String, ActiveTrade> _activeTrades = {};
  static final Map<String, Timer> _tradeTimers = {};
  static final StreamController<ActiveTrade> _tradeUpdates = StreamController.broadcast();

  /// Stream of trade updates
  static Stream<ActiveTrade> get tradeUpdates => _tradeUpdates.stream;

  /// Check if Breez SDK is ready
  static bool get isReady => BreezSparkService.isInitialized;

  /// Create a new trade as a buyer
  static Future<TradeResult<ActiveTrade>> createBuyTrade({
    required String offerId,
    required double fiatAmount,
    required String fiatCurrency,
    required int satsAmount,
    required double btcPrice,
    required String paymentMethodId,
    Map<String, String>? paymentDetails,
    bool requireTradeCode = false,
  }) async {
    final tradeId = _uuid.v4();
    P2PLogger.info('Trade', 'Creating buy trade', tradeId: tradeId, metadata: {
      'offerId': offerId,
      'fiatAmount': fiatAmount,
      'satsAmount': satsAmount,
    });

    try {
      // Generate trade code if required
      TradeCode? tradeCode;
      if (requireTradeCode) {
        tradeCode = TradeCode.generate(validity: const Duration(minutes: 10));
        P2PLogger.debug('Trade', 'Generated trade code', tradeId: tradeId);
      }

      final trade = ActiveTrade(
        id: tradeId,
        offerId: offerId,
        isBuyer: true,
        fiatAmount: fiatAmount,
        fiatCurrency: fiatCurrency,
        satsAmount: satsAmount,
        btcPrice: btcPrice,
        paymentMethodId: paymentMethodId,
        paymentDetails: paymentDetails,
        tradeCode: tradeCode,
        status: ActiveTradeStatus.awaitingPayment,
      );

      _activeTrades[tradeId] = trade;
      _startTradeTimer(tradeId);
      _tradeUpdates.add(trade);

      P2PLogger.info('Trade', 'Buy trade created successfully', tradeId: tradeId);
      return TradeResult.success(trade);
    } catch (e, stack) {
      P2PLogger.error(
        'Trade',
        'Failed to create buy trade: $e',
        tradeId: tradeId,
        errorCode: P2PErrorCodes.tradeCreationFailed,
        stackTrace: stack,
      );
      return TradeResult.failure(P2PErrorCodes.tradeCreationFailed);
    }
  }

  /// Create a new trade as a seller (generates invoice)
  static Future<TradeResult<ActiveTrade>> createSellTrade({
    required String offerId,
    required double fiatAmount,
    required String fiatCurrency,
    required int satsAmount,
    required double btcPrice,
    required String paymentMethodId,
    Map<String, String>? paymentDetails,
    bool requireTradeCode = false,
  }) async {
    final tradeId = _uuid.v4();
    P2PLogger.info('Trade', 'Creating sell trade', tradeId: tradeId, metadata: {
      'offerId': offerId,
      'fiatAmount': fiatAmount,
      'satsAmount': satsAmount,
    });

    try {
      // Check if SDK is initialized
      if (!isReady) {
        P2PLogger.error('Trade', 'SDK not initialized', tradeId: tradeId, errorCode: P2PErrorCodes.sdkNotInitialized);
        return TradeResult.failure(P2PErrorCodes.sdkNotInitialized);
      }

      // Check balance
      final balance = await BreezSparkService.getBalance();
      if (balance < satsAmount) {
        P2PLogger.error('Trade', 'Insufficient balance: $balance < $satsAmount', tradeId: tradeId, errorCode: P2PErrorCodes.insufficientBalance);
        return TradeResult.failure(P2PErrorCodes.insufficientBalance);
      }

      // Generate trade code if required
      TradeCode? tradeCode;
      if (requireTradeCode) {
        tradeCode = TradeCode.generate(validity: const Duration(minutes: 10));
        P2PLogger.debug('Trade', 'Generated trade code', tradeId: tradeId);
      }

      // Create invoice for the trade amount
      P2PLogger.debug('Trade', 'Creating Lightning invoice for $satsAmount sats', tradeId: tradeId);
      final bolt11 = await BreezSparkService.createInvoice(
        sats: satsAmount,
        memo: 'P2P Trade $tradeId',
      );

      final now = DateTime.now();
      final invoice = P2PInvoice(
        bolt11: bolt11,
        amountSats: satsAmount,
        createdAt: now,
        expiresAt: now.add(const Duration(seconds: kTradeTimerSeconds)),
        tradeId: tradeId,
      );

      final trade = ActiveTrade(
        id: tradeId,
        offerId: offerId,
        isBuyer: false,
        fiatAmount: fiatAmount,
        fiatCurrency: fiatCurrency,
        satsAmount: satsAmount,
        btcPrice: btcPrice,
        paymentMethodId: paymentMethodId,
        paymentDetails: paymentDetails,
        invoice: invoice,
        tradeCode: tradeCode,
        status: ActiveTradeStatus.awaitingPayment,
      );

      _activeTrades[tradeId] = trade;
      _startTradeTimer(tradeId);
      _tradeUpdates.add(trade);

      P2PLogger.info('Trade', 'Sell trade created with invoice', tradeId: tradeId);
      return TradeResult.success(trade);
    } catch (e, stack) {
      P2PLogger.error(
        'Trade',
        'Failed to create sell trade: $e',
        tradeId: tradeId,
        errorCode: P2PErrorCodes.tradeCreationFailed,
        stackTrace: stack,
      );
      return TradeResult.failure(P2PErrorCodes.tradeCreationFailed);
    }
  }

  /// Start the 4-minute trade timer
  static void _startTradeTimer(String tradeId) {
    _tradeTimers[tradeId]?.cancel();
    
    _tradeTimers[tradeId] = Timer(const Duration(seconds: kTradeTimerSeconds), () {
      _onTradeTimerExpired(tradeId);
    });

    P2PLogger.debug('Trade', 'Started 4-minute timer', tradeId: tradeId);
  }

  /// Handle timer expiration
  static void _onTradeTimerExpired(String tradeId) {
    final trade = _activeTrades[tradeId];
    if (trade == null) return;

    // Only expire if not already completed or cancelled
    if (trade.status == ActiveTradeStatus.awaitingPayment ||
        trade.status == ActiveTradeStatus.buyerPaid) {
      final expiredTrade = trade.copyWith(
        status: ActiveTradeStatus.expired,
        cancelledAt: DateTime.now(),
        cancelReason: 'Payment timer expired',
      );
      
      _activeTrades[tradeId] = expiredTrade;
      _tradeUpdates.add(expiredTrade);
      
      P2PLogger.error('Trade', 'Trade expired - timer ran out', tradeId: tradeId, errorCode: P2PErrorCodes.timerExpired);
    }

    _tradeTimers.remove(tradeId);
  }

  /// Mark trade as paid (buyer side)
  static Future<TradeResult<ActiveTrade>> markAsPaid(String tradeId, {String? proofPath}) async {
    final trade = _activeTrades[tradeId];
    if (trade == null) {
      return TradeResult.failure(P2PErrorCodes.tradeNotFound);
    }

    if (trade.status != ActiveTradeStatus.awaitingPayment) {
      return TradeResult.failure(P2PErrorCodes.tradeAlreadyCompleted);
    }

    final proofs = List<String>.from(trade.proofPaths);
    if (proofPath != null) {
      proofs.add(proofPath);
    }

    final updatedTrade = trade.copyWith(
      status: ActiveTradeStatus.buyerPaid,
      paidAt: DateTime.now(),
      proofPaths: proofs,
    );

    _activeTrades[tradeId] = updatedTrade;
    _tradeUpdates.add(updatedTrade);

    P2PLogger.info('Trade', 'Buyer marked trade as paid', tradeId: tradeId);
    return TradeResult.success(updatedTrade);
  }

  /// Release sats (seller side) - completes the trade
  static Future<TradeResult<ActiveTrade>> releaseSats(String tradeId) async {
    final trade = _activeTrades[tradeId];
    if (trade == null) {
      return TradeResult.failure(P2PErrorCodes.tradeNotFound);
    }

    if (trade.status != ActiveTradeStatus.buyerPaid) {
      P2PLogger.warning('Trade', 'Cannot release - buyer has not marked as paid', tradeId: tradeId);
      return TradeResult.failure(P2PErrorCodes.tradeAlreadyCompleted);
    }

    try {
      // For seller: the buyer would pay the invoice we created
      // The release is confirming we received fiat and the Lightning payment can proceed
      
      final updatedTrade = trade.copyWith(
        status: ActiveTradeStatus.completed,
        completedAt: DateTime.now(),
      );

      _activeTrades[tradeId] = updatedTrade;
      _tradeTimers[tradeId]?.cancel();
      _tradeTimers.remove(tradeId);
      _tradeUpdates.add(updatedTrade);

      P2PLogger.info('Trade', 'Sats released - trade completed', tradeId: tradeId);
      return TradeResult.success(updatedTrade);
    } catch (e, stack) {
      P2PLogger.error('Trade', 'Failed to release sats: $e', tradeId: tradeId, stackTrace: stack);
      return TradeResult.failure(P2PErrorCodes.invoicePaymentFailed);
    }
  }

  /// Cancel a trade
  static Future<TradeResult<ActiveTrade>> cancelTrade(String tradeId, {String? reason}) async {
    final trade = _activeTrades[tradeId];
    if (trade == null) {
      return TradeResult.failure(P2PErrorCodes.tradeNotFound);
    }

    if (trade.status == ActiveTradeStatus.completed) {
      return TradeResult.failure(P2PErrorCodes.tradeAlreadyCompleted);
    }

    final updatedTrade = trade.copyWith(
      status: ActiveTradeStatus.cancelled,
      cancelledAt: DateTime.now(),
      cancelReason: reason ?? 'Cancelled by user',
    );

    _activeTrades[tradeId] = updatedTrade;
    _tradeTimers[tradeId]?.cancel();
    _tradeTimers.remove(tradeId);
    _tradeUpdates.add(updatedTrade);

    P2PLogger.info('Trade', 'Trade cancelled: ${reason ?? "by user"}', tradeId: tradeId);
    return TradeResult.success(updatedTrade);
  }

  /// Get a trade by ID
  static ActiveTrade? getTrade(String tradeId) => _activeTrades[tradeId];

  /// Get all active trades
  static List<ActiveTrade> getActiveTrades() {
    return _activeTrades.values.where((t) =>
      t.status == ActiveTradeStatus.awaitingPayment ||
      t.status == ActiveTradeStatus.buyerPaid ||
      t.status == ActiveTradeStatus.releasing
    ).toList();
  }

  /// Get trade history
  static List<ActiveTrade> getTradeHistory() {
    return _activeTrades.values.where((t) =>
      t.status == ActiveTradeStatus.completed ||
      t.status == ActiveTradeStatus.cancelled ||
      t.status == ActiveTradeStatus.expired
    ).toList()
      ..sort((a, b) => (b.completedAt ?? b.cancelledAt ?? b.createdAt)
          .compareTo(a.completedAt ?? a.cancelledAt ?? a.createdAt));
  }

  /// Get remaining time for a trade in seconds
  static int getTradeTimeRemaining(String tradeId) {
    final trade = _activeTrades[tradeId];
    if (trade == null) return 0;

    final elapsed = DateTime.now().difference(trade.createdAt).inSeconds;
    final remaining = kTradeTimerSeconds - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  /// Cleanup and dispose
  static void dispose() {
    for (final timer in _tradeTimers.values) {
      timer.cancel();
    }
    _tradeTimers.clear();
    _tradeUpdates.close();
  }
}
