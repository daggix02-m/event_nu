import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppText {
  static TextTheme textTheme(TextTheme base) {
    final spaceGrotesk = GoogleFonts.spaceGroteskTextTheme(base);
    final inter = GoogleFonts.interTextTheme(base);
    return base.copyWith(
      displayLarge: spaceGrotesk.displayLarge?.copyWith(
        fontSize: 44,
        height: 52 / 44,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.02 * 44,
        color: base.displayLarge?.color,
      ),
      headlineLarge: spaceGrotesk.headlineLarge?.copyWith(
        fontSize: 30,
        height: 38 / 30,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.01 * 30,
      ),
      headlineMedium: spaceGrotesk.headlineMedium?.copyWith(
        fontSize: 24,
        height: 32 / 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.01 * 24,
      ),
      headlineSmall: spaceGrotesk.headlineSmall?.copyWith(
        fontSize: 20,
        height: 28 / 20,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: spaceGrotesk.titleMedium?.copyWith(
        fontSize: 18,
        height: 24 / 18,
        fontWeight: FontWeight.w500,
      ),
      titleSmall: spaceGrotesk.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: inter.bodyLarge?.copyWith(fontSize: 16, height: 24 / 16),
      bodyMedium: inter.bodyMedium?.copyWith(fontSize: 14, height: 20 / 14),
      bodySmall: inter.bodySmall?.copyWith(fontSize: 12, height: 16 / 12),
      labelLarge: inter.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.01 * 14,
      ),
      labelMedium: inter.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.02 * 12,
      ),
      labelSmall: inter.labelSmall?.copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.04 * 10,
      ),
    );
  }
}