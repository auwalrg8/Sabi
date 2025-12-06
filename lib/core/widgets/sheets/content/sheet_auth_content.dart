import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sabi_wallet/core/constants/colors.dart';

/// Reusable authentication content widget for bottom sheets
/// 
/// Displays an auth icon with title, message, and action buttons
/// Used in authentication required sheets
class SheetAuthContent extends StatelessWidget {
  /// The title to display
  final String title;
  
  /// The message to display
  final String message;
  
  /// Callback when cancel button is pressed
  final VoidCallback onCancel;
  
  /// Callback when sign in button is pressed
  final VoidCallback onSignIn;
  
  /// The icon to display (default: lock_1)
  final IconData icon;

  const SheetAuthContent({
    super.key,
    required this.title,
    required this.message,
    required this.onCancel,
    required this.onSignIn,
    this.icon = Iconsax.lock_1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Auth icon
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
        )
            .animate()
            .scale(duration: 600.ms, curve: Curves.elasticOut)
            .fadeIn(duration: 400.ms),
        const SizedBox(height: 24),

        // Title
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
          textAlign: TextAlign.center,
        )
            .animate()
            .fadeIn(duration: 400.ms, delay: 200.ms)
            .slideY(
              begin: 0.2,
              end: 0,
              duration: 400.ms,
              delay: 200.ms,
            ),
        const SizedBox(height: 12),

        // Message
        Text(
          message,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
          textAlign: TextAlign.center,
        )
            .animate()
            .fadeIn(duration: 400.ms, delay: 300.ms)
            .slideY(
              begin: 0.2,
              end: 0,
              duration: 400.ms,
              delay: 300.ms,
            ),
        const SizedBox(height: 32),

        // Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: onSignIn,
                icon: const Icon(Iconsax.login),
                label: Text('Sign In', style: TextStyle(color: AppColors.surface)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        )
            .animate()
            .fadeIn(duration: 400.ms, delay: 400.ms)
            .slideY(
              begin: 0.2,
              end: 0,
              duration: 400.ms,
              delay: 400.ms,
            ),
      ],
    );
  }
}

