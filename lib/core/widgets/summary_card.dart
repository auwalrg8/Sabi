import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';

/// A styled summary card for transaction confirmations
class SummaryCard extends StatelessWidget {
  final List<SummaryItem> items;
  final String? title;
  final EdgeInsets? padding;

  const SummaryCard({
    super.key,
    required this.items,
    this.title,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: 16.h),
          ],
          ...items.asMap().entries.map((entry) {
            final isLast = entry.key == items.length - 1;
            return Column(
              children: [
                _SummaryRow(item: entry.value),
                if (!isLast) ...[
                  SizedBox(height: 12.h),
                  Divider(
                    color: AppColors.textSecondary.withValues(alpha: 0.1),
                    height: 1,
                  ),
                  SizedBox(height: 12.h),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }
}

class SummaryItem {
  final String label;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color? valueColor;
  final bool isHighlighted;
  final bool isCopyable;

  const SummaryItem({
    required this.label,
    required this.value,
    this.subtitle,
    this.icon,
    this.valueColor,
    this.isHighlighted = false,
    this.isCopyable = false,
  });
}

class _SummaryRow extends StatelessWidget {
  final SummaryItem item;

  const _SummaryRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (item.icon != null) ...[
          Container(
            width: 36.w,
            height: 36.h,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(
              item.icon,
              color: AppColors.primary,
              size: 18.sp,
            ),
          ),
          SizedBox(width: 12.w),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(height: 4.h),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.value,
                      style: TextStyle(
                        color: item.valueColor ?? Colors.white,
                        fontSize: item.isHighlighted ? 18.sp : 15.sp,
                        fontWeight: item.isHighlighted
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (item.isCopyable)
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: item.value));
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${item.label} copied'),
                            backgroundColor: AppColors.surface,
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Padding(
                        padding: EdgeInsets.only(left: 8.w),
                        child: Icon(
                          Icons.copy,
                          color: AppColors.primary,
                          size: 16.sp,
                        ),
                      ),
                    ),
                ],
              ),
              if (item.subtitle != null) ...[
                SizedBox(height: 2.h),
                Text(
                  item.subtitle!,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
