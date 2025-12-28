// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_themes.dart';

class ThemeProvider extends ChangeNotifier {
  String _currentThemeId = AppThemes.latteId;

  // Accept initial theme to fix startup flash
  ThemeProvider({String? initialThemeId}) {
    if (initialThemeId != null) {
      _currentThemeId = initialThemeId;
    }
  }

  String get currentThemeId => _currentThemeId;

  // FIXED: Global AppBar Bleed Fix
  // We force scrolledUnderElevation to 0 for WHATEVER theme is selected
  ThemeData get currentTheme {
    final theme = AppThemes.getTheme(_currentThemeId);
    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        scrolledUnderElevation: 0, // Prevents color change on scroll
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
    );
  }

  /// Initialize from SharedPreferences (local-only, no Firebase)
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedThemeId = prefs.getString('selected_theme_id');

      if (savedThemeId != null && savedThemeId != _currentThemeId) {
        _currentThemeId = savedThemeId;
        notifyListeners();
      }

      debugPrint('[ThemeProvider] ✅ Loaded theme from SharedPreferences: $_currentThemeId');
    } catch (e) {
      debugPrint('[ThemeProvider] ❌ Error loading theme: $e');
    }
  }

  /// Set theme (local-only, no Firebase sync)
  Future<void> setTheme(String themeId) async {
    if (_currentThemeId == themeId) return;

    _currentThemeId = themeId;
    notifyListeners();

    try {
      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_theme_id', themeId);

      debugPrint('[ThemeProvider] ✅ Theme saved locally: $themeId');
    } catch (e) {
      debugPrint('[ThemeProvider] ❌ Error saving theme: $e');
    }
  }
}
