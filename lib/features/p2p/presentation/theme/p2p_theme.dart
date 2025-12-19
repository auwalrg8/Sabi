import 'package:flutter/material.dart';

class P2PColors {
  static const background = Color(0xFF0F1115);
  static const primary = Color(0xFF4CAF50);
  static const success = Color(0xFF2ECC71);
  static const error = Color(0xFFE74C3C);
  static const surface = Color(0xFF1B1D22);
  static const cardBackgroundLight = Color(0xFF23252A);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF9AA0A6);
  static const textMuted = Color(0xFF7B8086);
  static const divider = Color(0xFF2A2D33);
}

class P2PTextStyles {
  static const heading2 = TextStyle(fontSize: 20, color: Colors.white);
  static const bodyLarge = TextStyle(fontSize: 16, color: Colors.white);
  static const bodyMedium = TextStyle(fontSize: 14, color: Colors.white);
  static const bodySmall = TextStyle(fontSize: 12, color: Color(0xFF9AA0A6));
  static const statLabel = TextStyle(fontSize: 12, color: Color(0xFF9AA0A6));
  static const caption = TextStyle(fontSize: 12, color: Color(0xFF9AA0A6));
  static const priceText = TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white);
}

class P2PDecorations {
  static final cardDecoration = BoxDecoration(
    color: P2PColors.cardBackgroundLight,
    borderRadius: BorderRadius.circular(12),
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
