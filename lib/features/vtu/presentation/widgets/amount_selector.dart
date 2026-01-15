import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/services/rate_service.dart';

/// Amount selector grid with Naira and Sats display
class AmountSelector extends StatelessWidget {
  final List<double> amounts;
  final double? selectedAmount;
  final ValueChanged<double> onAmountSelected;
  final Color accentColor;

  const AmountSelector({
    super.key,
    required this.amounts,
    this.selectedAmount,
    required this.onAmountSelected,
    this.accentColor = const Color(0xFFF7931A),
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Amount',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 12.h),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 10.w,
            mainAxisSpacing: 10.h,
            childAspectRatio: 1.1,
          ),
          itemCount: amounts.length,
          itemBuilder: (context, index) {
            final amount = amounts[index];
            final isSelected = selectedAmount == amount;
            return _AmountButton(
              amount: amount,
              isSelected: isSelected,
              accentColor: accentColor,
              onTap: () => onAmountSelected(amount),
            );
          },
        ),
      ],
    );
  }
}

class _AmountButton extends StatelessWidget {
  final double amount;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;

  const _AmountButton({
    required this.amount,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? accentColor.withOpacity(0.15)
                  : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected ? accentColor : const Color(0xFF2A2A3E),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              RateService.formatNaira(amount),
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFFA1A1B2),
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom amount input field
class CustomAmountInput extends StatelessWidget {
  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final double? minAmount;
  final double? maxAmount;

  const CustomAmountInput({
    super.key,
    required this.controller,
    this.errorText,
    this.onChanged,
    this.minAmount,
    this.maxAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Or Enter Custom Amount',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8.h),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color:
                  errorText != null
                      ? const Color(0xFFFF4D4F)
                      : const Color(0xFF2A2A3E),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF111128),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12.r),
                    bottomLeft: Radius.circular(12.r),
                  ),
                ),
                child: Text(
                  '₦',
                  style: TextStyle(
                    color: const Color(0xFFA1A1B2),
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: Colors.white, fontSize: 16.sp),
                  decoration: InputDecoration(
                    hintText: '1,000',
                    hintStyle: TextStyle(
                      color: const Color(0xFF6B7280),
                      fontSize: 16.sp,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 14.h,
                    ),
                  ),
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
        if (minAmount != null || maxAmount != null) ...[
          SizedBox(height: 6.h),
          Text(
            'Min: ${RateService.formatNaira(minAmount ?? 0)} • Max: ${RateService.formatNaira(maxAmount ?? 0)}',
            style: TextStyle(color: const Color(0xFF6B7280), fontSize: 11.sp),
          ),
        ],
        if (errorText != null) ...[
          SizedBox(height: 6.h),
          Text(
            errorText!,
            style: TextStyle(color: const Color(0xFFFF4D4F), fontSize: 12.sp),
          ),
        ],
      ],
    );
  }
}
