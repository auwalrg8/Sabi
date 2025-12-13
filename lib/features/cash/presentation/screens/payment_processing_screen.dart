// ignore_for_file: unused_local_variable
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/features/cash/presentation/providers/cash_provider.dart';
import 'payment_success_screen.dart';

class PaymentProcessingScreen extends ConsumerStatefulWidget {
  const PaymentProcessingScreen({super.key});

  @override
  ConsumerState<PaymentProcessingScreen> createState() =>
      _PaymentProcessingScreenState();
}

class _PaymentProcessingScreenState
    extends ConsumerState<PaymentProcessingScreen>
    with TickerProviderStateMixin {
  late AnimationController _spinController;
  late AnimationController _progressController;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _startProgressSimulation();
  }

  @override
  void dispose() {
    _spinController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _startProgressSimulation() async {
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() => _currentStep = 0);

    await Future.delayed(const Duration(seconds: 2));
    setState(() => _currentStep = 1);

    await Future.delayed(const Duration(seconds: 2));
    setState(() => _currentStep = 2);

    await ref.read(cashProvider.notifier).processPayment();

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const PaymentSuccessScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 31.w),
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RotationTransition(
                turns: _spinController,
                child: Icon(
                  Icons.refresh,
                  size: 76.sp,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'Checking payment...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16.h),
              Text(
                'We will verify your payment. It will take 1-3  minutes. ',
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 14.sp,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),
              _buildProgressStep(
                0,
                'Payment details received',
                Icons.check_circle,
                AppColors.accentGreen,
              ),
              SizedBox(height: 12.h),
              _buildProgressStep(
                1,
                'Verifying with bank...',
                Icons.refresh,
                AppColors.primary,
              ),
              SizedBox(height: 12.h),
              _buildProgressStep(
                2,
                'Crediting your wallet',
                Icons.circle_outlined,
                const Color(0xFF374151),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressStep(
    int stepIndex,
    String label,
    IconData icon,
    Color iconColor,
  ) {
    final isCompleted = _currentStep > stepIndex;
    final isActive = _currentStep == stepIndex;
    final isPending = _currentStep < stepIndex;

    Color textColor = const Color(0xFF6B7280);
    FontWeight fontWeight = FontWeight.w400;

    if (isCompleted) {
      textColor = const Color(0xFFD1D5DB);
    } else if (isActive) {
      textColor = Colors.white;
      fontWeight = FontWeight.w500;
    }

    return Row(
      children: [
        if (isActive)
          RotationTransition(
            turns: _spinController,
            child: Icon(icon, size: 20.sp, color: iconColor),
          )
        else if (isCompleted)
          Icon(Icons.check_circle, size: 20.sp, color: AppColors.accentGreen)
        else
          Container(
            width: 20.w,
            height: 20.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: iconColor, width: 1),
            ),
          ),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12.sp,
              fontWeight: fontWeight,
            ),
          ),
        ),
      ],
    );
  }
}
