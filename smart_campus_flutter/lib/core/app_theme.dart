import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get darkMonochrome {
    const colorScheme = ColorScheme.dark(
      primary: Color(0xFF7DE2D1),
      onPrimary: Colors.black,
      secondary: Color(0xFFFFC857),
      onSecondary: Colors.black,
      surface: Color(0xFF091015),
      onSurface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF020508),
      canvasColor: const Color(0xFF020508),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xAA020508),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
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
        color: const Color(0xD0091015),
        elevation: 8,
        shadowColor: const Color(0x66000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0x24FFFFFF)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0x33FFFFFF),
        thickness: 1,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Color(0xFF9FA3A7),
        indicatorColor: Color(0xFF7DE2D1),
        dividerColor: Color(0x22FFFFFF),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: Color(0xFF10171D),
        side: BorderSide(color: Color(0x44FFFFFF)),
        selectedColor: Color(0xFF7DE2D1),
        labelStyle: TextStyle(color: Colors.white),
        secondaryLabelStyle: TextStyle(color: Colors.black),
        shape: StadiumBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF7DE2D1),
          foregroundColor: Colors.black,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Color(0x55FFFFFF)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF091015),
        hintStyle: const TextStyle(color: Color(0xFF8F8F8F)),
        labelStyle: const TextStyle(color: Color(0xFFE0E0E0)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0x40FFFFFF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0x40FFFFFF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF7DE2D1), width: 1.4),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F151A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: Color(0xFF9EF0E4),
        textColor: Colors.white,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Color(0xFF7DE2D1),
      ),
    );
  }
}
