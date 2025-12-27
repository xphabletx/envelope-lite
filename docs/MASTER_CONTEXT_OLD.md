# Envelope Lite - Master Context Documentation

## Project Overview

**Envelope Lite** is a Flutter-based budgeting application that implements the envelope budgeting methodology. Users can create virtual envelopes to allocate funds, manage accounts, track transactions, and project their financial future with scheduled payments and pay day automation.

**Architecture Style**: Clean Architecture with Repository Pattern, Provider State Management, and Firebase Backend
**Platform**: Flutter (iOS, Android, macOS)
**Backend**: Firebase (Authentication, Firestore, Cloud Functions)

---

## Table of Contents

1. [Directory Structure](#directory-structure)
2. [Core Models (Data Layer)](#core-models-data-layer)
3. [Services (Business Logic Layer)](#services-business-logic-layer)
4. [Providers (State Management)](#providers-state-management)
5. [Screens (UI Pages)](#screens-ui-pages)
6. [Widgets (Reusable Components)](#widgets-reusable-components)
7. [Data & Resources](#data--resources)
8. [Theme & Styling](#theme--styling)
9. [Utilities](#utilities)
10. [Application Entry Point](#application-entry-point)
11. [Data Flow Architecture](#data-flow-architecture)
12. [Key Architectural Patterns](#key-architectural-patterns)
13. [Firebase Structure](#firebase-structure)

---

## Directory Structure

```
lib/
├── main.dart                           # Application entry point
├── firebase_options.dart               # Firebase configuration
│
├── data/                               # Static reference data
├── models/                             # Domain models
├── providers/                          # State management (Provider)
├── services/                           # Business logic & Firebase repos
├── theme/                              # Theme definitions
├── utils/                              # Helper functions
├── screens/                            # Full-page UI components
└── widgets/                            # Reusable UI components
```

---

## Core Models (Data Layer)

**Location**: `lib/models/`

Models represent the core domain objects with Firebase serialization/deserialization methods.

### [account.dart](lib/models/account.dart)
**Purpose**: Represents a financial account (bank account, cash, credit card)

**Key Properties**:
- `id`: Unique identifier
- `name`: Account display name
- `balance`: Current balance
- `isShared`: Workspace collaboration flag
- `workspaceId`: Associated workspace
- Icon system: supports emoji, material icons, or company logos (via favicon)

**Methods**:
- `toFirestore()`: Serializes to Firestore document
- `fromFirestore()`: Deserializes from Firestore
- `getIconWidget()`: Returns appropriate icon widget based on icon type

**Links To**:
- Used by [account_repo.dart](lib/services/account_repo.dart) for CRUD operations
- Displayed in [account_card.dart](lib/widgets/accounts/account_card.dart)
- Managed in [account_list_screen.dart](lib/widgets/accounts/account_list_screen.dart)
- Referenced by [envelope.dart](lib/models/envelope.dart) for account linking

---

### [envelope.dart](lib/models/envelope.dart)
**Purpose**: Core budget envelope entity representing a spending category

**Key Properties**:
- `id`, `name`, `amount`: Basic envelope data
- `accountId`: Linked account
- `target`: Goal amount for envelope
- `targetByDate`: Deadline for target
- `autoFill`: Auto-allocation settings
- `isShared`: Workspace collaboration flag
- `workspaceId`: Associated workspace
- Icon system: emoji (legacy) + new icon system (emoji, material, company logo)

**Methods**:
- `toFirestore()`, `fromFirestore()`: Firebase serialization
- `copyWith()`: Immutable update helper
- `getIconWidget()`: Icon display with fallback logic
- `getDisplayName()`: Returns name with fallback to "Unnamed Envelope"

**Links To**:
- Managed by [envelope_repo.dart](lib/services/envelope_repo.dart)
- Displayed in [envelope_tile.dart](lib/widgets/envelope_tile.dart)
- Detail view: [envelopes_detail_screen.dart](lib/screens/envelope/envelopes_detail_screen.dart)
- Created via [envelope_creator.dart](lib/widgets/envelope_creator.dart)
- Used in projections by [projection_service.dart](lib/services/projection_service.dart)

---

### [transaction.dart](lib/models/transaction.dart)
**Purpose**: Records financial transactions (deposits, withdrawals, transfers)

**Key Properties**:
- `id`, `userId`, `envelopeId`: Transaction identifiers
- `type`: 'deposit', 'withdraw', 'transfer'
- `amount`: Transaction amount
- `note`: Optional description
- `timestamp`: Server timestamp
- `transferToEnvelopeId`, `transferToWorkspaceId`: Transfer metadata
- `linkedTransactionId`: Links related transfers

**Methods**:
- `toFirestore()`, `fromFirestore()`: Firebase serialization
- Validation: transfer type requires both 'from' and 'to' envelopes

**Links To**:
- Created by [envelope_repo.dart](lib/services/envelope_repo.dart) during operations
- Displayed in [envelope_transaction_list.dart](lib/screens/envelope/envelope_transaction_list.dart)
- Used for calculating envelope balances

---

### [envelope_group.dart](lib/models/envelope_group.dart)
**Purpose**: Groups envelopes into categories (e.g., "Housing", "Entertainment")

**Key Properties**:
- `id`, `name`: Group identifiers
- `envelopeIds`: List of envelope IDs in group
- `isEnabledForPayDay`: Include in pay day auto-allocation
- `orderIndex`: Display order

**Methods**:
- `toFirestore()`, `fromFirestore()`: Firebase serialization

**Links To**:
- Managed by [group_repo.dart](lib/services/group_repo.dart)
- Used in [groups_home_screen.dart](lib/screens/groups_home_screen.dart)
- Edited via [group_editor.dart](lib/widgets/group_editor.dart)
- Referenced in pay day allocation flow

---

### [scheduled_payment.dart](lib/models/scheduled_payment.dart)
**Purpose**: Recurring bills or income

**Key Properties**:
- `id`, `name`, `amount`: Payment details
- `frequency`: 'weekly', 'biweekly', 'monthly', 'yearly'
- `nextDueDate`: Next occurrence
- `envelopeId`: Target envelope for auto-payment
- `isIncome`: Flag for income vs expense

**Methods**:
- `toFirestore()`, `fromFirestore()`: Firebase serialization

**Links To**:
- Managed by [scheduled_payment_repo.dart](lib/services/scheduled_payment_repo.dart)
- Used by [projection_service.dart](lib/services/projection_service.dart) for forecasting
- Displayed in [scheduled_payments_list_screen.dart](lib/widgets/budget/scheduled_payments_list_screen.dart)

---

### [projection.dart](lib/models/projection.dart)
**Purpose**: Data structures for financial projections and forecasting

**Key Classes**:
- `ProjectionResult`: Complete projection with account/envelope balances over time
- `AccountProjection`: Account balance at specific point in time
- `EnvelopeProjection`: Envelope balance at specific point in time
- `ProjectionEvent`: Single event (pay day, scheduled payment, auto-fill)
- `ProjectionScenario`: What-if scenario with temporary envelopes
- `TemporaryEnvelope`: Hypothetical envelope for scenario modeling

**Methods**: Serialization and date-based lookups

**Links To**:
- Generated by [projection_service.dart](lib/services/projection_service.dart)
- Visualized in [projection_tool.dart](lib/widgets/budget/projection_tool.dart)
- Used in [budget_screen.dart](lib/screens/budget_screen.dart)

---

### [pay_day_settings.dart](lib/models/pay_day_settings.dart)
**Purpose**: Configuration for pay day automation

**Key Properties**:
- `frequency`: 'weekly', 'biweekly', 'monthly', 'custom'
- `nextPayDay`: Next pay day date
- `defaultAmount`: Default pay amount
- `defaultAccountId`: Source account for pay
- `customSchedule`: List of custom pay dates

**Methods**:
- `toFirestore()`, `fromFirestore()`: Firebase serialization

**Links To**:
- Used in [pay_day_allocation_screen.dart](lib/screens/pay_day/pay_day_allocation_screen.dart)
- Managed in user profile settings

---

### [user_profile.dart](lib/models/user_profile.dart)
**Purpose**: User settings and preferences

**Key Properties**:
- `userId`, `email`, `displayName`, `photoUrl`: User identity
- `selectedThemeId`: Current theme selection
- `selectedFontFamily`: Font preference
- `onboardingCompleted`: Onboarding state
- `tutorialStepsCompleted`: Tutorial progress
- `celebrationEmoji`: Preferred celebration emoji
- `languageCode`, `currencyCode`: Localization settings

**Methods**:
- `toFirestore()`, `fromFirestore()`: Firebase serialization
- `copyWith()`: Immutable update helper

**Links To**:
- Managed by [user_service.dart](lib/services/user_service.dart)
- Used in [settings_screen.dart](lib/screens/settings_screen.dart)
- Synced with [theme_provider.dart](lib/providers/theme_provider.dart)

---

## Services (Business Logic Layer)

**Location**: `lib/services/`

Services encapsulate business logic and Firebase operations using the Repository pattern.

### [envelope_repo.dart](lib/services/envelope_repo.dart)
**Purpose**: Main repository for envelope CRUD and transaction operations

**Key Methods**:
- `envelopesStream()`: Real-time stream of user's envelopes (solo + workspace)
- `createEnvelope()`: Create new envelope
- `updateEnvelope()`: Update envelope properties
- `deleteEnvelope()`: Delete envelope and its transactions
- `deposit()`: Add funds to envelope
- `withdraw()`: Remove funds from envelope (with balance validation)
- `transfer()`: Move funds between envelopes (creates linked transactions)
- `batchUpdateEnvelopes()`: Bulk updates for pay day allocation

**Workspace Support**:
- Reads from both `users/{userId}/solo/data/envelopes` and workspace registries
- Uses `CombineLatestStream` to merge solo and workspace envelopes
- Maintains ownership metadata for transfer operations

**Links To**:
- Uses [envelope.dart](lib/models/envelope.dart) and [transaction.dart](lib/models/transaction.dart)
- Called by screens: [envelopes_detail_screen.dart](lib/screens/envelope/envelopes_detail_screen.dart), [home_screen.dart](lib/screens/home_screen.dart)
- Called by modals: [deposit_modal.dart](lib/screens/envelope/modals/deposit_modal.dart), [withdraw_modal.dart](lib/screens/envelope/modals/withdraw_modal.dart), [transfer_modal.dart](lib/screens/envelope/modals/transfer_modal.dart)

---

### [account_repo.dart](lib/services/account_repo.dart)
**Purpose**: Repository for account management

**Key Methods**:
- `accountsStream()`: Real-time stream of user's accounts
- `createAccount()`: Create new account
- `updateAccount()`: Update account properties
- `deleteAccount()`: Delete account (validates no linked envelopes first)
- `getLinkedEnvelopes()`: Find all envelopes linked to an account
- `calculateTotalAssigned()`: Sum of all envelope amounts for account

**Workspace Support**: Similar to envelope_repo with solo/workspace modes

**Links To**:
- Uses [account.dart](lib/models/account.dart)
- Called by [account_list_screen.dart](lib/widgets/accounts/account_list_screen.dart)
- Referenced by [envelope_repo.dart](lib/services/envelope_repo.dart) for account linking
- Used in [account_detail_screen.dart](lib/screens/accounts/account_detail_screen.dart)

---

### [projection_service.dart](lib/services/projection_service.dart)
**Purpose**: Financial projection and forecasting engine

**Key Methods**:
- `generateProjection()`: Create projection from current state
- `applyScenario()`: Apply what-if scenario to projection
- `calculateEvents()`: Generate timeline of future events (pay days, scheduled payments)
- Helper methods for date calculations and balance updates

**Algorithm**:
1. Loads current accounts, envelopes, scheduled payments, pay day settings
2. Generates timeline of future events (pay days, scheduled payments, auto-fills)
3. Simulates each event chronologically, updating balances
4. Returns `ProjectionResult` with snapshots at each event

**Links To**:
- Uses [projection.dart](lib/models/projection.dart), [envelope.dart](lib/models/envelope.dart), [account.dart](lib/models/account.dart)
- Called by [budget_screen.dart](lib/screens/budget_screen.dart)
- Visualized in [projection_tool.dart](lib/widgets/budget/projection_tool.dart)

---

### [user_service.dart](lib/services/user_service.dart)
**Purpose**: User profile management

**Key Methods**:
- `userProfileStream()`: Real-time stream of user profile
- `getUserProfile()`: Fetch user profile once
- `createUserProfile()`: Create profile for new user
- `updateUserProfile()`: Update profile fields
- `markOnboardingComplete()`: Complete onboarding
- `updateTutorialStep()`: Track tutorial progress

**Links To**:
- Uses [user_profile.dart](lib/models/user_profile.dart)
- Called by [auth_service.dart](lib/services/auth_service.dart) on signup
- Used in [settings_screen.dart](lib/screens/settings_screen.dart)
- Synced with providers for theme/font/preferences

---

### [auth_service.dart](lib/services/auth_service.dart)
**Purpose**: Firebase authentication

**Key Methods**:
- `signInWithGoogle()`: Google Sign-In flow
- `signInWithEmailAndPassword()`: Email/password auth
- `signUpWithEmailAndPassword()`: Create new account
- `signOut()`: Sign out user
- `currentUser`: Stream of current user

**Links To**:
- Creates user profile via [user_service.dart](lib/services/user_service.dart)
- Used in [sign_in_screen.dart](lib/screens/sign_in_screen.dart)
- Auth gate in [main.dart](lib/main.dart) listens to auth state

---

### [group_repo.dart](lib/services/group_repo.dart)
**Purpose**: Envelope group management

**Key Methods**:
- `groupsStream()`: Real-time stream of groups
- `createGroup()`: Create new group
- `updateGroup()`: Update group properties
- `deleteGroup()`: Delete group
- `addEnvelopeToGroup()`, `removeEnvelopeFromGroup()`: Manage membership

**Links To**:
- Uses [envelope_group.dart](lib/models/envelope_group.dart)
- Called by [groups_home_screen.dart](lib/screens/groups_home_screen.dart)
- Used in [group_editor.dart](lib/widgets/group_editor.dart)

---

### [scheduled_payment_repo.dart](lib/services/scheduled_payment_repo.dart)
**Purpose**: Scheduled payment CRUD

**Key Methods**:
- `scheduledPaymentsStream()`: Real-time stream
- `createScheduledPayment()`: Create new scheduled payment
- `updateScheduledPayment()`: Update payment
- `deleteScheduledPayment()`: Delete payment

**Links To**:
- Uses [scheduled_payment.dart](lib/models/scheduled_payment.dart)
- Used by [projection_service.dart](lib/services/projection_service.dart)
- Managed in [add_scheduled_payment_screen.dart](lib/screens/add_scheduled_payment_screen.dart)

---

### [auto_payment_service.dart](lib/services/auto_payment_service.dart)
**Purpose**: Automatic payment execution

**Key Methods**:
- `processScheduledPayments()`: Execute due payments
- `calculateNextDueDate()`: Compute next occurrence based on frequency

**Links To**:
- Uses [scheduled_payment_repo.dart](lib/services/scheduled_payment_repo.dart)
- Uses [envelope_repo.dart](lib/services/envelope_repo.dart) to execute withdrawals

---

### [workspace_helper.dart](lib/services/workspace_helper.dart)
**Purpose**: Workspace collaboration utilities

**Key Methods**:
- `getWorkspaceContext()`: Determine if operating in workspace mode
- `getWorkspaceRegistryPath()`: Get Firestore path for workspace registry

**Links To**:
- Used by [envelope_repo.dart](lib/services/envelope_repo.dart) and [account_repo.dart](lib/services/account_repo.dart)
- Supports multi-tenant envelope sharing

---

### [tutorial_controller.dart](lib/services/tutorial_controller.dart)
**Purpose**: Tutorial overlay state management

**Key Methods**:
- `showTutorial()`: Display tutorial step
- `completeTutorialStep()`: Mark step as complete
- `resetTutorial()`: Start over

**Links To**:
- Used in [tutorial_overlay.dart](lib/widgets/tutorial_overlay.dart)
- Synced with [user_profile.dart](lib/models/user_profile.dart)

---

### [account_security_service.dart](lib/services/account_security_service.dart)
**Purpose**: Security features for accounts (PIN, biometric)

**Links To**: Account security features (future implementation)

---

### [localization_service.dart](lib/services/localization_service.dart)
**Purpose**: Localization and internationalization utilities

**Links To**: Used for currency/language formatting

---

### [migration_manager.dart](lib/services/migration_manager.dart) & [run_migrations_once.dart](lib/services/run_migrations_once.dart)
**Purpose**: Data migration utilities

**Key Methods**:
- `runMigrations()`: Execute one-time data migrations
- Used for schema updates and data transformations

**Links To**: Called in [home_screen.dart](lib/screens/home_screen.dart) on first load

---

### [icon_search_service_unlimited.dart](lib/services/icon_search_service_unlimited.dart)
**Purpose**: Icon search functionality for icon picker

**Links To**: Used in [omni_icon_picker_modal.dart](lib/widgets/envelope/omni_icon_picker_modal.dart)

---

## Providers (State Management)

**Location**: `lib/providers/`

Providers manage global application state using the Provider package (`ChangeNotifier`).

### [theme_provider.dart](lib/providers/theme_provider.dart)
**Purpose**: Manages selected theme

**Key Properties**:
- `selectedThemeId`: Current theme ID ('latte', 'blush', 'lavender', 'mint', 'mono', 'singularity')
- `currentTheme`: ThemeData object

**Key Methods**:
- `selectTheme()`: Change theme (syncs to Firebase and SharedPreferences)
- `syncWithUserProfile()`: Load theme from user profile

**Links To**:
- Uses [app_themes.dart](lib/theme/app_themes.dart)
- Used in [main.dart](lib/main.dart) via `Consumer<ThemeProvider>`
- Managed in [theme_picker_screen.dart](lib/screens/theme_picker_screen.dart)

---

### [font_provider.dart](lib/providers/font_provider.dart)
**Purpose**: Manages selected font family

**Key Properties**:
- `selectedFontFamily`: 'Caveat', 'Indie Flower', 'Roboto', 'Open Sans', 'System Default'
- `googleFontTextStyle`: Google Fonts text style

**Key Methods**:
- `selectFont()`: Change font (syncs to Firebase)
- `syncWithUserProfile()`: Load font from user profile

**Links To**:
- Uses `google_fonts` package
- Applied in [main.dart](lib/main.dart) theme
- Managed in [appearance_settings_screen.dart](lib/screens/appearance_settings_screen.dart)

---

### [app_preferences_provider.dart](lib/providers/app_preferences_provider.dart)
**Purpose**: Manages app-wide preferences

**Key Properties**:
- `celebrationEmoji`: Emoji for celebrations
- `languageCode`: Selected language
- `currencyCode`: Selected currency

**Key Methods**:
- `setCelebrationEmoji()`, `setLanguage()`, `setCurrency()`: Update preferences
- `syncWithUserProfile()`: Load from user profile

**Links To**:
- Used in [settings_screen.dart](lib/screens/settings_screen.dart)

---

### [locale_provider.dart](lib/providers/locale_provider.dart)
**Purpose**: Localization state

**Links To**: Used for internationalization

---

## Screens (UI Pages)

**Location**: `lib/screens/`

Screens are full-page UI components representing different routes.

### [main.dart](lib/main.dart) → MyApp → AuthGate
**Purpose**: Application root and authentication routing

**Navigation Flow**:
1. Listens to Firebase auth state
2. If not authenticated → [sign_in_screen.dart](lib/screens/sign_in_screen.dart)
3. If authenticated but no profile/onboarding incomplete → [onboarding_flow.dart](lib/screens/onboarding/onboarding_flow.dart)
4. If authenticated and onboarded → HomeScreenWrapper → [home_screen.dart](lib/screens/home_screen.dart)

---

### [home_screen.dart](lib/screens/home_screen.dart)
**Purpose**: Main navigation hub with tab bar

**Tabs**:
1. **Envelopes**: List of envelopes with search and filtering
2. **Accounts**: Link to [account_list_screen.dart](lib/widgets/accounts/account_list_screen.dart)
3. **Calendar**: Link to [calendar_screen.dart](lib/screens/calendar_screen.dart)
4. **Budget**: Link to [budget_screen.dart](lib/screens/budget_screen.dart)
5. **Stats/History**: Link to [stats_history_screen.dart](lib/screens/stats_history_screen.dart)

**Features**:
- Speed dial FAB for creating envelopes, accounts, groups, scheduled payments
- StreamBuilder for real-time envelope updates
- Group filtering
- Search functionality
- Settings navigation

**Links To**:
- Receives repos: [envelope_repo.dart](lib/services/envelope_repo.dart), [account_repo.dart](lib/services/account_repo.dart), [group_repo.dart](lib/services/group_repo.dart)
- Displays [envelope_tile.dart](lib/widgets/envelope_tile.dart) for each envelope
- Navigates to [envelopes_detail_screen.dart](lib/screens/envelope/envelopes_detail_screen.dart)

---

### [sign_in_screen.dart](lib/screens/sign_in_screen.dart)
**Purpose**: Authentication UI

**Features**:
- Google Sign-In button
- Email/password login
- Sign up flow

**Links To**:
- Uses [auth_service.dart](lib/services/auth_service.dart)

---

### [settings_screen.dart](lib/screens/settings_screen.dart)
**Purpose**: User settings and preferences

**Options**:
- Profile editing
- Theme selection → [theme_picker_screen.dart](lib/screens/theme_picker_screen.dart)
- Appearance → [appearance_settings_screen.dart](lib/screens/appearance_settings_screen.dart)
- Workspace settings → [workspace_settings_screen.dart](lib/screens/workspace_settings_screen.dart)
- Tutorial reset
- Sign out

**Links To**:
- Uses [user_service.dart](lib/services/user_service.dart)
- Uses providers: [theme_provider.dart](lib/providers/theme_provider.dart), [font_provider.dart](lib/providers/font_provider.dart)

---

### [budget_screen.dart](lib/screens/budget_screen.dart)
**Purpose**: Budget overview and projection tool

**Features**:
- Budget summary cards via [overview_cards.dart](lib/widgets/budget/overview_cards.dart)
- Projection timeline visualization via [projection_tool.dart](lib/widgets/budget/projection_tool.dart)
- Scenario editor via [scenario_editor_modal.dart](lib/widgets/budget/scenario_editor_modal.dart)
- Auto-fill settings via [auto_fill_list_screen.dart](lib/widgets/budget/auto_fill_list_screen.dart)

**Links To**:
- Uses [projection_service.dart](lib/services/projection_service.dart)
- Uses [projection.dart](lib/models/projection.dart)

---

### [calendar_screen.dart](lib/screens/calendar_screen.dart)
**Purpose**: Calendar view of scheduled payments and pay days

**Features**:
- Table calendar widget
- Event markers for scheduled payments
- Pay day highlighting

**Links To**:
- Uses [scheduled_payment_repo.dart](lib/services/scheduled_payment_repo.dart)
- Uses `table_calendar` package

---

### [stats_history_screen.dart](lib/screens/stats_history_screen.dart)
**Purpose**: Historical data and statistics

**Features**:
- Transaction history
- Spending trends
- Charts via `fl_chart` package

**Links To**:
- Uses [envelope_repo.dart](lib/services/envelope_repo.dart) for transaction history

---

### [groups_home_screen.dart](lib/screens/groups_home_screen.dart)
**Purpose**: Group management interface

**Features**:
- List of envelope groups
- Create/edit/delete groups
- Navigate to [group_detail_screen.dart](lib/screens/group_detail_screen.dart)

**Links To**:
- Uses [group_repo.dart](lib/services/group_repo.dart)
- Uses [group_editor.dart](lib/widgets/group_editor.dart)

---

### [group_detail_screen.dart](lib/screens/group_detail_screen.dart)
**Purpose**: Detail view for a single group

**Features**:
- List of envelopes in group
- Add/remove envelopes
- Group settings

**Links To**:
- Uses [envelope_group.dart](lib/models/envelope_group.dart)
- Displays [envelope_tile.dart](lib/widgets/envelope_tile.dart)

---

### [add_scheduled_payment_screen.dart](lib/screens/add_scheduled_payment_screen.dart)
**Purpose**: Create/edit scheduled payments

**Features**:
- Name, amount, frequency, due date inputs
- Envelope selection
- Income vs expense toggle

**Links To**:
- Uses [scheduled_payment_repo.dart](lib/services/scheduled_payment_repo.dart)

---

### Envelope Screens

**Location**: `lib/screens/envelope/`

#### [envelopes_detail_screen.dart](lib/screens/envelope/envelopes_detail_screen.dart)
**Purpose**: Full detail view for a single envelope

**Features**:
- Envelope header (balance, target, icon) via [envelope_header_card.dart](lib/screens/envelope/envelope_header_card.dart) or [modern_envelope_header_card.dart](lib/screens/envelope/modern_envelope_header_card.dart)
- Action buttons (deposit, withdraw, transfer) via [envelope_action_buttons.dart](lib/screens/envelope/envelope_action_buttons.dart)
- Transaction history via [envelope_transaction_list.dart](lib/screens/envelope/envelope_transaction_list.dart)
- Settings sheet via [envelope_settings_sheet.dart](lib/screens/envelope/envelope_settings_sheet.dart)

**Links To**:
- Uses [envelope_repo.dart](lib/services/envelope_repo.dart)
- Opens modals: [deposit_modal.dart](lib/screens/envelope/modals/deposit_modal.dart), [withdraw_modal.dart](lib/screens/envelope/modals/withdraw_modal.dart), [transfer_modal.dart](lib/screens/envelope/modals/transfer_modal.dart)

#### [envelope_header_card.dart](lib/screens/envelope/envelope_header_card.dart)
**Purpose**: Displays envelope summary (legacy style)

**Links To**: Used in [envelopes_detail_screen.dart](lib/screens/envelope/envelopes_detail_screen.dart)

#### [modern_envelope_header_card.dart](lib/screens/envelope/modern_envelope_header_card.dart)
**Purpose**: Modern design envelope header

**Links To**: Alternative header style

#### [envelope_action_buttons.dart](lib/screens/envelope/envelope_action_buttons.dart)
**Purpose**: Action buttons for deposit/withdraw/transfer

**Links To**: Opens transaction modals

#### [envelope_settings_sheet.dart](lib/screens/envelope/envelope_settings_sheet.dart)
**Purpose**: Envelope settings bottom sheet

**Features**:
- Edit name, target, auto-fill settings
- Delete envelope
- Icon selection

**Links To**:
- Uses [envelope_repo.dart](lib/services/envelope_repo.dart)
- Uses [omni_icon_picker_modal.dart](lib/widgets/envelope/omni_icon_picker_modal.dart)

#### [envelope_transaction_list.dart](lib/screens/envelope/envelope_transaction_list.dart)
**Purpose**: List of transactions for an envelope

**Links To**:
- Uses [transaction.dart](lib/models/transaction.dart)

#### Envelope Modals

**Location**: `lib/screens/envelope/modals/`

##### [deposit_modal.dart](lib/screens/envelope/modals/deposit_modal.dart)
**Purpose**: Deposit funds to envelope

**Features**:
- Amount input with calculator
- Note field
- Account selection

**Links To**: Calls `repo.deposit()` in [envelope_repo.dart](lib/services/envelope_repo.dart)

##### [withdraw_modal.dart](lib/screens/envelope/modals/withdraw_modal.dart)
**Purpose**: Withdraw funds from envelope

**Features**:
- Amount input with calculator
- Note field
- Balance validation

**Links To**: Calls `repo.withdraw()` in [envelope_repo.dart](lib/services/envelope_repo.dart)

##### [transfer_modal.dart](lib/screens/envelope/modals/transfer_modal.dart)
**Purpose**: Transfer funds between envelopes

**Features**:
- Source/destination envelope selection
- Amount input
- Creates linked transactions

**Links To**: Calls `repo.transfer()` in [envelope_repo.dart](lib/services/envelope_repo.dart)

---

### Account Screens

**Location**: `lib/screens/accounts/`

#### [account_list_screen.dart](lib/screens/accounts/account_list_screen.dart)
**Purpose**: List of all accounts (moved to widgets, but kept for compatibility)

**Features**:
- Account cards
- Create account button
- Total balance summary

**Links To**:
- Uses [account_repo.dart](lib/services/account_repo.dart)
- Displays [account_card.dart](lib/widgets/accounts/account_card.dart)
- Opens [account_editor_modal.dart](lib/widgets/accounts/account_editor_modal.dart)

#### [account_detail_screen.dart](lib/screens/accounts/account_detail_screen.dart)
**Purpose**: Detail view for a single account

**Features**:
- Account balance and info
- Linked envelopes
- Edit/delete account

**Links To**:
- Uses [account_repo.dart](lib/services/account_repo.dart)

---

### Pay Day Screens

**Location**: `lib/screens/pay_day/`

#### [pay_day_amount_screen.dart](lib/screens/pay_day/pay_day_amount_screen.dart)
**Purpose**: Step 1 of pay day flow - set amount

**Links To**: Navigates to [pay_day_allocation_screen.dart](lib/screens/pay_day/pay_day_allocation_screen.dart)

#### [pay_day_allocation_screen.dart](lib/screens/pay_day/pay_day_allocation_screen.dart)
**Purpose**: Step 2 - allocate pay to envelopes

**Features**:
- List of envelopes with allocation amounts
- Quick fill options (targets, auto-fill settings)
- Preview total allocation

**Links To**: Navigates to [pay_day_stuffing_screen.dart](lib/screens/pay_day/pay_day_stuffing_screen.dart)

#### [pay_day_stuffing_screen.dart](lib/screens/pay_day/pay_day_stuffing_screen.dart)
**Purpose**: Step 3 - animation/confirmation of allocation

**Links To**: Calls `repo.batchUpdateEnvelopes()` in [envelope_repo.dart](lib/services/envelope_repo.dart)

#### [pay_day_preview_screen.dart](lib/screens/pay_day/pay_day_preview_screen.dart)
**Purpose**: Preview before executing pay day

**Links To**: Final confirmation step

#### [add_to_pay_day_modal.dart](lib/screens/pay_day/add_to_pay_day_modal.dart)
**Purpose**: Add envelope to pay day allocation list

**Links To**: Used in pay day flow

---

### Onboarding Screens

**Location**: `lib/screens/onboarding/`

#### [onboarding_flow.dart](lib/screens/onboarding/onboarding_flow.dart)
**Purpose**: New user onboarding flow

**Features**:
- Welcome screens
- Feature tutorials
- Navigate to [onboarding_account_setup.dart](lib/screens/onboarding/onboarding_account_setup.dart)

#### [onboarding_account_setup.dart](lib/screens/onboarding/onboarding_account_setup.dart)
**Purpose**: Create first account during onboarding

**Links To**: Creates account via [account_repo.dart](lib/services/account_repo.dart)

---

### Appearance & Theme Screens

#### [appearance_settings_screen.dart](lib/screens/appearance_settings_screen.dart)
**Purpose**: Font and visual preferences

**Features**:
- Font family selector
- Preview text

**Links To**: Uses [font_provider.dart](lib/providers/font_provider.dart)

#### [theme_picker_screen.dart](lib/screens/theme_picker_screen.dart)
**Purpose**: Theme selection UI

**Features**:
- Grid of 6 theme options with previews
- Live preview

**Links To**: Uses [theme_provider.dart](lib/providers/theme_provider.dart)

---

### Workspace Screens

#### [workspace_settings_screen.dart](lib/screens/workspace_settings_screen.dart)
**Purpose**: Workspace collaboration settings

**Features**:
- Invite members
- View shared envelopes
- Leave workspace

**Links To**: Uses [workspace_helper.dart](lib/services/workspace_helper.dart)

#### [workspace_gate.dart](lib/screens/workspace_gate.dart)
**Purpose**: Workspace access control

**Links To**: Guards workspace-specific features

---

## Widgets (Reusable Components)

**Location**: `lib/widgets/`

### Core Widgets

#### [envelope_creator.dart](lib/widgets/envelope_creator.dart)
**Purpose**: Bottom sheet for creating new envelopes

**Features**:
- Name input
- Initial amount input
- Account selection
- Icon picker via [omni_icon_picker_modal.dart](lib/widgets/envelope/omni_icon_picker_modal.dart)

**Links To**:
- Uses [envelope_repo.dart](lib/services/envelope_repo.dart)
- Called from [home_screen.dart](lib/screens/home_screen.dart) FAB

---

#### [envelope_tile.dart](lib/widgets/envelope_tile.dart)
**Purpose**: Reusable list item for envelopes

**Features**:
- Icon, name, balance display
- Swipe actions (deposit, withdraw, transfer, delete)
- Progress indicator for targets
- Tap to open [envelopes_detail_screen.dart](lib/screens/envelope/envelopes_detail_screen.dart)

**Links To**:
- Used in [home_screen.dart](lib/screens/home_screen.dart)
- Uses [envelope.dart](lib/models/envelope.dart)

---

#### [group_editor.dart](lib/widgets/group_editor.dart)
**Purpose**: Bottom sheet for creating/editing groups

**Features**:
- Group name input
- Envelope selection (multi-select)
- Pay day enabled toggle

**Links To**:
- Uses [group_repo.dart](lib/services/group_repo.dart)
- Called from [groups_home_screen.dart](lib/screens/groups_home_screen.dart)

---

#### [calculator_widget.dart](lib/widgets/calculator_widget.dart)
**Purpose**: On-screen calculator for amount inputs

**Features**:
- Number pad
- Basic operations (+, -, ×, ÷)
- Result display

**Links To**:
- Uses [calculator_helper.dart](lib/utils/calculator_helper.dart)
- Used in transaction modals

---

#### [emoji_picker_sheet.dart](lib/widgets/emoji_picker_sheet.dart)
**Purpose**: Emoji picker bottom sheet (legacy)

**Features**:
- Grid of emojis
- Search/filter

**Links To**:
- Uses [emoji_database.dart](lib/data/emoji_database.dart)
- Being replaced by [omni_icon_picker_modal.dart](lib/widgets/envelope/omni_icon_picker_modal.dart)

---

#### [emoji_pie_chart.dart](lib/widgets/emoji_pie_chart.dart)
**Purpose**: Pie chart visualization using emoji as icons

**Features**:
- Displays spending breakdown by envelope
- Uses `fl_chart` package

**Links To**: Used in stats/budget screens

---

#### [quick_action_modal.dart](lib/widgets/quick_action_modal.dart)
**Purpose**: Quick action bottom sheet

**Links To**: General-purpose action sheet

---

#### [tutorial_overlay.dart](lib/widgets/tutorial_overlay.dart)
**Purpose**: Tutorial overlay with highlight and instructions

**Features**:
- Spotlight effect
- Step-by-step guidance
- Skip tutorial option

**Links To**:
- Uses [tutorial_controller.dart](lib/services/tutorial_controller.dart)
- Used throughout app for first-time user guidance

---

#### [partner_badge.dart](lib/widgets/partner_badge.dart) & [partner_visibility_toggle.dart](lib/widgets/partner_visibility_toggle.dart)
**Purpose**: Workspace partner collaboration indicators

**Links To**: Used for shared envelope features

---

### Account Widgets

**Location**: `lib/widgets/accounts/`

#### [account_card.dart](lib/widgets/accounts/account_card.dart)
**Purpose**: Card displaying account summary

**Features**:
- Account name, balance, icon
- Available vs assigned amounts
- Tap to open [account_detail_screen.dart](lib/screens/accounts/account_detail_screen.dart)

**Links To**:
- Uses [account.dart](lib/models/account.dart)
- Used in [account_list_screen.dart](lib/widgets/accounts/account_list_screen.dart)

---

#### [account_editor_modal.dart](lib/widgets/accounts/account_editor_modal.dart)
**Purpose**: Bottom sheet for creating/editing accounts

**Features**:
- Name input
- Initial balance
- Icon picker (emoji, material, company logo)
- Workspace toggle

**Links To**:
- Uses [account_repo.dart](lib/services/account_repo.dart)
- Uses [omni_icon_picker_modal.dart](lib/widgets/envelope/omni_icon_picker_modal.dart)

---

#### [account_list_screen.dart](lib/widgets/accounts/account_list_screen.dart)
**Purpose**: Account listing (also exists in screens/)

**Features**:
- List of account cards
- Total balance summary
- Create account button

**Links To**:
- Uses [account_repo.dart](lib/services/account_repo.dart)
- Displays [account_card.dart](lib/widgets/accounts/account_card.dart)

---

### Budget Widgets

**Location**: `lib/widgets/budget/`

#### [overview_cards.dart](lib/widgets/budget/overview_cards.dart)
**Purpose**: Budget summary cards

**Features**:
- Total allocated
- Total available
- Upcoming scheduled payments
- Pay day countdown

**Links To**: Used in [budget_screen.dart](lib/screens/budget_screen.dart)

---

#### [projection_tool.dart](lib/widgets/budget/projection_tool.dart)
**Purpose**: Visual timeline of financial projection

**Features**:
- Line chart of account/envelope balances over time
- Event markers (pay days, scheduled payments)
- Scenario comparison

**Links To**:
- Uses [projection_service.dart](lib/services/projection_service.dart)
- Uses [projection.dart](lib/models/projection.dart)
- Uses `fl_chart` package

---

#### [scenario_editor_modal.dart](lib/widgets/budget/scenario_editor_modal.dart)
**Purpose**: What-if scenario editor

**Features**:
- Add temporary envelopes
- Adjust scheduled payment amounts
- See projected impact

**Links To**:
- Uses [projection_service.dart](lib/services/projection_service.dart)
- Uses [projection.dart](lib/models/projection.dart) (`TemporaryEnvelope`, `ProjectionScenario`)

---

#### [auto_fill_list_screen.dart](lib/widgets/budget/auto_fill_list_screen.dart)
**Purpose**: Auto-fill settings for envelopes

**Features**:
- List of envelopes with auto-fill enabled
- Edit auto-fill amount and frequency

**Links To**:
- Uses [envelope_repo.dart](lib/services/envelope_repo.dart)

---

#### [scheduled_payments_list_screen.dart](lib/widgets/budget/scheduled_payments_list_screen.dart)
**Purpose**: List of scheduled payments

**Features**:
- Recurring bills/income
- Edit/delete scheduled payments
- Next due date display

**Links To**:
- Uses [scheduled_payment_repo.dart](lib/services/scheduled_payment_repo.dart)

---

### Envelope Widgets

**Location**: `lib/widgets/envelope/`

#### [omni_icon_picker_modal.dart](lib/widgets/envelope/omni_icon_picker_modal.dart)
**Purpose**: Unified icon picker supporting multiple icon types

**Features**:
- Tab 1: Emoji picker
- Tab 2: Material Icons (searchable)
- Tab 3: Company logos (searchable, uses Google Favicons API)
- Search functionality

**Links To**:
- Uses [emoji_database.dart](lib/data/emoji_database.dart)
- Uses [material_icons_database.dart](lib/data/material_icons_database.dart)
- Uses [company_logos_database.dart](lib/data/company_logos_database.dart)
- Uses [icon_search_service_unlimited.dart](lib/services/icon_search_service_unlimited.dart)
- Used in [envelope_creator.dart](lib/widgets/envelope_creator.dart), [account_editor_modal.dart](lib/widgets/accounts/account_editor_modal.dart), [envelope_settings_sheet.dart](lib/screens/envelope/envelope_settings_sheet.dart)

---

## Data & Resources

**Location**: `lib/data/`

### [emoji_database.dart](lib/data/emoji_database.dart)
**Purpose**: Static list of emoji with names and categories

**Structure**:
```dart
List<Map<String, String>> emojiDatabase = [
  {'emoji': '😀', 'name': 'grinning face', 'category': 'Smileys & Emotion'},
  // ... hundreds more
];
```

**Links To**: Used by [emoji_picker_sheet.dart](lib/widgets/emoji_picker_sheet.dart) and [omni_icon_picker_modal.dart](lib/widgets/envelope/omni_icon_picker_modal.dart)

---

### [material_icons_database.dart](lib/data/material_icons_database.dart)
**Purpose**: Static list of Material Design icon names

**Structure**:
```dart
List<String> materialIconsDatabase = [
  'home', 'settings', 'search', 'favorite', // ... 1000+ icons
];
```

**Links To**: Used by [omni_icon_picker_modal.dart](lib/widgets/envelope/omni_icon_picker_modal.dart)

---

### [company_logos_database.dart](lib/data/company_logos_database.dart)
**Purpose**: Static list of company names for logo lookup

**Structure**:
```dart
List<String> companyLogosDatabase = [
  'Apple', 'Google', 'Amazon', 'Netflix', // ... popular brands
];
```

**Usage**: App uses Google Favicons API to fetch logos dynamically:
```dart
String url = 'https://www.google.com/s2/favicons?domain=${companyName}.com&sz=128';
```

**Links To**: Used by [omni_icon_picker_modal.dart](lib/widgets/envelope/omni_icon_picker_modal.dart)

---

## Theme & Styling

**Location**: `lib/theme/`

### [app_themes.dart](lib/theme/app_themes.dart)
**Purpose**: Defines 6 color schemes for the app

**Themes**:
1. **Latte** - Warm beige/brown tones
2. **Blush** - Pink/rose tones
3. **Lavender** - Purple/lavender tones
4. **Mint** - Green/mint tones
5. **Mono** - Black and white (high contrast)
6. **Singularity** - Dark mode variant

**Structure**:
```dart
class AppThemes {
  static ThemeData latte = ThemeData(...);
  static ThemeData blush = ThemeData(...);
  // etc.

  static ThemeData getThemeById(String id) { ... }
}
```

**Links To**:
- Used by [theme_provider.dart](lib/providers/theme_provider.dart)
- Applied in [main.dart](lib/main.dart)
- Selected in [theme_picker_screen.dart](lib/screens/theme_picker_screen.dart)

---

## Utilities

**Location**: `lib/utils/`

### [calculator_helper.dart](lib/utils/calculator_helper.dart)
**Purpose**: Calculator logic for amount inputs

**Key Functions**:
- `evaluateExpression()`: Parse and evaluate math expressions
- Supports +, -, ×, ÷ operations

**Links To**: Used by [calculator_widget.dart](lib/widgets/calculator_widget.dart)

---

### [target_helper.dart](lib/utils/target_helper.dart)
**Purpose**: Helper functions for envelope targets

**Key Functions**:
- Calculate progress toward target
- Determine if target is on track
- Date calculations

**Links To**: Used in envelope display logic

---

## Application Entry Point

### [main.dart](lib/main.dart)

**Purpose**: Application entry point and root widget

**Key Responsibilities**:
1. **Firebase Initialization**:
   ```dart
   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
   ```

2. **SharedPreferences Setup**: Restore theme on launch

3. **Provider Setup**: MultiProvider with 4 providers
   - ThemeProvider
   - FontProvider
   - AppPreferencesProvider
   - TutorialController (LocalizationProvider in some branches)

4. **MyApp Widget**: Root Consumer that rebuilds on theme/font changes
   - Material App with theme from ThemeProvider
   - Custom fonts from FontProvider
   - Routes to AuthGate

5. **AuthGate Widget**: Authentication routing logic
   ```dart
   StreamBuilder<User?>(
     stream: FirebaseAuth.instance.authStateChanges(),
     builder: (context, snapshot) {
       // If authenticated → check profile → HomeScreen or Onboarding
       // If not authenticated → SignInScreen
     }
   )
   ```

6. **HomeScreenWrapper**: Creates service instances
   ```dart
   final envelopeRepo = EnvelopeRepo.firebase(...);
   final accountRepo = AccountRepo.firebase(...);
   // Pass to HomeScreen
   ```

**Navigation Tree**:
```
main()
  ↓
MyApp (Consumer<ThemeProvider, FontProvider>)
  ↓
MaterialApp
  ↓
AuthGate (StreamBuilder<User?>)
  ├─→ Not authenticated → SignInScreen
  │
  └─→ Authenticated → StreamBuilder<UserProfile?>
       ├─→ No profile/onboarding incomplete → OnboardingFlow
       │
       └─→ Profile exists & onboarded → HomeScreenWrapper
            ↓
            HomeScreen (with repos)
```

**Links To**: Entry point for entire application

---

## Data Flow Architecture

### Request Flow Example: Creating an Envelope

```
1. User taps FAB in HomeScreen
   ↓
2. EnvelopeCreatorWidget (bottom sheet) displayed
   ↓
3. User enters name, amount, selects icon via OmniIconPickerModal
   ↓
4. User taps "Create"
   ↓
5. Widget calls repo.createEnvelope(envelope)
   ↓
6. EnvelopeRepo.createEnvelope() writes to Firestore
   └─→ users/{userId}/solo/data/envelopes/{envelopeId}
   ↓
7. Firestore update triggers envelopesStream() to emit new list
   ↓
8. StreamBuilder in HomeScreen rebuilds
   ↓
9. New EnvelopeTile appears in list
```

---

### Stream-Based Real-Time Updates

**Pattern**: Services expose `Stream<T>` that UI widgets subscribe to via `StreamBuilder`

**Example**: Envelope List

```dart
// In EnvelopeRepo
Stream<List<Envelope>> envelopesStream() {
  final soloStream = _firestore
    .collection('users/$userId/solo/data/envelopes')
    .snapshots()
    .map((snapshot) => snapshot.docs.map((doc) => Envelope.fromFirestore(doc)).toList());

  final workspaceStream = _getWorkspaceEnvelopesStream();

  return CombineLatestStream.list([soloStream, workspaceStream])
    .map((lists) => lists.expand((list) => list).toList());
}

// In HomeScreen
StreamBuilder<List<Envelope>>(
  stream: envelopeRepo.envelopesStream(),
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      return ListView(
        children: snapshot.data!.map((envelope) => EnvelopeTile(envelope)).toList(),
      );
    }
    return CircularProgressIndicator();
  },
)
```

---

### State Management Flow

**Global State (Provider)**:
```
User selects new theme in ThemePickerScreen
  ↓
Calls themeProvider.selectTheme('lavender')
  ↓
ThemeProvider:
  1. Updates _selectedThemeId
  2. Calls notifyListeners()
  3. Saves to SharedPreferences
  4. Saves to Firebase (UserService.updateUserProfile)
  ↓
Consumer<ThemeProvider> in MyApp rebuilds
  ↓
MaterialApp receives new theme
  ↓
Entire app rebuilds with new colors
```

---

### Service-to-Service Dependencies

```
HomeScreenWrapper (service instantiation)
  ↓
Creates:
  - EnvelopeRepo (depends on Firestore)
  - AccountRepo (depends on Firestore)
  - GroupRepo (depends on Firestore)
  - ScheduledPaymentRepo (depends on Firestore)
  - UserService (depends on Firestore)
  - ProjectionService (depends on EnvelopeRepo, AccountRepo, ScheduledPaymentRepo)
  - AutoPaymentService (depends on ScheduledPaymentRepo, EnvelopeRepo)
  ↓
Passes to child widgets
```

---

## Key Architectural Patterns

### 1. Repository Pattern
**Purpose**: Abstract Firestore operations, provide clean API

**Implementation**:
- Each major entity has a repo: `EnvelopeRepo`, `AccountRepo`, `GroupRepo`, `ScheduledPaymentRepo`
- Repos expose:
  - Streams for real-time updates: `envelopesStream()`
  - CRUD methods: `create()`, `update()`, `delete()`
  - Domain-specific operations: `deposit()`, `withdraw()`, `transfer()`

**Benefits**:
- Decouples UI from Firebase
- Easier testing (can mock repos)
- Single source of truth for data operations

---

### 2. Provider Pattern (State Management)
**Purpose**: Manage global UI state

**Implementation**:
- `ChangeNotifier` classes for theme, font, preferences, tutorial
- `MultiProvider` at app root in [main.dart](lib/main.dart)
- `Consumer` widgets rebuild on state changes
- `Provider.of<T>(context)` for accessing state

**Benefits**:
- Reactive UI updates
- Separation of business logic from UI
- Easy access to global state without prop drilling

---

### 3. Stream-Based Architecture
**Purpose**: Real-time data synchronization

**Implementation**:
- Firestore `snapshots()` for live updates
- RxDart `CombineLatestStream` for merging multiple streams
- `StreamBuilder` widgets for reactive UI

**Benefits**:
- Automatic UI updates when data changes
- Multi-device sync
- Workspace collaboration support

---

### 4. Workspace Multi-Tenancy
**Purpose**: Support solo and shared envelopes

**Implementation**:
- Envelopes stored in user's `solo` collection
- Shared envelopes also indexed in workspace `registry`
- Repos merge solo + workspace streams
- Ownership metadata prevents unauthorized transfers

**Benefits**:
- Partner budgeting support
- Data isolation
- Flexible collaboration model

---

### 5. Icon System Evolution
**Purpose**: Support multiple icon types (emoji, material, company logos)

**Implementation**:
- Legacy `emoji` field preserved
- New fields: `iconType`, `iconData`
- Models have `getIconWidget()` with fallback logic
- `OmniIconPickerModal` supports all types

**Benefits**:
- Backward compatibility
- Richer visual options
- Gradual migration path

---

### 6. Projection Engine (Pure Functions)
**Purpose**: Calculate financial forecasts

**Implementation**:
- `ProjectionService` is stateless calculator
- Takes snapshots of current state
- Generates timeline of events
- Simulates each event chronologically
- Returns immutable `ProjectionResult`

**Benefits**:
- What-if scenarios without modifying data
- Testable (pure functions)
- Reusable across features

---

### 7. Dependency Injection
**Purpose**: Provide services to widgets

**Implementation**:
- `HomeScreenWrapper` creates repos/services
- Passes as constructor parameters to child widgets
- No global singletons (except FirebaseFirestore.instance)

**Benefits**:
- Testable (can inject mocks)
- Clear dependencies
- Scoped to user session

---

### 8. Bottom Sheet Modals
**Purpose**: Quick actions without full navigation

**Implementation**:
- `showModalBottomSheet()` for forms and pickers
- Widgets: `EnvelopeCreator`, `DepositModal`, `WithdrawModal`, `TransferModal`, `AccountEditorModal`, `GroupEditor`, etc.

**Benefits**:
- Reduced navigation complexity
- Contextual actions
- Better mobile UX

---

## Firebase Structure

### Firestore Collections

#### User Collections
```
users/{userId}
  ├─ [profile fields from UserProfile model]
  │
  ├─ solo/
  │   └─ data/
  │       ├─ envelopes/{envelopeId}
  │       │    ├─ id
  │       │    ├─ name
  │       │    ├─ amount
  │       │    ├─ accountId
  │       │    ├─ target
  │       │    ├─ targetByDate
  │       │    ├─ autoFill
  │       │    ├─ emoji (legacy)
  │       │    ├─ iconType
  │       │    ├─ iconData
  │       │    ├─ isShared
  │       │    ├─ workspaceId
  │       │    └─ createdAt
  │       │
  │       ├─ accounts/{accountId}
  │       │    ├─ id
  │       │    ├─ name
  │       │    ├─ balance
  │       │    ├─ iconType
  │       │    ├─ iconData
  │       │    ├─ isShared
  │       │    └─ workspaceId
  │       │
  │       ├─ groups/{groupId}
  │       │    ├─ id
  │       │    ├─ name
  │       │    ├─ envelopeIds
  │       │    ├─ isEnabledForPayDay
  │       │    └─ orderIndex
  │       │
  │       ├─ transactions/{transactionId}
  │       │    ├─ id
  │       │    ├─ userId
  │       │    ├─ envelopeId
  │       │    ├─ type
  │       │    ├─ amount
  │       │    ├─ note
  │       │    ├─ timestamp
  │       │    ├─ transferToEnvelopeId
  │       │    ├─ transferToWorkspaceId
  │       │    └─ linkedTransactionId
  │       │
  │       └─ scheduledPayments/{paymentId}
  │            ├─ id
  │            ├─ name
  │            ├─ amount
  │            ├─ frequency
  │            ├─ nextDueDate
  │            ├─ envelopeId
  │            └─ isIncome
  │
  └─ shared/
      └─ [references to shared workspace envelopes]
```

#### Workspace Collections
```
workspaces/{workspaceId}
  ├─ [workspace settings]
  ├─ members/{userId}
  │    └─ [member metadata]
  │
  ├─ accounts/{accountId}
  │    └─ [shared account data]
  │
  ├─ groups/{groupId}
  │    └─ [shared group data]
  │
  └─ registry/v1/
       └─ envelopes/{envelopeId}
            ├─ id
            ├─ name
            ├─ amount
            ├─ ownerId (original user)
            ├─ ownerDisplayName
            ├─ iconType
            ├─ iconData
            └─ [read-only index for discovery]
```

---

### Firebase Security Considerations

**Authentication**: Firebase Auth with Google Sign-In and Email/Password

**Firestore Security Rules** (not included in codebase, but implied):
- Users can only read/write their own `users/{userId}` documents
- Workspace members can read `workspaces/{workspaceId}/registry/v1/envelopes` for discovery
- Transfers validate ownership via registry metadata

---

## Key Dependencies

From [pubspec.yaml](pubspec.yaml):

| Package | Purpose |
|---------|---------|
| `firebase_core` ^4.2.1 | Firebase initialization |
| `firebase_auth` ^6.1.2 | Authentication |
| `cloud_firestore` ^6.1.0 | Firestore database |
| `provider` ^6.0.5 | State management |
| `google_fonts` ^6.1.0 | Custom fonts |
| `google_sign_in` ^6.2.1 | Google authentication |
| `intl` ^0.20.2 | Internationalization |
| `rxdart` ^0.28.0 | Stream utilities (CombineLatestStream) |
| `fl_chart` ^0.66.0 | Charts and graphs |
| `uuid` ^4.0.0 | Generate unique IDs |
| `cached_network_image` ^3.3.0 | Image caching (for company logos) |
| `shared_preferences` ^2.3.2 | Local key-value storage |
| `flutter_speed_dial` ^7.0.0 | Speed dial FAB |
| `table_calendar` ^3.1.2 | Calendar widget |

---

## File Count Summary

**Total Dart Files**: ~85

**Breakdown by Directory**:
- `models/`: 8 files
- `services/`: 15 files
- `providers/`: 4 files
- `screens/`: 25 files
- `widgets/`: 20 files
- `data/`: 3 files
- `theme/`: 1 file
- `utils/`: 2 files
- Root: 2 files (main.dart, firebase_options.dart)

---

## Development Workflow

### Adding a New Feature

1. **Model**: Create/update model in `lib/models/`
2. **Service**: Create/update repo in `lib/services/`
3. **UI**: Create screen in `lib/screens/` or widget in `lib/widgets/`
4. **Navigation**: Add route or modal trigger
5. **State**: Use Provider if global state needed
6. **Testing**: Test CRUD operations and UI flows

### Common Tasks

**Create New Envelope**:
- [home_screen.dart](lib/screens/home_screen.dart) → FAB → [envelope_creator.dart](lib/widgets/envelope_creator.dart) → [envelope_repo.dart](lib/services/envelope_repo.dart)

**Deposit to Envelope**:
- [envelope_tile.dart](lib/widgets/envelope_tile.dart) → Swipe action → [deposit_modal.dart](lib/screens/envelope/modals/deposit_modal.dart) → [envelope_repo.dart](lib/services/envelope_repo.dart)

**Change Theme**:
- [settings_screen.dart](lib/screens/settings_screen.dart) → [theme_picker_screen.dart](lib/screens/theme_picker_screen.dart) → [theme_provider.dart](lib/providers/theme_provider.dart) → [app_themes.dart](lib/theme/app_themes.dart)

**View Projection**:
- [budget_screen.dart](lib/screens/budget_screen.dart) → [projection_tool.dart](lib/widgets/budget/projection_tool.dart) → [projection_service.dart](lib/services/projection_service.dart)

---

## Troubleshooting Common Issues

### Envelope Not Appearing
- Check `envelopesStream()` in [envelope_repo.dart](lib/services/envelope_repo.dart)
- Verify `isShared` flag and `workspaceId` if using workspace mode
- Check Firestore security rules

### Theme Not Persisting
- Check [theme_provider.dart](lib/providers/theme_provider.dart) `selectTheme()` saves to SharedPreferences
- Verify [user_service.dart](lib/services/user_service.dart) updates user profile

### Transfer Fails
- Check `transfer()` in [envelope_repo.dart](lib/services/envelope_repo.dart) validates ownership
- Verify workspace registry has correct metadata

### Icon Not Displaying
- Check `getIconWidget()` in [envelope.dart](lib/models/envelope.dart) and [account.dart](lib/models/account.dart)
- Verify `iconType` is 'emoji', 'materialIcon', or 'companyLogo'
- For company logos, check `cached_network_image` is working

---

## Future Improvements / TODOs

Based on codebase structure, potential enhancements:

1. **Full Localization**: `LocalizationService` and `languageCode`/`currencyCode` are placeholders
2. **Account Security**: `AccountSecurityService` is stub for PIN/biometric
3. **Advanced Workspace Features**: Currently basic, could add permissions, audit logs
4. **Recurring Transfers**: Auto-transfers between envelopes on schedule
5. **Budget Reports**: PDF export, email summaries
6. **Mobile Bank Integration**: Link real bank accounts (Plaid, etc.)
7. **Widget Home Screen**: iOS/Android widgets for quick balance checks
8. **Offline Mode**: Better handling of offline scenarios
9. **Data Export**: CSV/JSON export of all data
10. **Dark Mode**: Singularity theme exists but could be expanded

---

## Glossary

| Term | Definition |
|------|------------|
| **Envelope** | Virtual budget category with allocated funds |
| **Account** | Financial account (bank, cash, credit) |
| **Transaction** | Deposit, withdrawal, or transfer of funds |
| **Group** | Collection of related envelopes |
| **Pay Day** | Automated fund allocation to envelopes |
| **Auto-Fill** | Automatic envelope funding on schedule |
| **Target** | Savings goal for an envelope |
| **Scheduled Payment** | Recurring bill or income |
| **Projection** | Forecast of future financial state |
| **Scenario** | What-if analysis with temporary envelopes |
| **Workspace** | Shared budget space for partners |
| **Solo Mode** | Individual (non-shared) budgeting |
| **Registry** | Workspace index of shared envelopes |

---

## Quick Reference

### Most Important Files

1. [main.dart](lib/main.dart) - Application entry point
2. [home_screen.dart](lib/screens/home_screen.dart) - Main navigation hub
3. [envelope_repo.dart](lib/services/envelope_repo.dart) - Core envelope logic
4. [envelope.dart](lib/models/envelope.dart) - Envelope data model
5. [envelope_tile.dart](lib/widgets/envelope_tile.dart) - Envelope UI component
6. [theme_provider.dart](lib/providers/theme_provider.dart) - Theme management
7. [projection_service.dart](lib/services/projection_service.dart) - Financial forecasting

### Most Connected Files

**High Fan-Out** (used by many files):
- [envelope_repo.dart](lib/services/envelope_repo.dart) - Used by all envelope-related UI
- [account_repo.dart](lib/services/account_repo.dart) - Used by all account-related UI
- [envelope.dart](lib/models/envelope.dart) - Referenced everywhere envelopes appear
- [theme_provider.dart](lib/providers/theme_provider.dart) - Used throughout app for theming

**High Fan-In** (uses many files):
- [home_screen.dart](lib/screens/home_screen.dart) - Integrates repos, providers, widgets
- [budget_screen.dart](lib/screens/budget_screen.dart) - Uses projection service, widgets, models
- [envelopes_detail_screen.dart](lib/screens/envelope/envelopes_detail_screen.dart) - Uses repo, models, modals, widgets

---

## Conclusion

**Envelope Lite** is a well-structured Flutter application demonstrating clean architecture principles. The separation of concerns (models, services, providers, UI) makes it maintainable and extensible. The combination of Repository pattern for data access, Provider for state management, and Stream-based real-time updates creates a robust and responsive user experience.

Key strengths:
- Clear architectural boundaries
- Real-time Firebase integration
- Flexible workspace collaboration
- Rich customization options
- Comprehensive financial projection engine

This master context document serves as a comprehensive guide to understanding the codebase structure, file relationships, and architectural decisions.

---

**Document Version**: 1.0
**Generated**: 2025-12-18
**Project**: Envelope Lite (Flutter Budget App)