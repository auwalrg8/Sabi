import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/core/widgets/amount_chips.dart';
import 'package:sabi_wallet/services/rate_service.dart';
import 'package:sabi_wallet/features/wallet/presentation/providers/rate_provider.dart';
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
  String _amountString = '';
  final formatter = NumberFormat.decimalPattern();
  FiatCurrency _selectedCurrency = FiatCurrency.ngn;

  final List<int> _quickAmounts = [5000, 10000, 50000, 100000, 500000, 1000000];

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
    super.dispose();
  }

  Future<void> _loadLiveRates() async {
    if (mounted) setState(() => _isLoadingRates = true);
    try {
      _selectedCurrency = ref.read(selectedFiatCurrencyProvider);
      final btc = await RateService.getBtcToFiatRate(_selectedCurrency);
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
    HapticFeedback.lightImpact();
    _refreshController.forward(from: 0);
    await _loadLiveRates();
    await Future.delayed(const Duration(milliseconds: 400));
    _refreshController.reverse();
  }

  void _onDigit(String digit) {
    HapticFeedback.lightImpact();
    if (_amountString.length >= 10) return;
    setState(() {
      _amountString += digit;
    });
    final parsed = double.tryParse(_amountString) ?? 0;
    ref.read(cashProvider.notifier).setAmount(parsed);
  }

  void _onDelete() {
    HapticFeedback.lightImpact();
    if (_amountString.isNotEmpty) {
      setState(() {
        _amountString = _amountString.substring(0, _amountString.length - 1);
      });
      final parsed = double.tryParse(_amountString) ?? 0;
      ref.read(cashProvider.notifier).setAmount(parsed);
    }
  }

  void _onQuickAmount(int? amount) {
    if (amount != null) {
      setState(() {
        _amountString = amount.toString();
      });
      ref.read(cashProvider.notifier).setAmount(amount.toDouble());
    } else {
      setState(() {
        _amountString = '';
      });
      ref.read(cashProvider.notifier).setAmount(0);
    }
  }

  int _calculateSats(double ngnAmount) {
    final rate = _liveBtcRate ?? 150000000;
    if (rate == 0) return 0;
    return ((ngnAmount / rate) * 100000000).round();
  }

  @override
  Widget build(BuildContext context) {
    final cashState = ref.watch(cashProvider);
    final cashNotifier = ref.read(cashProvider.notifier);
    final satsEquivalent = _calculateSats(cashState.selectedAmount);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Column(
                  children: [
                    SizedBox(height: 8.h),
                    _buildRateCard(cashState),
                    SizedBox(height: 20.h),
                    _buildTabSelector(cashState, cashNotifier),
                    SizedBox(height: 24.h),
                    _buildAmountDisplay(cashState, satsEquivalent),
                    SizedBox(height: 20.h),
                    _buildQuickAmounts(cashState),
                    SizedBox(height: 24.h),
                    _buildKeypad(),
                    SizedBox(height: 24.h),
                    _buildConversionPreview(cashState, satsEquivalent),
                    SizedBox(height: 16.h),
                    _buildActionButton(cashState, cashNotifier),
                    SizedBox(height: 24.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Cash',
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Row(
            children: [
              // History button
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CashHistoryScreen(),
                    ),
                  );
                },
                child: Container(
                  width: 40.w,
                  height: 40.h,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    Icons.history_rounded,
                    color: AppColors.primary,
                    size: 20.sp,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRateCard(CashState cashState) {
    return Skeletonizer(
      enabled: _isLoadingRates,
      enableSwitchAnimation: true,
      containersColor: AppColors.surface,
      effect: PulseEffect(
        duration: const Duration(milliseconds: 1000),
        from: AppColors.background,
        to: AppColors.borderColor.withValues(alpha: 0.3),
      ),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Rate icon with glow
            Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.accentGreen.withValues(alpha: 0.2),
                    AppColors.accentGreen.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                Icons.trending_up_rounded,
                color: AppColors.accentGreen,
                size: 22.sp,
              ),
            ),
            SizedBox(width: 14.w),
            // Rate info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Live Rate',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Container(
                        width: 6.w,
                        height: 6.w,
                        decoration: BoxDecoration(
                          color: AppColors.accentGreen,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accentGreen.withValues(
                                alpha: 0.5,
                              ),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    _liveBtcRate != null
                        ? '1 BTC = ${_selectedCurrency.symbol}${formatter.format(_liveBtcRate!.toInt())}'
                        : '1 BTC = ${_selectedCurrency.symbol}${formatter.format(cashState.btcPrice.toInt())}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    _liveUsdtRate != null
                        ? '1 USDT = ₦${formatter.format(_liveUsdtRate!.toInt())}'
                        : '1 USDT = ₦${formatter.format(cashState.buyRate.toInt())}',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            ),
            // Refresh button with animation
            GestureDetector(
              onTap: _refreshPrice,
              child: Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: RotationTransition(
                  turns: _refreshController,
                  child: Icon(
                    Icons.refresh_rounded,
                    color: AppColors.textSecondary,
                    size: 20.sp,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector(CashState cashState, CashNotifier cashNotifier) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111128),
        borderRadius: BorderRadius.circular(16.r),
      ),
      padding: EdgeInsets.all(4.w),
      child: Row(
        children: [
          // Buy Bitcoin tab
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                cashNotifier.toggleBuySell(true);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 44.h,
                decoration: BoxDecoration(
                  color:
                      cashState.isBuying
                          ? const Color(0xFF00C853)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Center(
                  child: Text(
                    'Buy Bitcoin',
                    style: TextStyle(
                      color: cashState.isBuying ? Colors.white : Colors.white54,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Spend Bitcoin tab
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                cashNotifier.toggleBuySell(false);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 44.h,
                decoration: BoxDecoration(
                  color:
                      !cashState.isBuying
                          ? const Color(0xFFF7931A)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Center(
                  child: Text(
                    'Spend Bitcoin',
                    style: TextStyle(
                      color:
                          !cashState.isBuying ? Colors.white : Colors.white54,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountDisplay(CashState cashState, int satsEquivalent) {
    final displayAmount =
        cashState.selectedAmount > 0
            ? formatter.format(cashState.selectedAmount.toInt())
            : '0';

    return Column(
      children: [
        // Currency label
        Text(
          cashState.isBuying ? 'You pay' : 'You spend',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 12.h),
        // Main amount with currency
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '₦',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 32.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 4.w),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(
                      begin: 0.9,
                      end: 1.0,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Text(
                displayAmount,
                key: ValueKey(displayAmount),
                style: TextStyle(
                  color:
                      cashState.selectedAmount > 0
                          ? Colors.white
                          : AppColors.textTertiary,
                  fontSize: 48.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        // Sats equivalent
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: Text(
            cashState.selectedAmount > 0
                ? '≈ ${formatter.format(satsEquivalent)} sats'
                : 'Enter amount in Naira',
            key: ValueKey(satsEquivalent),
            style: TextStyle(
              color:
                  cashState.selectedAmount > 0
                      ? AppColors.primary
                      : AppColors.textTertiary,
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAmounts(CashState cashState) {
    return AmountChips(
      amounts: _quickAmounts,
      selectedAmount: cashState.selectedAmount.toInt(),
      onSelected: _onQuickAmount,
      currency: '₦',
      formatAmount: (amount) => '₦${formatter.format(amount)}',
    );
  }

  Widget _buildKeypad() {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows.map((row) => _buildKeypadRow(row)).toList(),
    );
  }

  Widget _buildKeypadRow(List<String> keys) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: keys.map((key) => _buildKeypadButton(key)).toList(),
      ),
    );
  }

  Widget _buildKeypadButton(String value) {
    if (value.isEmpty) {
      return SizedBox(width: 72.w, height: 56.h);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: value == '⌫' ? _onDelete : () => _onDigit(value),
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          width: 72.w,
          height: 56.h,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14.r),
          ),
          child: Center(
            child:
                value == '⌫'
                    ? Icon(
                      Icons.backspace_outlined,
                      color: AppColors.textSecondary,
                      size: 22.sp,
                    )
                    : Text(
                      value,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
          ),
        ),
      ),
    );
  }

  Widget _buildConversionPreview(CashState cashState, int satsEquivalent) {
    if (cashState.selectedAmount <= 0) return const SizedBox.shrink();

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: cashState.selectedAmount > 0 ? 1.0 : 0.0,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: AppColors.borderColor.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: AppColors.textSecondary,
              size: 18.sp,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                cashState.isBuying
                    ? 'You will receive ~${formatter.format(satsEquivalent)} sats'
                    : 'You will spend ~${formatter.format(satsEquivalent)} sats',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13.sp,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(CashState cashState, CashNotifier cashNotifier) {
    final isEnabled = cashState.selectedAmount > 0;

    return SizedBox(
      width: double.infinity,
      height: 56.h,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.r),
          gradient:
              isEnabled
                  ? LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                  : null,
          color: isEnabled ? null : AppColors.surface,
          boxShadow:
              isEnabled
                  ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                  : null,
        ),
        child: ElevatedButton(
          onPressed:
              isEnabled ? () => _handleContinue(cashState, cashNotifier) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.open_in_new_rounded,
                color: isEnabled ? Colors.white : AppColors.textTertiary,
                size: 20.sp,
              ),
              SizedBox(width: 10.w),
              Text(
                'Continue on Tapnob',
                style: TextStyle(
                  color: isEnabled ? Colors.white : AppColors.textTertiary,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleContinue(
    CashState cashState,
    CashNotifier cashNotifier,
  ) async {
    HapticFeedback.mediumImpact();
    cashNotifier.generateReference();
    final amount = cashState.selectedAmount;

    if (cashState.isBuying) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (_) => Center(
              child: Container(
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 16.h),
                    Text(
                      'Creating invoice...',
                      style: TextStyle(color: Colors.white, fontSize: 14.sp),
                    ),
                  ],
                ),
              ),
            ),
      );
      try {
        final rate = _liveBtcRate ?? cashState.btcPrice;
        final satsDouble = (amount / (rate == 0 ? 1 : rate)) * 100000000.0;
        final sats = satsDouble.round();
        final invoice = await BreezSparkService.createInvoice(
          sats: sats,
          memo: 'Tapnob purchase',
        );
        if (!mounted) return;
        Navigator.pop(context);
        try {
          await Clipboard.setData(ClipboardData(text: invoice));
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
          SnackBar(
            backgroundColor: AppColors.surface,
            content: Text(
              'Could not create invoice — opening Tapnob',
              style: TextStyle(color: Colors.white, fontSize: 14.sp),
            ),
          ),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) =>
                    TapnobWebViewScreen(amount: amount, isBuying: true),
          ),
        );
      }
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => TapnobWebViewScreen(amount: amount, isBuying: false),
        ),
      );
    }
  }
}
