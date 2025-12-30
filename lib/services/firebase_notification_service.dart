import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Color;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';

/// Top-level function to handle background messages (MUST be top-level)
/// This runs in a separate isolate when app is terminated/background
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Need to initialize Firebase again for background isolate
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  debugPrint('🔔 [Background] FCM message received: ${message.messageId}');
  debugPrint('🔔 [Background] Data: ${message.data}');
  
  // Handle the background message
  await FirebaseNotificationService._handleBackgroundMessage(message);
}

/// Notification channel definitions for Android
class NotificationChannels {
  // Payment notifications - highest priority
  static const String paymentChannelId = 'sabi_wallet_payments';
  static const String paymentChannelName = 'Payments';
  static const String paymentChannelDesc = 'Lightning payment notifications';
  
  // P2P trade notifications - high priority
  static const String p2pChannelId = 'sabi_wallet_p2p';
  static const String p2pChannelName = 'P2P Trading';
  static const String p2pChannelDesc = 'P2P trade updates and messages';
  
  // Social notifications (zaps, DMs)
  static const String socialChannelId = 'sabi_wallet_social';
  static const String socialChannelName = 'Social';
  static const String socialChannelDesc = 'Zaps, DMs, and social activity';
  
  // VTU order notifications
  static const String vtuChannelId = 'sabi_wallet_vtu';
  static const String vtuChannelName = 'VTU Orders';
  static const String vtuChannelDesc = 'Airtime and data purchase updates';
  
  // Default channel
  static const String defaultChannelId = 'sabi_wallet_default';
  static const String defaultChannelName = 'General';
  static const String defaultChannelDesc = 'General notifications';
}

/// Notification types for categorization
enum PushNotificationType {
  paymentReceived,
  paymentSent,
  zapReceived,
  dmReceived,
  p2pTradeStarted,
  p2pPaymentMarked,
  p2pPaymentConfirmed,
  p2pFundsReleased,
  p2pTradeCancelled,
  p2pTradeDisputed,
  p2pNewMessage,
  p2pNewInquiry,
  vtuOrderComplete,
  vtuOrderFailed,
  socialRecoveryRequest,
  rateAlert,
  general,
}

/// Main Firebase Cloud Messaging service for Sabi Wallet
/// Handles:
/// - FCM token management
/// - Foreground/background/terminated message handling
/// - Local notification display
/// - Integration with existing notification system
class FirebaseNotificationService {
  static final FirebaseNotificationService _instance = FirebaseNotificationService._internal();
  factory FirebaseNotificationService() => _instance;
  FirebaseNotificationService._internal();

  // Firebase Messaging instance
  FirebaseMessaging? _messaging;
  
  // Local notifications plugin for displaying notifications
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  // Stream controller for notification events (for UI updates)
  final StreamController<RemoteMessage> _messageStreamController = 
      StreamController<RemoteMessage>.broadcast();
  
  // Stream controller for notification taps (for navigation)
  final StreamController<Map<String, dynamic>> _notificationTapController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  // Current FCM token
  String? _fcmToken;
  
  // Initialization state
  bool _isInitialized = false;

  // Getters
  String? get fcmToken => _fcmToken;
  bool get isInitialized => _isInitialized;
  Stream<RemoteMessage> get messageStream => _messageStreamController.stream;
  Stream<Map<String, dynamic>> get notificationTapStream => _notificationTapController.stream;

  /// Initialize Firebase and FCM
  Future<void> init() async {
    if (_isInitialized) {
      debugPrint('⚠️ FirebaseNotificationService already initialized');
      return;
    }

    try {
      // Initialize Firebase (if not already done)
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        debugPrint('✅ Firebase initialized');
      }

      _messaging = FirebaseMessaging.instance;

      // Set up background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Request permissions
      await _requestPermissions();

      // Initialize local notifications
      await _initLocalNotifications();

      // Create notification channels (Android)
      await _createNotificationChannels();

      // Get initial FCM token
      await _getToken();

      // Listen for token refresh
      _messaging!.onTokenRefresh.listen(_onTokenRefresh);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification taps when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check if app was opened from a notification (terminated state)
      final initialMessage = await _messaging!.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('🔔 App opened from terminated state via notification');
        _handleNotificationTap(initialMessage);
      }

      _isInitialized = true;
      debugPrint('✅ FirebaseNotificationService initialized');
      debugPrint('🔑 FCM Token: $_fcmToken');
    } catch (e, stack) {
      debugPrint('❌ Error initializing FirebaseNotificationService: $e');
      debugPrint('$stack');
    }
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    try {
      final settings = await _messaging!.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('🔔 Notification permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ User granted notification permission');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('⚠️ User granted provisional notification permission');
      } else {
        debugPrint('❌ User denied notification permission');
      }

      // For iOS, also request critical alerts if needed for payments
      if (Platform.isIOS) {
        await _messaging!.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    } catch (e) {
      debugPrint('❌ Error requesting permissions: $e');
    }
  }

  /// Initialize local notifications plugin
  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const iosSettings = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    debugPrint('✅ Local notifications initialized');
  }

  /// Create Android notification channels
  Future<void> _createNotificationChannels() async {
    if (!Platform.isAndroid) return;

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    // Payment channel - highest priority
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        NotificationChannels.paymentChannelId,
        NotificationChannels.paymentChannelName,
        description: NotificationChannels.paymentChannelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        ledColor: Color(0xFFF7931A), // Bitcoin orange
      ),
    );

    // P2P channel - high priority
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        NotificationChannels.p2pChannelId,
        NotificationChannels.p2pChannelName,
        description: NotificationChannels.p2pChannelDesc,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );

    // Social channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        NotificationChannels.socialChannelId,
        NotificationChannels.socialChannelName,
        description: NotificationChannels.socialChannelDesc,
        importance: Importance.defaultImportance,
        playSound: true,
      ),
    );

    // VTU channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        NotificationChannels.vtuChannelId,
        NotificationChannels.vtuChannelName,
        description: NotificationChannels.vtuChannelDesc,
        importance: Importance.defaultImportance,
        playSound: true,
      ),
    );

    // Default channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        NotificationChannels.defaultChannelId,
        NotificationChannels.defaultChannelName,
        description: NotificationChannels.defaultChannelDesc,
        importance: Importance.defaultImportance,
      ),
    );

    debugPrint('✅ Android notification channels created');
  }

  /// Get FCM token
  Future<String?> _getToken() async {
    try {
      _fcmToken = await _messaging!.getToken();
      
      if (_fcmToken != null) {
        // Save token locally
        await _saveTokenLocally(_fcmToken!);
        
        // TODO: Send token to your backend/Nostr profile
        debugPrint('🔑 FCM Token obtained: ${_fcmToken!.substring(0, 20)}...');
      }
      
      return _fcmToken;
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
      return null;
    }
  }

  /// Handle token refresh
  void _onTokenRefresh(String newToken) async {
    debugPrint('🔄 FCM Token refreshed');
    _fcmToken = newToken;
    
    await _saveTokenLocally(newToken);
    
    // TODO: Update token on backend/Nostr profile
  }

  /// Save FCM token locally
  Future<void> _saveTokenLocally(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);
    } catch (e) {
      debugPrint('❌ Error saving FCM token: $e');
    }
  }

  /// Get saved FCM token
  Future<String?> getSavedToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('fcm_token');
    } catch (e) {
      debugPrint('❌ Error getting saved FCM token: $e');
      return null;
    }
  }

  /// Handle foreground message (app is open)
  void _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('🔔 [Foreground] FCM message received: ${message.messageId}');
    debugPrint('🔔 [Foreground] Title: ${message.notification?.title}');
    debugPrint('🔔 [Foreground] Body: ${message.notification?.body}');
    debugPrint('🔔 [Foreground] Data: ${message.data}');

    // Emit to stream for UI updates
    _messageStreamController.add(message);

    // Show local notification (since FCM doesn't auto-show in foreground)
    await _showLocalNotification(message);
  }

  /// Handle background message (static method for isolate)
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    debugPrint('🔔 [Background Handler] Processing message: ${message.messageId}');
    
    // Background messages with notification payload are auto-displayed by FCM
    // Data-only messages need manual handling
    
    if (message.notification == null && message.data.isNotEmpty) {
      // Data-only message - show local notification
      final localNotifications = FlutterLocalNotificationsPlugin();
      
      final type = _getNotificationType(message.data['type'] as String?);
      final channelId = _getChannelForType(type);
      
      await localNotifications.show(
        message.hashCode,
        message.data['title'] ?? 'Sabi Wallet',
        message.data['body'] ?? 'You have a new notification',
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelId,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(
            presentSound: true,
            presentBadge: true,
            presentAlert: true,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }

  /// Handle notification tap (app in background)
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('🔔 [Tap] Notification tapped: ${message.messageId}');
    debugPrint('🔔 [Tap] Data: ${message.data}');

    // Emit to stream for navigation
    _notificationTapController.add(message.data);
    
    // Handle navigation based on notification type
    _navigateToScreen(message.data);
  }

  /// Handle local notification tap
  void _onLocalNotificationTap(NotificationResponse response) {
    debugPrint('🔔 [Local Tap] Notification tapped: ${response.payload}');

    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        _notificationTapController.add(data);
        _navigateToScreen(data);
      } catch (e) {
        debugPrint('❌ Error parsing notification payload: $e');
      }
    }
  }

  /// Navigate to appropriate screen based on notification data
  void _navigateToScreen(Map<String, dynamic> data) {
    final type = _getNotificationType(data['type'] as String?);
    
    debugPrint('🧭 Navigating for notification type: $type');
    
    // TODO: Implement actual navigation using your router
    switch (type) {
      case PushNotificationType.paymentReceived:
      case PushNotificationType.paymentSent:
        // Navigate to transaction details or wallet
        debugPrint('→ Navigate to wallet/transaction');
        break;
        
      case PushNotificationType.zapReceived:
        // Navigate to zaps or social feed
        debugPrint('→ Navigate to social/zaps');
        break;
        
      case PushNotificationType.dmReceived:
        // Navigate to DMs
        debugPrint('→ Navigate to DMs');
        break;
        
      case PushNotificationType.p2pTradeStarted:
      case PushNotificationType.p2pPaymentMarked:
      case PushNotificationType.p2pPaymentConfirmed:
      case PushNotificationType.p2pFundsReleased:
      case PushNotificationType.p2pTradeCancelled:
      case PushNotificationType.p2pTradeDisputed:
      case PushNotificationType.p2pNewMessage:
      case PushNotificationType.p2pNewInquiry:
        // Navigate to P2P trade
        final tradeId = data['tradeId'] as String?;
        debugPrint('→ Navigate to P2P trade: $tradeId');
        break;
        
      case PushNotificationType.vtuOrderComplete:
      case PushNotificationType.vtuOrderFailed:
        // Navigate to VTU order
        debugPrint('→ Navigate to VTU orders');
        break;
        
      case PushNotificationType.socialRecoveryRequest:
        // Navigate to social recovery
        debugPrint('→ Navigate to social recovery');
        break;
        
      default:
        // Navigate to notification center
        debugPrint('→ Navigate to notifications');
    }
  }

  /// Show local notification for FCM message
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    // Determine notification type and channel
    final type = _getNotificationType(data['type'] as String?);
    final channelId = _getChannelForType(type);
    final channelName = _getChannelNameForType(type);

    // Get title and body
    final title = notification?.title ?? data['title'] ?? 'Sabi Wallet';
    final body = notification?.body ?? data['body'] ?? 'You have a new notification';

    // Show notification
    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: _getImportanceForType(type),
          priority: _getPriorityForType(type),
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFFF7931A),
          enableVibration: true,
          playSound: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentSound: true,
          presentBadge: true,
          presentAlert: true,
        ),
      ),
      payload: jsonEncode(data),
    );
  }

  /// Get notification type from string
  static PushNotificationType _getNotificationType(String? typeString) {
    switch (typeString) {
      case 'payment_received':
        return PushNotificationType.paymentReceived;
      case 'payment_sent':
        return PushNotificationType.paymentSent;
      case 'zap_received':
        return PushNotificationType.zapReceived;
      case 'dm_received':
        return PushNotificationType.dmReceived;
      case 'p2p_trade_started':
        return PushNotificationType.p2pTradeStarted;
      case 'p2p_payment_marked':
        return PushNotificationType.p2pPaymentMarked;
      case 'p2p_payment_confirmed':
        return PushNotificationType.p2pPaymentConfirmed;
      case 'p2p_funds_released':
        return PushNotificationType.p2pFundsReleased;
      case 'p2p_trade_cancelled':
        return PushNotificationType.p2pTradeCancelled;
      case 'p2p_trade_disputed':
        return PushNotificationType.p2pTradeDisputed;
      case 'p2p_new_message':
        return PushNotificationType.p2pNewMessage;
      case 'p2p_new_inquiry':
        return PushNotificationType.p2pNewInquiry;
      case 'vtu_order_complete':
        return PushNotificationType.vtuOrderComplete;
      case 'vtu_order_failed':
        return PushNotificationType.vtuOrderFailed;
      case 'social_recovery_request':
        return PushNotificationType.socialRecoveryRequest;
      case 'rate_alert':
        return PushNotificationType.rateAlert;
      default:
        return PushNotificationType.general;
    }
  }

  /// Get channel ID for notification type
  static String _getChannelForType(PushNotificationType type) {
    switch (type) {
      case PushNotificationType.paymentReceived:
      case PushNotificationType.paymentSent:
        return NotificationChannels.paymentChannelId;
        
      case PushNotificationType.p2pTradeStarted:
      case PushNotificationType.p2pPaymentMarked:
      case PushNotificationType.p2pPaymentConfirmed:
      case PushNotificationType.p2pFundsReleased:
      case PushNotificationType.p2pTradeCancelled:
      case PushNotificationType.p2pTradeDisputed:
      case PushNotificationType.p2pNewMessage:
      case PushNotificationType.p2pNewInquiry:
        return NotificationChannels.p2pChannelId;
        
      case PushNotificationType.zapReceived:
      case PushNotificationType.dmReceived:
        return NotificationChannels.socialChannelId;
        
      case PushNotificationType.vtuOrderComplete:
      case PushNotificationType.vtuOrderFailed:
        return NotificationChannels.vtuChannelId;
        
      default:
        return NotificationChannels.defaultChannelId;
    }
  }

  /// Get channel name for notification type
  static String _getChannelNameForType(PushNotificationType type) {
    switch (type) {
      case PushNotificationType.paymentReceived:
      case PushNotificationType.paymentSent:
        return NotificationChannels.paymentChannelName;
        
      case PushNotificationType.p2pTradeStarted:
      case PushNotificationType.p2pPaymentMarked:
      case PushNotificationType.p2pPaymentConfirmed:
      case PushNotificationType.p2pFundsReleased:
      case PushNotificationType.p2pTradeCancelled:
      case PushNotificationType.p2pTradeDisputed:
      case PushNotificationType.p2pNewMessage:
      case PushNotificationType.p2pNewInquiry:
        return NotificationChannels.p2pChannelName;
        
      case PushNotificationType.zapReceived:
      case PushNotificationType.dmReceived:
        return NotificationChannels.socialChannelName;
        
      case PushNotificationType.vtuOrderComplete:
      case PushNotificationType.vtuOrderFailed:
        return NotificationChannels.vtuChannelName;
        
      default:
        return NotificationChannels.defaultChannelName;
    }
  }

  /// Get importance for notification type
  Importance _getImportanceForType(PushNotificationType type) {
    switch (type) {
      case PushNotificationType.paymentReceived:
        return Importance.max;
        
      case PushNotificationType.p2pTradeStarted:
      case PushNotificationType.p2pPaymentMarked:
      case PushNotificationType.p2pPaymentConfirmed:
      case PushNotificationType.p2pFundsReleased:
      case PushNotificationType.p2pTradeDisputed:
        return Importance.high;
        
      default:
        return Importance.defaultImportance;
    }
  }

  /// Get priority for notification type
  Priority _getPriorityForType(PushNotificationType type) {
    switch (type) {
      case PushNotificationType.paymentReceived:
        return Priority.max;
        
      case PushNotificationType.p2pTradeStarted:
      case PushNotificationType.p2pPaymentMarked:
      case PushNotificationType.p2pPaymentConfirmed:
      case PushNotificationType.p2pFundsReleased:
      case PushNotificationType.p2pTradeDisputed:
        return Priority.high;
        
      default:
        return Priority.defaultPriority;
    }
  }

  /// Subscribe to a topic for group notifications
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging?.subscribeToTopic(topic);
      debugPrint('✅ Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('❌ Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging?.unsubscribeFromTopic(topic);
      debugPrint('✅ Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('❌ Error unsubscribing from topic: $e');
    }
  }

  /// Delete FCM token (for logout)
  Future<void> deleteToken() async {
    try {
      await _messaging?.deleteToken();
      _fcmToken = null;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('fcm_token');
      
      debugPrint('✅ FCM token deleted');
    } catch (e) {
      debugPrint('❌ Error deleting FCM token: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _messageStreamController.close();
    _notificationTapController.close();
  }
}
