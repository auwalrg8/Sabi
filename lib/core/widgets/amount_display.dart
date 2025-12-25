import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';

/// Animated amount display with currency toggle
class AmountDisplay extends StatelessWidget {
  final String amount;
  final String currency;
  final String? secondaryAmount;
  final String? secondaryCurrency;
  final VoidCallback? onToggleCurrency;

  const AmountDisplay({
    super.key,
    required this.amount,
    required this.currency,
    this.secondaryAmount,
    this.secondaryCurrency,
    this.onToggleCurrency,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggleCurrency != null
          ? () {
              HapticFeedback.selectionClick();
              onToggleCurrency!();
            }
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Currency label with toggle hint
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                currency,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (onToggleCurrency != null) ...[
                SizedBox(width: 6.w),
                Icon(
                  Icons.swap_vert_rounded,
                  color: AppColors.primary,
                  size: 18.sp,
                ),
              ],
            ],
          ),
          SizedBox(height: 8.h),
          // Main amount with animation
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.8, end: 1.0).animate(animation),
                  child: child,
                ),
              );
            },
            child: Text(
              _formatAmount(amount),
              key: ValueKey(amount),
              style: TextStyle(
                color: Colors.white,
                fontSize: 52.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
              ),
            ),
          ),
          SizedBox(height: 8.h),
          // Secondary amount (conversion)
          if (secondaryAmount != null && secondaryCurrency != null)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: Text(
                '≈ $secondaryCurrency$secondaryAmount',
                key: ValueKey('$secondaryCurrency$secondaryAmount'),
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatAmount(String amount) {
    // Add thousand separators
    final parts = amount.split('.');
    final intPart = parts[0];
    final decPart = parts.length > 1 ? '.${parts[1]}' : '';
    
    final formatted = intPart.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
    
    return '$formatted$decPart';
  }
}
