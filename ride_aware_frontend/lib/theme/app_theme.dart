import 'package:flutter/material.dart';

class AppTheme {
  // Core color palette
  static const Color primary = Color(0xFF6750A4);
  static const Color onPrimary = Colors.white;
  static const Color secondary = Color(0xFF625B71);
  static const Color surface = Color(0xFF1C1B1F);
  static const Color onSurface = Color(0xFFE6E1E5);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        onPrimary: onPrimary,
        secondary: secondary,
        surface: surface,
        background: surface,
        onSurface: onSurface,
      ),
      scaffoldBackgroundColor: surface,
      cardTheme: const CardThemeData(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(fontSize: 16),
      ),
    );
  }
}
