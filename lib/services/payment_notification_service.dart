import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sabi_wallet/services/notification_service.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';

/// Service for managing local push notifications (OS-level)
class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  /// Initialize local notifications
  static Future<void> initialize() async {
    try {
      if (_isInitialized) return;

      // Android initialization
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization
      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(initSettings);
      _isInitialized = true;

      debugPrint('✅ Local notifications initialized');
    } catch (e) {
      debugPrint('❌ Local notifications init error: $e');
    }
  }

  /// Show payment received notification
  static Future<void> showPaymentNotification({
    required String title,
    required String body,
    required String notificationId,
    required Map<String, String>? payload,
  }) async {
    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'payment_channel',
        'Payment Notifications',
        channelDescription: 'Notifications for incoming payments and zaps',
        importance: Importance.max,
        priority: Priority.high,
        enableVibration: true,
        sound: RawResourceAndroidNotificationSound('notification'),
        playSound: true,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'notification.caf',
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.show(
        notificationId.hashCode,
        title,
        body,
        details,
        payload: payload,
      );

      debugPrint('✅ Push notification shown: $title');
    } catch (e) {
      debugPrint('❌ Show notification error: $e');
    }
  }

  /// Request notification permissions
  static Future<bool> requestPermissions() async {
    try {
      if (!defaultTargetPlatform.toString().contains('android')) {
        return true; // iOS permissions handled during init
      }

      final result = await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      return result ?? false;
    } catch (e) {
      debugPrint('❌ Request permissions error: $e');
      return false;
    }
  }
}

/// Service for syncing Breez SDK payment events to local notifications
class PaymentNotificationSync {
  static StreamSubscription? _paymentStreamSubscription;
  static StreamSubscription? _balanceStreamSubscription;

  /// Start listening to Breez SDK payment stream
  static Future<void> startListeningToPayments() async {
    try {
      // Unsubscribe from any previous subscription
      await stopListeningToPayments();

      debugPrint('🔔 Starting to listen to Breez SDK payment stream...');

      // Subscribe to payment stream
      _paymentStreamSubscription =
          BreezSparkService.paymentStream.listen((payment) async {
        await _handlePaymentReceived(payment);
      }, onError: (error) {
        debugPrint('❌ Payment stream error: $error');
      });

      // Subscribe to balance stream for real-time updates
      _balanceStreamSubscription =
          BreezSparkService.balanceStream.listen((balance) async {
        debugPrint('💰 Balance updated: $balance sats');
      }, onError: (error) {
        debugPrint('❌ Balance stream error: $error');
      });

      debugPrint('✅ Listening to Breez SDK streams');
    } catch (e) {
      debugPrint('❌ Error starting payment listener: $e');
    }
  }

  /// Handle incoming payment
  static Future<void> _handlePaymentReceived(
    BreezSparkService.PaymentRecord payment,
  ) async {
    try {
      debugPrint('🎉 Payment received: ${payment.amountSats} sats');

      // 1. Add to notification center
      await NotificationService.addPaymentNotification(
        isInbound: payment.isIncoming,
        amountSats: payment.amountSats,
        description: payment.description.isNotEmpty ? payment.description : null,
      );

      // 2. Show local push notification (OS-level)
      if (payment.isIncoming) {
        await LocalNotificationService.showPaymentNotification(
          title: '₦ Payment Received!',
          body: 'You received ${payment.amountSats} sats',
          notificationId: payment.id,
          payload: {
            'payment_id': payment.id,
            'amount': payment.amountSats.toString(),
            'type': 'payment_received',
          },
        );
      }

      debugPrint('✅ Payment notification processed');
    } catch (e) {
      debugPrint('❌ Error handling payment notification: $e');
    }
  }

  /// Stop listening to payment stream
  static Future<void> stopListeningToPayments() async {
    try {
      await _paymentStreamSubscription?.cancel();
      await _balanceStreamSubscription?.cancel();
      _paymentStreamSubscription = null;
      _balanceStreamSubscription = null;
      debugPrint('✅ Stopped listening to payment streams');
    } catch (e) {
      debugPrint('❌ Error stopping payment listener: $e');
    }
  }
}
