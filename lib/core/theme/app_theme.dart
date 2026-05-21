import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        onSecondary: Colors.white,
        secondaryContainer: AppColors.secondaryContainer,
        tertiary: AppColors.tertiary,
        onTertiary: Colors.white,
        tertiaryContainer: AppColors.tertiaryContainer,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        surfaceContainerHighest: AppColors.surfaceContainerHighest,
        surfaceContainerHigh: AppColors.surfaceContainerHigh,
        surfaceContainerLow: AppColors.surfaceContainerLow,
        surfaceContainerLowest: AppColors.surfaceContainerLowest,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
        error: AppColors.error,
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.manropeTextTheme().copyWith(
        displayLarge: GoogleFonts.manrope(
          fontSize: 56,
          fontWeight: FontWeight.w700,
          color: AppColors.onSurface,
        ),
        displayMedium: GoogleFonts.manrope(
          fontSize: 45,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
        ),
        headlineLarge: GoogleFonts.manrope(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: AppColors.onSurface,
        ),
        headlineMedium: GoogleFonts.manrope(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
        ),
        headlineSmall: GoogleFonts.manrope(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
        ),
        titleLarge: GoogleFonts.manrope(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
        ),
        titleMedium: GoogleFonts.publicSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
        ),
        titleSmall: GoogleFonts.publicSans(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.onSurface,
        ),
        bodyLarge: GoogleFonts.publicSans(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.onSurface,
        ),
        bodyMedium: GoogleFonts.publicSans(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.onSurface,
        ),
        bodySmall: GoogleFonts.publicSans(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppColors.onSurfaceVariant,
        ),
        labelLarge: GoogleFonts.publicSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
        ),
        labelMedium: GoogleFonts.publicSans(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.onSurface,
        ),
        labelSmall: GoogleFonts.publicSans(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.onSurfaceVariant,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: BorderSide(color: AppColors.outlineVariant),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.publicSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        floatingLabelStyle: GoogleFonts.publicSans(
          color: AppColors.primary,
          fontWeight: FontWeight.w500,
        ),
        labelStyle: GoogleFonts.publicSans(
          color: AppColors.onSurfaceVariant,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.onSurface,
        ),
        iconTheme: IconThemeData(color: AppColors.onSurface),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceContainerLowest,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.publicSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.publicSans(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 2,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.tertiaryFixed,
        labelStyle: GoogleFonts.publicSans(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        side: BorderSide.none,
      ),
      scaffoldBackgroundColor: AppColors.surface,
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
