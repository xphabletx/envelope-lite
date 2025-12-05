// lib/services/localization_service.dart
// FIX: Removed unused _currentLanguage field

class LocalizationService {
  // Singleton pattern
  static final LocalizationService _instance = LocalizationService._internal();
  factory LocalizationService() => _instance;
  LocalizationService._internal();

  // Get localized string by key
  String getString(String key) {
    // For now, return the English string directly
    // Later this will look up from .arb files
    return _englishStrings[key] ?? key;
  }

  // Format currency
  String formatCurrency(double amount, {String? currencyCode}) {
    // Placeholder - will use intl package for proper formatting
    return '£${amount.toStringAsFixed(2)}';
  }

  // English strings (source of truth)
  static const Map<String, String> _englishStrings = {
    // App-wide
    'app_name': 'Team Envelopes',
    'your_envelopes': 'Your Envelopes',
    'settings': 'Settings',
    'cancel': 'Cancel',
    'save': 'Save',
    'delete': 'Delete',
    'edit': 'Edit',
    'close': 'Close',
    'continue': 'Continue',
    'back': 'Back',
    'done': 'Done',

    // Home Screen
    'home_envelopes_tab': 'Envelopes',
    'home_groups_tab': 'Groups',
    'home_budget_tab': 'Budget',
    'home_calendar_tab': 'Calendar',
    'home_pay_day_button': 'PAY DAY',
    'home_no_envelopes': 'No envelopes yet',
    'home_create_first': 'Tap + to create your first envelope',

    // Envelopes
    'envelope_new': 'New Envelope',
    'envelope_name': 'Envelope Name',
    'envelope_target': 'Target Amount',
    'envelope_current': 'Current Amount',
    'envelope_delete_confirm': 'Delete envelope?',

    // Groups
    'group_new': 'New Group',
    'group_name': 'Group Name',
    'group_no_binders': 'No binders yet',

    // Settings
    'settings_account': 'Account',
    'settings_display_name': 'Display Name',
    'settings_email': 'Email',
    'settings_appearance': 'Appearance',
    'settings_workspace': 'Workspace',
    'settings_sign_out': 'Sign Out',

    // Appearance
    'appearance_theme': 'Theme',
    'appearance_font': 'Font',
    'appearance_celebration': 'Celebration',
    'appearance_target_emoji': 'Target Complete Emoji',

    // Workspace
    'workspace_create': 'Create Workspace',
    'workspace_join': 'Join Workspace',
    'workspace_settings': 'Workspace Settings',
    'workspace_members': 'Members',
    'workspace_sharing': 'Sharing',

    // Onboarding
    'onboarding_photo': 'Add a Profile Photo',
    'onboarding_display_name': 'What should we call you?',
    'onboarding_theme': 'Pick Your Vibe',
    'onboarding_font': 'Choose Your Font',
    'onboarding_language': 'Select Language',
    'onboarding_currency': 'Select Currency',
    'onboarding_get_started': 'Get Started 🎉',

    // Errors & Messages
    'error_required_field': 'This field is required',
    'error_invalid_amount': 'Please enter a valid amount',
    'success_saved': 'Saved successfully',
    'success_updated': 'Updated successfully',
    'success_deleted': 'Deleted successfully',
  };
}

// Helper function for quick access
String tr(String key) {
  return LocalizationService().getString(key);
}
