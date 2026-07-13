import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Dark-mode-first, OLED-friendly (true black) Material 3 theme with a
/// minimal "Bento Box" aesthetic: rounded cards, soft elevation, one
/// accent color used sparingly.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFF000000); // true black (OLED)
  static const Color surface = Color(0xFF121212);
  static const Color surfaceVariant = Color(0xFF1C1C1E);
  static const Color accent = Color(0xFF00E5A0); // neon-mint accent
  static const Color accentSecondary = Color(0xFF3D5CFF);
  static const Color textPrimary = Color(0xFFF5F5F7);
  static const Color textSecondary = Color(0xFF9A9AA2);
  static const Color error = Color(0xFFFF5470);
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        secondary: AppColors.accentSecondary,
        surface: AppColors.surface,
        error: AppColors.error,
        onPrimary: Colors.black,
        onSurface: AppColors.textPrimary,
      ),
      scaffoldBackgroundColor: AppColors.background,
    );

    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceVariant,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.surfaceVariant, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
      dividerTheme: const DividerThemeData(color: AppColors.surfaceVariant, thickness: 1),
    );
  }
}
