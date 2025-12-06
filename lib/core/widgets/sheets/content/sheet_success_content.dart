import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';

/// Reusable success content widget for bottom sheets
/// 
/// Displays a success icon with optional title and message
/// Used in success sheets
class SheetSuccessContent extends StatelessWidget {
  /// Optional title to display
  final String? title;
  
  /// The success message to display
  final String message;
  
  /// The icon to display (default: tick_circle5)
  final IconData icon;
  
  /// The color of the icon (default: green)
  final Color iconColor;
  
  /// The size of the icon (default: 64)
  final double iconSize;

  const SheetSuccessContent({
    super.key,
    this.title,
    required this.message,
    this.icon = Iconsax.tick_circle5,
    this.iconColor = Colors.green,
    this.iconSize = 64,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Success icon
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: iconSize,
            color: iconColor,
          ),
        )
            .animate()
            .scale(duration: 600.ms, curve: Curves.elasticOut)
            .fadeIn(duration: 400.ms),
        const SizedBox(height: 24),

        // Title (if provided)
        if (title != null) ...[
          Text(
            title!,
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
        ],

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
      ],
    );
  }
}

