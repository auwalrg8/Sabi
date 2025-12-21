import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';
import 'package:sabi_wallet/services/profile_service.dart';
import 'package:sabi_wallet/features/nostr/nostr_service.dart';
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
  String _selectedTab = 'lightning';
  UserProfile? _userProfile;
  String? _nostrNpub;
  bool _isLoadingNostr = false;

  final List<int> presetAmounts = [1000, 5000, 10000, 50000, 100000];
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
    _loadNostrNpub();
  }

  Future<void> _loadUserProfile() async {
    final profile = await ProfileService.getProfile();
    if (mounted) {
      setState(() => _userProfile = profile);
    }
  }

  Future<void> _loadNostrNpub() async {
    setState(() => _isLoadingNostr = true);
    try {
      await NostrService.init();
      final npub = await NostrService.getNpub();
      if (mounted) {
        setState(() {
          _nostrNpub = npub;
          _isLoadingNostr = false;
        });
      }
    } catch (e) {
      print('❌ Error loading Nostr npub: $e');
      if (mounted) {
        setState(() => _isLoadingNostr = false);
      }
    }
  }

  Future<void> _registerLightningAddress() async {
    if (_userProfile == null || _isSyncingLightningAddress) return;
    setState(() => _isSyncingLightningAddress = true);
    try {
      await BreezSparkService.registerLightningAddress(
        username: _userProfile!.username,
        description: _userProfile!.lightningAddressDescription,
      );
      await BreezSparkService.fetchLightningAddress();
      await _loadUserProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lightning address registered'),
          backgroundColor: AppColors.accentGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to register address: $e'),
          backgroundColor: AppColors.surface,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSyncingLightningAddress = false);
    }
  }

  Future<void> _refreshLightningAddress() async {
    if (_userProfile == null || _isSyncingLightningAddress) return;
    setState(() => _isSyncingLightningAddress = true);
    try {
      await BreezSparkService.fetchLightningAddress();
      await _loadUserProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lightning address refreshed'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to refresh address: $e'),
          backgroundColor: AppColors.surface,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSyncingLightningAddress = false);
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
                    if (_selectedTab == 'lightning') ...[
                      _buildQRCodeSection(),
                      SizedBox(height: 30.h),
                      _buildUserInfo(),
                      SizedBox(height: 4.h),
                      _buildAmountSelector(),
                      SizedBox(height: 30.h),
                      _buildExpiryAndDescription(),
                      SizedBox(height: 30.h),
                      _buildActionButtons(),
                    ] else if (_selectedTab == 'nostr') ...[
                      _buildNostrReceiveSection(),
                    ],
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
    return Padding(
      padding: EdgeInsets.fromLTRB(30.w, 20.h, 30.w, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(Icons.arrow_back, color: Colors.white, size: 24.sp),
              ),
              Text(
                'Receive',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    isStaticMode = !isStaticMode;
                  });
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: isStaticMode ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          _buildTabSelector(),
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      height: 44.h,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 'lightning'),
              child: Container(
                height: 44.h,
                decoration: BoxDecoration(
                  color:
                      _selectedTab == 'lightning'
                          ? AppColors.primary
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Center(
                  child: Text(
                    '⚡ ${AppLocalizations.of(context)!.lightning}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight:
                          _selectedTab == 'lightning'
                              ? FontWeight.w600
                              : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 'nostr'),
              child: Container(
                height: 44.h,
                decoration: BoxDecoration(
                  color:
                      _selectedTab == 'nostr'
                          ? AppColors.primary
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Center(
                  child: Text(
                    'Nostr',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight:
                          _selectedTab == 'nostr'
                              ? FontWeight.w600
                              : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRCodeSection() {
    final displayData = _bolt11;

    return Container(
      height: 315.h,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.primary, width: 5.w),
      ),
      child: Center(
        child:
            displayData != null
                ? Image.network(
                  'https://api.qrserver.com/v1/create-qr-code/?size=240x240&data=${Uri.encodeComponent(displayData)}',
                  width: 255.w,
                  height: 275.h,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 245.w,
                      height: 240.h,
                      color: Colors.grey[330],
                      child: Center(
                        child: Icon(
                          Icons.error_outline,
                          size: 48.sp,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  },
                )
                : Container(
                  width: 240.w,
                  height: 240.h,
                  color: Colors.grey[330],
                  child: Center(
                    child: Text(
                      'Create invoice to show QR',
                      style: TextStyle(color: Colors.grey, fontSize: 12.sp),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
      ),
    );
  }

  Widget _buildUserInfo() {
    final username = _userProfile?.sabiUsername ?? '@sabi/user';
    final registered = _userProfile?.hasLightningAddress ?? false;
    final description =
      _userProfile?.lightningAddressDescription ??
      'Share $username to receive Lightning payments instantly.';

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 40.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  username,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 8.w),
              GestureDetector(
                onTap: () => _copyToClipboard(username, 'Lightning address'),
                child: Container(
                  width: 34.w,
                  height: 34.h,
                  padding: EdgeInsets.all(8.h),
                  child: Icon(
                    Icons.copy,
                    color: AppColors.primary,
                    size: 18.sp,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Text(
            description,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12.sp,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(height: 8.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              registered ? Icons.check_circle : Icons.lightbulb,
              color: registered ? AppColors.accentGreen : AppColors.primary,
              size: 18.sp,
            ),
            SizedBox(width: 6.w),
            Text(
              registered
                  ? 'Lightning address registered'
                  : 'Register to receive via Lightning address',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 40.w),
          child: SizedBox(
            width: double.infinity,
            child:
                registered
                    ? OutlinedButton(
                      onPressed:
                          _isSyncingLightningAddress
                              ? null
                              : _refreshLightningAddress,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                      ),
                      child: Text(
                        _isSyncingLightningAddress
                            ? 'Refreshing…'
                            : 'Refresh LN address',
                        style: const TextStyle(color: AppColors.primary),
                      ),
                    )
                    : ElevatedButton(
                      onPressed:
                          _isSyncingLightningAddress
                              ? null
                              : _registerLightningAddress,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                      ),
                      child: Text(
                        _isSyncingLightningAddress
                            ? 'Registering…'
                            : 'Register Lightning address',
                        style: const TextStyle(color: AppColors.surface),
                      ),
                    ),
          ),
        ),
      ],
    );
  }

  Widget _buildAmountSelector() {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.w,
      alignment: WrapAlignment.start,
      children: [
        Container(
          width: 120.w,
          height: 40.h,
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(color: Colors.transparent),
          ),
          child: TextField(
            keyboardType: TextInputType.number,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.w400,
            ),
            decoration: InputDecoration(
              hintText: 'Custom',
              hintStyle: TextStyle(
                color: Color(0xFFCCCCCC),
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 10.h),
            ),
            onChanged: (value) {
              final amount = int.tryParse(value.replaceAll(',', ''));
              setState(() {
                selectedAmount = amount;
              });
            },
          ),
        ),
        ...presetAmounts.map((amount) => _buildAmountButton(amount)),
      ],
    );
  }

  Widget _buildAmountButton(int amount) {
    final isSelected = selectedAmount == amount;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedAmount = isSelected ? null : amount;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 13.w, vertical: 9.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Text(
          '₦ ${_formatAmount(amount)}',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String _formatAmount(int amount) {
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)},${(amount % 1000).toString().padLeft(3, '0')}';
    }
    return amount.toString();
  }

  Widget _buildExpiryAndDescription() {
    return Column(
      children: [
        SizedBox(height: 10.h),
        SizedBox(
          width: double.infinity,
          child: Container(
            height: 48.h,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: Colors.transparent),
            ),
            child: TextField(
              controller: _descriptionController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Describe the payment you want to receive',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50.h,
          child: ElevatedButton(
            onPressed:
                _bolt11 == null
                    ? null
                    : () => _copyToClipboard(_bolt11!, 'Invoice'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'Share Invoice',
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500),
            ),
          ),
        ),
        if (selectedAmount != null) ...[
          SizedBox(height: 17.h),
          SizedBox(
            width: double.infinity,
            height: 52.h,
            child: OutlinedButton(
              onPressed: _creating ? null : _createInvoice,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary),
                backgroundColor: Colors.transparent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
              child: Text(
                _creating ? 'Creating…' : 'Create Invoice',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
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

  Widget _buildNostrReceiveSection() {
    if (_isLoadingNostr) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Text(
          'Your Nostr npub:',
          style: TextStyle(color: Colors.white70, fontSize: 14.sp),
        ),
        SelectableText(
          _nostrNpub ?? 'Not set',
          style: TextStyle(color: Colors.white, fontSize: 16.sp),
        ),
        const SizedBox(height: 24),
        if (_nostrNpub != null)
          Image.network(
            'https://api.qrserver.com/v1/create-qr-code/?size=240x240&data=${Uri.encodeComponent(_nostrNpub!)}',
            width: 200.w,
            height: 200.h,
            fit: BoxFit.cover,
          ),
      ],
    );
  }
}
