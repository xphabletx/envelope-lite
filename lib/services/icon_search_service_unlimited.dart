// lib/services/icon_search_service_UNLIMITED.dart
// UNLIMITED SEARCH: Local suggestions + Live domain testing + Emoji detection

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../data/material_icons_database.dart';
import '../data/emoji_database.dart';
import '../data/company_logos_database.dart';

enum IconType { emoji, materialIcon, companyLogo }

class IconSearchResult {
  final IconType type;
  final String value;
  final String displayName;
  final Widget preview;
  final List<String> keywords;
  final String category;
  final String? source; // 'suggested', 'custom', 'keyboard'

  IconSearchResult({
    required this.type,
    required this.value,
    required this.displayName,
    required this.preview,
    required this.keywords,
    required this.category,
    this.source,
  });
}

class OmniIconSearchResults {
  final List<IconSearchResult> emojis;
  final List<IconSearchResult> materialIcons;
  final List<IconSearchResult> companyLogos;
  final List<IconSearchResult> customDomains; // NEW: User-entered domains

  OmniIconSearchResults({
    this.emojis = const [],
    this.materialIcons = const [],
    this.companyLogos = const [],
    this.customDomains = const [],
  });

  int get totalResults =>
      emojis.length +
      materialIcons.length +
      companyLogos.length +
      customDomains.length;

  bool get isEmpty => totalResults == 0;
}

class IconSearchService {
  /// Synonym mapping for smarter searches
  static final synonymMap = {
    'fuel': ['gas', 'petrol', 'gasoline', 'station'],
    'car': ['vehicle', 'auto', 'automobile', 'transport'],
    'phone': ['mobile', 'cell', 'telephone', 'contact'],
    'money': ['cash', 'finance', 'payment', 'wallet', 'bank'],
    'food': ['dining', 'restaurant', 'eating', 'meal'],
    'house': ['home', 'property', 'rent', 'mortgage'],
    'electric': ['electricity', 'power', 'energy', 'utility'],
    'tv': ['television', 'streaming', 'video', 'entertainment'],
    'internet': ['broadband', 'wifi', 'network', 'connection'],
    'gym': ['fitness', 'exercise', 'workout', 'health'],
    'shop': ['shopping', 'store', 'retail', 'mall'],
    'flower': ['flowers', 'bouquet', 'floral', 'blossom', 'rose', 'plant', 'nature', 'garden'],
  };

  /// Get all search terms including synonyms
  static List<String> _getSearchTerms(String query) {
    final terms = [query];

    // Add synonyms if they exist
    if (synonymMap.containsKey(query)) {
      terms.addAll(synonymMap[query]!);
    }

    return terms;
  }

  /// Main omni search function with unlimited capabilities
  static Future<OmniIconSearchResults> search(
    String query, {
    int maxPerType = 10,
  }) async {
    if (query.isEmpty) {
      return _getPopularDefaults();
    }

    final normalizedQuery = query.toLowerCase().trim();

    // Get ALL search terms (original + synonyms)
    final searchTerms = _getSearchTerms(normalizedQuery);

    // Check emoji detection first
    final emojiDetected = _detectEmoji(query);
    if (emojiDetected != null) {
      return OmniIconSearchResults(
        emojis: [emojiDetected],
      );
    }

    // ALWAYS search all databases with ALL terms
    final localEmojis = _searchEmojisComprehensive(searchTerms, maxPerType);
    final localIcons =
        _searchMaterialIconsComprehensive(searchTerms, maxPerType);
    final localLogos =
        _searchCompanyLogosComprehensive(searchTerms, maxPerType);

    // Only test custom domains if no local matches
    List<IconSearchResult> customDomains = [];
    if (localLogos.isEmpty && !normalizedQuery.contains(' ')) {
      customDomains = await _testCustomDomains(normalizedQuery);
    }

    return OmniIconSearchResults(
      emojis: localEmojis,
      materialIcons: localIcons,
      companyLogos: localLogos,
      customDomains: customDomains,
    );
  }

  /// Detect if user typed an emoji from their keyboard
  static IconSearchResult? _detectEmoji(String input) {
    // Check if input contains emoji characters
    final emojiRegex = RegExp(
      r'(\u00a9|\u00ae|[\u2000-\u3300]|\ud83c[\ud000-\udfff]|\ud83d[\ud000-\udfff]|\ud83e[\ud000-\udfff])',
    );

    if (emojiRegex.hasMatch(input)) {
      // Extract the emoji
      final emoji = input.trim();
      return IconSearchResult(
        type: IconType.emoji,
        value: emoji,
        displayName: 'Custom Emoji',
        preview: Text(emoji, style: const TextStyle(fontSize: 40)),
        keywords: ['custom', 'keyboard'],
        category: 'custom',
        source: 'keyboard',
      );
    }

    return null;
  }

  /// Special domain mapping for government and known entities
  static final Map<String, String> specialDomains = {
    'dvla': 'gov.uk',
    'hmrc': 'gov.uk',
    'nhs': 'nhs.uk',
    'tv licence': 'tvlicensing.co.uk',
    'tv license': 'tvlicensing.co.uk',
    'council tax': 'gov.uk',
    'passport': 'gov.uk',
  };

  /// Generic terms that should NOT be tested as domains
  static final List<String> genericTerms = [
    'hairdresser', 'barber', 'salon', 'stylist',
    'clothes', 'clothing', 'fashion', 'shop', 'store',
    'food', 'restaurant', 'cafe', 'dining',
    'hotel', 'accommodation', 'motel',
    'gym', 'fitness', 'exercise',
    'doctor', 'dentist', 'medical', 'hospital',
    'vet', 'veterinary',
    'garage', 'mechanic', 'repair',
    'plumber', 'electrician', 'builder',
    'christmas', 'birthday', 'party', 'celebration',
    'tickets', 'ticket', 'event',
    'holiday', 'vacation', 'travel',
    'insurance', 'bank', 'finance',
  ];

  /// Test if user's input could be a valid domain
  static Future<List<IconSearchResult>> _testCustomDomains(String query) async {
    final results = <IconSearchResult>[];

    // Skip if query is too short or contains spaces
    if (query.length < 3 || query.contains(' ')) {
      return results;
    }

    // Skip generic terms - these should only show icons/emojis
    if (genericTerms.contains(query.toLowerCase())) {
      return results;
    }

    // Check for special domain mappings first
    String? domainToTest;
    if (specialDomains.containsKey(query.toLowerCase())) {
      domainToTest = specialDomains[query.toLowerCase()];

      // Add result for special domain
      results.add(
        IconSearchResult(
          type: IconType.companyLogo,
          value: domainToTest!,
          displayName: query.toUpperCase(),
          preview: Image.network(
            'https://www.google.com/s2/favicons?sz=128&domain=$domainToTest',
            width: 40,
            height: 40,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.business, size: 40),
          ),
          keywords: [query, 'government', 'official'],
          category: 'custom',
          source: 'custom',
        ),
      );

      return results;
    }

    // Try common TLDs for company names
    final tlds = ['com', 'co.uk', 'net', 'org', 'io'];

    for (final tld in tlds) {
      final domain = '$query.$tld';

      // Quick check if logo exists
      final logoExists = await _checkLogoExists(domain);

      if (logoExists) {
        results.add(
          IconSearchResult(
            type: IconType.companyLogo,
            value: domain,
            displayName: query.toUpperCase(),
            preview: Image.network(
              'https://www.google.com/s2/favicons?sz=128&domain=$domain',
              width: 40,
              height: 40,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.business, size: 40),
            ),
            keywords: [query, 'custom', 'domain'],
            category: 'custom',
            source: 'custom',
          ),
        );
      }
    }

    return results;
  }

  /// Check if a logo exists for a domain
  static Future<bool> _checkLogoExists(String domain) async {
    try {
      final response = await http
          .head(
            Uri.parse(
              'https://www.google.com/s2/favicons?sz=128&domain=$domain',
            ),
          )
          .timeout(const Duration(seconds: 2));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Search Material Icons (COMPREHENSIVE - searches ALL icons)
  static List<IconSearchResult> _searchMaterialIconsComprehensive(
    List<String> searchTerms,
    int limit,
  ) {
    final results = <IconSearchResult>[];
    final scoreMap = <String, int>{};

    // Search ALL icons, don't break early
    for (final entry in materialIconsDatabase.entries) {
      final iconName = entry.key;
      final data = entry.value;
      final keywords = data['keywords'] as List<String>;

      // Calculate best score across all search terms
      int bestScore = 0;
      for (final term in searchTerms) {
        final score = _calculateRelevanceScore(term, iconName, keywords);
        if (score > bestScore) {
          bestScore = score;
        }
      }

      if (bestScore > 0) {
        scoreMap[iconName] = bestScore;
        results.add(IconSearchResult(
          type: IconType.materialIcon,
          value: iconName,
          displayName: _formatIconName(iconName),
          preview: Icon(data['icon'] as IconData, size: 40),
          keywords: keywords,
          category: data['category'] as String,
          source: 'suggested',
        ));
      }
    }

    // Sort by score and return top results
    results.sort(
        (a, b) => (scoreMap[b.value] ?? 0).compareTo(scoreMap[a.value] ?? 0));

    return results.take(limit).toList();
  }

  /// Search Emojis (COMPREHENSIVE - searches ALL emojis)
  static List<IconSearchResult> _searchEmojisComprehensive(
    List<String> searchTerms,
    int limit,
  ) {
    final results = <IconSearchResult>[];
    final scoreMap = <String, int>{};

    // Search ALL emojis
    for (final entry in emojiDatabase.entries) {
      final emoji = entry.key;
      final keywords = entry.value;

      // Check against all search terms
      int bestScore = 0;
      for (final term in searchTerms) {
        if (keywords.any((k) => k.contains(term))) {
          final score = keywords.any((k) => k == term) ? 100 : 50;
          if (score > bestScore) {
            bestScore = score;
          }
        }
      }

      if (bestScore > 0) {
        scoreMap[emoji] = bestScore;
        results.add(IconSearchResult(
          type: IconType.emoji,
          value: emoji,
          displayName: keywords.first,
          preview: Text(emoji, style: const TextStyle(fontSize: 40)),
          keywords: keywords,
          category: _categorizeEmoji(keywords),
          source: 'suggested',
        ));
      }
    }

    // Sort by score
    results.sort(
        (a, b) => (scoreMap[b.value] ?? 0).compareTo(scoreMap[a.value] ?? 0));

    return results.take(limit).toList();
  }

  /// Search Company Logos (COMPREHENSIVE - searches ALL companies)
  static List<IconSearchResult> _searchCompanyLogosComprehensive(
    List<String> searchTerms,
    int limit,
  ) {
    final results = <IconSearchResult>[];
    final scoreMap = <String, int>{};

    // Search ALL companies
    for (final category in companyLogosDatabase.entries) {
      for (final company in category.value.entries) {
        final companyName = company.key;
        final data = company.value;
        final domain = data['domain'] as String;
        final keywords = data['keywords'] as List<String>;

        // Check against all search terms
        int bestScore = 0;
        for (final term in searchTerms) {
          if (companyName.toLowerCase().contains(term) ||
              keywords.any((k) => k.contains(term))) {
            final score = companyName.toLowerCase() == term ? 100 : 50;
            if (score > bestScore) {
              bestScore = score;
            }
          }
        }

        if (bestScore > 0) {
          scoreMap[domain] = bestScore;
          results.add(IconSearchResult(
            type: IconType.companyLogo,
            value: domain,
            displayName: companyName,
            preview: Image.network(
              'https://www.google.com/s2/favicons?sz=128&domain=$domain',
              width: 40,
              height: 40,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.business, size: 40),
            ),
            keywords: keywords,
            category: category.key,
            source: 'suggested',
          ));
        }
      }
    }

    // Sort by score
    results.sort(
        (a, b) => (scoreMap[b.value] ?? 0).compareTo(scoreMap[a.value] ?? 0));

    return results.take(limit).toList();
  }

  /// Get popular defaults when no search query
  static OmniIconSearchResults _getPopularDefaults() {
    return OmniIconSearchResults(
      materialIcons: [
        _createMaterialIconResult('account_balance_wallet'),
        _createMaterialIconResult('home'),
        _createMaterialIconResult('restaurant'),
        _createMaterialIconResult('local_gas_station'),
        _createMaterialIconResult('shopping_cart'),
        _createMaterialIconResult('phone'),
        _createMaterialIconResult('bolt'),
        _createMaterialIconResult('fitness_center'),
      ],
      emojis: [
        _createEmojiResult('💰'),
        _createEmojiResult('🏠'),
        _createEmojiResult('🍔'),
        _createEmojiResult('🚗'),
        _createEmojiResult('📱'),
        _createEmojiResult('💳'),
        _createEmojiResult('⚡'),
        _createEmojiResult('🏋️'),
      ],
    );
  }

  /// Calculate relevance score for ranking
  static int _calculateRelevanceScore(
    String query,
    String name,
    List<String> keywords,
  ) {
    int score = 0;

    if (name == query) {
      score += 100;
    }
    if (name.startsWith(query)) {
      score += 50;
    }
    if (name.contains(query)) {
      score += 25;
    }

    for (final keyword in keywords) {
      if (keyword == query) {
        score += 75;
      }
      if (keyword.startsWith(query)) {
        score += 40;
      }
      if (keyword.contains(query)) {
        score += 15;
      }
    }

    return score;
  }

  /// Format icon name for display
  static String _formatIconName(String iconName) {
    return iconName
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  /// Helper to categorize emoji
  static String _categorizeEmoji(List<String> keywords) {
    if (keywords.any((k) => ['money', 'cash', 'finance'].contains(k))) {
      return 'finance';
    }
    if (keywords.any((k) => ['home', 'house'].contains(k))) {
      return 'home';
    }
    if (keywords.any((k) => ['food', 'restaurant'].contains(k))) {
      return 'food';
    }
    return 'other';
  }

  /// Helper functions to create results
  static IconSearchResult _createMaterialIconResult(String iconName) {
    final data = materialIconsDatabase[iconName]!;
    return IconSearchResult(
      type: IconType.materialIcon,
      value: iconName,
      displayName: _formatIconName(iconName),
      preview: Icon(data['icon'] as IconData, size: 40),
      keywords: data['keywords'] as List<String>,
      category: data['category'] as String,
      source: 'suggested',
    );
  }

  static IconSearchResult _createEmojiResult(String emoji) {
    final keywords = emojiDatabase[emoji]!;
    return IconSearchResult(
      type: IconType.emoji,
      value: emoji,
      displayName: keywords.first,
      preview: Text(emoji, style: const TextStyle(fontSize: 40)),
      keywords: keywords,
      category: _categorizeEmoji(keywords),
      source: 'suggested',
    );
  }
}
