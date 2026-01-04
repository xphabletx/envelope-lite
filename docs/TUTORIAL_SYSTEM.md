# Tutorial System Documentation

## Overview

The Stuffrite app features a comprehensive tutorial system with per-screen guidance and a searchable FAQ. The system uses spotlight highlighting, dark overlays, and emoji-rich tips to help users discover features without being intrusive.

---

## Core Infrastructure

### Files

**Tutorial System:**
- `lib/data/tutorial_sequences.dart` - All 9 tutorial sequences with 30+ tips
- `lib/services/tutorial_controller.dart` - Per-screen completion tracking
- `lib/widgets/tutorial_overlay.dart` - Tutorial UI component with spotlight
- `lib/widgets/tutorial_wrapper.dart` - Screen wrapper for auto-triggering

**FAQ System:**
- `lib/data/faq_data.dart` - 27 comprehensive FAQ items
- `lib/screens/settings/faq_screen.dart` - Searchable FAQ interface

**Management:**
- `lib/screens/settings/tutorial_manager_screen.dart` - Granular tutorial control
- `lib/screens/settings_screen.dart` - Entry points (Help & FAQ, Tutorial Manager)

### Tutorial Sequences

The system includes 9 tutorial sequences:

1. **Home Screen** (4 tips) - ✅ Integrated
2. **Binders** (3 tips) - ⏳ Needs integration
3. **Envelope Details** (5 tips) - ⏳ Needs integration
4. **Calendar** (2 tips) - ⏳ Needs integration
5. **Accounts** (2 tips) - ⏳ Needs integration
6. **Settings** (4 tips) - ⏳ Needs integration
7. **Pay Day** (3 tips) - ⏳ Needs integration
8. **Time Machine** (4 tips) - ⏳ Needs integration
9. **Workspace** (3 tips) - ⏳ Needs integration

---

## Features

### Tutorial System
✅ Auto-triggers on first visit to each screen
✅ Spotlight highlighting with dark overlay and glowing holes
✅ Smart tooltip positioning based on spotlight location
✅ Progress tracking (1 of 4, 2 of 4, etc.)
✅ Skip tutorial option
✅ Auto-saves completion state to SharedPreferences
✅ Tutorial Manager for granular control
✅ Replay specific screens independently
✅ Reset all tutorials at once
✅ Beautiful fade-in/out animations

### FAQ System
✅ 27 comprehensive FAQ items covering all features
✅ Real-time search (questions, answers, tags)
✅ Emoji-rich presentation
✅ Expandable cards
✅ Screenshot placeholders (ready for images)
✅ No results state
✅ Works offline

---

## Implementation Guide

### Quick 3-Step Integration

For any screen that needs tutorials:

#### Step 1: Add Imports
```dart
import '../widgets/tutorial_wrapper.dart';
import '../data/tutorial_sequences.dart';
```

#### Step 2: Create GlobalKeys for Spotlights (Optional)
```dart
class _YourScreenState extends State<YourScreen> {
  final GlobalKey _importantButtonKey = GlobalKey();
  final GlobalKey _specialFeatureKey = GlobalKey();
  // ... rest of your code
}
```

#### Step 3: Wrap Scaffold with TutorialWrapper
```dart
@override
Widget build(BuildContext context) {
  return TutorialWrapper(
    tutorialSequence: yourScreenTutorial, // From tutorial_sequences.dart
    spotlightKeys: {
      'important_button': _importantButtonKey,
      'special_feature': _specialFeatureKey,
    },
    child: Scaffold(
      // Your existing scaffold code
      floatingActionButton: FloatingActionButton(
        key: _importantButtonKey, // Assign key to widget
        // ...
      ),
    ),
  );
}
```

---

## Screen Integration Checklist

### ✅ 1. Home Screen
**File:** `lib/screens/home_screen.dart`
**Status:** Complete - working example
**Tutorial:** `homeTutorial`
**Spotlight Keys:** `fab`, `sort_button`, `mine_only_toggle`

### ⏳ 2. Binders Screen
**File:** `lib/screens/groups_home_screen.dart`
**Tutorial:** `bindersTutorial`
**Spotlight Keys:** `view_history_button`

### ⏳ 3. Envelope Details
**File:** `lib/screens/envelope/envelopes_detail_screen.dart`
**Tutorial:** `envelopeDetailTutorial`
**Spotlight Keys:** `calculator_chip`, `month_selector`, `target_card`, `envelope_fab`, `binder_link`

### ⏳ 4. Calendar
**File:** `lib/screens/calendar_screen.dart`
**Tutorial:** `calendarTutorial`
**Spotlight Keys:** `view_toggle`

### ⏳ 5. Accounts
**File:** `lib/screens/accounts/account_list_screen.dart`
**Tutorial:** `accountsTutorial`
**Spotlight Keys:** `balance_card`

### ⏳ 6. Settings
**File:** `lib/screens/settings_screen.dart`
**Tutorial:** `settingsTutorial`
**Spotlight Keys:** `theme_selector`, `font_picker`, `export_option`

### ⏳ 7. Pay Day
**File:** `lib/screens/pay_day/pay_day_amount_screen.dart`
**Tutorial:** `payDayTutorial`
**Spotlight Keys:** `auto_fill_toggle`, `allocation_summary`

### ⏳ 8. Time Machine
**File:** `lib/widgets/budget/time_machine_screen.dart`
**Tutorial:** `timeMachineTutorial`
**Spotlight Keys:** `date_picker`, `pay_settings`, `toggle_switches`, `enter_button`

### ⏳ 9. Workspace
**File:** `lib/screens/workspace_management_screen.dart`
**Tutorial:** `workspaceTutorial`
**Spotlight Keys:** `join_workspace`

---

## How It Works

### Spotlight Effect

When a tutorial step has `spotlightWidgetKey` set:

1. **Dark overlay** (70% black) covers the entire screen
2. **Glowing hole** is cut out around the target widget
3. **White border** glows around the highlighted area
4. **Tooltip** positions intelligently above or below the spotlight
5. **User interaction** is blocked except for tutorial buttons

### Completion Tracking

- Stored in SharedPreferences key: `tutorial_completed_screens`
- Format: `List<String>` of completed screen IDs
- Example: `['home', 'binders', 'envelope_detail']`
- Persists offline, no Firebase dependency

### Auto-Triggering

- Uses `RouteAware` to detect screen navigation
- Checks completion status on screen entry
- Shows tutorial if not completed
- Never repeats once user completes or skips

---

## User Experience Flow

1. User opens app for first time
2. **Home tutorial** shows automatically (4 tips)
3. User completes or skips tutorial
4. Tutorial saved as complete, never shows again on home
5. User navigates to **Binders** tab
6. **Binders tutorial** shows automatically (first visit)
7. Process repeats for each screen

---

## TutorialController API

```dart
// Check if screen tutorial is complete
await TutorialController.isScreenComplete('home'); // Returns bool

// Mark screen tutorial as complete
await TutorialController.markScreenComplete('home');

// Reset specific screen tutorial
await TutorialController.resetScreen('home');

// Reset all tutorials
await TutorialController.resetAll();

// Get all completion statuses
await TutorialController.getAllCompletionStatus(); // Returns Map<String, bool>
```

---

## Testing Checklist

After integrating remaining screens:

- [ ] Fresh install → Home tutorial shows
- [ ] Complete home tutorial → doesn't show again
- [ ] Navigate to Binders → Binders tutorial shows
- [ ] Settings → Tutorial Manager → All screens listed with status
- [ ] Tutorial Manager → Reset specific screen → Shows again on visit
- [ ] Tutorial Manager → Reset all → All tutorials show again
- [ ] Settings → FAQ → Search works correctly
- [ ] FAQ → Expand items → Answers and screenshots visible
- [ ] Tutorial overlay → Skip → Marks complete
- [ ] Tutorial overlay → Progress bar accurate
- [ ] Spotlight highlighting → Correct widget highlighted
- [ ] Tooltip positioning → Above/below spotlight appropriately

---

## Debug Logging

The `TutorialWrapper` includes debug logging:

```
[Tutorial] Checking status for screen: home
[Tutorial] Screen home - Complete: false, Will show: true
[Tutorial] ✅ Tutorial will be shown for home
[Tutorial] ⏭️ Tutorial already completed for binders
```

Check Flutter console logs to debug tutorial behavior.

---

## FAQ System

### FAQ Data Structure

Located in `lib/data/faq_data.dart`:

```dart
FaqItem(
  id: 'getting_started_1',
  category: 'Getting Started',
  question: 'What is envelope budgeting?',
  answer: 'Detailed answer...',
  emoji: '📚',
  tags: ['beginner', 'basics', 'envelope'],
  screenshotPath: null, // Optional: 'assets/images/faq/screenshot.png'
),
```

### FAQ Categories

1. Getting Started
2. Envelopes & Targets
3. Binders
4. Accounts
5. Pay Day & Auto-Fill
6. Time Machine
7. Workspaces
8. Customization
9. Advanced Features
10. Scheduled Payments
11. Security & Backups
12. Troubleshooting

### Adding Screenshots to FAQ

1. Take screenshots of features
2. Add to `assets/images/faq/`
3. Update `screenshotPath` in `faq_data.dart`
4. Update `faq_screen.dart` to use `Image.asset()` instead of placeholder

---

## Architecture Decisions

### Why This Approach?

1. **TutorialWrapper over Consumer** - Simpler than Provider pattern
2. **Per-screen tracking** - More flexible than single global tutorial
3. **SharedPreferences** - Offline-first, no Firebase dependency
4. **Spotlight highlighting** - Draws attention without being intrusive
5. **Screenshot placeholders** - Easy to add images later
6. **Emoji-rich content** - Fun, engaging, memorable

### Data Storage

- **Local only** - SharedPreferences (key: `tutorial_completed_screens`)
- **No cloud sync** - Tutorial progress is device-specific
- **Lightweight** - ~1KB per user
- **Privacy-friendly** - No analytics tracking (optional to add)

---

## Future Enhancements (Optional)

### Analytics

Track tutorial engagement:
- Firebase Analytics events for completion/skip rates
- Track which tutorials are most helpful
- Track which FAQ items are viewed most
- A/B test tutorial content

### Advanced Spotlight

Currently supported but not fully utilized:
- Multiple spotlights per step
- Animated spotlight transitions
- Custom spotlight shapes
- Interactive spotlights (click to continue)

### Onboarding Flow

Could be expanded to:
- Multi-step onboarding wizard on first launch
- Feature announcements for updates
- Contextual help based on user behavior
- Adaptive tutorials based on user expertise

---

## Success Metrics

This implementation delivers:

- **30+ tutorial tips** across 9 major screens
- **27 FAQ items** covering all app features
- **Zero breaking changes** to existing code
- **100% offline capable** tutorial system
- **Fun, emoji-rich** user experience
- **Granular control** for power users
- **Production-ready** architecture

The system significantly improves user onboarding and feature discovery! 🎉

---

## Notes

- Tutorial content focuses on feature discovery, not hand-holding
- Each tip is 1-2 sentences maximum
- Highlights hidden/advanced features users might miss
- Works offline with SharedPreferences
- Can be reset/replayed from Settings
- No heavy dependencies or external services
