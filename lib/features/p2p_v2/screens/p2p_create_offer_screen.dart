import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/services/nostr/nostr_service.dart';
import '../providers/p2p_provider.dart';

/// P2P v2 Create Offer Screen
/// 
/// Clean form for creating/editing P2P offers
class P2PV2CreateOfferScreen extends ConsumerStatefulWidget {
  final NostrP2POffer? editOffer;

  const P2PV2CreateOfferScreen({super.key, this.editOffer});

  @override
  ConsumerState<P2PV2CreateOfferScreen> createState() => _P2PV2CreateOfferScreenState();
}

class _P2PV2CreateOfferScreenState extends ConsumerState<P2PV2CreateOfferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _minAmountController = TextEditingController();
  final _maxAmountController = TextEditingController();
  
  P2POfferType _offerType = P2POfferType.sell;
  String _currency = 'NGN';
  final Set<String> _selectedPaymentMethods = {};
  final Map<String, TextEditingController> _paymentDetailsControllers = {};
  
  bool _isPublishing = false;

  final List<String> _availablePaymentMethods = [
    'Bank Transfer',
    'GTBank',
    'Opay',
    'PalmPay',
    'Moniepoint',
    'First Bank',
    'Zenith Bank',
    'Access Bank',
    'UBA',
    'Kuda',
    'Mobile Money',
  ];

  final List<String> _currencies = ['NGN', 'USD', 'GBP', 'EUR', 'KES', 'GHS'];

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    if (widget.editOffer != null) {
      final offer = widget.editOffer!;
      _titleController.text = offer.title;
      _descriptionController.text = offer.description;
      _priceController.text = offer.pricePerBtc.toStringAsFixed(0);
      _minAmountController.text = (offer.minAmountSats ?? '').toString();
      _maxAmountController.text = (offer.maxAmountSats ?? '').toString();
      _offerType = offer.type;
      _currency = offer.currency;
      _selectedPaymentMethods.addAll(offer.paymentMethods);
      
      // Initialize payment details controllers
      if (offer.paymentAccountDetails != null) {
        for (final entry in offer.paymentAccountDetails!.entries) {
          _paymentDetailsControllers[entry.key] = TextEditingController(text: entry.value);
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _minAmountController.dispose();
    _maxAmountController.dispose();
    for (final controller in _paymentDetailsControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context),
            
            // Form
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: EdgeInsets.all(16.w),
                  children: [
                    // Offer Type
                    _buildOfferTypeSelector(),
                    SizedBox(height: 20.h),
                    
                    // Title
                    _buildTextField(
                      controller: _titleController,
                      label: 'Offer Title',
                      hint: 'e.g., Quick BTC Sale - Fast Response',
                      validator: (v) => v?.isEmpty == true ? 'Title is required' : null,
                    ),
                    SizedBox(height: 16.h),
                    
                    // Price
                    _buildPriceInput(),
                    SizedBox(height: 16.h),
                    
                    // Amount limits
                    _buildAmountLimits(),
                    SizedBox(height: 16.h),
                    
                    // Payment Methods
                    _buildPaymentMethodsSelector(),
                    SizedBox(height: 16.h),
                    
                    // Payment Details
                    if (_selectedPaymentMethods.isNotEmpty)
                      _buildPaymentDetailsSection(),
                    
                    // Description
                    _buildTextField(
                      controller: _descriptionController,
                      label: 'Terms & Instructions',
                      hint: 'Add any terms or payment instructions for buyers...',
                      maxLines: 4,
                    ),
                    
                    SizedBox(height: 32.h),
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

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40.w,
              height: 40.h,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(Icons.arrow_back, color: Colors.white, size: 20.sp),
            ),
          ),
          SizedBox(width: 12.w),
          Text(
            widget.editOffer != null ? 'Edit Offer' : 'Create Offer',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'I want to',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.sp,
          ),
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Expanded(
              child: _buildTypeOption(
                P2POfferType.sell,
                'Sell Bitcoin',
                'Receive fiat payment',
                Icons.sell,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildTypeOption(
                P2POfferType.buy,
                'Buy Bitcoin',
                'Pay with fiat',
                Icons.shopping_cart,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeOption(P2POfferType type, String title, String subtitle, IconData icon) {
    final isSelected = _offerType == type;
    return GestureDetector(
      onTap: () => setState(() => _offerType = type),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.2) : AppColors.surface,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              size: 28.sp,
            ),
            SizedBox(height: 8.h),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? AppColors.primary : Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 11.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    String? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.sp,
          ),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(color: Colors.white, fontSize: 14.sp),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textTertiary),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide.none,
            ),
            suffixText: suffix,
            suffixStyle: TextStyle(color: AppColors.textSecondary),
            contentPadding: EdgeInsets.all(16.w),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Price per BTC',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.sp,
          ),
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v?.isEmpty == true) return 'Price is required';
                  final price = double.tryParse(v!);
                  if (price == null || price <= 0) return 'Invalid price';
                  return null;
                },
                style: TextStyle(color: Colors.white, fontSize: 14.sp),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: TextStyle(color: AppColors.textTertiary),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.all(16.w),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _currency,
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  dropdownColor: AppColors.surface,
                  items: _currencies.map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c, style: TextStyle(color: Colors.white)),
                  )).toList(),
                  onChanged: (v) => setState(() => _currency = v!),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAmountLimits() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Amount Limits (sats)',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.sp,
          ),
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _minAmountController,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v?.isEmpty == true) return 'Required';
                  final amount = int.tryParse(v!);
                  if (amount == null || amount < 1000) return 'Min 1000';
                  return null;
                },
                style: TextStyle(color: Colors.white, fontSize: 14.sp),
                decoration: InputDecoration(
                  labelText: 'Minimum',
                  labelStyle: TextStyle(color: AppColors.textTertiary, fontSize: 12.sp),
                  hintText: '10000',
                  hintStyle: TextStyle(color: AppColors.textTertiary),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.all(16.w),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              child: Text('-', style: TextStyle(color: AppColors.textTertiary)),
            ),
            Expanded(
              child: TextFormField(
                controller: _maxAmountController,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v?.isEmpty == true) return 'Required';
                  final amount = int.tryParse(v!);
                  if (amount == null) return 'Invalid';
                  final min = int.tryParse(_minAmountController.text) ?? 0;
                  if (amount <= min) return '> min';
                  return null;
                },
                style: TextStyle(color: Colors.white, fontSize: 14.sp),
                decoration: InputDecoration(
                  labelText: 'Maximum',
                  labelStyle: TextStyle(color: AppColors.textTertiary, fontSize: 12.sp),
                  hintText: '1000000',
                  hintStyle: TextStyle(color: AppColors.textTertiary),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.all(16.w),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentMethodsSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Methods',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.sp,
          ),
        ),
        SizedBox(height: 8.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: _availablePaymentMethods.map((method) {
            final isSelected = _selectedPaymentMethods.contains(method);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedPaymentMethods.remove(method);
                    _paymentDetailsControllers.remove(method)?.dispose();
                  } else {
                    _selectedPaymentMethods.add(method);
                    _paymentDetailsControllers[method] = TextEditingController();
                  }
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary.withOpacity(0.2) : AppColors.surface,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected) ...[
                      Icon(Icons.check, color: AppColors.primary, size: 16.sp),
                      SizedBox(width: 4.w),
                    ],
                    Text(
                      method,
                      style: TextStyle(
                        color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        fontSize: 13.sp,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        if (_selectedPaymentMethods.isEmpty)
          Padding(
            padding: EdgeInsets.only(top: 8.h),
            child: Text(
              'Select at least one payment method',
              style: TextStyle(
                color: AppColors.accentRed,
                fontSize: 11.sp,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPaymentDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Account Details',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.sp,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          'Enter your account details for each payment method',
          style: TextStyle(
            color: AppColors.textTertiary,
            fontSize: 11.sp,
          ),
        ),
        SizedBox(height: 12.h),
        ..._selectedPaymentMethods.map((method) {
          _paymentDetailsControllers.putIfAbsent(method, () => TextEditingController());
          return Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: TextField(
              controller: _paymentDetailsControllers[method],
              style: TextStyle(color: Colors.white, fontSize: 14.sp),
              decoration: InputDecoration(
                labelText: method,
                labelStyle: TextStyle(color: AppColors.textTertiary, fontSize: 12.sp),
                hintText: 'e.g., Account Name - Account Number',
                hintStyle: TextStyle(color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.all(16.w),
              ),
            ),
          );
        }),
        SizedBox(height: 8.h),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.borderColor)),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 52.h,
          child: ElevatedButton(
            onPressed: _isPublishing ? null : _submitOffer,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: _isPublishing
                ? SizedBox(
                    width: 24.w,
                    height: 24.h,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    widget.editOffer != null ? 'Update Offer' : 'Publish Offer',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitOffer() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPaymentMethods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select at least one payment method'),
          backgroundColor: AppColors.accentRed,
        ),
      );
      return;
    }

    setState(() => _isPublishing = true);

    try {
      final notifier = ref.read(p2pV2Provider.notifier);
      
      // Build payment details map
      final paymentDetails = <String, String>{};
      for (final method in _selectedPaymentMethods) {
        final details = _paymentDetailsControllers[method]?.text.trim();
        if (details != null && details.isNotEmpty) {
          paymentDetails[method] = details;
        }
      }

      if (widget.editOffer != null) {
        // Update existing offer
        final updatedOffer = NostrP2POffer(
          id: widget.editOffer!.id,
          eventId: widget.editOffer!.eventId,
          pubkey: widget.editOffer!.pubkey,
          type: _offerType,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          pricePerBtc: double.parse(_priceController.text),
          currency: _currency,
          minAmountSats: int.parse(_minAmountController.text),
          maxAmountSats: int.parse(_maxAmountController.text),
          paymentMethods: _selectedPaymentMethods.toList(),
          paymentAccountDetails: paymentDetails.isNotEmpty ? paymentDetails : null,
          createdAt: widget.editOffer!.createdAt,
          status: P2POfferStatus.active,
        );
        
        final success = await notifier.updateOffer(updatedOffer);
        
        if (mounted) {
          if (success) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Offer updated successfully'),
                backgroundColor: AppColors.accentGreen,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to update offer'),
                backgroundColor: AppColors.accentRed,
              ),
            );
          }
        }
      } else {
        // Create new offer
        final eventId = await notifier.publishOffer(
          type: _offerType,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          pricePerBtc: double.parse(_priceController.text),
          currency: _currency,
          minSats: int.parse(_minAmountController.text),
          maxSats: int.parse(_maxAmountController.text),
          paymentMethods: _selectedPaymentMethods.toList(),
          paymentDetails: paymentDetails.isNotEmpty ? paymentDetails : null,
        );

        if (mounted) {
          if (eventId != null) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Offer published successfully'),
                backgroundColor: AppColors.accentGreen,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to publish offer'),
                backgroundColor: AppColors.accentRed,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.accentRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
    }
  }
}
