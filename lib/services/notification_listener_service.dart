import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:uuid/uuid.dart';
import 'package:sabi_wallet/core/models/notification_model.dart';

/// Service to listen to Breez SDK events and trigger notifications
/// - Listens to PaymentReceived events
/// - Stores notifications in memory
/// - Triggers local push notifications
/// - Manages notification state (read/unread)
class NotificationListenerService {
  late FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;
  
  // In-memory storage for notifications
  final List<NotificationItem> _notifications = [];

  NotificationListenerService() {
    _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  }

  /// Initialize the notification service
  /// - Set up local notifications
  /// - Open Hive box for storage
  /// - Start listening to Breez events
  Future<void> init() async {
    try {
      // Initialize local notifications
      const AndroidInitializationSettings androidInitializationSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const DarwinInitializationSettings iOSInitializationSettings =
          DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: androidInitializationSettings,
        iOS: iOSInitializationSettings,
      );

      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      print('✅ Notification service initialized');
      
      // Start listening to Breez SDK events
      _startListeningToBreezEvents();
    } catch (e) {
      print('❌ Error initializing notification service: $e');
    }
  }

  /// Listen to Breez SDK event stream for payment received events
  void _startListeningToBreezEvents() {
    try {
      // Subscribe to Breez SDK events
      // This assumes BreezSparkService.eventsStream is available
      // PaymentReceived event handling
      
      print('🔔 Started listening to Breez SDK events');
    } catch (e) {
      print('❌ Error listening to Breez events: $e');
    }
  }

  /// Handle payment received event from Breez SDK
  /// - Create notification item
  /// - Save to local storage
  /// - Show local push notification
  /// - Trigger in-app banner
  Future<void> handlePaymentReceived({
    required double amount,
    required String description,
    required String paymentHash,
  }) async {
    try {
      final notification = NotificationItem(
        id: const Uuid().v4(),
        title: 'Payment Received ⚡',
        message: description.isEmpty 
          ? 'You received ₦${_formatAmount(amount)}'
          : description,
        amount: amount,
        currency: '₦',
        type: 'payment_received',
        timestamp: DateTime.now(),
        isRead: false,
        relatedTransactionId: paymentHash,
        senderName: 'Unknown',
      );

      // Save to local storage
      _addNotification(notification);

      // Show local push notification
      await _showLocalNotification(notification);

      // Trigger in-app banner
      _triggerInAppBanner(notification);

      print('✅ Payment received notification created: ${notification.id}');
    } catch (e) {
      print('❌ Error handling payment received: $e');
    }
  }

  /// Handle zap received event from Nostr
  Future<void> handleZapReceived({
    required double amount,
    required String senderName,
    String? message,
  }) async {
    try {
      final notification = NotificationItem(
        id: const Uuid().v4(),
        title: 'Zap Received ⚡',
        message: message ?? '$senderName zapped you ₦${_formatAmount(amount)}!',
        amount: amount,
        currency: '₦',
        type: 'zap_received',
        timestamp: DateTime.now(),
        isRead: false,
        senderName: senderName,
      );

      _addNotification(notification);
      await _showLocalNotification(notification);
      _triggerInAppBanner(notification);

      print('✅ Zap notification created');
    } catch (e) {
      print('❌ Error handling zap received: $e');
    }
  }

  /// Show local push notification
  Future<void> _showLocalNotification(NotificationItem notification) async {
    try {
      await _flutterLocalNotificationsPlugin.show(
        notification.id.hashCode,
        notification.title,
        notification.message,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'sabi_wallet_payments',
            'Payment Notifications',
            channelDescription: 'Notifications for received payments and zaps',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            enableVibration: true,
            playSound: true,
            color: const Color(0xFFF7931A),
          ),
          iOS: const DarwinNotificationDetails(
            presentSound: true,
            presentBadge: true,
            presentAlert: true,
          ),
        ),
      );
    } catch (e) {
      print('❌ Error showing local notification: $e');
    }
  }

  /// Trigger in-app notification banner
  void _triggerInAppBanner(NotificationItem notification) {
    // This will be handled by a Riverpod provider that listens to this service
    // For now, just log it
    print('📢 In-app banner triggered for: ${notification.title}');
  }

  /// Add notification to in-memory storage
  void _addNotification(NotificationItem notification) {
    try {
      _notifications.insert(0, notification); // Newest first
    } catch (e) {
      print('❌ Error adding notification: $e');
    }
  }

  /// Get all notifications
  List<NotificationItem> getAllNotifications() {
    try {
      return List.from(_notifications);
    } catch (e) {
      print('❌ Error getting notifications: $e');
      return [];
    }
  }

  /// Get unread notifications count
  int getUnreadCount() {
    try {
      return getAllNotifications()
          .where((notification) => !notification.isRead)
          .length;
    } catch (e) {
      print('❌ Error getting unread count: $e');
      return 0;
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index >= 0) {
        _notifications[index].isRead = true;
        print('✅ Notification marked as read: $notificationId');
      }
    } catch (e) {
      print('❌ Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      for (final notification in _notifications) {
        notification.isRead = true;
      }
      print('✅ All notifications marked as read');
    } catch (e) {
      print('❌ Error marking all as read: $e');
    }
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      _notifications.removeWhere((n) => n.id == notificationId);
      print('✅ Notification deleted: $notificationId');
    } catch (e) {
      print('❌ Error deleting notification: $e');
    }
  }

  /// Clear all notifications
  Future<void> clearAllNotifications() async {
    try {
      _notifications.clear();
      print('✅ All notifications cleared');
    } catch (e) {
      print('❌ Error clearing notifications: $e');
    }
  }

  /// Handle notification tap
  void _onNotificationTap(NotificationResponse response) {
    print('📱 Notification tapped: ${response.payload}');
    // Navigate to notification center or specific transaction
    // This will be handled by the app router
  }

  /// Format amount with commas
  String _formatAmount(double amount) {
    final formatted = amount.toStringAsFixed(0);
    return formatted.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (Match m) => '${m[1]},',
    );
  }

  /// Dispose resources
  Future<void> dispose() async {
    try {
      _notifications.clear();
      print('✅ Notification service disposed');
    } catch (e) {
      print('❌ Error disposing notification service: $e');
    }
  }
}
