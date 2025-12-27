import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/services/rate_service.dart';
import '../../data/models/models.dart';
import '../../services/vtu_service.dart';
import '../widgets/network_selector.dart';
import '../widgets/phone_input_with_contacts.dart';
import '../widgets/amount_selector.dart';
import 'vtu_confirm_screen.dart';
import 'vtu_order_history_screen.dart';

class AirtimeScreen extends ConsumerStatefulWidget {
  const AirtimeScreen({super.key});

  @override
  ConsumerState<AirtimeScreen> createState() => _AirtimeScreenState();
}

class _AirtimeScreenState extends ConsumerState<AirtimeScreen> {
  final _phoneController = TextEditingController();
  final _customAmountController = TextEditingController();
  NetworkProvider? _selectedNetwork;
  double? _selectedAmount;
  String? _phoneError;
  bool _useCustomAmount = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _customAmountController.dispose();
    super.dispose();
  }

  void _onPhoneChanged(String value) {
    setState(() {
      _phoneError = null;
      // Auto-detect network from phone prefix
      final detected = NetworkProviderExtension.detectFromPhone(value);
      if (detected != null && _selectedNetwork == null) {
        _selectedNetwork = detected;
      }
    });
  }

  void _onNetworkSelected(NetworkProvider network) {
    setState(() {
      _selectedNetwork = network;
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
    final phone = VtuService.formatPhoneNumber(_phoneController.text);
    return _selectedNetwork != null &&
        VtuService.isValidNigerianPhone(phone) &&
        _selectedAmount != null &&
        _selectedAmount! >= 50;
  }

  void _proceedToConfirm() {
    final phone = VtuService.formatPhoneNumber(_phoneController.text);

    if (!VtuService.isValidNigerianPhone(phone)) {
      setState(() {
        _phoneError = 'Please enter a valid 11-digit Nigerian phone number';
      });
      return;
    }

    if (_selectedNetwork == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a network')),
      );
      return;
    }

    if (_selectedAmount == null || _selectedAmount! < 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an amount (min ₦50)')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VtuConfirmScreen(
          serviceType: VtuServiceType.airtime,
          recipient: phone,
          amountNaira: _selectedAmount!,
          network: _selectedNetwork,
          networkCode: _selectedNetwork!.code,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amounts = VtuService.getAirtimeAmounts();

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
          'Buy Airtime',
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
                    // Network Selection
                    NetworkSelector(
                      selectedNetwork: _selectedNetwork,
                      onNetworkSelected: _onNetworkSelected,
                    ),
                    SizedBox(height: 24.h),

                    // Phone Number Input
                    PhoneInputWithContacts(
                      controller: _phoneController,
                      detectedNetwork: _selectedNetwork?.name,
                      networkColor: _selectedNetwork != null 
                          ? Color(_selectedNetwork!.primaryColor) 
                          : null,
                      errorText: _phoneError,
                      onChanged: _onPhoneChanged,
                      accentColor: _selectedNetwork != null 
                          ? Color(_selectedNetwork!.primaryColor) 
                          : const Color(0xFFF7931A),
                    ),
                    SizedBox(height: 24.h),

                    // Amount Selection
                    AmountSelector(
                      amounts: amounts,
                      selectedAmount: _useCustomAmount ? null : _selectedAmount,
                      onAmountSelected: _onAmountSelected,
                      accentColor: _selectedNetwork != null 
                          ? Color(_selectedNetwork!.primaryColor) 
                          : const Color(0xFFF7931A),
                    ),
                    SizedBox(height: 20.h),

                    // Custom Amount Input
                    CustomAmountInput(
                      controller: _customAmountController,
                      onChanged: _onCustomAmountChanged,
                      minAmount: 50,
                      maxAmount: 50000,
                    ),
                    SizedBox(height: 24.h),

                    // Summary Card
                    if (_selectedAmount != null && _selectedAmount! >= 50) ...[
                      _SummaryCard(
                        amountNaira: _selectedAmount!,
                        network: _selectedNetwork,
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
                      backgroundColor: _selectedNetwork != null 
                          ? Color(_selectedNetwork!.primaryColor) 
                          : const Color(0xFFF7931A),
                      disabledBackgroundColor: const Color(0xFF2A2A3E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: Text(
                      'Continue',
                      style: TextStyle(
                        color: _selectedNetwork == NetworkProvider.mtn 
                            ? Colors.black 
                            : Colors.white,
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

class _SummaryCard extends StatelessWidget {
  final double amountNaira;
  final NetworkProvider? network;

  const _SummaryCard({
    required this.amountNaira,
    this.network,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: VtuService.nairaToSats(amountNaira),
      builder: (context, snapshot) {
        final sats = snapshot.data ?? 0;
        final color = network != null ? Color(network!.primaryColor) : const Color(0xFFF7931A);
        
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
                    'Airtime Value',
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
