import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/services/hodl_hodl/hodl_hodl.dart';

/// API Setup screen for Hodl Hodl
/// Allows users to configure their API key
class HodlHodlApiSetupScreen extends ConsumerStatefulWidget {
  const HodlHodlApiSetupScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HodlHodlApiSetupScreen> createState() => _HodlHodlApiSetupScreenState();
}

class _HodlHodlApiSetupScreenState extends ConsumerState<HodlHodlApiSetupScreen> {
  final _apiKeyController = TextEditingController();
  bool _isLoading = false;
  bool _isSaving = false;
  bool _obscureKey = true;
  String? _currentKey;

  @override
  void initState() {
    super.initState();
    _loadCurrentKey();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentKey() async {
    setState(() => _isLoading = true);
    try {
      final service = ref.read(hodlHodlServiceProvider);
      final key = await service.getApiKey();
      if (mounted) {
        setState(() {
          _currentKey = key;
          if (key != null) {
            _apiKeyController.text = key;
          }
        });
      }
    } catch (e) {
      // Ignore errors
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveApiKey() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter an API key'),
          backgroundColor: AppColors.accentRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final service = ref.read(hodlHodlServiceProvider);
      await service.setApiKey(key);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('API key saved successfully'),
            backgroundColor: AppColors.accentGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save API key: $e'),
            backgroundColor: AppColors.accentRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _removeApiKey() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Text(
          'Remove API Key',
          style: TextStyle(color: Colors.white, fontSize: 18.sp),
        ),
        content: Text(
          'Are you sure you want to remove your Hodl Hodl API key?',
          style: TextStyle(color: Colors.white70, fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final service = ref.read(hodlHodlServiceProvider);
      await service.clearApiKey();
      
      if (mounted) {
        setState(() {
          _currentKey = null;
          _apiKeyController.clear();
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('API key removed'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove API key: $e'),
            backgroundColor: AppColors.accentRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
        title: Text(
          'Hodl Hodl Setup',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : SingleChildScrollView(
                padding: EdgeInsets.all(24.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info banner
                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.security, color: AppColors.primary, size: 24.sp),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Text(
                                  'Non-Custodial Trading',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12.h),
                          Text(
                            'Hodl Hodl is a non-custodial P2P exchange. You need an API key to create trades. Get one for free at hodlhodl.com',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 32.h),
                    
                    // API Key input
                    Text(
                      'API Key',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: TextField(
                        controller: _apiKeyController,
                        obscureText: _obscureKey,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontFamily: 'monospace',
                        ),
                        decoration: InputDecoration(
                          hintText: 'Paste your API key here',
                          hintStyle: TextStyle(color: Colors.white38, fontSize: 14.sp),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16.w),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureKey ? Icons.visibility_off : Icons.visibility,
                              color: Colors.white54,
                            ),
                            onPressed: () {
                              setState(() => _obscureKey = !_obscureKey);
                            },
                          ),
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 12.h),
                    
                    // How to get key
                    GestureDetector(
                      onTap: () {
                        // Copy URL to clipboard
                        Clipboard.setData(const ClipboardData(
                          text: 'https://hodlhodl.com/settings/api',
                        ));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('URL copied to clipboard'),
                            backgroundColor: AppColors.accentGreen,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.help_outline, color: Colors.white54, size: 18.sp),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'How to get an API key',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    '1. Create account at hodlhodl.com\n2. Go to Settings → API\n3. Generate new API key',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12.sp,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.copy, color: Colors.white38, size: 16.sp),
                          ],
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 32.h),
                    
                    // Save button
                    SizedBox(
                      width: double.infinity,
                      height: 56.h,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _isSaving ? null : _saveApiKey,
                        child: _isSaving
                            ? SizedBox(
                                width: 24.w,
                                height: 24.h,
                                child: const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Save API Key',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    
                    // Remove key option
                    if (_currentKey != null) ...[
                      SizedBox(height: 16.h),
                      Center(
                        child: TextButton(
                          onPressed: _removeApiKey,
                          child: Text(
                            'Remove API Key',
                            style: TextStyle(
                              color: AppColors.accentRed,
                              fontSize: 14.sp,
                            ),
                          ),
                        ),
                      ),
                    ],
                    
                    SizedBox(height: 32.h),
                    
                    // Security note
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: AppColors.accentGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lock, color: AppColors.accentGreen, size: 16.sp),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Text(
                              'Your API key is stored securely on your device and never shared.',
                              style: TextStyle(
                                color: AppColors.accentGreen,
                                fontSize: 12.sp,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
