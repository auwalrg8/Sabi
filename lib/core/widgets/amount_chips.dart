import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';

/// Selectable amount chips for quick amount selection
class AmountChips extends StatelessWidget {
  final List<int> amounts;
  final int? selectedAmount;
  final ValueChanged<int?> onSelected;
  final String Function(int)? formatAmount;
  final String? currency;

  const AmountChips({
    super.key,
    required this.amounts,
    required this.selectedAmount,
    required this.onSelected,
    this.formatAmount,
    this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10.w,
      runSpacing: 10.h,
      alignment: WrapAlignment.center,
      children:
          amounts.map((amount) {
            final isSelected = selectedAmount == amount;
            return _AmountChip(
              amount: amount,
              isSelected: isSelected,
              onTap: () {
                HapticFeedback.selectionClick();
                onSelected(isSelected ? null : amount);
              },
              formatAmount: formatAmount,
              currency: currency,
            );
          }).toList(),
    );
  }
}

class _AmountChip extends StatelessWidget {
  final int amount;
  final bool isSelected;
  final VoidCallback onTap;
  final String Function(int)? formatAmount;
  final String? currency;

  const _AmountChip({
    required this.amount,
    required this.isSelected,
    required this.onTap,
    this.formatAmount,
    this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final displayText =
        formatAmount != null
            ? formatAmount!(amount)
            : '${currency ?? ''}${_formatNumber(amount)}';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(
            color:
                isSelected
                    ? AppColors.primary
                    : AppColors.textSecondary.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Text(
          displayText,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontSize: 14.sp,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(0)}k';
    }
    return number.toString();
  }
}
