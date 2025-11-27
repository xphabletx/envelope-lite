// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';
import '../theme/app_themes.dart';
import '../services/user_service.dart';

class ThemeProvider extends ChangeNotifier {
  String _currentThemeId = AppThemes.latteId;
  UserService? _userService;

  ThemeProvider();

  String get currentThemeId => _currentThemeId;
  ThemeData get currentTheme => AppThemes.getTheme(_currentThemeId);

  // Initialize with user service
  void initialize(UserService userService) {
    _userService = userService;
    _loadThemeFromFirebase();
  }

  // Load theme from Firebase
  Future<void> _loadThemeFromFirebase() async {
    if (_userService == null) return;

    final profile = await _userService!.getUserProfile();
    if (profile != null) {
      _currentThemeId = profile.selectedTheme;
      notifyListeners();
    }
  }

  // Change theme
  Future<void> setTheme(String themeId) async {
    if (_currentThemeId == themeId) return;

    _currentThemeId = themeId;
    notifyListeners();

    // Save to Firebase
    if (_userService != null) {
      await _userService!.updateUserProfile(selectedTheme: themeId);
    }
  }
}
