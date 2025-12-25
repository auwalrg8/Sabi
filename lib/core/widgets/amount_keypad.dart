import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';

/// A modern number keypad for amount input
class AmountKeypad extends StatelessWidget {
  final VoidCallback onDelete;
  final ValueChanged<String> onDigit;
  final bool showDecimal;

  const AmountKeypad({
    super.key,
    required this.onDelete,
    required this.onDigit,
    this.showDecimal = true,
  });

  @override
  Widget build(BuildContext context) {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      [showDecimal ? '.' : '', '0', '⌫'],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows.map((row) => _buildRow(row)).toList(),
    );
  }

  Widget _buildRow(List<String> keys) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: keys.map((key) => _KeypadButton(
          value: key,
          onTap: key.isEmpty
              ? null
              : key == '⌫'
                  ? onDelete
                  : () => onDigit(key),
        )).toList(),
      ),
    );
  }
}

class _KeypadButton extends StatelessWidget {
  final String value;
  final VoidCallback? onTap;

  const _KeypadButton({
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) {
      return SizedBox(width: 80.w, height: 60.h);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap != null
            ? () {
                HapticFeedback.lightImpact();
                onTap!();
              }
            : null,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          width: 80.w,
          height: 60.h,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Center(
            child: value == '⌫'
                ? Icon(
                    Icons.backspace_outlined,
                    color: AppColors.textSecondary,
                    size: 24.sp,
                  )
                : Text(
                    value,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
