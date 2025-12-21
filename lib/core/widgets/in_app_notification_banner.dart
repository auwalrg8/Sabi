import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/models/notification_model.dart';

/// In-app notification banner that slides down from top
/// - Auto-dismisses after 5 seconds
/// - Shows payment/zap received with amount
/// - Tappable to open notification center
class InAppNotificationBanner extends StatefulWidget {
  final NotificationItem notification;
  final VoidCallback onDismiss;
  final VoidCallback? onTap;

  const InAppNotificationBanner({
    required this.notification,
    required this.onDismiss,
    this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  State<InAppNotificationBanner> createState() => _InAppNotificationBannerState();
}

class _InAppNotificationBannerState extends State<InAppNotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();

    // Auto-dismiss after 5 seconds
    Future.delayed(const Duration(seconds: 5), _dismissBanner);
  }

  void _dismissBanner() {
    if (mounted) {
      _animationController.reverse().then((_) {
        if (mounted) {
          widget.onDismiss();
        }
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: GestureDetector(
        onTap: () {
          widget.onTap?.call();
          _dismissBanner();
        },
        child: Container(
          margin: EdgeInsets.only(
            top: 0,
            left: 12.w,
            right: 12.w,
            bottom: 12.h,
          ),
          padding: EdgeInsets.all(14.r),
          decoration: BoxDecoration(
            color: const Color(0xFF111128),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: _getAccentColor(),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon with color coding
              Container(
                width: 44.r,
                height: 44.r,
                decoration: BoxDecoration(
                  color: _getAccentColor().withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    _getIcon(),
                    color: _getAccentColor(),
                    size: 22,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              
              // Content (title + message)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.notification.title,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontFamily: 'Google Sans',
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      widget.notification.message,
                      maxLines: 1,
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
              
              // Close button
              GestureDetector(
                onTap: _dismissBanner,
                child: Icon(
                  Icons.close,
                  color: const Color(0xFFA1A1B2),
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getAccentColor() {
    switch (widget.notification.type) {
      case 'payment_received':
      case 'zap_received':
        return const Color(0xFF00FFB2); // Mint for success
      case 'trade_completed':
        return const Color(0xFFF7931A); // Orange for trade
      default:
        return const Color(0xFFA1A1B2);
    }
  }

  IconData _getIcon() {
    switch (widget.notification.type) {
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
