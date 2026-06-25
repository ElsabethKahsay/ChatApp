import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTheme {
  static const String _themePrefsKey = 'app_is_dark';

  // ── Primary Colors (for backward compatibility) ───────────────────────────
  static const Color primaryPurple = Color(0xFFD4A8F0);
  static const Color primaryTeal   = Color(0xFF00BFA6);
  static const Color primaryCoral  = Color(0xFFFF6B6B);
  
  // ── Pastel Palette (Hex Colors) ───────────────────────────────────────────
  static const Color pink         = Color(0xFFF8B4C8);
  static const Color lightPink    = Color(0xFFFDE0EC);
  static const Color purple       = Color(0xFFD4A8F0);
  static const Color lightPurple  = Color(0xFFEFDFFF);
  static const Color blue         = Color(0xFFA2D2FF);
  static const Color lightBlue    = Color(0xFFBDE0FE);
  static const Color mint         = Color(0xFFB5EAD7);
  static const Color peach        = Color(0xFFFFDAC1);
  static const Color lavender     = Color(0xFFE2D5F8);
  static const Color sky          = Color(0xFFC7CEEA);
  static const Color softWhite    = Color(0xFFF8F9FA);
  static const Color textDark     = Color(0xFF2D3436);
  static const Color textMuted    = Color(0xFF636E72);
  static const Color forgetMeNotBlue = Color(0xFF6495ED);

  // ── Dark Theme Colors ──────────────────────────────────────────────────────
  static const Color darkBg       = Color(0xFF1A1A2E);
  static const Color darkSurface  = Color(0xFF16213E);
  static const Color darkCard     = Color(0xFF0F3460);
  static const Color darkText     = Color(0xFFE8E8E8);
  static const Color darkTextMuted = Color(0xFFA0A0B0);

  // ── User Avatar Colors ────────────────────────────────────────────────────
  static const List<Color> avatarColors = [
    Color(0xFFF8B4C8),
    Color(0xFFD4A8F0),
    Color(0xFFB5EAD7),
    Color(0xFFA2D2FF),
    Color(0xFFFFDAC1),
    Color(0xFFC7CEEA),
    Color(0xFFE2D5F8),
    Color(0xFFBDE0FE),
    Color(0xFFFDE0EC),
    Color(0xFF6495ED),
    Color(0xFF00BFA6),
    Color(0xFFFF6B6B),
  ];

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [purple, pink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient sunsetGradient = LinearGradient(
    colors: [pink, peach],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient oceanGradient = LinearGradient(
    colors: [blue, mint],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient bgGradient = LinearGradient(
    colors: [lightPink, lavender, pink],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static Color getAvatarColor(String userId) {
    final index = userId.hashCode.abs() % avatarColors.length;
    return avatarColors[index];
  }

  // ── Theme Mode ────────────────────────────────────────────────────────────
  static bool isDarkMode = false;

  static Future<void> loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isDarkMode = prefs.getBool(_themePrefsKey) ?? false;
    } catch (_) {
      isDarkMode = false;
    }
  }

  static Future<void> setThemeMode(bool dark) async {
    isDarkMode = dark;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themePrefsKey, dark);
    } catch (_) {}
  }

  static Future<void> toggleTheme() async {
    await setThemeMode(!isDarkMode);
  }

  static ThemeData get theme => isDarkMode ? darkTheme : lightTheme;

  // ── Light Theme (Pink/Purple with White Backgrounds) ──────────────────────
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: purple,
      brightness: Brightness.light,
      primary: purple,
      secondary: pink,
      surface: Colors.white,
    ),
    textTheme: GoogleFonts.interTextTheme().apply(
      bodyColor: textDark,
      displayColor: textDark,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: textDark,
      elevation: 0,
      titleTextStyle: GoogleFonts.inter(
        color: textDark,
        fontSize: 24,
        fontWeight: FontWeight.w600,
      ),
    ),
    scaffoldBackgroundColor: Colors.white,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: softWhite,
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
        textStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
    ),
  );

  // ── Dark Theme (Coral on Dark Navy) ───────────────────────────────────────
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryCoral,
      brightness: Brightness.dark,
      primary: primaryCoral,
      secondary: purple,
      surface: darkSurface,
    ),
    textTheme: GoogleFonts.interTextTheme().apply(
      bodyColor: darkText,
      displayColor: darkText,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: darkText,
      elevation: 0,
      titleTextStyle: GoogleFonts.inter(
        color: darkText,
        fontSize: 24,
        fontWeight: FontWeight.w600,
      ),
    ),
    scaffoldBackgroundColor: darkBg,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: darkCard, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: primaryCoral, width: 2),
      ),
      hintStyle: const TextStyle(color: darkTextMuted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryCoral,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 0,
        textStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
    ),
  );
}
