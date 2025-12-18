import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/features/wallet/domain/models/send_transaction.dart';
import 'package:sabi_wallet/features/wallet/presentation/screens/payment_success_screen.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';

class SendProgressScreen extends StatefulWidget {
  final SendTransaction transaction;

  const SendProgressScreen({super.key, required this.transaction});

  @override
  State<SendProgressScreen> createState() => _SendProgressScreenState();
}

class _SendProgressScreenState extends State<SendProgressScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _hasError = false;
  String _errorMessage = '';
  Timer? _successTimer;
  bool _navigatedToSuccess = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // ACTUAL PAYMENT EXECUTION
    _executePayment();
  }

  Future<void> _executePayment() async {
    try {
      // Convert NGN amount to sats (using the amountInSats from transaction model)
      final amountSats = widget.transaction.amountInSats.toInt();

      // Send payment via Breez Spark SDK with amount
      final sendFuture = BreezSparkService.sendPayment(
        widget.transaction.recipient.identifier,
        sats: amountSats,
        recipientName: widget.transaction.recipient.name,
      );

      _successTimer = Timer(const Duration(seconds: 5), _navigateToSuccess);

      final result = await sendFuture;

      // Extract actual fees and amounts from SDK response
      final actualAmountSats = BreezSparkService.extractSendAmountSats(result);
      final actualFeeSats = BreezSparkService.extractSendFeeSats(result);

      debugPrint(
        '✅ Payment sent: $actualAmountSats sats, fee: $actualFeeSats sats',
      );
    } catch (e) {
      debugPrint('❌ Payment failed: $e');
      _successTimer?.cancel();
      if (_navigatedToSuccess) return;
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  void _navigateToSuccess() {
    if (_navigatedToSuccess || !mounted) return;
    _navigatedToSuccess = true;
    _successTimer?.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder:
            (context) => PaymentSuccessScreen(transaction: widget.transaction),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _successTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(30.h),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 80.sp),
                  SizedBox(height: 24.h),
                  Text(
                    'Payment Failed',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    _errorMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14.sp,
                    ),
                  ),
                  SizedBox(height: 40.h),
                  ElevatedButton(
                    onPressed:
                        () => Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentRed,
                      padding: EdgeInsets.symmetric(
                        horizontal: 40.w,
                        vertical: 16.h,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: Text(
                      'Go Back',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: child,
                  );
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 201.w,
                      height: 201.h,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 4.w,
                        ),
                      ),
                    ),
                    Container(
                      width: 128.w,
                      height: 128.h,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.flash_on,
                        color: Colors.white,
                        size: 64.sp,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 66.h),
              Text(
                'Sending...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 29.h),
              Text(
                'Please wait',
                style: TextStyle(color: Colors.white70, fontSize: 14.sp),
              ),
              SizedBox(height: 29.h),
              SizedBox(
                width: 160.w,
                height: 50.h,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: AppColors.accentRed,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
