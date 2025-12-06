import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Reusable dialog content widget
/// 
/// Displays title and message with animations
/// Used in all dialog types
class DialogContent extends StatelessWidget {
  /// The dialog title
  final String title;
  
  /// The dialog message
  final String message;
  
  /// Delay before title animation starts (default: 200ms)
  final int titleDelay;
  
  /// Delay before message animation starts (default: 300ms)
  final int messageDelay;

  const DialogContent({
    super.key,
    required this.title,
    required this.message,
    this.titleDelay = 200,
    this.messageDelay = 300,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
            .fadeIn(duration: 400.ms, delay: titleDelay.ms)
            .slideY(
              begin: 0.2,
              end: 0,
              duration: 400.ms,
              delay: titleDelay.ms,
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
            .fadeIn(duration: 400.ms, delay: messageDelay.ms)
            .slideY(
              begin: 0.2,
              end: 0,
              duration: 400.ms,
              delay: messageDelay.ms,
            ),
      ],
    );
  }
}

