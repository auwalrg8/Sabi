import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../services/firebase/firebase_notification_providers.dart';
import '../../../../services/firebase/fcm_token_registration_service.dart';
import '../../../../services/firebase_notification_service.dart';

/// Screen for managing push notification settings
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(notificationPreferencesProvider);
    final prefsNotifier = ref.read(notificationPreferencesProvider.notifier);
    final pushEnabled = ref.watch(pushNotificationsEnabledProvider);
    final healthCheck = ref.watch(cloudFunctionsHealthProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        elevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          // Push notification status card
          _buildStatusCard(context, pushEnabled, healthCheck),
          
          SizedBox(height: 24.h),
          
          // Category settings
          _buildSectionHeader('Notification Categories'),
          SizedBox(height: 8.h),
          
          _buildToggleTile(
            title: 'Payment Notifications',
            subtitle: 'Receive alerts when you receive Bitcoin',
            icon: Icons.bolt,
            iconColor: Colors.orange,
            value: prefs.paymentsEnabled,
            onChanged: (v) => prefsNotifier.setPaymentsEnabled(v),
          ),
          
          _buildToggleTile(
            title: 'P2P Trade Notifications',
            subtitle: 'Updates on your trades, offers, and messages',
            icon: Icons.swap_horiz,
            iconColor: Colors.blue,
            value: prefs.p2pEnabled,
            onChanged: (v) => prefsNotifier.setP2PEnabled(v),
          ),
          
          _buildToggleTile(
            title: 'Social Notifications',
            subtitle: 'Zaps, DMs, likes, and follows',
            icon: Icons.people,
            iconColor: Colors.purple,
            value: prefs.socialEnabled,
            onChanged: (v) => prefsNotifier.setSocialEnabled(v),
          ),
          
          _buildToggleTile(
            title: 'VTU Notifications',
            subtitle: 'Airtime, data, and bill payment status',
            icon: Icons.phone_android,
            iconColor: Colors.green,
            value: prefs.vtuEnabled,
            onChanged: (v) => prefsNotifier.setVTUEnabled(v),
          ),
          
          SizedBox(height: 24.h),
          
          // Sound & Vibration settings
          _buildSectionHeader('Alert Settings'),
          SizedBox(height: 8.h),
          
          _buildToggleTile(
            title: 'Sound',
            subtitle: 'Play sound for notifications',
            icon: Icons.volume_up,
            value: prefs.soundEnabled,
            onChanged: (v) => prefsNotifier.setSoundEnabled(v),
          ),
          
          _buildToggleTile(
            title: 'Vibration',
            subtitle: 'Vibrate for notifications',
            icon: Icons.vibration,
            value: prefs.vibrationEnabled,
            onChanged: (v) => prefsNotifier.setVibrationEnabled(v),
          ),
          
          _buildToggleTile(
            title: 'Badge Count',
            subtitle: 'Show unread count on app icon',
            icon: Icons.circle_notifications,
            value: prefs.badgeEnabled,
            onChanged: (v) => prefsNotifier.setBadgeEnabled(v),
          ),
          
          SizedBox(height: 24.h),
          
          // Test notification button
          _buildSectionHeader('Testing'),
          SizedBox(height: 8.h),
          _buildTestNotificationButton(context, ref),
          
          SizedBox(height: 16.h),
          _buildDebugSection(context, ref),
          
          SizedBox(height: 32.h),
        ],
      ),
    );
  }

  Widget _buildStatusCard(
    BuildContext context,
    AsyncValue<bool> pushEnabled,
    AsyncValue<bool> healthCheck,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.notifications_active,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24.sp,
                ),
                SizedBox(width: 12.w),
                Text(
                  'Push Notifications',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            
            // Permission status
            _buildStatusRow(
              'Permission',
              pushEnabled.when(
                data: (enabled) => enabled ? 'Enabled' : 'Disabled',
                loading: () => 'Checking...',
                error: (_, __) => 'Unknown',
              ),
              pushEnabled.when(
                data: (enabled) => enabled ? Colors.green : Colors.red,
                loading: () => Colors.grey,
                error: (_, __) => Colors.grey,
              ),
            ),
            
            SizedBox(height: 8.h),
            
            // Server status
            _buildStatusRow(
              'Cloud Server',
              healthCheck.when(
                data: (healthy) => healthy ? 'Connected' : 'Disconnected',
                loading: () => 'Checking...',
                error: (_, __) => 'Error',
              ),
              healthCheck.when(
                data: (healthy) => healthy ? Colors.green : Colors.red,
                loading: () => Colors.grey,
                error: (_, __) => Colors.red,
              ),
            ),
            
            if (pushEnabled.valueOrNull == false) ...[
              SizedBox(height: 12.h),
              Text(
                'Enable notifications in your device settings to receive alerts.',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String status, Color statusColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            color: Colors.grey[700],
          ),
        ),
        Row(
          children: [
            Container(
              width: 8.w,
              height: 8.w,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 6.w),
            Text(
              status,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: statusColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14.sp,
        fontWeight: FontWeight.w600,
        color: Colors.grey[600],
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildToggleTile({
    required String title,
    String? subtitle,
    required IconData icon,
    Color? iconColor,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.symmetric(vertical: 4.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.r),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.grey[600],
                ),
              )
            : null,
        secondary: Icon(icon, color: iconColor ?? Colors.grey[600]),
        value: value,
        onChanged: onChanged,
        activeColor: Colors.orange,
      ),
    );
  }

  Widget _buildTestNotificationButton(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.symmetric(vertical: 4.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.r),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: const Icon(Icons.send, color: Colors.blue),
        title: Text(
          'Send Test Notification',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          'Verify push notifications are working',
          style: TextStyle(
            fontSize: 12.sp,
            color: Colors.grey[600],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _sendTestNotification(context, ref),
      ),
    );
  }

  Future<void> _sendTestNotification(BuildContext context, WidgetRef ref) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final bridge = ref.read(breezWebhookBridgeProvider);
      final success = await bridge.sendTestNotification(
        title: 'Sabi Wallet',
        body: 'Push notifications are working! 🎉',
        type: 'general',
      );

      // ignore: use_build_context_synchronously
      Navigator.of(context).pop(); // Close loading

      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Test notification sent! Check your device.'
                : 'Failed to send notification. Check your connection.',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      // ignore: use_build_context_synchronously
      Navigator.of(context).pop(); // Close loading
      
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildDebugSection(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.symmetric(vertical: 4.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.r),
        side: BorderSide(color: Colors.orange.shade200),
      ),
      child: ExpansionTile(
        leading: const Icon(Icons.bug_report, color: Colors.orange),
        title: Text(
          'Debug Info',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDebugButton(
                  context,
                  'Show FCM Token Status',
                  Icons.token,
                  () async {
                    final status = await FCMTokenRegistrationService().debugStatus();
                    // ignore: use_build_context_synchronously
                    _showDebugDialog(context, 'FCM Token Status', status);
                  },
                ),
                SizedBox(height: 8.h),
                _buildDebugButton(
                  context,
                  'Force Re-register Token',
                  Icons.refresh,
                  () async {
                    await FCMTokenRegistrationService().forceRegisterToken();
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Token re-registered! Check logs for details.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                ),
                SizedBox(height: 8.h),
                _buildDebugButton(
                  context,
                  'Copy FCM Token',
                  Icons.copy,
                  () async {
                    final token = FirebaseNotificationService().fcmToken;
                    if (token != null) {
                      await Clipboard.setData(ClipboardData(text: token));
                      // ignore: use_build_context_synchronously
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('FCM Token copied to clipboard!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      // ignore: use_build_context_synchronously
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No FCM token available'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebugButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18.sp),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.orange,
          side: const BorderSide(color: Colors.orange),
        ),
      ),
    );
  }

  void _showDebugDialog(BuildContext context, String title, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: data.entries.map((e) {
              String valueStr = e.value?.toString() ?? 'null';
              // Truncate long values
              if (valueStr.length > 50) {
                valueStr = '${valueStr.substring(0, 50)}...';
              }
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 4.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.key,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      valueStr,
                      style: TextStyle(fontSize: 14.sp),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
