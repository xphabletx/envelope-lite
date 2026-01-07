# Old Pay Day System Files (Archive)

These files represent the **pre-Cockpit** Pay Day system from commit `493c427` (Phase 3: Visual Pay Day Stuffing with Binder-based Animation).

## Purpose
These files are preserved for reference but are **NOT wired into the application**. They use the `_old.dart` suffix to avoid conflicts with the current Pay Day Cockpit system.

## Archived Files

### Screens
- **`pay_day_amount_screen_old.dart`** - Original amount entry screen (multi-step wizard approach)
- **`pay_day_allocation_screen_old.dart`** - Original allocation/strategy screen with manual envelope selection
- **`pay_day_stuffing_screen_old.dart`** - Original animated stuffing execution screen with binder-based animations
- **`add_to_pay_day_modal_old.dart`** - Modal for adding envelopes to pay day allocations

### Services
- **`pay_day_processor_old.dart`** (in `lib/services/`) - Original pay day processing service

### Widgets
- **`stuffing_binder_card_old.dart`** (in `lib/widgets/binder/`) - Binder card widget used during stuffing animation

## Architecture Differences

### Old System (Multi-Screen Wizard)
- **3 separate screens**: Amount → Allocation → Stuffing
- Navigation between screens via `Navigator.push()`
- State managed across screen transitions
- Binder-based visual animations during stuffing
- Manual envelope selection in allocation phase

### New System (Single Cockpit)
- **Single screen** with 4 phases: `CockpitPhase` enum
- All state in `PayDayCockpitProvider`
- Phase transitions via `notifyListeners()`
- Unified "cockpit" metaphor
- Autopilot allocations with manual boosts

## Key Features from Old System

1. **Visual Binder Animations** - Stuffing showed binders "filling up" with animated progress
2. **Manual Allocation Control** - Users could add/remove individual envelopes
3. **Multi-Step Wizard Flow** - Clear progression through Amount → Strategy → Execute
4. **Binder Grouping** - Envelopes grouped by binder during stuffing display

## Current System
The current Pay Day Cockpit (`pay_day_cockpit.dart` + `pay_day_cockpit_provider.dart`) consolidates all functionality into a single screen with improved:
- Account mode detection
- Autopilot allocation strategy
- Real-time fuel calculations
- Horizon impact visualization

## Do Not Use
These files are for **reference only**. Do not import or wire them into the application. They may have outdated dependencies or conflicting class names with the current system.

---
*Archived: January 7, 2026*
*Commit: 493c427 - Phase 3: Visual Pay Day Stuffing with Binder-based Animation*
