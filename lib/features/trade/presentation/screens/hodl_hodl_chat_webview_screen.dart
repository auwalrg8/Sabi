import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:sabi_wallet/core/constants/colors.dart';

/// WebView screen for HodlHodl contract chat
/// Opens the contract page directly on HodlHodl website for reliable chat
class HodlHodlChatWebViewScreen extends ConsumerStatefulWidget {
  final String contractId;
  final String counterpartyName;

  const HodlHodlChatWebViewScreen({
    Key? key,
    required this.contractId,
    required this.counterpartyName,
  }) : super(key: key);

  @override
  ConsumerState<HodlHodlChatWebViewScreen> createState() =>
      _HodlHodlChatWebViewScreenState();
}

class _HodlHodlChatWebViewScreenState
    extends ConsumerState<HodlHodlChatWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  double _loadingProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    final contractUrl = 'https://hodlhodl.com/contracts/${widget.contractId}';
    
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.background)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _loadingProgress = 0.0;
              });
            }
          },
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                _loadingProgress = progress / 100;
              });
            }
          },
          onPageFinished: (url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _loadingProgress = 1.0;
              });
              // Try to auto-scroll to chat section
              _scrollToChat();
            }
          },
          onWebResourceError: (error) {
            debugPrint('WebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(contractUrl));
  }

  Future<void> _scrollToChat() async {
    // JavaScript to scroll to chat section if it exists
    await _controller.runJavaScript('''
      (function() {
        var chatSection = document.querySelector('.chat-section, .messages, [class*="chat"], [class*="message"]');
        if (chatSection) {
          chatSection.scrollIntoView({ behavior: 'smooth', block: 'center' });
        }
      })();
    ''');
  }

  Future<void> _refreshPage() async {
    await _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white, size: 24.sp),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chat with ${widget.counterpartyName}',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'HodlHodl Web Chat',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11.sp,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white70, size: 22.sp),
            onPressed: _refreshPage,
          ),
        ],
      ),
      body: Stack(
        children: [
          // WebView
          WebViewWidget(controller: _controller),
          
          // Loading indicator
          if (_isLoading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: _loadingProgress,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }
}
