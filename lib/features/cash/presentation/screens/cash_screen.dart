import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/services/rate_service.dart';
import 'tapnob_webview_screen.dart';
import '../providers/cash_provider.dart';
import 'cash_history_screen.dart';

class CashScreen extends ConsumerStatefulWidget {
  const CashScreen({super.key});

  @override
  ConsumerState<CashScreen> createState() => _CashScreenState();
}

class _CashScreenState extends ConsumerState<CashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _refreshController;
  double? _liveBtcRate;
  double? _liveUsdtRate;
  final TextEditingController _amountInputController = TextEditingController();

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
      duration: const Duration(milliseconds: 500),
    );
    _loadLiveRate();
  }

  Future<void> _loadLiveRate() async {
    final btc = await RateService.getBtcToNgnRate();
    final usdt = await RateService.getUsdToNgnRate();
    if (mounted) {
      setState(() {
        _liveBtcRate = btc;
        _liveUsdtRate = usdt;
      });
    }
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _amountInputController.dispose();
    super.dispose();
  }

  void _refreshPrice() {
    _refreshController.forward(from: 0);
    ref.read(cashProvider.notifier).refreshPrice();
    _loadLiveRate(); // Also refresh BTC rate
  }

  @override
  Widget build(BuildContext context) {
    final cashState = ref.watch(cashProvider);
    final formatter = NumberFormat('#,###');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 15.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Cash',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CashHistoryScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.all(10.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A2942),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.history,
                        color: AppColors.textTertiary,
                        size: 20.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 30.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: EdgeInsets.all(17.h),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: const Color(0xFF1F2937)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x26000000),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                              GestureDetector(
                                onTap: _refreshPrice,
                                child: RotationTransition(
                                  turns: _refreshController,
                                  child: Icon(
                                    Icons.refresh,
                                    color: Color(0xFF6B7280),
                                    size: 17.sp,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10.h),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Buy rate',
                                    style: TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 12.sp,
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Text(
                                    '₦ ${cashState.buyRate.toStringAsFixed(0)}/USDT',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Text(
                                    'Sell rate',
                                    style: TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 12.sp,
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Text(
                                    '₦ ${cashState.sellRate.toStringAsFixed(0)}/USDT',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 17.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        vertical: 4.h,
                        horizontal: 4.w,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A2942),
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap:
                                  () => ref
                                      .read(cashProvider.notifier)
                                      .toggleBuySell(true),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: EdgeInsets.symmetric(vertical: 13.h),
                                decoration: BoxDecoration(
                                  color:
                                      cashState.isBuying
                                          ? AppColors.primary
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9999),
                                ),
                                child: Text(
                                  '◉ Buy Bitcoin',
                                  style: TextStyle(
                                    color:
                                        cashState.isBuying
                                            ? AppColors.surface
                                            : AppColors.textTertiary,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap:
                                  () => ref
                                      .read(cashProvider.notifier)
                                      .toggleBuySell(false),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: EdgeInsets.symmetric(vertical: 13.h),
                                decoration: BoxDecoration(
                                  color:
                                      !cashState.isBuying
                                          ? AppColors.primary
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9999),
                                ),
                                child: Text(
                                  '○ Spend Bitcoin',
                                  style: TextStyle(
                                    color:
                                        !cashState.isBuying
                                            ? AppColors.surface
                                            : AppColors.textTertiary,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 17.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24.w,
                        vertical: 17.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20.r),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x26000000),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
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
                          SizedBox(height: 12.h),
                          Padding(
                            padding: EdgeInsets.only(bottom: 8.h),
                            child: Text(
                              'Powered by Tapnob – trusted Nigerians',
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
                                  fontSize: 41.sp,
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                ),
                              ),
                              SizedBox(width: 15.w),
                              Expanded(
                                child: TextField(
                                  controller: _amountInputController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: false),
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  style: TextStyle(
                                    color: cashState.selectedAmount > 0 ? Colors.white : const Color(0xFFCCCCCC),
                                    fontSize: 48.sp,
                                    fontWeight: FontWeight.w700,
                                    height: 1,
                                  ),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    hintText: '0.00',
                                    hintStyle: TextStyle(color: const Color(0xFFCCCCCC), fontSize: 48.sp),
                                  ),
                                  onChanged: (value) {
                                    final cleaned = value.replaceAll(RegExp(r'[^0-9.]'), '');
                                    final parsed = double.tryParse(cleaned) ?? 0;
                                    ref.read(cashProvider.notifier).setAmount(parsed);
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
                              final isSelected =
                                  cashState.selectedAmount == amount;

                              return GestureDetector(
                                onTap: () {
                                    // set quick amount and update input field
                                    ref.read(cashProvider.notifier).setAmount(amount);
                                    _amountInputController.text = amount.toInt().toString();
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16.w,
                                    vertical: 9.h,
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
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          // Removed the receive/fee/total section as requested
                        ],
                      ),
                    ),
                    SizedBox(height: 17.h),
                    // Daily limit card commented out per request
                    /*
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 17.w,
                        vertical: 17.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x1A111128),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: AppColors.primary),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x26000000),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daily limit: ₦100k used of ₦5M',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Link BVN to increase limit →',
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 10.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                    */
                    SizedBox(height: 30.h),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(31.w, 0, 31.w, 30.h),
              child: SizedBox(
                width: double.infinity,
                height: 52.h,
                  child: ElevatedButton(
                  onPressed: cashState.selectedAmount > 0
                      ? () {
                          // Keep card structure but open Tapnob WebView with pre-filled amount
                          ref.read(cashProvider.notifier).generateReference();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TapnobWebViewScreen(
                                amount: cashState.selectedAmount,
                                isBuying: cashState.isBuying,
                              ),
                            ),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        cashState.selectedAmount > 0
                            ? AppColors.primary
                            : AppColors.primary.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  child: Text(
                    'Continue on Tapnob',
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
    );
  }
}
