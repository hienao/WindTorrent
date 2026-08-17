import 'package:flutter/material.dart';
import 'package:windwalker/core/theme/neo_theme_extension.dart';

/// WindTorrent unified design tokens based on DESIGN.md (2026-04-27)
class AppColors {
  // Unified palette
  static const Color primary = Color(0xFF1677FF);
  static const Color success = Color(0xFF14B8A6);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  static const Color backgroundLight = Color(0xFFF6F8FB);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);

  static const Color backgroundDark = Color(0xFF0B1220);
  static const Color surfaceDark = Color(0xFF111827);
  static const Color borderDark = Color(0xFF1F2937);
  static const Color textPrimaryDark = Color(0xFFE5E7EB);
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  // status colors
  static const Color downloading = warning;
  static const Color waiting = warning;
  static const Color paused = Color(0xFF94A3B8);
  static const Color seed = success;
  static const Color completed = success;
  static const Color offline = Color(0xFF94A3B8);
  static const Color onlineColor = success;
  static const Color offlineColor = offline;
  static const Color taskErrorColor = error;

  // Legacy aliases to keep existing code compiling
  static const Color uberBlack = textPrimaryLight;
  static const Color pureWhite = surfaceLight;
  static const Color hoverGray = Color(0xFFF1F5F9);
  static const Color hoverLight = Color(0xFFF8FAFC);
  static const Color chipGray = Color(0xFFEFF6FF);
  static const Color bodyGray = textSecondaryLight;
  static const Color mutedGray = textSecondaryLight;
  static const Color primaryLight = surfaceLight;
  static const Color primaryContainer = chipGray;
  static const Color onPrimaryContainer = textPrimaryLight;
  static const Color accent = primary;
  static const Color accentLight = surfaceLight;
  static const Color accentDark = primary;
  static const Color accentContainer = chipGray;
  static const Color onAccentContainer = textPrimaryLight;
  static const Color downloadingLight = Color(0xFFFCD34D);
  static const Color waitingLight = Color(0xFFFDE68A);
  static const Color completedLight = Color(0xFF5EEAD4);
  static const Color pausedLight = Color(0xFFCBD5E1);
  static const Color seedLight = Color(0xFF99F6E4);
  static const Color errorLight = Color(0xFFFCA5A5);
  static const Color offlineLight = Color(0xFFCBD5E1);
  static const Color surfaceVariantLight = Color(0xFFF8FAFC);
  static const Color surfaceVariantDark = Color(0xFF1F2937);
  static const Color textTertiaryLight = Color(0xFF94A3B8);
  static const Color textTertiaryDark = Color(0xFF64748B);
  static const Color aria2Color = primary;
  static const Color qbitColor = success;
  static const Color transColor = warning;
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double xxxxl = 40;
  static const double xxxxxl = 48;
  static const double xxxxxxl = 56;
}

class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double pill = 999;
}

class AppElevation {
  static List<BoxShadow> level1({bool isDark = false}) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> level2({bool isDark = false}) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.12),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> level3({bool isDark = false}) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.16),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
}

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      surface: AppColors.surfaceLight,
      error: AppColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      extensions: const [NeoThemeTokens.light],
      appBarTheme: const AppBarThemeData(
        centerTitle: false,
        backgroundColor: AppColors.backgroundLight,
        foregroundColor: AppColors.textPrimaryLight,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.borderLight),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: AppColors.borderLight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        side: const BorderSide(color: AppColors.borderLight),
        backgroundColor: AppColors.surfaceLight,
        selectedColor: const Color(0xFFE8F1FF),
        labelStyle: const TextStyle(
          color: AppColors.textPrimaryLight,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderLight,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      primary: AppColors.primary,
      surface: AppColors.surfaceDark,
      error: AppColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      extensions: const [NeoThemeTokens.dark],
      appBarTheme: const AppBarThemeData(
        centerTitle: false,
        backgroundColor: AppColors.backgroundDark,
        foregroundColor: AppColors.textPrimaryDark,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.borderDark),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
    );
  }
}
