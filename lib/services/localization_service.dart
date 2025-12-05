// lib/services/localization_service.dart
// PLACEHOLDER SERVICE - Will be fully implemented with proper l10n later
// This provides a structure for Gemini to work with

class LocalizationService {
  // Singleton pattern
  static final LocalizationService _instance = LocalizationService._internal();
  factory LocalizationService() => _instance;
  LocalizationService._internal();

  // Current language code (placeholder - will be managed by provider)
  String _currentLanguage = 'en';

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
    // --- App-wide ---
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
    'remove': 'Remove',
    'clear': 'Clear',
    'reset': 'Reset',
    'history': 'History',
    'saving': 'Saving...',
    'to': 'to',
    'from': 'From',
    'available': 'Available',
    'amount': 'Amount',
    'emoji': 'Emoji',
    'binder': 'Binder',

    // --- Home Screen ---
    'home_envelopes_tab': 'Envelopes',
    'home_groups_tab': 'Groups',
    'home_budget_tab': 'Budget',
    'home_calendar_tab': 'Calendar',
    'home_pay_day_button': 'PAY DAY',
    'home_no_envelopes': 'No envelopes yet',
    'home_create_first': 'Tap + to create your first envelope',
    'sort_by': 'Sort by',
    'sort_az': 'A-Z',
    'sort_balance': 'Highest Balance',
    'sort_target': 'Highest Target',
    'sort_percent': '% to Target',
    'cancel_selection': 'Cancel Selection',
    'calculator': 'Calculator',
    'calculator_tooltip': 'Open Calculator',
    'multi_select_mode': 'Enter Multi-Select Mode',

    // --- Envelopes ---
    'envelope_new': 'New Envelope',
    'envelope_create_button': 'Create Envelope',
    'envelope_name': 'Envelope Name',
    'envelope_target': 'Target Amount',
    'envelope_current': 'Current Amount',
    'envelope_delete_confirm': 'Delete envelope?',
    'envelope_view_history_tooltip': 'View full history',
    'envelope_return_current_month': 'Tap to return to current month',
    'envelope_in_binder': 'In Binder',
    'envelope_add_subtitle': 'Add subtitle',
    'envelope_subtitle_hint': 'e.g., "Weekly shopping"',
    'envelope_subtitle_optional': 'Subtitle (optional)',
    'envelope_starting_amount': 'Starting Amount (£)',
    'envelope_target_amount': 'Target Amount (£)',
    'envelope_add_to_binder': 'Add to Binder',
    'envelope_no_binder': 'No Binder',
    'envelope_enable_autofill': 'Enable Auto-Fill',
    'envelope_autofill_subtitle': 'Automatically add money on pay day',
    'envelope_autofill_amount': 'Auto-Fill Amount (£)',
    'envelope_autofill_helper': 'Amount to add each pay day',
    'envelope_schedule_payment': 'Schedule Payment',
    'envelope_add_recurring_payment': 'Add recurring payment',
    'envelope_recurring_payment_subtitle':
        'Set up a recurring payment after creating',
    'action_add_money': 'Add Money',
    'action_take_money': 'Take Money',
    'action_move_money': 'Move Money',
    'transfer_to_envelope': 'To Envelope',
    'description_optional': 'Description (optional)',

    // --- Groups / Binders ---
    'group_new': 'New Group',
    'group_new_binder': 'New Binder',
    'group_edit_binder': 'Edit Binder',
    'group_name': 'Group Name',
    'group_no_binders': 'No binders yet',
    'group_create_first_binder': 'Tap + to create your first binder',
    'group_create_binder': 'Create Binder',
    'group_create_binder_tooltip': 'Create new binder',
    'group_delete_binder': 'Delete Binder',
    'group_binders_title': 'Binders',
    'group_binder_total': 'Binder Total',
    'tap_again_for_details': 'Tap again for details',
    'group_history': 'History',
    'group_binder_color': 'Binder Color',
    'group_binder_name_label': 'Binder name',
    'group_pay_day_auto': 'Pay Day Auto-Fill',
    'group_pay_day_hint': 'Include in Pay Day preview',
    'group_assign_envelopes': 'Assign Envelopes:',
    'save_changes': 'Save Changes',

    // --- Budget Screen ---
    'budget_overview_title': 'Budget Overview',
    'budget_total_saved': 'Total Saved',
    'budget_target': 'Target',
    'budget_this_month': 'This Month',
    'budget_income': 'Income',
    'budget_spent': 'Spent',
    'budget_net_change': 'Net Change',
    'budget_envelope_progress': 'Envelope Progress',
    'budget_total_envelopes': 'Total Envelopes',
    'budget_with_targets': 'With Targets',
    'budget_fully_funded': 'Fully Funded',
    'budget_top_envelopes': 'Top 5 Envelopes',

    // --- Calendar Screen ---
    'calendar_title': 'Calendar',
    'calendar_today': 'Today',
    'calendar_add_payment_tooltip': 'Add Scheduled Payment',
    'calendar_month_view': 'Month View',
    'calendar_week_view': 'Week View',
    'calendar_no_payments_week': 'No payments in this week',
    'calendar_no_payments_month': 'No payments in this month',

    // --- Settings ---
    'settings_account': 'Account',
    'settings_display_name': 'Display Name',
    'settings_edit_display_name': 'Edit Display Name',
    'settings_display_name_hint': 'e.g., Sarah\'s Budget',
    'settings_email': 'Email',
    'settings_appearance': 'Appearance',
    'settings_workspace': 'Workspace',
    'settings_sign_out': 'Sign Out',
    'settings_section_profile': 'Profile',
    'settings_profile_photo': 'Profile Photo',
    'settings_tap_to_upload': 'Tap to upload',
    'settings_customize_appearance': 'Customize Appearance',
    'settings_appearance_subtitle': 'Theme, font, and celebration emoji',
    'settings_workspace_subtitle': 'Manage sharing, members & workspace',
    'settings_create_join_workspace': 'Create / Join Workspace',
    'settings_solo_mode': 'Currently in Solo Mode',
    'settings_logout_confirm': 'Logout?',
    'settings_logout_warning': 'Are you sure you want to logout?',
    'settings_section_help': 'FAQ / Help',
    'settings_faq': 'Frequently Asked Questions',
    'settings_section_support': 'Support',
    'settings_contact_us': 'Contact Us',
    'settings_app_version': 'App Version',

    // --- Appearance ---
    'appearance_theme': 'Theme',
    'appearance_change_theme_hint': 'Tap to change theme',
    'appearance_font': 'Font',
    'appearance_change_font_hint': 'Tap to change font',
    'appearance_choose_font': 'Choose Font',
    'appearance_celebration': 'Celebration',
    'appearance_target_emoji': 'Target Complete Emoji',
    'appearance_target_emoji_hint': 'Shows when envelope reaches 100%',
    'appearance_choose_emoji': 'Choose Celebration Emoji',
    'appearance_emoji_instructions':
        'Tap the box and select an emoji from your keyboard',
    'appearance_emoji_instructions_short': 'Select an emoji from your keyboard',
    'appearance_emoji_explanation':
        'This emoji will appear when any envelope reaches 100%',

    // --- Workspace ---
    'workspace_create': 'Create Workspace',
    'workspace_join': 'Join Workspace',
    'workspace_settings': 'Workspace Settings',
    'workspace_members': 'Members',
    'workspace_sharing': 'Sharing',
    'workspace_start_or_join': 'Start or Join Workspace',
    'workspace_creating': 'Creating...',
    'workspace_create_new': 'Create New Shared Workspace',
    'workspace_created_success': 'Workspace created. Share this code:',
    'workspace_join_existing': 'Or join an existing one:',
    'workspace_enter_code': 'Enter 6-digit Join Code',
    'workspace_joining': 'Joining...',
    'workspace_join_button': 'Join Workspace',
    'workspace_join_code_label': 'Join Code (immutable)',
    'workspace_display_name_optional': 'Display name (optional)',
    'workspace_display_name_hint': 'e.g. Team Love',
    'workspace_display_name_explanation':
        'Shown as "CODE (Display name)". Joining always uses CODE.',
    'workspace_name_updated': 'Workspace name updated.',
    'workspace_members_title': 'Workspace Members',
    'workspace_no_members': 'No members yet',
    'workspace_tab_sharing': 'Sharing',
    'workspace_tab_members': 'Members',
    'workspace_tab_workspace': 'Workspace',
    'workspace_my_envelopes': 'My Envelopes',
    'workspace_sharing_envelopes_subtitle':
        'Control which envelopes your partner can see',
    'workspace_visible_to_partner': 'Visible to partner',
    'workspace_hidden_from_partner': 'Hidden from partner',
    'workspace_my_binders': 'My Binders',
    'workspace_sharing_binders_subtitle':
        'Control which binders your partner can see',
    'workspace_you': 'You',
    'workspace_set_nickname_tooltip': 'Set nickname',
    'workspace_set_nickname_for': 'Set Nickname for',
    'workspace_nickname_privacy_note': 'This nickname is only visible to you.',
    'workspace_nickname': 'Nickname',
    'workspace_nickname_hint': 'e.g. Girl, Babe, Partner',
    'workspace_nickname_cleared': 'Nickname cleared',
    'workspace_nickname_saved': 'Nickname saved',
    'workspace_name_label': 'Workspace Name',
    'workspace_edit_details_tooltip': 'Edit workspace details',
    'workspace_leave_button': 'Leave',
    'workspace_leave_subtitle': 'Remove yourself from this workspace',
    'workspace_leave_confirm': 'Leave Workspace?',
    'workspace_leave_warning':
        'You will no longer see partner envelopes or be able to transfer money.\n\nYour envelopes and transaction history will remain intact.',
    'workspace_left_success': 'Left workspace successfully',
    'workspace_about_title': 'About Workspaces',
    'workspace_about_content':
        '• View and transfer money to partner\'s envelopes\n• Add partner envelopes to your Pay Day auto-fill\n• All your data stays with you when you leave\n• Transaction history is preserved for both members',
    'unknown_user': 'Unknown User',

    // --- Onboarding ---
    'onboarding_photo': 'Add a Profile Photo',
    'onboarding_photo_subtitle': 'Help your workspace members recognize you',
    'onboarding_choose_photo': 'Choose Photo',
    'onboarding_skip': 'Skip for now',
    'onboarding_display_name': 'What should we call you?',
    'onboarding_display_name_subtitle':
        'This name will appear in your workspace',
    'onboarding_theme': 'Pick Your Vibe',
    'onboarding_theme_subtitle': 'You can change this anytime in Settings',
    'onboarding_font': 'Choose Your Font',
    'onboarding_font_subtitle': 'This will be used throughout the app',
    'onboarding_language': 'Select Language',
    'onboarding_language_subtitle': 'Currently only English is supported',
    'language_english': 'English',
    'language_default': 'Default language',
    'onboarding_currency': 'Select Currency',
    'onboarding_currency_subtitle': 'Currently only GBP (£) is supported',
    'currency_gbp': 'British Pound (GBP)',
    'currency_default': 'Default currency',
    'onboarding_get_started': 'Get Started 🎉',

    // --- Errors & Success Messages ---
    'error_generic': 'Error',
    'error_required_field': 'This field is required',
    'error_invalid_amount': 'Please enter a valid amount',
    'error_no_email': 'No email found',
    'error_envelope_not_found': 'Envelope not found',
    'error_no_user_logged_in': 'No user logged in',
    'error_creating_workspace': 'Error creating workspace',
    'error_workspace_not_found': 'No workspace found for that code',
    'error_joining_workspace': 'Error joining workspace',
    'error_saving_name': 'Failed to save name',
    'error_saving_nickname': 'Failed to save nickname',
    'error_db_not_initialized': 'Database not initialized.',
    'error_invalid_starting_amount': 'Invalid starting amount',
    'error_invalid_target': 'Invalid target',
    'error_autofill_amount_required':
        'Please enter an auto-fill amount or disable auto-fill',
    'error_invalid_autofill': 'Invalid auto-fill amount',
    'error_creating_envelope': 'Error creating envelope',
    'error_select_target_envelope': 'Please select a target envelope',
    'error_enter_amount': 'Please enter an amount',
    'error_insufficient_funds': 'Insufficient funds in envelope',
    'error_enter_name': 'Please enter a name',

    'success_saved': 'Saved successfully',
    'success_updated': 'Updated successfully',
    'success_deleted': 'Deleted successfully',
    'success_display_name_updated': 'Display name updated',
    'success_joined_workspace': 'Joined workspace!',
    'success_signed_out': 'Signed out',
    'success_binder_updated': 'Binder updated!',
    'success_binder_created': 'Binder created!',
    'success_envelope_created': 'Envelope created successfully',
    'success_moved': 'Moved',

    'feature_coming_soon': 'Coming soon',
  };
}

// Helper function for quick access
String tr(String key) {
  return LocalizationService().getString(key);
}
