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

  const TapnobWebViewScreen({super.key, required this.amount, required this.isBuying});

  @override
  ConsumerState<TapnobWebViewScreen> createState() => _TapnobWebViewScreenState();
}

class _TapnobWebViewScreenState extends ConsumerState<TapnobWebViewScreen> with SingleTickerProviderStateMixin {
  late final WebViewController _controller;
  bool _completed = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
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
        },
      ));

    final base = widget.isBuying ? 'https://tapnob.com/buybtc' : 'https://tapnob.com/spendbtc';
    final full = '$base?amountNGN=${widget.amount.toInt()}&mode=${widget.isBuying ? 'buy' : 'spend'}';
    _controller.loadRequest(Uri.parse(full));
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
                        color: const Color(0xFF00FFB2).withOpacity(0.12),
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
