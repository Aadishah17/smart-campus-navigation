import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get darkMonochrome {
    const colorScheme = ColorScheme.dark(
      primary: Color(0xFF5FD1C5),
      onPrimary: Colors.black,
      secondary: Color(0xFFFFC857),
      onSecondary: Colors.black,
      surface: Color(0xFF0B0D0F),
      onSurface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF050607),
      canvasColor: const Color(0xFF050607),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xAA050607),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
        bodyMedium: TextStyle(fontSize: 14.5, height: 1.4),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xCC0B0D0F),
        elevation: 6,
        shadowColor: const Color(0x7A000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0x22FFFFFF)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0x33FFFFFF),
        thickness: 1,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Color(0xFF9FA3A7),
        indicatorColor: Color(0xFF5FD1C5),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: Color(0xFF111417),
        side: BorderSide(color: Color(0x44FFFFFF)),
        selectedColor: Color(0xFF5FD1C5),
        labelStyle: TextStyle(color: Colors.white),
        secondaryLabelStyle: TextStyle(color: Colors.black),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF5FD1C5),
          foregroundColor: Colors.black,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Color(0x55FFFFFF)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0A0D10),
        hintStyle: const TextStyle(color: Color(0xFF8F8F8F)),
        labelStyle: const TextStyle(color: Color(0xFFE0E0E0)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x40FFFFFF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x40FFFFFF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF5FD1C5), width: 1.4),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F1315),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
    );
  }
}
