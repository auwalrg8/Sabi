import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/core/services/secure_storage_service.dart';
import 'package:sabi_wallet/features/wallet/presentation/screens/home_screen.dart';

class PinLoginScreen extends ConsumerStatefulWidget {
  const PinLoginScreen({super.key});

  @override
  ConsumerState<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends ConsumerState<PinLoginScreen> {
  String _pin = '';
  String _errorMessage = '';
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _canUseBiometrics = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      setState(() {
        _canUseBiometrics = canCheck && isDeviceSupported;
      });

      // Auto-trigger biometric if available
      if (_canUseBiometrics) {
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
        _validatePin();
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Logo/Icon
              const Icon(
                Icons.lock_outline,
                color: AppColors.primary,
                size: 80,
              ),
              const SizedBox(height: 40),

              // Title
              const Text(
                'Enter PIN',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontFamily: 'Inter',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),

              // Subtitle
              const Text(
                'Enter your 4-digit PIN to unlock',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // PIN Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final isFilled = index < _pin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFilled ? AppColors.primary : AppColors.surface,
                      border: Border.all(
                        color:
                            isFilled
                                ? AppColors.primary
                                : AppColors.borderColor,
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),

              // Error Message
              const SizedBox(height: 20),
              SizedBox(
                height: 20,
                child:
                    _errorMessage.isNotEmpty
                        ? Text(
                          _errorMessage,
                          style: const TextStyle(
                            color: AppColors.accentRed,
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        )
                        : null,
              ),

              const Spacer(),

              // Number Pad
              _NumberPad(
                onNumberPressed: _onNumberPressed,
                onDeletePressed: _onDeletePressed,
              ),

              // Biometric Button
              if (_canUseBiometrics) ...[
                const SizedBox(height: 20),
                TextButton.icon(
                  onPressed: _authenticateWithBiometrics,
                  icon: const Icon(
                    Icons.fingerprint,
                    color: AppColors.primary,
                    size: 28,
                  ),
                  label: const Text(
                    'Use Biometrics',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 40),
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
      width: 300,
      child: Column(
        children: [
          // Rows 1-3
          for (var row = 0; row < 3; row++)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
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

          // Bottom row with 0 and delete
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const SizedBox(width: 70, height: 70), // Spacer
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
      borderRadius: BorderRadius.circular(35),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surface,
          border: Border.all(color: AppColors.borderColor, width: 1),
        ),
        child: Center(
          child: Text(
            number,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'Inter',
              fontSize: 24,
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
      borderRadius: BorderRadius.circular(35),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surface,
          border: Border.all(color: AppColors.borderColor, width: 1),
        ),
        child: const Center(
          child: Icon(
            Icons.backspace_outlined,
            color: AppColors.textSecondary,
            size: 24,
          ),
        ),
      ),
    );
  }
}
