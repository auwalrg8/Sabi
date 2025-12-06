import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/core/services/secure_storage_service.dart';

enum PinChangeStep { enterCurrent, enterNew, confirmNew }

class ChangePinScreen extends ConsumerStatefulWidget {
  final bool isCreate;

  const ChangePinScreen({super.key, this.isCreate = false});

  @override
  ConsumerState<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends ConsumerState<ChangePinScreen> {
  late PinChangeStep _currentStep;
  String _currentPin = '';
  String _newPin = '';
  String _confirmPin = '';
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    // Skip current PIN step if creating new PIN
    _currentStep =
        widget.isCreate ? PinChangeStep.enterNew : PinChangeStep.enterCurrent;
  }

  String get _currentPinInput {
    switch (_currentStep) {
      case PinChangeStep.enterCurrent:
        return _currentPin;
      case PinChangeStep.enterNew:
        return _newPin;
      case PinChangeStep.confirmNew:
        return _confirmPin;
    }
  }

  String get _title {
    switch (_currentStep) {
      case PinChangeStep.enterCurrent:
        return 'Enter Current PIN';
      case PinChangeStep.enterNew:
        return 'Enter New PIN';
      case PinChangeStep.confirmNew:
        return 'Confirm New PIN';
    }
  }

  String get _subtitle {
    switch (_currentStep) {
      case PinChangeStep.enterCurrent:
        return 'Please enter your current 4-digit PIN';
      case PinChangeStep.enterNew:
        return 'Create a new 4-digit PIN';
      case PinChangeStep.confirmNew:
        return 'Re-enter your new PIN to confirm';
    }
  }

  void _onNumberPressed(String number) {
    setState(() {
      _errorMessage = '';

      switch (_currentStep) {
        case PinChangeStep.enterCurrent:
          if (_currentPin.length < 4) {
            _currentPin += number;
            if (_currentPin.length == 4) {
              _validateCurrentPin();
            }
          }
          break;
        case PinChangeStep.enterNew:
          if (_newPin.length < 4) {
            _newPin += number;
            if (_newPin.length == 4) {
              _moveToConfirmStep();
            }
          }
          break;
        case PinChangeStep.confirmNew:
          if (_confirmPin.length < 4) {
            _confirmPin += number;
            if (_confirmPin.length == 4) {
              _validateAndSavePin();
            }
          }
          break;
      }
    });
  }

  void _onDeletePressed() {
    setState(() {
      _errorMessage = '';

      switch (_currentStep) {
        case PinChangeStep.enterCurrent:
          if (_currentPin.isNotEmpty) {
            _currentPin = _currentPin.substring(0, _currentPin.length - 1);
          }
          break;
        case PinChangeStep.enterNew:
          if (_newPin.isNotEmpty) {
            _newPin = _newPin.substring(0, _newPin.length - 1);
          }
          break;
        case PinChangeStep.confirmNew:
          if (_confirmPin.isNotEmpty) {
            _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
          }
          break;
      }
    });
  }

  Future<void> _validateCurrentPin() async {
    final storage = ref.read(secureStorageServiceProvider);
    final isValid = await storage.verifyPinCode(_currentPin);

    if (!isValid) {
      setState(() {
        _errorMessage = 'Incorrect PIN. Please try again.';
        _currentPin = '';
      });
    } else {
      setState(() {
        _currentStep = PinChangeStep.enterNew;
      });
    }
  }

  void _moveToConfirmStep() {
    setState(() {
      _currentStep = PinChangeStep.confirmNew;
    });
  }

  Future<void> _validateAndSavePin() async {
    if (_newPin != _confirmPin) {
      setState(() {
        _errorMessage = 'PINs do not match. Please try again.';
        _confirmPin = '';
      });
      return;
    }

    final storage = ref.read(secureStorageServiceProvider);
    await storage.savePinCode(_newPin);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.isCreate
              ? 'PIN created successfully'
              : 'PIN changed successfully',
        ),
        backgroundColor: AppColors.accentGreen,
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.textPrimary,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.isCreate ? 'Create PIN' : 'Change PIN',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontFamily: 'Inter',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),

                    // Title
                    Text(
                      _title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'Inter',
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Subtitle
                    Text(
                      _subtitle,
                      style: const TextStyle(
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
                        final isFilled = index < _currentPinInput.length;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                isFilled
                                    ? AppColors.primary
                                    : AppColors.surface,
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

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
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
    return Column(
      children: [
        _buildNumberRow(['1', '2', '3']),
        const SizedBox(height: 16),
        _buildNumberRow(['4', '5', '6']),
        const SizedBox(height: 16),
        _buildNumberRow(['7', '8', '9']),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 80, height: 80), // Empty space
            _NumberButton(number: '0', onPressed: () => onNumberPressed('0')),
            SizedBox(
              width: 80,
              height: 80,
              child: IconButton(
                icon: const Icon(
                  Icons.backspace_outlined,
                  color: AppColors.textPrimary,
                ),
                onPressed: onDeletePressed,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNumberRow(List<String> numbers) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children:
          numbers
              .map(
                (number) => _NumberButton(
                  number: number,
                  onPressed: () => onNumberPressed(number),
                ),
              )
              .toList(),
    );
  }
}

class _NumberButton extends StatelessWidget {
  final String number;
  final VoidCallback onPressed;

  const _NumberButton({required this.number, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 80,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          shape: const CircleBorder(),
          backgroundColor: AppColors.surface,
        ),
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
    );
  }
}
