import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/services/rate_service.dart';
import '../../data/models/models.dart';
import '../../services/vtu_service.dart';
import '../../services/vtu_api_service.dart';
import 'vtu_confirm_screen.dart';
import 'vtu_order_history_screen.dart';

class CableTvScreen extends ConsumerStatefulWidget {
  const CableTvScreen({super.key});

  @override
  ConsumerState<CableTvScreen> createState() => _CableTvScreenState();
}

class _CableTvScreenState extends ConsumerState<CableTvScreen> {
  final _smartcardController = TextEditingController();
  final _phoneController = TextEditingController();
  CableTvProvider? _selectedProvider;
  VtuCableTvPlan? _selectedPlan;
  VtuCableTvCustomerInfo? _customerInfo;
  List<VtuCableTvPlan> _plans = [];
  bool _isLoadingPlans = false;
  bool _isVerifying = false;
  String? _smartcardError;
  String? _verificationError;

  @override
  void dispose() {
    _smartcardController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onProviderSelected(CableTvProvider provider) async {
    setState(() {
      _selectedProvider = provider;
      _selectedPlan = null;
      _plans = [];
      _customerInfo = null;
      _verificationError = null;
      _isLoadingPlans = true;
    });

    // Load plans for this provider
    final plans = await VtuService.getCableTvPlans(provider.code);

    setState(() {
      _plans = plans;
      _isLoadingPlans = false;
    });
  }

  void _onPlanSelected(VtuCableTvPlan plan) {
    setState(() {
      _selectedPlan = plan;
    });
  }

  Future<void> _verifySmartcard() async {
    final smartcard = _smartcardController.text.trim();

    if (!VtuService.isValidSmartcardNumber(smartcard)) {
      setState(() {
        _smartcardError =
            'Please enter a valid smartcard number (10-11 digits)';
      });
      return;
    }

    if (_selectedProvider == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a provider first')),
      );
      return;
    }

    setState(() {
      _isVerifying = true;
      _smartcardError = null;
      _verificationError = null;
      _customerInfo = null;
    });

    final info = await VtuService.verifyCableTvCustomer(
      smartcardNumber: smartcard,
      providerCode: _selectedProvider!.code,
    );

    setState(() {
      _isVerifying = false;
      if (info != null && info.isValid) {
        _customerInfo = info;
      } else {
        _verificationError =
            'Could not verify smartcard. Please check the number and try again.';
      }
    });
  }

  bool get _isFormValid {
    return _selectedProvider != null &&
        _selectedPlan != null &&
        _customerInfo != null &&
        _customerInfo!.isValid;
  }

  void _proceedToConfirm() {
    if (!_isFormValid) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => VtuConfirmScreen(
              serviceType: VtuServiceType.cableTv,
              recipient: _smartcardController.text.trim(),
              amountNaira: _selectedPlan!.displayPrice,
              cableTvProvider: _selectedProvider,
              variationId: _selectedPlan!.variationId,
              cableTvPlanName: _selectedPlan!.name,
              phone: _phoneController.text.trim(),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          'Cable TV',
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
                      'Select Provider',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    _ProviderSelector(
                      selectedProvider: _selectedProvider,
                      onProviderSelected: _onProviderSelected,
                    ),
                    SizedBox(height: 24.h),

                    // Smartcard Number Input
                    _SmartcardInputField(
                      controller: _smartcardController,
                      selectedProvider: _selectedProvider,
                      errorText: _smartcardError,
                      onChanged: (value) {
                        setState(() {
                          _smartcardError = null;
                          _customerInfo = null;
                          _verificationError = null;
                        });
                      },
                    ),
                    SizedBox(height: 12.h),

                    // Verify Button
                    if (_selectedProvider != null) ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _isVerifying ? null : _verifySmartcard,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Color(_selectedProvider!.primaryColor),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          child:
                              _isVerifying
                                  ? SizedBox(
                                    width: 20.w,
                                    height: 20.h,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(
                                        _selectedProvider!.primaryColor,
                                      ),
                                    ),
                                  )
                                  : Text(
                                    'Verify Smartcard',
                                    style: TextStyle(
                                      color: Color(
                                        _selectedProvider!.primaryColor,
                                      ),
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                        ),
                      ),
                    ],
                    SizedBox(height: 12.h),

                    // Verification Error
                    if (_verificationError != null) ...[
                      Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4D4F).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(
                            color: const Color(0xFFFF4D4F).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: const Color(0xFFFF4D4F),
                              size: 20.sp,
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                _verificationError!,
                                style: TextStyle(
                                  color: const Color(0xFFFF4D4F),
                                  fontSize: 13.sp,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),
                    ],

                    // Customer Info Card
                    if (_customerInfo != null) ...[
                      _CustomerInfoCard(
                        customerInfo: _customerInfo!,
                        provider: _selectedProvider,
                      ),
                      SizedBox(height: 24.h),
                    ],

                    // Phone Number Input (for notification)
                    if (_customerInfo != null) ...[
                      _PhoneInputField(
                        controller: _phoneController,
                        selectedProvider: _selectedProvider,
                      ),
                      SizedBox(height: 24.h),
                    ],

                    // Plan Selection
                    if (_customerInfo != null && _plans.isNotEmpty) ...[
                      Text(
                        'Select Package',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      _PlansList(
                        plans: _plans,
                        selectedPlan: _selectedPlan,
                        onPlanSelected: _onPlanSelected,
                        provider: _selectedProvider,
                      ),
                      SizedBox(height: 24.h),
                    ],

                    // Loading Plans
                    if (_isLoadingPlans) ...[
                      Center(
                        child: Column(
                          children: [
                            SizedBox(
                              width: 30.w,
                              height: 30.h,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color:
                                    _selectedProvider != null
                                        ? Color(_selectedProvider!.primaryColor)
                                        : const Color(0xFF1E88E5),
                              ),
                            ),
                            SizedBox(height: 12.h),
                            Text(
                              'Loading packages...',
                              style: TextStyle(
                                color: const Color(0xFFA1A1B2),
                                fontSize: 14.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24.h),
                    ],

                    // Summary Card
                    if (_selectedPlan != null) ...[
                      _SummaryCard(
                        plan: _selectedPlan!,
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
                      backgroundColor:
                          _selectedProvider != null
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

class _ProviderSelector extends StatelessWidget {
  final CableTvProvider? selectedProvider;
  final ValueChanged<CableTvProvider> onProviderSelected;

  const _ProviderSelector({
    this.selectedProvider,
    required this.onProviderSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children:
          CableTvProvider.values.map((provider) {
            final isSelected = selectedProvider == provider;
            return Expanded(
              child: GestureDetector(
                onTap: () => onProviderSelected(provider),
                child: Container(
                  margin: EdgeInsets.only(
                    right: provider != CableTvProvider.values.last ? 10.w : 0,
                  ),
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? Color(provider.primaryColor).withOpacity(0.15)
                            : const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color:
                          isSelected
                              ? Color(provider.primaryColor)
                              : const Color(0xFF2A2A3E),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 40.w,
                        height: 40.h,
                        decoration: BoxDecoration(
                          color: Color(provider.primaryColor),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Icon(Icons.tv, color: Colors.white, size: 22.sp),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        provider.name,
                        style: TextStyle(
                          color:
                              isSelected
                                  ? Colors.white
                                  : const Color(0xFFA1A1B2),
                          fontSize: 12.sp,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }
}

class _SmartcardInputField extends StatelessWidget {
  final TextEditingController controller;
  final CableTvProvider? selectedProvider;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const _SmartcardInputField({
    required this.controller,
    this.selectedProvider,
    this.errorText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Smartcard / IUC Number',
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
              color:
                  errorText != null
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
                  Icons.credit_card,
                  color:
                      selectedProvider != null
                          ? Color(selectedProvider!.primaryColor)
                          : const Color(0xFFA1A1B2),
                  size: 22.sp,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: Colors.white, fontSize: 16.sp),
                  decoration: InputDecoration(
                    hintText: 'Enter smartcard number',
                    hintStyle: TextStyle(
                      color: const Color(0xFF6B7280),
                      fontSize: 16.sp,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 14.h,
                    ),
                  ),
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
        if (errorText != null) ...[
          SizedBox(height: 6.h),
          Text(
            errorText!,
            style: TextStyle(color: const Color(0xFFFF4D4F), fontSize: 12.sp),
          ),
        ],
      ],
    );
  }
}

class _PhoneInputField extends StatelessWidget {
  final TextEditingController controller;
  final CableTvProvider? selectedProvider;

  const _PhoneInputField({required this.controller, this.selectedProvider});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Phone Number (for notification)',
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
            border: Border.all(color: const Color(0xFF2A2A3E)),
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
                  Icons.phone,
                  color:
                      selectedProvider != null
                          ? Color(selectedProvider!.primaryColor)
                          : const Color(0xFFA1A1B2),
                  size: 22.sp,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: Colors.white, fontSize: 16.sp),
                  decoration: InputDecoration(
                    hintText: 'Enter phone number',
                    hintStyle: TextStyle(
                      color: const Color(0xFF6B7280),
                      fontSize: 16.sp,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 14.h,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CustomerInfoCard extends StatelessWidget {
  final VtuCableTvCustomerInfo customerInfo;
  final CableTvProvider? provider;

  const _CustomerInfoCard({required this.customerInfo, this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle,
                color: const Color(0xFF10B981),
                size: 20.sp,
              ),
              SizedBox(width: 8.w),
              Text(
                'Customer Verified',
                style: TextStyle(
                  color: const Color(0xFF10B981),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          _InfoRow(label: 'Name', value: customerInfo.customerName),
          if (customerInfo.currentBouquet.isNotEmpty) ...[
            SizedBox(height: 8.h),
            _InfoRow(
              label: 'Current Package',
              value: customerInfo.currentBouquet,
            ),
          ],
          if (customerInfo.dueDate.isNotEmpty) ...[
            SizedBox(height: 8.h),
            _InfoRow(label: 'Due Date', value: customerInfo.dueDate),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 13.sp),
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _PlansList extends StatelessWidget {
  final List<VtuCableTvPlan> plans;
  final VtuCableTvPlan? selectedPlan;
  final ValueChanged<VtuCableTvPlan> onPlanSelected;
  final CableTvProvider? provider;

  const _PlansList({
    required this.plans,
    this.selectedPlan,
    required this.onPlanSelected,
    this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        provider != null
            ? Color(provider!.primaryColor)
            : const Color(0xFF1E88E5);

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: plans.length,
      separatorBuilder: (_, __) => SizedBox(height: 10.h),
      itemBuilder: (context, index) {
        final plan = plans[index];
        final isSelected = selectedPlan?.variationId == plan.variationId;

        return GestureDetector(
          onTap: () => onPlanSelected(plan),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color:
                  isSelected ? color.withOpacity(0.1) : const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: isSelected ? color : const Color(0xFF2A2A3E),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44.w,
                  height: 44.h,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(Icons.live_tv, color: color, size: 22.sp),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        plan.validity,
                        style: TextStyle(
                          color: const Color(0xFFA1A1B2),
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      RateService.formatNaira(plan.displayPrice),
                      style: TextStyle(
                        color: color,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final VtuCableTvPlan plan;
  final CableTvProvider? provider;

  const _SummaryCard({required this.plan, this.provider});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: VtuService.nairaToSats(plan.displayPrice),
      builder: (context, snapshot) {
        final sats = snapshot.data ?? 0;
        final color =
            provider != null
                ? Color(provider!.primaryColor)
                : const Color(0xFF1E88E5);

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
                    'Package',
                    style: TextStyle(
                      color: const Color(0xFFA1A1B2),
                      fontSize: 14.sp,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      plan.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Amount',
                    style: TextStyle(
                      color: const Color(0xFFA1A1B2),
                      fontSize: 14.sp,
                    ),
                  ),
                  Text(
                    RateService.formatNaira(plan.displayPrice),
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
