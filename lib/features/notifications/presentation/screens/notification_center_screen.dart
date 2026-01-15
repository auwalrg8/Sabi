import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/models/notification_model.dart';
import 'package:intl/intl.dart';

/// Notification center screen showing all received payments/zaps/trades
class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState
    extends ConsumerState<NotificationCenterScreen> {
  List<NotificationItem> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  void _loadNotifications() {
    // This would be done through Riverpod in production
    setState(() {
      _notifications = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C0C1A),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: Text(
          'Notifications',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontFamily: 'Google Sans',
          ),
        ),
        actions: [
          if (_notifications.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(right: 16.w),
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    // Mark all as read
                    setState(() {
                      for (var notif in _notifications) {
                        notif.isRead = true;
                      }
                    });
                  },
                  child: Text(
                    'Mark all read',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: const Color(0xFFF7931A),
                      fontFamily: 'Google Sans',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body:
          _notifications.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_off,
                      size: 60,
                      color: const Color(0xFF555566),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'No notifications yet',
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: const Color(0xFFA1A1B2),
                        fontFamily: 'Google Sans',
                      ),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                padding: EdgeInsets.all(16.r),
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  final notification = _notifications[index];
                  return _buildNotificationTile(notification);
                },
              ),
    );
  }

  Widget _buildNotificationTile(NotificationItem notification) {
    return GestureDetector(
      onTap: () {
        // Mark as read and open details
        setState(() {
          notification.isRead = true;
        });
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(
          color: const Color(0xFF111128),
          border: Border.all(
            color:
                notification.isRead
                    ? Colors.transparent
                    : const Color(0xFFF7931A),
            width: notification.isRead ? 0 : 1.5,
          ),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            // Avatar/Icon
            Container(
              width: 48.r,
              height: 48.r,
              decoration: BoxDecoration(
                color: _getIconBackgroundColor(notification.type),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  _getIcon(notification.type),
                  color: _getIconColor(notification.type),
                  size: 24,
                ),
              ),
            ),
            SizedBox(width: 12.w),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        notification.title,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontFamily: 'Google Sans',
                        ),
                      ),
                      Text(
                        _formatTime(notification.timestamp),
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: const Color(0xFFA1A1B2),
                          fontFamily: 'Google Sans',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    notification.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: const Color(0xFFA1A1B2),
                      fontFamily: 'Google Sans',
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),

            // Amount badge
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: _getAccentColor(notification.type).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                '${notification.currency}${_formatAmount(notification.amount)}',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: _getAccentColor(notification.type),
                  fontFamily: 'Google Sans',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM dd').format(timestamp);
    }
  }

  String _formatAmount(double amount) {
    final formatted = amount.toStringAsFixed(0);
    return formatted.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (Match m) => '${m[1]},',
    );
  }

  Color _getAccentColor(String type) {
    switch (type) {
      case 'payment_received':
      case 'zap_received':
        return const Color(0xFF00FFB2);
      case 'trade_completed':
        return const Color(0xFFF7931A);
      default:
        return const Color(0xFFA1A1B2);
    }
  }

  Color _getIconBackgroundColor(String type) {
    return _getAccentColor(type).withOpacity(0.15);
  }

  Color _getIconColor(String type) {
    return _getAccentColor(type);
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'payment_received':
        return Icons.arrow_downward_rounded;
      case 'zap_received':
        return Icons.bolt;
      case 'trade_completed':
        return Icons.swap_horiz;
      default:
        return Icons.notifications;
    }
  }
}
