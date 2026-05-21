import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary - The Growth Core
  static const Color primary = Color(0xFF0D631B);
  static const Color primaryContainer = Color(0xFF2E7D32);
  static const Color onPrimaryContainer = Color(0xFFCBFFC2);
  static const Color primaryFixed = Color(0xFFA3F69C);
  static const Color primaryFixedDim = Color(0xFF88D982);

  // Secondary - The Earth Accent
  static const Color secondary = Color(0xFF75584D);
  static const Color secondaryContainer = Color(0xFFFED7CA);
  static const Color onSecondaryContainer = Color(0xFF795C51);

  // Tertiary - The Harvest Highlight
  static const Color tertiary = Color(0xFF6E5100);
  static const Color tertiaryContainer = Color(0xFF8C6800);
  static const Color tertiaryFixed = Color(0xFFFFDFA0);
  static const Color tertiaryFixedDim = Color(0xFFF8BD2A);

  // Surface hierarchy
  static const Color surface = Color(0xFFF7FBF0);
  static const Color surfaceBright = Color(0xFFF7FBF0);
  static const Color surfaceContainer = Color(0xFFEBEFE5);
  static const Color surfaceContainerHigh = Color(0xFFE5EADF);
  static const Color surfaceContainerHighest = Color(0xFFE0E4DA);
  static const Color surfaceContainerLow = Color(0xFFF1F5EB);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFD7DBD2);
  static const Color surfaceVariant = Color(0xFFE0E4DA);

  // On-surface
  static const Color onSurface = Color(0xFF181D17);
  static const Color onSurfaceVariant = Color(0xFF40493D);

  // Outline
  static const Color outline = Color(0xFF707A6C);
  static const Color outlineVariant = Color(0xFFBFCABA);

  // Error
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  // Inverse
  static const Color inverseSurface = Color(0xFF2D322B);
  static const Color inversePrimary = Color(0xFF88D982);
  static const Color inverseOnSurface = Color(0xFFEEF2E8);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryContainer],
  );

  static const LinearGradient lightGreenGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9), Color(0xFFA5D6A7)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF43A047)],
  );
}
