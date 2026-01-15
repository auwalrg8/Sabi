import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sabi_wallet/core/constants/colors.dart';

/// Reusable dialog button widget
///
/// A full-width elevated button with animations
/// Used for single-button dialogs (info, success, error, warning)
class DialogButton extends StatelessWidget {
  /// The button text
  final String text;

  /// Callback when button is pressed
  final VoidCallback onPressed;

  /// Background color of the button (optional, uses theme primary if not provided)
  final Color? backgroundColor;

  /// Foreground/text color of the button (optional, uses theme onPrimary if not provided)
  final Color? foregroundColor;

  /// Delay before button animation starts (default: 400ms)
  final int animationDelay;

  const DialogButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.animationDelay = 400,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  backgroundColor ?? Theme.of(context).colorScheme.primary,
              foregroundColor: foregroundColor ?? AppColors.surface,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(text, style: const TextStyle(color: AppColors.surface)),
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms, delay: animationDelay.ms)
        .slideY(begin: 0.2, end: 0, duration: 400.ms, delay: animationDelay.ms);
  }
}
