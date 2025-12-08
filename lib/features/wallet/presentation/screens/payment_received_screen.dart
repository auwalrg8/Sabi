import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';

class PaymentReceivedScreen extends StatefulWidget {
  final int amountSats;
  final String description;

  const PaymentReceivedScreen({
    super.key,
    required this.amountSats,
    this.description = '',
  });

  @override
  State<PaymentReceivedScreen> createState() => _PaymentReceivedScreenState();
}

class _PaymentReceivedScreenState extends State<PaymentReceivedScreen>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  final List<FallingSat> _fallingSats = [];
  Timer? _satTimer;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    // Haptic feedback
    HapticFeedback.heavyImpact();

    // Scale animation for amount
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );

    // Fade animation for text
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    // Start animations
    _scaleController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _fadeController.forward();
    });

    // Start falling sats animation
    _startFallingSats();

    // Auto close after 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _startFallingSats() {
    _satTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (mounted && _fallingSats.length < 30) {
        setState(() {
          _fallingSats.add(
            FallingSat(
              left: _random.nextDouble() * MediaQuery.of(context).size.width,
              animationController: AnimationController(
                duration: Duration(milliseconds: 1500 + _random.nextInt(1000)),
                vsync: this,
              )..forward(),
            ),
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    _satTimer?.cancel();
    for (var sat in _fallingSats) {
      sat.animationController.dispose();
    }
    super.dispose();
  }

  String _formatSats(int sats) {
    return sats.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.85),
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            // Falling sats
            ..._fallingSats.map((sat) => _buildFallingSat(sat)),

            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Success icon
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      width: 100.w,
                      height: 100.h,
                      decoration: BoxDecoration(
                        color: AppColors.accentGreen.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle,
                        size: 60.sp,
                        color: AppColors.accentGreen,
                      ),
                    ),
                  ),

                  SizedBox(height: 40.h),

                  // "Payment Received" text
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Text(
                      'Payment Received',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  SizedBox(height: 20.h),

                  // Amount with scale animation
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      children: [
                        Text(
                          '+${_formatSats(widget.amountSats)}',
                          style: TextStyle(
                            color: AppColors.accentGreen,
                            fontSize: 64.sp,
                            fontWeight: FontWeight.w900,
                            height: 1.0.h,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'SATS',
                          style: TextStyle(
                            color: AppColors.accentGreen,
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 4.w,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 30.h),

                  // Description if available
                  if (widget.description.isNotEmpty)
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 40.w),
                        child: Text(
                          widget.description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),

                  SizedBox(height: 60.h),

                  // Tap to dismiss hint
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Text(
                      'Tap anywhere to dismiss',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallingSat(FallingSat sat) {
    return AnimatedBuilder(
      animation: sat.animationController,
      builder: (context, child) {
        final screenHeight = MediaQuery.of(context).size.height;
        final progress = sat.animationController.value;

        return Positioned(
          left: sat.left,
          top: progress * screenHeight - 30,
          child: Opacity(
            opacity: 1.0 - progress,
            child: Transform.rotate(
              angle: progress * 2 * pi,
              child: Text(
                '₿',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class FallingSat {
  final double left;
  final AnimationController animationController;

  FallingSat({required this.left, required this.animationController});
}
