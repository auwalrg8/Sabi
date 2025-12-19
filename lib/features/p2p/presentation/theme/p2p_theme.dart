import 'package:flutter/material.dart';
import 'package:sabi_wallet/core/constants/colors.dart';

// Map P2P theme tokens to the app's canonical `AppColors` so P2P UI
// uses the same color system as the rest of the app.
class P2PColors {
  static const background = AppColors.background;
  static const primary = AppColors.primary;
  static const success = AppColors.accentGreen;
  static const error = AppColors.accentRed;
  static const surface = AppColors.surface;
  static const cardBackgroundLight = AppColors.surface;
  static const textPrimary = AppColors.textPrimary;
  static const textSecondary = AppColors.textSecondary;
  static const textMuted = AppColors.textTertiary;
  static const divider = AppColors.borderColor;
}

class P2PTextStyles {
  static const heading2 = TextStyle(fontSize: 20, color: AppColors.textPrimary);
  static const bodyLarge = TextStyle(fontSize: 16, color: AppColors.textPrimary);
  static const bodyMedium = TextStyle(fontSize: 14, color: AppColors.textPrimary);
  static const bodySmall = TextStyle(fontSize: 12, color: AppColors.textSecondary);
  static const statLabel = TextStyle(fontSize: 12, color: AppColors.textSecondary);
  static const caption = TextStyle(fontSize: 12, color: AppColors.textSecondary);
  static const priceText = TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary);
}

class P2PDecorations {
  static final cardDecoration = BoxDecoration(
    color: P2PColors.cardBackgroundLight,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 6, offset: const Offset(0, 2)),
    ],
  );

  static final statCardDecoration = BoxDecoration(
    color: P2PColors.surface,
    borderRadius: BorderRadius.circular(8),
  );
}

class P2PAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const P2PAppBar({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: P2PColors.background,
      elevation: 0,
      title: Text(title, style: P2PTextStyles.heading2),
      centerTitle: true,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
