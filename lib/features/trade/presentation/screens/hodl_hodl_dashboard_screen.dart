import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/services/hodl_hodl/hodl_hodl.dart';

import 'hodl_hodl_profile_screen.dart';
import 'hodl_hodl_webview_setup_screen.dart';
import 'hodl_hodl_payment_methods_screen.dart';

/// HodlHodl Dashboard - User's trading profile connected to HodlHodl API
class HodlHodlDashboardScreen extends ConsumerStatefulWidget {
  const HodlHodlDashboardScreen({super.key});

  @override
  ConsumerState<HodlHodlDashboardScreen> createState() =>
      _HodlHodlDashboardScreenState();
}

class _HodlHodlDashboardScreenState
    extends ConsumerState<HodlHodlDashboardScreen> {
  bool _loading = true;
  String? _errorMessage;
  bool _isApiKeyIssue = false;

  // User data from HodlHodl API
  Map<String, dynamic>? _userData;
  // ignore: unused_field - stored for future trade history display
  List<HodlHodlContract>? _contracts;
  List<Map<String, dynamic>> _paymentInstructions = [];

  // Stats
  int _completedTrades = 0;
  int _activeTrades = 0;
  int _totalTrades = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final hodlHodlService = HodlHodlService();
      final isConfigured = await hodlHodlService.isConfigured();

      if (!isConfigured) {
        setState(() {
          _loading = false;
          _errorMessage = 'Not connected to HodlHodl';
        });
        return;
      }

      // Fetch user data, contracts, and payment instructions from HodlHodl API
      final results = await Future.wait([
        hodlHodlService.getMe(),
        hodlHodlService.getMyContracts(limit: 100),
        hodlHodlService.getMyPaymentInstructions(),
      ]);

      final userData = results[0] as Map<String, dynamic>;
      final contracts = results[1] as List<HodlHodlContract>;
      final paymentInstructions = results[2] as List<Map<String, dynamic>>;

      // Calculate stats
      int completed = 0;
      int active = 0;
      for (final contract in contracts) {
        if (contract.status == 'completed') {
          completed++;
        } else if (contract.status != 'cancelled' &&
            contract.status != 'expired') {
          active++;
        }
      }

      if (mounted) {
        setState(() {
          _userData = userData;
          _contracts = contracts;
          _paymentInstructions = paymentInstructions;
          _completedTrades = completed;
          _activeTrades = active;
          _totalTrades = contracts.length;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString();
        bool isApiKeyIssue = false;
        
        // Clean up the error message
        if (errorMsg.contains('Exception:')) {
          errorMsg = errorMsg.replaceFirst('Exception:', '').trim();
        }
        if (errorMsg.contains('HodlHodlApiException')) {
          // Extract the message from HodlHodlApiException
          final match = RegExp(r'HodlHodlApiException:\s*(.+)').firstMatch(errorMsg);
          if (match != null) {
            errorMsg = match.group(1) ?? errorMsg;
          }
        }
        
        // Check for API key related issues first
        if (errorMsg.contains('api_key_invalid') || 
            errorMsg.contains('invalid_api_key') || 
            errorMsg.contains('authentication_failed') ||
            errorMsg.contains('API key is invalid') ||
            errorMsg.contains('API access not enabled')) {
          errorMsg = 'API access is not enabled or your API key is invalid.\n\nTo fix this:\n1. Go to HodlHodl.com\n2. Open Account Settings → API Access tab\n3. Enable "API Access"\n4. Copy your API key\n5. Tap "Reconnect" below';
          isApiKeyIssue = true;
        } else if (errorMsg.contains('<!DOCTYPE') || errorMsg.contains('<html') || errorMsg.contains('404')) {
          errorMsg = 'Unable to authenticate with HodlHodl.\n\nMake sure API access is enabled in your HodlHodl account settings (Account Settings → API Access tab).';
          isApiKeyIssue = true;
        } else if (errorMsg.contains('401') || errorMsg.contains('Unauthorized') || errorMsg.contains('unauthorized')) {
          errorMsg = 'Authentication failed. Please check that API access is enabled in your HodlHodl account settings.';
          isApiKeyIssue = true;
        } else if (errorMsg.contains('network') || errorMsg.contains('SocketException')) {
          errorMsg = 'Network error. Please check your connection.';
        } else if (errorMsg.contains('server_error')) {
          errorMsg = 'HodlHodl server is temporarily unavailable. Please try again later.';
        } else if (errorMsg.contains('FormatException')) {
          errorMsg = 'HodlHodl service returned an invalid response. Please try again later.';
        }
        
        setState(() {
          _loading = false;
          _errorMessage = errorMsg;
          _isApiKeyIssue = isApiKeyIssue;
        });
      }
    }
  }

  double get _successRate {
    if (_totalTrades == 0) return 100;
    return (_completedTrades / _totalTrades) * 100;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20.sp),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'HodlHodl Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon:
                Icon(Icons.refresh_rounded, color: AppColors.primary, size: 24.sp),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2.w,
              ),
            )
          : _errorMessage != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: AppColors.primary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(20.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Profile Header
                        _buildProfileHeader(),
                        SizedBox(height: 24.h),

                        // Stats Grid
                        _buildStatsGrid(),
                        SizedBox(height: 24.h),

                        // Payment Methods Section
                        _buildPaymentMethodsSection(),
                        SizedBox(height: 24.h),

                        // API Status
                        _buildApiStatusCard(),
                        SizedBox(height: 40.h),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildErrorState() {
    final isNotConnected = _errorMessage?.contains('Not connected') == true;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isNotConnected 
                  ? Icons.link_off_rounded 
                  : _isApiKeyIssue 
                      ? Icons.key_off_rounded 
                      : Icons.error_outline,
              color: isNotConnected || _isApiKeyIssue ? AppColors.primary : AppColors.accentRed,
              size: 64.sp,
            ),
            SizedBox(height: 16.h),
            Text(
              isNotConnected 
                  ? 'Not Connected' 
                  : _isApiKeyIssue 
                      ? 'API Key Issue' 
                      : 'Error Loading Data',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              isNotConnected
                  ? 'Connect your HodlHodl account to see your trading stats'
                  : _errorMessage ?? 'Unknown error',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14.sp,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            if (isNotConnected || _isApiKeyIssue)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HodlHodlWebViewSetupScreen(),
                    ),
                  ).then((_) => _loadData());
                },
                icon: Icon(_isApiKeyIssue ? Icons.refresh : Icons.link, size: 20.sp),
                label: Text(_isApiKeyIssue ? 'Reconnect HodlHodl' : 'Connect HodlHodl'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
            if (!isNotConnected && !_isApiKeyIssue)
              TextButton.icon(
                onPressed: _loadData,
                icon: Icon(Icons.refresh, size: 20.sp),
                label: const Text('Try Again'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            if (_isApiKeyIssue) ...[
              SizedBox(height: 12.h),
              TextButton.icon(
                onPressed: _showDebugInfo,
                icon: Icon(Icons.bug_report, size: 20.sp),
                label: const Text('Debug API Connection'),
                style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showDebugInfo() async {
    setState(() => _loading = true);
    
    try {
      final debugInfo = await HodlHodlService().debugApiConnection();
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            'API Debug Info',
            style: TextStyle(color: Colors.white, fontSize: 18.sp),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _debugRow('Status Code', '${debugInfo['statusCode'] ?? 'N/A'}'),
                _debugRow('Content-Type', '${debugInfo['contentType'] ?? 'N/A'}'),
                _debugRow('Is HTML Response', '${debugInfo['isHtml'] ?? 'N/A'}'),
                _debugRow('API Key Configured', '${debugInfo['apiKeyConfigured'] ?? false}'),
                _debugRow('API Key Length', '${debugInfo['apiKeyLength'] ?? 'N/A'}'),
                _debugRow('Body Length', '${debugInfo['bodyLength'] ?? 0}'),
                SizedBox(height: 12.h),
                Text(
                  'Response Preview:',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
                ),
                SizedBox(height: 4.h),
                Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    '${debugInfo['bodyPreview'] ?? debugInfo['error'] ?? 'No data'}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10.sp,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close', style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _debugRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp)),
          Text(value, style: TextStyle(color: Colors.white, fontSize: 12.sp)),
        ],
      ),
    );
  }

  void _openProfileEdit() {
    if (_userData == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HodlHodlProfileScreen(userData: _userData!),
      ),
    ).then((result) {
      if (result == true) {
        _loadData();
      }
    });
  }

  Widget _buildProfileHeader() {
    final login = _userData?['login'] ?? 'Trader';
    final rating = _userData?['rating'];
    final verified = _userData?['verified'] == true;
    final tradesCount = _userData?['trades_count'] ?? _completedTrades;

    return GestureDetector(
      onTap: _openProfileEdit,
      child: Container(
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withValues(alpha: 0.2),
              AppColors.surface,
            ],
          ),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 32.r,
              backgroundColor: AppColors.primary,
              child: Text(
                login.isNotEmpty ? login[0].toUpperCase() : 'T',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(width: 16.w),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        login,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (verified) ...[
                        SizedBox(width: 6.w),
                        Icon(
                          Icons.verified_rounded,
                          color: AppColors.accentGreen,
                          size: 18.sp,
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      if (rating != null) ...[
                        Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: 16.sp,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          rating.toString(),
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(width: 12.w),
                      ],
                      Text(
                        '$tradesCount trades',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13.sp,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Edit button
            Icon(
              Icons.edit_outlined,
              color: AppColors.primary,
              size: 20.sp,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.check_circle_outline_rounded,
            iconColor: AppColors.accentGreen,
            label: 'Completed',
            value: '$_completedTrades',
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _buildStatCard(
            icon: Icons.hourglass_empty_rounded,
            iconColor: Colors.orange,
            label: 'Active',
            value: '$_activeTrades',
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _buildStatCard(
            icon: Icons.trending_up_rounded,
            iconColor: AppColors.primary,
            label: 'Success',
            value: '${_successRate.toStringAsFixed(0)}%',
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 12.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 24.sp),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11.sp,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsSection() {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Payment Methods',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HodlHodlPaymentMethodsScreen(),
                    ),
                  ).then((_) => _loadData());
                },
                child: Text(
                  _paymentInstructions.isEmpty ? 'Add' : 'Manage',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          if (_paymentInstructions.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.textSecondary,
                    size: 20.sp,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      'Add payment methods to your HodlHodl account',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13.sp,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: _paymentInstructions.take(3).map((instruction) {
                final name = instruction['name'] ?? 'Unknown';
                final methodName = instruction['payment_method_name'] ?? '';
                final methodType = instruction['payment_method_type'] ?? '';
                return Padding(
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: Row(
                    children: [
                      Icon(Icons.payment, color: AppColors.primary, size: 18.sp),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13.sp,
                              ),
                            ),
                            if (methodName.isNotEmpty || methodType.isNotEmpty)
                              Text(
                                methodName.isNotEmpty ? methodName : methodType,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11.sp,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          if (_paymentInstructions.length > 3) ...[
            SizedBox(height: 8.h),
            Text(
              '+${_paymentInstructions.length - 3} more',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.sp,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildApiStatusCard() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const HodlHodlWebViewSetupScreen(),
          ),
        ).then((_) => _loadData());
      },
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color: AppColors.accentGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child:
                  Icon(Icons.link, color: AppColors.accentGreen, size: 20.sp),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HodlHodl Connected',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'Tap to manage API settings',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
              size: 24.sp,
            ),
          ],
        ),
      ),
    );
  }
}
