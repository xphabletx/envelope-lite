# Cockpit Preview Enhancements Guide

## ✅ Completed Changes (Already in cockpit_preview.dart)
1. Added `_horizonBoosts` Map to track boost percentages (0.0-1.0)
2. Added `getTotalBoostAmount()` and `getEnvelopeBoostAmount()` methods
3. Added `updateCashFlowAmount()` and `updateHorizonBoost()` methods  
4. Updated `_animateGoldBoost()` to use horizon boost percentages

## 🚧 Remaining Enhancements Needed

### 1. Enhanced Phase 2 Strategy Review Screen

**Location**: Replace the `_buildPhase2StrategyReview()` method (~line 700)

**Key Features to Add**:
- **Section 1: Cash Flow Allocations**
  - Show ALL envelopes (not just cash-flow enabled)
  - Each row has: Checkbox | Emoji | Name | Editable TextField (\$amount)
  - TextField uses `NumberFormat.currency(symbol: '\$', decimalDigits: 0)`
  - Gray out/mark envelopes not in autopilot with italic text
  - TextField `onChanged` calls `_provider.updateCashFlowAmount(envelope.id, newAmount)`

- **Section 2: Horizon Boosts** (Distinctive golden container)
  - Golden/amber gradient background with rocket icon
  - For each envelope WITH targetAmount:
    - Row: Emoji | Name | Percentage badge
    - Slider: 0-100% (20 divisions for 5% increments)
    - `onChanged` calls `_provider.updateHorizonBoost(envelope.id, value)`
    - Below slider: Show boost amount and days saved in real-time
  - Top of section: "Total Boost Gauge" showing % of available fuel allocated

**Complete code**: See `/tmp/phase2_enhanced.dart` (292 lines)

### 2. Auto-Scroll in Phase 3 Waterfall

**Location**: `_buildPhase3WaterfallExecution()` method (~line 886)

**Changes Needed**:
```dart
// Add to _CockpitPreviewState class:
final ScrollController _scrollController = ScrollController();

@override
void dispose() {
  _scrollController.dispose();
  super.dispose();
}

// In _buildPhase3WaterfallExecution(), wrap ListView with:
ListView.builder(
  controller: _scrollController,  // ADD THIS
  padding: const EdgeInsets.all(16),
  itemCount: envelopesToStuff.length,
  itemBuilder: (context, index) {
    // existing code
  },
)

// Add listener to provider in initState:
_provider.addListener(() {
  if (_provider.currentEnvelopeIndex >= 0 && _scrollController.hasClients) {
    _scrollController.animateTo(
      _provider.currentEnvelopeIndex * 160.0, // envelope tile height
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }
});
```

### 3. Fix Envelope Tile Layout (HorizonProgress on RIGHT)

**Location**: `StuffingEnvelopeRowCockpit` widget (~line 1170)

**Current Layout**: Emoji | Name | HorizonProgress | Amount  
**Needed Layout**: Emoji | Name | Amount | HorizonProgress (RIGHT)

**Change**:
```dart
Row(
  children: [
    HorizonProgress(...), // MOVE THIS TO END
    SizedBox(width: 16),
    Text(envelope.emoji, ...),
    SizedBox(width: 16),
    Expanded(child: Column(...)), // Name and info
    Text('\$...', ...), // Amount
    SizedBox(width: 16),
    HorizonProgress(percentage: progress, size: 50), // ADD HERE (right side)
  ],
)
```

### 4. Clickable Future Recalibrated Cards (Phase 4)

**Location**: `_buildPhase4FutureRecalibrated()` (~line 1050)

**Wrap each `_buildSuccessMetric()` with GestureDetector**:

```dart
GestureDetector(
  onTap: () => _showDaysSavedDetail(),
  child: _buildSuccessMetric(...),
)
```

**Add three modal methods**:

```dart
void _showDaysSavedDetail() {
  showModalBottomSheet(
    context: context,
    builder: (context) => Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text('Days Saved Breakdown', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: _provider.allEnvelopes.where((e) => _provider.stuffingProgress.containsKey(e.id)).map((envelope) {
                final daysSaved = _calculateEnvelopeDaysSaved(envelope);
                return ListTile(
                  leading: Text(envelope.emoji, style: TextStyle(fontSize: 32)),
                  title: Text(envelope.name),
                  trailing: Text('$daysSaved days', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    ),
  );
}

void _showFuelEfficiencyDetail() {
  final autopilotTotal = _provider.autopilotReserve;
  final boostTotal = _provider.getTotalBoostAmount();
  
  showModalBottomSheet(
    context: context,
    builder: (context) => Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text('Fuel Efficiency Breakdown', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          SizedBox(height: 24),
          _buildEfficiencyBar('Autopilot', autopilotTotal, _provider.externalInflow, Colors.blue),
          SizedBox(height: 16),
          _buildEfficiencyBar('Horizon Boost', boostTotal, _provider.externalInflow, Colors.amber),
        ],
      ),
    ),
  );
}

void _showHorizonAdvancementDetail() {
  showModalBottomSheet(
    context: context,
    builder: (context) => Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text('Horizon Advancement', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: _provider.allEnvelopes.where((e) => !e.isNeed && e.targetAmount != null).map((envelope) {
                final stuffed = _provider.stuffingProgress[envelope.id] ?? 0.0;
                final progressGain = (stuffed / envelope.targetAmount!) * 100;
                return ListTile(
                  leading: Text(envelope.emoji, style: TextStyle(fontSize: 32)),
                  title: Text(envelope.name),
                  trailing: Text('+${progressGain.toStringAsFixed(1)}%', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    ),
  );
}
```

### 5. Add Helper Method for Days Saved Calculation

**Location**: Add to `_CockpitPreviewState` class

```dart
int _calculateEnvelopeDaysSaved(MockEnvelope envelope) {
  final stuffedAmount = _provider.stuffingProgress[envelope.id] ?? 0.0;
  if (envelope.targetAmount == null || stuffedAmount == 0) return 0;

  final monthlyVelocity = envelope.cashFlowAmount ?? 0.0;
  if (monthlyVelocity <= 0) return 0;

  final oldDays = (envelope.targetAmount! - envelope.currentAmount) / (monthlyVelocity / 30.44);
  final newDays = (envelope.targetAmount! - (envelope.currentAmount + stuffedAmount)) / (monthlyVelocity / 30.44);

  return (oldDays - newDays).round();
}
```

## Summary of Changes

| Feature | Lines of Code | Complexity | Priority |
|---------|--------------|------------|----------|
| Enhanced Phase 2 UI | ~300 lines | High | ⭐⭐⭐ Critical |
| Auto-scroll | ~15 lines | Low | ⭐⭐ Important |
| Tile layout fix | ~10 lines | Low | ⭐⭐ Important |
| Clickable Phase 4 | ~80 lines | Medium | ⭐ Nice-to-have |

## Testing Checklist

After implementing:
- [ ] Phase 2: Can edit cash flow amounts, see totals update
- [ ] Phase 2: Can toggle envelopes on/off
- [ ] Phase 2: Horizon boost sliders work, show days saved
- [ ] Phase 2: Total boost gauge updates correctly
- [ ] Phase 3: Envelopes auto-scroll into view as they fill
- [ ] Phase 3: HorizonProgress appears on right side
- [ ] Phase 3: Gold boost animates on boosted envelopes only
- [ ] Phase 4: Can click cards to see detailed breakdowns
- [ ] Phase 4: Metrics are accurate

## Integration Steps

1. **Backup current file**: Already done (`cockpit_preview_backup.dart`)
2. **Replace Phase 2 method**: Use code from `/tmp/phase2_enhanced.dart`
3. **Add ScrollController**: Follow "Auto-Scroll" section above
4. **Fix tile layout**: Reorder Row children in `StuffingEnvelopeRowCockpit`
5. **Add clickable cards**: Wrap metrics with GestureDetector, add modal methods
6. **Test thoroughly**: Run through all 4 phases

