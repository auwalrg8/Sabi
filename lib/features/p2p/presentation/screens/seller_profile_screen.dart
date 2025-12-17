import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/features/p2p/data/p2p_offer_model.dart';
import 'package:sabi_wallet/features/p2p/utils/format_utils.dart';

class SellerProfileScreen extends StatelessWidget {
  final P2POfferModel offer;

  const SellerProfileScreen({super.key, required this.offer});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: AppColors.surface, title: const Text('Seller Profile')),
      backgroundColor: AppColors.background,
      body: Padding(
        padding: EdgeInsets.all(16.h),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(radius: 28, backgroundColor: AppColors.primary, child: Text(offer.name[0], style: const TextStyle(color: Colors.white))),
            SizedBox(width: 12.w),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(offer.name, style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w800)),
              SizedBox(height: 6.h),
              Text('${offer.ratingPercent}% • ${offer.trades} trades', style: TextStyle(color: AppColors.textSecondary)),
            ])
          ]),

          SizedBox(height: 18.h),
          Text('Typical limits', style: TextStyle(color: AppColors.textSecondary)),
          SizedBox(height: 8.h),
          Text('₦${offer.minLimit} - ₦${offer.maxLimit}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),

          SizedBox(height: 16.h),
          Text('Payment methods', style: TextStyle(color: AppColors.textSecondary)),
          SizedBox(height: 8.h),
          Text(offer.paymentMethod, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),

          SizedBox(height: 16.h),
          Text('Rate', style: TextStyle(color: AppColors.textSecondary)),
          SizedBox(height: 8.h),
          Text(formatCurrency(offer.pricePerBtc), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),

          SizedBox(height: 20.h),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: EdgeInsets.symmetric(vertical: 12.h)),
            onPressed: () {
              // Show offers by this seller (placeholder)
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Show seller offers (placeholder)')));
            },
            child: const Text('View Offers'),
          ),
        ]),
      ),
    );
  }
}
