// lib/services/background_payment_sync_service.dart
// Background service to detect payments when app is killed/closed

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

/// Push notification API base URL
const String _pushApiBaseUrl = String.fromEnvironment(
  'PUSH_API_URL',
  defaultValue: 'https://vercel-api-one-sigma.vercel.app/api',
);

/// Task identifiers for WorkManager
const String backgroundPaymentSyncTask = 'backgroundPaymentSyncTask';
const String backgroundPaymentSyncPeriodicTask = 'backgroundPaymentSyncPeriodicTask';

/// Keys for SharedPreferences
const String _lastPaymentIdKey = 'background_last_payment_id';
const String _nostrPubkeyKey = 'background_nostr_pubkey';
const String _fcmTokenKey = 'fcm_token';
const String _lastSyncTimeKey = 'background_last_sync_time';

/// Called by WorkManager when background task is executed
/// This MUST be a top-level function (not inside a class)
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint('🔄 [Background] WorkManager task started: $task');
    
    try {
      switch (task) {
        case backgroundPaymentSyncTask:
        case backgroundPaymentSyncPeriodicTask:
          await _performBackgroundSync();
          break;
        case Workmanager.iOSBackgroundTask:
          await _performBackgroundSync();
          break;
      }
      
      debugPrint('✅ [Background] Task completed successfully');
      return Future.value(true);
    } catch (e) {
      debugPrint('❌ [Background] Task failed: $e');
      return Future.value(false);
    }
  });
}

/// Perform the actual background sync
/// 
/// NOTE: Breez SDK Spark is "nodeless" - the wallet state is only accessible
/// when the SDK is fully initialized with the user's mnemonic. In background
/// mode, we cannot access the Breez SDK directly.
/// 
/// This function does the following:
/// 1. Calls the server to trigger an FCM notification check
/// 2. The server then sends FCM data message to wake the app
/// 3. When app wakes, it can do a proper sync
Future<void> _performBackgroundSync() async {
  debugPrint('🔍 [Background] Starting payment sync...');
  
  try {
    final prefs = await SharedPreferences.getInstance();
    final nostrPubkey = prefs.getString(_nostrPubkeyKey);
    final fcmToken = prefs.getString(_fcmTokenKey);
    final lastSyncTime = prefs.getInt(_lastSyncTimeKey) ?? 0;
    
    if (nostrPubkey == null || fcmToken == null) {
      debugPrint('⚠️ [Background] Missing nostr pubkey or FCM token, skipping sync');
      return;
    }
    
    // Update last sync time
    await prefs.setInt(_lastSyncTimeKey, DateTime.now().millisecondsSinceEpoch);
    
    // Call server to send a wake-up FCM message
    // This triggers the app to do a proper foreground sync
    final response = await http.post(
      Uri.parse('$_pushApiBaseUrl/webhook/wake-device'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nostrPubkey': nostrPubkey,
        'fcmToken': fcmToken,
        'lastSyncTime': lastSyncTime,
        'reason': 'background_sync',
      }),
    ).timeout(const Duration(seconds: 30));
    
    if (response.statusCode == 200) {
      debugPrint('✅ [Background] Wake-up request sent successfully');
      
      // Also show a reminder notification if it's been a while since last app use
      final lastAppUse = prefs.getInt('last_app_use_time') ?? 0;
      final hoursSinceUse = (DateTime.now().millisecondsSinceEpoch - lastAppUse) / (1000 * 60 * 60);
      
      if (hoursSinceUse > 24) {
        // It's been more than 24 hours, show a gentle reminder
        await _showLocalNotification(
          title: 'Sabi Wallet',
          body: 'Open the app to check for new payments',
          payload: '{"action": "sync"}',
        );
        debugPrint('📭 [Background] User inactive for ${hoursSinceUse.toStringAsFixed(1)} hours - showing reminder');
      }
    } else {
      debugPrint('⚠️ [Background] Server response: ${response.statusCode} - ${response.body}');
    }
  } catch (e) {
    debugPrint('❌ [Background] Sync error: $e');
  }
}

/// Show a local notification
Future<void> _showLocalNotification({
  required String title,
  required String body,
  String? payload,
}) async {
  final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();
  
  // Initialize if needed
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings();
  const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
  await notifications.initialize(settings);
  
  // Create notification
  const androidDetails = AndroidNotificationDetails(
    'sabi_wallet_payments',
    'Payments',
    channelDescription: 'Lightning payment notifications',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    icon: '@mipmap/ic_launcher',
  );
  
  const iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );
  
  const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
  
  await notifications.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    body,
    details,
    payload: payload,
  );
  
  debugPrint('🔔 [Background] Local notification shown');
}

/// Service class for managing background sync
class BackgroundPaymentSyncService {
  static final BackgroundPaymentSyncService _instance = BackgroundPaymentSyncService._internal();
  factory BackgroundPaymentSyncService() => _instance;
  BackgroundPaymentSyncService._internal();
  
  bool _isInitialized = false;
  
  /// Initialize WorkManager
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('ℹ️ BackgroundPaymentSyncService already initialized');
      return;
    }
    
    try {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: kDebugMode,
      );
      
      _isInitialized = true;
      debugPrint('✅ BackgroundPaymentSyncService initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize WorkManager: $e');
    }
  }
  
  /// Start periodic background sync
  /// This will run approximately every 15 minutes (minimum allowed by Android)
  Future<void> startPeriodicSync() async {
    if (!_isInitialized) {
      await initialize();
    }
    
    try {
      // Cancel any existing periodic task
      await Workmanager().cancelByUniqueName(backgroundPaymentSyncPeriodicTask);
      
      // Register periodic task
      await Workmanager().registerPeriodicTask(
        backgroundPaymentSyncPeriodicTask,
        backgroundPaymentSyncPeriodicTask,
        frequency: const Duration(minutes: 15), // Minimum on Android
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(minutes: 1),
      );
      
      debugPrint('✅ Periodic background sync registered (every 15 min)');
    } catch (e) {
      debugPrint('❌ Failed to register periodic sync: $e');
    }
  }
  
  /// Run immediate one-time sync
  Future<void> runImmediateSync() async {
    if (!_isInitialized) {
      await initialize();
    }
    
    try {
      await Workmanager().registerOneOffTask(
        'immediate_${DateTime.now().millisecondsSinceEpoch}',
        backgroundPaymentSyncTask,
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
      );
      
      debugPrint('✅ Immediate sync task registered');
    } catch (e) {
      debugPrint('❌ Failed to register immediate sync: $e');
    }
  }
  
  /// Stop all background sync tasks
  Future<void> stopAllSync() async {
    try {
      await Workmanager().cancelAll();
      debugPrint('🛑 All background sync tasks cancelled');
    } catch (e) {
      debugPrint('❌ Failed to cancel sync tasks: $e');
    }
  }
  
  /// Save nostr pubkey for background sync
  Future<void> saveNostrPubkey(String pubkey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nostrPubkeyKey, pubkey);
    debugPrint('💾 Nostr pubkey saved for background sync');
  }
  
  /// Save FCM token for background wake-up calls
  Future<void> saveFcmToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fcmTokenKey, token);
    debugPrint('💾 FCM token saved for background sync');
  }
  
  /// Save last payment ID for change detection
  Future<void> saveLastPaymentId(String paymentId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastPaymentIdKey, paymentId);
    debugPrint('💾 Last payment ID saved: $paymentId');
  }
  
  /// Update last app use time (call when app comes to foreground)
  Future<void> updateLastAppUseTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_app_use_time', DateTime.now().millisecondsSinceEpoch);
  }
  
  /// Clear all saved data
  Future<void> clearData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_nostrPubkeyKey);
    await prefs.remove(_lastPaymentIdKey);
    await prefs.remove(_fcmTokenKey);
    await prefs.remove(_lastSyncTimeKey);
    debugPrint('🗑️ Background sync data cleared');
  }
}
