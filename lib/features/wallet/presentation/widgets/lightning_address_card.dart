// lib/features/wallet/presentation/widgets/lightning_address_card.dart
// Reusable widget for displaying lightning address with copy functionality

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/services/profile_service.dart';

/// A card widget that displays the user's lightning address.
/// Includes copy-to-clipboard functionality and optional edit button.
class LightningAddressCard extends StatelessWidget {
  final UserProfile? userProfile;
  final bool showEditButton;
  final VoidCallback? onEdit;
  final VoidCallback? onRefresh;
  final bool isLoading;

  const LightningAddressCard({
    super.key,
    required this.userProfile,
    this.showEditButton = true,
    this.onEdit,
    this.onRefresh,
    this.isLoading = false,
  });

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Lightning address copied!'),
        backgroundColor: AppColors.accentGreen,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final address = userProfile?.sabiUsername ?? 'Not registered';
    final hasAddress = userProfile?.hasLightningAddress ?? false;
    final description = userProfile?.lightningAddressDescription ?? 
        'Share your Lightning address to receive payments instantly.';

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: hasAddress 
              ? AppColors.primary.withOpacity(0.3)
              : AppColors.borderColor,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  Icons.bolt_rounded,
                  color: AppColors.primary,
                  size: 20.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lightning Address',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    if (isLoading)
                      SizedBox(
                        width: 100.w,
                        height: 16.h,
                        child: LinearProgressIndicator(
                          backgroundColor: AppColors.surface,
                          color: AppColors.primary,
                        ),
                      )
                    else
                      Text(
                        address,
                        style: TextStyle(
                          color: hasAddress 
                              ? AppColors.textPrimary 
                              : AppColors.textTertiary,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              if (hasAddress && !isLoading) ...[
                // Copy button
                IconButton(
                  onPressed: () => _copyToClipboard(context, address),
                  icon: Icon(
                    Icons.copy_rounded,
                    color: AppColors.primary,
                    size: 20.sp,
                  ),
                  tooltip: 'Copy address',
                ),
              ],
              if (showEditButton && !isLoading) ...[
                // Edit button
                IconButton(
                  onPressed: onEdit,
                  icon: Icon(
                    Icons.edit_rounded,
                    color: AppColors.textSecondary,
                    size: 20.sp,
                  ),
                  tooltip: 'Edit address',
                ),
              ],
            ],
          ),
          
          SizedBox(height: 12.h),
          
          // Description
          Text(
            description,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13.sp,
              height: 1.4,
            ),
          ),
          
          // Action buttons
          if (!hasAddress && !isLoading) ...[
            SizedBox(height: 16.h),
            Text(
              'Your lightning address is being set up automatically...',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 12.sp,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          
          if (onRefresh != null && !isLoading) ...[
            SizedBox(height: 12.h),
            GestureDetector(
              onTap: onRefresh,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.refresh_rounded,
                    color: AppColors.primary,
                    size: 14.sp,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    'Refresh',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
