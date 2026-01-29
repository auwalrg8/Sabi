import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/services/nostr/nostr_service.dart';

/// Clean, modern offer card for P2P v2
class P2POfferCard extends StatelessWidget {
  final NostrP2POffer offer;
  final VoidCallback onTap;
  final bool isMyOffer;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const P2POfferCard({
    super.key,
    required this.offer,
    required this.onTap,
    this.isMyOffer = false,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: AppColors.borderColor.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Seller info + Type badge
            Row(
              children: [
                // Seller avatar
                _buildSellerAvatar(),
                SizedBox(width: 12.w),
                
                // Seller name and rating
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer.sellerName ?? 'Anonymous',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Row(
                        children: [
                          Icon(Icons.star, color: AppColors.accentYellow, size: 12.sp),
                          SizedBox(width: 4.w),
                          Text(
                            '${offer.sellerCompletionRate.toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11.sp,
                            ),
                          ),
                          if (offer.sellerTradeCount > 0) ...[
                            SizedBox(width: 8.w),
                            Text(
                              '${offer.sellerTradeCount} trades',
                              style: TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 11.sp,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Type badge
                _buildTypeBadge(),
              ],
            ),
            
            SizedBox(height: 16.h),
            
            // Price
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Price',
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 11.sp,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        offer.formattedPrice,
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Limits
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Limits',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 11.sp,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      offer.amountRange,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            SizedBox(height: 12.h),
            
            // Payment methods
            Wrap(
              spacing: 6.w,
              runSpacing: 6.h,
              children: offer.paymentMethods.take(3).map((method) {
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    method,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 11.sp,
                    ),
                  ),
                );
              }).toList(),
            ),
            
            // Actions for my offers
            if (isMyOffer && (onEdit != null || onDelete != null)) ...[
              SizedBox(height: 12.h),
              Divider(color: AppColors.borderColor, height: 1),
              SizedBox(height: 8.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onEdit != null)
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: Icon(Icons.edit, size: 16.sp, color: AppColors.textSecondary),
                      label: Text(
                        'Edit',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
                      ),
                    ),
                  if (onDelete != null)
                    TextButton.icon(
                      onPressed: onDelete,
                      icon: Icon(Icons.delete_outline, size: 16.sp, color: AppColors.accentRed),
                      label: Text(
                        'Delete',
                        style: TextStyle(color: AppColors.accentRed, fontSize: 12.sp),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSellerAvatar() {
    return Container(
      width: 40.w,
      height: 40.h,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: offer.sellerAvatar != null
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: offer.sellerAvatar!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _buildAvatarFallback(),
              ),
            )
          : _buildAvatarFallback(),
    );
  }

  Widget _buildAvatarFallback() {
    final initial = (offer.sellerName ?? 'A')[0].toUpperCase();
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          color: AppColors.primary,
          fontSize: 16.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTypeBadge() {
    final isBuy = offer.type == P2POfferType.buy;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: isBuy
            ? AppColors.accentGreen.withOpacity(0.2)
            : AppColors.accentRed.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(
        isBuy ? 'BUY' : 'SELL',
        style: TextStyle(
          color: isBuy ? AppColors.accentGreen : AppColors.accentRed,
          fontSize: 11.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
