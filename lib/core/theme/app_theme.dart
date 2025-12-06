import 'package:flutter/material.dart';

import '../constants/colors.dart';

class AppTheme {
  static final ThemeData light = ThemeData(
    fontFamily: 'Inter',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark, // Dark mode base
      primary: AppColors.primary,
      surface: AppColors.surface,
      onPrimary: AppColors.textPrimary,
      onSurface: AppColors.textPrimary,
      // background/onBackground are deprecated; use surface/onSurface instead
    ),
    useMaterial3: true,
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
  );
}
