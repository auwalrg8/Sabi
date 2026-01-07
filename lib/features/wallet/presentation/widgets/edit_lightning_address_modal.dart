// lib/features/wallet/presentation/widgets/edit_lightning_address_modal.dart
// Modal for editing/changing lightning address username

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';
import 'package:sabi_wallet/services/lightning_address_manager.dart';

/// Shows a modal bottom sheet for editing the lightning address.
/// Returns true if the address was successfully updated.
Future<bool?> showEditLightningAddressModal({
  required BuildContext context,
  required String currentUsername,
  required bool hasExistingAddress,
}) async {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => EditLightningAddressModal(
      currentUsername: currentUsername,
      hasExistingAddress: hasExistingAddress,
    ),
  );
}

class EditLightningAddressModal extends StatefulWidget {
  final String currentUsername;
  final bool hasExistingAddress;

  const EditLightningAddressModal({
    super.key,
    required this.currentUsername,
    required this.hasExistingAddress,
  });

  @override
  State<EditLightningAddressModal> createState() => _EditLightningAddressModalState();
}

class _EditLightningAddressModalState extends State<EditLightningAddressModal> {
  late TextEditingController _usernameController;
  String? _errorText;
  bool _isChecking = false;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.currentUsername);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _saveUsername() async {
    final newUsername = _usernameController.text.trim().toLowerCase();
    
    // Validate format
    final validationError = LightningAddressManager.validateUsername(newUsername);
    if (validationError != null) {
      setState(() => _errorText = validationError);
      return;
    }
    
    // Skip if username hasn't changed
    if (newUsername == widget.currentUsername.toLowerCase()) {
      Navigator.pop(context, false);
      return;
    }

    // Check availability
    setState(() {
      _isChecking = true;
      _errorText = null;
    });

    try {
      final available = await BreezSparkService.checkLightningAddressAvailability(newUsername);
      
      if (!available) {
        setState(() {
          _errorText = 'Username "$newUsername" is already taken';
          _isChecking = false;
        });
        return;
      }

      // Update address
      setState(() {
        _isChecking = false;
        _isUpdating = true;
      });

      // Delete old address if exists
      if (widget.hasExistingAddress) {
        await BreezSparkService.deleteLightningAddress();
      }

      // Register new address
      await BreezSparkService.registerLightningAddress(
        username: newUsername,
        description: 'Receive sats via Sabi Wallet',
      );

      // Save to secure storage
      await LightningAddressManager.saveRegisteredAddress(
        username: newUsername,
        fullAddress: LightningAddressManager.formatAddress(newUsername),
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _errorText = 'Failed to update: ${e.toString().replaceAll('Exception: ', '')}';
        _isChecking = false;
        _isUpdating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isProcessing = _isChecking || _isUpdating;
    
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24.r),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.borderColor,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: 20.h),

            // Title
            Text(
              widget.hasExistingAddress ? 'Change Lightning Address' : 'Set Lightning Address',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Choose a unique username for your Lightning address',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.sp,
              ),
            ),
            SizedBox(height: 20.h),

            // Username input
            Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: _errorText != null ? Colors.red : AppColors.borderColor,
                ),
              ),
              child: TextField(
                controller: _usernameController,
                enabled: !isProcessing,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14.sp,
                ),
                textInputAction: TextInputAction.done,
                autocorrect: false,
                onSubmitted: (_) => _saveUsername(),
                decoration: InputDecoration(
                  hintText: 'username',
                  hintStyle: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 14.sp,
                  ),
                  suffixText: '@${LightningAddressManager.domain}',
                  suffixStyle: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.sp,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 14.h,
                  ),
                ),
                onChanged: (_) {
                  if (_errorText != null) {
                    setState(() => _errorText = null);
                  }
                },
              ),
            ),
            
            // Error text
            if (_errorText != null) ...[
              SizedBox(height: 8.h),
              Text(
                _errorText!,
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12.sp,
                ),
              ),
            ],
            
            SizedBox(height: 20.h),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isProcessing ? null : () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.borderColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14.sp,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isProcessing ? null : _saveUsername,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                    ),
                    child: isProcessing
                        ? SizedBox(
                            width: 20.w,
                            height: 20.w,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Save',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
          ],
        ),
      ),
    );
  }
}
