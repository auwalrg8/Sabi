import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';

/// A visual step progress indicator for multi-step flows
class StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String>? stepLabels;

  const StepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.stepLabels,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps * 2 - 1, (index) {
        if (index.isOdd) {
          // Connector line
          final stepBefore = index ~/ 2;
          final isCompleted = stepBefore < currentStep;
          return Expanded(
            child: Container(
              height: 2.h,
              margin: EdgeInsets.symmetric(horizontal: 4.w),
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppColors.primary
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(1.r),
              ),
            ),
          );
        } else {
          // Step circle
          final stepIndex = index ~/ 2;
          final isCompleted = stepIndex < currentStep;
          final isCurrent = stepIndex == currentStep;

          return _StepCircle(
            stepNumber: stepIndex + 1,
            isCompleted: isCompleted,
            isCurrent: isCurrent,
            label: stepLabels != null && stepIndex < stepLabels!.length
                ? stepLabels![stepIndex]
                : null,
          );
        }
      }),
    );
  }
}

class _StepCircle extends StatelessWidget {
  final int stepNumber;
  final bool isCompleted;
  final bool isCurrent;
  final String? label;

  const _StepCircle({
    required this.stepNumber,
    required this.isCompleted,
    required this.isCurrent,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: isCurrent ? 36.w : 28.w,
          height: isCurrent ? 36.h : 28.h,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted
                ? AppColors.primary
                : isCurrent
                    ? AppColors.primary.withValues(alpha: 0.2)
                    : AppColors.surface,
            border: Border.all(
              color: isCompleted || isCurrent
                  ? AppColors.primary
                  : AppColors.textSecondary.withValues(alpha: 0.3),
              width: 2.w,
            ),
          ),
          child: Center(
            child: isCompleted
                ? Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16.sp,
                  )
                : Text(
                    '$stepNumber',
                    style: TextStyle(
                      color: isCurrent
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontSize: isCurrent ? 14.sp : 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        if (label != null) ...[
          SizedBox(height: 4.h),
          Text(
            label!,
            style: TextStyle(
              color: isCurrent
                  ? AppColors.primary
                  : isCompleted
                      ? Colors.white
                      : AppColors.textSecondary,
              fontSize: 10.sp,
              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ],
    );
  }
}
