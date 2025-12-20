import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/features/p2p/data/p2p_offer_model.dart';
import 'package:sabi_wallet/features/p2p/providers/trade_providers.dart';
import 'package:sabi_wallet/features/p2p/utils/format_utils.dart';
import 'package:sabi_wallet/features/p2p/presentation/screens/merchant_profile_screen.dart';
import 'package:intl/intl.dart';
import 'dart:io';

class OfferDetailsScreen extends ConsumerStatefulWidget {
  final P2POfferModel offer;

  const OfferDetailsScreen({super.key, required this.offer});

  @override
  ConsumerState<OfferDetailsScreen> createState() => _OfferDetailsScreenState();
}

class _OfferDetailsScreenState extends ConsumerState<OfferDetailsScreen> {
  double _amount = 0;
  final TextEditingController _amountController = TextEditingController(text: '0');
  final formatter = NumberFormat('#,###');

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _setAmount(double amount) {
    setState(() {
      _amount = amount;
      _amountController.text = amount.toInt().toString();
    });
  }

  double get _receiveSats {
    if (_amount == 0) return 0;
    return (_amount / widget.offer.pricePerBtc) * 100000000;
  }

  @override
  Widget build(BuildContext context) {
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
          'Offer Details',
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
            // Merchant card
            Container(
              padding: EdgeInsets.all(20.w),
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
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          final merchantId = widget.offer.merchant?.id ?? widget.offer.name;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MerchantProfileScreen(merchantId: merchantId),
                            ),
                          );
                        },
                        child: FutureBuilder(
                          future: ProfileService.getProfile(),
                          builder: (ctx, snap) {
                            final user = snap.data;
                            final isCurrentUser = user != null && (widget.offer.merchant?.id == user.username || widget.offer.name == user.fullName || widget.offer.name == user.username);
                            if (isCurrentUser && user!.profilePicturePath != null && user.profilePicturePath!.isNotEmpty) {
                              return CircleAvatar(
                                radius: 30.r,
                                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                                backgroundImage: FileImage(File(user.profilePicturePath!)) as ImageProvider,
                              );
                            }

                            if (widget.offer.merchant?.avatarUrl != null && widget.offer.merchant!.avatarUrl!.isNotEmpty) {
                              return CircleAvatar(
                                radius: 30.r,
                                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                                backgroundImage: NetworkImage(widget.offer.merchant!.avatarUrl!),
                              );
                            }

                            return CircleAvatar(
                              radius: 30.r,
                              backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                              child: Text(
                                widget.offer.name[0],
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 24.sp,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    final merchantId = widget.offer.merchant?.id ?? widget.offer.name;
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => MerchantProfileScreen(merchantId: merchantId),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    widget.offer.name,
                                    style: TextStyle(
                                      fontSize: 17.sp,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Icon(Icons.verified, color: Colors.blue, size: 20.sp),
                              ],
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              '${widget.offer.ratingPercent}% • ${widget.offer.trades} trades',
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (widget.offer.requiresKyc) ...[
                              SizedBox(height: 8.h),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.primary),
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                                child: Text(
                                  'KYC required for first trade',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),
                  Row(
                    children: [
                      Expanded(
                        child: _InfoTile(
                          icon: Icons.access_time,
                          iconColor: AppColors.accentGreen,
                          label: 'Response',
                          value: widget.offer.responseTime ?? '<3 min',
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _InfoTile(
                          icon: Icons.trending_up,
                          iconColor: AppColors.primary,
                          label: 'Volume',
                          value: '₦${(widget.offer.volume ?? 45000000) ~/ 1000000}M',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 17.h),

            // Warning
            if (widget.offer.requiresKyc)
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, color: AppColors.primary, size: 20.sp),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        'You must verify identity in chat before payment',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (widget.offer.requiresKyc) SizedBox(height: 17.h),

            // Amount input
            Container(
              padding: EdgeInsets.all(20.w),
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
                    'How much you wan buy?',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 21.h),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '₦',
                        style: TextStyle(
                          fontSize: 41.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: TextField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(
                            fontSize: 48.sp,
                            fontWeight: FontWeight.w700,
                            color: _amount > 0 ? Colors.white : AppColors.textSecondary,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: '0',
                            hintStyle: TextStyle(
                              fontSize: 48.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          onChanged: (value) {
                            final amount = double.tryParse(value.replaceAll(',', '')) ?? 0;
                            setState(() => _amount = amount);
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: [
                      _AmountChip(amount: 50000, onTap: _setAmount),
                      _AmountChip(amount: 100000, onTap: _setAmount),
                      _AmountChip(amount: 500000, onTap: _setAmount),
                      _AmountChip(amount: 1000000, onTap: _setAmount),
                    ],
                  ),
                  SizedBox(height: 20.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'You receive',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        _receiveSats > 0 ? '${formatter.format(_receiveSats)} sats' : '0 sats',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentGreen,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Rate',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '₦1,616 per \$1',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 17.h),

            // Payment instructions
            if (widget.offer.paymentInstructions != null)
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: AppColors.primary),
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
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.primary, size: 20.sp),
                        SizedBox(width: 8.w),
                        Text(
                          'Payment Instructions',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      widget.offer.paymentInstructions!,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            if (widget.offer.paymentInstructions != null) SizedBox(height: 17.h),

            // Security notice
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
              child: Row(
                children: [
                  Icon(Icons.security, color: AppColors.accentGreen, size: 20.sp),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      'Funds held in non-custodial Lightning escrow until you confirm receipt. Your money is safe.',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),

            // Trade button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _amount >= widget.offer.minLimit && _amount <= widget.offer.maxLimit
                      ? AppColors.primary
                      : AppColors.disabled,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
                onPressed: _amount >= widget.offer.minLimit && _amount <= widget.offer.maxLimit
                    ? () {
                        ref.read(tradeProvider(widget.offer.id).notifier).updatePayAmount(_amount);
                        ref.read(tradeProvider(widget.offer.id).notifier).startTrade();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Trade started for ${formatCurrency(_amount)}'),
                            backgroundColor: AppColors.accentGreen,
                          ),
                        );
                        Navigator.pop(context);
                      }
                    : null,
                child: Text(
                  'Start Trade',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
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

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(50),
          ),
          child: Icon(icon, color: iconColor, size: 20.sp),
        ),
        SizedBox(width: 12.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10.sp,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              value,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AmountChip extends StatelessWidget {
  final double amount;
  final Function(double) onTap;

  const _AmountChip({required this.amount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,###');
    return GestureDetector(
      onTap: () => onTap(amount),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Text(
          '₦ ${formatter.format(amount)}',
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
