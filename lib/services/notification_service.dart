import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final String type; // 'payment_received', 'payment_sent', 'system'
  final bool isRead;
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
  static const _notificationsBox = 'notifications';
  static late Box _box;

  static Future<void> init() async {
    try {
      _box = await Hive.openBox(_notificationsBox);
      debugPrint('✅ Notification service initialized');
    } catch (e) {
      debugPrint('❌ Notification service init error: $e');
    }
  }

  /// Add a new notification
  static Future<void> addNotification(NotificationModel notification) async {
    try {
      await _box.put(notification.id, notification.toMap());
      debugPrint('✅ Added notification: ${notification.title}');
    } catch (e) {
      debugPrint('❌ Add notification error: $e');
    }
  }

  /// Get all notifications (sorted by timestamp, most recent first)
  static Future<List<NotificationModel>> getAllNotifications() async {
    try {
      final List<NotificationModel> notifications = [];

      for (final key in _box.keys) {
        final data = _box.get(key);
        notifications.add(
          NotificationModel.fromMap(Map<String, dynamic>.from(data)),
        );
      }

      // Sort by timestamp (most recent first)
      notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return notifications;
    } catch (e) {
      debugPrint('❌ Get notifications error: $e');
      return [];
    }
  }

  /// Get unread notifications count
  static Future<int> getUnreadCount() async {
    try {
      final notifications = await getAllNotifications();
      return notifications.where((n) => !n.isRead).length;
    } catch (e) {
      debugPrint('❌ Get unread count error: $e');
      return 0;
    }
  }

  /// Mark notification as read
  static Future<void> markAsRead(String notificationId) async {
    try {
      final data = _box.get(notificationId) as Map?;
      if (data != null) {
        final notification = NotificationModel.fromMap(
          Map<String, dynamic>.from(data),
        );
        await _box.put(
          notificationId,
          notification.copyWith(isRead: true).toMap(),
        );
        debugPrint('✅ Marked notification as read: $notificationId');
      }
    } catch (e) {
      debugPrint('❌ Mark as read error: $e');
    }
  }

  /// Mark all notifications as read
  static Future<void> markAllAsRead() async {
    try {
      final notifications = await getAllNotifications();
      for (final notification in notifications) {
        if (!notification.isRead) {
          await markAsRead(notification.id);
        }
      }
      debugPrint('✅ Marked all notifications as read');
    } catch (e) {
      debugPrint('❌ Mark all as read error: $e');
    }
  }

  /// Delete a notification
  static Future<void> deleteNotification(String notificationId) async {
    try {
      await _box.delete(notificationId);
      debugPrint('✅ Deleted notification: $notificationId');
    } catch (e) {
      debugPrint('❌ Delete notification error: $e');
    }
  }

  /// Clear all notifications
  static Future<void> clearAll() async {
    try {
      await _box.clear();
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
