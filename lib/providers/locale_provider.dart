// lib/providers/locale_provider.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  // Current selections
  String _languageCode = 'en';
  String _currencyCode = 'GBP';
  String _currencySymbol = '£';
  String _horizonEmoji = '🥰'; // Emoji shown when envelope reaches 100%

  // Getters
  String get languageCode => _languageCode;
  String get currencyCode => _currencyCode;
  String get currencySymbol => _currencySymbol;
  String get horizonEmoji => _horizonEmoji; // Renamed from celebrationEmoji

  // Keep old getter for backward compatibility
  @Deprecated('Use horizonEmoji instead')
  String get celebrationEmoji => _horizonEmoji;

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

  /// Initialize from SharedPreferences (local-only, no Firebase)
  Future<void> initialize(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _languageCode = prefs.getString('language_code') ?? 'en';
      _currencyCode = prefs.getString('currency_code') ?? 'GBP';
      _currencySymbol = _getCurrencySymbol(_currencyCode);
      // Load from old 'celebration_emoji' key for backward compatibility
      _horizonEmoji = prefs.getString('celebration_emoji') ?? prefs.getString('horizon_emoji') ?? '🥰';

      notifyListeners();
    } catch (e) {
    }
  }

  /// Set language (local-only, no Firebase sync)
  Future<void> setLanguage(String languageCode) async {
    _languageCode = languageCode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language_code', languageCode);

    } catch (e) {
    }
  }

  /// Set currency (local-only, no Firebase sync)
  Future<void> setCurrency(String currencyCode) async {
    _currencyCode = currencyCode;
    _currencySymbol = _getCurrencySymbol(currencyCode);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currency_code', currencyCode);

    } catch (e) {
    }
  }

  /// Set horizon emoji - shown when envelope reaches 100% (local-only, no Firebase sync)
  Future<void> setHorizonEmoji(String emoji) async {
    _horizonEmoji = emoji;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('horizon_emoji', emoji);

    } catch (e) {
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
