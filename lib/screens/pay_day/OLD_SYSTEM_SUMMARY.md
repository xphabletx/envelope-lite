# Old Pay Day System - Quick Reference

## File Overview

### 📱 Screens (lib/screens/pay_day/)

#### `pay_day_amount_screen_old.dart` (14KB, ~400 lines)
**Purpose:** First step of wizard - enter pay amount
- TextField for amount input with calculator helper
- Shows expected pay amount from settings
- FittedBox for responsive text scaling
- Navigator.push to allocation screen

**Key Classes:**
- `PayDayAmountScreen` - StatefulWidget
- `_PayDayAmountScreenState` - Amount entry logic

---

#### `pay_day_allocation_screen_old.dart` (57KB, ~1,600 lines)
**Purpose:** Second step - review and adjust allocations
- Manual envelope selection/deselection
- Binder-based grouping
- Add/remove envelopes from pay day
- Shows available/allocated amounts
- Navigator.push to stuffing screen

**Key Classes:**
- `PayDayAllocationScreen` - Main allocation UI
- Envelope cards with checkboxes
- Binder expansion tiles
- "Add More" functionality

---

#### `pay_day_stuffing_screen_old.dart` (30KB, ~850 lines)
**Purpose:** Third step - visual execution with animations
- Animated binder cards filling up
- Real-time progress tracking
- Horizon impact calculations
- Success celebration screen

**Key Classes:**
- `PayDayStuffingScreen` - Stuffing execution UI
- Animated binder cards
- Progress indicators
- Horizon savings display

---

#### `add_to_pay_day_modal_old.dart` (9.7KB, ~280 lines)
**Purpose:** Modal for adding envelopes during allocation
- Search/filter envelopes
- Add individual envelopes
- Add entire binders

**Key Classes:**
- `AddToPayDayModal` - BottomSheet widget
- Envelope search functionality
- Binder selection

---

### 🔧 Services (lib/services/)

#### `pay_day_processor_old.dart` (7.4KB, ~200 lines)
**Purpose:** Backend processing for pay day execution
- Account vs Simple mode detection
- Envelope deposits/transfers
- Account balance updates
- Transaction creation

**Key Functions:**
- `processPayDay()` - Main execution
- `_depositToAccount()` - Account mode
- `_depositToEnvelopes()` - Simple mode
- Horizon calculations

---

### 🎨 Widgets (lib/widgets/binder/)

#### `stuffing_binder_card_old.dart` (11KB, ~360 lines)
**Purpose:** Visual binder card during stuffing animation
- Expandable binder display
- Progress bar animations
- Envelope list with amounts
- Target total calculations

**Key Classes:**
- `StuffingBinderCard` - Animated card widget
- Progress indicators
- Envelope rows

---

## Architecture Comparison

### Old System Flow
```
Amount Screen (Navigator.push)
    ↓
Allocation Screen (Navigator.push)
    ↓
Stuffing Screen
    ↓
Pop back to home
```

**State Management:** Passed via constructor parameters and Navigator.push arguments

### New System Flow (Cockpit)
```
Single Screen with CockpitPhase:
- amountEntry
- strategyReview
- stuffingExecution
- success
```

**State Management:** `PayDayCockpitProvider` with `notifyListeners()`

---

## What Changed

### Old → New
1. **Multi-screen wizard** → Single cockpit screen
2. **Manual allocation** → Autopilot with boosts
3. **Binder animations** → Simplified progress
4. **Navigator.push** → Phase transitions
5. **Scattered state** → Unified provider

### Features Removed
- Animated binder cards during stuffing
- "Add to Pay Day" modal
- Step-by-step wizard navigation
- Visual binder grouping in stuffing UI

### Features Added
- Account mode auto-detection
- Autopilot allocation strategy
- Real-time fuel calculations
- Unified cockpit interface
- Better account integration

---

*See README_OLD_FILES.md for usage notes*
