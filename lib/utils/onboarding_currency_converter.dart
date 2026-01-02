/// Currency converter for onboarding examples
/// Uses median 12-month conversion rates with smart rounding for clean numbers
class OnboardingCurrencyConverter {
  // Median conversion rates from GBP (12-month average 2024)
  // These are for EXAMPLES ONLY, not financial calculations
  static const Map<String, double> conversionRates = {
    // Base
    'GBP': 1.0,

    // Europe
    'EUR': 1.17,
    'CHF': 1.10,
    'SEK': 13.50,
    'NOK': 13.80,
    'DKK': 8.70,
    'PLN': 5.10,
    'TRY': 43.00,

    // Americas
    'USD': 1.27,
    'CAD': 1.72,
    'MXN': 21.50,
    'BRL': 6.35,
    'ARS': 1100.00,

    // Asia-Pacific
    'JPY': 190.00,
    'CNY': 9.10,
    'INR': 106.00,
    'AUD': 1.93,
    'NZD': 2.10,
    'SGD': 1.70,
    'HKD': 9.90,
    'KRW': 1720.00,

    // Middle East & Africa
    'AED': 4.65,
    'SAR': 4.75,
    'ZAR': 23.00,
  };

  /// Convert GBP amount to user's selected currency with smart rounding
  static double convert(double gbpAmount, String currencyCode) {
    final rate = conversionRates[currencyCode] ?? 1.0;
    final converted = gbpAmount * rate;

    // Round based on currency type for clean numbers
    if (['JPY', 'KRW', 'ARS'].contains(currencyCode)) {
      // No decimal currencies - round to nearest 100
      return (converted / 100).round() * 100.0;
    } else if (['INR', 'MXN', 'BRL', 'TRY', 'ZAR'].contains(currencyCode)) {
      // Large-value currencies - round to nearest 10
      return (converted / 10).round() * 10.0;
    } else {
      // Standard currencies - round to nearest 5
      return (converted / 5).round() * 5.0;
    }
  }

  /// Get all example amounts for Envelope Mindset screen
  static Map<String, double> getExamples(String currencyCode) {
    return {
      'netflix': convert(12.99, currencyCode),
      'groceries': convert(200.00, currencyCode),
      'savings': convert(500.00, currencyCode),
      'coffee': convert(20.00, currencyCode),
    };
  }
}
