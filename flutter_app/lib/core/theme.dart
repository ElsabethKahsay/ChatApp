import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Primary Palette ────────────────────────────────────────────────────────
  static const Color primaryPurple = Color(0xFF6C5DD3);
  static const Color primaryTeal   = Color(0xFF00BFA6);
  static const Color primaryCoral  = Color(0xFFFF6B6B);
  static const Color primaryAmber  = Color(0xFFFFB800);
  static const Color primaryBlue   = Color(0xFF4A90E2);
  
  // ── Pastel Accents ────────────────────────────────────────────────────────
  static const Color pink       = Color(0xFFF8B4C8);
  static const Color lightPink  = Color(0xFFFDE0EC);
  static const Color purple     = Color(0xFFD4A8F0);
  static const Color lightPurple= Color(0xFFEFDFFF);
  static const Color blue       = Color(0xFFA2D2FF);
  static const Color lightBlue  = Color(0xFFBDE0FE);
  static const Color mint       = Color(0xFFB5EAD7);
  static const Color peach      = Color(0xFFFFDAC1);
  static const Color lavender   = Color(0xFFE2D5F8);
  static const Color sky        = Color(0xFFC7CEEA);
  static const Color softWhite  = Color(0xFFF8F9FA);
  static const Color textDark   = Color(0xFF2D3436);
  static const Color textMuted  = Color(0xFF636E72);

  // ── User Avatar Colors (diverse palette) ─────────────────────────────────
  static const List<Color> avatarColors = [
    Color(0xFF6C5DD3), // Purple
    Color(0xFF00BFA6), // Teal
    Color(0xFFFF6B6B), // Coral
    Color(0xFFFFB800), // Amber
    Color(0xFF4A90E2), // Blue
    Color(0xFFE91E63), // Pink
    Color(0xFF9C27B0), // Deep Purple
    Color(0xFF00BCD4), // Cyan
    Color(0xFF8BC34A), // Light Green
    Color(0xFFFF9800), // Orange
    Color(0xFF795548), // Brown
    Color(0xFF607D8B), // Blue Grey
  ];

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryPurple, primaryTeal],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient sunsetGradient = LinearGradient(
    colors: [primaryCoral, primaryAmber],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient oceanGradient = LinearGradient(
    colors: [primaryBlue, primaryTeal],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient bgGradient = LinearGradient(
    colors: [softWhite, lavender, mint],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static Color getAvatarColor(String userId) {
    final index = userId.hashCode.abs() % avatarColors.length;
    return avatarColors[index];
  }

  // ── Theme ─────────────────────────────────────────────────────────────────
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryPurple,
      brightness: Brightness.light,
      primary: primaryPurple,
      secondary: primaryTeal,
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
