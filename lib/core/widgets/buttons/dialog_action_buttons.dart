import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sabi_wallet/core/constants/colors.dart';

/// Reusable dialog action buttons widget
///
/// Displays two buttons side-by-side (cancel and confirm)
/// Used for confirmation and danger dialogs
class DialogActionButtons extends StatelessWidget {
  /// The cancel button text
  final String cancelText;

  /// The confirm button text
  final String confirmText;

  /// Callback when cancel button is pressed
  final VoidCallback onCancel;

  /// Callback when confirm button is pressed
  final VoidCallback onConfirm;

  /// Background color of the confirm button (default: red for danger actions)
  final Color? confirmBackgroundColor;

  /// Foreground color of the confirm button (default: white)
  final Color? confirmForegroundColor;

  /// Delay before buttons animation starts (default: 400ms)
  final int animationDelay;

  const DialogActionButtons({
    super.key,
    required this.cancelText,
    required this.confirmText,
    required this.onCancel,
    required this.onConfirm,
    this.confirmBackgroundColor,
    this.confirmForegroundColor,
    this.animationDelay = 400,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
          children: [
            // Cancel button
            Expanded(
              child: OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(cancelText),
              ),
            ),
            const SizedBox(width: 12),

            // Confirm button
            Expanded(
              child: ElevatedButton(
                onPressed: onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: confirmBackgroundColor ?? Colors.red,
                  foregroundColor: confirmForegroundColor ?? AppColors.surface,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  confirmText,
                  style: const TextStyle(color: AppColors.surface),
                ),
              ),
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 400.ms, delay: animationDelay.ms)
        .slideY(begin: 0.2, end: 0, duration: 400.ms, delay: animationDelay.ms);
  }
}
