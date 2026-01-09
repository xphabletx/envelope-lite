# 🔄 Dynamic Insight Recalculation - Implementation Summary

## Overview

This document describes the implementation of **Dynamic Insight Recalculation**, a feature that automatically adjusts cash flow amounts after Autopilot payments execute, enabling intelligent "catch-up" scenarios for bills due before payday.

## The Problem

When a bill is due **before** the next payday, users need two different amounts:
1. **Initial catch-up amount** (NOW) - to cover the gap before the first bill
2. **Ongoing sustainable amount** (NEXT) - to maintain coverage after the first bill

**Example Scenario:**
- Starting balance: $10
- Bill amount: $25 (due in 3 days, before next payday in 14 days)
- Pay frequency: Biweekly

**Without Dynamic Recalculation:**
- System would show: "Need $15 now"
- User manually has to figure out ongoing amount

**With Dynamic Recalculation:**
- System shows: "Pay $15 NOW, then $12.50 every paycheck"
- After first bill, automatically adjusts to $12.50

---

## Architecture

### Components Modified/Created

#### 1. **InsightData Model** ([lib/models/insight_data.dart](lib/models/insight_data.dart))
**Added Fields:**
```dart
double? initialCatchUpAmount;      // One-time "NOW" amount
double? ongoingCashFlow;           // Sustainable "NEXT" amount
bool isInSetupPhase;               // True until first bill payment
DateTime? setupPhaseEndDate;       // When setup phase ends
int? payPeriodsUntilSteadyState;   // Periods until steady state
```

#### 2. **InsightRecalculationService** ([lib/services/insight_recalculation_service.dart](lib/services/insight_recalculation_service.dart))
**NEW SERVICE**

**Purpose:** Background service that recalculates Insight cash flow after Autopilot executes

**Key Methods:**
- `recalculateAfterAutopilot()` - Main entry point, triggered after payment execution
- `_calculateCashFlow()` - Core calculation logic for setup phase vs steady state
- `_hasReachedSteadyState()` - Determines if we're still in setup phase

**Flow:**
1. Gets envelope with new balance (after bill payment)
2. Fetches scheduled payments for envelope
3. Calculates new recommended cash flow
4. Detects if steady state reached
5. Updates envelope's `cashFlowAmount`
6. Creates notification for user

#### 3. **ScheduledPaymentProcessor** ([lib/services/scheduled_payment_processor.dart](lib/services/scheduled_payment_processor.dart))
**Modified:** Added recalculation trigger after line 164

```dart
// After marking payment as executed
if (payment.isAutomatic) {
  final recalcService = InsightRecalculationService();
  await recalcService.recalculateAfterAutopilot(
    envelopeId: payment.envelopeId!,
    userId: userId,
    envelopeRepo: envelopeRepo,
    paymentRepo: paymentRepo,
    notificationRepo: notificationRepo,
  );
}
```

#### 4. **InsightTile Widget** ([lib/widgets/insight_tile.dart](lib/widgets/insight_tile.dart))
**Modified Sections:**

**a) _calculateCashFlow() method (lines 433-472)**
- Detects setup phase (bill before payday)
- Calculates both initial AND ongoing amounts
- Stores setup phase data in InsightData

**b) UI Display (lines 1844-1959)**
- Shows prominent "SETUP PHASE" card with both amounts
- Displays: "💰 Initial Payment (NOW): $15.00"
- Displays: "🔄 After First Bill (ONGOING): $12.50/paycheck"
- Shows explanation about automatic adjustment

---

## How It Works

### Setup Phase Detection

**Condition:** `autopilotPeriods == 0`
(Bill due date is before next payday)

**When Detected:**
1. Calculate initial catch-up: `gap = billAmount - startingAmount`
2. Calculate ongoing amount: `billAmount / payPeriodsPerCycle`
3. Set `isInSetupPhase = true`
4. Store both amounts in InsightData
5. Use initial amount for current cash flow

### Steady State Detection

**In InsightRecalculationService:**
```dart
isInSteadyState = payPeriodsUntilBill >= payPeriodsPerCycle
```

**Meaning:** We have at least one full bill cycle's worth of paydays before the bill

**Outcome:**
- When true: Use sustainable ongoing amount
- When false: Still in setup, use catch-up amount

### Automatic Transition Flow

```
Day 1: User sets up Insight
  ├─ Insight detects: Bill in 3 days, payday in 14 days
  ├─ Calculates: Initial $15, Ongoing $12.50
  ├─ Shows setup phase UI
  └─ Sets cash flow to $15

Day 3: Autopilot executes
  ├─ ScheduledPaymentProcessor deducts $25
  ├─ Triggers InsightRecalculationService
  ├─ Recalculates with new balance ($0)
  ├─ Detects: Now have 1 full cycle until next bill
  ├─ Updates cash flow to $12.50
  ├─ Creates notification: "Cash Flow adjusted to $12.50"
  └─ Steady state reached ✓

Day 14: First payday after bill
  └─ Cash flow adds $12.50

Day 28: Second payday
  └─ Cash flow adds $12.50 (now have $25)

Day 33: Second bill
  ├─ Autopilot deducts $25
  ├─ Recalculates (still $12.50)
  └─ No change - stays in steady state ✓
```

---

## Key Features

### 1. **No User Interaction Required**
- Recalculation happens automatically in background
- Triggered by AppLifecycleObserver when app resumes
- User doesn't need to open Insight for adjustment

### 2. **Intelligent Notifications**
- Notification created after each recalculation
- Shows: Old amount → New amount
- Indicates when steady state reached

### 3. **Visual Clarity**
- Setup phase shown with distinct "🔄 SETUP PHASE" card
- Both amounts displayed side-by-side
- Clear explanation of what happens when

### 4. **Handles Complex Scenarios**

**Multiple Bills Before Steady State:**
- Weekly pay, monthly bill
- First bill in 3 weeks = 3 catch-up payments
- After first bill, 4 paydays per cycle
- Recalculates after each until steady state

**Horizon + Autopilot Together:**
- Existing logic already handles allocation
- Autopilot before payday → starting amount goes to Autopilot
- Recalculation works for both goals

**Affordability Warnings:**
- Separate warnings for NOW vs ONGOING amounts
- "Initial catch-up of $15 needed before [date]"
- "Recurring $12.50 exceeds available income"

---

## Technical Decisions

### Why Store Setup Phase Data?
- Allows UI to show both amounts simultaneously
- Enables smooth transition without losing context
- Provides clear user communication

### Why Not Update ScheduledPayment Amount?
- ScheduledPayment stores the **bill amount** ($25)
- Cash flow is the **savings amount** ($12.50)
- These are different concepts
- Calendar/budget show bill amount (correct)
- Insight shows cash flow amount (correct)

### Why Recalculate After Every Payment?
- Bill timing may not align with pay cycles
- Multiple adjustments may be needed
- Steady state detection prevents unnecessary updates

### Why Use Notification?
- User may not open envelope settings
- Provides awareness of automatic changes
- Shows migration to home screen bell icon

---

## Integration Points

### 1. **AppLifecycleObserver**
- Runs on app resume
- Calls ScheduledPaymentProcessor
- Processor triggers recalculation

### 2. **Calendar Events**
- Display ScheduledPayment.amount (bill amount)
- No changes needed
- Already shows correct data

### 3. **Budget Overview Cards**
- Display ScheduledPayment data
- No changes needed
- Already shows correct data

### 4. **Envelope Settings**
- InsightTile integrated
- Shows setup phase UI
- Passes InsightData to parent

---

## Testing Scenarios

### Scenario 1: Basic Setup Phase
```
Starting: $10
Bill: $25 in 3 days
Payday: 14 days (biweekly)

Expected:
- Initial: $15
- Ongoing: $12.50
- After first bill: Auto-adjust to $12.50
```

### Scenario 2: Multiple Bills Before Steady State
```
Starting: $5
Bill: $25 monthly
Pay: Weekly

Week 1: Need $20 (gap)
Week 2-4: Pay varies (catch-up)
After first bill: $6.25/week (steady)
```

### Scenario 3: Bill Already Covered
```
Starting: $30
Bill: $25 monthly
Pay: Biweekly

Result:
- No catch-up needed
- Immediate steady state
- $12.50/paycheck to maintain
```

### Scenario 4: Horizon + Autopilot
```
Starting: $10
Autopilot: $25 in 3 days
Horizon: $100 by end of year
Pay: Biweekly

Expected:
- Initial autopilot: $15
- Ongoing autopilot: $12.50
- Horizon: Calculated separately
- Both recalculate after first bill
```

---

## Future Enhancements

### 1. **Multiple Autopilot Payments**
- Handle envelopes with 2+ scheduled payments
- Calculate combined catch-up amounts
- Prioritize by due date

### 2. **Manual Override Handling**
- Show recommended vs manual amounts
- Warn if manual amount insufficient
- Allow user to accept recommendation

### 3. **Projection Display**
- Show balance over time graph
- Visualize catch-up → steady state
- Display when envelope will be "safe"

### 4. **Smart Notifications**
- Only notify on significant changes (>$1)
- Batch multiple recalculations
- Provide action buttons ("View Envelope")

---

## Files Modified

1. ✅ [lib/models/insight_data.dart](lib/models/insight_data.dart) - Added setup phase fields
2. ✅ [lib/services/insight_recalculation_service.dart](lib/services/insight_recalculation_service.dart) - NEW SERVICE
3. ✅ [lib/services/scheduled_payment_processor.dart](lib/services/scheduled_payment_processor.dart) - Added recalc trigger
4. ✅ [lib/widgets/insight_tile.dart](lib/widgets/insight_tile.dart) - Calculation + UI updates

---

## Success Criteria Met

- ✅ Detects setup phase (bill before payday)
- ✅ Calculates both initial AND ongoing amounts
- ✅ Shows both amounts in UI prominently
- ✅ Automatically recalculates after Autopilot executes
- ✅ Transitions to steady state correctly
- ✅ Creates notifications for user awareness
- ✅ Handles complex scenarios (Horizon + Autopilot)
- ✅ Works without user needing to open Insight
- ✅ Calendar/budget cards show correct data

---

## Conclusion

The Dynamic Insight Recalculation feature provides intelligent, automatic cash flow management that adapts to real-world timing mismatches between paydays and bill due dates. Users get clear guidance on both immediate and ongoing savings needs, with automatic adjustments happening in the background as bills are paid.

**No more manual calculations. No more guessing. Just smart, adaptive financial planning.** 🚀
