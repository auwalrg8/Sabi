import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:sabi_wallet/core/constants/colors.dart';

/// Reusable skeleton loading wrapper for consistent loading states
class AppSkeleton extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final bool ignoreContainers;
  final bool enableSwitchAnimation;

  const AppSkeleton({
    super.key,
    required this.isLoading,
    required this.child,
    this.ignoreContainers = false,
    this.enableSwitchAnimation = true,
  });

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: isLoading,
      enableSwitchAnimation: enableSwitchAnimation,
      containersColor: AppColors.surface,
      justifyMultiLineText: true,
      ignoreContainers: ignoreContainers,
      effect: PulseEffect(
        duration: const Duration(milliseconds: 1000),
        from: AppColors.background,
        to: AppColors.borderColor.withValues(alpha: 0.3),
        lowerBound: 0,
        upperBound: 1.0,
      ),
      switchAnimationConfig: const SwitchAnimationConfig(
        switchOutCurve: Curves.easeInOut,
      ),
      child: child,
    );
  }
}

/// Skeleton placeholder for text
class SkeletonText extends StatelessWidget {
  final double width;
  final double height;

  const SkeletonText({super.key, this.width = 100, this.height = 16});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width.w,
      height: height.h,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4.r),
      ),
    );
  }
}

/// Skeleton placeholder for circular avatar
class SkeletonAvatar extends StatelessWidget {
  final double size;

  const SkeletonAvatar({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size.w,
      height: size.w,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Skeleton placeholder for rectangular card
class SkeletonCard extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const SkeletonCard({
    super.key,
    this.width,
    this.height = 80,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width?.w,
      height: height.h,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(borderRadius.r),
      ),
    );
  }
}

/// Profile skeleton loader
class ProfileSkeletonLoader extends StatelessWidget {
  const ProfileSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(30.w, 10.h, 30.w, 30.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonText(width: 80, height: 24),
          SizedBox(height: 15.h),
          // Profile card skeleton
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Column(
              children: [
                SkeletonAvatar(size: 80),
                SizedBox(height: 16.h),
                SkeletonText(width: 120, height: 20),
                SizedBox(height: 8.h),
                SkeletonText(width: 150, height: 14),
              ],
            ),
          ),
          SizedBox(height: 20.h),
          // Nostr card skeleton
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: const Color(0xFF111128),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24.w,
                      height: 24.w,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    SkeletonText(width: 100, height: 16),
                  ],
                ),
                SizedBox(height: 12.h),
                SkeletonText(width: double.infinity, height: 40),
              ],
            ),
          ),
          SizedBox(height: 20.h),
          // Menu items skeleton
          ...List.generate(
            4,
            (index) => Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: Container(
                height: 56.h,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cash screen skeleton loader
class CashSkeletonLoader extends StatelessWidget {
  const CashSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Live price card skeleton
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Container(
            padding: EdgeInsets.all(14.h),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonText(width: 80, height: 12),
                    SizedBox(height: 8.h),
                    SkeletonText(width: 180, height: 15),
                    SizedBox(height: 4.h),
                    SkeletonText(width: 120, height: 11),
                  ],
                ),
                Container(
                  width: 20.w,
                  height: 20.w,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2A2A3E),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Buy/Sell toggle skeleton
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2942),
              borderRadius: BorderRadius.circular(9999),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44.h,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(9999),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Container(
                    height: 44.h,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(9999),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 12.h),
        // Amount input skeleton
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 18.h),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonText(width: 160, height: 12),
                SizedBox(height: 16.h),
                Row(
                  children: [
                    SkeletonText(width: 30, height: 40),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: SkeletonText(width: double.infinity, height: 42),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                // Quick amounts grid skeleton
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 2.5,
                  ),
                  itemCount: 6,
                  itemBuilder:
                      (context, index) => Container(
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Transaction list skeleton loader
class TransactionSkeletonLoader extends StatelessWidget {
  final int itemCount;

  const TransactionSkeletonLoader({super.key, this.itemCount = 3});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (index) => Container(
          margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: const BoxDecoration(
                  color: Color(0xFF2A2A3E),
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonText(width: 120, height: 14),
                    SizedBox(height: 4.h),
                    SkeletonText(width: 80, height: 12),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SkeletonText(width: 60, height: 14),
                  SizedBox(height: 4.h),
                  SkeletonText(width: 40, height: 12),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
