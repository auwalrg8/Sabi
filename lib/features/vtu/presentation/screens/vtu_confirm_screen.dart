import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/services/rate_service.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';
import '../../data/models/models.dart';
import '../../services/vtu_service.dart';
import '../providers/vtu_providers.dart';
import 'vtu_success_screen.dart';

class VtuConfirmScreen extends ConsumerStatefulWidget {
  final VtuServiceType serviceType;
  final String recipient;
  final double amountNaira;
  final NetworkProvider? network;
  final String? networkCode;
  final DataPlan? dataPlan;
  final ElectricityProvider? electricityProvider;
  final MeterType? meterType;
  final String? variationId; // For live API data plans
  final CableTvProvider? cableTvProvider;
  final String? cableTvPlanName;
  final String? phone; // Contact phone for notifications

  const VtuConfirmScreen({
    super.key,
    required this.serviceType,
    required this.recipient,
    required this.amountNaira,
    this.network,
    this.networkCode,
    this.dataPlan,
    this.electricityProvider,
    this.meterType,
    this.variationId,
    this.cableTvProvider,
    this.cableTvPlanName,
    this.phone,
  });

  @override
  ConsumerState<VtuConfirmScreen> createState() => _VtuConfirmScreenState();
}

class _VtuConfirmScreenState extends ConsumerState<VtuConfirmScreen> {
  bool _isProcessing = false;
  int _amountSats = 0;
  int _userBalance = 0;
  bool _hasSufficientBalance = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPaymentInfo();
  }

  Future<void> _loadPaymentInfo() async {
    try {
      final sats = await VtuService.nairaToSats(widget.amountNaira);
      final balance = await BreezSparkService.getBalance();

      setState(() {
        _amountSats = sats;
        _userBalance = balance;
        _hasSufficientBalance = balance >= sats;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load payment info';
      });
    }
  }

  Color get _accentColor {
    if (widget.network != null) {
      return Color(widget.network!.primaryColor);
    }
    if (widget.electricityProvider != null) {
      return Color(widget.electricityProvider!.primaryColor);
    }
    if (widget.cableTvProvider != null) {
      return Color(widget.cableTvProvider!.primaryColor);
    }
    return const Color(0xFFF7931A);
  }

  String get _serviceTitle {
    switch (widget.serviceType) {
      case VtuServiceType.airtime:
        return '${widget.network?.name ?? ''} Airtime';
      case VtuServiceType.data:
        return '${widget.network?.name ?? ''} Data';
      case VtuServiceType.electricity:
        return '${widget.electricityProvider?.shortName ?? ''} Electricity';
      case VtuServiceType.cableTv:
        return '${widget.cableTvProvider?.name ?? ''} Cable TV';
    }
  }

  IconData get _serviceIcon {
    switch (widget.serviceType) {
      case VtuServiceType.airtime:
        return Icons.phone_android;
      case VtuServiceType.data:
        return Icons.wifi;
      case VtuServiceType.electricity:
        return Icons.bolt;
      case VtuServiceType.cableTv:
        return Icons.tv;
    }
  }

  Future<void> _processPayment() async {
    if (!_hasSufficientBalance) {
      _showInsufficientBalanceDialog();
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      VtuOrder completedOrder;

      switch (widget.serviceType) {
        case VtuServiceType.airtime:
          completedOrder = await VtuService.processAirtimePurchase(
            phone: widget.recipient,
            networkCode: widget.networkCode ?? widget.network?.code ?? 'mtn',
            amountNaira: widget.amountNaira,
          );
          break;

        case VtuServiceType.data:
          completedOrder = await VtuService.processDataPurchase(
            phone: widget.recipient,
            networkCode: widget.networkCode ?? widget.network?.code ?? 'mtn',
            variationId: widget.variationId ?? widget.dataPlan?.id ?? '',
            amountNaira: widget.amountNaira,
            planName: widget.dataPlan?.name ?? 'Data Bundle',
          );
          break;

        case VtuServiceType.electricity:
          completedOrder = await VtuService.processElectricityPurchase(
            meterNumber: widget.recipient,
            discoCode: widget.electricityProvider?.code ?? '',
            meterType: widget.meterType?.code ?? 'prepaid',
            amountNaira: widget.amountNaira,
            phone: widget.phone ?? widget.recipient, // Use phone or meter for notifications
          );
          break;

        case VtuServiceType.cableTv:
          completedOrder = await VtuService.processCableTvPurchase(
            smartcardNumber: widget.recipient,
            providerCode: widget.cableTvProvider?.code ?? '',
            variationId: widget.variationId ?? '',
            amountNaira: widget.amountNaira,
            planName: widget.cableTvPlanName ?? 'Cable TV Subscription',
            phone: widget.phone ?? '',
          );
          break;
      }

      // Refresh orders list
      ref.read(vtuOrdersProvider.notifier).refresh();

      if (!mounted) return;

      // Navigate to success screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VtuSuccessScreen(order: completedOrder),
        ),
      );
    } on InsufficientBalanceException catch (e) {
      setState(() {
        _isProcessing = false;
        _hasSufficientBalance = false;
        _errorMessage = 'Insufficient balance: need ${e.required} sats';
      });
      _showInsufficientBalanceDialog();
    } on PaymentFailedException catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Payment failed: ${e.message}';
      });
      _showPaymentFailedDialog(e.message);
    } on VtuDeliveryException catch (e) {
      // Payment was made but delivery failed
      setState(() {
        _isProcessing = false;
        _errorMessage = e.message;
      });
      if (e.isVtuLiquidityIssue) {
        _showVtuLiquidityDialog(e.message);
      } else if (e.isServiceUnavailable) {
        _showServiceUnavailableDialog(e.message);
      } else {
        _showDeliveryFailedDialog(e.message, isRecoverable: e.isRecoverable);
      }
    } on VtuNetworkException catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = e.message;
      });
      _showNetworkErrorDialog(e.message);
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = e.toString();
      });
      _showErrorSnackbar('Error: ${e.toString()}');
    }
  }

  void _showInsufficientBalanceDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.orange,
                  size: 24.sp,
                ),
                SizedBox(width: 8.w),
                const Text(
                  'Insufficient Balance',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You need $_amountSats sats for this purchase.',
                  style: TextStyle(
                    color: const Color(0xFFA1A1B2),
                    fontSize: 14.sp,
                  ),
                ),
                SizedBox(height: 12.h),
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C0C1A),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Your Balance:',
                        style: TextStyle(
                          color: const Color(0xFFA1A1B2),
                          fontSize: 13.sp,
                        ),
                      ),
                      Text(
                        '$_userBalance sats',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8.h),
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Shortfall:',
                        style: TextStyle(
                          color: const Color(0xFFA1A1B2),
                          fontSize: 13.sp,
                        ),
                      ),
                      Text(
                        '${_amountSats - _userBalance} sats',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
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
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Color(0xFFA1A1B2)),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Navigate to receive/fund screen
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF7931A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: const Text(
                  'Add Funds',
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ],
          ),
    );
  }

  void _showDeliveryFailedDialog(String message, {bool isRecoverable = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 24.sp,
                ),
                SizedBox(width: 8.w),
                const Text(
                  'Delivery Issue',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Your payment was successful, but delivery encountered an issue:',
                  style: TextStyle(
                    color: const Color(0xFFA1A1B2),
                    fontSize: 14.sp,
                  ),
                ),
                SizedBox(height: 12.h),
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    message,
                    style: TextStyle(color: Colors.orange, fontSize: 13.sp),
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  isRecoverable
                      ? 'This issue may be temporary. You can try again or contact support.'
                      : 'Don\'t worry! Your order has been recorded and our team will process it manually. You\'ll receive your service shortly.',
                  style: TextStyle(
                    color: const Color(0xFFA1A1B2),
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
            actions: [
              if (isRecoverable)
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _processPayment(); // Retry
                  },
                  child: const Text(
                    'Retry',
                    style: TextStyle(color: Color(0xFFF7931A)),
                  ),
                ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context); // Go back to previous screen
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: Text(
                  'Understood',
                  style: TextStyle(
                    color:
                        widget.network == NetworkProvider.mtn
                            ? Colors.black
                            : Colors.white,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  void _showPaymentFailedDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
            title: Row(
              children: [
                Icon(Icons.payment, color: Colors.red, size: 24.sp),
                SizedBox(width: 8.w),
                const Text(
                  'Payment Failed',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'The Lightning payment could not be completed:',
                  style: TextStyle(
                    color: const Color(0xFFA1A1B2),
                    fontSize: 14.sp,
                  ),
                ),
                SizedBox(height: 12.h),
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    message,
                    style: TextStyle(color: Colors.red, fontSize: 13.sp),
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  'No funds have been deducted. Please check your wallet connection and try again.',
                  style: TextStyle(
                    color: const Color(0xFFA1A1B2),
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Color(0xFFA1A1B2)),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _processPayment(); // Retry
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: const Text(
                  'Try Again',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  void _showVtuLiquidityDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
            title: Row(
              children: [
                Icon(Icons.account_balance, color: Colors.orange, size: 24.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'Service Temporarily Unavailable',
                    style: TextStyle(color: Colors.white, fontSize: 16.sp),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.orange,
                        size: 20.sp,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          'Our VTU provider is experiencing liquidity issues.',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 13.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'Your payment was successful and has been recorded. Our team has been notified and will process your order as soon as the service is restored.',
                  style: TextStyle(
                    color: const Color(0xFFA1A1B2),
                    fontSize: 13.sp,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  'Expected resolution: Within 1-2 hours',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: const Text(
                  'Understood',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  void _showServiceUnavailableDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
            title: Row(
              children: [
                Icon(Icons.cloud_off, color: Colors.grey, size: 24.sp),
                SizedBox(width: 8.w),
                const Text(
                  'Service Unavailable',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'The VTU service is temporarily unavailable:',
                  style: TextStyle(
                    color: const Color(0xFFA1A1B2),
                    fontSize: 14.sp,
                  ),
                ),
                SizedBox(height: 12.h),
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C0C1A),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    message,
                    style: TextStyle(
                      color: const Color(0xFFA1A1B2),
                      fontSize: 13.sp,
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  'Please try again in a few minutes. If the issue persists, contact support.',
                  style: TextStyle(
                    color: const Color(0xFFA1A1B2),
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Color(0xFFA1A1B2)),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _processPayment(); // Retry
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: const Text(
                  'Try Again',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  void _showNetworkErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
            title: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.red, size: 24.sp),
                SizedBox(width: 8.w),
                const Text(
                  'Connection Error',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Unable to connect to the service:',
                  style: TextStyle(
                    color: const Color(0xFFA1A1B2),
                    fontSize: 14.sp,
                  ),
                ),
                SizedBox(height: 12.h),
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.signal_wifi_off,
                        color: Colors.red,
                        size: 20.sp,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          message,
                          style: TextStyle(color: Colors.red, fontSize: 13.sp),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  'Please check your internet connection and try again.',
                  style: TextStyle(
                    color: const Color(0xFFA1A1B2),
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Color(0xFFA1A1B2)),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _processPayment(); // Retry
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
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
          'Confirm Purchase',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20.w),
                child: Column(
                  children: [
                    SizedBox(height: 20.h),

                    // Service Icon
                    Container(
                      width: 80.w,
                      height: 80.h,
                      decoration: BoxDecoration(
                        color: _accentColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _accentColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Icon(
                        _serviceIcon,
                        color: _accentColor,
                        size: 40.sp,
                      ),
                    ),
                    SizedBox(height: 16.h),

                    Text(
                      _serviceTitle,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 32.h),

                    // Details Card
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(20.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111128),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: const Color(0xFF2A2A3E)),
                      ),
                      child: Column(
                        children: [
                          _DetailRow(
                            label:
                                widget.serviceType == VtuServiceType.electricity
                                    ? 'Meter Number'
                                    : 'Phone Number',
                            value: widget.recipient,
                          ),
                          Divider(color: const Color(0xFF2A2A3E), height: 24.h),

                          if (widget.dataPlan != null) ...[
                            _DetailRow(
                              label: 'Data Plan',
                              value:
                                  '${widget.dataPlan!.dataAmount} - ${widget.dataPlan!.validity}',
                            ),
                            Divider(
                              color: const Color(0xFF2A2A3E),
                              height: 24.h,
                            ),
                          ],

                          if (widget.meterType != null) ...[
                            _DetailRow(
                              label: 'Meter Type',
                              value: widget.meterType!.name,
                            ),
                            Divider(
                              color: const Color(0xFF2A2A3E),
                              height: 24.h,
                            ),
                          ],

                          _DetailRow(
                            label: 'Amount',
                            value: RateService.formatNaira(widget.amountNaira),
                            valueColor: Colors.white,
                          ),
                          Divider(color: const Color(0xFF2A2A3E), height: 24.h),

                          _DetailRow(
                            label: 'You Pay',
                            value: '$_amountSats sats',
                            valueColor: _accentColor,
                            isHighlighted: true,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24.h),

                    // Balance Info Card
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color:
                            _hasSufficientBalance
                                ? const Color(0xFF0D2818)
                                : Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color:
                              _hasSufficientBalance
                                  ? const Color(
                                    0xFF22C55E,
                                  ).withValues(alpha: 0.3)
                                  : Colors.red.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _hasSufficientBalance
                                ? Icons.check_circle
                                : Icons.error_outline,
                            color:
                                _hasSufficientBalance
                                    ? const Color(0xFF22C55E)
                                    : Colors.red,
                            size: 20.sp,
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your Balance',
                                  style: TextStyle(
                                    color: const Color(0xFFA1A1B2),
                                    fontSize: 12.sp,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  '$_userBalance sats',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_hasSufficientBalance)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 4.h,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF22C55E,
                                ).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                              child: Text(
                                'Sufficient',
                                style: TextStyle(
                                  color: const Color(0xFF22C55E),
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 4.h,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                              child: Text(
                                'Insufficient',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Auto-pay Notice
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A2E),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.flash_on,
                            color: const Color(0xFFF7931A),
                            size: 18.sp,
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Text(
                              'Payment will be deducted automatically from your wallet and service delivered instantly.',
                              style: TextStyle(
                                color: const Color(0xFFA1A1B2),
                                fontSize: 12.sp,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Error message
                    if (_errorMessage != null) ...[
                      SizedBox(height: 16.h),
                      Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 18.sp,
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12.sp,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom Buttons
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
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 52.h,
                      child: ElevatedButton(
                        onPressed:
                            _isProcessing || !_hasSufficientBalance
                                ? null
                                : _processPayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _hasSufficientBalance
                                  ? _accentColor
                                  : const Color(0xFF2A2A3E),
                          disabledBackgroundColor: const Color(0xFF2A2A3E),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child:
                            _isProcessing
                                ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20.w,
                                      height: 20.h,
                                      child: const CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 12.w),
                                    Text(
                                      'Processing...',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                )
                                : Text(
                                  _hasSufficientBalance
                                      ? 'Pay Now'
                                      : 'Insufficient Balance',
                                  style: TextStyle(
                                    color:
                                        widget.network == NetworkProvider.mtn &&
                                                _hasSufficientBalance
                                            ? Colors.black
                                            : Colors.white,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    TextButton(
                      onPressed:
                          _isProcessing ? null : () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: const Color(0xFFA1A1B2),
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isHighlighted;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 14.sp),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? const Color(0xFFA1A1B2),
            fontSize: isHighlighted ? 18.sp : 14.sp,
            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
