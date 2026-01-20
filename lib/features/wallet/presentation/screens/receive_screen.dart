import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/core/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';
import 'package:sabi_wallet/services/profile_service.dart';
// Nostr receive removed from this screen — nostr imports not required here
import 'package:sabi_wallet/features/wallet/presentation/widgets/edit_lightning_address_modal.dart';
import 'package:sabi_wallet/l10n/app_localizations.dart';

class ReceiveScreen extends ConsumerStatefulWidget {
  const ReceiveScreen({super.key});

  @override
  ConsumerState<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends ConsumerState<ReceiveScreen> {
  bool isStaticMode = false;
  int? selectedAmount;
  String selectedExpiry = '24 hours';
  bool isExpiryExpanded = false;
  final TextEditingController _descriptionController = TextEditingController();
  String? _bolt11;
  bool _creating = false;
  bool _isSyncingLightningAddress = false;
  UserProfile? _userProfile;

  final List<int> presetAmounts = [1000, 5000, 10000];
  final List<String> expiryOptions = [
    '1 hour',
    '24 hours',
    '7 days',
    'Never expires',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final profile = await ProfileService.getProfile();
    if (mounted) {
      setState(() => _userProfile = profile);
    }
  }

  // Nostr npub loading removed — nostr receive removed from this screen

  Future<void> _refreshLightningAddress() async {
    if (_isSyncingLightningAddress) return;
    setState(() => _isSyncingLightningAddress = true);
    try {
      await BreezSparkService.fetchLightningAddress();
      await _loadUserProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lightning address refreshed'),
          backgroundColor: AppColors.accentGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to refresh: ${e.toString().replaceAll('Exception: ', '')}',
          ),
          backgroundColor: AppColors.surface,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSyncingLightningAddress = false);
    }
  }

  Future<void> _showEditLightningAddressModal() async {
    final currentUsername =
        _userProfile?.lightningAddress?.username ??
        _userProfile?.username ??
        '';
    final hasExisting = _userProfile?.hasLightningAddress ?? false;

    final result = await showEditLightningAddressModal(
      context: context,
      currentUsername: currentUsername,
      hasExistingAddress: hasExisting,
    );

    if (result == true) {
      await _loadUserProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lightning address updated!'),
            backgroundColor: AppColors.accentGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        backgroundColor: AppColors.surface,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(30.h),
                child: Column(
                  children: [
                      _buildQRCodeSection(),
                      SizedBox(height: 30.h),
                      _buildUserInfo(),
                      SizedBox(height: 4.h),
                      _buildAmountSelector(),
                      SizedBox(height: 30.h),
                      _buildExpiryAndDescription(),
                      SizedBox(height: 30.h),
                      _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 20.h),
      child: Column(
        children: [
          // Top row with back button and title
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
                child: Container(
                  width: 40.w,
                  height: 40.h,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 20.sp,
                  ),
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Text(
                  'Receive',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              // Share button
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  final data = _bolt11 ?? _userProfile?.sabiUsername;
                  if (data != null) {
                    _copyToClipboard(data, 'Address');
                  }
                },
                child: Container(
                  width: 40.w,
                  height: 40.h,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    Icons.share_rounded,
                    color: AppColors.primary,
                    size: 20.sp,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
        ],
      ),
    );
  }

  

  Widget _buildQRCodeSection() {
    final displayData = _bolt11 ?? _userProfile?.sabiUsername;

    return GestureDetector(
      onTap:
          displayData != null
              ? () {
                HapticFeedback.lightImpact();
                _copyToClipboard(displayData, 'Invoice');
              }
              : null,
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24.r),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            displayData != null
                ? QrImageView(
                  data: displayData,
                  version: QrVersions.auto,
                  size: 220.w,
                  backgroundColor: Colors.white,
                  padding: EdgeInsets.all(8.r),
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                  errorStateBuilder: (context, error) {
                    return _buildQRPlaceholder('QR Error');
                  },
                )
                : _buildQRPlaceholder('Select amount to create invoice'),
            if (displayData != null) ...[
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.touch_app_rounded,
                      color: AppColors.primary,
                      size: 14.sp,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      'Tap to copy',
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
      ),
    );
  }

  Widget _buildQRPlaceholder(String message) {
    return Container(
      width: 220.w,
      height: 220.w,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.qr_code_2_rounded, size: 48.sp, color: Colors.grey[400]),
            SizedBox(height: 12.h),
            Text(
              message,
              style: TextStyle(color: Colors.grey[500], fontSize: 12.sp),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildUserInfo() {
    // Use profile-style lightning address card (copy + display only)
    final username = _userProfile?.sabiUsername ?? '@sabi/user';
    final displayAddress = username;

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _copyToClipboard(displayAddress, 'Lightning address'),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bolt_rounded, color: AppColors.primary, size: 20.sp),
                  SizedBox(width: 8.w),
                  Flexible(
                    child: Text(
                      displayAddress,
                      style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  IconButton(
                    onPressed: () => _copyToClipboard(displayAddress, 'Lightning address'),
                    icon: Icon(Icons.copy_rounded, color: AppColors.primary, size: 18.sp),
                    tooltip: 'Copy',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  

  Widget _buildAmountSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Amount (sats)',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 12.h),
        // Custom amount input
        Container(
          height: 52.h,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: TextField(
            keyboardType: TextInputType.number,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'Enter custom amount',
              hintStyle: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Icon(
                Icons.edit_rounded,
                color: AppColors.textSecondary,
                size: 20.sp,
              ),
              suffixText: 'sats',
              suffixStyle: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14.sp,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 14.h,
              ),
            ),
            onChanged: (value) {
              final amount = int.tryParse(value.replaceAll(',', ''));
              setState(() {
                selectedAmount = amount;
              });
            },
          ),
        ),
        SizedBox(height: 16.h),
        // Preset amounts using AmountChips
        AmountChips(
          amounts: presetAmounts,
          selectedAmount: selectedAmount,
          currency: '',
          formatAmount: (amount) => '${_formatAmountShort(amount)} sats',
          onSelected: (amount) {
            HapticFeedback.selectionClick();
            setState(() {
              selectedAmount = amount;
            });
          },
        ),
      ],
    );
  }

  String _formatAmountShort(int amount) {
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}k';
    }
    return amount.toString();
  }

  Widget _buildExpiryAndDescription() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: TextField(
        controller: _descriptionController,
        style: TextStyle(color: Colors.white, fontSize: 14.sp),
        maxLines: 2,
        minLines: 1,
        decoration: InputDecoration(
          hintText: 'Add a description (optional)',
          hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp),
          prefixIcon: Icon(
            Icons.note_alt_outlined,
            color: AppColors.textSecondary,
            size: 20.sp,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 14.h,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final hasInvoice = _bolt11 != null;
    final canCreate = selectedAmount != null && selectedAmount! > 0;

    return Column(
      children: [
        // Create Invoice button (primary action)
        SizedBox(
          width: double.infinity,
          height: 56.h,
          child: ElevatedButton(
            onPressed:
                !canCreate || _creating
                    ? null
                    : () {
                      HapticFeedback.mediumImpact();
                      _createInvoice();
                    },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
            ),
            child:
                _creating
                    ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20.w,
                          height: 20.h,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.w,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Text(
                          'Creating Invoice...',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                    : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_rounded, size: 20.sp),
                        SizedBox(width: 8.w),
                        Text(
                          hasInvoice ? 'Create New Invoice' : 'Create Invoice',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
          ),
        ),
        // Share button (only shown when invoice exists)
        if (hasInvoice) ...[
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            height: 52.h,
            child: OutlinedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                _copyToClipboard(_bolt11!, 'Invoice');
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.copy_rounded, size: 18.sp),
                  SizedBox(width: 8.w),
                  Text(
                    'Copy Invoice',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        // Hint when no amount selected
        if (!canCreate && !hasInvoice) ...[
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: AppColors.textSecondary,
                size: 16.sp,
              ),
              SizedBox(width: 6.w),
              Text(
                'Select an amount to create an invoice',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.sp,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _createInvoice() async {
    if (selectedAmount == null) return;
    setState(() => _creating = true);
    try {
      final username = _userProfile?.sabiUsername ?? '@sabi/user';
      final result = await BreezSparkService.createInvoice(
        sats: selectedAmount!,
        memo:
            _descriptionController.text.isEmpty
                ? 'Payment to $username'
                : _descriptionController.text,
      );

      if (!mounted) return;

      setState(() {
        // Result is already the bolt11 string
        _bolt11 = result;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invoice created successfully'),
          backgroundColor: AppColors.surface,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create invoice: $e'),
          backgroundColor: AppColors.surface,
        ),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  // Nostr receive UI removed; no nostr-specific widgets here anymore.
}
