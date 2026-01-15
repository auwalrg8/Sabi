import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Reusable animated dialog icon widget
///
/// Displays an icon with a circular background and animations
/// Used in all dialog types (info, success, error, warning, danger)
class DialogIcon extends StatelessWidget {
  /// The icon to display
  final IconData icon;

  /// The color of the icon
  final Color iconColor;

  /// The background color of the icon container
  final Color backgroundColor;

  /// The size of the icon (default: 64)
  final double iconSize;

  /// The padding around the icon (default: 24)
  final double padding;

  /// Whether to apply shake animation (used for danger/warning dialogs)
  final bool applyShake;

  const DialogIcon({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    this.iconSize = 64,
    this.padding = 24,
    this.applyShake = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      child: Icon(icon, size: iconSize, color: iconColor),
    );

    // Apply animations
    var animatedWidget = iconWidget
        .animate()
        .scale(duration: 600.ms, curve: Curves.elasticOut)
        .fadeIn(duration: 400.ms);

    // Add shake animation for danger/warning dialogs
    if (applyShake) {
      animatedWidget = animatedWidget.shake(duration: 400.ms, delay: 200.ms);
    }

    return animatedWidget;
  }
}
