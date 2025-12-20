import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
// colors are referenced inline; no AppColors import required here
import 'package:sabi_wallet/features/cash/presentation/providers/cash_provider.dart';

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
  bool _injectionDone = false;
  Timer? _injectionTimer;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) {
          _checkForSuccess(url);
            // try inject early if invoice available
            if (widget.invoice != null) {
              _injectInvoice(widget.invoice!);
            }
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
            if (widget.invoice != null) {
              _injectInvoice(widget.invoice!);
            }
        },
      ));

    final base = widget.isBuying ? 'https://tapnob.com/buybtc' : 'https://tapnob.com/spendbtc';
    final full = '$base?amountNGN=${widget.amount.toInt()}&mode=${widget.isBuying ? 'buy' : 'spend'}';
    _controller.loadRequest(Uri.parse(full));
    // If we have an invoice, attempt repeated injection for a short window
    if (widget.invoice != null) {
      _injectionTimer = Timer.periodic(const Duration(milliseconds: 450), (t) {
        if (_injectionDone || !_loading == false && !_loading) {
          // continue attempting while loading or until done
        }
        if (_injectionDone) {
          t.cancel();
          return;
        }
        // limit attempts
        if (t.tick > 12) {
          t.cancel();
          return;
        }
        _injectInvoice(widget.invoice!);
      });
    }
  }

  void _injectInvoice(String invoice) {
    try {
      final esc = invoice.replaceAll("'", "\\'");
      // Try multiple selectors and dispatch events to trigger any JS listeners on the page.
      final js = '''
      (function() {
        try {
          var invoice = '${esc}';
          var selectors = [
            'input[placeholder="Paste lightning invoice"]',
            'input[placeholder*="invoice"]',
            'textarea[placeholder*="invoice"]',
            'input[type="text"]',
            'textarea',
            'input[name*="invoice"]',
            '[id*="invoice"]',
            '[class*="invoice"]'
          ];
          for (var i=0;i<selectors.length;i++){
            var el = document.querySelector(selectors[i]);
            if (!el) continue;
            try {
              if ('value' in el) el.value = invoice;
              else el.innerText = invoice;
              el.focus();
              var ev = new Event('input', {bubbles: true});
              el.dispatchEvent(ev);
              var ev2 = new Event('change', {bubbles: true});
              el.dispatchEvent(ev2);
              // also set attribute for frameworks that watch attributes
              el.setAttribute('value', invoice);
              return true;
            } catch(e) {
              // continue to next
            }
          }
          // as a fallback, try to find any editable element and set clipboard then focus
          try {
            if (navigator && navigator.clipboard && navigator.clipboard.writeText) {
              navigator.clipboard.writeText(invoice).catch(function(){});
            }
          } catch(e){}
          return false;
        } catch(e) { return false; }
      })();
      ''';
      _controller.runJavaScript(js);
      debugPrint('Tapnob: attempted invoice injection');
    } catch (e) {
      // ignore
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
