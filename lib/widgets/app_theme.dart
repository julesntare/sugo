import 'package:flutter/material.dart';

class AppColors {
  static const Color deepPurple = Color(0xFF5B2BFF);
  static const Color magenta = Color(0xFFEA3C89);
  static const Color teal = Color(0xFF00C2A8);
  static const Color softYellow = Color(0xFFFFD166);
}

class AppTheme {
  static LinearGradient mainGradient() => const LinearGradient(
    colors: [AppColors.deepPurple, AppColors.magenta],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(seedColor: AppColors.deepPurple);
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.teal,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}
