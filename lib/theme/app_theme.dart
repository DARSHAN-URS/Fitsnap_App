import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Color Palette
  static const Color primary = Color(0xFF0F172A); // Slate 900
  static const Color primaryLight = Color(0xFF1E293B); // Slate 800
  static const Color accent = Color(0xFF00D1B2); // Teal 400
  static const Color accentLight = Color(0xFF5EEAD4); // Teal 200

  // Neon Accents
  static const Color neonIndigo = Color(0xFF6366F1);
  static const Color neonPink = Color(0xFFEC4899);
  static const Color neonCyan = Color(0xFF06B6D4);
  static const Color neonEmerald = Color(0xFF10B981);
  static const Color neonAmber = Color(0xFFF59E0B);
  
  // Macro Specific Colors (Premium variations)
  static const Color proteinColor = Color(0xFF6366F1); // Indigo
  static const Color carbsColor = Color(0xFFF97316);   // Orange
  static const Color fatsColor = Color(0xFF06B6D4);    // Cyan
  static const Color caloriesColor = Color(0xFFEF4444); // Red/Coral

  // Gradients (Refined for new teal-neon aesthetic)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF00D1B2), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF5EEAD4), Color(0xFF00D1B2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFFF8FAFC), Color(0xFFEEF2F6)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient authGradient = LinearGradient(
    colors: [Color(0xFFF8FAFC), Color(0xFFEEF2F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Card Shadow
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.04),
      blurRadius: 24,
      offset: const Offset(0, 8),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.02),
      blurRadius: 8,
      offset: const Offset(0, 2),
      spreadRadius: -2,
    ),
  ];

  static List<BoxShadow> get glowShadow => [
    BoxShadow(
      color: const Color(0xFF6366F1).withOpacity(0.15),
      blurRadius: 20,
      offset: const Offset(0, 10),
      spreadRadius: 0,
    ),
  ];

  // Border Radius
  static BorderRadius get cardRadius => BorderRadius.circular(24);
  static BorderRadius get pillRadius => BorderRadius.circular(30);

  // Typography Styles
  static TextStyle get h1 => GoogleFonts.inter(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.0,
    color: primary,
  );

  static TextStyle get h2 => GoogleFonts.inter(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: primary,
  );

  static TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: primary,
  );

  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 14,
    color: const Color(0xFF334155), // Slate 700
  );

  static TextStyle get labelSmall => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: const Color(0xFF64748B), // Slate 500
  );

  // Glassmorphic Input Decoration helper
  static InputDecoration getGlassInputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 15),
      prefixIcon: Icon(prefixIcon, color: Colors.white.withOpacity(0.5), size: 22),
      suffixIcon: suffixIcon,
      border: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: accent,
        background: Color(0xFFF8FAFC),
        surface: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.light().textTheme,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF0F172A),
        contentTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
      ),
      useMaterial3: true,
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      colorScheme: const ColorScheme.dark(
        primary: Colors.white,
        secondary: accent,
        background: Color(0xFF0F172A),
        surface: Color(0xFF1E293B),
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.dark().textTheme,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF0F172A),
        contentTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
      ),
      useMaterial3: true,
    );
  }
}
