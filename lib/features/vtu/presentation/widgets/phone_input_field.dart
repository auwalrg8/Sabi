import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Phone number input field with Nigerian formatting
class PhoneInputField extends StatelessWidget {
  final TextEditingController controller;
  final String? detectedNetwork;
  final Color? networkColor;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const PhoneInputField({
    super.key,
    required this.controller,
    this.detectedNetwork,
    this.networkColor,
    this.errorText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Phone Number',
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
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF111128),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12.r),
                    bottomLeft: Radius.circular(12.r),
                  ),
                ),
                child: Row(
                  children: [
                    Text('🇳🇬', style: TextStyle(fontSize: 18.sp)),
                    SizedBox(width: 4.w),
                    Text(
                      '+234',
                      style: TextStyle(
                        color: const Color(0xFFA1A1B2),
                        fontSize: 14.sp,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: Colors.white, fontSize: 16.sp),
                  decoration: InputDecoration(
                    hintText: '0801 234 5678',
                    hintStyle: TextStyle(
                      color: const Color(0xFF6B7280),
                      fontSize: 16.sp,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 14.h,
                    ),
                    suffixIcon:
                        detectedNetwork != null
                            ? Padding(
                              padding: EdgeInsets.only(right: 12.w),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8.w,
                                  vertical: 4.h,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      networkColor?.withOpacity(0.2) ??
                                      Colors.grey.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: Text(
                                  detectedNetwork!,
                                  style: TextStyle(
                                    color: networkColor ?? Colors.grey,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            )
                            : null,
                    suffixIconConstraints: BoxConstraints(minHeight: 24.h),
                  ),
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
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
