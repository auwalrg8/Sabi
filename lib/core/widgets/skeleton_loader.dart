// import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:sabi_wallet/core/constants/colors.dart';

// class SkeletonLoader extends StatefulWidget {
//   final double? width;
//   final double? height;
//   final BorderRadius? borderRadius;

//   const SkeletonLoader({
//     super.key,
//     this.width,
//     this.height,
//     this.borderRadius,
//   });

//   @override
//   State<SkeletonLoader> createState() => _SkeletonLoaderState();
// }

// class _SkeletonLoaderState extends State<SkeletonLoader>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _controller;
//   late Animation<double> _animation;

//   @override
//   void initState() {
//     super.initState();
//     _controller = AnimationController(
//       duration: const Duration(milliseconds: 1200),
//       vsync: this,
//     )..repeat();

//     _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
//       CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
//     );
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return AnimatedBuilder(
//       animation: _animation,
//       builder: (context, child) {
//         return Container(
//           width: widget.width,
//           height: widget.height,
//           decoration: BoxDecoration(
//             borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
//             gradient: LinearGradient(
//               begin: Alignment.centerLeft,
//               end: Alignment.centerRight,
//               colors: [
//                 AppColors.surface,
//                 AppColors.surface.withValues(alpha: 0.5),
//                 AppColors.surface,
//               ],
//               stops: [
//                 _animation.value - 0.3,
//                 _animation.value,
//                 _animation.value + 0.3,
//               ].map((e) => e.clamp(0.0, 1.0)).toList(),
//             ),
//           ),
//         );
//       },
//     );
//   }
// }

// class BalanceCardSkeleton extends StatelessWidget {
//   const BalanceCardSkeleton({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: double.infinity,
//       padding: EdgeInsets.symmetric(horizontal: 25.w, vertical: 20.h),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//           colors: [
//             AppColors.surface,
//             AppColors.surface.withValues(alpha: 0.8),
//           ],
//         ),
//         borderRadius: BorderRadius.circular(24),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withValues(alpha: 0.2),
//             blurRadius: 20,
//             offset: const Offset(0, 8),
//           ),
//         ],
//       ),
//       child: Column(
//         children: [
//           SkeletonLoader(
//             width: 100.w,
//             height: 14.h,
//             borderRadius: BorderRadius.circular(8),
//           ),
//           SizedBox(height: 12.h),
//           SkeletonLoader(
//             width: 200.w,
//             height: 56.h,
//             borderRadius: BorderRadius.circular(12),
//           ),
//           SizedBox(height: 12.h),
//           SkeletonLoader(
//             width: 120.w,
//             height: 16.h,
//             borderRadius: BorderRadius.circular(8),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class TransactionItemSkeleton extends StatelessWidget {
//   const TransactionItemSkeleton({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: EdgeInsets.only(bottom: 16.h),
//       child: Row(
//         children: [
//           SkeletonLoader(
//             width: 44.w,
//             height: 44.h,
//             borderRadius: BorderRadius.circular(22),
//           ),
//           SizedBox(width: 14.w),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 SkeletonLoader(
//                   width: 120.w,
//                   height: 16.h,
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 SizedBox(height: 6.h),
//                 SkeletonLoader(
//                   width: 80.w,
//                   height: 12.h,
//                   borderRadius: BorderRadius.circular(6),
//                 ),
//               ],
//             ),
//           ),
//           SizedBox(width: 12.w),
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.end,
//             children: [
//               SkeletonLoader(
//                 width: 80.w,
//                 height: 16.h,
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               SizedBox(height: 6.h),
//               SkeletonLoader(
//                 width: 60.w,
//                 height: 12.h,
//                 borderRadius: BorderRadius.circular(6),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }
