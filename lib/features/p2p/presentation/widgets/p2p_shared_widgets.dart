import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/features/p2p/providers/nip99_p2p_providers.dart';

/// Shared Explainer Card used by P2P and Trade features.
class ExplainerCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  const ExplainerCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: iconColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, color: iconColor, size: 24.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.white70,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared NIP-99 Relay Status Banner.
class Nip99StatusBanner extends ConsumerWidget {
  const Nip99StatusBanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nip99Offers = ref.watch(nip99P2POffersProvider);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF9333EA).withOpacity(0.15),
            const Color(0xFF7C3AED).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFF9333EA).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 8.w,
            height: 8.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: nip99Offers.when(
                data: (_) => const Color(0xFF00C853),
                loading: () => const Color(0xFFFFA726),
                error: (_, __) => Colors.red,
              ),
              boxShadow: [
                BoxShadow(
                  color: nip99Offers.when(
                    data: (_) => const Color(0xFF00C853).withOpacity(0.5),
                    loading: () => const Color(0xFFFFA726).withOpacity(0.5),
                    error: (_, __) => Colors.red.withOpacity(0.5),
                  ),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Icon(Icons.bolt, color: const Color(0xFF9333EA), size: 14.sp),
          SizedBox(width: 4.w),
          Text(
            'NIP-99 Marketplace',
            style: TextStyle(
              color: const Color(0xFF9333EA),
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          nip99Offers.when(
            data: (offers) => Text(
              '${offers.length} offers',
              style: TextStyle(color: Colors.white54, fontSize: 11.sp),
            ),
            loading: () => SizedBox(
              width: 12.w,
              height: 12.h,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: const Color(0xFF9333EA),
              ),
            ),
            error: (_, __) => Text(
              'Offline',
              style: TextStyle(color: Colors.red, fontSize: 11.sp),
            ),
          ),
        ],
      ),
    );
  }
}
