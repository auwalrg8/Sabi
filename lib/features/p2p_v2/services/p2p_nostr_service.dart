import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sabi_wallet/services/nostr/nostr_service.dart';
import 'package:sabi_wallet/services/nostr/dm_service.dart';

/// P2P v2 Nostr Service - Clean wrapper around NIP-99 marketplace
///
/// Responsibilities:
/// - Fetch and cache offers from Nostr relays
/// - Publish/update/delete offers
/// - Send and receive trade messages via NIP-04 DMs
/// - Track relay connection status
class P2PNostrService {
  static final P2PNostrService _instance = P2PNostrService._internal();
  factory P2PNostrService() => _instance;
  P2PNostrService._internal();

  final NIP99MarketplaceService _marketplace = NIP99MarketplaceService();
  final NostrProfileService _profileService = NostrProfileService();
  final DMService _dmService = DMService();

  // Event streams for reactive updates
  final _offersController = StreamController<List<NostrP2POffer>>.broadcast();
  final _messagesController = StreamController<TradeMessageEvent>.broadcast();
  final _connectionController = StreamController<ConnectionStatus>.broadcast();

  // Caches
  final Map<String, NostrP2POffer> _offersCache = {};
  final Map<String, List<TradeMessageEvent>> _messagesCache = {};

  // State
  bool _isInitialized = false;
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  StreamSubscription? _offerSubscription;
  StreamSubscription? _dmSubscription;

  // ==================== Getters ====================

  /// Stream of all offers (updates when offers change)
  Stream<List<NostrP2POffer>> get offersStream => _offersController.stream;

  /// Stream of incoming trade messages
  Stream<TradeMessageEvent> get messagesStream => _messagesController.stream;

  /// Stream of connection status changes
  Stream<ConnectionStatus> get connectionStream => _connectionController.stream;

  /// Current connection status
  ConnectionStatus get connectionStatus => _connectionStatus;

  /// Current user's public key
  String? get currentPubkey => _profileService.currentPubkey;

  /// Whether the user has a Nostr identity
  bool get hasIdentity => currentPubkey != null;

  /// All cached offers
  List<NostrP2POffer> get cachedOffers => _offersCache.values.toList();

  // ==================== Initialization ====================

  /// Initialize service and connect to relays
  Future<void> init() async {
    if (_isInitialized) return;

    debugPrint('🚀 P2PNostrService: Initializing...');
    _updateConnectionStatus(ConnectionStatus.connecting);

    try {
      // Initialize DM service for trade messages
      await _dmService.initialize();

      // Subscribe to incoming DMs for trade messages
      _subscribeToTradeDMs();

      // Fetch initial offers
      await refreshOffers();

      // Subscribe to real-time updates
      _subscribeToOfferUpdates();

      _isInitialized = true;
      _updateConnectionStatus(ConnectionStatus.connected);
      debugPrint('✅ P2PNostrService: Initialized successfully');
    } catch (e) {
      debugPrint('❌ P2PNostrService: Init failed: $e');
      _updateConnectionStatus(ConnectionStatus.error);
      rethrow;
    }
  }

  /// Cleanup resources
  void dispose() {
    _offerSubscription?.cancel();
    _dmSubscription?.cancel();
    _offersController.close();
    _messagesController.close();
    _connectionController.close();
    _isInitialized = false;
  }

  // ==================== Offers ====================

  /// Refresh all offers from relays with smart filtering
  Future<List<NostrP2POffer>> refreshOffers({
    int limit = 200,
    String? location,
    String? currency,
    P2POfferType? type,
    String? paymentMethod,
    bool useCache = false,
  }) async {
    debugPrint(
      '🔄 P2PNostrService: Refreshing offers (limit: $limit, currency: $currency)...',
    );

    try {
      final offers = await _marketplace.fetchOffers(
        limit: limit,
        location: location,
        currency: currency,
        type: type,
        paymentMethod: paymentMethod,
        useCache: useCache,
      );
      await _marketplace.enrichOffersWithProfiles(offers);

      // Update cache
      _offersCache.clear();
      for (final offer in offers) {
        _offersCache[offer.id] = offer;
      }

      // Emit update
      _offersController.add(_offersCache.values.toList());

      debugPrint(
        '✅ P2PNostrService: Got ${offers.length} Sabi Wallet P2P offers',
      );
      return offers;
    } catch (e) {
      debugPrint('❌ P2PNostrService: Failed to refresh offers: $e');
      _updateConnectionStatus(ConnectionStatus.error);
      rethrow;
    }
  }

  /// Load more offers (pagination)
  Future<List<NostrP2POffer>> loadMoreOffers({
    required int offset,
    int limit = 50,
    String? location,
    String? currency,
    P2POfferType? type,
    String? paymentMethod,
  }) async {
    debugPrint('🔄 P2PNostrService: Loading more offers (offset: $offset)...');

    try {
      final offers = await _marketplace.fetchOffers(
        limit: limit,
        offset: offset,
        location: location,
        currency: currency,
        type: type,
        paymentMethod: paymentMethod,
        useCache: false,
      );
      await _marketplace.enrichOffersWithProfiles(offers);

      // Add to cache (don't clear)
      for (final offer in offers) {
        _offersCache[offer.id] = offer;
      }

      // Emit updated full list
      _offersController.add(_offersCache.values.toList());

      debugPrint('✅ P2PNostrService: Loaded ${offers.length} more offers');
      return offers;
    } catch (e) {
      debugPrint('❌ P2PNostrService: Failed to load more offers: $e');
      rethrow;
    }
  }

  /// Get cached offers (no network call)
  List<NostrP2POffer> getCachedOffers({
    String? location,
    String? currency,
    P2POfferType? type,
    String? paymentMethod,
  }) {
    return _marketplace.getCachedOffers(
      location: location,
      currency: currency,
      type: type,
      paymentMethod: paymentMethod,
    );
  }

  /// Clear offers cache
  void clearCache() {
    _offersCache.clear();
    _marketplace.clearOffersCache();
  }

  /// Fetch user's own offers
  Future<List<NostrP2POffer>> fetchMyOffers() async {
    final pubkey = currentPubkey;
    if (pubkey == null) return [];

    debugPrint('🔄 P2PNostrService: Fetching my offers...');

    try {
      final offers = await _marketplace.fetchUserOffers(pubkey);

      // Update cache with my offers
      for (final offer in offers) {
        _offersCache[offer.id] = offer;
      }

      debugPrint('✅ P2PNostrService: Got ${offers.length} of my offers');
      return offers;
    } catch (e) {
      debugPrint('❌ P2PNostrService: Failed to fetch my offers: $e');
      rethrow;
    }
  }

  /// Get a specific offer by ID (from cache or fetch)
  Future<NostrP2POffer?> getOffer(String offerId) async {
    // Check cache first
    if (_offersCache.containsKey(offerId)) {
      return _offersCache[offerId];
    }

    // Not in cache, refresh and try again
    await refreshOffers();
    return _offersCache[offerId];
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
    final pubkey = currentPubkey;
    if (pubkey == null) {
      throw Exception('No Nostr identity - please set up your keys first');
    }

    debugPrint('📢 P2PNostrService: Publishing offer...');

    // Generate unique ID
    final uniqueId =
        'p2p_${DateTime.now().millisecondsSinceEpoch}_${pubkey.substring(0, 8)}';

    final offer = NostrP2POffer(
      id: uniqueId,
      eventId: '',
      pubkey: pubkey,
      type: type,
      title: title,
      description: description,
      pricePerBtc: pricePerBtc,
      currency: currency,
      minAmountSats: minSats,
      maxAmountSats: maxSats,
      paymentMethods: paymentMethods,
      paymentAccountDetails: paymentDetails,
      location: location,
      createdAt: DateTime.now(),
      status: P2POfferStatus.active,
    );

    try {
      final eventId = await _marketplace.publishOffer(offer);

      if (eventId != null) {
        // Cache the new offer
        _offersCache[offer.id] = offer;
        _offersController.add(_offersCache.values.toList());
        debugPrint('✅ P2PNostrService: Offer published: $eventId');
      }

      return eventId;
    } catch (e) {
      debugPrint('❌ P2PNostrService: Failed to publish offer: $e');
      rethrow;
    }
  }

  /// Update an existing offer
  Future<bool> updateOffer(NostrP2POffer offer) async {
    debugPrint('📝 P2PNostrService: Updating offer ${offer.id}...');

    try {
      final success = await _marketplace.updateOffer(offer);

      if (success) {
        _offersCache[offer.id] = offer;
        _offersController.add(_offersCache.values.toList());
        debugPrint('✅ P2PNostrService: Offer updated');
      }

      return success;
    } catch (e) {
      debugPrint('❌ P2PNostrService: Failed to update offer: $e');
      rethrow;
    }
  }

  /// Delete/cancel an offer
  Future<bool> deleteOffer(String offerId) async {
    debugPrint('🗑️ P2PNostrService: Deleting offer $offerId...');

    try {
      final success = await _marketplace.deleteOffer(offerId);

      if (success) {
        _offersCache.remove(offerId);
        _offersController.add(_offersCache.values.toList());
        debugPrint('✅ P2PNostrService: Offer deleted');
      }

      return success;
    } catch (e) {
      debugPrint('❌ P2PNostrService: Failed to delete offer: $e');
      rethrow;
    }
  }

  // ==================== Trade Messages (NIP-04 DMs) ====================

  /// Trade message prefix for identifying P2P messages in DMs
  static const String _tradeMessagePrefix = 'SABI_P2P_TRADE:';

  /// Send a trade message to counterparty via NIP-04 encrypted DM
  Future<bool> sendTradeMessage({
    required String tradeId,
    required String recipientPubkey,
    required TradeMessageType type,
    String? offerId,
    String? content,
    String? imageUrl,
    int? amountSats,
    String? lightningInvoice,
    String? paymentMethod,
  }) async {
    final pubkey = currentPubkey;
    if (pubkey == null) return false;

    debugPrint(
      '💬 P2PNostrService: Sending trade message type=$type offerId=$offerId...',
    );

    final message = TradeMessageEvent(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      tradeId: tradeId,
      offerId: offerId,
      senderPubkey: pubkey,
      recipientPubkey: recipientPubkey,
      type: type,
      content: content,
      imageUrl: imageUrl,
      amountSats: amountSats,
      lightningInvoice: lightningInvoice,
      paymentMethod: paymentMethod,
      timestamp: DateTime.now(),
    );

    try {
      // Build structured message payload for the DM
      final payload = {
        'type': type.name,
        'trade_id': tradeId,
        'offer_id': offerId,
        'content': content,
        'image_url': imageUrl,
        'amount_sats': amountSats,
        'lightning_invoice': lightningInvoice,
        'payment_method': paymentMethod,
        'timestamp': message.timestamp.millisecondsSinceEpoch,
      };

      // Encode as JSON with prefix so we can identify P2P messages
      final dmContent = '$_tradeMessagePrefix${jsonEncode(payload)}';

      // Send via DMService (NIP-04 encrypted)
      final success = await _dmService.sendDM(
        recipientPubkey: recipientPubkey,
        message: dmContent,
        relatedOfferId: tradeId,
      );

      if (success) {
        // Cache locally
        _cacheMessage(message);
        _messagesController.add(message);
        debugPrint('✅ P2PNostrService: Trade message sent via NIP-04 DM');
      } else {
        debugPrint('❌ P2PNostrService: Failed to send DM');
      }

      return success;
    } catch (e) {
      debugPrint('❌ P2PNostrService: Failed to send message: $e');
      return false;
    }
  }

  /// Get messages for a specific trade
  List<TradeMessageEvent> getMessagesForTrade(String tradeId) {
    return _messagesCache[tradeId] ?? [];
  }

  /// Subscribe to messages for a specific trade
  Stream<TradeMessageEvent> subscribeToTradeMessages(String tradeId) {
    return messagesStream.where((msg) => msg.tradeId == tradeId);
  }

  // ==================== Private Methods ====================

  /// Subscribe to incoming DMs and filter for trade messages
  void _subscribeToTradeDMs() {
    _dmSubscription?.cancel();
    _dmSubscription = _dmService.dmStream.listen(
      (dm) {
        // Check if this is a P2P trade message
        if (dm.content.startsWith(_tradeMessagePrefix)) {
          _handleIncomingTradeMessage(dm);
        }
      },
      onError: (e) {
        debugPrint('❌ P2PNostrService: DM stream error: $e');
      },
    );
    debugPrint('✅ P2PNostrService: Subscribed to trade DMs');
  }

  /// Parse and handle incoming trade message from DM
  void _handleIncomingTradeMessage(DirectMessage dm) {
    try {
      // Extract JSON payload after prefix
      final jsonStr = dm.content.substring(_tradeMessagePrefix.length);
      final payload = jsonDecode(jsonStr) as Map<String, dynamic>;

      final message = TradeMessageEvent(
        id: dm.id,
        tradeId: payload['trade_id'] as String? ?? '',
        offerId: payload['offer_id'] as String?,
        senderPubkey: dm.senderPubkey,
        recipientPubkey: dm.recipientPubkey,
        type: TradeMessageType.values.firstWhere(
          (t) => t.name == payload['type'],
          orElse: () => TradeMessageType.chat,
        ),
        content: payload['content'] as String?,
        imageUrl: payload['image_url'] as String?,
        amountSats: payload['amount_sats'] as int?,
        lightningInvoice: payload['lightning_invoice'] as String?,
        paymentMethod: payload['payment_method'] as String?,
        timestamp: dm.timestamp,
      );

      debugPrint(
        '📨 P2PNostrService: Received trade message: ${message.type} offerId=${message.offerId}',
      );

      // Cache and emit
      _cacheMessage(message);
      _messagesController.add(message);
    } catch (e) {
      debugPrint('⚠️ P2PNostrService: Failed to parse trade message: $e');
    }
  }

  void _subscribeToOfferUpdates() {
    _offerSubscription?.cancel();
    _offerSubscription = _marketplace.subscribeToOffers().listen(
      (offer) {
        _offersCache[offer.id] = offer;
        _offersController.add(_offersCache.values.toList());
      },
      onError: (e) {
        debugPrint('❌ P2PNostrService: Offer stream error: $e');
        _updateConnectionStatus(ConnectionStatus.error);
      },
    );
  }

  void _updateConnectionStatus(ConnectionStatus status) {
    _connectionStatus = status;
    _connectionController.add(status);
  }

  void _cacheMessage(TradeMessageEvent message) {
    _messagesCache.putIfAbsent(message.tradeId, () => []);
    _messagesCache[message.tradeId]!.add(message);
  }
}

// ==================== Connection Status ====================

enum ConnectionStatus { disconnected, connecting, connected, error }

// ==================== Trade Message Types ====================

enum TradeMessageType {
  /// Buyer initiates trade
  tradeRequest,

  /// Seller accepts/rejects trade
  tradeAccepted,
  tradeRejected,

  /// Buyer submits Lightning invoice
  invoiceSubmitted,

  /// Buyer marks payment as sent
  paymentSent,

  /// Buyer uploads payment receipt
  receiptUploaded,

  /// Seller confirms payment received
  paymentConfirmed,

  /// Seller releases Bitcoin
  btcReleased,

  /// Trade completed
  tradeCompleted,

  /// Trade cancelled
  tradeCancelled,

  /// Generic chat message
  chat,

  /// Trade dispute
  dispute,
}

// ==================== Trade Message Event ====================

class TradeMessageEvent {
  final String id;
  final String tradeId;
  final String? offerId; // The offer this trade is for
  final String senderPubkey;
  final String recipientPubkey;
  final TradeMessageType type;
  final String? content;
  final String? imageUrl;
  final int? amountSats;
  final String? lightningInvoice;
  final String? paymentMethod;
  final DateTime timestamp;
  final bool isRead;

  const TradeMessageEvent({
    required this.id,
    required this.tradeId,
    this.offerId,
    required this.senderPubkey,
    required this.recipientPubkey,
    required this.type,
    this.content,
    this.imageUrl,
    this.amountSats,
    this.lightningInvoice,
    this.paymentMethod,
    required this.timestamp,
    this.isRead = false,
  });

  /// Check if this message is from me
  bool isFromMe(String? myPubkey) => senderPubkey == myPubkey;

  /// Human-readable message type
  String get typeLabel {
    switch (type) {
      case TradeMessageType.tradeRequest:
        return 'Trade Requested';
      case TradeMessageType.tradeAccepted:
        return 'Trade Accepted';
      case TradeMessageType.tradeRejected:
        return 'Trade Rejected';
      case TradeMessageType.invoiceSubmitted:
        return 'Invoice Submitted';
      case TradeMessageType.paymentSent:
        return 'Payment Sent';
      case TradeMessageType.receiptUploaded:
        return 'Receipt Uploaded';
      case TradeMessageType.paymentConfirmed:
        return 'Payment Confirmed';
      case TradeMessageType.btcReleased:
        return 'Bitcoin Released';
      case TradeMessageType.tradeCompleted:
        return 'Trade Completed';
      case TradeMessageType.tradeCancelled:
        return 'Trade Cancelled';
      case TradeMessageType.chat:
        return 'Message';
      case TradeMessageType.dispute:
        return 'Dispute';
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'trade_id': tradeId,
    'offer_id': offerId,
    'sender_pubkey': senderPubkey,
    'recipient_pubkey': recipientPubkey,
    'type': type.name,
    'content': content,
    'image_url': imageUrl,
    'amount_sats': amountSats,
    'lightning_invoice': lightningInvoice,
    'payment_method': paymentMethod,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'is_read': isRead,
  };

  factory TradeMessageEvent.fromJson(Map<String, dynamic> json) {
    return TradeMessageEvent(
      id: json['id'] as String,
      tradeId: json['trade_id'] as String,
      offerId: json['offer_id'] as String?,
      senderPubkey: json['sender_pubkey'] as String,
      recipientPubkey: json['recipient_pubkey'] as String,
      type: TradeMessageType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => TradeMessageType.chat,
      ),
      content: json['content'] as String?,
      imageUrl: json['image_url'] as String?,
      amountSats: json['amount_sats'] as int?,
      lightningInvoice: json['lightning_invoice'] as String?,
      paymentMethod: json['payment_method'] as String?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      isRead: json['is_read'] as bool? ?? false,
    );
  }
}
