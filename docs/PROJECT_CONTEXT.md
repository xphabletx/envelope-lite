Envelope Lite: Project Context & Architecture
1. Project Overview
App Name: Envelope Lite (Team Envelopes)

Core Concept: Zero-based budgeting app using "Envelopes" (categories) and "Binders" (Groups).

Unique Selling Point: Hybrid Solo vs. Workspace mode. Users manage personal budgets but can join a "Workspace" to share specific envelopes/binders with a partner.

Tech Stack: Flutter (Dart).

Backend: Firebase Firestore (NoSQL) + Firebase Auth.

State Management: Provider pattern (ChangeNotifiers: ThemeProvider, FontProvider, AppPreferencesProvider).

2. Architecture & Data Flow
Repository Pattern: UI components never call Firestore directly. They must go through:

EnvelopeRepo: Handles Envelopes, Transactions, and Workspace logic.

GroupRepo: Handles Binders (Groups).

ScheduledPaymentRepo: Handles recurring calendar items.

Stream-Based UI: The app relies heavily on StreamBuilder listening to Repo streams for real-time updates.

Theming: Dynamic theming (colors, fonts) is handled via ThemeProvider and FontProvider. All text widgets should use fontProvider.getTextStyle() rather than hardcoded styles.

3. Key Feature Logic
Workspaces (The "Gate")

Logic: EnvelopeRepo contains a _workspaceId.

If null: Repo reads from users/{uid}/solo.

If set: Repo reads from workspaces/{workspaceId}.

Sharing: Envelopes and Groups have an isShared boolean. Even in a workspace, a user can mark an item as private (hidden from partner).

Registry: A high-level collection workspaces/{id}/registry is used to track envelope balances quickly without reading full user sub-collections.

Pay Day Engine

Location: pay_day_preview_screen.dart

Logic:

User selects envelopes/binders to "fill".

App calculates autoFillAmount (set on the Envelope model).

User confirms -> App creates TransactionType.deposit records for every selected envelope in a batch write.

Updates currentAmount on envelopes.

Scheduling

Location: calendar_screen_v2.dart & scheduled_payment_repo.dart

Logic: Payments are stored in a separate collection. The calendar calculates "Occurrences" based on frequency (Weekly, Monthly, etc.) to display dots on the UI.

Auto-Execution: (Planned feature) The system checks if a scheduled payment is due and isAutomatic, then triggers a transaction.

4. File-by-File Breakdown
Core (Root)

lib/main.dart: Entry point. Initializes Firebase, sets up MultiProvider, and uses AuthGate to route to Login or Home.

lib/firebase_options.dart: Auto-generated configuration. Do not edit.

Models (lib/models/)

envelope.dart: Core budget item. Contains currentAmount, targetAmount, autoFillAmount, and isShared.

envelope_group.dart: "Binder". Groups envelopes. Contains colorName and payDayEnabled.

transaction.dart: Represents money movement. Types: deposit, withdrawal, transfer.

scheduled_payment.dart: Recurrence rules for calendar items.

user_profile.dart: User metadata (display name, selected theme, onboarding status).

Services & Repositories (lib/services/)

envelope_repo.dart: CRITICAL. The brain of the app. Handles CRUD for envelopes/transactions. Manages the switch between "Solo" and "Workspace" paths.

group_repo.dart: CRUD for Binders.

auth_service.dart: Wraps Firebase Auth (Google & Email/Password).

workspace_helper.dart: Static utilities for managing workspace preferences (SharedPrefs) and member lookup.

migration_manager.dart / run_migrations_once.dart: System to backfill data structures (e.g., adding ownerId to old documents) on app start.

localization_service.dart: Dictionary for app strings (currently English only).

Providers (lib/providers/)

theme_provider.dart: Manages color themes (Latte, Blush, etc.). Persists to Firebase user profile.

font_provider.dart: Manages Google Fonts selection. Persists to SharedPreferences.

app_preferences_provider.dart: Manages local settings like currency and celebration emojis.

Screens - Core

home_screen.dart: Dashboard. Contains the _AllEnvelopes list, FAB (Speed Dial), and navigation logic.

sign_in_screen.dart: Login UI. Includes a complex bottom sheet for "Create Account".

settings_screen.dart: Menu linking to Profile, Appearance, Workspace, etc.

onboarding_flow.dart: 6-step wizard for new users (Photo, Name, Theme, Font, Language, Currency).

Screens - Features

groups_home_screen.dart: The "Binder" view. Renders the visual "Open Folder" UI (_BinderSpread).

group_detail_screen.dart: Inside a specific binder. Shows detailed stats and transaction history for that group.

budget_screen.dart: High-level dashboard showing "Net Worth" (Total Saved vs Target) and Income vs Expense.

calendar_screen_v2.dart: Calendar view of Scheduled Payments.

pay_day_preview_screen.dart: The "Pay Day" mechanics. Lists all auto-fill envelopes and executes batch deposits.

stats_history_screen.dart: Advanced filtering. Allows user to select specific envelopes/groups and date ranges to see a ledger.

workspace_gate.dart: UI for Creating or Joining a workspace via 6-digit code.

workspace_settings_screen.dart: Manage members, renaming, and granular privacy toggles (sharing specific binders/envelopes).

Screens - Envelope Specific (lib/screens/envelope/)

envelopes_detail_screen.dart: The view when you tap an envelope. Shows the 3D envelope card, transaction list, and quick actions.

envelope_settings_sheet.dart: Form to edit envelope name, target, auto-fill, and binder assignment.

envelope_header_card.dart: The visual "3D" envelope component using CustomPainter.

envelope_transaction_list.dart: Displays transactions grouped by date (Today, Yesterday, etc.).

Widgets (lib/widgets/)

calculator_widget.dart: A draggable, floating calculator overlay.

Logic: Custom stateful widget with arithmetic logic. Includes a "minimized" state. Contains specific error suppression logic to handle layout overflows during animations.

envelope_tile.dart: The main list item for Envelopes.

Features: Displays balance and EmojiPieChart. Handles "Swipe to Reveal" actions (Add/Spend/Transfer) triggering QuickActionModal. Supports Multi-select mode.

quick_action_modal.dart: A unified modal for Deposit, Withdrawal, and Transfer transactions. Used primarily by the swipe actions on EnvelopeTile.

envelope_creator.dart: Bottom sheet form for creating Envelopes. Handles validation, binder assignment, and chaining into AddScheduledPaymentScreen.

group_editor.dart: Bottom sheet form for creating/editing Binders (Groups). Handles color picking and assigning envelopes to the group.

emoji_pie_chart.dart: Visual progress indicator. Renders a pie chart using CustomPainter or a "Celebration Emoji" (from AppPreferencesProvider) when at 100%.

partner_visibility_toggle.dart: The toggle switch used on Home and Group screens to filter partner data. Persists state via WorkspaceHelper.

partner_badge.dart: Simple visual chip to label envelopes/binders owned by other workspace members.

emoji_picker_button.dart: A UI wrapper that triggers the native system Emoji Keyboard via a hidden TextField but displays results in a custom dialog.

Cleanup & Maintenance Report
This is a consolidated list of areas identified for future cleanup or refactoring.

lib/screens/home_screen.dart: The SpeedDialChild sdChild(...) function sits globally outside the class. Action: Move inside _HomeScreenState.

lib/screens/sign_in_screen.dart: _openCreateAccountSheet is a massive 160-line logic block inside the UI. Action: Refactor or add documentation header.

lib/screens/pay_day_preview_screen.dart: _initializeState contains complex unchecked logic regarding binder/envelope relationships. Action: Add documentation explaining why binders are auto-selected.

lib/screens/stats_history_screen.dart: _getUserNamesForTransaction is a hidden helper method doing async lookups. Action: Add docstring.

lib/screens/calendar_screen_v2.dart: _getOccurrencesInRange contains critical "magic logic" for date recursion. Action: Add documentation header.

lib/screens/groups_home_screen.dart: Contains // FIX: Removed dead code check comment. Action: Remove the comment to clean up the code.

lib/screens/workspace_gate.dart: Hardcoded exclusion string for code generation. Action: Comment why (I, O, 1, 0 are excluded for readability).

lib/main.dart: AuthGate contains a comment // Bypass onboarding check. Action: Verify if Onboarding is live; if so, remove comment and implement check.

lib/screens/settings_screen.dart: onTap for "Display Name" contains significant inline logic. Action: Extract to _editDisplayName method.

lib/widgets/calculator_widget.dart: Uses FlutterError.onError to suppress layout overflow errors. Action: Tag as technical debt; fix layout constraints eventually.

lib/widgets/envelope_tile.dart: Uses hardcoded layout math (_actionButtonsWidth = 164.0) for swipe animations. Action: Add comment warning that changing button size requires updating this constant.

Redundant Modals: QuickActionModal (in Widgets) duplicates logic found in DepositModal, WithdrawModal, etc. (in Screens). Action: Long-term refactor to use a single modal system.