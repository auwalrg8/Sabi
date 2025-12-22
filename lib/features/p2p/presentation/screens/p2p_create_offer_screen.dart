import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sabi_wallet/features/p2p/data/payment_method_model.dart';
import 'package:sabi_wallet/features/p2p/providers/p2p_providers.dart';

/// P2P Create Offer Screen - Binance/NoOnes inspired
class P2PCreateOfferScreen extends ConsumerStatefulWidget {
  const P2PCreateOfferScreen({super.key});

  @override
  ConsumerState<P2PCreateOfferScreen> createState() => _P2PCreateOfferScreenState();
}

class _P2PCreateOfferScreenState extends ConsumerState<P2PCreateOfferScreen> {
  final _formKey = GlobalKey<FormState>();
  final formatter = NumberFormat('#,###');

  bool _isSellOffer = true;
  double _marginPercent = 1.5;
  int _minLimit = 10000;
  int _maxLimit = 1000000;
  bool _requiresKyc = false;
  final Set<String> _selectedPaymentMethods = {};
  final TextEditingController _minController = TextEditingController(text: '10,000');
  final TextEditingController _maxController = TextEditingController(text: '1,000,000');
  final TextEditingController _instructionsController = TextEditingController();
  bool _isSubmitting = false;
  int _currentStep = 0;

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exchangeRates = ref.watch(exchangeRatesProvider);
    final marketRate = exchangeRates['BTC_NGN'] ?? 131448939.22;
    final yourRate = marketRate * (1 + _marginPercent / 100);

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C0C1A),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20.sp),
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
                      color: isActive
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
              border: Border(
                top: BorderSide(color: Color(0xFF2A2A3E)),
              ),
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
                        child: Text(
                          'Back',
                          style: TextStyle(fontSize: 16.sp),
                        ),
                      ),
                    ),
                  if (_currentStep > 0) SizedBox(width: 12.w),
                  Expanded(
                    flex: _currentStep > 0 ? 2 : 1,
                    child: ElevatedButton(
                      onPressed: _currentStep == 2
                          ? (_selectedPaymentMethods.isNotEmpty ? _submitOffer : null)
                          : () => setState(() => _currentStep++),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF7931A),
                        disabledBackgroundColor: const Color(0xFF2A2A3E),
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                      ),
                      child: _isSubmitting
                          ? SizedBox(
                              width: 24.w,
                              height: 24.h,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
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
          style: TextStyle(
            color: const Color(0xFFA1A1B2),
            fontSize: 14.sp,
          ),
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
          style: TextStyle(
            color: const Color(0xFFA1A1B2),
            fontSize: 13.sp,
          ),
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
          style: TextStyle(
            color: const Color(0xFFA1A1B2),
            fontSize: 14.sp,
          ),
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
                  color: const Color(0xFFF7931A).withOpacity(0.2),
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
                      color: _marginPercent >= 0
                          ? const Color(0xFF00FFB2)
                          : const Color(0xFFFF6B6B),
                      fontSize: 32.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_marginPercent.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: _marginPercent >= 0
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
                  overlayColor: const Color(0xFFF7931A).withOpacity(0.2),
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
            color: const Color(0xFF00FFB2).withOpacity(0.1),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: const Color(0xFF00FFB2).withOpacity(0.3),
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

        // KYC Toggle
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: const Color(0xFF111128),
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Row(
            children: [
              Icon(
                Icons.verified_user,
                color: const Color(0xFFA1A1B2),
                size: 24.sp,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Require KYC',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Only verified traders can respond',
                      style: TextStyle(
                        color: const Color(0xFFA1A1B2),
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _requiresKyc,
                onChanged: (value) => setState(() => _requiresKyc = value),
                activeColor: const Color(0xFFF7931A),
                activeTrackColor: const Color(0xFFF7931A).withOpacity(0.3),
                inactiveThumbColor: const Color(0xFFA1A1B2),
                inactiveTrackColor: const Color(0xFF2A2A3E),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep3PaymentMethods() {
    final paymentMethods = ref.watch(paymentMethodsProvider);

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
          style: TextStyle(
            color: const Color(0xFFA1A1B2),
            fontSize: 14.sp,
          ),
        ),
        SizedBox(height: 24.h),

        // Payment Methods List
        ...paymentMethods.map((method) {
          final isSelected = _selectedPaymentMethods.contains(method.id);
          return GestureDetector(
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedPaymentMethods.remove(method.id);
                } else {
                  _selectedPaymentMethods.add(method.id);
                }
              });
            },
            child: Container(
              margin: EdgeInsets.only(bottom: 12.h),
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: const Color(0xFF111128),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: isSelected ? const Color(0xFFF7931A) : const Color(0xFF2A2A3E),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24.w,
                    height: 24.h,
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFF7931A) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6.r),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFF7931A) : const Color(0xFFA1A1B2),
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? Icon(Icons.check, color: Colors.white, size: 16.sp)
                        : null,
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          method.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          method.type.name.replaceAllMapped(
                            RegExp(r'([A-Z])'),
                            (m) => ' ${m.group(1)}',
                          ).trim(),
                          style: TextStyle(
                            color: const Color(0xFFA1A1B2),
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _getPaymentMethodIcon(method.type),
                    color: const Color(0xFFA1A1B2),
                    size: 24.sp,
                  ),
                ],
              ),
            ),
          );
        }),
        SizedBox(height: 24.h),

        // Payment Instructions
        Text(
          'Payment Instructions',
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
              hintText: 'Add any special instructions for buyers (e.g., account details, transfer notes)...',
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
              color: const Color(0xFF00FFB2).withOpacity(0.1),
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
      // TODO: Create offer with provider
      // Using limit values: min=$_minLimit, max=$_maxLimit
      debugPrint('Creating offer with limits: $_minLimit - $_maxLimit NGN');
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Offer created successfully!'),
            backgroundColor: const Color(0xFF00FFB2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create offer: $e'),
          backgroundColor: const Color(0xFFFF6B6B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
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
          color: isSelected ? color.withOpacity(0.15) : const Color(0xFF111128),
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
                color: isSelected ? color.withOpacity(0.2) : const Color(0xFF1A1A2E),
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
              style: TextStyle(
                color: const Color(0xFFA1A1B2),
                fontSize: 12.sp,
              ),
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
          style: TextStyle(
            color: const Color(0xFFA1A1B2),
            fontSize: 12.sp,
          ),
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
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
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
          style: TextStyle(
            color: const Color(0xFFA1A1B2),
            fontSize: 13.sp,
          ),
        ),
      ),
    );
  }
}
