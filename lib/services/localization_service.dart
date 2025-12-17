// lib/services/localization_service.dart
class LocalizationService {
  static final LocalizationService _instance = LocalizationService._internal();
  factory LocalizationService() => _instance;
  LocalizationService._internal();

  String getString(String key) {
    return _englishStrings[key] ?? key;
  }

  String formatCurrency(double amount, {String? currencyCode}) {
    return '£${amount.toStringAsFixed(2)}';
  }

  static const Map<String, String> _englishStrings = {
    // --- APP WIDE ---
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
    'reset_default': 'Reset to Default',
    'history': 'History',
    'saving': 'Saving...',
    'unknown_user': 'Unknown User',
    'envelopes': 'Envelopes',
    'binders': 'Binders',
    'tap_again_for_details': 'Tap again for details',
    'save_changes': 'Save Changes',

    // --- DIALOGS ---
    'delete_envelopes_title': 'Delete Envelopes?',
    'delete_envelopes_confirm':
        'Are you sure you want to delete this many envelopes:',

    // --- HOME ---
    'home_envelopes_tab': 'Envelopes',
    'home_binders_tab': 'Binders',
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

    // --- ENVELOPES ---
    'envelope_new': 'New Envelope',
    'envelope_create_button': 'Create Envelope',
    'envelope_name': 'Envelope Name',
    'envelope_subtitle_optional': 'Subtitle (optional)',
    'envelope_subtitle_hint': 'e.g. "Weekly shopping"',
    'envelope_starting_amount': 'Starting Amount',
    'envelope_target_amount': 'Target Amount',
    'envelope_view_history_tooltip': 'View full history',
    'envelope_return_current_month': 'Tap to return to current month',
    'envelope_in_binder': 'In Binder',
    'envelope_add_to_binder': 'Add to Binder',
    'envelope_no_binder': 'No Binder',
    'envelope_enable_autofill': 'Enable Pay Day Auto-Fill',
    'envelope_autofill_subtitle': 'Automatically add money on pay day',
    'envelope_autofill_amount': 'Auto-Fill Amount',
    'envelope_autofill_helper': 'Amount to add each pay day',
    'envelope_schedule_payment': 'Schedule Payment',
    'envelope_add_recurring_payment': 'Add Scheduled Payment',
    'envelope_recurring_payment_subtitle':
        'Set up recurring deposits/withdrawals',
    'action_add_money': 'Add Money',
    'action_take_money': 'Take Money',
    'action_move_money': 'Move Money',

    // --- GROUPS ---
    'group_new': 'New Group',
    'group_new_binder': 'New Binder',
    'group_edit_binder': 'Edit Binder',
    'group_binder_name_label': 'Binder Name',
    'group_create_binder': 'Create Binder',
    'group_create_binder_tooltip': 'Create new binder',
    'group_delete_binder': 'Delete Binder',
    'group_binders_title': 'Binders',
    'group_no_binders': 'No binders yet',
    'group_create_first_binder': 'Tap + to create your first binder',
    'group_binder_total': 'Binder Total',
    'group_binder_color': 'Binder Color',
    'group_pay_day_auto': 'Pay Day Auto-Fill',
    'group_pay_day_hint': 'Include in Pay Day preview',
    'group_assign_envelopes': 'Assign Envelopes:',
    'group_history': 'History',

    // --- BUDGET ---
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
    'budget_top_envelopes': 'Top Envelopes',

    // --- CALENDAR ---
    'calendar_title': 'Calendar',
    'calendar_today': 'Today',
    'calendar_add_payment_tooltip': 'Add Scheduled Payment',
    'calendar_month_view': 'Month View',
    'calendar_week_view': 'Week View',
    'calendar_no_payments_week': 'No payments in this week',
    'calendar_no_payments_month': 'No payments in this month',

    // --- SETTINGS ---
    'settings_appearance': 'Appearance',
    'appearance_theme': 'Theme',
    'appearance_font': 'Font',
    'appearance_celebration': 'Celebration',
    'appearance_change_theme_hint': 'Tap to change theme',
    'appearance_change_font_hint': 'Tap to change font',
    'appearance_target_emoji': 'Target Emoji',
    'appearance_target_emoji_hint': 'Shows when envelope reaches 100%',
    'appearance_choose_emoji': 'Choose Emoji',
    'appearance_choose_font': 'Choose Font',
    'appearance_emoji_instructions': 'Tap circle to open keyboard',

    // --- WORKSPACE ---
    'workspace_settings': 'Workspace Settings',
    'workspace_start_or_join': 'Start or Join Workspace',
    'workspace_create_new': 'Create New Shared Workspace',
    'workspace_join_existing': 'Or join an existing one:',
    'workspace_enter_code': 'Enter 6-digit Join Code',
    'workspace_join_button': 'Join Workspace',
    'workspace_join_code_label': 'Join Code (immutable)',
    'workspace_display_name_optional': 'Display name (optional)',
    'workspace_display_name_hint': 'e.g. Team Love',
    'workspace_display_name_explanation':
        'Shown as "CODE (Display name)". Joining always uses CODE.',
    'workspace_name_updated': 'Workspace name updated.',
    'workspace_members_title': 'Members',
    'workspace_no_members': 'No members yet',
    'workspace_tab_sharing': 'Sharing',
    'workspace_tab_members': 'Members',
    'workspace_tab_workspace': 'Workspace',
    'workspace_my_envelopes': 'My Envelopes',
    'workspace_my_binders': 'My Binders',
    'workspace_visible_to_partner': 'Visible to partner',
    'workspace_hidden_from_partner': 'Hidden from partner',
    'workspace_sharing_setup': 'Sharing Setup',
    'workspace_select_to_hide': 'Select envelopes/binders to HIDE (Private):',
    'workspace_create_confirm': 'Create & Share',
    'workspace_join_confirm': 'Join & Share',
    'workspace_hide_future': 'Hide future envelopes by default',
    'workspace_you': 'You',
    'workspace_set_nickname_tooltip': 'Set Nickname',
    'workspace_set_nickname_for': 'Set Nickname for',
    'workspace_nickname': 'Nickname',
    'workspace_nickname_hint': 'e.g. Partner',
    'workspace_nickname_privacy_note': 'Only you will see this nickname.',
    'workspace_nickname_cleared': 'Nickname cleared',
    'workspace_nickname_saved': 'Nickname saved',
    'workspace_leave_button': 'Leave Workspace',
    'workspace_leave_confirm': 'Leave Workspace?',
    'workspace_leave_warning':
        'Are you sure? You will lose access to shared items.',
    'workspace_left_success': 'Left workspace',
    'workspace_about_title': 'About',
    'workspace_about_content':
        'Workspaces allow you to share envelopes and budgets with a partner.',

    // --- ERRORS & MESSAGES ---
    'error_generic': 'Error',
    'error_required_field': 'This field is required',
    'error_enter_name': 'Please enter a name',
    'error_invalid_amount': 'Please enter a valid amount',
    'error_invalid_starting_amount': 'Invalid starting amount',
    'error_invalid_target': 'Invalid target amount',
    'error_autofill_amount_required': 'Auto-fill amount is required',
    'error_invalid_autofill': 'Invalid auto-fill amount',
    'error_creating_workspace': 'Error creating workspace',
    'error_creating_envelope': 'Error creating envelope',
    'error_workspace_not_found': 'Workspace not found',
    'error_joining_workspace': 'Error joining workspace',
    'error_saving_name': 'Error saving name',
    'error_saving_nickname': 'Error saving nickname',
    'error_no_user_logged_in': 'No user logged in',
    'success_binder_updated': 'Binder updated successfully',
    'success_binder_created': 'Binder created successfully',
    'success_envelope_created': 'Envelope created successfully',
  };
}

String tr(String key, {List<String>? args}) {
  String text = LocalizationService().getString(key);
  if (args != null && args.isNotEmpty) {
    return "$text ${args.join(' ')}";
  }
  return text;
}
