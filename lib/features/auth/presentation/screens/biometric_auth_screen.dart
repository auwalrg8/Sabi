import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:local_auth/local_auth.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/core/services/secure_storage_service.dart';
import 'package:sabi_wallet/features/wallet/presentation/screens/home_screen.dart';
import 'package:sabi_wallet/features/profile/presentation/providers/settings_provider.dart';

class BiometricAuthScreen extends ConsumerStatefulWidget {
  const BiometricAuthScreen({super.key, required HomeScreen child});

  @override
  ConsumerState<BiometricAuthScreen> createState() =>
      _BiometricAuthScreenState();
}

class _BiometricAuthScreenState extends ConsumerState<BiometricAuthScreen> {
  String _pin = '';
  String _errorMessage = '';
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _canUseBiometrics = false;
  bool _isCheckingPin = true; // Show loading while checking PIN status

  @override
  void initState() {
    super.initState();
    _initAuth();
  }

  /// Initialize auth - check if PIN exists first, then proceed accordingly
  Future<void> _initAuth() async {
    final storage = ref.read(secureStorageServiceProvider);
    final hasPin = await storage.hasPinCode();

    if (!hasPin) {
      // No PIN set - go directly to Home
      if (mounted) _navigateToHome();
      return;
    }

    // PIN exists - show PIN screen
    if (mounted) {
      setState(() {
        _isCheckingPin = false;
      });
    }

    // Now check biometrics
    _checkBiometrics();
  }

  Future<void> _checkPinAndAuthenticate() async {
    final storage = ref.read(secureStorageServiceProvider);
    final hasPin = await storage.hasPinCode();
    if (!hasPin) {
      // No PIN set — don't force creation here. Let user set PIN from settings or suggestions.
      // Proceed to Home directly.
      if (mounted) _navigateToHome();
      return;
    }

    // PIN exists -> validate it
    await _validatePin();
  }

  Future<void> _checkBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      setState(() {
        _canUseBiometrics = canCheck && isDeviceSupported;
      });

      // Only attempt biometric auth if the user enabled it in app settings
      final settings = ref.read(settingsNotifierProvider);
      final biometricEnabled = settings.biometricEnabled;
      if (_canUseBiometrics && biometricEnabled) {
        await _authenticateWithBiometrics();
      }
    } catch (e) {
      debugPrint('Biometric check error: $e');
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access your wallet',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated && mounted) {
        _navigateToHome();
      }
    } catch (e) {
      debugPrint('Biometric auth error: $e');
    }
  }

  void _onNumberPressed(String number) {
    if (_pin.length >= 4) return;

    setState(() {
      _errorMessage = '';
      _pin += number;

      if (_pin.length == 4) {
        _checkPinAndAuthenticate();
      }
    });
  }

  void _onDeletePressed() {
    if (_pin.isEmpty) return;

    setState(() {
      _errorMessage = '';
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  Future<void> _validatePin() async {
    final storage = ref.read(secureStorageServiceProvider);
    final isValid = await storage.verifyPinCode(_pin);

    if (isValid) {
      _navigateToHome();
    } else {
      setState(() {
        _errorMessage = 'Incorrect PIN. Please try again.';
        _pin = '';
      });
    }
  }

  void _navigateToHome() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while checking if PIN is set
    if (_isCheckingPin) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 30.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              Icon(Icons.lock_outline, color: AppColors.primary, size: 80.sp),
              SizedBox(height: 40.h),

              Text(
                'Enter PIN',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontFamily: 'Inter',
                  fontSize: 28.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 12.h),

              Text(
                'Enter your 4-digit PIN to unlock',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontFamily: 'Inter',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 40.h),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final isFilled = index < _pin.length;
                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 8.w),
                    width: 16.w,
                    height: 16.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFilled ? AppColors.primary : AppColors.surface,
                      border: Border.all(
                        color:
                            isFilled
                                ? AppColors.primary
                                : AppColors.borderColor,
                        width: 2.w,
                      ),
                    ),
                  );
                }),
              ),

              SizedBox(height: 20.h),
              SizedBox(
                height: 20.h,
                child:
                    _errorMessage.isNotEmpty
                        ? Text(
                          _errorMessage,
                          style: TextStyle(
                            color: AppColors.accentRed,
                            fontFamily: 'Inter',
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w400,
                          ),
                        )
                        : null,
              ),

              const Spacer(),

              _NumberPad(
                onNumberPressed: _onNumberPressed,
                onDeletePressed: _onDeletePressed,
              ),

              if (_canUseBiometrics) ...[
                SizedBox(height: 20.h),
                TextButton.icon(
                  onPressed: _authenticateWithBiometrics,
                  icon: Icon(
                    Icons.fingerprint,
                    color: AppColors.primary,
                    size: 28.sp,
                  ),
                  label: Text(
                    'Use Biometrics',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontFamily: 'Inter',
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],

              SizedBox(height: 40.h),
            ],
          ),
        ),
      ),
    );
  }
}

class _NumberPad extends StatelessWidget {
  final Function(String) onNumberPressed;
  final VoidCallback onDeletePressed;

  const _NumberPad({
    required this.onNumberPressed,
    required this.onDeletePressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300.w,
      child: Column(
        children: [
          for (var row = 0; row < 3; row++)
            Padding(
              padding: EdgeInsets.only(bottom: 20.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (var col = 1; col <= 3; col++)
                    _NumberButton(
                      number: '${row * 3 + col}',
                      onPressed: onNumberPressed,
                    ),
                ],
              ),
            ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              SizedBox(width: 70.w, height: 70.h),
              _NumberButton(number: '0', onPressed: onNumberPressed),
              _DeleteButton(onPressed: onDeletePressed),
            ],
          ),
        ],
      ),
    );
  }
}

class _NumberButton extends StatelessWidget {
  final String number;
  final Function(String) onPressed;

  const _NumberButton({required this.number, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onPressed(number),
      borderRadius: BorderRadius.circular(35.r),
      child: Container(
        width: 70.w,
        height: 70.h,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surface,
          border: Border.all(color: AppColors.borderColor, width: 1.w),
        ),
        child: Center(
          child: Text(
            number,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'Inter',
              fontSize: 24.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _DeleteButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _DeleteButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(35.r),
      child: Container(
        width: 70.w,
        height: 70.h,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surface,
          border: Border.all(color: AppColors.borderColor, width: 1.w),
        ),
        child: Center(
          child: Icon(
            Icons.backspace_outlined,
            color: AppColors.textSecondary,
            size: 24.sp,
          ),
        ),
      ),
    );
  }
}
