// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_themes.dart';
import '../services/user_service.dart';

class ThemeProvider extends ChangeNotifier {
  String _currentThemeId = AppThemes.latteId;
  UserService? _userService;

  // Accept initial theme to fix startup flash
  ThemeProvider({String? initialThemeId}) {
    if (initialThemeId != null) {
      _currentThemeId = initialThemeId;
    }
  }

  String get currentThemeId => _currentThemeId;

  // FIXED (Bug 5): Global AppBar Bleed Fix
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

  // Sync with Firebase (called after login)
  Future<void> initialize(UserService userService) async {
    _userService = userService;
    await _loadThemeFromFirebase();
  }

  Future<void> _loadThemeFromFirebase() async {
    if (_userService == null) return;

    try {
      final profile = await _userService!.getUserProfile();
      if (profile != null && profile.selectedTheme != _currentThemeId) {
        _currentThemeId = profile.selectedTheme;
        notifyListeners();
        // Update local storage to keep in sync
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('selected_theme_id', _currentThemeId);
      }
    } catch (e) {
      debugPrint('Error loading theme: $e');
    }
  }

  Future<void> setTheme(String themeId) async {
    if (_currentThemeId == themeId) return;

    _currentThemeId = themeId;
    notifyListeners();

    // Save to Local Storage (Immediate)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_theme_id', themeId);

    // Save to Firebase (Background)
    if (_userService != null) {
      await _userService!.updateUserProfile(selectedTheme: themeId);
    }
  }
}
