// lib/providers/app_preferences_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferencesProvider with ChangeNotifier {
  static const String _celebrationEmojiKey = 'celebration_emoji';
  static const String _languageKey = 'selected_language';
  static const String _currencyKey = 'selected_currency';

  String _celebrationEmoji = '🥰';
  String _selectedLanguage = 'en';
  String _selectedCurrency = 'GBP';

  String get celebrationEmoji => _celebrationEmoji;
  String get selectedLanguage => _selectedLanguage;
  String get selectedCurrency => _selectedCurrency;

  AppPreferencesProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _celebrationEmoji = prefs.getString(_celebrationEmojiKey) ?? '🥰';
    _selectedLanguage = prefs.getString(_languageKey) ?? 'en';
    _selectedCurrency = prefs.getString(_currencyKey) ?? 'GBP';
    notifyListeners();
  }

  Future<void> setCelebrationEmoji(String emoji) async {
    _celebrationEmoji = emoji;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_celebrationEmojiKey, emoji);
    notifyListeners();
  }

  Future<void> setLanguage(String languageCode) async {
    _selectedLanguage = languageCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, languageCode);
    notifyListeners();
  }

  Future<void> setCurrency(String currencyCode) async {
    _selectedCurrency = currencyCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currencyKey, currencyCode);
    notifyListeners();
  }

  String getCurrencySymbol() {
    switch (_selectedCurrency) {
      case 'GBP':
        return '£';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      default:
        return '£';
    }
  }

  static String getLanguageName(String code) {
    switch (code) {
      case 'en':
        return 'English';
      case 'es':
        return 'Español';
      case 'fr':
        return 'Français';
      default:
        return 'English';
    }
  }

  static String getCurrencyName(String code) {
    switch (code) {
      case 'GBP':
        return 'British Pound (£)';
      case 'USD':
        return 'US Dollar (\$)';
      case 'EUR':
        return 'Euro (€)';
      default:
        return 'British Pound (£)';
    }
  }
}
