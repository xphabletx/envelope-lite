// lib/theme/app_themes.dart
import 'package:flutter/material.dart';

class AppThemes {
  // Theme IDs
  static const String latteId = 'latte_love';
  static const String blushId = 'blush_gold';
  static const String lavenderId = 'lavender_dreams';
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
      case lavenderId:
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
      case lavenderId:
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
        id: lavenderId,
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
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Color(0xFF5C4033),
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Color(0xFF5C4033)),
      bodyMedium: TextStyle(color: Color(0xFF795548)),
      titleLarge: TextStyle(
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
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Color(0xFF6B4E71),
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Color(0xFF6B4E71)),
      bodyMedium: TextStyle(color: Color(0xFF9B7EAC)),
      titleLarge: TextStyle(
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
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Color(0xFF4A3F6B),
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Color(0xFF4A3F6B)),
      bodyMedium: TextStyle(color: Color(0xFF6B5B95)),
      titleLarge: TextStyle(
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
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Color(0xFF2C5F4D),
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Color(0xFF2C5F4D)),
      bodyMedium: TextStyle(color: Color(0xFF4A7C5D)),
      titleLarge: TextStyle(
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
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Color(0xFF212121),
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Color(0xFF212121)),
      bodyMedium: TextStyle(color: Color(0xFF616161)),
      titleLarge: TextStyle(
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
      onSurface: Colors.white, // Deep space blue
    ),
    scaffoldBackgroundColor: const Color(0xFF0A1929),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0A1929),
      elevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      iconTheme: IconThemeData(color: Color(0xFF00BCD4)),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Color(0xFFB0BEC5)),
      titleLarge: TextStyle(
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

class BinderColorOption {
  final String id;
  final String displayName;
  final Color binderColor;
  final Color paperColor;
  final Color envelopeTextColor;
  final Color envelopeBorderColor;

  const BinderColorOption({
    required this.id,
    required this.displayName,
    required this.binderColor,
    required this.paperColor,
    required this.envelopeTextColor,
    required this.envelopeBorderColor,
  });
}

class ThemeBinderColors {
  // Returns available binder colors for a given theme
  static List<BinderColorOption> getColorsForTheme(String themeId) {
    switch (themeId) {
      case AppThemes.latteId:
        return _latteLoveColors;
      case AppThemes.blushId:
        return _blushGoldColors;
      case AppThemes.lavenderId:
        return _lavenderDreamsColors;
      case AppThemes.mintId:
        return _mintFreshColors;
      case AppThemes.monoId:
        return _monochromeColors;
      case AppThemes.singularityId:
        return _singularityColors;
      default:
        return _latteLoveColors;
    }
  }

  static final _latteLoveColors = [
    const BinderColorOption(
      id: 'espresso',
      displayName: 'Espresso',
      binderColor: Color(0xFF5C4033),
      paperColor: Color(0xFFF5EFE6),
      envelopeTextColor: Color(0xFF3E2723),
      envelopeBorderColor: Color(0xFF8B6F47),
    ),
    const BinderColorOption(
      id: 'caramel',
      displayName: 'Caramel',
      binderColor: Color(0xFFC89B6C),
      paperColor: Color(0xFFFFF8F0),
      envelopeTextColor: Color(0xFF5D4037),
      envelopeBorderColor: Color(0xFFA67C52),
    ),
    const BinderColorOption(
      id: 'mocha',
      displayName: 'Mocha',
      binderColor: Color(0xFF8B6F47),
      paperColor: Color(0xFFF0E8DC),
      envelopeTextColor: Color(0xFF4A3426),
      envelopeBorderColor: Color(0xFF6D563D),
    ),
    const BinderColorOption(
      id: 'vanilla_cream',
      displayName: 'Vanilla Cream',
      binderColor: Color(0xFFE8DFD0),
      paperColor: Color(0xFFFFFBF5),
      envelopeTextColor: Color(0xFF6B5544),
      envelopeBorderColor: Color(0xFFC4A582),
    ),
  ];

  static final _blushGoldColors = [
    const BinderColorOption(
      id: 'rose_gold',
      displayName: 'Rose Gold',
      binderColor: Color(0xFFD4AF37),
      paperColor: Color(0xFFFFF5F5),
      envelopeTextColor: Color(0xFF8B6B4D),
      envelopeBorderColor: Color(0xFFE8A0BF),
    ),
    const BinderColorOption(
      id: 'blush_pink',
      displayName: 'Blush Pink',
      binderColor: Color(0xFFE8A0BF),
      paperColor: Color(0xFFFFF8FA),
      envelopeTextColor: Color(0xFF6B4E71),
      envelopeBorderColor: Color(0xFFD4AF37),
    ),
    const BinderColorOption(
      id: 'dusty_rose',
      displayName: 'Dusty Rose',
      binderColor: Color(0xFFC9A0A6),
      paperColor: Color(0xFFFAF0F2),
      envelopeTextColor: Color(0xFF5C4550),
      envelopeBorderColor: Color(0xFFB88B94),
    ),
    const BinderColorOption(
      id: 'champagne',
      displayName: 'Champagne',
      binderColor: Color(0xFFF7E7CE),
      paperColor: Color(0xFFFFFAF5),
      envelopeTextColor: Color(0xFF8B7355),
      envelopeBorderColor: Color(0xFFDDB892),
    ),
  ];

  static final _lavenderDreamsColors = [
    const BinderColorOption(
      id: 'deep_lavender',
      displayName: 'Deep Lavender',
      binderColor: Color(0xFF9B87C6),
      paperColor: Color(0xFFF5F0FF),
      envelopeTextColor: Color(0xFF4A3F6B),
      envelopeBorderColor: Color(0xFFB8A7D9),
    ),
    const BinderColorOption(
      id: 'lilac',
      displayName: 'Lilac',
      binderColor: Color(0xFFC5B3E6),
      paperColor: Color(0xFFFAF7FF),
      envelopeTextColor: Color(0xFF5C4F7A),
      envelopeBorderColor: Color(0xFFA695C7),
    ),
    const BinderColorOption(
      id: 'periwinkle',
      displayName: 'Periwinkle',
      binderColor: Color(0xFF8B9DC3),
      paperColor: Color(0xFFF0F2FA),
      envelopeTextColor: Color(0xFF3D4E6B),
      envelopeBorderColor: Color(0xFF7B8FB8),
    ),
    const BinderColorOption(
      id: 'violet_mist',
      displayName: 'Violet Mist',
      binderColor: Color(0xFFDFD3E3),
      paperColor: Color(0xFFFFFBFF),
      envelopeTextColor: Color(0xFF6B5B7A),
      envelopeBorderColor: Color(0xFFB8A7C7),
    ),
  ];

  static final _mintFreshColors = [
    const BinderColorOption(
      id: 'sage_green',
      displayName: 'Sage Green',
      binderColor: Color(0xFF7BB8A0),
      paperColor: Color(0xFFF5FFF9),
      envelopeTextColor: Color(0xFF2C5F4D),
      envelopeBorderColor: Color(0xFF5A9B82),
    ),
    const BinderColorOption(
      id: 'mint',
      displayName: 'Mint',
      binderColor: Color(0xFFA8D8C8),
      paperColor: Color(0xFFF7FFFC),
      envelopeTextColor: Color(0xFF3A6B5A),
      envelopeBorderColor: Color(0xFF8CC4B2),
    ),
    const BinderColorOption(
      id: 'eucalyptus',
      displayName: 'Eucalyptus',
      binderColor: Color(0xFF8FAA9E),
      paperColor: Color(0xFFF2F7F5),
      envelopeTextColor: Color(0xFF3E5249),
      envelopeBorderColor: Color(0xFF6D8C7F),
    ),
    const BinderColorOption(
      id: 'sea_glass',
      displayName: 'Sea Glass',
      binderColor: Color(0xFFB8D8D8),
      paperColor: Color(0xFFF5FFFE),
      envelopeTextColor: Color(0xFF4A6B6B),
      envelopeBorderColor: Color(0xFF90C4C4),
    ),
  ];

  static final _monochromeColors = [
    const BinderColorOption(
      id: 'charcoal',
      displayName: 'Charcoal',
      binderColor: Color(0xFF424242),
      paperColor: Color(0xFFFAFAFA),
      envelopeTextColor: Color(0xFF212121),
      envelopeBorderColor: Color(0xFF616161),
    ),
    const BinderColorOption(
      id: 'steel',
      displayName: 'Steel',
      binderColor: Color(0xFF757575),
      paperColor: Color(0xFFF5F5F5),
      envelopeTextColor: Color(0xFF424242),
      envelopeBorderColor: Color(0xFF9E9E9E),
    ),
    const BinderColorOption(
      id: 'silver',
      displayName: 'Silver',
      binderColor: Color(0xFFBDBDBD),
      paperColor: Color(0xFFFFFFFF),
      envelopeTextColor: Color(0xFF616161),
      envelopeBorderColor: Color(0xFF9E9E9E),
    ),
    const BinderColorOption(
      id: 'ink_black',
      displayName: 'Ink Black',
      binderColor: Color(0xFF212121),
      paperColor: Color(0xFFF0F0F0),
      envelopeTextColor: Color(0xFF000000),
      envelopeBorderColor: Color(0xFF424242),
    ),
  ];

  static final _singularityColors = [
    const BinderColorOption(
      id: 'cosmic_teal',
      displayName: 'Cosmic Teal',
      binderColor: Color(0xFF00BCD4),
      paperColor: Color(0xFF1E2A3A),
      envelopeTextColor: Color(0xFFE0F7FA),
      envelopeBorderColor: Color(0xFF00E5FF),
    ),
    const BinderColorOption(
      id: 'deep_space',
      displayName: 'Deep Space',
      binderColor: Color(0xFF2196F3),
      paperColor: Color(0xFF1A2332),
      envelopeTextColor: Color(0xFFBBDEFB),
      envelopeBorderColor: Color(0xFF42A5F5),
    ),
    const BinderColorOption(
      id: 'nebula_purple',
      displayName: 'Nebula Purple',
      binderColor: Color(0xFF7B1FA2),
      paperColor: Color(0xFF1C1C2E),
      envelopeTextColor: Color(0xFFE1BEE7),
      envelopeBorderColor: Color(0xFFAB47BC),
    ),
    const BinderColorOption(
      id: 'lunar_grey',
      displayName: 'Lunar Grey',
      binderColor: Color(0xFF546E7A),
      paperColor: Color(0xFF263238),
      envelopeTextColor: Color(0xFFCFD8DC),
      envelopeBorderColor: Color(0xFF78909C),
    ),
  ];
}
