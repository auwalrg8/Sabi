import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sabi_wallet/features/p2p/data/payment_method_model.dart';
import 'package:sabi_wallet/features/p2p/data/models/payment_method_international.dart';
import 'package:sabi_wallet/features/p2p/providers/p2p_providers.dart';
import 'package:sabi_wallet/features/p2p/providers/nip99_p2p_providers.dart';
import 'package:sabi_wallet/features/p2p/data/p2p_offer_model.dart';
import 'package:sabi_wallet/services/nostr_service.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';
import 'package:sabi_wallet/features/p2p/utils/p2p_logger.dart';
import 'package:sabi_wallet/services/nostr/models/nostr_offer.dart';

/// P2P Create Offer Screen - Binance/NoOnes inspired
class P2PCreateOfferScreen extends ConsumerStatefulWidget {
  const P2PCreateOfferScreen({super.key});

  @override
  ConsumerState<P2PCreateOfferScreen> createState() =>
      _P2PCreateOfferScreenState();
}

class _P2PCreateOfferScreenState extends ConsumerState<P2PCreateOfferScreen> {
  final _formKey = GlobalKey<FormState>();
  final formatter = NumberFormat('#,###');

  bool _isSellOffer = true;
  double _marginPercent = 1.5;
  int _minLimit = 10000;
  int _maxLimit = 1000000;
  bool _useTradeCode = false; // Optional trade code verification
  bool _openToProfileSharing = false; // Allow trust profile sharing
  final Set<String> _selectedPaymentMethods = {};

  /// Map of payment method ID to account details entered by user
  final Map<String, String> _paymentAccountDetails = {};

  /// Controllers for each payment method's account details input
  final Map<String, TextEditingController> _accountDetailsControllers = {};
  final TextEditingController _minController = TextEditingController(
    text: '10,000',
  );
  final TextEditingController _maxController = TextEditingController(
    text: '1,000,000',
  );
  final TextEditingController _instructionsController = TextEditingController();
  bool _isSubmitting = false;
  int _currentStep = 0;
  bool _hasNostrKeys = false;
  bool _isCheckingNostr = true;

  @override
  void initState() {
    super.initState();
    _checkNostrIdentity();
  }

  Future<void> _checkNostrIdentity() async {
    final profileService = ref.read(nostrP2PProfileProvider);
    // Force re-check to pick up any keys set up via Profile screen
    await profileService.init(force: true);

    if (mounted) {
      setState(() {
        _hasNostrKeys = profileService.hasKeys;
        _isCheckingNostr = false;
      });

      // If no Nostr keys, show setup dialog
      if (!_hasNostrKeys) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showNostrSetupDialog();
        });
      }
    }
  }

  Future<void> _showNostrSetupDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF111128),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.electric_bolt,
                  color: const Color(0xFFF7931A),
                  size: 24.sp,
                ),
                SizedBox(width: 8.w),
                Text(
                  'Nostr Setup Required',
                  style: TextStyle(color: Colors.white, fontSize: 18.sp),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'To create P2P offers, you need to set up your Nostr identity first.',
                  style: TextStyle(
                    color: const Color(0xFFA1A1B2),
                    fontSize: 14.sp,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  'Your offers will be published to Nostr relays and visible to other users.',
                  style: TextStyle(
                    color: const Color(0xFFA1A1B2),
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: const Color(0xFFA1A1B2),
                    fontSize: 14.sp,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF7931A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: Text(
                  'Set Up Nostr',
                  style: TextStyle(color: Colors.white, fontSize: 14.sp),
                ),
              ),
            ],
          ),
    );

    if (result == true) {
      // Navigate to profile screen to set up Nostr
      if (mounted) {
        Navigator.pop(context);
        // User can set up Nostr in Profile screen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please set up your Nostr identity in Profile'),
            backgroundColor: const Color(0xFFF7931A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } else {
      // User cancelled, go back
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    _instructionsController.dispose();
    // Dispose all account details controllers
    for (final controller in _accountDetailsControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while checking Nostr identity
    if (_isCheckingNostr) {
      return Scaffold(
        backgroundColor: const Color(0xFF0C0C1A),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFFF7931A)),
              ),
              SizedBox(height: 16.h),
              Text(
                'Checking Nostr identity...',
                style: TextStyle(
                  color: const Color(0xFFA1A1B2),
                  fontSize: 14.sp,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final exchangeRates = ref.watch(exchangeRatesProvider);
    final marketRate = exchangeRates['BTC_NGN'] ?? 131448939.22;
    final yourRate = marketRate * (1 + _marginPercent / 100);

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C0C1A),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20.sp,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Create Offer',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: Column(
        children: [
          // Progress Indicator
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: List.generate(3, (index) {
                final isActive = index <= _currentStep;
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 4.w),
                    height: 4.h,
                    decoration: BoxDecoration(
                      color:
                          isActive
                              ? const Color(0xFFF7931A)
                              : const Color(0xFF2A2A3E),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                );
              }),
            ),
          ),
          SizedBox(height: 16.h),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_currentStep == 0) ...[
                      _buildStep1OfferType(),
                    ] else if (_currentStep == 1) ...[
                      _buildStep2Pricing(marketRate, yourRate),
                    ] else ...[
                      _buildStep3PaymentMethods(),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Bottom Navigation
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: const BoxDecoration(
              color: Color(0xFF111128),
              border: Border(top: BorderSide(color: Color(0xFF2A2A3E))),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _currentStep--),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF2A2A3E)),
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                        ),
                        child: Text('Back', style: TextStyle(fontSize: 16.sp)),
                      ),
                    ),
                  if (_currentStep > 0) SizedBox(width: 12.w),
                  Expanded(
                    flex: _currentStep > 0 ? 2 : 1,
                    child: ElevatedButton(
                      onPressed:
                          _currentStep == 2
                              ? (_selectedPaymentMethods.isNotEmpty
                                  ? _submitOffer
                                  : null)
                              : () => setState(() => _currentStep++),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF7931A),
                        disabledBackgroundColor: const Color(0xFF2A2A3E),
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                      ),
                      child:
                          _isSubmitting
                              ? SizedBox(
                                width: 24.w,
                                height: 24.h,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    Colors.white,
                                  ),
                                ),
                              )
                              : Text(
                                _currentStep == 2 ? 'Create Offer' : 'Continue',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1OfferType() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What do you want to do?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          'Choose whether you want to sell or buy Bitcoin',
          style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 14.sp),
        ),
        SizedBox(height: 24.h),

        // Sell/Buy Toggle Cards
        Row(
          children: [
            Expanded(
              child: _OfferTypeCard(
                icon: Icons.sell,
                title: 'Sell BTC',
                subtitle: 'Get Naira for your Bitcoin',
                isSelected: _isSellOffer,
                color: const Color(0xFFFF6B6B),
                onTap: () => setState(() => _isSellOffer = true),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _OfferTypeCard(
                icon: Icons.shopping_cart,
                title: 'Buy BTC',
                subtitle: 'Spend Naira to get Bitcoin',
                isSelected: !_isSellOffer,
                color: const Color(0xFF00FFB2),
                onTap: () => setState(() => _isSellOffer = false),
              ),
            ),
          ],
        ),
        SizedBox(height: 32.h),

        // Trade Limits
        Text(
          'Trade Limits',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: _LimitInput(
                label: 'Minimum',
                controller: _minController,
                onChanged: (value) {
                  final clean = value.replaceAll(',', '');
                  _minLimit = int.tryParse(clean) ?? 10000;
                },
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _LimitInput(
                label: 'Maximum',
                controller: _maxController,
                onChanged: (value) {
                  final clean = value.replaceAll(',', '');
                  _maxLimit = int.tryParse(clean) ?? 1000000;
                },
              ),
            ),
          ],
        ),
        SizedBox(height: 24.h),

        // Quick Limit Buttons
        Text(
          'Quick Set',
          style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 13.sp),
        ),
        SizedBox(height: 8.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: [
            _QuickLimitChip(
              label: '₦10K - ₦100K',
              onTap: () => _setLimits(10000, 100000),
            ),
            _QuickLimitChip(
              label: '₦50K - ₦500K',
              onTap: () => _setLimits(50000, 500000),
            ),
            _QuickLimitChip(
              label: '₦100K - ₦1M',
              onTap: () => _setLimits(100000, 1000000),
            ),
            _QuickLimitChip(
              label: '₦500K - ₦5M',
              onTap: () => _setLimits(500000, 5000000),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep2Pricing(double marketRate, double yourRate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Set Your Pricing',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          'Adjust your margin above or below market rate',
          style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 14.sp),
        ),
        SizedBox(height: 24.h),

        // Market Rate Info
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: const Color(0xFF111128),
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7931A).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.currency_bitcoin,
                  color: const Color(0xFFF7931A),
                  size: 24.sp,
                ),
              ),
              SizedBox(width: 16.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Market Rate',
                    style: TextStyle(
                      color: const Color(0xFFA1A1B2),
                      fontSize: 12.sp,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '₦${_formatRate(marketRate)}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 24.h),

        // Margin Slider
        Text(
          'Your Margin',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 12.h),
        Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: const Color(0xFF111128),
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _marginPercent >= 0 ? '+' : '',
                    style: TextStyle(
                      color:
                          _marginPercent >= 0
                              ? const Color(0xFF00FFB2)
                              : const Color(0xFFFF6B6B),
                      fontSize: 32.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_marginPercent.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color:
                          _marginPercent >= 0
                              ? const Color(0xFF00FFB2)
                              : const Color(0xFFFF6B6B),
                      fontSize: 32.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFFF7931A),
                  inactiveTrackColor: const Color(0xFF2A2A3E),
                  thumbColor: const Color(0xFFF7931A),
                  overlayColor: const Color(0xFFF7931A).withValues(alpha: 0.2),
                  trackHeight: 8.h,
                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: 12.r),
                ),
                child: Slider(
                  value: _marginPercent,
                  min: -5,
                  max: 10,
                  divisions: 30,
                  onChanged: (value) {
                    setState(() => _marginPercent = value);
                  },
                ),
              ),
              SizedBox(height: 8.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '-5%',
                    style: TextStyle(
                      color: const Color(0xFFA1A1B2),
                      fontSize: 12.sp,
                    ),
                  ),
                  Text(
                    '+10%',
                    style: TextStyle(
                      color: const Color(0xFFA1A1B2),
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 24.h),

        // Your Rate Preview
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: const Color(0xFF00FFB2).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: const Color(0xFF00FFB2).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Rate',
                style: TextStyle(
                  color: const Color(0xFFA1A1B2),
                  fontSize: 14.sp,
                ),
              ),
              Text(
                '₦${_formatRate(yourRate)}',
                style: TextStyle(
                  color: const Color(0xFF00FFB2),
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 24.h),

        // Trade Code Toggle (optional extra verification)
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: const Color(0xFF111128),
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Row(
            children: [
              Icon(Icons.security, color: const Color(0xFFA1A1B2), size: 24.sp),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trade Code Verification',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Add extra security with split 6-digit code',
                      style: TextStyle(
                        color: const Color(0xFFA1A1B2),
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _useTradeCode,
                onChanged: (value) => setState(() => _useTradeCode = value),
                activeThumbColor: const Color(0xFFF7931A),
                activeTrackColor: const Color(
                  0xFFF7931A,
                ).withValues(alpha: 0.3),
                inactiveThumbColor: const Color(0xFFA1A1B2),
                inactiveTrackColor: const Color(0xFF2A2A3E),
              ),
            ],
          ),
        ),

        // Trade Code Info
        if (_useTradeCode) ...[
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: const Color(0xFF4FC3F7).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: const Color(0xFF4FC3F7).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  color: const Color(0xFF4FC3F7),
                  size: 18.sp,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'A 6-digit code will be generated. You share first 3 digits, buyer shares last 3. Both must match for trade completion.',
                    style: TextStyle(
                      color: const Color(0xFF4FC3F7),
                      fontSize: 12.sp,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        SizedBox(height: 16.h),

        // Profile Sharing Toggle
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: const Color(0xFF111128),
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FFB2).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.handshake_outlined,
                  color: const Color(0xFF00FFB2),
                  size: 20.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Open to Trust Sharing',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Allow traders to request social profile exchange',
                      style: TextStyle(
                        color: const Color(0xFFA1A1B2),
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _openToProfileSharing,
                onChanged:
                    (value) => setState(() => _openToProfileSharing = value),
                activeThumbColor: const Color(0xFF00FFB2),
                activeTrackColor: const Color(
                  0xFF00FFB2,
                ).withValues(alpha: 0.3),
                inactiveThumbColor: const Color(0xFFA1A1B2),
                inactiveTrackColor: const Color(0xFF2A2A3E),
              ),
            ],
          ),
        ),

        // Profile Sharing Info
        if (_openToProfileSharing) ...[
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: const Color(0xFF00FFB2).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: const Color(0xFF00FFB2).withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      color: const Color(0xFF00FFB2),
                      size: 18.sp,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Build Trust Without KYC',
                      style: TextStyle(
                        color: const Color(0xFF00FFB2),
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Text(
                  '• Traders can request to share social profiles\n'
                  '• You control what to share per trade\n'
                  '• Profiles never stored or shown publicly',
                  style: TextStyle(
                    color: const Color(0xFFA1A1B2),
                    fontSize: 12.sp,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStep3PaymentMethods() {
    final paymentMethods = ref.watch(paymentMethodsProvider);
    final internationalMethods = PaymentMethods.getAllMethods();

    // Group international methods by primary region (first region in list)
    final methodsByRegion = <PaymentRegion, List<InternationalPaymentMethod>>{};
    for (final method in internationalMethods) {
      if (method.regions.isNotEmpty) {
        final primaryRegion = method.regions.first;
        methodsByRegion.putIfAbsent(primaryRegion, () => []).add(method);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Methods',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          'Select the payment methods you accept',
          style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 14.sp),
        ),
        SizedBox(height: 24.h),

        // Nigerian Payment Methods (from existing provider)
        if (paymentMethods.isNotEmpty) ...[
          _PaymentCategoryHeader(
            title: '🇳🇬 Nigerian Methods',
            subtitle: 'Local bank transfers and mobile money',
          ),
          SizedBox(height: 12.h),
          ...paymentMethods.map((method) {
            final isSelected = _selectedPaymentMethods.contains(method.id);
            return _PaymentMethodTile(
              id: method.id,
              name: method.name,
              subtitle:
                  method.type.name
                      .replaceAllMapped(
                        RegExp(r'([A-Z])'),
                        (m) => ' ${m.group(1)}',
                      )
                      .trim(),
              icon: _getPaymentMethodIcon(method.type),
              isSelected: isSelected,
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedPaymentMethods.remove(method.id);
                  } else {
                    _selectedPaymentMethods.add(method.id);
                  }
                });
              },
            );
          }),
          SizedBox(height: 24.h),
        ],

        // International Payment Methods by Region
        ...methodsByRegion.entries.map((entry) {
          final region = entry.key;
          final methods = entry.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PaymentCategoryHeader(
                title: '${_getRegionEmoji(region)} ${_getRegionName(region)}',
                subtitle: _getRegionSubtitle(region),
              ),
              SizedBox(height: 12.h),
              ...methods.map((method) {
                final isSelected = _selectedPaymentMethods.contains(method.id);
                return _PaymentMethodTile(
                  id: method.id,
                  name: method.name,
                  subtitle: '~${method.estimatedMinutes} min',
                  icon: Icons.payment,
                  isSelected: isSelected,
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedPaymentMethods.remove(method.id);
                      } else {
                        _selectedPaymentMethods.add(method.id);
                      }
                    });
                  },
                );
              }),
              SizedBox(height: 16.h),
            ],
          );
        }),

        SizedBox(height: 8.h),

        // Account Details for Selected Payment Methods
        if (_selectedPaymentMethods.isNotEmpty) ...[
          Text(
            'Account Details',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Enter your account details for each payment method. Buyers will see this information when trading.',
            style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 13.sp),
          ),
          SizedBox(height: 12.h),
          ..._selectedPaymentMethods.map((methodId) {
            // Get method name for display
            final paymentMethods = ref.read(paymentMethodsProvider);
            final internationalMethods = PaymentMethods.getAllMethods();
            String methodName = methodId;
            String placeholder = 'Enter account details...';

            // Find in Nigerian methods
            final nigerianMethod =
                paymentMethods.where((m) => m.id == methodId).firstOrNull;
            if (nigerianMethod != null) {
              methodName = nigerianMethod.name;
              if (nigerianMethod.type == PaymentMethodType.bankTransfer) {
                placeholder = 'e.g., GTBank 0123456789 - John Doe';
              } else if (nigerianMethod.type == PaymentMethodType.mobileMoney) {
                placeholder = 'e.g., 08012345678 - John Doe';
              } else if (nigerianMethod.type == PaymentMethodType.giftCard) {
                placeholder = 'e.g., Amazon email: john@email.com';
              } else {
                placeholder = 'e.g., Location: Lekki Phase 1, Lagos';
              }
            } else {
              // Find in international methods
              final intlMethod =
                  internationalMethods
                      .where((m) => m.id == methodId)
                      .firstOrNull;
              if (intlMethod != null) {
                methodName = intlMethod.name;
                placeholder = 'Enter ${intlMethod.name} account details...';
              }
            }

            // Create controller if not exists
            _accountDetailsControllers.putIfAbsent(
              methodId,
              () => TextEditingController(
                text: _paymentAccountDetails[methodId] ?? '',
              ),
            );

            return Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF111128),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: const Color(0xFF2A2A3E)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet,
                          color: const Color(0xFFF7931A),
                          size: 18.sp,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          methodName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    TextField(
                      controller: _accountDetailsControllers[methodId],
                      onChanged: (value) {
                        _paymentAccountDetails[methodId] = value;
                      },
                      style: TextStyle(color: Colors.white, fontSize: 14.sp),
                      decoration: InputDecoration(
                        hintText: placeholder,
                        hintStyle: TextStyle(
                          color: const Color(0xFF6B6B80),
                          fontSize: 14.sp,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0C0C1A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 10.h,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          SizedBox(height: 16.h),
        ],

        // Payment Instructions
        Text(
          'Additional Instructions (Optional)',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 12.h),
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: const Color(0xFF111128),
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: TextField(
            controller: _instructionsController,
            maxLines: 4,
            style: TextStyle(color: Colors.white, fontSize: 14.sp),
            decoration: InputDecoration(
              hintText:
                  'Add any special instructions for buyers (e.g., preferred transfer times, notes)...',
              hintStyle: TextStyle(
                color: const Color(0xFF6B6B80),
                fontSize: 14.sp,
              ),
              border: InputBorder.none,
            ),
          ),
        ),
        SizedBox(height: 16.h),

        // Selected Summary
        if (_selectedPaymentMethods.isNotEmpty)
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: const Color(0xFF00FFB2).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: const Color(0xFF00FFB2),
                  size: 20.sp,
                ),
                SizedBox(width: 8.w),
                Text(
                  '${_selectedPaymentMethods.length} payment method(s) selected',
                  style: TextStyle(
                    color: const Color(0xFF00FFB2),
                    fontSize: 13.sp,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _setLimits(int min, int max) {
    setState(() {
      _minLimit = min;
      _maxLimit = max;
      _minController.text = formatter.format(min);
      _maxController.text = formatter.format(max);
    });
  }

  IconData _getPaymentMethodIcon(PaymentMethodType type) {
    switch (type) {
      case PaymentMethodType.bankTransfer:
        return Icons.account_balance;
      case PaymentMethodType.mobileMoney:
        return Icons.phone_android;
      case PaymentMethodType.cash:
        return Icons.money;
      case PaymentMethodType.giftCard:
        return Icons.card_giftcard;
      case PaymentMethodType.wallet:
        return Icons.account_balance_wallet;
      case PaymentMethodType.other:
        return Icons.more_horiz;
    }
  }

  String _getRegionEmoji(PaymentRegion region) {
    switch (region) {
      case PaymentRegion.nigeria:
        return '🇳🇬';
      case PaymentRegion.global:
        return '🌍';
      case PaymentRegion.usa:
        return '🇺🇸';
      case PaymentRegion.europe:
        return '🇪🇺';
      case PaymentRegion.uk:
        return '🇬🇧';
      case PaymentRegion.india:
        return '🇮🇳';
      case PaymentRegion.brazil:
        return '🇧🇷';
      case PaymentRegion.canada:
        return '🇨🇦';
      case PaymentRegion.africa:
        return '🌍';
      case PaymentRegion.latinAmerica:
        return '🌎';
      case PaymentRegion.asia:
        return '🌏';
    }
  }

  String _getRegionName(PaymentRegion region) {
    switch (region) {
      case PaymentRegion.nigeria:
        return 'Nigeria';
      case PaymentRegion.global:
        return 'Global';
      case PaymentRegion.usa:
        return 'United States';
      case PaymentRegion.europe:
        return 'Europe';
      case PaymentRegion.uk:
        return 'United Kingdom';
      case PaymentRegion.india:
        return 'India';
      case PaymentRegion.brazil:
        return 'Brazil';
      case PaymentRegion.canada:
        return 'Canada';
      case PaymentRegion.africa:
        return 'Africa';
      case PaymentRegion.latinAmerica:
        return 'Latin America';
      case PaymentRegion.asia:
        return 'Asia';
    }
  }

  String _getRegionSubtitle(PaymentRegion region) {
    switch (region) {
      case PaymentRegion.nigeria:
        return 'Local Nigerian payment methods';
      case PaymentRegion.global:
        return 'Available worldwide';
      case PaymentRegion.usa:
        return 'US-based payment methods';
      case PaymentRegion.europe:
        return 'European payment methods';
      case PaymentRegion.uk:
        return 'UK-based payment methods';
      case PaymentRegion.india:
        return 'Indian payment methods';
      case PaymentRegion.brazil:
        return 'Brazilian payment methods';
      case PaymentRegion.canada:
        return 'Canadian payment methods';
      case PaymentRegion.africa:
        return 'Pan-African mobile money';
      case PaymentRegion.latinAmerica:
        return 'Latin American payment methods';
      case PaymentRegion.asia:
        return 'Asian payment methods';
    }
  }

  String _formatRate(double rate) {
    if (rate >= 1000000) {
      return '${(rate / 1000000).toStringAsFixed(2)}M';
    }
    return formatter.format(rate.toInt());
  }

  Future<void> _submitOffer() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPaymentMethods.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      // Check if Nostr identity is available
      final profileService = ref.read(nostrP2PProfileProvider);
      if (!profileService.hasKeys) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Please set up your Nostr identity in Profile first',
              ),
              backgroundColor: const Color(0xFFF7931A),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              action: SnackBarAction(
                label: 'Go to Profile',
                textColor: Colors.white,
                onPressed: () => Navigator.pop(context),
              ),
            ),
          );
        }
        setState(() => _isSubmitting = false);
        return;
      }

      // For sell offers, check wallet balance first
      int walletBalance = 0;
      if (_isSellOffer) {
        walletBalance = await BreezSparkService.getBalance();

        // Calculate required sats based on max limit
        // maxLimit is in NGN, convert to sats using current rate
        final exchangeRates = ref.read(exchangeRatesProvider);
        final marketRate = exchangeRates['BTC_NGN'] ?? 131448939.22;
        final btcAmount = _maxLimit / marketRate;
        final requiredSats =
            (btcAmount * 100000000).round(); // Convert BTC to sats

        if (walletBalance < requiredSats) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Insufficient balance. You have ${formatter.format(walletBalance)} sats but need ${formatter.format(requiredSats)} sats for this offer.',
                ),
                backgroundColor: const Color(0xFFFF6B6B),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                duration: const Duration(seconds: 5),
              ),
            );
          }
          setState(() => _isSubmitting = false);
          return;
        }
      }

      P2PLogger.info(
        'Offer',
        'Creating P2P offer',
        metadata: {
          'type': _isSellOffer ? 'sell' : 'buy',
          'marginPercent': _marginPercent,
          'minLimit': _minLimit,
          'maxLimit': _maxLimit,
          'useTradeCode': _useTradeCode,
          'openToProfileSharing': _openToProfileSharing,
          'paymentMethods': _selectedPaymentMethods.toList(),
          'walletBalance': walletBalance,
        },
      );

      // Build offer model
      final id = 'offer_${DateTime.now().millisecondsSinceEpoch}';
      final name = 'You';
      final exchangeRates = ref.read(exchangeRatesProvider);
      final marketRate = exchangeRates['BTC_NGN'] ?? 131448939.22;
      final pricePerBtc = marketRate * (1 + _marginPercent / 100);

      // For sell offers, set availableSats to wallet balance
      // This represents the max sats this offer can sell
      double? availableSats;
      if (_isSellOffer) {
        availableSats = walletBalance.toDouble();
      }

      // Collect payment account details from controllers
      final accountDetails = <String, String>{};
      for (final methodId in _selectedPaymentMethods) {
        final controller = _accountDetailsControllers[methodId];
        if (controller != null && controller.text.isNotEmpty) {
          accountDetails[methodId] = controller.text;
        }
      }

      final offer = P2POfferModel(
        id: id,
        name: name,
        pricePerBtc: pricePerBtc,
        paymentMethod:
            _selectedPaymentMethods.isNotEmpty
                ? _selectedPaymentMethods.first
                : 'Unknown',
        eta: '5–15 min',
        ratingPercent: 100,
        trades: 0,
        minLimit: _minLimit,
        maxLimit: _maxLimit,
        type: _isSellOffer ? OfferType.sell : OfferType.buy,
        merchant: null,
        acceptedMethods: null,
        marginPercent: _marginPercent,
        requiresKyc: _useTradeCode,
        paymentInstructions:
            _instructionsController.text.isEmpty
                ? null
                : _instructionsController.text,
        availableSats: availableSats,
        lockedSats: 0, // No sats locked initially
        paymentAccountDetails:
            accountDetails.isNotEmpty ? accountDetails : null,
      );

      // Publish to Nostr relays using NIP-99 (kind 30402) - no local storage
      try {
        // Use NIP-99 service for publishing offers
        final eventId = await ref
            .read(nip99OfferNotifierProvider.notifier)
            .publishOffer(
              type: _isSellOffer ? P2POfferType.sell : P2POfferType.buy,
              title: '${_isSellOffer ? "Selling" : "Buying"} BTC for NGN',
              description:
                  _instructionsController.text.isEmpty
                      ? 'P2P ${_isSellOffer ? "sell" : "buy"} offer via Sabi Wallet'
                      : _instructionsController.text,
              pricePerBtc: pricePerBtc,
              currency: 'NGN',
              minSats: (_minLimit / (pricePerBtc / 100000000)).round(),
              maxSats: (_maxLimit / (pricePerBtc / 100000000)).round(),
              paymentMethods: _selectedPaymentMethods.toList(),
              paymentDetails: accountDetails.isNotEmpty ? accountDetails : null,
            );

        if (eventId != null) {
          P2PLogger.info(
            'Offer',
            'Published via NIP-99 successfully: $eventId',
          );
        } else {
          // Fallback to legacy NostrService if NIP-99 fails
          try {
            await NostrService.publishOffer(offer.toJson());
            P2PLogger.info('Offer', 'Published via legacy Nostr service');
          } catch (_) {
            P2PLogger.warning('Offer', 'Failed to publish to Nostr relays');
            throw Exception('Failed to publish offer to Nostr network');
          }
        }
      } catch (e) {
        // Fallback to legacy NostrService
        try {
          await NostrService.publishOffer(offer.toJson());
          P2PLogger.info(
            'Offer',
            'Published via legacy Nostr service (fallback)',
          );
        } catch (_) {
          // non-fatal: publishing may fail if nostr not initialized
          P2PLogger.warning('Offer', 'Failed to publish to Nostr relays');
          rethrow; // Re-throw to show error to user
        }
      }

      P2PLogger.info('Offer', 'P2P offer created successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Offer created successfully!'),
            backgroundColor: const Color(0xFF00FFB2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e, stack) {
      P2PLogger.error(
        'Offer',
        'Failed to create P2P offer: $e',
        errorCode: P2PErrorCodes.tradeCreationFailed,
        stackTrace: stack,
      );
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create offer: $e'),
            backgroundColor: const Color(0xFFFF6B6B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }
}

/// Offer Type Card
class _OfferTypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _OfferTypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? color.withValues(alpha: 0.15)
                  : const Color(0xFF111128),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected ? color : const Color(0xFF2A2A3E),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? color.withValues(alpha: 0.2)
                        : const Color(0xFF1A1A2E),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? color : const Color(0xFFA1A1B2),
                size: 32.sp,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? color : Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 12.sp),
            ),
          ],
        ),
      ),
    );
  }
}

/// Limit Input
class _LimitInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final Function(String) onChanged;

  const _LimitInput({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 12.sp),
        ),
        SizedBox(height: 8.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          decoration: BoxDecoration(
            color: const Color(0xFF111128),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: const Color(0xFF2A2A3E)),
          ),
          child: Row(
            children: [
              Text(
                '₦',
                style: TextStyle(
                  color: const Color(0xFFA1A1B2),
                  fontSize: 16.sp,
                ),
              ),
              SizedBox(width: 4.w),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: Colors.white, fontSize: 16.sp),
                  decoration: const InputDecoration(border: InputBorder.none),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Quick Limit Chip
class _QuickLimitChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickLimitChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: const Color(0xFF2A2A3E)),
        ),
        child: Text(
          label,
          style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 13.sp),
        ),
      ),
    );
  }
}

/// Payment Category Header
class _PaymentCategoryHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _PaymentCategoryHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          subtitle,
          style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 12.sp),
        ),
      ],
    );
  }
}

/// Payment Method Tile (reusable)
class _PaymentMethodTile extends StatelessWidget {
  final String id;
  final String name;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentMethodTile({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: const Color(0xFF111128),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color:
                isSelected ? const Color(0xFFF7931A) : const Color(0xFF2A2A3E),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 22.w,
              height: 22.h,
              decoration: BoxDecoration(
                color:
                    isSelected ? const Color(0xFFF7931A) : Colors.transparent,
                borderRadius: BorderRadius.circular(5.r),
                border: Border.all(
                  color:
                      isSelected
                          ? const Color(0xFFF7931A)
                          : const Color(0xFFA1A1B2),
                  width: 2,
                ),
              ),
              child:
                  isSelected
                      ? Icon(Icons.check, color: Colors.white, size: 14.sp)
                      : null,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: const Color(0xFFA1A1B2),
                      fontSize: 11.sp,
                    ),
                  ),
                ],
              ),
            ),
            Icon(icon, color: const Color(0xFFA1A1B2), size: 20.sp),
          ],
        ),
      ),
    );
  }
}
