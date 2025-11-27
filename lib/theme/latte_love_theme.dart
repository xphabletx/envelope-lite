import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LatteTheme {
  // Latte Love Color Palette
  static const Color primaryBackground = Color(0xFFF5F0E8); // Warm cream
  static const Color cardBackground = Color(0xFFE8DFD0); // Light tan
  static const Color accentBrown = Color(0xFF8B6F47); // Chocolate brown
  static const Color darkBrown = Color(0xFF5C4033); // Rich brown
  static const Color goldAccent = Color(0xFFD4AF37); // Gold
  static const Color textPrimary = Color(0xFF3E2723); // Dark brown
  static const Color textSecondary = Color(0xFF795548); // Medium brown

  static ThemeData get theme {
    return ThemeData(
      scaffoldBackgroundColor: primaryBackground,
      primaryColor: accentBrown,
      colorScheme: ColorScheme.light(
        primary: accentBrown,
        secondary: goldAccent,
        surface: cardBackground,
        surfaceContainerHighest: primaryBackground,
      ),

      // Caveat font for handwritten feel on titles
      // Poppins for body text (better readability)
      textTheme: TextTheme(
        displayLarge: GoogleFonts.caveat(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        displayMedium: GoogleFonts.caveat(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        titleLarge: GoogleFonts.caveat(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleMedium: GoogleFonts.caveat(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: GoogleFonts.poppins(fontSize: 16, color: textPrimary),
        bodyMedium: GoogleFonts.poppins(fontSize: 14, color: textSecondary),
        bodySmall: GoogleFonts.poppins(fontSize: 12, color: textSecondary),
      ),

      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: primaryBackground,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: GoogleFonts.caveat(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: goldAccent,
          foregroundColor: darkBrown,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
