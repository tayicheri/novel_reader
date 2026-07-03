import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens from Stitch project "Audio Web Reader" (app: Tayi Whisper).
class AppColors {
  static const Color primary = Color(0xFF004AC6);
  static const Color primaryContainer = Color(0xFF2563EB);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFFEEEFFF);
  static const Color surface = Color(0xFFF9F9FF);
  static const Color onSurface = Color(0xFF111C2D);
  static const Color onSurfaceVariant = Color(0xFF434655);
  static const Color surfaceContainerLow = Color(0xFFF0F3FF);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainer = Color(0xFFE7EEFF);
  static const Color outlineVariant = Color(0xFFC3C6D7);
  static const Color error = Color(0xFFBA1A1A);

  static const Color darkSurface = Color(0xFF263143);
  static const Color darkOnSurface = Color(0xFFECF1FF);
  static const Color darkSurfaceDim = Color(0xFF1A2332);
  static const Color darkSurfaceContainer = Color(0xFF2F3A4D);
  static const Color darkPrimaryFixedDim = Color(0xFFB4C5FF);
}

class AppTheme {
  static TextTheme _buildTextTheme(Color bodyColor, Color headlineColor) {
    final inter = GoogleFonts.interTextTheme();
    final hanken = GoogleFonts.hankenGroteskTextTheme();

    return TextTheme(
      headlineLarge: hanken.headlineLarge?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 36 / 28,
        color: headlineColor,
      ),
      headlineSmall: hanken.headlineSmall?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 28 / 20,
        color: headlineColor,
      ),
      titleMedium: hanken.titleMedium?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: headlineColor,
      ),
      bodyLarge: inter.bodyLarge?.copyWith(
        fontSize: 18,
        height: 28 / 18,
        color: bodyColor,
      ),
      bodyMedium: inter.bodyMedium?.copyWith(
        fontSize: 16,
        height: 24 / 16,
        color: bodyColor,
      ),
      bodySmall: inter.bodySmall?.copyWith(
        fontSize: 14,
        height: 20 / 14,
        color: bodyColor,
      ),
      labelLarge: inter.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 20 / 14,
        color: bodyColor,
      ),
      labelMedium: inter.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 16 / 12,
        color: bodyColor,
      ),
    );
  }

  static ThemeData light() {
    final colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.onPrimaryContainer,
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      onSurfaceVariant: AppColors.onSurfaceVariant,
      surfaceContainerLow: AppColors.surfaceContainerLow,
      surfaceContainerLowest: AppColors.surfaceContainerLowest,
      surfaceContainerHighest: AppColors.surfaceContainer,
      outlineVariant: AppColors.outlineVariant,
      error: AppColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.surface,
      textTheme: _buildTextTheme(AppColors.onSurfaceVariant, AppColors.primary),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.hankenGrotesk(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        hintStyle: GoogleFonts.inter(color: AppColors.onSurfaceVariant),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceContainerLow,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.outlineVariant),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.dark(
      primary: AppColors.primaryContainer,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primary,
      onPrimaryContainer: AppColors.darkPrimaryFixedDim,
      surface: AppColors.darkSurfaceDim,
      onSurface: AppColors.darkOnSurface,
      onSurfaceVariant: AppColors.darkOnSurface.withValues(alpha: 0.75),
      surfaceContainerLow: AppColors.darkSurface,
      surfaceContainerLowest: AppColors.darkSurfaceDim,
      surfaceContainerHighest: AppColors.darkSurfaceContainer,
      outlineVariant: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
      error: AppColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.darkSurfaceDim,
      textTheme: _buildTextTheme(
        AppColors.darkOnSurface.withValues(alpha: 0.85),
        AppColors.darkPrimaryFixedDim,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkPrimaryFixedDim,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.hankenGrotesk(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.darkPrimaryFixedDim,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurfaceContainer,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryContainer, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryContainer,
          foregroundColor: AppColors.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}

enum ReaderFontSize { small, medium, large }

extension ReaderFontSizeX on ReaderFontSize {
  double get scale {
    switch (this) {
      case ReaderFontSize.small:
        return 0.9;
      case ReaderFontSize.medium:
        return 1.0;
      case ReaderFontSize.large:
        return 1.15;
    }
  }

  String get label {
    switch (this) {
      case ReaderFontSize.small:
        return 'Petit';
      case ReaderFontSize.medium:
        return 'Moyen';
      case ReaderFontSize.large:
        return 'Grand';
    }
  }
}
