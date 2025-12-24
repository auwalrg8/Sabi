import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/services/rate_service.dart';
import '../../data/models/models.dart';
import '../../services/vtu_service.dart';
import '../widgets/network_selector.dart';
import '../widgets/phone_input_field.dart';
import 'vtu_confirm_screen.dart';
import 'vtu_order_history_screen.dart';

class DataScreen extends ConsumerStatefulWidget {
  const DataScreen({super.key});

  @override
  ConsumerState<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends ConsumerState<DataScreen> {
  final _phoneController = TextEditingController();
  NetworkProvider? _selectedNetwork;
  DataPlan? _selectedPlan;
  String? _phoneError;

  @override
  void dispose() {
    _phoneController.dispose();
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
      _selectedPlan = null; // Reset plan when network changes
    });
  }

  void _onPlanSelected(DataPlan plan) {
    setState(() {
      _selectedPlan = plan;
    });
  }

  bool get _isFormValid {
    final phone = VtuService.formatPhoneNumber(_phoneController.text);
    return _selectedNetwork != null &&
        VtuService.isValidNigerianPhone(phone) &&
        _selectedPlan != null;
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

    if (_selectedPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a data plan')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VtuConfirmScreen(
          serviceType: VtuServiceType.data,
          recipient: phone,
          amountNaira: _selectedPlan!.priceNaira,
          network: _selectedNetwork,
          networkCode: _selectedNetwork!.code,
          dataPlan: _selectedPlan,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plans = _selectedNetwork != null
        ? DataPlan.getPlansForNetwork(_selectedNetwork!)
        : <DataPlan>[];

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
          'Buy Data',
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
                    PhoneInputField(
                      controller: _phoneController,
                      detectedNetwork: _selectedNetwork?.name,
                      networkColor: _selectedNetwork != null 
                          ? Color(_selectedNetwork!.primaryColor) 
                          : null,
                      errorText: _phoneError,
                      onChanged: _onPhoneChanged,
                    ),
                    SizedBox(height: 24.h),

                    // Data Plans
                    if (_selectedNetwork != null) ...[
                      Text(
                        'Select Data Plan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: plans.length,
                        separatorBuilder: (_, __) => SizedBox(height: 10.h),
                        itemBuilder: (context, index) {
                          final plan = plans[index];
                          final isSelected = _selectedPlan?.id == plan.id;
                          return _DataPlanCard(
                            plan: plan,
                            isSelected: isSelected,
                            accentColor: Color(_selectedNetwork!.primaryColor),
                            onTap: () => _onPlanSelected(plan),
                          );
                        },
                      ),
                    ] else ...[
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(32.w),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A2E),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: const Color(0xFF2A2A3E)),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.wifi,
                              color: const Color(0xFF6B7280),
                              size: 48.sp,
                            ),
                            SizedBox(height: 12.h),
                            Text(
                              'Select a network to view data plans',
                              style: TextStyle(
                                color: const Color(0xFFA1A1B2),
                                fontSize: 14.sp,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                    SizedBox(height: 24.h),

                    // Summary Card
                    if (_selectedPlan != null) ...[
                      _SummaryCard(
                        plan: _selectedPlan!,
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

class _DataPlanCard extends StatelessWidget {
  final DataPlan plan;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;

  const _DataPlanCard({
    required this.plan,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: isSelected 
              ? accentColor.withOpacity(0.1) 
              : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected ? accentColor : const Color(0xFF2A2A3E),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48.w,
              height: 48.h,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Center(
                child: Text(
                  plan.dataAmount,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.description,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Valid for ${plan.validity}',
                    style: TextStyle(
                      color: const Color(0xFFA1A1B2),
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  RateService.formatNaira(plan.priceNaira),
                  style: TextStyle(
                    color: isSelected ? accentColor : Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: accentColor,
                    size: 18.sp,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final DataPlan plan;
  final NetworkProvider? network;

  const _SummaryCard({
    required this.plan,
    this.network,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: VtuService.nairaToSats(plan.priceNaira),
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
                    'Data Bundle',
                    style: TextStyle(
                      color: const Color(0xFFA1A1B2),
                      fontSize: 14.sp,
                    ),
                  ),
                  Text(
                    '${plan.dataAmount} - ${plan.validity}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Price',
                    style: TextStyle(
                      color: const Color(0xFFA1A1B2),
                      fontSize: 14.sp,
                    ),
                  ),
                  Text(
                    RateService.formatNaira(plan.priceNaira),
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
