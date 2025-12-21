import 'package:flutter/foundation.dart';

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final String type; // 'payment_received', 'payment_sent', 'system'
  bool isRead;
  final Map<String, dynamic>? metadata;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
    this.isRead = false,
    this.metadata,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'message': message,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'type': type,
    'isRead': isRead,
    'metadata': metadata,
  };

  factory NotificationModel.fromMap(Map<String, dynamic> map) =>
      NotificationModel(
        id: map['id'] as String,
        title: map['title'] as String,
        message: map['message'] as String,
        timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
        type: map['type'] as String,
        isRead: map['isRead'] as bool? ?? false,
        metadata: map['metadata'] as Map<String, dynamic>?,
      );

  NotificationModel copyWith({
    String? id,
    String? title,
    String? message,
    DateTime? timestamp,
    String? type,
    bool? isRead,
    Map<String, dynamic>? metadata,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      metadata: metadata ?? this.metadata,
    );
  }
}

class NotificationService {
  // In-memory storage for notifications (no Hive needed)
  static final List<NotificationModel> _notifications = [];

  static Future<void> init() async {
    try {
      debugPrint('✅ Notification service initialized (in-memory)');
    } catch (e) {
      debugPrint('❌ Notification service init error: $e');
    }
  }

  /// Add a new notification
  static Future<void> addNotification(NotificationModel notification) async {
    try {
      _notifications.insert(0, notification); // Add to beginning (newest first)
      debugPrint('✅ Added notification: ${notification.title}');
    } catch (e) {
      debugPrint('❌ Add notification error: $e');
    }
  }

  /// Get all notifications (sorted by timestamp, most recent first)
  static Future<List<NotificationModel>> getAllNotifications() async {
    try {
      return List.from(_notifications);
    } catch (e) {
      debugPrint('❌ Get notifications error: $e');
      return [];
    }
  }

  /// Get unread notifications count
  static Future<int> getUnreadCount() async {
    try {
      return _notifications.where((n) => !n.isRead).length;
    } catch (e) {
      debugPrint('❌ Get unread count error: $e');
      return 0;
    }
  }

  /// Mark notification as read
  static Future<void> markAsRead(String notificationId) async {
    try {
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index >= 0) {
        _notifications[index].isRead = true;
        debugPrint('✅ Marked notification as read: $notificationId');
      }
    } catch (e) {
      debugPrint('❌ Mark as read error: $e');
    }
  }

  /// Mark all notifications as read
  static Future<void> markAllAsRead() async {
    try {
      for (final notification in _notifications) {
        notification.isRead = true;
      }
      debugPrint('✅ Marked all notifications as read');
    } catch (e) {
      debugPrint('❌ Mark all as read error: $e');
    }
  }

  /// Delete a notification
  static Future<void> deleteNotification(String notificationId) async {
    try {
      _notifications.removeWhere((n) => n.id == notificationId);
      debugPrint('✅ Deleted notification: $notificationId');
    } catch (e) {
      debugPrint('❌ Delete notification error: $e');
    }
  }

  /// Clear all notifications
  static Future<void> clearAll() async {
    try {
      _notifications.clear();
      debugPrint('✅ Cleared all notifications');
    } catch (e) {
      debugPrint('❌ Clear notifications error: $e');
    }
  }

  /// Create a payment notification
  static Future<void> addPaymentNotification({
    required bool isInbound,
    required int amountSats,
    String? description,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final notification = NotificationModel(
      id: id,
      title: isInbound ? 'Payment Received' : 'Payment Sent',
      message:
          '${isInbound ? 'Received' : 'Sent'} $amountSats sats${description != null && description.isNotEmpty ? ' - $description' : ''}',
      timestamp: DateTime.now(),
      type: isInbound ? 'payment_received' : 'payment_sent',
      metadata: {'amountSats': amountSats, 'description': description},
    );

    await addNotification(notification);
  }
}
