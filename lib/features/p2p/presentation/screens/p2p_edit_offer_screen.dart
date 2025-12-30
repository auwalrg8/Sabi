import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sabi_wallet/features/p2p/data/p2p_offer_model.dart';
import 'package:sabi_wallet/features/p2p/providers/p2p_providers.dart';
import 'package:sabi_wallet/features/p2p/providers/nip99_p2p_providers.dart';
import 'package:sabi_wallet/features/p2p/utils/p2p_logger.dart';
import 'package:sabi_wallet/services/nostr/models/nostr_offer.dart';

/// P2P Edit Offer Screen - Modify and republish existing offer
class P2PEditOfferScreen extends ConsumerStatefulWidget {
  final P2POfferModel offer;

  const P2PEditOfferScreen({super.key, required this.offer});

  @override
  ConsumerState<P2PEditOfferScreen> createState() => _P2PEditOfferScreenState();
}

class _P2PEditOfferScreenState extends ConsumerState<P2PEditOfferScreen> {
  final _formKey = GlobalKey<FormState>();
  final formatter = NumberFormat('#,###');

  late double _marginPercent;
  late int _minLimit;
  late int _maxLimit;
  late Set<String> _selectedPaymentMethods;
  late Map<String, String> _paymentAccountDetails;
  final Map<String, TextEditingController> _accountDetailsControllers = {};
  late TextEditingController _minController;
  late TextEditingController _maxController;
  late TextEditingController _instructionsController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initializeFromOffer();
  }

  void _initializeFromOffer() {
    // Initialize values from existing offer
    _marginPercent = widget.offer.marginPercent ?? 1.5;
    _minLimit = widget.offer.minLimit;
    _maxLimit = widget.offer.maxLimit;
    // Get payment methods from acceptedMethods or create set from paymentMethod
    _selectedPaymentMethods =
        widget.offer.acceptedMethods?.map((m) => m.id).toSet() ??
        {widget.offer.paymentMethod};
    _paymentAccountDetails =
        widget.offer.paymentAccountDetails != null
            ? Map.from(widget.offer.paymentAccountDetails!)
            : {};

    // Initialize controllers
    _minController = TextEditingController(text: formatter.format(_minLimit));
    _maxController = TextEditingController(text: formatter.format(_maxLimit));
    _instructionsController = TextEditingController(
      text: widget.offer.paymentInstructions ?? '',
    );

    // Initialize account details controllers
    for (final entry in _paymentAccountDetails.entries) {
      _accountDetailsControllers[entry.key] = TextEditingController(
        text: entry.value,
      );
    }
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    _instructionsController.dispose();
    for (final controller in _accountDetailsControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          'Edit Offer',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          if (_isSubmitting)
            Padding(
              padding: EdgeInsets.all(16.w),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.orange,
                  strokeWidth: 2,
                ),
              ),
            )
          else
            TextButton(
              onPressed: _submitChanges,
              child: Text(
                'Save',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Banner
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        'Changes will create a new offer and delete the old one on the Nostr network.',
                        style: TextStyle(
                          color: Colors.blue[200],
                          fontSize: 13.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24.h),

              // Offer Type (read-only)
              _buildSectionTitle('Offer Type'),
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF111128),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(
                        color: (widget.offer.type == OfferType.sell
                                ? Colors.orange
                                : Colors.green)
                            .withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Icon(
                        widget.offer.type == OfferType.sell
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        color:
                            widget.offer.type == OfferType.sell
                                ? Colors.orange
                                : Colors.green,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Text(
                      widget.offer.type == OfferType.sell
                          ? 'Selling BTC'
                          : 'Buying BTC',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.lock, color: Colors.grey[600], size: 18),
                  ],
                ),
              ),
              SizedBox(height: 24.h),

              // Margin Percent
              _buildSectionTitle('Price Margin'),
              SizedBox(height: 8.h),
              _buildMarginSlider(),
              SizedBox(height: 24.h),

              // Limits
              _buildSectionTitle('Trade Limits (NGN)'),
              SizedBox(height: 8.h),
              Row(
                children: [
                  Expanded(
                    child: _buildAmountInput(
                      controller: _minController,
                      label: 'Minimum',
                      onChanged: (value) {
                        final cleanValue = value.replaceAll(',', '');
                        _minLimit = int.tryParse(cleanValue) ?? 10000;
                      },
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: _buildAmountInput(
                      controller: _maxController,
                      label: 'Maximum',
                      onChanged: (value) {
                        final cleanValue = value.replaceAll(',', '');
                        _maxLimit = int.tryParse(cleanValue) ?? 1000000;
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24.h),

              // Payment Methods
              _buildSectionTitle('Payment Methods'),
              SizedBox(height: 8.h),
              _buildPaymentMethods(),
              SizedBox(height: 24.h),

              // Payment Instructions
              _buildSectionTitle('Payment Instructions (Optional)'),
              SizedBox(height: 8.h),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF111128),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: TextFormField(
                  controller: _instructionsController,
                  maxLines: 4,
                  style: TextStyle(color: Colors.white, fontSize: 14.sp),
                  decoration: InputDecoration(
                    hintText: 'Enter payment instructions for buyers...',
                    hintStyle: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14.sp,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16.w),
                  ),
                ),
              ),
              SizedBox(height: 32.h),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 56.h,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    disabledBackgroundColor: Colors.grey[800],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  child:
                      _isSubmitting
                          ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : Text(
                            'Save Changes',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                ),
              ),
              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.white,
        fontSize: 16.sp,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildMarginSlider() {
    final exchangeRates = ref.watch(exchangeRatesProvider);
    final marketRate = exchangeRates['BTC_NGN'] ?? 131448939.22;
    final adjustedPrice = marketRate * (1 + _marginPercent / 100);

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF111128),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_marginPercent >= 0 ? '+' : ''}${_marginPercent.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: _marginPercent >= 0 ? Colors.green : Colors.red,
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₦${formatter.format(adjustedPrice.toInt())}',
                    style: TextStyle(
                      color: const Color(0xFF00FFB2),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'per BTC',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11.sp),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 12.h),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.orange,
              inactiveTrackColor: Colors.grey[800],
              thumbColor: Colors.orange,
              overlayColor: Colors.orange.withOpacity(0.2),
            ),
            child: Slider(
              value: _marginPercent,
              min: -10,
              max: 20,
              divisions: 60,
              onChanged: (value) {
                setState(() => _marginPercent = value);
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '-10%',
                style: TextStyle(color: Colors.grey[600], fontSize: 12.sp),
              ),
              Text(
                '0%',
                style: TextStyle(color: Colors.grey[600], fontSize: 12.sp),
              ),
              Text(
                '+20%',
                style: TextStyle(color: Colors.grey[600], fontSize: 12.sp),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmountInput({
    required TextEditingController controller,
    required String label,
    required Function(String) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111128),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 16.w, top: 12.h),
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[500], fontSize: 12.sp),
            ),
          ),
          TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              prefixText: '₦ ',
              prefixStyle: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 8.h,
              ),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              _ThousandsSeparatorInputFormatter(),
            ],
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethods() {
    // Get Nigerian payment methods
    final allMethods = ref.watch(paymentMethodsProvider);

    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children:
          allMethods.map((method) {
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
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? Colors.orange.withOpacity(0.2)
                          : const Color(0xFF111128),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color: isSelected ? Colors.orange : Colors.grey[800]!,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected)
                      Padding(
                        padding: EdgeInsets.only(right: 8.w),
                        child: Icon(
                          Icons.check,
                          color: Colors.orange,
                          size: 16,
                        ),
                      ),
                    Text(
                      method.name,
                      style: TextStyle(
                        color: isSelected ? Colors.orange : Colors.white,
                        fontSize: 13.sp,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
    );
  }

  Future<void> _submitChanges() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPaymentMethods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select at least one payment method'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Get current exchange rate
      final exchangeRates = ref.read(exchangeRatesProvider);
      final marketRate = exchangeRates['BTC_NGN'] ?? 131448939.22;
      final pricePerBtc = marketRate * (1 + _marginPercent / 100);

      // Collect payment account details
      final accountDetails = <String, String>{};
      for (final methodId in _selectedPaymentMethods) {
        final controller = _accountDetailsControllers[methodId];
        if (controller != null && controller.text.isNotEmpty) {
          accountDetails[methodId] = controller.text;
        }
      }

      P2PLogger.info(
        'EditOffer',
        'Updating offer ${widget.offer.id}',
        metadata: {
          'marginPercent': _marginPercent,
          'minLimit': _minLimit,
          'maxLimit': _maxLimit,
          'paymentMethods': _selectedPaymentMethods.toList(),
        },
      );

      // Delete old offer first
      final deleteSuccess = await ref
          .read(nip99OfferNotifierProvider.notifier)
          .deleteOffer(widget.offer.id);

      if (!deleteSuccess) {
        P2PLogger.warning(
          'EditOffer',
          'Failed to delete old offer, proceeding anyway',
        );
      }

      // Publish new offer
      final eventId = await ref
          .read(nip99OfferNotifierProvider.notifier)
          .publishOffer(
            type:
                widget.offer.type == OfferType.sell
                    ? P2POfferType.sell
                    : P2POfferType.buy,
            title:
                '${widget.offer.type == OfferType.sell ? "Selling" : "Buying"} BTC for NGN',
            description:
                _instructionsController.text.isEmpty
                    ? 'P2P ${widget.offer.type == OfferType.sell ? "sell" : "buy"} offer via Sabi Wallet'
                    : _instructionsController.text,
            pricePerBtc: pricePerBtc,
            currency: 'NGN',
            minSats: (_minLimit / (pricePerBtc / 100000000)).round(),
            maxSats: (_maxLimit / (pricePerBtc / 100000000)).round(),
            paymentMethods: _selectedPaymentMethods.toList(),
            paymentDetails: accountDetails.isNotEmpty ? accountDetails : null,
          );

      if (eventId != null) {
        P2PLogger.info('EditOffer', 'Offer updated successfully: $eventId');

        // Refresh offers
        ref.invalidate(userNip99OffersProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Offer updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context); // Return to seller offer screen
          Navigator.pop(context); // Return to P2P home
        }
      } else {
        throw Exception('Failed to publish updated offer');
      }
    } catch (e) {
      P2PLogger.error('EditOffer', 'Failed to update offer: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update offer: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

/// Input formatter for thousands separator
class _ThousandsSeparatorInputFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat('#,###');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    final cleanValue = newValue.text.replaceAll(',', '');
    final parsed = int.tryParse(cleanValue);
    if (parsed == null) return oldValue;

    final formatted = _formatter.format(parsed);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
