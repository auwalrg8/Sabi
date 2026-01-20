import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/colors.dart';
import '../../../../services/firebase/firebase_notification_providers.dart';

/// Screen for managing push notification settings
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(notificationPreferencesProvider);
    final prefsNotifier = ref.read(notificationPreferencesProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 20.h),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back,
                      color: AppColors.textPrimary,
                      size: 24.sp,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Notification Settings',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontFamily: 'Inter',
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 30.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Notification Categories Section
                    _SectionHeader(title: 'Notification Categories'),
                    SizedBox(height: 12.h),

                    _NotificationToggleTile(
                      icon: Icons.bolt,
                      iconColor: AppColors.accentYellow,
                      title: 'Payment Notifications',
                      subtitle: 'Receive alerts when you receive Bitcoin',
                      value: prefs.paymentsEnabled,
                      onChanged: (v) => prefsNotifier.setPaymentsEnabled(v),
                    ),
                    SizedBox(height: 10.h),

                    _NotificationToggleTile(
                      icon: Icons.swap_horiz,
                      iconColor: AppColors.primary,
                      title: 'P2P Trade Notifications',
                      subtitle: 'Updates on your trades, offers, and messages',
                      value: prefs.p2pEnabled,
                      onChanged: (v) => prefsNotifier.setP2PEnabled(v),
                    ),
                    SizedBox(height: 10.h),

                    _NotificationToggleTile(
                      icon: Icons.people,
                      iconColor: Colors.purple,
                      title: 'Social Notifications',
                      subtitle: 'Zaps, DMs, likes, and follows',
                      value: prefs.socialEnabled,
                      onChanged: (v) => prefsNotifier.setSocialEnabled(v),
                    ),
                    SizedBox(height: 10.h),

                    _NotificationToggleTile(
                      icon: Icons.phone_android,
                      iconColor: AppColors.accentGreen,
                      title: 'VTU Notifications',
                      subtitle: 'Airtime, data, and bill payment status',
                      value: prefs.vtuEnabled,
                      onChanged: (v) => prefsNotifier.setVTUEnabled(v),
                    ),

                    SizedBox(height: 32.h),

                    // Alert Settings Section
                    _SectionHeader(title: 'Alert Settings'),
                    SizedBox(height: 12.h),

                    _NotificationToggleTile(
                      icon: Icons.volume_up,
                      iconColor: AppColors.textSecondary,
                      title: 'Sound',
                      subtitle: 'Play sound for notifications',
                      value: prefs.soundEnabled,
                      onChanged: (v) => prefsNotifier.setSoundEnabled(v),
                    ),
                    SizedBox(height: 10.h),

                    _NotificationToggleTile(
                      icon: Icons.vibration,
                      iconColor: AppColors.textSecondary,
                      title: 'Vibration',
                      subtitle: 'Vibrate for notifications',
                      value: prefs.vibrationEnabled,
                      onChanged: (v) => prefsNotifier.setVibrationEnabled(v),
                    ),
                    SizedBox(height: 10.h),

                    _NotificationToggleTile(
                      icon: Icons.circle_notifications,
                      iconColor: AppColors.accentRed,
                      title: 'Badge Count',
                      subtitle: 'Show unread count on app icon',
                      value: prefs.badgeEnabled,
                      onChanged: (v) => prefsNotifier.setBadgeEnabled(v),
                    ),

                    SizedBox(height: 32.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        color: AppColors.textSecondary,
        fontFamily: 'Inter',
        fontSize: 12.sp,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _NotificationToggleTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NotificationToggleTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, color: iconColor, size: 20.sp),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
            inactiveThumbColor: AppColors.textSecondary,
            inactiveTrackColor: AppColors.borderColor,
          ),
        ],
      ),
    );
  }
}
