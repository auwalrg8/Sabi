import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/services/rate_service.dart';
import '../../data/models/models.dart';
import '../../services/vtu_service.dart';
import '../../services/vtu_api_service.dart';
import '../widgets/network_selector.dart';
import '../widgets/phone_input_with_contacts.dart';
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

  // API data
  List<DataPlan> _apiPlans = [];
  bool _isLoadingPlans = false;
  String? _loadError;

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
        _loadPlansFromApi(detected);
      }
    });
  }

  void _onNetworkSelected(NetworkProvider network) {
    setState(() {
      _selectedNetwork = network;
      _selectedPlan = null; // Reset plan when network changes
    });
    _loadPlansFromApi(network);
  }

  Future<void> _loadPlansFromApi(NetworkProvider network) async {
    setState(() {
      _isLoadingPlans = true;
      _loadError = null;
      _apiPlans = [];
    });

    try {
      final vtuPlans = await VtuApiService.getDataPlans(network.code);
      final plans = vtuPlans.map((p) => p.toDataPlan(network)).toList();

      if (mounted) {
        setState(() {
          _apiPlans = plans;
          _isLoadingPlans = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = 'Failed to load plans. Using offline data.';
          _apiPlans = DataPlan.getPlansForNetwork(network); // Fallback
          _isLoadingPlans = false;
        });
      }
    }
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a network')));
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
        builder:
            (_) => VtuConfirmScreen(
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
    // Group plans by service name
    final groupedPlans = <String, List<DataPlan>>{};
    for (final plan in _apiPlans) {
      final key = plan.serviceName ?? 'Data Plans';
      groupedPlans.putIfAbsent(key, () => []).add(plan);
    }

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
                    PhoneInputWithContacts(
                      controller: _phoneController,
                      detectedNetwork: _selectedNetwork?.name,
                      networkColor:
                          _selectedNetwork != null
                              ? Color(_selectedNetwork!.primaryColor)
                              : null,
                      errorText: _phoneError,
                      onChanged: _onPhoneChanged,
                      accentColor:
                          _selectedNetwork != null
                              ? Color(_selectedNetwork!.primaryColor)
                              : const Color(0xFFF7931A),
                    ),
                    SizedBox(height: 24.h),

                    // Error message if any
                    if (_loadError != null) ...[
                      Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber,
                              color: Colors.orange,
                              size: 18.sp,
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                _loadError!,
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 12.sp,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12.h),
                    ],

                    // Data Plans
                    if (_selectedNetwork != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Select Data Plan',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (_apiPlans.isNotEmpty)
                            Text(
                              '${_apiPlans.length} plans',
                              style: TextStyle(
                                color: const Color(0xFFA1A1B2),
                                fontSize: 12.sp,
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 12.h),

                      if (_isLoadingPlans) ...[
                        _buildLoadingShimmer(),
                      ] else if (groupedPlans.isEmpty) ...[
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
                                Icons.error_outline,
                                color: const Color(0xFF6B7280),
                                size: 48.sp,
                              ),
                              SizedBox(height: 12.h),
                              Text(
                                'No plans available. Try again later.',
                                style: TextStyle(
                                  color: const Color(0xFFA1A1B2),
                                  fontSize: 14.sp,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 12.h),
                              TextButton(
                                onPressed:
                                    () => _loadPlansFromApi(_selectedNetwork!),
                                child: Text(
                                  'Retry',
                                  style: TextStyle(fontSize: 14.sp),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // Grouped plans by service name
                        ...groupedPlans.entries.map((entry) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Service name header
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 6.h,
                                ),
                                decoration: BoxDecoration(
                                  color: Color(
                                    _selectedNetwork!.primaryColor,
                                  ).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                                child: Text(
                                  entry.key,
                                  style: TextStyle(
                                    color: Color(
                                      _selectedNetwork!.primaryColor,
                                    ),
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              SizedBox(height: 8.h),
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: entry.value.length,
                                separatorBuilder:
                                    (_, __) => SizedBox(height: 10.h),
                                itemBuilder: (context, index) {
                                  final plan = entry.value[index];
                                  final isSelected =
                                      _selectedPlan?.id == plan.id;
                                  return _DataPlanCard(
                                    plan: plan,
                                    isSelected: isSelected,
                                    accentColor: Color(
                                      _selectedNetwork!.primaryColor,
                                    ),
                                    onTap: () => _onPlanSelected(plan),
                                  );
                                },
                              ),
                              SizedBox(height: 16.h),
                            ],
                          );
                        }),
                      ],
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
                      backgroundColor:
                          _selectedNetwork != null
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
                        color:
                            _selectedNetwork == NetworkProvider.mtn
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

  Widget _buildLoadingShimmer() {
    return Column(
      children: List.generate(5, (index) {
        return Container(
          margin: EdgeInsets.only(bottom: 10.h),
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: const Color(0xFF2A2A3E)),
          ),
          child: Row(
            children: [
              Container(
                width: 48.w,
                height: 48.h,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A3E),
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14.h,
                      width: 120.w,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A3E),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Container(
                      height: 12.h,
                      width: 80.w,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A3E),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 16.h,
                width: 60.w,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A3E),
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ),
            ],
          ),
        );
      }),
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
    final hasDiscount =
        plan.retailPrice != null && plan.retailPrice! > plan.priceNaira;
    final discountPercent = plan.discountPercent;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color:
              isSelected
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
                // Show reseller price (what customer pays)
                Text(
                  RateService.formatNaira(plan.priceNaira),
                  style: TextStyle(
                    color: isSelected ? accentColor : Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                // Show strikethrough retail price if discounted
                if (hasDiscount) ...[
                  SizedBox(height: 2.h),
                  Text(
                    RateService.formatNaira(plan.retailPrice!),
                    style: TextStyle(
                      color: const Color(0xFF6B7280),
                      fontSize: 11.sp,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 6.w,
                      vertical: 2.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: Text(
                      '-${discountPercent.toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: const Color(0xFF10B981),
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ] else if (isSelected) ...[
                  Icon(Icons.check_circle, color: accentColor, size: 18.sp),
                ],
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

  const _SummaryCard({required this.plan, this.network});

  @override
  Widget build(BuildContext context) {
    final hasDiscount =
        plan.retailPrice != null && plan.retailPrice! > plan.priceNaira;
    final savings = hasDiscount ? plan.retailPrice! - plan.priceNaira : 0.0;

    return FutureBuilder<int>(
      future: VtuService.nairaToSats(plan.priceNaira),
      builder: (context, snapshot) {
        final sats = snapshot.data ?? 0;
        final color =
            network != null
                ? Color(network!.primaryColor)
                : const Color(0xFFF7931A);

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
              // Retail price (strikethrough if discounted)
              if (hasDiscount) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Retail Price',
                      style: TextStyle(
                        color: const Color(0xFF6B7280),
                        fontSize: 13.sp,
                      ),
                    ),
                    Text(
                      RateService.formatNaira(plan.retailPrice!),
                      style: TextStyle(
                        color: const Color(0xFF6B7280),
                        fontSize: 14.sp,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your Price',
                    style: TextStyle(
                      color: const Color(0xFFA1A1B2),
                      fontSize: 14.sp,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        RateService.formatNaira(plan.priceNaira),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (hasDiscount) ...[
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Text(
                            'Save ${RateService.formatNaira(savings)}',
                            style: TextStyle(
                              color: const Color(0xFF10B981),
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
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
