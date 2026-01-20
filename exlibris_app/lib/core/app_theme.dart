import 'package:flutter/material.dart';

/// Centralized theme for ExLibris app
/// Based on the auth/accueil pages design

class AppColors {
  AppColors._();

  // Primary gradient colors
  static const Color backgroundDark = Color(0xFF02191D);
  static const Color backgroundLight = Color(0xFF051E24);
  static const Color gradientStart = Color(0xFF0D1F1F);
  static const Color gradientEnd = Color(0xFF1A3A3A);

  // Card colors
  static const Color cardBackground = Color(0x0AFFFFFF); // 4% white
  static const Color cardBorder = Color(0x1FFFFFFF); // 12% white

  // Text colors
  static const Color textPrimary = Colors.white;
  static Color textSecondary = Colors.white.withOpacity(0.7);
  static Color textMuted = Colors.white.withOpacity(0.5);

  // Accent colors
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);
  static const Color accent = Color(0xFF22D3EE);

  // Input field
  static Color inputBackground = Colors.white.withOpacity(0.1);
  static Color inputBorder = Colors.white.withOpacity(0.2);
}

class AppGradients {
  AppGradients._();

  static const LinearGradient background = LinearGradient(
    colors: [AppColors.backgroundDark, AppColors.backgroundLight],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient authBackground = LinearGradient(
    colors: [AppColors.gradientStart, AppColors.gradientEnd],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1F2933), Color(0xFF111827)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

class AppDecorations {
  AppDecorations._();

  static BoxDecoration get pageBackground => const BoxDecoration(
        gradient: AppGradients.background,
      );

  static BoxDecoration get cardDecoration => BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      );

  static BoxDecoration get sectionCard => BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
      );

  static InputDecoration inputDecoration({
    required String label,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: Colors.white70)
          : null,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.inputBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white, width: 2),
      ),
    );
  }
}

class AppTextStyles {
  AppTextStyles._();

  static const TextStyle heading1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle body = TextStyle(
    fontSize: 14,
    color: AppColors.textSecondary,
  );

  static const TextStyle bodyWhite = TextStyle(
    fontSize: 14,
    color: AppColors.textPrimary,
  );

  static TextStyle caption = TextStyle(
    fontSize: 12,
    color: AppColors.textMuted,
  );
}
