import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/core/models/notification_model.dart';
import 'package:sabi_wallet/services/notification_listener_service.dart';

// Singleton instance of notification service
final notificationListenerServiceProvider = Provider<NotificationListenerService>((ref) {
  return NotificationListenerService();
});

// List of all notifications (sorted by timestamp, newest first)
final notificationsProvider = StateNotifierProvider<
    NotificationsNotifier,
    List<NotificationItem>>((ref) {
  return NotificationsNotifier();
});

class NotificationsNotifier extends StateNotifier<List<NotificationItem>> {
  NotificationsNotifier() : super([]);

  void addNotification(NotificationItem notification) {
    state = [notification, ...state];
  }

  void markAsRead(String notificationId) {
    state = [
      for (final notification in state)
        if (notification.id == notificationId)
          notification.copyWith(isRead: true)
        else
          notification,
    ];
  }

  void markAllAsRead() {
    state = [
      for (final notification in state)
        notification.copyWith(isRead: true),
    ];
  }

  void deleteNotification(String notificationId) {
    state = [
      for (final notification in state)
        if (notification.id != notificationId) notification,
    ];
  }

  void clearAll() {
    state = [];
  }
}

// Unread notifications count
final unreadCountProvider = StateProvider<int>((ref) {
  final notifications = ref.watch(notificationsProvider);
  return notifications.where((n) => !n.isRead).length;
});

// In-app banner notification stream
final inAppBannerProvider = StateProvider<NotificationItem?>((ref) => null);

// Show in-app banner
final showInAppBannerProvider =
    StateNotifierProvider<ShowInAppBannerNotifier, NotificationItem?>((ref) {
  return ShowInAppBannerNotifier();
});

class ShowInAppBannerNotifier extends StateNotifier<NotificationItem?> {
  ShowInAppBannerNotifier() : super(null);

  void show(NotificationItem notification) {
    state = notification;
    
    // Auto-dismiss after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (state?.id == notification.id) {
        state = null;
      }
    });
  }

  void dismiss() {
    state = null;
  }
}
