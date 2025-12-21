import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
// colors are referenced inline; no AppColors import required here
import 'package:sabi_wallet/features/cash/presentation/providers/cash_provider.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';
import 'package:sabi_wallet/services/rate_service.dart';

class TapnobWebViewScreen extends ConsumerStatefulWidget {
  final double amount;
  final bool isBuying;
  final String? invoice;

  const TapnobWebViewScreen({super.key, required this.amount, required this.isBuying, this.invoice});

  @override
  ConsumerState<TapnobWebViewScreen> createState() => _TapnobWebViewScreenState();
}

class _TapnobWebViewScreenState extends ConsumerState<TapnobWebViewScreen> with SingleTickerProviderStateMixin {
  late final WebViewController _controller;
  bool _completed = false;
  bool _loading = true;
  bool _showPayModal = false;
  bool _showSuccess = false;
  String? _detectedInvoice;
  int? _invoiceAmountSats;
  double? _expectedNgn;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'InvoiceChannel',
        onMessageReceived: (JavaScriptMessage message) {
          final invoice = message.message;
          _detectedInvoice = invoice;
          _preparePayment(invoice);
        },
      )
      ..setNavigationDelegate(NavigationDelegate(
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
            Clipboard.getData(Clipboard.kTextPlain).then((data) {
              if (data != null && data.text != null && data.text!.isNotEmpty) {
                _injectInvoice(data.text!);
              }
            });
          }
        },
      ));

    final base = widget.isBuying ? 'https://tapnob.com/buybtc' : 'https://tapnob.com/spendbtc';
    final full = '$base?amountNGN=${widget.amount.toInt()}&mode=${widget.isBuying ? 'buy' : 'spend'}';
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

  void _preparePayment(String invoice) async {
    try {
      final prep = await BreezSparkService.prepareSendPayment(invoice);
      _invoiceAmountSats = prep.amount.toInt();
      final btcToNgn = await RateService.getBtcToNgnRate();
      final usdToNgn = await RateService.getUsdToNgnRate();
      final btcToUsd = btcToNgn / usdToNgn;
      final btcAmount = _invoiceAmountSats! / 100000000.0;
      final usdAmount = btcAmount * btcToUsd;
      _expectedNgn = usdAmount * usdToNgn;
      setState(() {
        _showPayModal = true;
      });
    } catch (e) {
      debugPrint('Error preparing payment: $e');
    }
  }

  void _payInvoice() async {
    if (_detectedInvoice == null) return;
    try {
      await BreezSparkService.sendPayment(_detectedInvoice!);
      setState(() {
        _showPayModal = false;
        _showSuccess = true;
      });
      Future.delayed(const Duration(seconds: 3), () {
        setState(() {
          _showSuccess = false;
        });
      });
    } catch (e) {
      debugPrint('Error paying invoice: $e');
      // show error
    }
  }

  void _checkForSuccess(String? url) async {
    if (url == null) return;
    final u = url.toLowerCase();
    if (_completed) return;
    if (u.contains('success') || u.contains('status=success') || u.contains('tapnob.com/success')) {
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
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isBuying ? 'Buy Bitcoin on Tapnob' : 'Sell Bitcoin on Tapnob';

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
                    icon: Icon(Icons.arrow_back, color: Colors.white, size: 20.sp),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w600),
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
                    const Center(
                      child: CircularProgressIndicator(),
                    ),
                  if (_completed)
                    Positioned.fill(
                      child: Container(
                        color: const Color(0xFF00FFB2).withValues(alpha: 0.12),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline, size: 72.sp, color: const Color(0xFF00FFB2)),
                              SizedBox(height: 12.h),
                              Text(
                                'Trade complete! Balance updated.',
                                style: TextStyle(color: const Color(0xFF00FFB2), fontSize: 18.sp, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (_showPayModal) _buildPayModal(),
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
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF111128),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pay ${_invoiceAmountSats ?? 0} SAT from your Sabi balance?',
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _showPayModal = false;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF7931A),
                      ),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: _payInvoice,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00FFB2),
                      ),
                      child: const Text('Pay Now'),
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

  Widget _buildSuccessOverlay() {
    return Positioned.fill(
      child: Container(
        color: const Color(0xFF00FFB2).withOpacity(0.1),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, size: 72, color: const Color(0xFF00FFB2)),
              const SizedBox(height: 12),
              Text(
                'Payment sent! You’ll receive ₦${_expectedNgn?.toStringAsFixed(0) ?? '0'} soon',
                style: const TextStyle(color: Color(0xFF00FFB2), fontSize: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
