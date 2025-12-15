// lib/providers/locale_provider.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class LocaleProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? _userId;

  // Current selections
  String _languageCode = 'en';
  String _currencyCode = 'GBP';
  String _currencySymbol = '£';

  // Getters
  String get languageCode => _languageCode;
  String get currencyCode => _currencyCode;
  String get currencySymbol => _currencySymbol;

  // Supported languages
  static const List<Map<String, String>> supportedLanguages = [
    {'code': 'en', 'name': 'English', 'flag': '🇬🇧'},
    {'code': 'de', 'name': 'Deutsch', 'flag': '🇩🇪'},
    {'code': 'fr', 'name': 'Français', 'flag': '🇫🇷'},
    {'code': 'es', 'name': 'Español', 'flag': '🇪🇸'},
    {'code': 'it', 'name': 'Italiano', 'flag': '🇮🇹'},
  ];

  // Supported currencies
  static const List<Map<String, String>> supportedCurrencies = [
    {'code': 'GBP', 'name': 'British Pound', 'symbol': '£'},
    {'code': 'EUR', 'name': 'Euro', 'symbol': '€'},
    {'code': 'USD', 'name': 'US Dollar', 'symbol': '\$'},
  ];

  /// Initialize with user ID and load preferences from Firebase
  Future<void> initialize(String userId) async {
    _userId = userId;
    await _loadFromFirebase();
  }

  /// Load user's language and currency preferences from Firebase
  Future<void> _loadFromFirebase() async {
    if (_userId == null) return;

    try {
      final doc = await _db.collection('users').doc(_userId).get();
      final data = doc.data();

      if (data != null) {
        if (data['languageCode'] != null) {
          _languageCode = data['languageCode'] as String;
        }
        if (data['currencyCode'] != null) {
          _currencyCode = data['currencyCode'] as String;
          _currencySymbol = _getCurrencySymbol(_currencyCode);
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading locale preferences: $e');
    }
  }

  /// Set language and persist to Firebase
  Future<void> setLanguage(String languageCode) async {
    if (_userId == null) return;

    _languageCode = languageCode;
    notifyListeners();

    try {
      await _db.collection('users').doc(_userId).update({
        'languageCode': languageCode,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving language: $e');
    }
  }

  /// Set currency and persist to Firebase
  Future<void> setCurrency(String currencyCode) async {
    if (_userId == null) return;

    _currencyCode = currencyCode;
    _currencySymbol = _getCurrencySymbol(currencyCode);
    notifyListeners();

    try {
      await _db.collection('users').doc(_userId).update({
        'currencyCode': currencyCode,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving currency: $e');
    }
  }

  /// Get currency symbol for code
  String _getCurrencySymbol(String code) {
    switch (code) {
      case 'GBP':
        return '£';
      case 'EUR':
        return '€';
      case 'USD':
        return '\$';
      default:
        return '£';
    }
  }

  /// Format currency amount based on current locale
  String formatCurrency(double amount) {
    // Map currency code to locale
    String locale;
    switch (_currencyCode) {
      case 'GBP':
        locale = 'en_GB';
        break;
      case 'EUR':
        locale = _languageCode == 'de' ? 'de_DE' : 'fr_FR';
        break;
      case 'USD':
        locale = 'en_US';
        break;
      default:
        locale = 'en_GB';
    }

    final formatter = NumberFormat.currency(
      locale: locale,
      symbol: _currencySymbol,
      decimalDigits: 2,
    );

    return formatter.format(amount);
  }

  /// Get language name for code
  static String getLanguageName(String code) {
    final lang = supportedLanguages.firstWhere(
      (l) => l['code'] == code,
      orElse: () => supportedLanguages[0],
    );
    return lang['name']!;
  }

  /// Get language flag for code
  static String getLanguageFlag(String code) {
    final lang = supportedLanguages.firstWhere(
      (l) => l['code'] == code,
      orElse: () => supportedLanguages[0],
    );
    return lang['flag']!;
  }

  /// Get currency name for code
  static String getCurrencyName(String code) {
    final currency = supportedCurrencies.firstWhere(
      (c) => c['code'] == code,
      orElse: () => supportedCurrencies[0],
    );
    return currency['name']!;
  }

  /// Get currency symbol for code (static)
  static String getCurrencySymbolStatic(String code) {
    final currency = supportedCurrencies.firstWhere(
      (c) => c['code'] == code,
      orElse: () => supportedCurrencies[0],
    );
    return currency['symbol']!;
  }
}
