// lib/theme/app_themes.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppThemes {
  // Theme IDs
  static const String latteId = 'latte_love';
  static const String blushId = 'blush_gold';
  static const String lavenderID = 'lavender_dreams';
  static const String mintId = 'mint_fresh';
  static const String monoId = 'monochrome';
  static const String singularityId = 'singularity';

  // Get theme by ID
  static ThemeData getTheme(String themeId) {
    switch (themeId) {
      case latteId:
        return latteLove;
      case blushId:
        return blushGold;
      case lavenderID:
        return lavenderDreams;
      case mintId:
        return mintFresh;
      case monoId:
        return monochrome;
      case singularityId:
        return singularity;
      default:
        return latteLove;
    }
  }

  // Get theme name for display
  static String getThemeName(String themeId) {
    switch (themeId) {
      case latteId:
        return 'Latte Love';
      case blushId:
        return 'Blush & Gold';
      case lavenderID:
        return 'Lavender Dreams';
      case mintId:
        return 'Mint Fresh';
      case monoId:
        return 'Monochrome';
      case singularityId:
        return 'Singularity';
      default:
        return 'Latte Love';
    }
  }

  // Get all available themes
  static List<ThemeOption> getAllThemes() {
    return [
      ThemeOption(
        id: latteId,
        name: 'Latte Love',
        description: 'Warm creams, tans, and chocolate browns',
        primaryColor: const Color(0xFF8B6F47),
        surfaceColor: const Color(0xFFE8DFD0),
      ),
      ThemeOption(
        id: blushId,
        name: 'Blush & Gold',
        description: 'Soft pinks, rose gold, and cream',
        primaryColor: const Color(0xFFD4AF37),
        surfaceColor: const Color(0xFFF8E8E8),
      ),
      ThemeOption(
        id: lavenderID,
        name: 'Lavender Dreams',
        description: 'Lilacs, soft purples, and pale blues',
        primaryColor: const Color(0xFFB8A7D9),
        surfaceColor: const Color(0xFFE6D9F5),
      ),
      ThemeOption(
        id: mintId,
        name: 'Mint Fresh',
        description: 'Soft mint, sage green, and cream',
        primaryColor: const Color(0xFFA8D8C8),
        surfaceColor: const Color(0xFFD4F1E8),
      ),
      ThemeOption(
        id: monoId,
        name: 'Monochrome',
        description: 'Classic black, white, and greys',
        primaryColor: const Color(0xFF424242),
        surfaceColor: const Color(0xFFE8E8E8),
      ),
      ThemeOption(
        id: singularityId,
        name: 'Singularity',
        description: 'Deep space blues and cosmic teal',
        primaryColor: const Color(0xFF00BCD4),
        surfaceColor: const Color(0xFF1A2332),
      ),
    ];
  }

  // 1. LATTE LOVE (Existing - Warm browns)
  static final ThemeData latteLove = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF8B6F47), // Rich brown
      secondary: Color(0xFFD4AF37), // Gold
      surface: Color(0xFFE8DFD0), // Cream
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Color(0xFF5C4033), // Dark brown for text
    ),
    scaffoldBackgroundColor: const Color(0xFFF5F0E8),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF5F0E8),
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Caveat',
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Color(0xFF5C4033),
      ),
    ),
    textTheme: GoogleFonts.caveatTextTheme().copyWith(
      bodyLarge: const TextStyle(color: Color(0xFF5C4033)),
      bodyMedium: const TextStyle(color: Color(0xFF795548)),
      titleLarge: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF5C4033),
      ),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFFE8DFD0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );

  // 2. BLUSH & GOLD (Soft pinks, rose gold)
  static final ThemeData blushGold = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFFD4AF37), // Rose gold
      secondary: Color(0xFFE8A0BF), // Soft pink
      surface: Color(0xFFF8E8E8), // Light cream-pink
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Color(0xFF6B4E71), // Muted purple-brown for text
    ),
    scaffoldBackgroundColor: const Color(0xFFFFF5F5),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFFFF5F5),
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Caveat',
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Color(0xFF6B4E71),
      ),
    ),
    textTheme: GoogleFonts.caveatTextTheme().copyWith(
      bodyLarge: const TextStyle(color: Color(0xFF6B4E71)),
      bodyMedium: const TextStyle(color: Color(0xFF9B7EAC)),
      titleLarge: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF6B4E71),
      ),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFFF8E8E8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );

  // 3. LAVENDER DREAMS (Lilacs, soft purples)
  static final ThemeData lavenderDreams = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFFB8A7D9), // Soft purple
      secondary: Color(0xFF9B87C6), // Deeper lavender
      surface: Color(0xFFE6D9F5), // Very light lavender
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Color(0xFF4A3F6B), // Deep purple for text
    ),
    scaffoldBackgroundColor: const Color(0xFFF5F0FF),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF5F0FF),
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Caveat',
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Color(0xFF4A3F6B),
      ),
    ),
    textTheme: GoogleFonts.caveatTextTheme().copyWith(
      bodyLarge: const TextStyle(color: Color(0xFF4A3F6B)),
      bodyMedium: const TextStyle(color: Color(0xFF6B5B95)),
      titleLarge: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF4A3F6B),
      ),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFFE6D9F5),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );

  // 4. MINT FRESH (Soft mint, sage green)
  static final ThemeData mintFresh = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFFA8D8C8), // Soft mint
      secondary: Color(0xFF7BB8A0), // Sage green
      surface: Color(0xFFD4F1E8), // Very light mint
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Color(0xFF2C5F4D), // Deep green for text
    ),
    scaffoldBackgroundColor: const Color(0xFFF0FFF5),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF0FFF5),
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Caveat',
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Color(0xFF2C5F4D),
      ),
    ),
    textTheme: GoogleFonts.caveatTextTheme().copyWith(
      bodyLarge: const TextStyle(color: Color(0xFF2C5F4D)),
      bodyMedium: const TextStyle(color: Color(0xFF4A7C5D)),
      titleLarge: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF2C5F4D),
      ),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFFD4F1E8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );

  // 5. MONOCHROME (Black, white, greys)
  static final ThemeData monochrome = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF424242), // Dark grey
      secondary: Color(0xFF757575), // Medium grey
      surface: Color(0xFFE8E8E8), // Light grey
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Color(0xFF212121), // Near black for text
    ),
    scaffoldBackgroundColor: const Color(0xFFF5F5F5),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF5F5F5),
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Caveat',
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Color(0xFF212121),
      ),
    ),
    textTheme: GoogleFonts.caveatTextTheme().copyWith(
      bodyLarge: const TextStyle(color: Color(0xFF212121)),
      bodyMedium: const TextStyle(color: Color(0xFF616161)),
      titleLarge: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF212121),
      ),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFFE8E8E8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );

  // 6. SINGULARITY (Dark mode - Deep space blues and cosmic teal)
  static final ThemeData singularity = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF00BCD4), // Cosmic teal
      secondary: Color(0xFF2196F3), // Space blue
      surface: Color(0xFF1A2332), // Dark blue-grey
      onPrimary: Color(0xFF0A1929), // Very dark blue
      onSecondary: Colors.white,
      onSurface: Colors.white, // White text
      background: Color(0xFF0A1929), // Deep space blue
    ),
    scaffoldBackgroundColor: const Color(0xFF0A1929),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0A1929),
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Caveat',
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      iconTheme: IconThemeData(color: Color(0xFF00BCD4)),
    ),
    textTheme: GoogleFonts.caveatTextTheme().copyWith(
      bodyLarge: const TextStyle(color: Colors.white),
      bodyMedium: const TextStyle(color: Color(0xFFB0BEC5)),
      titleLarge: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF1A2332),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF0A1929),
      selectedItemColor: Color(0xFF00BCD4),
      unselectedItemColor: Color(0xFF546E7A),
    ),
  );
}

// Theme option model for picker
class ThemeOption {
  final String id;
  final String name;
  final String description;
  final Color primaryColor;
  final Color surfaceColor;

  ThemeOption({
    required this.id,
    required this.name,
    required this.description,
    required this.primaryColor,
    required this.surfaceColor,
  });
}
