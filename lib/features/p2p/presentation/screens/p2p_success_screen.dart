import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:flutter_confetti/flutter_confetti.dart';

/// P2P Success Screen - Trade completion celebration
class P2PSuccessScreen extends StatefulWidget {
  final double amount;
  final double sats;
  final String merchantName;
  final bool isSeller; // true if current user was the seller

  const P2PSuccessScreen({
    super.key,
    required this.amount,
    required this.sats,
    required this.merchantName,
    this.isSeller = false,
  });

  @override
  State<P2PSuccessScreen> createState() => _P2PSuccessScreenState();
}

class _P2PSuccessScreenState extends State<P2PSuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _confettiFired = false;

  final formatter = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();
  }

  void _fireConfetti() {
    if (!_confettiFired) {
      _confettiFired = true;
      // Launch confetti from center-top
      Confetti.launch(
        context,
        options: ConfettiOptions(
          particleCount: 100,
          spread: 70,
          y: 0.3,
          colors: [
            const Color(0xFFF7931A),
            const Color(0xFF00FFB2),
            const Color(0xFF6366F1),
            const Color(0xFFEC4899),
            const Color(0xFFFFD93D),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fire confetti after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _fireConfetti());

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C1A),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.5,
                colors: [
                  const Color(0xFF00FFB2).withValues(alpha: 0.15),
                  const Color(0xFF0C0C1A),
                ],
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Padding(
              padding: EdgeInsets.all(24.w),
              child: Column(
                children: [
                  const Spacer(),

                  // Success Icon
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Opacity(
                          opacity: _fadeAnimation.value,
                          child: Container(
                            padding: EdgeInsets.all(32.w),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF00FFB2,
                              ).withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Container(
                              padding: EdgeInsets.all(24.w),
                              decoration: const BoxDecoration(
                                color: Color(0xFF00FFB2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check,
                                color: const Color(0xFF0C0C1A),
                                size: 48.sp,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 32.h),

                  // Success Text
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        Text(
                          'Trade Successful! 🎉',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          widget.isSeller
                              ? 'You sold ${formatter.format(widget.sats.toInt())} sats'
                              : 'BTC has been added to your wallet',
                          style: TextStyle(
                            color: const Color(0xFFA1A1B2),
                            fontSize: 16.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 40.h),

                  // Trade Details Card
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      padding: EdgeInsets.all(24.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111128),
                        borderRadius: BorderRadius.circular(24.r),
                        border: Border.all(
                          color: const Color(0xFF00FFB2).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          // Amount received
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: EdgeInsets.all(12.w),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFF7931A,
                                  ).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Icon(
                                  Icons.currency_bitcoin,
                                  color: const Color(0xFFF7931A),
                                  size: 32.sp,
                                ),
                              ),
                              SizedBox(width: 16.w),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '+${formatter.format(widget.sats.toInt())} sats',
                                    style: TextStyle(
                                      color: const Color(0xFF00FFB2),
                                      fontSize: 24.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '≈ ₦${formatter.format(widget.amount.toInt())}',
                                    style: TextStyle(
                                      color: const Color(0xFFA1A1B2),
                                      fontSize: 14.sp,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(height: 24.h),
                          const Divider(color: Color(0xFF2A2A3E)),
                          SizedBox(height: 16.h),

                          // Trade details
                          _DetailRow(
                            label: 'Traded with',
                            value: widget.merchantName,
                          ),
                          SizedBox(height: 12.h),
                          _DetailRow(
                            label: 'Time',
                            value: _formatTime(DateTime.now()),
                          ),
                          SizedBox(height: 12.h),
                          const _DetailRow(
                            label: 'Status',
                            value: 'Completed',
                            valueColor: Color(0xFF00FFB2),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Action Buttons
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(
                                context,
                              ).popUntil((route) => route.isFirst);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00FFB2),
                              padding: EdgeInsets.symmetric(vertical: 16.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                            ),
                            child: Text(
                              'Back to P2P',
                              style: TextStyle(
                                color: const Color(0xFF0C0C1A),
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 12.h),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () {
                              // TODO: Navigate to wallet
                              Navigator.of(
                                context,
                              ).popUntil((route) => route.isFirst);
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 16.h),
                            ),
                            child: Text(
                              'View in Wallet',
                              style: TextStyle(
                                color: const Color(0xFFF7931A),
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(time.year, time.month, time.day);

    if (date == today) {
      return 'Today at ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
    return '${time.day}/${time.month}/${time.year} at ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

/// Detail Row Widget
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 14.sp),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
