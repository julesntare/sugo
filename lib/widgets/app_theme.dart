import 'package:flutter/material.dart';

class AppColors {
  // Primary brand colors
  static const Color primary = Color.fromARGB(255, 0, 85, 75); // deep teal
  static const Color primaryLight = Color.fromARGB(
    255,
    42,
    117,
    110,
  ); // teal lighten
  static const Color accent = Color(0xFFFFC107); // warm amber for highlights

  // Neutral dark background and surfaces
  static const Color background = Color.fromARGB(255, 63, 66, 73);
  static const Color slate = Color(0xFF12232E);
  static const Color cardGrey = Color(0xFF0F1722);

  // Text colors
  static const Color text = Color(0xFFE6F5F0); // gentle off-white
  static const Color lightGrey = Color(0xFFB9C6C2);

  // Semi-transparent tints used by components (alpha values chosen for subtlety)
  static const Color slateTint12 = Color.fromARGB(
    31,
    18,
    35,
    46,
  ); // ~12% on slate
  static const Color slateTint8 = Color.fromARGB(
    20,
    18,
    35,
    46,
  ); // ~8% on slate

  // Warning/Alert colors
  static const Color warning = Color(0xFFFFA726); // Orange for warning state
  static const Color danger = Color(0xFFEF5350); // Red for danger/error state

  // Backwards compatibility aliases
  static const Color darkBlue = primary;
  static const Color blueAccent = primaryLight;
  // Old alias names used around the codebase — map them to new palette
  static const Color deepPurple = primary;
  static const Color magenta = Color(
    0xFF6B7A8F,
  ); // muted accent kept for legacy widgets
  static const Color teal = primaryLight;
}

class AppTheme {
  static LinearGradient mainGradient() => const LinearGradient(
    colors: [AppColors.primary, AppColors.primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData light() {
    final primary = AppColors.primary;
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    );

    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: AppColors.text,
        elevation: 2,
        centerTitle: true,
      ),
      // card color should be slightly lighter than scaffold background
      cardColor: AppColors.cardGrey,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryLight,
        foregroundColor: AppColors.background,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.lightGrey,
        textColor: AppColors.text,
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
        bodyMedium: TextStyle(color: AppColors.lightGrey),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        // subtle filled color using the slate tint
        fillColor: AppColors.slateTint12,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
