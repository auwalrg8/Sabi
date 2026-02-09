import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/services/hodl_hodl/hodl_hodl.dart';

/// WebView-based Hodl Hodl API key setup screen
/// Allows users to sign up, log in, and get API key - all in-app
class HodlHodlWebViewSetupScreen extends ConsumerStatefulWidget {
  const HodlHodlWebViewSetupScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HodlHodlWebViewSetupScreen> createState() =>
      _HodlHodlWebViewSetupScreenState();
}

class _HodlHodlWebViewSetupScreenState
    extends ConsumerState<HodlHodlWebViewSetupScreen> {
  late final WebViewController _controller;
  final TextEditingController _apiKeyController = TextEditingController();
  
  bool _isLoading = true;
  bool _isValidating = false;
  int _currentStep = 1; // 1: Login, 2: Navigate to API, 3: Copy & Paste
  String _currentUrl = '';
  bool _isOnApiPage = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.background)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              _isLoading = true;
              _currentUrl = url;
            });
          },
          onPageFinished: (url) async {
            setState(() {
              _isLoading = false;
              _currentUrl = url;
            });
            _detectPageAndUpdateStep(url);
          },
          onWebResourceError: (error) {
            debugPrint('WebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse('https://hodlhodl.com/join/HWNHN/'));
  }

  void _detectPageAndUpdateStep(String url) {
    // Detect if on API settings page
    if (url.contains('edit_api_preferences') || url.contains('/settings/api')) {
      setState(() {
        _currentStep = 3;
        _isOnApiPage = true;
      });
    }
    // Detect if logged in (has session or on dashboard) - auto redirect to API page
    else if (url.contains('/dashboard') || 
             url.contains('/offers') || 
             url.contains('/settings') ||
             url.contains('/accounts') && !url.contains('sign') && !url.contains('login')) {
      setState(() {
        _currentStep = 2;
        _isOnApiPage = false;
      });
      // Auto-redirect to API settings after login
      _autoRedirectToApiSettings();
    }
    // Still on login/signup
    else {
      setState(() {
        _currentStep = 1;
        _isOnApiPage = false;
      });
    }
  }

  /// Auto-redirect to API settings after successful login
  Future<void> _autoRedirectToApiSettings() async {
    // Small delay to let the page settle
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted && !_isOnApiPage) {
      await _controller.loadRequest(
        Uri.parse('https://accounts.hodlhodl.com/accounts/edit_api_preferences'),
      );
    }
  }

  /// Navigate directly to API settings page
  Future<void> _goToApiSettings() async {
    HapticFeedback.lightImpact();
    await _controller.loadRequest(
      Uri.parse('https://accounts.hodlhodl.com/accounts/edit_api_preferences'),
    );
  }

  /// Validate and save API key
  Future<void> _validateAndSaveApiKey() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      _showError('Please paste your API key');
      return;
    }

    setState(() => _isValidating = true);
    HapticFeedback.mediumImpact();

    try {
      final service = ref.read(hodlHodlServiceProvider);
      
      // Save the API key
      await service.setApiKey(key);
      
      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20.sp),
                SizedBox(width: 12.w),
                const Text('API key saved successfully!'),
              ],
            ),
            backgroundColor: AppColors.accentGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showError('Failed to save API key: $e');
    } finally {
      if (mounted) setState(() => _isValidating = false);
    }
  }

  void _showError(String message) {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.accentRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Custom app bar
            _buildAppBar(),
            
            // Progress indicator
            _buildProgressBar(),
            
            // WebView (70%)
            Expanded(
              flex: 7,
              child: Stack(
                children: [
                  WebViewWidget(controller: _controller),
                  if (_isLoading)
                    Container(
                      color: AppColors.background.withOpacity(0.7),
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    ),
                ],
              ),
            ),
            
            // Bottom panel (30%)
            _buildBottomPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      height: 56.h,
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: Colors.white12, width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.close, color: Colors.white, size: 24.sp),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connect Hodl Hodl',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _truncateUrl(_currentUrl),
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11.sp,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Refresh button
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white70, size: 22.sp),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
    );
  }

  String _truncateUrl(String url) {
    if (url.isEmpty) return 'Loading...';
    try {
      final uri = Uri.parse(url);
      final path = uri.path.length > 30 
          ? '${uri.path.substring(0, 30)}...' 
          : uri.path;
      return '${uri.host}$path';
    } catch (_) {
      return url;
    }
  }

  Widget _buildProgressBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      color: AppColors.surface,
      child: Row(
        children: [
          _buildStepIndicator(1, 'Login'),
          _buildStepConnector(1),
          _buildStepIndicator(2, 'API Settings'),
          _buildStepConnector(2),
          _buildStepIndicator(3, 'Copy Key'),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label) {
    final isActive = _currentStep >= step;
    final isCurrent = _currentStep == step;
    
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 28.w,
            height: 28.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? AppColors.primary : Colors.white12,
              border: isCurrent 
                  ? Border.all(color: AppColors.primary, width: 2) 
                  : null,
            ),
            child: Center(
              child: isActive && !isCurrent
                  ? Icon(Icons.check, color: Colors.white, size: 16.sp)
                  : Text(
                      '$step',
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.white38,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white38,
              fontSize: 10.sp,
              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector(int afterStep) {
    final isActive = _currentStep > afterStep;
    return Container(
      width: 24.w,
      height: 2,
      margin: EdgeInsets.only(bottom: 20.h),
      color: isActive ? AppColors.primary : Colors.white12,
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        border: Border(top: BorderSide(color: Colors.white12, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Current step instructions
          _buildStepInstructions(),
          
          SizedBox(height: 12.h),
          
          // API Key input field (always visible)
          Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: _isOnApiPage ? AppColors.primary : Colors.white12,
                width: _isOnApiPage ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _apiKeyController,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.sp,
                      fontFamily: 'monospace',
                    ),
                    decoration: InputDecoration(
                      hintText: 'Paste your API key here',
                      hintStyle: TextStyle(color: Colors.white38, fontSize: 13.sp),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(14.w),
                      prefixIcon: Icon(
                        Icons.key,
                        color: _isOnApiPage ? AppColors.primary : Colors.white38,
                        size: 20.sp,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                // Paste button
                IconButton(
                  icon: Icon(Icons.paste, color: Colors.white54, size: 20.sp),
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    if (data?.text != null) {
                      _apiKeyController.text = data!.text!;
                      setState(() {});
                      HapticFeedback.lightImpact();
                    }
                  },
                ),
              ],
            ),
          ),
          
          SizedBox(height: 12.h),
          
          // Action buttons
          Row(
            children: [
              // Go to API Settings button
              if (_currentStep == 2)
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.primary),
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    onPressed: _goToApiSettings,
                    icon: Icon(Icons.settings, size: 18.sp),
                    label: Text(
                      'Go to API Settings',
                      style: TextStyle(fontSize: 13.sp),
                    ),
                  ),
                ),
              
              if (_currentStep == 2) SizedBox(width: 12.w),
              
              // Save button
              Expanded(
                child: SizedBox(
                  height: 48.h,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _apiKeyController.text.isNotEmpty
                          ? AppColors.primary
                          : Colors.white12,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _apiKeyController.text.isNotEmpty && !_isValidating
                        ? _validateAndSaveApiKey
                        : null,
                    child: _isValidating
                        ? SizedBox(
                            width: 20.w,
                            height: 20.h,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check, size: 18.sp),
                              SizedBox(width: 8.w),
                              Text(
                                'Connect',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w700,
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
    );
  }

  Widget _buildStepInstructions() {
    String instruction;
    IconData icon;
    
    switch (_currentStep) {
      case 1:
        instruction = 'Sign up or log in to your Hodl Hodl account';
        icon = Icons.login;
        break;
      case 2:
        instruction = 'Navigate to Settings → API to get your key';
        icon = Icons.settings;
        break;
      case 3:
        instruction = 'Copy your API key and paste it below';
        icon = Icons.content_copy;
        break;
      default:
        instruction = '';
        icon = Icons.info;
    }
    
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 18.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              instruction,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
