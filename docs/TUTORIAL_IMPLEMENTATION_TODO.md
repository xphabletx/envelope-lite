# Tutorial Implementation TODO

## Overview
The tutorial system is partially implemented. Currently, only the Home Screen has the `TutorialWrapper` working. The other screens need to have the wrapper added.

## Completed
- ✅ Home Screen (`lib/screens/home_screen.dart`) - Has `TutorialWrapper` with `homeTutorial`
- ✅ Tutorial debug logging added to `TutorialWrapper`
- ✅ Tutorial re-checking on route navigation (`didPopNext`)
- ✅ Tutorial manager can now navigate to screens (shows message)
- ✅ Tutorial sequences defined in `lib/data/tutorial_sequences.dart`

## Screens That Need TutorialWrapper

### 1. Binders Screen (Groups Home)
**File**: `lib/screens/groups_home_screen.dart`
**Tutorial**: `bindersTutorial`
**Spotlight Keys Needed**:
- `view_history_button` - For the "View History" button tip

**Implementation**:
```dart
// Add import
import '../widgets/tutorial_wrapper.dart';
import '../data/tutorial_sequences.dart';

// In build method, wrap the main Scaffold with:
return TutorialWrapper(
  tutorialSequence: bindersTutorial,
  spotlightKeys: {
    'view_history_button': _viewHistoryButtonKey,
  },
  child: Scaffold(...),
);
```

### 2. Calendar Screen
**File**: `lib/screens/calendar_screen.dart` (CalendarScreenV2)
**Tutorial**: `calendarTutorial`
**Spotlight Keys Needed**:
- `view_toggle` - For the week/month view toggle

### 3. Envelope Detail Screen
**File**: `lib/screens/envelope/envelopes_detail_screen.dart`
**Tutorial**: `envelopeDetailTutorial`
**Spotlight Keys Needed**:
- `calculator_chip`
- `month_selector`
- `target_card`
- `envelope_fab`
- `binder_link`

### 4. Accounts Screen
**File**: `lib/screens/accounts/account_list_screen.dart`
**Tutorial**: `accountsTutorial`
**Spotlight Keys Needed**:
- `balance_card`

### 5. Settings Screen
**File**: `lib/screens/settings_screen.dart`
**Tutorial**: `settingsTutorial`
**Spotlight Keys Needed**:
- `theme_selector`
- `font_picker`
- `export_option`

### 6. Pay Day Screen
**File**: `lib/screens/pay_day/pay_day_amount_screen.dart` (or first screen in flow)
**Tutorial**: `payDayTutorial`
**Spotlight Keys Needed**:
- `auto_fill_toggle`
- `allocation_summary`

### 7. Time Machine Screen
**File**: `lib/widgets/budget/time_machine_screen.dart`
**Tutorial**: `timeMachineTutorial`
**Spotlight Keys Needed**:
- `date_picker`
- `pay_settings`
- `toggle_switches`
- `enter_button`

### 8. Workspace Screen
**File**: `lib/screens/workspace_management_screen.dart` or workspace gate
**Tutorial**: `workspaceTutorial`
**Spotlight Keys Needed**:
- `join_workspace`

## Implementation Pattern

For each screen:

1. **Add imports**:
```dart
import '../widgets/tutorial_wrapper.dart';
import '../data/tutorial_sequences.dart';
```

2. **Create GlobalKey fields** for spotlight widgets:
```dart
final GlobalKey _someButtonKey = GlobalKey();
```

3. **Assign keys** to the widgets that need spotlights:
```dart
IconButton(
  key: _someButtonKey,
  icon: const Icon(Icons.settings),
  // ...
)
```

4. **Wrap the build output** with TutorialWrapper:
```dart
return TutorialWrapper(
  tutorialSequence: yourTutorial,
  spotlightKeys: {
    'button_id': _someButtonKey,
  },
  child: Scaffold(...),
);
```

## Debug Logging

The `TutorialWrapper` now includes debug logging:
- `[Tutorial] Checking status for screen: {screenId}`
- `[Tutorial] Screen {screenId} - Complete: {bool}, Will show: {bool}`
- `[Tutorial] ✅ Tutorial will be shown for {screenId}`
- `[Tutorial] ⏭️ Tutorial already completed for {screenId}`

Check Flutter logs to see which tutorials are being checked and shown.

## Navigation from Tutorial Manager

The Tutorial Manager (`lib/screens/settings/tutorial_manager_screen.dart`) now has:
- Tappable tutorial cards
- `_navigateToScreen()` method (currently shows message)
- Could be enhanced to actually navigate to specific tabs/screens

To implement full navigation, you would need to:
1. Pass a navigation callback to `TutorialManagerScreen`
2. Or use a global navigator key
3. Map `screenId` to specific navigation actions

## Testing

1. Reset all tutorials from Tutorial Manager
2. Navigate to each screen
3. Check debug logs to see if tutorial status is checked
4. Verify tutorial overlay appears for screens with `TutorialWrapper`
5. Complete tutorial and verify it doesn't show again
6. Reset and verify it shows again on next visit

## Notes

- The Home Screen tutorial has been reordered: FAB first, Sort second, Swipe third
- The FAB description was changed from "Hold" to "Tap"
- Tutorial wrapper uses `RouteAware` to detect when returning to screen after resetting tutorials
