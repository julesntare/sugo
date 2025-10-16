import 'package:flutter/material.dart';

class AppColors {
  static const Color darkBlue = Color(0xFF1E88E5);
  static const Color blueAccent = Color(0xFF1565C0);
  static const Color slate = Color(0xFF2F3B45);
  // soft off-white (not pure white) for text/icons on dark backgrounds
  static const Color lightGrey = Color(0xFFEEEEF2);
  // slightly lighter card background to add separation from scaffold
  static const Color cardGrey = Color.fromARGB(255, 45, 45, 55);
  // backward-compatible aliases (old theme)
  static const Color deepPurple = darkBlue;
  static const Color magenta = Color(0xFF6B7A8F); // muted accent
  static const Color teal = blueAccent;
}

class AppTheme {
  static LinearGradient mainGradient() => const LinearGradient(
    colors: [AppColors.darkBlue, AppColors.slate],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData light() {
    final primary = AppColors.darkBlue;
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    );

    return ThemeData(
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.cardGrey,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
      ),
      // prefer using cardColor which is broadly supported across Flutter versions
      cardColor: Color.alphaBlend(
        Colors.white.withValues(alpha: 0.35),
        AppColors.cardGrey,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.blueAccent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.blueAccent,
        foregroundColor: Colors.white,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.lightGrey,
        textColor: Colors.white,
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        bodyMedium: TextStyle(color: AppColors.lightGrey),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.slate.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
