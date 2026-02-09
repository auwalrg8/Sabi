import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';

/// A tooltip overlay that appears on first install to encourage users
/// to complete wallet setup (backup, nostr keys, PIN code)
class SetupTooltipOverlay extends StatefulWidget {
  final VoidCallback onDismiss;
  final GlobalKey? targetKey;
  final List<String> pendingSetupItems;

  const SetupTooltipOverlay({
    super.key,
    required this.onDismiss,
    this.targetKey,
    required this.pendingSetupItems,
  });

  @override
  State<SetupTooltipOverlay> createState() => _SetupTooltipOverlayState();
}

class _SetupTooltipOverlayState extends State<SetupTooltipOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _getMainMessage() {
    if (widget.pendingSetupItems.isEmpty) {
      return 'Your wallet is all set up!';
    }

    final count = widget.pendingSetupItems.length;
    if (count == 1) {
      return 'Complete 1 important step to secure your wallet';
    }
    return 'Complete $count important steps to secure your wallet';
  }

  String _getSetupItemLabel(String item) {
    switch (item) {
      case 'backup':
        return '🛡️ Back up your wallet';
      case 'nostr':
        return '🔑 Set up Nostr keys';
      case 'pin':
        return '🔒 Create a PIN code';
      case 'socialRecovery':
        return '👥 Set up Social Recovery';
      default:
        return item;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Semi-transparent backdrop
          GestureDetector(
            onTap: widget.onDismiss,
            child: AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return Container(
                  color: Colors.black.withValues(alpha: 0.75),
                );
              },
            ),
          ),

          // Tooltip card positioned above center
          Positioned(
            left: 20.w,
            right: 20.w,
            top: MediaQuery.of(context).size.height * 0.25,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: child,
                );
              },
              child: Container(
                padding: EdgeInsets.all(20.r),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.95),
                      AppColors.primary.withValues(alpha: 0.85),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20.r),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header icon
                    Container(
                      padding: EdgeInsets.all(12.r),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.security_rounded,
                        color: Colors.white,
                        size: 32.sp,
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Title
                    Text(
                      'Secure Your Wallet',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8.h),

                    // Subtitle
                    Text(
                      _getMainMessage(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14.sp,
                      ),
                    ),
                    SizedBox(height: 20.h),

                    // Setup items list
                    if (widget.pendingSetupItems.isNotEmpty) ...[
                      Container(
                        padding: EdgeInsets.all(12.r),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Column(
                          children: widget.pendingSetupItems.map((item) {
                            return Padding(
                              padding: EdgeInsets.symmetric(vertical: 6.h),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8.w,
                                    height: 8.h,
                                    decoration: BoxDecoration(
                                      color: _getItemColor(item),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: Text(
                                      _getSetupItemLabel(item),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      SizedBox(height: 20.h),
                    ],

                    // Arrow pointing down to suggestions
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, 4 * _pulseController.value),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white.withValues(alpha: 0.8),
                            size: 32.sp,
                          ),
                        );
                      },
                    ),

                    Text(
                      'Tap the cards below to get started',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12.sp,
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Dismiss button
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: widget.onDismiss,
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: Text(
                          'Got it!',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getItemColor(String item) {
    switch (item) {
      case 'backup':
        return const Color(0xFFF94B4B); // Red
      case 'nostr':
        return const Color(0xFF7A3DFE); // Purple
      case 'pin':
        return const Color(0xFF00F2B5); // Green
      case 'socialRecovery':
        return const Color(0xFF8B5CF6); // Violet
      default:
        return Colors.white;
    }
  }
}

/// A pulsing glow wrapper for suggestion cards when setup is incomplete
class PulsingGlowWrapper extends StatefulWidget {
  final Widget child;
  final bool shouldPulse;
  final Color glowColor;

  const PulsingGlowWrapper({
    super.key,
    required this.child,
    this.shouldPulse = true,
    this.glowColor = AppColors.primary,
  });

  @override
  State<PulsingGlowWrapper> createState() => _PulsingGlowWrapperState();
}

class _PulsingGlowWrapperState extends State<PulsingGlowWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.shouldPulse) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(PulsingGlowWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldPulse && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.shouldPulse && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.shouldPulse) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.r),
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withValues(alpha: 0.3 * _animation.value),
                blurRadius: 12 + (8 * _animation.value),
                spreadRadius: 2 * _animation.value,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
