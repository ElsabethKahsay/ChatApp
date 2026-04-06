import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Pastel palette ────────────────────────────────────────────────────────
  static const Color pink       = Color(0xFFF8B4C8);
  static const Color lightPink  = Color(0xFFFDE0EC);
  static const Color purple     = Color(0xFFD4A8F0);
  static const Color lightPurple= Color(0xFFEFDFFF);
  static const Color blue       = Color(0xffa2d2ff);
  static const Color lightblue  = Color(0xffbde0fe);
  static const Color softWhite  = Color(0xFFFFF6FB);
  static const Color textDark   = Color(0xFF3D2C4E);
  static const Color textMuted  = Color(0xFF7A6B8A);

  // Added more pastel colors to the theme.
  static const Color pastelPink = Color(0xFFFFC1E3);
  static const Color pastelBlue = Color(0xFFB3E5FC);
  static const Color pastelGreen = Color(0xFFC8E6C9);
  static const Color pastelYellow = Color(0xFFFFF9C4);
  static const Color pastelPurple = Color(0xFFE1BEE7);

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [purple, pink],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient blueGradient = LinearGradient(
    colors: [blue, lightblue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient bgGradient = LinearGradient(
    colors: [softWhite, lightPink, lightPurple],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── Theme ─────────────────────────────────────────────────────────────────
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: pink,
      brightness: Brightness.light,
      primary: purple,
      secondary: blue,
      surface: softWhite,
    ),
    textTheme: GoogleFonts.quicksandTextTheme().apply(
      bodyColor: textDark,
      displayColor: textDark,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: GoogleFonts.quicksand(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    scaffoldBackgroundColor: softWhite,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: lightPurple, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: purple, width: 2),
      ),
      hintStyle: const TextStyle(color: textMuted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: purple,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 0,
        textStyle: GoogleFonts.quicksand(
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    ),
  );
}
