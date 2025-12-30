/// P2P Notification Service - Real-time notifications via Nostr subscriptions
///
/// Tracks:
/// - New inquiries on your offers (DMs tagged with offer ID)
/// - Trade status updates (payment marked, confirmed, etc.)
/// - New trades started on your offers
library;

import 'dart:async';
import 'package:sabi_wallet/services/nostr/relay_pool_manager.dart';
import 'package:sabi_wallet/services/nostr/nostr_profile_service.dart';
import 'package:sabi_wallet/features/p2p/utils/p2p_logger.dart';

/// Types of P2P notifications
enum P2PNotificationType {
  /// New inquiry/message on your offer
  inquiry,

  /// New trade started on your offer
  tradeStarted,

  /// Buyer marked payment as sent
  paymentMarked,

  /// Payment confirmed by seller
  paymentConfirmed,

  /// Funds released
  fundsReleased,

  /// Trade cancelled
  tradeCancelled,

  /// Trade disputed
  tradeDisputed,

  /// General message in trade chat
  tradeMessage,
}

/// P2P Notification Model
class P2PNotification {
  final String id;
  final P2PNotificationType type;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool isRead;

  /// Related offer ID (for inquiries)
  final String? offerId;

  /// Related trade ID
  final String? tradeId;

  /// Sender pubkey
  final String? senderPubkey;
  final String? senderName;
  final String? senderAvatar;

  /// Action data for quick actions
  final Map<String, dynamic>? actionData;

  P2PNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
    this.offerId,
    this.tradeId,
    this.senderPubkey,
    this.senderName,
    this.senderAvatar,
    this.actionData,
  });

  P2PNotification copyWith({bool? isRead}) {
    return P2PNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
      offerId: offerId,
      tradeId: tradeId,
      senderPubkey: senderPubkey,
      senderName: senderName,
      senderAvatar: senderAvatar,
      actionData: actionData,
    );
  }

  /// Icon for notification type
  String get icon {
    switch (type) {
      case P2PNotificationType.inquiry:
        return '💬';
      case P2PNotificationType.tradeStarted:
        return '⚡';
      case P2PNotificationType.paymentMarked:
        return '💰';
      case P2PNotificationType.paymentConfirmed:
        return '✅';
      case P2PNotificationType.fundsReleased:
        return '🎉';
      case P2PNotificationType.tradeCancelled:
        return '❌';
      case P2PNotificationType.tradeDisputed:
        return '⚠️';
      case P2PNotificationType.tradeMessage:
        return '💬';
    }
  }
}

/// P2P Notification Service
class P2PNotificationService {
  static final P2PNotificationService _instance =
      P2PNotificationService._internal();
  factory P2PNotificationService() => _instance;
  P2PNotificationService._internal();

  final RelayPoolManager _relayPool = RelayPoolManager();
  final NostrProfileService _profileService = NostrProfileService();

  // Notifications list
  final List<P2PNotification> _notifications = [];

  // Stream controllers
  final _notificationController = StreamController<P2PNotification>.broadcast();
  final _unreadCountController = StreamController<int>.broadcast();

  // Subscription state
  bool _isSubscribed = false;
  String? _currentPubkey;

  // User's offer IDs for filtering
  final Set<String> _userOfferIds = {};

  /// Stream of new notifications
  Stream<P2PNotification> get notificationStream =>
      _notificationController.stream;

  /// Stream of unread count updates
  Stream<int> get unreadCountStream => _unreadCountController.stream;

  /// Get all notifications (most recent first)
  List<P2PNotification> get notifications {
    final sorted = List<P2PNotification>.from(_notifications);
    sorted.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted;
  }

  /// Get unread count
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  /// Initialize and start listening
  Future<void> initialize() async {
    if (_isSubscribed) return;

    _currentPubkey = _profileService.currentPubkey;
    if (_currentPubkey == null) {
      P2PLogger.warning('Notifications', 'No pubkey, cannot subscribe');
      return;
    }

    P2PLogger.info('Notifications', 'Initializing P2P notifications...');

    // Subscribe to DMs (for inquiries and trade messages)
    await _subscribeToP2PDMs();

    _isSubscribed = true;
    P2PLogger.info('Notifications', 'P2P notification service started');
  }

  /// Register user's offer IDs for filtering relevant notifications
  void registerUserOffers(List<String> offerIds) {
    _userOfferIds.addAll(offerIds);
    P2PLogger.debug(
      'Notifications',
      'Registered ${offerIds.length} user offers',
    );
  }

  /// Subscribe to DMs relevant to P2P (tagged with offer/trade IDs)
  Future<void> _subscribeToP2PDMs() async {
    if (_currentPubkey == null) return;

    // Filter for DMs sent to us
    final filter = <String, dynamic>{
      'kinds': [4], // NIP-04 encrypted DM
      '#p': [_currentPubkey],
    };

    _relayPool.subscribe(filter, (event) async {
      try {
        await _handleIncomingDM(event);
      } catch (e) {
        P2PLogger.warning('Notifications', 'Error processing DM: $e');
      }
    });
  }

  /// Handle incoming DM and create notification if P2P-related
  Future<void> _handleIncomingDM(dynamic event) async {
    final senderPubkey = event.pubkey as String;
    final tags =
        (event.tags as List<dynamic>)
            .map((t) => (t as List<dynamic>).map((e) => e.toString()).toList())
            .toList();

    // Check for P2P-related tags
    String? offerId;
    String? tradeId;
    String? messageType;

    for (final tag in tags) {
      if (tag.length >= 2) {
        if (tag[0] == 'offer' || tag[0] == 'e') {
          offerId = tag[1];
        }
        if (tag[0] == 'trade') {
          tradeId = tag[1];
        }
        if (tag[0] == 'type') {
          messageType = tag[1];
        }
      }
    }

    // Only process if it's P2P-related (has offer or trade tag)
    // Or if it matches one of user's offer IDs
    final isP2PRelated =
        offerId != null ||
        tradeId != null ||
        messageType != null ||
        _userOfferIds.contains(offerId);

    if (!isP2PRelated) {
      // Check content for P2P keywords
      // Note: Content is encrypted, so we can't check it here
      // This will be handled after decryption
      return;
    }

    // Determine notification type
    P2PNotificationType type;
    String title;
    String body;

    if (messageType == 'trade_started') {
      type = P2PNotificationType.tradeStarted;
      title = 'New trade started';
      body = 'Someone wants to trade with you';
    } else if (messageType == 'payment_marked') {
      type = P2PNotificationType.paymentMarked;
      title = 'Payment marked';
      body = 'Buyer has marked payment as sent';
    } else if (messageType == 'payment_confirmed') {
      type = P2PNotificationType.paymentConfirmed;
      title = 'Payment confirmed';
      body = 'Seller confirmed receiving payment';
    } else if (messageType == 'funds_released') {
      type = P2PNotificationType.fundsReleased;
      title = 'Funds released! 🎉';
      body = 'BTC has been sent successfully';
    } else if (messageType == 'trade_cancelled') {
      type = P2PNotificationType.tradeCancelled;
      title = 'Trade cancelled';
      body = 'Trade has been cancelled';
    } else if (tradeId != null) {
      type = P2PNotificationType.tradeMessage;
      title = 'New trade message';
      body = 'You have a new message';
    } else {
      type = P2PNotificationType.inquiry;
      title = 'New offer inquiry';
      body = 'Someone is interested in your offer';
    }

    // Fetch sender profile
    String? senderName;
    String? senderAvatar;
    try {
      final profile = await _profileService.fetchProfile(senderPubkey);
      if (profile != null) {
        senderName = profile.displayName ?? profile.name;
        senderAvatar = profile.picture;
      }
    } catch (e) {
      // Ignore profile fetch errors
    }

    final notification = P2PNotification(
      id: event.id as String,
      type: type,
      title: title,
      body: body,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (event.timestamp as int) * 1000,
      ),
      offerId: offerId,
      tradeId: tradeId,
      senderPubkey: senderPubkey,
      senderName: senderName,
      senderAvatar: senderAvatar,
      actionData: {
        'offerId': offerId,
        'tradeId': tradeId,
        'messageType': messageType,
      },
    );

    _addNotification(notification);
  }

  /// Add notification to list and notify listeners
  void _addNotification(P2PNotification notification) {
    // Check for duplicates
    if (_notifications.any((n) => n.id == notification.id)) return;

    _notifications.add(notification);
    _notificationController.add(notification);
    _unreadCountController.add(unreadCount);

    P2PLogger.info(
      'Notifications',
      'New notification: ${notification.type.name}',
    );
  }

  /// Add notification manually (from trade manager, etc.)
  void addNotification({
    required P2PNotificationType type,
    required String title,
    required String body,
    String? offerId,
    String? tradeId,
    String? senderPubkey,
    String? senderName,
    Map<String, dynamic>? actionData,
  }) {
    final notification = P2PNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      title: title,
      body: body,
      timestamp: DateTime.now(),
      offerId: offerId,
      tradeId: tradeId,
      senderPubkey: senderPubkey,
      senderName: senderName,
      actionData: actionData,
    );
    _addNotification(notification);
  }

  /// Mark notification as read
  void markAsRead(String notificationId) {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      _unreadCountController.add(unreadCount);
    }
  }

  /// Mark all notifications as read
  void markAllAsRead() {
    for (var i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
    _unreadCountController.add(0);
  }

  /// Clear all notifications
  void clearAll() {
    _notifications.clear();
    _unreadCountController.add(0);
  }

  /// Get notifications for a specific offer
  List<P2PNotification> getNotificationsForOffer(String offerId) {
    return _notifications.where((n) => n.offerId == offerId).toList();
  }

  /// Get notifications for a specific trade
  List<P2PNotification> getNotificationsForTrade(String tradeId) {
    return _notifications.where((n) => n.tradeId == tradeId).toList();
  }

  /// Dispose resources
  void dispose() {
    _notificationController.close();
    _unreadCountController.close();
  }
}
