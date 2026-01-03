import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/services/rate_service.dart';

import '../../data/models/models.dart';
import '../../services/vtu_service.dart';
import '../widgets/amount_selector.dart';
import 'vtu_confirm_screen.dart';
import 'vtu_order_history_screen.dart';

class UtilitiesScreen extends ConsumerStatefulWidget {
  const UtilitiesScreen({super.key});

  @override
  ConsumerState<UtilitiesScreen> createState() => _UtilitiesScreenState();
}

class _UtilitiesScreenState extends ConsumerState<UtilitiesScreen> {
  final _meterController = TextEditingController();
  final _customAmountController = TextEditingController();
  ElectricityProvider? _selectedProvider;
  MeterType _selectedMeterType = MeterType.prepaid;
  double? _selectedAmount;
  String? _meterError;
  bool _useCustomAmount = false;
  
  // Verification State
  bool _isVerifying = false;
  String? _verifiedName;
  String? _verifiedAddress;

  @override
  void dispose() {
    _meterController.dispose();
    _customAmountController.dispose();
    super.dispose();
  }

  void _onProviderSelected(ElectricityProvider provider) {
    setState(() {
      _selectedProvider = provider;
      // Reset verification when provider changes
      _verifiedName = null;
      _verifiedAddress = null;
      _meterError = null;
    });
  }

  void _onMeterTypeSelected(MeterType type) {
    setState(() {
      _selectedMeterType = type;
      // Reset verification when meter type changes
      _verifiedName = null;
      _verifiedAddress = null;
      _meterError = null;
    });
  }

  void _onAmountSelected(double amount) {
    setState(() {
      _selectedAmount = amount;
      _useCustomAmount = false;
      _customAmountController.clear();
    });
  }

  void _onCustomAmountChanged(String value) {
    setState(() {
      _useCustomAmount = value.isNotEmpty;
      if (value.isNotEmpty) {
        _selectedAmount = double.tryParse(value.replaceAll(',', ''));
      } else {
        _selectedAmount = null;
      }
    });
  }

  bool get _isFormValid {
    // Basic validation
    final hasValidInputs =
        _selectedProvider != null &&
        VtuService.isValidMeterNumber(_meterController.text.trim()) &&
        _selectedAmount != null &&
        _selectedAmount! >= 1000;
        
    // MUST have verified name to proceed
    return hasValidInputs && _verifiedName != null;
  }

  Future<void> _verifyMeter() async {
    final meter = _meterController.text.trim();

    // reset previous state
    setState(() {
      _meterError = null;
      _verifiedName = null;
      _verifiedAddress = null;
    });

    // Quick validation before API call
    if (_selectedProvider == null) {
      setState(() => _meterError = 'Select a provider first');
      return;
    }

    if (!VtuService.isValidMeterNumber(meter)) {
      setState(() => _meterError = 'Invalid meter number format');
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final info = await VtuService.verifyMeter(
        meterNumber: meter,
        discoCode: _selectedProvider!.code,
        meterType: _selectedMeterType.name,
      );

      if (mounted) {
        setState(() {
          _isVerifying = false;
          if (info != null && info.isValid) {
            _verifiedName = info.customerName;
            _verifiedAddress = info.address;
          } else {
            _meterError = 'Meter not found or invalid';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _meterError = 'Verification failed: Network error';
        });
      }
    }
  }

  void _proceedToConfirm() {
    final meter = _meterController.text.trim();

    if (!VtuService.isValidMeterNumber(meter)) {
      setState(() {
        _meterError = 'Please enter a valid meter number (11-13 digits)';
      });
      return;
    }

    if (_selectedProvider == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a distribution company')),
      );
      return;
    }

    if (_selectedAmount == null || _selectedAmount! < 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an amount (min ₦1,000)')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VtuConfirmScreen(
          serviceType: VtuServiceType.electricity,
          recipient: meter,
          amountNaira: _selectedAmount!,
          electricityProvider: _selectedProvider,
          meterType: _selectedMeterType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amounts = VtuService.getElectricityAmounts();

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Pay Electricity',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const VtuOrderHistoryScreen(),
                ),
              );
            },
          ),
        ],
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
                    // Provider Selection
                    Text(
                      'Select Distribution Company',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    _ProviderGrid(
                      selectedProvider: _selectedProvider,
                      onProviderSelected: _onProviderSelected,
                    ),
                    SizedBox(height: 24.h),

                    // Meter Type Selection
                    Text(
                      'Meter Type',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Row(
                      children: MeterType.values.map((type) {
                        final isSelected = _selectedMeterType == type;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => _onMeterTypeSelected(type),
                            child: Container(
                              margin: EdgeInsets.only(
                                right: type == MeterType.prepaid ? 8.w : 0,
                                left: type == MeterType.postpaid ? 8.w : 0,
                              ),
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? const Color(0xFF1E88E5).withOpacity(0.15) 
                                    : const Color(0xFF1A1A2E),
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(
                                  color: isSelected 
                                      ? const Color(0xFF1E88E5) 
                                      : const Color(0xFF2A2A3E),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  type.name,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : const Color(0xFFA1A1B2),
                                    fontSize: 14.sp,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 24.h),

                    // Meter Number Input
                    _MeterInputField(
                      controller: _meterController,
                      selectedProvider: _selectedProvider,
                      errorText: _meterError,
                      isVerifying: _isVerifying,
                      onVerifyPressed: _verifyMeter,
                      onChanged: (value) {
                        setState(() {
                          // Clear verification when typing
                          _meterError = null;
                          _verifiedName = null;
                          _verifiedAddress = null;
                        });
                      },
                    ),
                    
                    // Validation Result
                    if (_verifiedName != null) ...[
                      SizedBox(height: 12.h),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E88E5).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(
                            color: const Color(0xFF1E88E5).withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: const Color(0xFF1E88E5),
                                  size: 16.sp,
                                ),
                                SizedBox(width: 6.w),
                                Text(
                                  'Verified Customer',
                                  style: TextStyle(
                                    color: const Color(0xFF1E88E5),
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              _verifiedName!,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_verifiedAddress != null &&
                                _verifiedAddress!.isNotEmpty) ...[
                              SizedBox(height: 2.h),
                              Text(
                                _verifiedAddress!,
                                style: TextStyle(
                                  color: const Color(0xFFA1A1B2),
                                  fontSize: 13.sp,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    SizedBox(height: 24.h),

                    // Amount Selection
                    AmountSelector(
                      amounts: amounts,
                      selectedAmount: _useCustomAmount ? null : _selectedAmount,
                      onAmountSelected: _onAmountSelected,
                      accentColor: _selectedProvider != null 
                          ? Color(_selectedProvider!.primaryColor) 
                          : const Color(0xFF1E88E5),
                    ),
                    SizedBox(height: 20.h),

                    // Custom Amount Input
                    CustomAmountInput(
                      controller: _customAmountController,
                      onChanged: _onCustomAmountChanged,
                      minAmount: 1000,
                      maxAmount: 100000,
                    ),
                    SizedBox(height: 24.h),

                    // Summary Card
                    if (_selectedAmount != null && _selectedAmount! >= 1000) ...[
                      _SummaryCard(
                        amountNaira: _selectedAmount!,
                        provider: _selectedProvider,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom Button
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: const Color(0xFF111128),
                border: Border(
                  top: BorderSide(color: const Color(0xFF2A2A3E), width: 1),
                ),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 52.h,
                  child: ElevatedButton(
                    onPressed: _isFormValid ? _proceedToConfirm : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedProvider != null 
                          ? Color(_selectedProvider!.primaryColor) 
                          : const Color(0xFF1E88E5),
                      disabledBackgroundColor: const Color(0xFF2A2A3E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: Text(
                      'Continue',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderGrid extends StatelessWidget {
  final ElectricityProvider? selectedProvider;
  final ValueChanged<ElectricityProvider> onProviderSelected;

  const _ProviderGrid({
    this.selectedProvider,
    required this.onProviderSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10.w,
        mainAxisSpacing: 10.h,
        childAspectRatio: 1.2,
      ),
      itemCount: ElectricityProvider.values.length,
      itemBuilder: (context, index) {
        final provider = ElectricityProvider.values[index];
        final isSelected = selectedProvider == provider;
        return GestureDetector(
          onTap: () => onProviderSelected(provider),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected 
                  ? Color(provider.primaryColor).withOpacity(0.15) 
                  : const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: isSelected 
                    ? Color(provider.primaryColor) 
                    : const Color(0xFF2A2A3E),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 32.w,
                  height: 32.h,
                  decoration: BoxDecoration(
                    color: Color(provider.primaryColor),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.bolt,
                    color: Colors.white,
                    size: 18.sp,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  provider.shortName,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFFA1A1B2),
                    fontSize: 10.sp,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MeterInputField extends StatelessWidget {
  final TextEditingController controller;
  final ElectricityProvider? selectedProvider;
  final String? errorText;
  final bool isVerifying;
  final VoidCallback? onVerifyPressed;
  final ValueChanged<String>? onChanged;

  const _MeterInputField({
    required this.controller,
    this.selectedProvider,
    this.errorText,
    this.onChanged,
    this.isVerifying = false,
    this.onVerifyPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Meter Number',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8.h),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: errorText != null 
                  ? const Color(0xFFFF4D4F) 
                  : const Color(0xFF2A2A3E),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF111128),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12.r),
                    bottomLeft: Radius.circular(12.r),
                  ),
                ),
                child: Icon(
                  Icons.electric_meter,
                  color: selectedProvider != null 
                      ? Color(selectedProvider!.primaryColor) 
                      : const Color(0xFFA1A1B2),
                  size: 22.sp,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter meter number',
                    hintStyle: TextStyle(
                      color: const Color(0xFF6B7280),
                      fontSize: 16.sp,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
                  ),
                  onChanged: onChanged,
                ),
              ),
              
              // Verify Button suffix
              if (onVerifyPressed != null)
                GestureDetector(
                  onTap: isVerifying ? null : onVerifyPressed,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    color: Colors.transparent, // Hit test area
                    child: Center(
                      child:
                          isVerifying
                              ? SizedBox(
                                width: 20.w,
                                height: 20.w,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : Text(
                                'Verify',
                                style: TextStyle(
                                  color: const Color(0xFF1E88E5),
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (errorText != null) ...[
          SizedBox(height: 6.h),
          Text(
            errorText!,
            style: TextStyle(
              color: const Color(0xFFFF4D4F),
              fontSize: 12.sp,
            ),
          ),
        ],
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final double amountNaira;
  final ElectricityProvider? provider;

  const _SummaryCard({
    required this.amountNaira,
    this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: VtuService.nairaToSats(amountNaira),
      builder: (context, snapshot) {
        final sats = snapshot.data ?? 0;
        final color = provider != null ? Color(provider!.primaryColor) : const Color(0xFF1E88E5);
        
        return Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Electricity Units',
                    style: TextStyle(
                      color: const Color(0xFFA1A1B2),
                      fontSize: 14.sp,
                    ),
                  ),
                  Text(
                    RateService.formatNaira(amountNaira),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'You Pay',
                    style: TextStyle(
                      color: const Color(0xFFA1A1B2),
                      fontSize: 14.sp,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.flash_on, color: color, size: 16.sp),
                      SizedBox(width: 4.w),
                      Text(
                        '${sats.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} sats',
                        style: TextStyle(
                          color: color,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
