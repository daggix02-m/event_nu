import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color surface = Color(0xFF141217);
  static const Color surfaceDim = Color(0xFF141217);
  static const Color surfaceBright = Color(0xFF3B383E);
  static const Color surfaceContainerLowest = Color(0xFF0F0D12);
  static const Color surfaceContainerLow = Color(0xFF1D1B20);
  static const Color surfaceContainer = Color(0xFF211F24);
  static const Color surfaceContainerHigh = Color(0xFF2B292E);
  static const Color surfaceContainerHighest = Color(0xFF363439);
  static const Color onSurface = Color(0xFFE7E0E8);
  static const Color onSurfaceVariant = Color(0xFFCAC4D0);
  static const Color inverseSurface = Color(0xFFE7E0E8);
  static const Color inverseOnSurface = Color(0xFF322F35);
  static const Color outline = Color(0xFF948F9A);
  static const Color outlineVariant = Color(0xFF49454F);

  static const Color primary = Color(0xFFE9DDFF);
  static const Color onPrimary = Color(0xFF37265E);
  static const Color primaryContainer = Color(0xFFD0BCFF);
  static const Color onPrimaryContainer = Color(0xFF594983);
  static const Color inversePrimary = Color(0xFF665590);
  static const Color neon = Color(0xFFA078FF);

  static const Color secondary = Color(0xFFFEB59D);
  static const Color onSecondary = Color(0xFF502314);
  static const Color secondaryContainer = Color(0xFF6E3B2A);
  static const Color onSecondaryContainer = Color(0xFFEEA790);

  static const Color tertiary = Color(0xFFBFE8FF);
  static const Color onTertiary = Color(0xFF003547);
  static const Color tertiaryContainer = Color(0xFF78D1FB);
  static const Color onTertiaryContainer = Color(0xFF005975);

  static const Color error = Color(0xFFFFB4AB);
  static const Color onError = Color(0xFF690005);
  static const Color errorContainer = Color(0xFF93000A);
  static const Color onErrorContainer = Color(0xFFFFDAD6);

  static const List<Color> primaryGradient = <Color>[primaryContainer, neon];
}