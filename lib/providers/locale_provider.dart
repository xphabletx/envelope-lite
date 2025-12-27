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
    // Europe
    {'code': 'GBP', 'name': 'British Pound', 'symbol': '£'},
    {'code': 'EUR', 'name': 'Euro', 'symbol': '€'},

    // Americas
    {'code': 'USD', 'name': 'US Dollar', 'symbol': '\$'},
    {'code': 'CAD', 'name': 'Canadian Dollar', 'symbol': 'C\$'},
    {'code': 'MXN', 'name': 'Mexican Peso', 'symbol': 'Mex\$'},
    {'code': 'BRL', 'name': 'Brazilian Real', 'symbol': 'R\$'},
    {'code': 'ARS', 'name': 'Argentine Peso', 'symbol': 'ARS\$'},

    // Asia-Pacific
    {'code': 'JPY', 'name': 'Japanese Yen', 'symbol': '¥'},
    {'code': 'CNY', 'name': 'Chinese Yuan', 'symbol': '¥'},
    {'code': 'INR', 'name': 'Indian Rupee', 'symbol': '₹'},
    {'code': 'AUD', 'name': 'Australian Dollar', 'symbol': 'A\$'},
    {'code': 'NZD', 'name': 'New Zealand Dollar', 'symbol': 'NZ\$'},
    {'code': 'SGD', 'name': 'Singapore Dollar', 'symbol': 'S\$'},
    {'code': 'HKD', 'name': 'Hong Kong Dollar', 'symbol': 'HK\$'},
    {'code': 'KRW', 'name': 'South Korean Won', 'symbol': '₩'},

    // Middle East & Africa
    {'code': 'AED', 'name': 'UAE Dirham', 'symbol': 'AED'},
    {'code': 'SAR', 'name': 'Saudi Riyal', 'symbol': 'SAR'},
    {'code': 'ZAR', 'name': 'South African Rand', 'symbol': 'R'},

    // Other
    {'code': 'CHF', 'name': 'Swiss Franc', 'symbol': 'CHF'},
    {'code': 'SEK', 'name': 'Swedish Krona', 'symbol': 'kr'},
    {'code': 'NOK', 'name': 'Norwegian Krone', 'symbol': 'kr'},
    {'code': 'DKK', 'name': 'Danish Krone', 'symbol': 'kr'},
    {'code': 'PLN', 'name': 'Polish Złoty', 'symbol': 'zł'},
    {'code': 'TRY', 'name': 'Turkish Lira', 'symbol': '₺'},
  ];

  Future<void> initialize(String userId) async {
    _userId = userId;
    await _loadFromFirebase();
  }

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

  String _getCurrencySymbol(String code) {
    final currency = supportedCurrencies.firstWhere(
      (c) => c['code'] == code,
      orElse: () => supportedCurrencies[0],
    );
    return currency['symbol']!;
  }

  String formatCurrency(double amount) {
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

  static String getLanguageName(String code) {
    final lang = supportedLanguages.firstWhere(
      (l) => l['code'] == code,
      orElse: () => supportedLanguages[0],
    );
    return lang['name']!;
  }

  static String getLanguageFlag(String code) {
    final lang = supportedLanguages.firstWhere(
      (l) => l['code'] == code,
      orElse: () => supportedLanguages[0],
    );
    return lang['flag']!;
  }

  static String getCurrencyName(String code) {
    final currency = supportedCurrencies.firstWhere(
      (c) => c['code'] == code,
      orElse: () => supportedCurrencies[0],
    );
    return currency['name']!;
  }

  static String getCurrencySymbolStatic(String code) {
    final currency = supportedCurrencies.firstWhere(
      (c) => c['code'] == code,
      orElse: () => supportedCurrencies[0],
    );
    return currency['symbol']!;
  }
}
