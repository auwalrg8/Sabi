import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';
import 'package:sabi_wallet/services/firebase/webhook_bridge_services.dart';
import 'package:sabi_wallet/services/firebase/fcm_token_registration_service.dart';
import 'package:sabi_wallet/features/wallet/presentation/screens/home_screen.dart';
import 'restore_choice_screen.dart';

class EntryScreen extends ConsumerStatefulWidget {
  const EntryScreen({super.key});

  @override
  ConsumerState<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends ConsumerState<EntryScreen> {
  bool _isLoading = false;

  Future<void> _createNewWallet() async {
    setState(() => _isLoading = true);

    try {
      // Generate new wallet
      await BreezSparkService.initializeSparkSDK();

      // Mark onboarding complete
      await BreezSparkService.setOnboardingComplete();

      // Start webhook bridge for push notifications
      BreezWebhookBridgeService().startListening();
      debugPrint('✅ BreezWebhookBridgeService started after wallet creation');

      // Register FCM token for push notifications
      FCMTokenRegistrationService().registerToken();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating wallet: $e'),
            backgroundColor: const Color(0xFFFF4D4F),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreWallet() async {
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RestoreChoiceScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C1A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Header
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/sabi_logo.png',
                      width: 132.w,
                      fit: BoxFit.contain,
                    ),
                    SizedBox(height: 32.h),
                    Text(
                      'Welcome',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28.sp,
                        fontWeight: FontWeight.w800,
                        height: 1.2.h,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 14.h),
                    Text(
                      'Keep your Bitcoin safe. Nobody fit block your money or freeze your account.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w500,
                        height: 1.5.h,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              // Buttons
              Column(
                children: [
                  // Create Wallet Button
                  SizedBox(
                    width: double.infinity,
                    height: 56.h,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _createNewWallet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFA500),
                        disabledBackgroundColor: const Color(
                          0xFFFFA500,
                        ).withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        elevation: 0,
                      ),
                      icon:
                          _isLoading
                              ? SizedBox(
                                width: 20.w,
                                height: 20.h,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    // Colors.black.withValues(alpha: 0.8),
                                    AppColors.background,
                                  ),
                                  strokeWidth: 2,
                                ),
                              )
                              : Icon(Icons.add, color: AppColors.background),
                      label: Text(
                        _isLoading ? 'Creating...' : "Let's Sabi ₿",
                        style: TextStyle(
                          // color: Colors.black.withValues(alpha: 0.8),
                          color: AppColors.background,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  // Restore Button
                  SizedBox(
                    width: double.infinity,
                    height: 56.h,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _restoreWallet,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Color(0xFF1F2937),
                          width: 1.5.w,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Restore',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
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
    );
  }
}
