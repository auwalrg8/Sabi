import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/services/hodl_hodl/hodl_hodl.dart';

import 'create_payment_method_screen.dart';

/// Create Offer Screen
/// Allows users to create and publish offers to Hodl Hodl marketplace
class CreateOfferScreen extends ConsumerStatefulWidget {
  const CreateOfferScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CreateOfferScreen> createState() => _CreateOfferScreenState();
}

class _CreateOfferScreenState extends ConsumerState<CreateOfferScreen> {
  final _minAmountController = TextEditingController();
  final _maxAmountController = TextEditingController();
  final _fixedAmountController = TextEditingController();
  final _marginController = TextEditingController(text: '0');
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _paymentWindowController = TextEditingController(text: '90');

  bool _isSubmitting = false;

  @override
  void dispose() {
    _minAmountController.dispose();
    _maxAmountController.dispose();
    _fixedAmountController.dispose();
    _marginController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _paymentWindowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(createOfferFormProvider);
    final paymentInstructionsAsync = ref.watch(userPaymentInstructionsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white, size: 24.sp),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Create Offer',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(createOfferFormProvider.notifier).reset();
              _resetControllers();
            },
            child: Text(
              'Reset',
              style: TextStyle(color: Colors.white54, fontSize: 14.sp),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            _buildProgressIndicator(),

            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Side selector (Buy / Sell)
                    _buildSideSelector(formState),
                    SizedBox(height: 24.h),

                    // Rate type (Floating / Fixed)
                    _buildRateTypeSelector(formState),
                    SizedBox(height: 24.h),

                    // Exchange & Currency
                    _buildExchangeCurrencyRow(formState),
                    SizedBox(height: 16.h),

                    // Margin
                    _buildMarginInput(formState),
                    SizedBox(height: 24.h),

                    // Amount section
                    _buildAmountSection(formState),
                    SizedBox(height: 24.h),

                    // Payment Methods
                    _buildPaymentMethodsSection(formState, paymentInstructionsAsync),
                    SizedBox(height: 24.h),

                    // Advanced settings (collapsible)
                    _buildAdvancedSettings(formState),
                    SizedBox(height: 24.h),

                    // Offer description
                    _buildOfferDescription(formState),
                    SizedBox(height: 24.h),

                    // Toggles
                    _buildToggles(formState),
                    SizedBox(height: 32.h),

                    // Preview card
                    _buildPreviewCard(formState),
                    SizedBox(height: 100.h), // Space for bottom button
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomSheet: _buildBottomButton(formState),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
      child: Row(
        children: [
          _buildStep(1, 'Create', true),
          _buildStepLine(false),
          _buildStep(2, 'Payment', false),
          _buildStepLine(false),
          _buildStep(3, 'Escrow', false),
          _buildStepLine(false),
          _buildStep(4, 'Trade', false),
          _buildStepLine(false),
          _buildStep(5, 'Complete', false),
        ],
      ),
    );
  }

  Widget _buildStep(int number, String label, bool active) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 24.w,
            height: 24.h,
            decoration: BoxDecoration(
              color: active ? AppColors.primary : Colors.white12,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: TextStyle(
                  color: active ? Colors.white : Colors.white54,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : Colors.white38,
              fontSize: 9.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepLine(bool active) {
    return Expanded(
      child: Container(
        height: 2,
        color: active ? AppColors.primary : Colors.white12,
        margin: EdgeInsets.only(bottom: 16.h),
      ),
    );
  }

  Widget _buildSideSelector(CreateOfferFormState formState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What do you want to do?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: _buildSideOption(
                OfferSide.buy,
                formState.side == OfferSide.buy,
                Icons.arrow_downward,
                AppColors.accentGreen,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildSideOption(
                OfferSide.sell,
                formState.side == OfferSide.sell,
                Icons.arrow_upward,
                AppColors.accentRed,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSideOption(OfferSide side, bool selected, IconData icon, Color color) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(createOfferFormProvider.notifier).setSide(side);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: selected ? color : Colors.white12,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24.sp),
            ),
            SizedBox(height: 12.h),
            Text(
              side.displayName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              side.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRateTypeSelector(CreateOfferFormState formState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rate Type',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 12.h),
        Container(
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildRateTypeOption(RateType.floating, formState.rateType == RateType.floating),
              ),
              Expanded(
                child: _buildRateTypeOption(RateType.fixed, formState.rateType == RateType.fixed),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRateTypeOption(RateType type, bool selected) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(createOfferFormProvider.notifier).setRateType(type);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Center(
          child: Text(
            type.displayName,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontSize: 14.sp,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExchangeCurrencyRow(CreateOfferFormState formState) {
    return Row(
      children: [
        // Exchange source
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Exchange',
                style: TextStyle(color: Colors.white54, fontSize: 12.sp),
              ),
              SizedBox(height: 8.h),
              _buildDropdown<ExchangeSource>(
                value: formState.exchangeSource,
                items: ExchangeSource.all,
                onChanged: (v) => ref.read(createOfferFormProvider.notifier).setExchangeSource(v!),
                displayBuilder: (e) => e.name,
              ),
            ],
          ),
        ),
        SizedBox(width: 12.w),
        // Currency
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Currency',
                style: TextStyle(color: Colors.white54, fontSize: 12.sp),
              ),
              SizedBox(height: 8.h),
              _buildDropdown<CurrencyOption>(
                value: formState.currency,
                items: CurrencyOption.popular,
                onChanged: (v) => ref.read(createOfferFormProvider.notifier).setCurrency(v!),
                displayBuilder: (c) => '${c.flagEmoji ?? ''} ${c.code}'.trim(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<T> items,
    required void Function(T?) onChanged,
    required String Function(T) displayBuilder,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.white12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(
                displayBuilder(item),
                style: TextStyle(color: Colors.white, fontSize: 14.sp),
              ),
            );
          }).toList(),
          onChanged: onChanged,
          dropdownColor: AppColors.surface,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: Colors.white54, size: 20.sp),
        ),
      ),
    );
  }

  Widget _buildMarginInput(CreateOfferFormState formState) {
    return Row(
      children: [
        Icon(Icons.add_circle_outline, color: AppColors.primary, size: 20.sp),
        SizedBox(width: 8.w),
        Text(
          'Add margin',
          style: TextStyle(color: Colors.white, fontSize: 14.sp),
        ),
        const Spacer(),
        SizedBox(
          width: 100.w,
          child: TextField(
            controller: _marginController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 14.sp),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: TextStyle(color: Colors.white38),
              suffixText: '%',
              suffixStyle: TextStyle(color: Colors.white54, fontSize: 14.sp),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            ),
            onChanged: (v) {
              final margin = double.tryParse(v) ?? 0;
              ref.read(createOfferFormProvider.notifier).setMargin(margin);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAmountSection(CreateOfferFormState formState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Amount',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            // Toggle between fixed and range
            Container(
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAmountTypeChip(AmountType.fixed, formState.amountType == AmountType.fixed),
                  _buildAmountTypeChip(AmountType.range, formState.amountType == AmountType.range),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),

        if (formState.amountType == AmountType.fixed) ...[
          _buildAmountInput(
            controller: _fixedAmountController,
            label: 'Amount',
            currency: formState.currency,
            onChanged: (v) {
              ref.read(createOfferFormProvider.notifier).setFixedAmount(double.tryParse(v));
            },
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: _buildAmountInput(
                  controller: _minAmountController,
                  label: 'Min',
                  currency: formState.currency,
                  onChanged: (v) {
                    ref.read(createOfferFormProvider.notifier).setMinAmount(double.tryParse(v));
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                child: Text('—', style: TextStyle(color: Colors.white38, fontSize: 20.sp)),
              ),
              Expanded(
                child: _buildAmountInput(
                  controller: _maxAmountController,
                  label: 'Max',
                  currency: formState.currency,
                  onChanged: (v) {
                    ref.read(createOfferFormProvider.notifier).setMaxAmount(double.tryParse(v));
                  },
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildAmountTypeChip(AmountType type, bool selected) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(createOfferFormProvider.notifier).setAmountType(type);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6.r),
        ),
        child: Text(
          type.displayName,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white54,
            fontSize: 11.sp,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildAmountInput({
    required TextEditingController controller,
    required String label,
    required CurrencyOption currency,
    required void Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white54, fontSize: 11.sp),
        ),
        SizedBox(height: 6.h),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: Colors.white12),
          ),
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: TextStyle(color: Colors.white24),
              prefixText: '${currency.symbol} ',
              prefixStyle: TextStyle(color: Colors.white54, fontSize: 16.sp),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(14.w),
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodsSection(
    CreateOfferFormState formState,
    AsyncValue<List<UserPaymentInstruction>> paymentInstructionsAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Payment Methods',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${formState.selectedPaymentInstructionIds.length}/10',
              style: TextStyle(color: Colors.white38, fontSize: 12.sp),
            ),
          ],
        ),
        SizedBox(height: 12.h),

        paymentInstructionsAsync.when(
          data: (instructions) {
            if (instructions.isEmpty) {
              return _buildAddPaymentMethodButton(true);
            }
            return Column(
              children: [
                // Selected payment methods
                ...instructions.map((instruction) {
                  final isSelected = formState.selectedPaymentInstructionIds.contains(instruction.id);
                  return _buildPaymentMethodTile(instruction, isSelected);
                }),
                SizedBox(height: 8.h),
                if (instructions.length < 10)
                  _buildAddPaymentMethodButton(false),
              ],
            );
          },
          loading: () => Center(
            child: Padding(
              padding: EdgeInsets.all(20.w),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
          error: (_, __) => _buildAddPaymentMethodButton(true),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodTile(UserPaymentInstruction instruction, bool selected) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (selected) {
          ref.read(createOfferFormProvider.notifier).removePaymentInstruction(instruction.id);
        } else {
          ref.read(createOfferFormProvider.notifier).addPaymentInstruction(instruction.id);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.white12,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20.w,
              height: 20.h,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.primary : Colors.white38,
                  width: 2,
                ),
              ),
              child: selected
                  ? Icon(Icons.check, color: Colors.white, size: 12.sp)
                  : null,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    instruction.paymentMethodName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    instruction.name,
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.payment,
              color: Colors.white38,
              size: 20.sp,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddPaymentMethodButton(bool isFirst) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const CreatePaymentMethodScreen()),
        );
        if (result == true) {
          ref.invalidate(userPaymentInstructionsProvider);
        }
      },
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.white24, style: BorderStyle.solid),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, color: AppColors.primary, size: 20.sp),
            SizedBox(width: 8.w),
            Text(
              isFirst ? 'Add payment method' : 'Add another payment method',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedSettings(CreateOfferFormState formState) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Row(
          children: [
            Icon(Icons.settings, color: Colors.white54, size: 18.sp),
            SizedBox(width: 8.w),
            Text(
              'Advanced settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        iconColor: Colors.white54,
        collapsedIconColor: Colors.white54,
        children: [
          SizedBox(height: 12.h),
          // Payment window
          _buildSettingRow(
            icon: Icons.timer,
            label: 'Payment window',
            child: SizedBox(
              width: 80.w,
              child: TextField(
                controller: _paymentWindowController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 14.sp),
                decoration: InputDecoration(
                  suffixText: 'min',
                  suffixStyle: TextStyle(color: Colors.white54, fontSize: 12.sp),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
                ),
                onChanged: (v) {
                  final minutes = int.tryParse(v) ?? 90;
                  ref.read(createOfferFormProvider.notifier).setPaymentWindowMinutes(minutes);
                },
              ),
            ),
          ),
          SizedBox(height: 12.h),
          // BTC confirmations
          _buildSettingRow(
            icon: Icons.verified,
            label: 'BTC confirmations',
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: formState.confirmations,
                  items: [1, 2, 3, 6].map((c) {
                    return DropdownMenuItem<int>(
                      value: c,
                      child: Text(
                        '$c confirmation${c > 1 ? 's' : ''}',
                        style: TextStyle(color: Colors.white, fontSize: 13.sp),
                      ),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      ref.read(createOfferFormProvider.notifier).setConfirmations(v);
                    }
                  },
                  dropdownColor: AppColors.surface,
                  icon: Icon(Icons.keyboard_arrow_down, color: Colors.white54, size: 18.sp),
                ),
              ),
            ),
          ),
          SizedBox(height: 12.h),
          // Location
          _buildSettingRow(
            icon: Icons.location_on,
            label: 'Location',
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                formState.countryCode ?? 'Global',
                style: TextStyle(color: Colors.white, fontSize: 13.sp),
              ),
            ),
          ),
          SizedBox(height: 12.h),
          // Available hours
          _buildSettingRow(
            icon: Icons.access_time,
            label: '24 hours access',
            child: Switch(
              value: formState.is24Hours,
              onChanged: (v) {
                ref.read(createOfferFormProvider.notifier).setIs24Hours(v);
              },
              activeColor: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.white38, size: 18.sp),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: Colors.white70, fontSize: 13.sp),
          ),
        ),
        child,
      ],
    );
  }

  Widget _buildOfferDescription(CreateOfferFormState formState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Offer Description',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 12.h),
        TextField(
          controller: _titleController,
          style: TextStyle(color: Colors.white, fontSize: 14.sp),
          decoration: InputDecoration(
            hintText: 'Title (optional)',
            hintStyle: TextStyle(color: Colors.white38),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.all(14.w),
            counterText: '${_titleController.text.length}/100',
            counterStyle: TextStyle(color: Colors.white38, fontSize: 11.sp),
          ),
          maxLength: 100,
          onChanged: (v) {
            ref.read(createOfferFormProvider.notifier).setTitle(v.isEmpty ? null : v);
            setState(() {}); // Update counter
          },
        ),
        SizedBox(height: 12.h),
        TextField(
          controller: _descriptionController,
          style: TextStyle(color: Colors.white, fontSize: 14.sp),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Description (optional)',
            hintStyle: TextStyle(color: Colors.white38),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.all(14.w),
            counterText: '${_descriptionController.text.length}/5000',
            counterStyle: TextStyle(color: Colors.white38, fontSize: 11.sp),
          ),
          maxLength: 5000,
          onChanged: (v) {
            ref.read(createOfferFormProvider.notifier).setDescription(v.isEmpty ? null : v);
            setState(() {}); // Update counter
          },
        ),
      ],
    );
  }

  Widget _buildToggles(CreateOfferFormState formState) {
    return Column(
      children: [
        _buildToggleRow(
          icon: Icons.visibility,
          title: 'Enable offer after creation',
          subtitle: 'Your offer will be active and visible to other users',
          value: formState.enabledAfterCreation,
          onChanged: (v) {
            ref.read(createOfferFormProvider.notifier).setEnabledAfterCreation(v);
          },
        ),
        SizedBox(height: 16.h),
        _buildToggleRow(
          icon: Icons.lock_outline,
          title: 'Make offer private',
          subtitle: 'Only accessible by link, not displayed in offer list',
          value: formState.isPrivate,
          onChanged: (v) {
            ref.read(createOfferFormProvider.notifier).setIsPrivate(v);
          },
        ),
      ],
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required void Function(bool) onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 22.sp),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11.sp,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primary,
        ),
      ],
    );
  }

  Widget _buildPreviewCard(CreateOfferFormState formState) {
    final marginDisplay = formState.margin == 0
        ? 'at market rate'
        : formState.margin > 0
            ? '+${formState.margin.toStringAsFixed(1)}% margin'
            : '${formState.margin.toStringAsFixed(1)}% discount';

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.preview, color: AppColors.primary, size: 18.sp),
              SizedBox(width: 8.w),
              Text(
                'Offer Preview',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          _buildPreviewRow('Type', formState.side.displayName),
          _buildPreviewRow('Price', '${formState.exchangeSource.name} ${formState.currency.code} | $marginDisplay'),
          if (formState.amountType == AmountType.fixed && formState.fixedAmount != null)
            _buildPreviewRow('Amount', '${formState.currency.symbol}${formState.fixedAmount}')
          else if (formState.minAmount != null || formState.maxAmount != null)
            _buildPreviewRow(
              'Amount',
              '${formState.currency.symbol}${formState.minAmount ?? '-'} - ${formState.currency.symbol}${formState.maxAmount ?? '-'}',
            ),
          _buildPreviewRow('Payment methods', '${formState.selectedPaymentInstructionIds.length} selected'),
        ],
      ),
    );
  }

  Widget _buildPreviewRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.white54, fontSize: 12.sp),
          ),
          Text(
            value,
            style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton(CreateOfferFormState formState) {
    final isValid = formState.isValid;

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isValid ? AppColors.primary : Colors.white12,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  elevation: 0,
                ),
                onPressed: isValid && !_isSubmitting ? _submitOffer : null,
                child: _isSubmitting
                    ? SizedBox(
                        width: 24.w,
                        height: 24.h,
                        child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        'Create Offer',
                        style: TextStyle(
                          color: isValid ? Colors.white : Colors.white38,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitOffer() async {
    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      await ref.read(createOfferFormProvider.notifier).submitOffer();
      
      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('🎉 Offer created successfully!'),
            backgroundColor: AppColors.accentGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.accentRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _resetControllers() {
    _minAmountController.clear();
    _maxAmountController.clear();
    _fixedAmountController.clear();
    _marginController.text = '0';
    _titleController.clear();
    _descriptionController.clear();
    _paymentWindowController.text = '90';
    setState(() {});
  }
}
