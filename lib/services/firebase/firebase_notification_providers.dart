import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_notification_service.dart';
import 'webhook_bridge_services.dart';

/// Provider for the Firebase Notification Service instance
final firebaseNotificationServiceProvider = Provider<FirebaseNotificationService>((ref) {
  return FirebaseNotificationService();
});

/// Provider for the FCM token
final fcmTokenProvider = FutureProvider<String?>((ref) async {
  final service = ref.watch(firebaseNotificationServiceProvider);
  return service.fcmToken ?? await service.getSavedToken();
});

/// Provider for listening to foreground messages
final fcmMessageStreamProvider = StreamProvider<RemoteMessage>((ref) {
  final service = ref.watch(firebaseNotificationServiceProvider);
  return service.messageStream;
});

/// Provider for notification tap events (for navigation)
final fcmNotificationTapProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final service = ref.watch(firebaseNotificationServiceProvider);
  return service.notificationTapStream;
});

/// Notification preferences state
class NotificationPreferences {
  final bool paymentsEnabled;
  final bool p2pEnabled;
  final bool socialEnabled;
  final bool vtuEnabled;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool badgeEnabled;

  const NotificationPreferences({
    this.paymentsEnabled = true,
    this.p2pEnabled = true,
    this.socialEnabled = true,
    this.vtuEnabled = true,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.badgeEnabled = true,
  });

  NotificationPreferences copyWith({
    bool? paymentsEnabled,
    bool? p2pEnabled,
    bool? socialEnabled,
    bool? vtuEnabled,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? badgeEnabled,
  }) {
    return NotificationPreferences(
      paymentsEnabled: paymentsEnabled ?? this.paymentsEnabled,
      p2pEnabled: p2pEnabled ?? this.p2pEnabled,
      socialEnabled: socialEnabled ?? this.socialEnabled,
      vtuEnabled: vtuEnabled ?? this.vtuEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      badgeEnabled: badgeEnabled ?? this.badgeEnabled,
    );
  }

  Map<String, dynamic> toMap() => {
    'paymentsEnabled': paymentsEnabled,
    'p2pEnabled': p2pEnabled,
    'socialEnabled': socialEnabled,
    'vtuEnabled': vtuEnabled,
    'soundEnabled': soundEnabled,
    'vibrationEnabled': vibrationEnabled,
    'badgeEnabled': badgeEnabled,
  };

  factory NotificationPreferences.fromMap(Map<String, dynamic> map) {
    return NotificationPreferences(
      paymentsEnabled: map['paymentsEnabled'] as bool? ?? true,
      p2pEnabled: map['p2pEnabled'] as bool? ?? true,
      socialEnabled: map['socialEnabled'] as bool? ?? true,
      vtuEnabled: map['vtuEnabled'] as bool? ?? true,
      soundEnabled: map['soundEnabled'] as bool? ?? true,
      vibrationEnabled: map['vibrationEnabled'] as bool? ?? true,
      badgeEnabled: map['badgeEnabled'] as bool? ?? true,
    );
  }
}

/// Notifier for managing notification preferences
class NotificationPreferencesNotifier extends StateNotifier<NotificationPreferences> {
  NotificationPreferencesNotifier() : super(const NotificationPreferences()) {
    _loadPreferences();
  }

  static const String _prefsKey = 'notification_preferences';

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_prefsKey);
      
      if (json != null) {
        // Parse JSON and load preferences
        // For simplicity, using individual keys
        state = NotificationPreferences(
          paymentsEnabled: prefs.getBool('notif_payments') ?? true,
          p2pEnabled: prefs.getBool('notif_p2p') ?? true,
          socialEnabled: prefs.getBool('notif_social') ?? true,
          vtuEnabled: prefs.getBool('notif_vtu') ?? true,
          soundEnabled: prefs.getBool('notif_sound') ?? true,
          vibrationEnabled: prefs.getBool('notif_vibration') ?? true,
          badgeEnabled: prefs.getBool('notif_badge') ?? true,
        );
      }
      debugPrint('✅ Notification preferences loaded');
    } catch (e) {
      debugPrint('❌ Error loading notification preferences: $e');
    }
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notif_payments', state.paymentsEnabled);
      await prefs.setBool('notif_p2p', state.p2pEnabled);
      await prefs.setBool('notif_social', state.socialEnabled);
      await prefs.setBool('notif_vtu', state.vtuEnabled);
      await prefs.setBool('notif_sound', state.soundEnabled);
      await prefs.setBool('notif_vibration', state.vibrationEnabled);
      await prefs.setBool('notif_badge', state.badgeEnabled);
      debugPrint('✅ Notification preferences saved');
    } catch (e) {
      debugPrint('❌ Error saving notification preferences: $e');
    }
  }

  void setPaymentsEnabled(bool enabled) {
    state = state.copyWith(paymentsEnabled: enabled);
    _savePreferences();
  }

  void setP2PEnabled(bool enabled) {
    state = state.copyWith(p2pEnabled: enabled);
    _savePreferences();
  }

  void setSocialEnabled(bool enabled) {
    state = state.copyWith(socialEnabled: enabled);
    _savePreferences();
  }

  void setVTUEnabled(bool enabled) {
    state = state.copyWith(vtuEnabled: enabled);
    _savePreferences();
  }

  void setSoundEnabled(bool enabled) {
    state = state.copyWith(soundEnabled: enabled);
    _savePreferences();
  }

  void setVibrationEnabled(bool enabled) {
    state = state.copyWith(vibrationEnabled: enabled);
    _savePreferences();
  }

  void setBadgeEnabled(bool enabled) {
    state = state.copyWith(badgeEnabled: enabled);
    _savePreferences();
  }

  void resetToDefaults() {
    state = const NotificationPreferences();
    _savePreferences();
  }
}

/// Provider for notification preferences
final notificationPreferencesProvider = 
    StateNotifierProvider<NotificationPreferencesNotifier, NotificationPreferences>((ref) {
  return NotificationPreferencesNotifier();
});

/// Push notification history item
class PushNotificationItem {
  final String id;
  final String title;
  final String body;
  final String type;
  final Map<String, dynamic> data;
  final DateTime receivedAt;
  final bool isRead;

  const PushNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.data,
    required this.receivedAt,
    this.isRead = false,
  });

  PushNotificationItem copyWith({
    String? id,
    String? title,
    String? body,
    String? type,
    Map<String, dynamic>? data,
    DateTime? receivedAt,
    bool? isRead,
  }) {
    return PushNotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      data: data ?? this.data,
      receivedAt: receivedAt ?? this.receivedAt,
      isRead: isRead ?? this.isRead,
    );
  }
}

/// Notifier for push notification history
class PushNotificationHistoryNotifier extends StateNotifier<List<PushNotificationItem>> {
  final FirebaseNotificationService _service;
  StreamSubscription<RemoteMessage>? _subscription;

  PushNotificationHistoryNotifier(this._service) : super([]) {
    _listenToMessages();
  }

  void _listenToMessages() {
    _subscription = _service.messageStream.listen((message) {
      final item = PushNotificationItem(
        id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: message.notification?.title ?? message.data['title'] ?? 'Notification',
        body: message.notification?.body ?? message.data['body'] ?? '',
        type: message.data['type'] ?? 'general',
        data: message.data,
        receivedAt: DateTime.now(),
      );

      // Add to beginning of list (newest first)
      state = [item, ...state];
      
      // Keep only last 100 notifications
      if (state.length > 100) {
        state = state.sublist(0, 100);
      }
    });
  }

  void markAsRead(String id) {
    state = state.map((item) {
      if (item.id == id) {
        return item.copyWith(isRead: true);
      }
      return item;
    }).toList();
  }

  void markAllAsRead() {
    state = state.map((item) => item.copyWith(isRead: true)).toList();
  }

  void removeNotification(String id) {
    state = state.where((item) => item.id != id).toList();
  }

  void clearAll() {
    state = [];
  }

  int get unreadCount => state.where((item) => !item.isRead).length;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Provider for push notification history
final pushNotificationHistoryProvider = 
    StateNotifierProvider<PushNotificationHistoryNotifier, List<PushNotificationItem>>((ref) {
  final service = ref.watch(firebaseNotificationServiceProvider);
  return PushNotificationHistoryNotifier(service);
});

/// Provider for unread push notification count
final unreadPushNotificationCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(pushNotificationHistoryProvider);
  return notifications.where((n) => !n.isRead).length;
});

/// Provider to check if push notifications are enabled
final pushNotificationsEnabledProvider = FutureProvider<bool>((ref) async {
  final messaging = FirebaseMessaging.instance;
  final settings = await messaging.getNotificationSettings();
  return settings.authorizationStatus == AuthorizationStatus.authorized ||
         settings.authorizationStatus == AuthorizationStatus.provisional;
});
// ============================================================================
// Webhook Bridge Providers
// ============================================================================

/// Provider for the Breez Webhook Bridge Service
/// This bridges payment events to Firebase Cloud Functions
final breezWebhookBridgeProvider = Provider<BreezWebhookBridgeService>((ref) {
  final service = BreezWebhookBridgeService();
  
  // Dispose when provider is disposed
  ref.onDispose(() {
    service.dispose();
  });
  
  return service;
});

/// Provider for P2P Webhook Service
final p2pWebhookServiceProvider = Provider<P2PWebhookService>((ref) {
  return P2PWebhookService();
});

/// Provider for Zap Webhook Service
final zapWebhookServiceProvider = Provider<ZapWebhookService>((ref) {
  return ZapWebhookService();
});

/// Provider for DM Webhook Service
final dmWebhookServiceProvider = Provider<DMWebhookService>((ref) {
  return DMWebhookService();
});

/// Provider for VTU Webhook Service
final vtuWebhookServiceProvider = Provider<VTUWebhookService>((ref) {
  return VTUWebhookService();
});

/// Provider to check Cloud Functions health
final cloudFunctionsHealthProvider = FutureProvider<bool>((ref) async {
  final bridge = ref.read(breezWebhookBridgeProvider);
  return bridge.checkCloudFunctionsHealth();
});