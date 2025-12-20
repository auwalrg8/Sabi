import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/features/p2p/data/p2p_offer_model.dart';
import 'package:sabi_wallet/services/profile_service.dart';
import 'package:sabi_wallet/features/p2p/data/merchant_model.dart';
import 'package:sabi_wallet/features/p2p/providers/p2p_providers.dart';
import 'package:sabi_wallet/features/p2p/providers/trade_providers.dart';

class CreateOfferScreen extends ConsumerStatefulWidget {
  const CreateOfferScreen({super.key});

  @override
  ConsumerState<CreateOfferScreen> createState() => _CreateOfferScreenState();
}

class _CreateOfferScreenState extends ConsumerState<CreateOfferScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final createState = ref.watch(createOfferProvider);
    final paymentMethods = ref.watch(paymentMethodsProvider);
    final exchangeRates = ref.watch(exchangeRatesProvider);
    final marketRate = exchangeRates['BTC_NGN'] ?? 1600.0;
    final yourRate = createState.calculateRate(marketRate);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 24.sp),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Create Offer',
          style: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // What do you want to sell
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What do you want to sell?',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      Expanded(
                        child: _TypeButton(
                          label: 'Sell BTC',
                          isSelected: createState.type == OfferType.sell,
                          onTap: () => ref.read(createOfferProvider.notifier).setType(OfferType.sell),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _TypeButton(
                          label: 'Buy BTC',
                          isSelected: createState.type == OfferType.buy,
                          onTap: () => ref.read(createOfferProvider.notifier).setType(OfferType.buy),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),

            // Set Your Margin
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Set Your Margin',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 14.h),
                  Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: AppColors.primary,
                          inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                          thumbColor: AppColors.primary,
                          overlayColor: AppColors.primary.withValues(alpha: 0.2),
                          trackHeight: 6.h,
                        ),
                        child: Slider(
                          value: createState.marginPercent.clamp(-2.0, 5.0),
                          min: -2.0,
                          max: 5.0,
                          onChanged: (value) {
                            ref.read(createOfferProvider.notifier).setMargin(value);
                          },
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '-2%',
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '${createState.marginPercent >= 0 ? '+' : ''}${createState.marginPercent.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            '+5%',
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Market rate',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              '₦${marketRate.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Your rate',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              '₦${yourRate.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),

            // Amount Available
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Amount Available',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: Colors.white,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. 5000',
                      hintStyle: TextStyle(
                        fontSize: 16.sp,
                        color: AppColors.textSecondary,
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) {
                      final sats = double.tryParse(value) ?? 0;
                      ref.read(createOfferProvider.notifier).setAvailableSats(sats);
                    },
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Sats you want to ${createState.type == OfferType.sell ? 'sell' : 'buy'}',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),

            // Payment Methods You Accept
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment Methods You Accept',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  TextField(
                    controller: _searchController,
                    style: TextStyle(fontSize: 14.sp, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search',
                      hintStyle: TextStyle(fontSize: 14.sp, color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(color: AppColors.borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(color: AppColors.borderColor),
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  ...paymentMethods.map((method) {
                    final isSelected = createState.selectedPaymentMethods.contains(method.id);
                    return Padding(
                      padding: EdgeInsets.only(bottom: 8.h),
                      child: _PaymentMethodTile(
                        name: method.name,
                        isSelected: isSelected,
                        onTap: () {
                          ref.read(createOfferProvider.notifier).togglePaymentMethod(method.id);
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
            SizedBox(height: 12.h),

            // Require KYC
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Require KYC for first trade',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'Buyer must verify identity before paying',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: createState.requiresKyc,
                    onChanged: (value) {
                      ref.read(createOfferProvider.notifier).setRequiresKyc(value);
                    },
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),

            // Publish button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
                onPressed: () async {
                  // Build an offer from the create state and save to user offers
                  final state = ref.read(createOfferProvider);
                  final marketRate = (ref.read(exchangeRatesProvider)['BTC_NGN']) ?? 130000000.0;
                  final price = state.calculateRate(marketRate);
                  final id = 'user_offer_${DateTime.now().millisecondsSinceEpoch}';
                  final profile = await ProfileService.getProfile();
                  final merchant = profile != null
                      ? MerchantModel(
                          id: profile.username.isNotEmpty ? profile.username : 'me',
                          name: profile.fullName.isNotEmpty ? profile.fullName : profile.username ?? 'You',
                          avatarUrl: profile.profilePicturePath,
                          trades30d: 0,
                          completionRate: 100.0,
                          avgReleaseMinutes: 15,
                          totalVolume: 0,
                          joinedDate: DateTime.now(),
                        )
                      : null;

                  final offer = P2POfferModel(
                    id: id,
                    name: merchant?.name ?? 'You',
                    pricePerBtc: price,
                    paymentMethod: state.selectedPaymentMethods.isNotEmpty ? state.selectedPaymentMethods.first : 'Unknown',
                    eta: '-',
                    ratingPercent: 100,
                    trades: 0,
                    minLimit: 0,
                    maxLimit: 999999999,
                    type: state.type,
                    merchant: merchant,
                    acceptedMethods: null,
                    marginPercent: state.marginPercent,
                    requiresKyc: state.requiresKyc,
                    paymentInstructions: null,
                    availableSats: state.availableSats,
                  );

                  await ref.read(userOffersProvider.notifier).addOffer(offer);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Offer published successfully!'),
                      backgroundColor: AppColors.accentGreen,
                    ),
                  );
                  ref.read(createOfferProvider.notifier).reset();
                  Navigator.pop(context);
                },
                child: Text(
                  'Publish Offer',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            SizedBox(height: 8.h),
            Center(
              child: Text(
                'Your offer will be live in less than 10 seconds',
                style: TextStyle(
                  fontSize: 10.sp,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentMethodTile({
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12.r),
          border: isSelected ? Border.all(color: AppColors.primary) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              name,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                color: Colors.white,
              ),
            ),
            if (isSelected)
              const Icon(Icons.check, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
