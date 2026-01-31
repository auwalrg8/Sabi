import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/features/cash/presentation/providers/cash_provider.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';
import 'package:sabi_wallet/services/rate_service.dart';
import 'package:sabi_wallet/services/firebase/webhook_bridge_services.dart';

class TapnobWebViewScreen extends ConsumerStatefulWidget {
  final double amount;
  final bool isBuying;
  final String? invoice;

  const TapnobWebViewScreen({
    super.key,
    required this.amount,
    required this.isBuying,
    this.invoice,
  });

  @override
  ConsumerState<TapnobWebViewScreen> createState() =>
      _TapnobWebViewScreenState();
}

class _TapnobWebViewScreenState extends ConsumerState<TapnobWebViewScreen>
    with SingleTickerProviderStateMixin {
  late final WebViewController _controller;
  bool _completed = false;
  bool _loading = true;
  bool _showPayModal = false;
  bool _showSuccess = false;
  bool _showInsufficientModal = false;
  bool _showErrorModal = false;
  bool _isPaying = false;
  bool _paymentSettled = false;
  String? _detectedInvoice;
  int? _invoiceAmountSats;
  double? _expectedNgn;
  int _availableBalance = 0;
  double? _availableNgn;
  String _errorMessage = '';
  String _errorTitle = 'Payment Failed';
  bool _isInsufficientBalanceError = false;
  int _buyInjectAttempts = 0;
  static const int _buyInjectMaxAttempts = 2;

  @override
  void initState() {
    super.initState();
    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..addJavaScriptChannel(
            'InvoiceChannel',
            onMessageReceived: (JavaScriptMessage message) {
              final invoice = message.message;
              if (_paymentSettled) return;
              _detectedInvoice = invoice;
              _preparePayment(invoice);
            },
          )
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageStarted: (url) {
                _checkForSuccess(url);
              },
              onNavigationRequest: (req) {
                _checkForSuccess(req.url);
                return NavigationDecision.navigate;
              },
              onPageFinished: (url) {
                setState(() {
                  _loading = false;
                });
                _checkForSuccess(url);
                if (!widget.isBuying) {
                  _injectExtractionScript();
                } else {
                  // attempt injection from clipboard up to 2 times (immediate + one retry)
                  _buyInjectAttempts = 0;
                  _attemptBuyInjectionFromClipboard();
                }
              },
            ),
          );

    final base =
        widget.isBuying
            ? 'https://www.tapnob.com/buybtc'
            : 'https://www.tapnob.com/spendbtc';
    var full =
        '$base?amountNGN=${widget.amount.toInt()}&mode=${widget.isBuying ? 'buy' : 'spend'}&asset=${widget.isBuying ? 'bitcoin_lightning' : 'BTC'}';
    if (widget.isBuying) {
      full += '&method=invoice';
      if (widget.invoice != null && widget.invoice!.isNotEmpty) {
        full += '&invoice=${Uri.encodeComponent(widget.invoice!)}';
      }
    }
    _controller.loadRequest(Uri.parse(full));
  }

  void _injectInvoice(String invoice) {
    final js = '''
      var invoice = '${invoice.replaceAll("'", "\\'")}';
      function tryInject() {
        var inputs = document.querySelectorAll('input, textarea');
        for (var i = 0; i < inputs.length; i++) {
          var el = inputs[i];
          var ph = el.placeholder || '';
          if (ph.toLowerCase().includes('invoice') || ph.toLowerCase().includes('paste') || ph.toLowerCase().includes('lightning')) {
            el.value = invoice;
            el.dispatchEvent(new Event('input', {bubbles: true}));
            el.dispatchEvent(new Event('change', {bubbles: true}));
            return true;
          }
        }
        return false;
      }
      if (tryInject()) return;
      var observer = new MutationObserver(function(mutations) {
        mutations.forEach(function(mutation) {
          if (mutation.type === 'childList') {
            if (tryInject()) {
              observer.disconnect();
            }
          }
        });
      });
      observer.observe(document.body, { childList: true, subtree: true });
    ''';
    _controller.runJavaScript(js);
  }

  void _injectExtractionScript() {
    final js = '''
      function findInvoice() {
        var elements = document.querySelectorAll('*');
        for (var el of elements) {
          var text = el.textContent || el.value || el.getAttribute('data-lnbc') || '';
          if (text.includes('lnbc')) {
            return text.trim();
          }
        }
        return null;
      }
      var invoice = findInvoice();
      if (invoice) {
        InvoiceChannel.postMessage(invoice);
      } else {
        var observer = new MutationObserver(function() {
          var inv = findInvoice();
          if (inv) {
            InvoiceChannel.postMessage(inv);
            observer.disconnect();
          }
        });
        observer.observe(document.body, { childList: true, subtree: true });
      }
    ''';
    _controller.runJavaScript(js);
  }

  Future<void> _attemptBuyInjectionFromClipboard() async {
    try {
      _buyInjectAttempts++;
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final invoice = data?.text;
      bool injected = false;
      if (invoice != null && invoice.isNotEmpty) {
        final success = await _tryInjectJsReturningBool(invoice);
        if (success == true) {
          injected = true;
          return;
        }
      }
      if (!injected && _buyInjectAttempts < _buyInjectMaxAttempts) {
        // retry shortly
        Future.delayed(
          const Duration(milliseconds: 450),
          _attemptBuyInjectionFromClipboard,
        );
      } else if (!injected && invoice != null && invoice.isNotEmpty) {
        // attempts exhausted - install observer-based injector as fallback
        _injectInvoice(invoice);
      }
    } catch (e) {
      debugPrint('Buy injection attempt error: $e');
    }
  }

  Future<bool?> _tryInjectJsReturningBool(String invoice) async {
    final esc = invoice.replaceAll("'", "\\'");
    final js = '''(function(){
      try{
        var invoice = "$esc";
        function getHintText(el){
          try{
            var ph = (el.getAttribute && el.getAttribute('placeholder')) || '';
            var aria = (el.getAttribute && el.getAttribute('aria-label')) || '';
            var id = el.id || '';
            var name = el.name || '';
            var cls = el.className || '';
            var data = '';
            try{ data = JSON.stringify(el.dataset) }catch(e){}
            var label = '';
            try{ var lab = el.closest('label'); if(lab) label = lab.innerText || ''; }catch(e){}
            return (ph + ' ' + aria + ' ' + id + ' ' + name + ' ' + cls + ' ' + data + ' ' + label).toLowerCase();
          }catch(e){return ''}
        }
        function setNativeValue(el, value){
          try{
            var proto = Object.getPrototypeOf(el);
            var desc = Object.getOwnPropertyDescriptor(proto, 'value') || Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value');
            var setter = desc && desc.set;
            if(setter) setter.call(el, value);
            else el.value = value;
          }catch(e){ try{ el.value = value;}catch(e){} }
          try{ el.setAttribute && el.setAttribute('value', value); }catch(e){}
          try{ var ev = new Event('input', {bubbles:true}); el.dispatchEvent(ev);}catch(e){}
          try{ var ev2 = new Event('change', {bubbles:true}); el.dispatchEvent(ev2);}catch(e){}
          try{ if(el.setSelectionRange) el.setSelectionRange(value.length, value.length);}catch(e){}
        }
        var nodes = Array.from(document.querySelectorAll('input,textarea,[contenteditable="true"]'));
        // prefer inputs that explicitly mention paste/lightning/invoice
        var candidates = nodes.filter(function(el){
          var hint = getHintText(el);
          return hint.indexOf('paste')!==-1 && (hint.indexOf('lightning')!==-1 || hint.indexOf('invoice')!==-1) || hint.indexOf('lnbc')!==-1 || hint.indexOf('bolt11')!==-1;
        });
        if(candidates.length===0){
          // fallback to broader invoice hints
          candidates = nodes.filter(function(el){
            var hint = getHintText(el);
            return hint.indexOf('invoice')!==-1 || hint.indexOf('lightning')!==-1 || hint.indexOf('paste')!==-1 || hint.indexOf('lnbc')!==-1;
          });
        }
        if(candidates.length===0) candidates = nodes;
        for(var i=0;i<candidates.length;i++){
          var el = candidates[i];
          try{
            setNativeValue(el, invoice);
            try{ el.focus && el.focus(); }catch(e){}
            if((el.value && el.value.indexOf(invoice.substring(0,8))!==-1) || (el.innerText && el.innerText.indexOf(invoice.substring(0,8))!==-1)) return true;
          }catch(e){}
        }
        return false;
      }catch(e){return false}
    })();''';
    try {
      final res = await _controller.runJavaScriptReturningResult(js);
      if (res == true || res == 'true' || res == 1 || res == '1') return true;
      return false;
    } catch (e) {
      // fallback to non-returning observer-based injection
      _injectInvoice(invoice);
      return null;
    }
  }

  void _preparePayment(String invoice) async {
    if (_paymentSettled) return;
    try {
      // First check balance before preparing payment
      final balance = await BreezSparkService.getBalance();
      _availableBalance = balance;
      
      final prep = await BreezSparkService.prepareSendPayment(invoice);
      _invoiceAmountSats = prep.amount.toInt();
      final btcToNgn = await RateService.getBtcToNgnRate();
      final usdToNgn = await RateService.getUsdToNgnRate();
      final btcToUsd = btcToNgn / usdToNgn;
      final btcAmount = _invoiceAmountSats! / 100000000.0;
      final usdAmount = btcAmount * btcToUsd;
      _expectedNgn = usdAmount * usdToNgn;

      // Calculate available balance in NGN
      final availableBtcAmount = balance / 100000000.0;
      final availableUsdAmount = availableBtcAmount * btcToUsd;
      _availableNgn = availableUsdAmount * usdToNgn;

      if (_invoiceAmountSats! > balance) {
        setState(() {
          _showInsufficientModal = true;
        });
      } else {
        setState(() {
          _showPayModal = true;
        });
      }
    } catch (e) {
      debugPrint('Error preparing payment: $e');
      final errorStr = e.toString().toLowerCase();
      
      // Check if it's an insufficient balance error
      if (errorStr.contains('insufficient') || 
          errorStr.contains('not enough') ||
          errorStr.contains('balance') ||
          (errorStr.contains('invalid') && _availableBalance == 0)) {
        _errorTitle = 'Insufficient Balance';
        _errorMessage = 'You don\'t have enough sats to pay this invoice. Please top up your wallet first.';
        _isInsufficientBalanceError = true;
      } else if (errorStr.contains('invalid input') || errorStr.contains('invalidinput')) {
        // "invalid input" often means the invoice couldn't be parsed or balance issue
        _errorTitle = 'Unable to Process';
        _errorMessage = 'Could not process this invoice. This may be due to insufficient balance or an invalid invoice format.';
        _isInsufficientBalanceError = true;
      } else {
        _errorTitle = 'Payment Failed';
        _errorMessage = BreezSparkService.getUserFriendlyErrorMessage(e);
        _isInsufficientBalanceError = false;
      }
      
      setState(() {
        _showErrorModal = true;
      });
    }
  }

  void _payInvoice() async {
    if (_detectedInvoice == null) return;
    setState(() {
      _isPaying = true;
    });
    try {
      await BreezSparkService.sendPayment(_detectedInvoice!);
      // Mark as settled to avoid duplicate payments
      _paymentSettled = true;

      setState(() {
        _showPayModal = false;
        _isPaying = false;
        _showSuccess = true;
      });

      // Update app balance/transactions and ensure Spend tab is active
      try {
        await ref.read(cashProvider.notifier).processPayment();
        ref.read(cashProvider.notifier).toggleBuySell(false);
      } catch (_) {}

      // Emit outgoing payment notification/webhook
      try {
        await BreezWebhookBridgeService().sendOutgoingPaymentNotification(
          amountSats: _invoiceAmountSats ?? 0,
          recipientName: 'Tapnob',
          description: 'Tapnob purchase',
        );
      } catch (_) {}

      // Close the Tapnob webview after a short delay
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        Navigator.of(context).pop();
      });
      Future.delayed(const Duration(seconds: 3), () {
        setState(() {
          _showSuccess = false;
        });
      });
    } catch (e) {
      debugPrint('Error paying invoice: $e');
      final errorStr = e.toString().toLowerCase();
      
      // Check if it's an insufficient balance error
      if (errorStr.contains('insufficient') || 
          errorStr.contains('not enough') ||
          errorStr.contains('balance')) {
        _errorTitle = 'Insufficient Balance';
        _errorMessage = 'You don\'t have enough sats to complete this payment.';
        _isInsufficientBalanceError = true;
      } else {
        _errorTitle = 'Payment Failed';
        _errorMessage = BreezSparkService.getUserFriendlyErrorMessage(e);
        _isInsufficientBalanceError = BreezSparkService.isRetryableError(e) == false;
      }
      
      setState(() {
        _showPayModal = false;
        _isPaying = false;
        _showErrorModal = true;
      });
    }
  }

  void _checkForSuccess(String? url) async {
    if (url == null) return;
    final u = url.toLowerCase();
    if (_completed) return;
    if (u.contains('success') ||
        u.contains('status=success') ||
        u.contains('tapnob.com/success') ||
        u.contains('www.tapnob.com/success')) {
      setState(() {
        _completed = true;
      });
      // update local transactions/balance
      await ref.read(cashProvider.notifier).processPayment();
      // show overlay for a moment then pop to home
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      // pop back to root (Home)
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  Future<void> _onRefresh() async {
    await _controller.reload();
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.isBuying ? 'Buy Bitcoin on Tapnob' : 'Spend Bitcoin on Tapnob';

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C1A),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              height: 56.h,
              color: const Color(0xFF0C0C1A),
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      if (_completed) {
                        Navigator.of(context).popUntil((r) => r.isFirst);
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                    icon: Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 20.sp,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  RefreshIndicator(
                    onRefresh: _onRefresh,
                    child: WebViewWidget(controller: _controller),
                  ),
                  if (_loading)
                    const Center(child: CircularProgressIndicator()),
                  if (_completed)
                    Positioned.fill(
                      child: Container(
                        color: const Color(0xFF00FFB2).withValues(alpha: 0.12),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 72.sp,
                                color: const Color(0xFF00FFB2),
                              ),
                              SizedBox(height: 12.h),
                              Text(
                                'Trade complete! Balance updated.',
                                style: TextStyle(
                                  color: const Color(0xFF00FFB2),
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (_showPayModal) _buildPayModal(),
                  if (_showInsufficientModal) _buildInsufficientModal(),
                  if (_showErrorModal) _buildErrorModal(),
                  if (_showSuccess) _buildSuccessOverlay(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayModal() {
    final formatter = NumberFormat.decimalPattern();
    final amountSats = _invoiceAmountSats ?? 0;
    final amountNgn = _expectedNgn?.toStringAsFixed(0) ?? '0';
    final balanceSats = _availableBalance;
    final balanceNgn = _availableNgn?.toStringAsFixed(0) ?? '0';

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.7),
        child: Center(
          child: Container(
            margin: EdgeInsets.all(24.w),
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  width: 64.w,
                  height: 64.w,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.bolt_rounded,
                    color: AppColors.primary,
                    size: 32.sp,
                  ),
                ),
                SizedBox(height: 20.h),

                // Title
                Text(
                  'Confirm Payment',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 8.h),

                // Subtitle
                Text(
                  'Pay from your Sabi wallet',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14.sp,
                  ),
                ),
                SizedBox(height: 24.h),

                // Amount Card
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${formatter.format(amountSats)} sats',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '≈ ₦$amountNgn',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12.h),

                // Balance info
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: AppColors.accentGreen.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Available Balance',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13.sp,
                        ),
                      ),
                      Text(
                        '${formatter.format(balanceSats)} sats (₦$balanceNgn)',
                        style: TextStyle(
                          color: AppColors.accentGreen,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),

                // Buttons
                if (_isPaying)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    child: const CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 52.h,
                          child: OutlinedButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              setState(() => _showPayModal = false);
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: AppColors.textSecondary.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: SizedBox(
                          height: 52.h,
                          child: ElevatedButton(
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              _payInvoice();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentGreen,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.bolt_rounded, size: 18.sp),
                                SizedBox(width: 6.w),
                                Text(
                                  'Pay Now',
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInsufficientModal() {
    final formatter = NumberFormat.decimalPattern();
    final neededSats = _invoiceAmountSats ?? 0;
    final neededNgn = _expectedNgn?.toStringAsFixed(0) ?? '0';
    final availableSats = _availableBalance;
    final availableNgn = _availableNgn?.toStringAsFixed(0) ?? '0';
    final shortfall = neededSats - availableSats;

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.7),
        child: Center(
          child: Container(
            margin: EdgeInsets.all(24.w),
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Warning icon
                Container(
                  width: 64.w,
                  height: 64.w,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.primary,
                    size: 32.sp,
                  ),
                ),
                SizedBox(height: 20.h),

                // Title
                Text(
                  'Insufficient Balance',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 8.h),

                Text(
                  'You need more sats to complete this payment',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14.sp,
                  ),
                ),
                SizedBox(height: 24.h),

                // Needed amount
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: AppColors.accentRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: AppColors.accentRed.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Required',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13.sp,
                        ),
                      ),
                      Text(
                        '${formatter.format(neededSats)} sats (₦$neededNgn)',
                        style: TextStyle(
                          color: AppColors.accentRed,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8.h),

                // Available amount
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Available',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13.sp,
                        ),
                      ),
                      Text(
                        '${formatter.format(availableSats)} sats (₦$availableNgn)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8.h),

                // Shortfall
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Shortfall',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13.sp,
                        ),
                      ),
                      Text(
                        '${formatter.format(shortfall)} sats',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),

                // Button
                SizedBox(
                  width: double.infinity,
                  height: 52.h,
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() => _showInsufficientModal = false);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: Text(
                      'Got it',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorModal() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.7),
        child: Center(
          child: Container(
            margin: EdgeInsets.all(24.w),
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: _isInsufficientBalanceError 
                    ? AppColors.primary.withValues(alpha: 0.3)
                    : AppColors.accentRed.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Error icon
                Container(
                  width: 64.w,
                  height: 64.w,
                  decoration: BoxDecoration(
                    color: _isInsufficientBalanceError
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : AppColors.accentRed.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isInsufficientBalanceError 
                        ? Icons.account_balance_wallet_outlined
                        : Icons.error_outline_rounded,
                    color: _isInsufficientBalanceError 
                        ? AppColors.primary 
                        : AppColors.accentRed,
                    size: 32.sp,
                  ),
                ),
                SizedBox(height: 20.h),

                // Title
                Text(
                  _errorTitle,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 12.h),

                // Error message
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    _errorMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
                SizedBox(height: 24.h),

                // Button
                SizedBox(
                  width: double.infinity,
                  height: 52.h,
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() => _showErrorModal = false);
                      // Navigate back to Cash/Trade tab
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: Text(
                      _isInsufficientBalanceError ? 'Top Up Wallet' : 'Go Back',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessOverlay() {
    final amountNgn = _expectedNgn?.toStringAsFixed(0) ?? '0';

    return Positioned.fill(
      child: Container(
        color: AppColors.accentGreen.withValues(alpha: 0.15),
        child: Center(
          child: Container(
            margin: EdgeInsets.all(32.w),
            padding: EdgeInsets.all(32.w),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24.r),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentGreen.withValues(alpha: 0.3),
                  blurRadius: 40,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80.w,
                  height: 80.w,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accentGreen,
                        AppColors.accentGreen.withValues(alpha: 0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentGreen.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 40.sp,
                  ),
                ),
                SizedBox(height: 24.h),
                Text(
                  'Payment Sent!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'You will receive NGN $amountNgn soon',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.accentGreen,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Check your bank account shortly',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13.sp,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
