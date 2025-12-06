import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Reusable loading indicator widget for bottom sheets
/// 
/// Displays a circular progress indicator with animations
/// Used in loading sheets
class SheetLoadingIndicator extends StatelessWidget {
  /// The loading message to display
  final String message;
  
  /// The size of the loading indicator (default: 48)
  final double indicatorSize;
  
  /// The padding around the indicator (default: 24)
  final double padding;

  const SheetLoadingIndicator({
    super.key,
    required this.message,
    this.indicatorSize = 48,
    this.padding = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Loading indicator
        Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: SizedBox(
            width: indicatorSize,
            height: indicatorSize,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        )
            .animate(onPlay: (controller) => controller.repeat())
            .rotate(duration: 2000.ms)
            .then()
            .shimmer(duration: 1000.ms),
        const SizedBox(height: 24),

        // Message
        Text(
          message,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
          textAlign: TextAlign.center,
        )
            .animate()
            .fadeIn(duration: 400.ms)
            .slideY(begin: 0.2, end: 0, duration: 400.ms),
      ],
    );
  }
}

