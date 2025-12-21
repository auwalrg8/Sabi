import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Unread notification badge widget
/// - Shows red dot with count for unread notifications
/// - Positioned in top-right corner of bell icon
class NotificationBadge extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onTap;

  const NotificationBadge({
    required this.unreadCount,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Bell Icon
        GestureDetector(
          onTap: onTap,
          child: Icon(
            Icons.notifications_outlined,
            color: Colors.white,
            size: 24,
          ),
        ),
        
        // Badge (red dot + count)
        if (unreadCount > 0)
          Positioned(
            top: -6,
            right: -6,
            child: Container(
              width: 20.r,
              height: 20.r,
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                  style: TextStyle(
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontFamily: 'Google Sans',
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
