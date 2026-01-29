import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/services/nostr/nostr_service.dart';
import 'package:sabi_wallet/services/payment_notification_service.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';
import '../services/p2p_nostr_service.dart';
import '../services/p2p_trade_storage.dart';
import '../data/p2p_state.dart';

/// Single source of truth provider for P2P v2
/// Manages all P2P state: offers, trades, messages, connection
final p2pV2Provider = StateNotifierProvider<P2PStateNotifier, P2PState>((ref) {
  return P2PStateNotifier();
});

/// P2P v2 State Notifier
/// 
/// This is the ONLY provider you need for P2P v2.
/// It manages:
/// - Offers (browse & my offers)
/// - Active trades
/// - Trade messages
/// - Connection status
class P2PStateNotifier extends StateNotifier<P2PState> {
  P2PStateNotifier() : super(const P2PState()) {
    _init();
  }

  final P2PNostrService _nostrService = P2PNostrService();
  StreamSubscription? _offersSubscription;
  StreamSubscription? _messagesSubscription;
  StreamSubscription? _connectionSubscription;

  // ==================== Initialization ====================

  Future<void> _init() async {
    debugPrint('🚀 P2PStateNotifier: Initializing...');
    
    // Initialize trade storage first
    await P2PTradeStorage.init();
    
    // Load persisted trades
    final persistedTrades = await P2PTradeStorage.loadAllTrades();
    if (persistedTrades.isNotEmpty) {
      state = state.copyWith(trades: persistedTrades);
      debugPrint('📦 P2PStateNotifier: Loaded ${persistedTrades.length} trades from storage');
    }
    
    // Listen to connection status
    _connectionSubscription = _nostrService.connectionStream.listen((status) {
      state = state.copyWith(
        connectionStatus: _mapConnectionStatus(status),
      );
    });

    // Listen to offers updates
    _offersSubscription = _nostrService.offersStream.listen((offers) {
      _updateOffers(offers);
    });

    // Listen to incoming messages
    _messagesSubscription = _nostrService.messagesStream.listen((message) {
      _handleIncomingMessage(message);
    });

    // Start loading
    await refreshOffers();
  }

  @override
  void dispose() {
    _offersSubscription?.cancel();
    _messagesSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }

  // ==================== Getters ====================

  /// Current user's pubkey
  String? get myPubkey => _nostrService.currentPubkey;

  /// Whether user has Nostr identity
  bool get hasIdentity => _nostrService.hasIdentity;

  /// All offers for browsing (excluding my own)
  List<NostrP2POffer> get browseOffers => state.offers.values
      .where((o) => o.pubkey != myPubkey)
      .where((o) => o.status == P2POfferStatus.active)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// My own offers
  List<NostrP2POffer> get myOffers => state.offers.values
      .where((o) => o.pubkey == myPubkey)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Active trades (where I'm buyer or seller)
  List<P2PTrade> get activeTrades => state.trades.values
      .where((t) => !t.isCompleted && !t.isCancelled)
      .toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  /// Completed trades
  List<P2PTrade> get completedTrades => state.trades.values
      .where((t) => t.isCompleted)
      .toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  // ==================== Offers ====================

  /// Refresh all offers from relays with optional filters
  Future<void> refreshOffers({
    String? location,
    String? currency,
    P2POfferType? type,
    String? paymentMethod,
  }) async {
    if (state.isLoadingOffers) return;

    state = state.copyWith(
      isLoadingOffers: true,
      offersError: null,
    );

    try {
      await _nostrService.init();
      
      // Fetch offers with filters
      final offers = await _nostrService.refreshOffers(
        location: location,
        currency: currency,
        type: type,
        paymentMethod: paymentMethod,
      );
      debugPrint('📦 P2PStateNotifier: Got ${offers.length} Sabi Wallet P2P offers');
      
      // Update state with fetched offers
      _updateOffers(offers);
      
      // Also fetch my offers specifically
      final myOffers = await _nostrService.fetchMyOffers();
      if (myOffers.isNotEmpty) {
        _updateOffers(myOffers);
      }
      
      state = state.copyWith(
        isLoadingOffers: false,
        hasMoreOffers: offers.length >= 200, // Assume more if we hit limit
      );
      debugPrint('✅ P2PStateNotifier: Offers refreshed, total: ${state.offers.length}');
    } catch (e) {
      debugPrint('❌ P2PStateNotifier: Failed to refresh offers: $e');
      state = state.copyWith(
        isLoadingOffers: false,
        offersError: e.toString(),
      );
    }
  }

  /// Load more offers (pagination)
  Future<void> loadMoreOffers({
    String? location,
    String? currency,
    P2POfferType? type,
    String? paymentMethod,
  }) async {
    if (state.isLoadingOffers || !state.hasMoreOffers) return;

    state = state.copyWith(isLoadingOffers: true);

    try {
      final currentCount = state.offers.length;
      final moreOffers = await _nostrService.loadMoreOffers(
        offset: currentCount,
        location: location,
        currency: currency,
        type: type,
        paymentMethod: paymentMethod,
      );
      
      // Add new offers to state
      if (moreOffers.isNotEmpty) {
        _updateOffers(moreOffers);
      }
      
      state = state.copyWith(
        isLoadingOffers: false,
        hasMoreOffers: moreOffers.length >= 50, // Assume more if we hit limit
      );
      
      debugPrint('✅ P2PStateNotifier: Loaded ${moreOffers.length} more offers');
    } catch (e) {
      debugPrint('❌ P2PStateNotifier: Failed to load more offers: $e');
      state = state.copyWith(isLoadingOffers: false);
    }
  }

  /// Get a specific offer
  NostrP2POffer? getOffer(String offerId) {
    return state.offers[offerId];
  }

  /// Publish a new offer
  Future<String?> publishOffer({
    required P2POfferType type,
    required String title,
    required String description,
    required double pricePerBtc,
    required String currency,
    required int minSats,
    required int maxSats,
    required List<String> paymentMethods,
    String? location,
    Map<String, String>? paymentDetails,
  }) async {
    state = state.copyWith(isPublishing: true);

    try {
      final eventId = await _nostrService.publishOffer(
        type: type,
        title: title,
        description: description,
        pricePerBtc: pricePerBtc,
        currency: currency,
        minSats: minSats,
        maxSats: maxSats,
        paymentMethods: paymentMethods,
        location: location,
        paymentDetails: paymentDetails,
      );

      state = state.copyWith(isPublishing: false);
      
      // Refresh my offers
      await _nostrService.fetchMyOffers();
      
      return eventId;
    } catch (e) {
      debugPrint('❌ P2PStateNotifier: Failed to publish offer: $e');
      state = state.copyWith(isPublishing: false);
      rethrow;
    }
  }

  /// Update an existing offer
  Future<bool> updateOffer(NostrP2POffer offer) async {
    try {
      final success = await _nostrService.updateOffer(offer);
      if (success) {
        await _nostrService.fetchMyOffers();
      }
      return success;
    } catch (e) {
      debugPrint('❌ P2PStateNotifier: Failed to update offer: $e');
      return false;
    }
  }

  /// Delete an offer
  Future<bool> deleteOffer(String offerId) async {
    try {
      final success = await _nostrService.deleteOffer(offerId);
      if (success) {
        final newOffers = Map<String, NostrP2POffer>.from(state.offers);
        newOffers.remove(offerId);
        
        final newMyOfferIds = Set<String>.from(state.myOfferIds);
        newMyOfferIds.remove(offerId);
        
        state = state.copyWith(
          offers: newOffers,
          myOfferIds: newMyOfferIds,
        );
      }
      return success;
    } catch (e) {
      debugPrint('❌ P2PStateNotifier: Failed to delete offer: $e');
      return false;
    }
  }

  // ==================== Trades ====================

  /// Start a new trade (as buyer)
  /// 
  /// The buyer provides their Lightning invoice so the seller can
  /// release Bitcoin to them after confirming fiat payment.
  Future<P2PTrade?> initiateTrade({
    required String offerId,
    required int amountSats,
    required String paymentMethod,
    String? lightningInvoice,
  }) async {
    final offer = state.offers[offerId];
    if (offer == null) {
      debugPrint('❌ P2PStateNotifier: Offer not found: $offerId');
      return null;
    }

    final buyerPubkey = myPubkey;
    if (buyerPubkey == null) {
      debugPrint('❌ P2PStateNotifier: No identity');
      return null;
    }

    // Calculate fiat amount
    final btcAmount = amountSats / 100000000;
    final fiatAmount = btcAmount * offer.pricePerBtc;

    // Create trade
    final trade = P2PTrade(
      id: 'trade_${DateTime.now().millisecondsSinceEpoch}_${buyerPubkey.substring(0, 8)}',
      offerId: offerId,
      offerTitle: offer.title,
      buyerPubkey: buyerPubkey,
      sellerPubkey: offer.pubkey,
      buyerLightningInvoice: lightningInvoice,
      myRole: TradeRole.buyer,
      satsAmount: amountSats,
      fiatAmount: fiatAmount,
      fiatCurrency: offer.currency,
      pricePerBtc: offer.pricePerBtc,
      paymentMethod: paymentMethod,
      status: TradeStatus.requested,
      createdAt: DateTime.now(),
    );

    // Add to state
    final newTrades = Map<String, P2PTrade>.from(state.trades);
    newTrades[trade.id] = trade;
    state = state.copyWith(trades: newTrades);
    
    // Persist to storage
    await P2PTradeStorage.saveTrade(trade);

    // Send trade request message (includes invoice if provided)
    await _nostrService.sendTradeMessage(
      tradeId: trade.id,
      recipientPubkey: offer.pubkey,
      type: TradeMessageType.tradeRequest,
      amountSats: amountSats,
      lightningInvoice: lightningInvoice,
      content: 'Trade request: $amountSats sats via $paymentMethod',
    );

    debugPrint('✅ P2PStateNotifier: Trade initiated: ${trade.id}');
    return trade;
  }

  /// Submit Lightning invoice (as buyer)
  /// 
  /// If the buyer didn't provide an invoice during trade initiation,
  /// they can submit it later with this method.
  Future<bool> submitBuyerInvoice(String tradeId, String lightningInvoice) async {
    final trade = state.trades[tradeId];
    if (trade == null) return false;

    if (trade.myRole != TradeRole.buyer) {
      debugPrint('❌ P2PStateNotifier: Only buyer can submit invoice');
      return false;
    }

    final updatedTrade = trade.copyWith(
      buyerLightningInvoice: lightningInvoice,
    );

    _updateTrade(updatedTrade);

    // Notify seller about the invoice
    await _nostrService.sendTradeMessage(
      tradeId: tradeId,
      recipientPubkey: trade.sellerPubkey,
      type: TradeMessageType.invoiceSubmitted,
      lightningInvoice: lightningInvoice,
      content: 'Lightning invoice submitted for payment.',
    );

    return true;
  }

  /// Accept a trade request (as seller)
  Future<bool> acceptTrade(String tradeId) async {
    final trade = state.trades[tradeId];
    if (trade == null) return false;

    final updatedTrade = trade.copyWith(
      status: TradeStatus.awaitingPayment,
    );

    _updateTrade(updatedTrade);

    await _nostrService.sendTradeMessage(
      tradeId: tradeId,
      recipientPubkey: trade.buyerPubkey,
      type: TradeMessageType.tradeAccepted,
      content: 'Trade accepted. Please send payment.',
    );

    return true;
  }

  /// Reject a trade request (as seller)
  Future<bool> rejectTrade(String tradeId, {String? reason}) async {
    final trade = state.trades[tradeId];
    if (trade == null) return false;

    final updatedTrade = trade.copyWith(
      status: TradeStatus.cancelled,
      cancelledAt: DateTime.now(),
      cancelReason: reason,
    );

    _updateTrade(updatedTrade);

    await _nostrService.sendTradeMessage(
      tradeId: tradeId,
      recipientPubkey: trade.buyerPubkey,
      type: TradeMessageType.tradeRejected,
      content: reason ?? 'Trade rejected.',
    );

    return true;
  }

  /// Mark payment as sent (as buyer)
  Future<bool> markPaymentSent(String tradeId) async {
    final trade = state.trades[tradeId];
    if (trade == null) return false;

    final updatedTrade = trade.copyWith(
      status: TradeStatus.paymentSent,
      paidAt: DateTime.now(),
    );

    _updateTrade(updatedTrade);

    await _nostrService.sendTradeMessage(
      tradeId: tradeId,
      recipientPubkey: trade.sellerPubkey,
      type: TradeMessageType.paymentSent,
      content: 'Payment sent. Please check your account.',
    );

    return true;
  }

  /// Upload payment receipt (as buyer)
  Future<bool> uploadReceipt(String tradeId, String imageUrl) async {
    final trade = state.trades[tradeId];
    if (trade == null) return false;

    final updatedReceipts = [...trade.receiptImages, imageUrl];
    final updatedTrade = trade.copyWith(
      receiptImages: updatedReceipts,
    );

    _updateTrade(updatedTrade);

    await _nostrService.sendTradeMessage(
      tradeId: tradeId,
      recipientPubkey: trade.sellerPubkey,
      type: TradeMessageType.receiptUploaded,
      imageUrl: imageUrl,
      content: 'Payment receipt uploaded.',
    );

    return true;
  }

  /// Confirm payment received (as seller)
  Future<bool> confirmPayment(String tradeId) async {
    final trade = state.trades[tradeId];
    if (trade == null) return false;

    final updatedTrade = trade.copyWith(
      status: TradeStatus.paymentConfirmed,
      confirmedAt: DateTime.now(),
    );

    _updateTrade(updatedTrade);

    await _nostrService.sendTradeMessage(
      tradeId: tradeId,
      recipientPubkey: trade.buyerPubkey,
      type: TradeMessageType.paymentConfirmed,
      content: 'Payment confirmed. Releasing Bitcoin...',
    );

    return true;
  }

  /// Release Bitcoin (as seller)
  /// 
  /// This sends the Lightning payment to the buyer's invoice/address.
  /// Since Breez SDK Spark doesn't support hold invoices, we use a
  /// reputation-based "seller-first" approach:
  /// 1. Buyer sends fiat to seller
  /// 2. Seller confirms fiat received
  /// 3. Seller releases BTC via Lightning
  Future<bool> releaseBitcoin(String tradeId) async {
    final trade = state.trades[tradeId];
    if (trade == null) {
      debugPrint('❌ P2PStateNotifier.releaseBitcoin: Trade not found');
      return false;
    }

    if (trade.buyerLightningInvoice == null || trade.buyerLightningInvoice!.isEmpty) {
      debugPrint('❌ P2PStateNotifier.releaseBitcoin: No buyer Lightning invoice');
      return false;
    }

    // Update status to releasing
    var updatedTrade = trade.copyWith(
      status: TradeStatus.releasing,
    );
    _updateTrade(updatedTrade);

    try {
      debugPrint('⚡ P2PStateNotifier: Sending ${trade.satsAmount} sats to buyer...');
      
      // Send Lightning payment using Breez SDK
      await BreezSparkService.sendPayment(
        trade.buyerLightningInvoice!,
        sats: trade.satsAmount,
        recipientName: 'P2P Buyer',
        comment: 'P2P Trade #${tradeId.substring(0, 8)}',
      );

      debugPrint('✅ P2PStateNotifier: Lightning payment sent successfully!');

      // Mark trade as completed
      updatedTrade = updatedTrade.copyWith(
        status: TradeStatus.completed,
        completedAt: DateTime.now(),
      );
      _updateTrade(updatedTrade);

      // Notify buyer via Nostr DM
      await _nostrService.sendTradeMessage(
        tradeId: tradeId,
        recipientPubkey: trade.buyerPubkey,
        type: TradeMessageType.btcReleased,
        amountSats: trade.satsAmount,
        content: 'Bitcoin released! ${trade.satsAmount} sats sent to your wallet.',
      );

      return true;
    } catch (e) {
      debugPrint('❌ P2PStateNotifier: Failed to release Bitcoin: $e');
      
      // Revert to paymentConfirmed status on failure
      updatedTrade = updatedTrade.copyWith(
        status: TradeStatus.paymentConfirmed,
      );
      _updateTrade(updatedTrade);
      
      rethrow;
    }
  }

  /// Cancel a trade
  Future<bool> cancelTrade(String tradeId, {String? reason}) async {
    final trade = state.trades[tradeId];
    if (trade == null) return false;

    final updatedTrade = trade.copyWith(
      status: TradeStatus.cancelled,
      cancelledAt: DateTime.now(),
      cancelReason: reason,
    );

    _updateTrade(updatedTrade);

    // Notify counterparty
    final recipientPubkey = trade.buyerPubkey == myPubkey 
        ? trade.sellerPubkey 
        : trade.buyerPubkey;

    await _nostrService.sendTradeMessage(
      tradeId: tradeId,
      recipientPubkey: recipientPubkey,
      type: TradeMessageType.tradeCancelled,
      content: reason ?? 'Trade cancelled.',
    );

    return true;
  }

  /// Send a chat message in a trade
  Future<bool> sendChatMessage(String tradeId, String message) async {
    final trade = state.trades[tradeId];
    if (trade == null) return false;

    final recipientPubkey = trade.buyerPubkey == myPubkey 
        ? trade.sellerPubkey 
        : trade.buyerPubkey;

    return await _nostrService.sendTradeMessage(
      tradeId: tradeId,
      recipientPubkey: recipientPubkey,
      type: TradeMessageType.chat,
      content: message,
    );
  }

  /// Get messages for a trade
  List<TradeMessage> getTradeMessages(String tradeId) {
    return state.trades[tradeId]?.messages ?? [];
  }

  // ==================== Private Methods ====================

  void _updateOffers(List<NostrP2POffer> offers) {
    debugPrint('🔄 P2PStateNotifier._updateOffers: Processing ${offers.length} offers');
    
    final newOffers = Map<String, NostrP2POffer>.from(state.offers);
    final newMyOfferIds = Set<String>.from(state.myOfferIds);

    for (final offer in offers) {
      newOffers[offer.id] = offer;
      if (offer.pubkey == myPubkey) {
        newMyOfferIds.add(offer.id);
      }
    }

    debugPrint('📊 P2PStateNotifier._updateOffers: New total offers: ${newOffers.length}');
    
    state = state.copyWith(
      offers: newOffers,
      myOfferIds: newMyOfferIds,
    );
  }

  void _updateTrade(P2PTrade trade) {
    final newTrades = Map<String, P2PTrade>.from(state.trades);
    newTrades[trade.id] = trade;
    state = state.copyWith(trades: newTrades);
    
    // Persist to storage
    P2PTradeStorage.saveTrade(trade).then((_) {
      debugPrint('💾 P2PStateNotifier: Trade ${trade.id.substring(0, 8)}... persisted');
    }).catchError((e) {
      debugPrint('❌ P2PStateNotifier: Failed to persist trade: $e');
    });
  }

  void _handleIncomingMessage(TradeMessageEvent event) {
    final trade = state.trades[event.tradeId];
    
    if (trade == null) {
      // New trade from incoming request - we are the seller receiving a buy request
      if (event.type == TradeMessageType.tradeRequest) {
        _handleIncomingTradeRequest(event);
      } else {
        debugPrint('⚠️ P2PStateNotifier: Unknown trade ${event.tradeId} for message type ${event.type}');
      }
      return;
    }

    // Add message to trade
    final message = TradeMessage(
      id: event.id,
      senderPubkey: event.senderPubkey,
      content: event.content ?? event.typeLabel,
      imageUrl: event.imageUrl,
      timestamp: event.timestamp,
      isSystemMessage: event.type != TradeMessageType.chat,
    );

    final updatedMessages = [...trade.messages, message];
    var updatedTrade = trade.copyWith(
      messages: updatedMessages,
    );
    
    // Handle invoice submission - update buyer's Lightning invoice
    if (event.type == TradeMessageType.invoiceSubmitted && event.lightningInvoice != null) {
      updatedTrade = updatedTrade.copyWith(
        buyerLightningInvoice: event.lightningInvoice,
      );
      debugPrint('📝 P2PStateNotifier: Buyer submitted Lightning invoice');
    }
    
    // Handle trade request with invoice attached
    if (event.type == TradeMessageType.tradeRequest && event.lightningInvoice != null) {
      updatedTrade = updatedTrade.copyWith(
        buyerLightningInvoice: event.lightningInvoice,
      );
    }

    // Update trade status based on message type
    final newStatus = _getStatusFromMessageType(event.type);
    if (newStatus != null) {
      _updateTrade(updatedTrade.copyWith(status: newStatus));
      
      // Show notification for important status changes
      _notifyTradeStatusChange(trade, event.type);
    } else {
      _updateTrade(updatedTrade);
      
      // Show notification for chat messages or invoice submission
      if (event.type == TradeMessageType.chat) {
        _showTradeNotification(
          title: '💬 New Message',
          body: event.content ?? 'New message in your trade',
          tradeId: trade.id,
        );
      } else if (event.type == TradeMessageType.invoiceSubmitted) {
        _showTradeNotification(
          title: '⚡ Invoice Received',
          body: 'Buyer submitted their Lightning invoice',
          tradeId: trade.id,
        );
      }
    }
  }
  
  /// Show notification based on trade status change
  void _notifyTradeStatusChange(P2PTrade trade, TradeMessageType messageType) {
    final isBuyer = trade.myRole == TradeRole.buyer;
    
    String title;
    String body;
    
    switch (messageType) {
      case TradeMessageType.tradeAccepted:
        title = '✅ Trade Accepted';
        body = isBuyer 
            ? 'Seller accepted your trade! Please send payment.'
            : 'You accepted the trade. Waiting for payment.';
        break;
      case TradeMessageType.tradeRejected:
        title = '❌ Trade Rejected';
        body = 'The trade was rejected.';
        break;
      case TradeMessageType.paymentSent:
        title = '💸 Payment Sent';
        body = isBuyer 
            ? 'Waiting for seller to confirm payment.'
            : 'Buyer marked payment as sent. Please verify and confirm.';
        break;
      case TradeMessageType.paymentConfirmed:
        title = '✅ Payment Confirmed';
        body = isBuyer 
            ? 'Seller confirmed your payment!'
            : 'You confirmed the payment. Releasing Bitcoin...';
        break;
      case TradeMessageType.btcReleased:
        title = '⚡ Bitcoin Released';
        body = 'Bitcoin is being sent via Lightning!';
        break;
      case TradeMessageType.tradeCompleted:
        title = '🎉 Trade Complete';
        body = 'Your P2P trade was completed successfully!';
        break;
      case TradeMessageType.tradeCancelled:
        title = '🚫 Trade Cancelled';
        body = 'The trade was cancelled.';
        break;
      default:
        return; // No notification for other types
    }
    
    _showTradeNotification(title: title, body: body, tradeId: trade.id);
  }

  /// Handle incoming trade request - creates a new trade where we are the seller
  void _handleIncomingTradeRequest(TradeMessageEvent event) {
    debugPrint('📥 P2PStateNotifier: Received trade request from ${event.senderPubkey.substring(0, 8)}...');
    
    // Find the related offer to get details
    final relatedOffer = state.offers[event.tradeId] ?? 
                         state.offers.values.firstWhere(
                           (o) => o.pubkey == myPubkey,
                           orElse: () => throw Exception('No matching offer found'),
                         );
    
    // Create trade as seller
    final trade = P2PTrade(
      id: event.tradeId,
      offerId: relatedOffer.id,
      offerTitle: relatedOffer.title,
      buyerPubkey: event.senderPubkey,
      sellerPubkey: myPubkey ?? '',
      myRole: TradeRole.seller,
      satsAmount: event.amountSats ?? relatedOffer.minAmountSats ?? 10000,
      fiatAmount: _calculateFiatAmount(
        event.amountSats ?? relatedOffer.minAmountSats ?? 10000,
        relatedOffer.pricePerBtc,
      ),
      fiatCurrency: relatedOffer.currency,
      pricePerBtc: relatedOffer.pricePerBtc,
      paymentMethod: relatedOffer.paymentMethods.firstOrNull ?? 'Bank Transfer',
      paymentDetails: relatedOffer.paymentAccountDetails,
      status: TradeStatus.requested,
      createdAt: event.timestamp,
      messages: [
        TradeMessage(
          id: event.id,
          senderPubkey: event.senderPubkey,
          content: event.content ?? 'Trade request received',
          timestamp: event.timestamp,
          isSystemMessage: true,
        ),
      ],
    );
    
    // Add to state
    final newTrades = Map<String, P2PTrade>.from(state.trades);
    newTrades[trade.id] = trade;
    state = state.copyWith(trades: newTrades);
    
    // Persist to storage
    P2PTradeStorage.saveTrade(trade);
    
    debugPrint('✅ P2PStateNotifier: Trade request added - ${trade.id}');
    
    // Send local notification to alert seller
    _showTradeNotification(
      title: '🛒 New Trade Request',
      body: 'Someone wants to buy ${trade.formattedAmount} from your offer',
      tradeId: trade.id,
    );
  }
  
  /// Show a local notification for trade updates
  void _showTradeNotification({
    required String title,
    required String body,
    required String tradeId,
  }) {
    LocalNotificationService.showPaymentNotification(
      title: title,
      body: body,
      notificationId: 'p2p_trade_$tradeId',
      payload: 'p2p_trade:$tradeId',
    );
  }
  
  double _calculateFiatAmount(int sats, double pricePerBtc) {
    return (sats / 100000000) * pricePerBtc;
  }

  TradeStatus? _getStatusFromMessageType(TradeMessageType type) {
    switch (type) {
      case TradeMessageType.tradeAccepted:
        return TradeStatus.awaitingPayment;
      case TradeMessageType.tradeRejected:
      case TradeMessageType.tradeCancelled:
        return TradeStatus.cancelled;
      case TradeMessageType.paymentSent:
        return TradeStatus.paymentSent;
      case TradeMessageType.paymentConfirmed:
        return TradeStatus.paymentConfirmed;
      case TradeMessageType.btcReleased:
        return TradeStatus.releasing;
      case TradeMessageType.tradeCompleted:
        return TradeStatus.completed;
      default:
        return null;
    }
  }

  RelayConnectionStatus _mapConnectionStatus(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.disconnected:
        return RelayConnectionStatus.disconnected;
      case ConnectionStatus.connecting:
        return RelayConnectionStatus.connecting;
      case ConnectionStatus.connected:
        return RelayConnectionStatus.connected;
      case ConnectionStatus.error:
        return RelayConnectionStatus.error;
    }
  }
}

// ==================== Convenience Providers ====================

/// Browse offers (excluding my own)
final p2pBrowseOffersProvider = Provider<List<NostrP2POffer>>((ref) {
  final notifier = ref.watch(p2pV2Provider.notifier);
  return notifier.browseOffers;
});

/// My offers
final p2pMyOffersProvider = Provider<List<NostrP2POffer>>((ref) {
  final notifier = ref.watch(p2pV2Provider.notifier);
  return notifier.myOffers;
});

/// Active trades
final p2pActiveTradesProvider = Provider<List<P2PTrade>>((ref) {
  final notifier = ref.watch(p2pV2Provider.notifier);
  return notifier.activeTrades;
});

/// Loading state
final p2pIsLoadingProvider = Provider<bool>((ref) {
  final state = ref.watch(p2pV2Provider);
  return state.isLoadingOffers || state.isLoadingTrades;
});

/// Connection status
final p2pConnectionStatusProvider = Provider<RelayConnectionStatus>((ref) {
  final state = ref.watch(p2pV2Provider);
  return state.connectionStatus;
});

/// Specific offer by ID
final p2pOfferProvider = Provider.family<NostrP2POffer?, String>((ref, offerId) {
  final state = ref.watch(p2pV2Provider);
  return state.offers[offerId];
});

/// Specific trade by ID
final p2pTradeProvider = Provider.family<P2PTrade?, String>((ref, tradeId) {
  final state = ref.watch(p2pV2Provider);
  return state.trades[tradeId];
});
