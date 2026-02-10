import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:uuid/uuid.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/features/p2p/data/payment_method_model.dart';
import 'package:sabi_wallet/features/p2p/services/payment_method_service.dart';

/// Screen to add or edit a payment method
class P2PAddPaymentMethodScreen extends ConsumerStatefulWidget {
  final PaymentMethodModel? existingMethod;

  const P2PAddPaymentMethodScreen({
    super.key,
    this.existingMethod,
  });

  @override
  ConsumerState<P2PAddPaymentMethodScreen> createState() =>
      _P2PAddPaymentMethodScreenState();
}

class _P2PAddPaymentMethodScreenState
    extends ConsumerState<P2PAddPaymentMethodScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  PaymentMethodType _selectedType = PaymentMethodType.bankTransfer;
  final _nameController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _phoneController = TextEditingController();
  final _walletAddressController = TextEditingController();
  final _instructionsController = TextEditingController();
  bool _isDefault = false;

  bool get _isEditing => widget.existingMethod != null;

  @override
  void initState() {
    super.initState();
    if (widget.existingMethod != null) {
      _populateFields(widget.existingMethod!);
    }
  }

  void _populateFields(PaymentMethodModel method) {
    _selectedType = method.type;
    _nameController.text = method.name;
    _bankNameController.text = method.bankName ?? '';
    _accountNameController.text = method.accountName ?? '';
    _accountNumberController.text = method.accountNumber ?? '';
    _phoneController.text = method.phoneNumber ?? '';
    _walletAddressController.text = method.walletAddress ?? '';
    _instructionsController.text = method.instructions ?? '';
    _isDefault = method.isDefault;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bankNameController.dispose();
    _accountNameController.dispose();
    _accountNumberController.dispose();
    _phoneController.dispose();
    _walletAddressController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : AppColors.accentGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final service = ref.read(paymentMethodServiceProvider);

      final method = PaymentMethodModel(
        id: widget.existingMethod?.id ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        type: _selectedType,
        bankName: _bankNameController.text.trim().isEmpty
            ? null
            : _bankNameController.text.trim(),
        accountName: _accountNameController.text.trim().isEmpty
            ? null
            : _accountNameController.text.trim(),
        accountNumber: _accountNumberController.text.trim().isEmpty
            ? null
            : _accountNumberController.text.trim(),
        phoneNumber: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        walletAddress: _walletAddressController.text.trim().isEmpty
            ? null
            : _walletAddressController.text.trim(),
        instructions: _instructionsController.text.trim().isEmpty
            ? null
            : _instructionsController.text.trim(),
        isDefault: _isDefault,
        createdAt: widget.existingMethod?.createdAt,
      );

      if (_isEditing) {
        await service.updatePaymentMethod(method);
        _showSnack('Payment method updated');
      } else {
        await service.addPaymentMethod(method);
        _showSnack('Payment method added');
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showSnack('Failed to save: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20.sp),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Edit Payment Method' : 'Add Payment Method',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(20.w),
          children: [
            // Payment Type Selection
            Text(
              'Payment Type',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 12.h),
            _buildTypeSelector(),
            SizedBox(height: 24.h),

            // Method Name
            _buildTextField(
              controller: _nameController,
              label: 'Display Name',
              hint: 'e.g., My GTBank Account',
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
            ),
            SizedBox(height: 20.h),

            // Type-specific fields
            ..._buildTypeSpecificFields(),

            // Instructions
            SizedBox(height: 20.h),
            _buildTextField(
              controller: _instructionsController,
              label: 'Additional Instructions (Optional)',
              hint: 'Any special instructions for the buyer',
              maxLines: 3,
            ),
            SizedBox(height: 24.h),

            // Default toggle
            Container(
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.star_outline_rounded,
                    color: AppColors.primary,
                    size: 24.sp,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Set as Default',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Use this method by default for new offers',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isDefault,
                    onChanged: (val) => setState(() => _isDefault = val),
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
            ),
            SizedBox(height: 40.h),

            // Save button
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: _saving
                  ? SizedBox(
                      width: 20.w,
                      height: 20.h,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.w,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _isEditing ? 'Update' : 'Add Payment Method',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Wrap(
      spacing: 10.w,
      runSpacing: 10.h,
      children: PaymentMethodType.values.map((type) {
        final isSelected = _selectedType == type;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedType = type);
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.2)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(type.icon, style: TextStyle(fontSize: 18.sp)),
                SizedBox(width: 8.w),
                Text(
                  type.displayName,
                  style: TextStyle(
                    color: isSelected ? AppColors.primary : Colors.white,
                    fontSize: 13.sp,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  List<Widget> _buildTypeSpecificFields() {
    switch (_selectedType) {
      case PaymentMethodType.bankTransfer:
        return [
          _buildTextField(
            controller: _bankNameController,
            label: 'Bank Name',
            hint: 'e.g., GTBank, Access Bank',
          ),
          SizedBox(height: 20.h),
          _buildTextField(
            controller: _accountNameController,
            label: 'Account Name',
            hint: 'Name on the account',
          ),
          SizedBox(height: 20.h),
          _buildTextField(
            controller: _accountNumberController,
            label: 'Account Number',
            hint: 'Your bank account number',
            keyboardType: TextInputType.number,
          ),
        ];

      case PaymentMethodType.mobileMoney:
        return [
          _buildTextField(
            controller: _bankNameController,
            label: 'Provider',
            hint: 'e.g., Opay, PalmPay, MTN MoMo',
          ),
          SizedBox(height: 20.h),
          _buildTextField(
            controller: _phoneController,
            label: 'Phone Number',
            hint: 'Mobile money phone number',
            keyboardType: TextInputType.phone,
          ),
          SizedBox(height: 20.h),
          _buildTextField(
            controller: _accountNameController,
            label: 'Account Name',
            hint: 'Name on the account',
          ),
        ];

      case PaymentMethodType.cash:
        return [
          _buildTextField(
            controller: _bankNameController,
            label: 'Location',
            hint: 'e.g., Lagos, Abuja, Kano',
          ),
        ];

      case PaymentMethodType.giftCard:
        return [
          _buildTextField(
            controller: _bankNameController,
            label: 'Gift Card Type',
            hint: 'e.g., Amazon, iTunes, Steam',
          ),
        ];

      case PaymentMethodType.wallet:
        return [
          _buildTextField(
            controller: _bankNameController,
            label: 'Wallet Type',
            hint: 'e.g., PayPal, Chipper Cash',
          ),
          SizedBox(height: 20.h),
          _buildTextField(
            controller: _walletAddressController,
            label: 'Wallet Address/Email',
            hint: 'Your wallet address or email',
          ),
        ];

      case PaymentMethodType.other:
        return [];
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: TextStyle(color: Colors.white, fontSize: 15.sp),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14.sp,
            ),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 14.h,
            ),
          ),
        ),
      ],
    );
  }
}
