import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/services/rate_service.dart';
import 'tapnob_webview_screen.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';
import '../providers/cash_provider.dart';
import 'cash_history_screen.dart';

class CashScreen extends ConsumerStatefulWidget {
  const CashScreen({super.key});

  @override
  ConsumerState<CashScreen> createState() => _CashScreenState();
}

class _CashScreenState extends ConsumerState<CashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _refreshController;
  double? _liveBtcRate;
  double? _liveUsdtRate;
  bool _isLoadingRates = true;
  final TextEditingController _amountInputController = TextEditingController();
  final formatter = NumberFormat.decimalPattern();

  final List<double> _quickAmounts = [
    5000,
    10000,
    50000,
    100000,
    500000,
    1000000,
  ];

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _loadLiveRates();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _amountInputController.dispose();
    super.dispose();
  }

  Future<void> _loadLiveRates() async {
    if (mounted) setState(() => _isLoadingRates = true);
    try {
      final btc = await RateService.getBtcToNgnRate();
      final usdt = await RateService.getUsdToNgnRate();
      if (!mounted) return;
      setState(() {
        _liveBtcRate = btc;
        _liveUsdtRate = usdt;
        _isLoadingRates = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingRates = false);
    }
  }

  Future<void> _refreshPrice() async {
    _refreshController.forward(from: 0);
    await _loadLiveRates();
    await Future.delayed(const Duration(milliseconds: 400));
    _refreshController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final cashState = ref.watch(cashProvider);
    final cashNotifier = ref.read(cashProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C0C1A),
        elevation: 0,
        title: const Text('Cash'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CashHistoryScreen()),
              );
            },
            icon: Icon(
              Icons.history,
              color: AppColors.textTertiary,
              size: 20.sp,
            ),
          ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: Skeletonizer(
          enabled: _isLoadingRates,
          enableSwitchAnimation: true,
          containersColor: AppColors.surface,
          effect: PulseEffect(
            duration: const Duration(milliseconds: 1000),
            from: AppColors.background,
            to: AppColors.borderColor.withValues(alpha: 0.3),
          ),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                child: Container(
                  padding: EdgeInsets.all(14.h),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.trending_up,
                                color: AppColors.accentGreen,
                                size: 16.sp,
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                'Live Price',
                                style: TextStyle(
                                  color: AppColors.textTertiary,
                                  fontSize: 12.sp,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            _liveBtcRate != null
                                ? '1 BTC = ₦${formatter.format(_liveBtcRate!.toInt())}'
                                : '1 BTC = ₦ ${formatter.format(cashState.btcPrice.toInt())}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            _liveUsdtRate != null
                                ? '1 USDT = ₦${formatter.format(_liveUsdtRate!.toInt())}'
                                : '1 USDT = ₦ ${formatter.format(cashState.buyRate.toInt())}',
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 11.sp,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: _refreshPrice,
                        child: RotationTransition(
                          turns: _refreshController,
                          child: Icon(
                            Icons.refresh,
                            color: const Color(0xFF6B7280),
                            size: 20.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2942),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => cashNotifier.toggleBuySell(true),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            decoration: BoxDecoration(
                              color:
                                  cashState.isBuying
                                      ? AppColors.primary
                                      : Colors.transparent,
                              borderRadius: BorderRadius.circular(9999),
                            ),
                            child: Text(
                              '◉ Buy Bitcoin',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color:
                                    cashState.isBuying
                                        ? AppColors.surface
                                        : AppColors.textTertiary,
                                fontSize: 14.sp,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => cashNotifier.toggleBuySell(false),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            decoration: BoxDecoration(
                              color:
                                  !cashState.isBuying
                                      ? AppColors.primary
                                      : Colors.transparent,
                              borderRadius: BorderRadius.circular(9999),
                            ),
                            child: Text(
                              '○ Spend Bitcoin',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color:
                                    !cashState.isBuying
                                        ? AppColors.surface
                                        : AppColors.textTertiary,
                                fontSize: 14.sp,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 18.w,
                    vertical: 18.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cashState.isBuying
                            ? 'How much you wan buy?'
                            : 'How much you wan spend?',
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 12.sp,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Padding(
                        padding: EdgeInsets.only(bottom: 8.h),
                        child: Text(
                          "We'll create the invoice for you – no copy-paste needed",
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 11.sp,
                          ),
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '₦',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 40.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: TextField(
                              controller: _amountInputController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: false,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              style: TextStyle(
                                color:
                                    cashState.selectedAmount > 0
                                        ? Colors.white
                                        : const Color(0xFFCCCCCC),
                                fontSize: 42.sp,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: '0.00',
                                hintStyle: TextStyle(
                                  color: const Color(0xFFCCCCCC),
                                  fontSize: 42.sp,
                                ),
                              ),
                              onChanged: (value) {
                                final cleaned = value.replaceAll(
                                  RegExp(r'[^0-9]'),
                                  '',
                                );
                                final parsed = double.tryParse(cleaned) ?? 0;
                                cashNotifier.setAmount(parsed);
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 2.5,
                            ),
                        itemCount: _quickAmounts.length,
                        itemBuilder: (context, index) {
                          final amount = _quickAmounts[index];
                          final isSelected = cashState.selectedAmount == amount;
                          return GestureDetector(
                            onTap: () {
                              cashNotifier.setAmount(amount);
                              _amountInputController.text =
                                  amount.toInt().toString();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 10.h,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isSelected
                                        ? AppColors.primary
                                        : AppColors.background,
                                borderRadius: BorderRadius.circular(9999),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '₦ ${formatter.format(amount.toInt())}',
                                  style: TextStyle(
                                    color:
                                        isSelected
                                            ? Colors.white
                                            : AppColors.textTertiary,
                                    fontSize: 12.sp,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 24.h),
                child: SizedBox(
                  width: double.infinity,
                  height: 52.h,
                  child: ElevatedButton(
                    onPressed:
                        cashState.selectedAmount > 0
                            ? () async {
                              cashNotifier.generateReference();
                              final amount = cashState.selectedAmount;
                              if (cashState.isBuying) {
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder:
                                      (_) => const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                );
                                try {
                                  final rate =
                                      _liveBtcRate ?? cashState.btcPrice;
                                  final satsDouble =
                                      (amount / (rate == 0 ? 1 : rate)) *
                                      100000000.0;
                                  final sats = satsDouble.round();
                                  final invoice =
                                      await BreezSparkService.createInvoice(
                                        sats: sats,
                                        memo: 'Tapnob purchase',
                                      );
                                  if (!mounted) return;
                                  Navigator.pop(context);
                                  try {
                                    await Clipboard.setData(
                                      ClipboardData(text: invoice),
                                    );
                                    debugPrint('Invoice copied to clipboard');
                                  } catch (_) {}
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => TapnobWebViewScreen(
                                            amount: amount,
                                            isBuying: true,
                                            invoice: invoice,
                                          ),
                                    ),
                                  );
                                } catch (e) {
                                  if (mounted) Navigator.pop(context);
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Could not create invoice — opening Tapnob',
                                      ),
                                    ),
                                  );
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => TapnobWebViewScreen(
                                            amount: amount,
                                            isBuying: true,
                                          ),
                                    ),
                                  );
                                }
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => TapnobWebViewScreen(
                                          amount: amount,
                                          isBuying: false,
                                        ),
                                  ),
                                );
                              }
                            }
                            : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          cashState.selectedAmount > 0
                              ? AppColors.primary
                              : AppColors.primary.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: Text(
                      'Generate Invoice & Continue',
                      style: TextStyle(
                        color: AppColors.surface,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
