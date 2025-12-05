// lib/providers/font_provider.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FontProvider with ChangeNotifier {
  static const String _fontKey = 'selected_font';

  // Font IDs
  static const String caveatId = 'caveat';
  static const String indieFlowerId = 'indie_flower';
  static const String robotoId = 'roboto';
  static const String openSansId = 'open_sans';
  static const String systemDefaultId = 'system_default';

  String _currentFontId =
      systemDefaultId; // CHANGED: default to system, not Caveat

  String get currentFontId => _currentFontId;

  FontProvider() {
    _loadFont();
  }

  Future<void> _loadFont() async {
    final prefs = await SharedPreferences.getInstance();
    _currentFontId =
        prefs.getString(_fontKey) ??
        systemDefaultId; // CHANGED: default to system
    notifyListeners();
  }

  Future<void> setFont(String fontId) async {
    _currentFontId = fontId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fontKey, fontId);
    notifyListeners();
  }

  // Get the TextTheme for the current font
  TextTheme getTextTheme() {
    switch (_currentFontId) {
      case caveatId:
        return GoogleFonts.caveatTextTheme();
      case indieFlowerId:
        return GoogleFonts.indieFlowerTextTheme();
      case robotoId:
        return GoogleFonts.robotoTextTheme();
      case openSansId:
        return GoogleFonts.openSansTextTheme();
      case systemDefaultId:
      default:
        return ThemeData.light().textTheme; // Flutter's default
    }
  }

  // Get TextStyle for specific use (buttons, labels, etc.)
  TextStyle getTextStyle({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    TextStyle baseStyle;

    switch (_currentFontId) {
      case caveatId:
        baseStyle = GoogleFonts.caveat();
        break;
      case indieFlowerId:
        baseStyle = GoogleFonts.indieFlower();
        break;
      case robotoId:
        baseStyle = GoogleFonts.roboto();
        break;
      case openSansId:
        baseStyle = GoogleFonts.openSans();
        break;
      case systemDefaultId:
      default:
        baseStyle = const TextStyle();
    }

    return baseStyle.copyWith(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  // Get font name for display
  static String getFontName(String fontId) {
    switch (fontId) {
      case caveatId:
        return 'Caveat';
      case indieFlowerId:
        return 'Indie Flower';
      case robotoId:
        return 'Roboto';
      case openSansId:
        return 'Open Sans';
      case systemDefaultId:
        return 'System Default';
      default:
        return 'Caveat';
    }
  }

  // Get all available fonts
  static List<FontOption> getAllFonts() {
    return [
      FontOption(
        id: caveatId,
        name: 'Caveat',
        description: 'Playful handwritten',
        isHandwritten: true,
      ),
      FontOption(
        id: indieFlowerId,
        name: 'Indie Flower',
        description: 'Casual handwritten',
        isHandwritten: true,
      ),
      FontOption(
        id: robotoId,
        name: 'Roboto',
        description: 'Clean and modern',
        isHandwritten: false,
      ),
      FontOption(
        id: openSansId,
        name: 'Open Sans',
        description: 'Friendly and readable',
        isHandwritten: false,
      ),
      FontOption(
        id: systemDefaultId,
        name: 'System Default',
        description: 'Your device font',
        isHandwritten: false,
      ),
    ];
  }
}

// Font option model
class FontOption {
  final String id;
  final String name;
  final String description;
  final bool isHandwritten;

  FontOption({
    required this.id,
    required this.name,
    required this.description,
    required this.isHandwritten,
  });
}
