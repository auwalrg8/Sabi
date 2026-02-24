import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/services/hodl_hodl/hodl_hodl.dart';

/// Create Payment Method Screen
/// Allows users to add new payment instructions for their offers
class CreatePaymentMethodScreen extends ConsumerStatefulWidget {
  const CreatePaymentMethodScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CreatePaymentMethodScreen> createState() => _CreatePaymentMethodScreenState();
}

class _CreatePaymentMethodScreenState extends ConsumerState<CreatePaymentMethodScreen> {
  final _nameController = TextEditingController();
  final _detailsController = TextEditingController();
  
  String? _selectedPaymentType;
  PaymentMethodOption? _selectedPaymentMethod;
  
  bool _isSubmitting = false;

  // Payment types and their methods
  static const Map<String, List<String>> _paymentTypes = {
    'Bank Transfer': ['bank_transfer', 'wire_transfer', 'sepa'],
    'Mobile Money': ['mpesa', 'mtn_mobile_money', 'airtel_money'],
    'Cash': ['cash_deposit', 'cash_in_person'],
    'Online Payment': ['paypal', 'venmo', 'zelle', 'cashapp'],
    'Crypto': ['usdt', 'usdc', 'lightning_network'],
    'Gift Cards': ['amazon_gift_card', 'itunes_gift_card', 'steam_gift_card'],
    'Other': ['other'],
  };

  // NOTE: Nigerian-specific payment methods should come from HodlHodl API
  // Using hardcoded fake IDs causes 422 validation errors
  // The HodlHodl API payment_methods endpoint returns valid IDs

  @override
  void dispose() {
    _nameController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paymentMethodsAsync = ref.watch(availablePaymentMethodsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.white, size: 24.sp),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Add Payment Method',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info banner
                    _buildInfoBanner(),
                    SizedBox(height: 24.h),

                    // Payment type selector
                    _buildPaymentTypeSelector(),
                    SizedBox(height: 24.h),

                    // Payment method selector
                    if (_selectedPaymentType != null) ...[
                      _buildPaymentMethodSelector(paymentMethodsAsync),
                      SizedBox(height: 24.h),
                    ],

                    // Name field
                    if (_selectedPaymentMethod != null) ...[
                      _buildNameField(),
                      SizedBox(height: 16.h),
                      _buildDetailsField(),
                    ],
                  ],
                ),
              ),
            ),

            // Submit button
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.primary, size: 24.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment Instruction',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Add your payment details for an approved payment method. Details are only visible to your counterparty when escrow is funded.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.sp,
                  ),
                ),
                SizedBox(height: 8.h),
                GestureDetector(
                  onTap: _openRequestPaymentMethod,
                  child: Text(
                    "Can't find your payment method? Request it on HodlHodl",
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12.sp,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openRequestPaymentMethod() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Request New Payment Method',
          style: TextStyle(color: Colors.white, fontSize: 16.sp),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To add a new payment method type (like Opay, Palmpay, etc.), you need to request it on the HodlHodl website.',
              style: TextStyle(color: Colors.white70, fontSize: 14.sp),
            ),
            SizedBox(height: 12.h),
            Text(
              'Steps:',
              style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8.h),
            Text(
              '1. Visit hodlhodl.com\n2. Go to Dashboard → Payment Methods\n3. Click "Add payment method (moderated)"\n4. Fill in the details and submit\n5. Wait for HodlHodl team to approve (within 1 business day)',
              style: TextStyle(color: Colors.white70, fontSize: 13.sp),
            ),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  Icon(Icons.link, color: AppColors.primary, size: 16.sp),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: SelectableText(
                      'hodlhodl.com/payment_methods',
                      style: TextStyle(color: AppColors.primary, fontSize: 13.sp),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got it', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentTypeSelector() {
    final types = _paymentTypes.keys.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Type',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 12.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: Colors.white12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedPaymentType,
              hint: Text(
                'Select payment type',
                style: TextStyle(color: Colors.white38, fontSize: 14.sp),
              ),
              items: types.map((type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Row(
                    children: [
                      Icon(_getPaymentTypeIcon(type), color: Colors.white54, size: 20.sp),
                      SizedBox(width: 12.w),
                      Text(
                        type,
                        style: TextStyle(color: Colors.white, fontSize: 14.sp),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedPaymentType = value;
                  _selectedPaymentMethod = null;
                });
              },
              dropdownColor: AppColors.surface,
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down, color: Colors.white54, size: 24.sp),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodSelector(AsyncValue<List<PaymentMethodOption>> paymentMethodsAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Method',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 12.h),
        paymentMethodsAsync.when(
          data: (methods) {
            // Filter methods based on selected type
            final filteredMethods = _getFilteredMethods(methods);
            
            return Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.white12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<PaymentMethodOption>(
                  value: _selectedPaymentMethod,
                  hint: Text(
                    'Select payment method',
                    style: TextStyle(color: Colors.white38, fontSize: 14.sp),
                  ),
                  items: filteredMethods.map((method) {
                    return DropdownMenuItem<PaymentMethodOption>(
                      value: method,
                      child: Text(
                        method.name,
                        style: TextStyle(color: Colors.white, fontSize: 14.sp),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedPaymentMethod = value;
                    });
                  },
                  dropdownColor: AppColors.surface,
                  isExpanded: true,
                  icon: Icon(Icons.keyboard_arrow_down, color: Colors.white54, size: 24.sp),
                ),
              ),
            );
          },
          loading: () => Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Center(
              child: SizedBox(
                width: 20.w,
                height: 20.h,
                child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
              ),
            ),
          ),
          error: (_, __) => _buildManualMethodInput(),
        ),
      ],
    );
  }

  Widget _buildManualMethodInput() {
    // Fallback UI for manual method entry if API fails
    final methods = _selectedPaymentType != null
        ? _paymentTypes[_selectedPaymentType]!
        : <String>[];

    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: methods.map((methodId) {
        final isSelected = _selectedPaymentMethod?.id == methodId;
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              _selectedPaymentMethod = PaymentMethodOption(
                id: methodId,
                type: _selectedPaymentType ?? '',
                name: _formatMethodName(methodId),
              );
            });
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withOpacity(0.2) : AppColors.surface,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.white12,
              ),
            ),
            child: Text(
              _formatMethodName(methodId),
              style: TextStyle(
                color: isSelected ? AppColors.primary : Colors.white,
                fontSize: 13.sp,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Name',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 8.w),
            Text(
              '(Only visible to you)',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 12.sp,
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: Colors.white12),
          ),
          child: TextField(
            controller: _nameController,
            style: TextStyle(color: Colors.white, fontSize: 14.sp),
            decoration: InputDecoration(
              hintText: 'e.g., My GTBank Account',
              hintStyle: TextStyle(color: Colors.white38),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16.w),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Details',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 12.h),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: Colors.white12),
          ),
          child: TextField(
            controller: _detailsController,
            style: TextStyle(color: Colors.white, fontSize: 14.sp),
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Enter account number, bank name, etc.\nThis will be shown to your counterparty.',
              hintStyle: TextStyle(color: Colors.white38, fontSize: 13.sp),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16.w),
            ),
          ),
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Icon(Icons.security, color: AppColors.accentGreen, size: 14.sp),
            SizedBox(width: 6.w),
            Expanded(
              child: Text(
                'Payment details are only visible to your counterparty when the escrow has been funded',
                style: TextStyle(
                  color: AppColors.accentGreen,
                  fontSize: 11.sp,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    final isValid = _selectedPaymentMethod != null &&
        _nameController.text.trim().isNotEmpty &&
        _detailsController.text.trim().isNotEmpty;

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 56.h,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isValid ? AppColors.primary : Colors.white12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              elevation: 0,
            ),
            onPressed: isValid && !_isSubmitting ? _submit : null,
            child: _isSubmitting
                ? SizedBox(
                    width: 24.w,
                    height: 24.h,
                    child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    'Create Payment Instruction',
                    style: TextStyle(
                      color: isValid ? Colors.white : Colors.white38,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_selectedPaymentMethod == null) return;

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      final service = ref.read(hodlHodlServiceProvider);
      await service.createPaymentInstruction(
        paymentMethodId: _selectedPaymentMethod!.id,
        name: _nameController.text.trim(),
        details: _detailsController.text.trim(),
      );

      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✓ Payment method added'),
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
            content: Text('Error: ${e.toString()}'),
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

  List<PaymentMethodOption> _getFilteredMethods(List<PaymentMethodOption> allMethods) {
    if (_selectedPaymentType == null) return allMethods;
    
    // Filter methods based on selected type
    // The HodlHodl API provides valid payment methods with proper IDs
    final typeKeywords = _paymentTypes[_selectedPaymentType] ?? [];
    
    // Filter methods that contain any of the type keywords in their id or type
    final filtered = allMethods.where((method) {
      final methodIdLower = method.id.toLowerCase();
      final methodTypeLower = method.type.toLowerCase();
      final methodNameLower = method.name.toLowerCase();
      
      // Check if method matches the selected payment type
      for (final keyword in typeKeywords) {
        if (methodIdLower.contains(keyword) || 
            methodTypeLower.contains(keyword) ||
            methodNameLower.contains(keyword)) {
          return true;
        }
      }
      
      // Also match based on type name
      final typeNameLower = _selectedPaymentType!.toLowerCase();
      return methodTypeLower.contains(typeNameLower) || 
             methodNameLower.contains(typeNameLower);
    }).toList();
    
    // If no filtered results, return all methods
    return filtered.isEmpty ? allMethods : filtered;
  }

  IconData _getPaymentTypeIcon(String type) {
    switch (type) {
      case 'Bank Transfer':
        return Icons.account_balance;
      case 'Mobile Money':
        return Icons.phone_android;
      case 'Cash':
        return Icons.money;
      case 'Online Payment':
        return Icons.language;
      case 'Crypto':
        return Icons.currency_bitcoin;
      case 'Gift Cards':
        return Icons.card_giftcard;
      default:
        return Icons.payment;
    }
  }

  String _formatMethodName(String id) {
    return id
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }
}
