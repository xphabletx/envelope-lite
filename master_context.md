# Master Context - Stuffrite Development

**Last Updated:** January 6, 2026
**Branch:** main
**Latest Commit:** [Pending] - Onboarding & Strategy Overhaul with Adaptive Layouts

---

## Recent Major Changes

### Onboarding & Strategy Overhaul (January 6, 2026)
Complete transformation of the onboarding experience from passive tutorial into strategic briefing, with adaptive layouts and updated terminology aligned with Time Machine philosophy.

**New Onboarding Flow - Strategic Briefing:**

1. **Simulation Briefing (Step 0 - "Powering the Time Machine")**
   - Replaced animated currency examples with static 3-card briefing
   - Explains "Mastering the Wall" concept (External → Internal → External)
   - Three Pillar Cards:
     - ⚡ **Envelope Cash Flow** - "The Engine": Automates savings velocity
     - 🛡️ **Autopilot** - "The Shield": Automates bills crossing The Wall
     - 🔮 **Time Machine** - "The Dashboard": Projects future balances
   - "Initialize System" CTA button with rocket emoji
   - Adaptive layout prevents overflow on all screen sizes

2. **Binder Template Selection**
   - Added **"Start from Scratch"** option as selectable card
   - Changed "Skip" button from FilledButton to OutlinedButton (de-emphasized)
   - Fixed RenderFlex overflow with adaptive layout pattern
   - Scrollable when needed, button always visible

3. **Envelope Detail Entry (Binder Template Quick Setup)**
   - Updated all pro-tips to explain new concepts:
     - **Horizon Goal**: References Horizon Navigator for visual settings
     - **Autopilot**: Explains external spending crossing "The Wall"
     - **Auto-execute**: Dynamic tip changes based on toggle state
     - **Envelope Cash Flow**: Explains Master Cash Flow and "The Engine"
   - Fixed back button navigation to go to previous envelope (not selection)
   - Applied adaptive layout to prevent "20-pixel scroll" issue

4. **Completion Screen ("Systems Ready")**
   - Changed from "You're All Set 🎉" to "Systems Ready, [Name]! 🚀"
   - Status chips showing configured systems:
     - ✅ Cash Flow Configured
     - ✅ Autopilot Ready
     - ✅ Time Machine Initialized
   - Pro-tip directs to Horizon Visuals and Time Machine
   - "Enter the Cockpit →" CTA button

5. **Removed Steps**
   - **Target Emoji Picker** (Step 12) - removed entirely
   - Users configure celebration visuals later in Horizon Navigator

**Terminology Alignment (Complete Scrub):**
- "Pay Day Deposit" → **"Envelope Cash Flow"**
- "Recurring Bill" → **"Autopilot"**
- "Target" → **"Horizon"** (from previous commit)
- Consistent use of "Cash Flow → Autopilot → Time Machine" pipeline
- "Master Cash Flow" explained as total allocation to all envelopes

**Adaptive Layout Pattern Applied:**
- LayoutBuilder + SingleChildScrollView + ConstrainedBox + IntrinsicHeight
- Spacer() widget to pin buttons to bottom viewport
- Eliminates overflow issues on all screen sizes
- Consistent pattern across: Simulation Briefing, Binder Template Selection, Envelope Details, Completion

**Pro-Tips Updated (4 total):**
1. **Horizon Goal**: "You can adjust visual settings and milestones later in the Horizon Navigator"
2. **Autopilot**: "Handles external spending that crosses 'The Wall'—money leaving your internal strategy to pay bills in the outside world"
3. **Auto-Execute**: Dynamic tip - enabled: "No notification needed—it just happens!" / disabled: "You'll receive a notification when this payment is due"
4. **Envelope Cash Flow**: Explains Master Cash Flow concept, "The Engine" metaphor, and pay period division calculation

**Navigation Improvements:**
- **Back button in envelope details**: Now goes to previous envelope (not template selection)
- **PopScope wrapper**: Intercepts system back button with smart routing
  - First envelope: returns to template selection
  - Other envelopes: goes to previous envelope details

**Files Modified:**
- [consolidated_onboarding_flow.dart](lib/screens/onboarding/consolidated_onboarding_flow.dart): ~220 lines removed (emoji picker), adaptive layouts added, terminology updated
- [binder_template_quick_setup.dart](lib/widgets/binder/binder_template_quick_setup.dart): All pro-tips updated, back navigation fixed, adaptive layout applied

**Technical Implementation:**
- Removed `_EnvelopeMindsetStep` animation controllers and currency conversion logic
- Created `_buildPillarCard()` helper method for 3-card briefing
- Created `_buildStatusChip()` helper method for completion screen
- Added `_StartFromScratchCard` widget with distinctive styling
- Added `PopScope` with `onPopInvokedWithResult` for smart back navigation
- Applied adaptive layout pattern to 4 screens: Simulation Briefing, Template Selection, Envelope Details, Completion

**User Experience Impact:**
- Clear value proposition: Time Machine as core feature
- Educational flow explains "why" before "what"
- Reduced cognitive load with static briefing vs animations
- Consistent messaging reinforces Cash Flow → Autopilot → Time Machine pipeline
- Better mobile UX with proper scrolling and button visibility
- Intuitive back navigation in multi-envelope setup

---

### Horizon Navigator Strategy Dashboard (Commit: 7bbccfc)
Complete transformation of Multi Target Screen from manual calculator into intelligent strategy dashboard with auto-detection, simulation, and deployment capabilities.

**New Architecture - Three Zones:**

1. **Zone A: Strategy Dashboard (The Vision)**
   - Enhanced summary card with Financial Freedom Date (latest target)
   - On Track / Behind Schedule status badge with color coding
   - Strategy Delta showing time saved/added by current strategy
   - Weighted progress bars for both amount and time
   - Visual metaphor: "Financial Cockpit" showing strategy health at a glance

2. **Zone B: Velocity Slider (The Engine)**
   - Interactive Strategy Booster slider (0% to +100% boost)
   - Auto-detected baseline display (e.g., "£250/mo detected")
   - Bidirectional sync between slider and manual text input
   - Real-time simulation updates as slider moves
   - Visual feedback: faster/slower/baseline with color coding
   - Commit Strategy button to deploy sandbox to Cash Flow settings

3. **Zone C: Horizon List (unchanged but integrated)**
   - Individual envelope cards show real-time impact
   - Dates update dynamically as slider moves
   - Per-envelope time saved indicators

**Smart Baseline Engine:**
- Auto-detects contribution speed for each envelope
- Priority system:
  1. Cash Flow amount (if enabled)
  2. Most recent EXTERNAL inflow transaction from history
  3. Zero (stalled)
- Normalizes all speeds to monthly frequency
- Pre-fills total contribution with detected baseline

**User Flow:**
```
Discovery → Experimentation → Decision → Action
Current Reality → Sandbox Testing → Impact Analysis → Deploy Strategy
```

**Key Features:**
- **Smart Detection**: Scans Cash Flow + transaction history automatically
- **What-if Simulation**: Slider allows experimentation without commitment
- **Time Impact**: Shows exactly how many days/months/years saved or added
- **One-click Deploy**: "Commit Strategy" writes simulation to Cash Flow settings
- **Confirmation Dialog**: Preview changes before applying
- **Success Feedback**: Clear messaging when strategy is deployed

**Technical Implementation:**
- Added `transaction.dart` import for baseline detection from history
- New state variables: `_envelopeBaselines`, `_baselineTotal`, `_velocityMultiplier`, `_manualOverride`, `_baselineCalculated`
- New methods: `_calculateBaseline()`, `_normalizeToMonthly()`, `_calculateTimeSaved()`, `_formatDays()`, `_commitStrategy()`
- Integration with `EnvelopeRepo.getTransactionsForEnvelopeSync()` for history access
- Bidirectional sync: manual input ↔ velocity slider

**Files Modified:**
- [multi_target_screen.dart](lib/screens/envelope/multi_target_screen.dart): +604 lines, complete refactor

**Visual Improvements:**
- Removed divider line in summary card for cleaner separation
- Gradient-based Strategy Booster card with subtle elevation
- Color-coded status: green (on track), red (behind schedule), neutral (baseline)
- Celebration icon for Financial Freedom Date
- Trending indicators for time saved/lost

---

### Horizon Aesthetic Refactor (Commit: 46be4e6)
Complete refactoring from "Target" terminology to "Horizon" aesthetic, aligning with Philosophy of the Wall and Latte Love theme.

**New Widget Created:**
- **lib/widgets/horizon_progress.dart** - Rising Sun visualization widget
  - Replaces EmojiPieChart for envelope tiles
  - Sun rises as progress increases with latte brown → gold → yellow gradient
  - Percentage text positioned below horizon line for better visibility
  - Integrates with Time Machine for progress tracking

**Terminology Changes (Target → Horizon):**
- "Target Amount" → "Horizon Goal"
- "Target Date" → "Horizon Date"
- "Target Progress" → "Horizon Progress"
- "Target reached! 🎉" → "Horizon reached! ✨"
- "Target reached X days ago" → "Horizon reached X days ago 🌅"
- Pluralization fixes: "1 Horizon" vs "2 Horizons" (was "1 Targets")

**UI/UX Improvements:**
- Fixed color contrast in multi-target total card:
  - Amount value: primary → secondary (improved visibility)
  - Days left badge: enhanced contrast with secondary color scheme
  - Percentage complete: better visibility
- Fixed time progress calculation to properly track elapsed time
- Time machine integration: correctly shows progress from today to viewing date

**Files Updated (16 files):**
- Core widgets: [envelope_tile.dart](lib/widgets/envelope_tile.dart), [horizon_progress.dart](lib/widgets/horizon_progress.dart)
- Screens: [envelope_settings_sheet.dart](lib/screens/envelope/envelope_settings_sheet.dart), [multi_target_screen.dart](lib/screens/envelope/multi_target_screen.dart), [groups_home_screen.dart](lib/screens/groups_home_screen.dart), [modern_envelope_header_card.dart](lib/screens/envelope/modern_envelope_header_card.dart), [envelopes_detail_screen.dart](lib/screens/envelope/envelopes_detail_screen.dart), [envelope_creator.dart](lib/widgets/envelope_creator.dart)
- Services: [localization_service.dart](lib/services/localization_service.dart), [data_export_service.dart](lib/services/data_export_service.dart)
- Utils: [target_helper.dart](lib/utils/target_helper.dart) (all suggestion messages updated)
- Data: [tutorial_sequences.dart](lib/data/tutorial_sequences.dart), [faq_data.dart](lib/data/faq_data.dart)
- Templates: [binder_template_quick_setup.dart](lib/widgets/binder/binder_template_quick_setup.dart), [overview_cards.dart](lib/widgets/budget/overview_cards.dart)
- Onboarding: [consolidated_onboarding_flow.dart](lib/screens/onboarding/consolidated_onboarding_flow.dart)

**Visual Impact:**
- Horizon aesthetic provides visual metaphor of sunrise representing progress toward goals
- Consistent "✨" and "🌅" emojis replacing "🎉" and "🎯"
- Better color contrast and readability across all themes
- Accurate time tracking with Time Machine support

---

### Bug Fixes and Minor Improvements (ff35e9a - 23de64f)

**Calendar Icon Button (ff35e9a):**
- Added calendar icon button to custom date picker in envelope settings
- Improves discoverability of date selection feature

**Account Dropdown Fix (23de64f):**
- Fixed account dropdowns showing domain names instead of icons
- Proper icon display for account selection

**Welcome Screen Updates (51fec4c - caf8f34):**
- Display currency symbol instead of mail icon on Welcome screen
- Convert Welcome screen to ListView with fixed bottom button
- Reduce spacing to eliminate keyboard overflow
- Fix keyboard overflow with flexible layout

---

## Recent Development Timeline

### January 6, 2026
- **[Pending]**: Onboarding & Strategy Overhaul (complete UX transformation)
- **7bbccfc**: Horizon Navigator Strategy Dashboard (major UX transformation)
- **46be4e6**: Horizon aesthetic refactor (major UI/terminology update)
- **ff35e9a**: Calendar icon button added to date picker
- **23de64f**: Account dropdown icon fix

### January 5, 2026
- **51fec4c**: Currency symbol display on Welcome screen
- **caf8f34**: Welcome screen ListView conversion
- **f707b21**: Welcome screen spacing reduction
- **f316ffc**: Welcome screen keyboard overflow fix

### January 4, 2026
- **e7bd895**: Nested creation flows and icon picker improvements
- **fe7cf3f**: Binder template emoji override fix
- **ebb0c4e**: Onboarding screen scrolling fixes

### January 3, 2026
- **493c427**: Phase 3 - Visual Pay Day Stuffing with Binder-based Animation
- **e5a9079**: Debug logging for Hive adapter registration
- **90fd819**: CRITICAL FIX - Register new Hive enum adapters for EXTERNAL/INTERNAL
- **94b4b62**: EXTERNAL/INTERNAL implementation guide
- **3547221**: Phase 2 - Transaction creation points and philosophy-aligned FAB labels
- **3bc1b0a**: Phase 1 - EXTERNAL/INTERNAL transaction philosophy core data model
- **c6cff78**: Pre-refactor documentation for External/Internal transaction philosophy

---

## Key Development Philosophies

### Philosophy of the Wall
The app follows the "Philosophy of the Wall" - a visual and conceptual metaphor where:
- **The Wall**: Separation between external world and internal strategy
- **External → Internal → External**: Money arrives, is organized, then flows out
- **Envelopes**: Visualized as bricks in a wall (internal strategy)
- **The Three Pillars**:
  1. **Envelope Cash Flow** (The Engine): Automates savings velocity
  2. **Autopilot** (The Shield): Automates bills crossing The Wall
  3. **Time Machine** (The Dashboard): Projects future balances
- **Horizon Aesthetic**: Goals represented as sunrises on the horizon
- **Progress Visualization**: Sun rises toward horizon line
- **Latte Love Theme**: Warm, inviting color palette (latte brown → gold → yellow)

### Onboarding Philosophy
- **Education First**: Explain "why" before "what"
- **Strategic Briefing**: Position Time Machine as core value proposition
- **Consistent Messaging**: Reinforce Cash Flow → Autopilot → Time Machine pipeline
- **Adaptive Layouts**: Content fits any screen size, buttons always visible
- **Contextual Guidance**: Pro-tips appear when relevant, explain concepts clearly

### Visual Design Language
- **Horizon Progress**: Rising sun visualization for goal tracking
- **Emojis**: ✨ for achievements, 🌅 for time-based completions, 🚀 for system initialization
- **Color Scheme**: Warm latte browns transitioning to golds and yellows
- **Contrast**: All text elements optimized for readability across themes
- **Adaptive Layouts**: LayoutBuilder + SingleChildScrollView + ConstrainedBox + IntrinsicHeight pattern

---

## Important Technical Notes

### Recent Architecture Changes
1. **Onboarding Transformation** (January 6, 2026)
   - Simulation Briefing replaces animated currency examples
   - Adaptive layout pattern prevents overflow on all screens
   - PopScope navigation for smart back button routing
   - Pro-tips updated with new terminology and concepts
   - Target emoji picker step removed (moved to Horizon Navigator)

2. **EXTERNAL/INTERNAL Transaction Philosophy** (Phases 1-3 completed)
   - Core data model refactored to distinguish external vs internal transactions
   - New Hive enum adapters registered
   - Visual Pay Day Stuffing with binder-based animations implemented

3. **Horizon Widget System**
   - New [horizon_progress.dart](lib/widgets/horizon_progress.dart) replaces EmojiPieChart
   - Time Machine integration for accurate progress tracking
   - Gradient-based sun visualization

4. **Horizon Navigator Dashboard**
   - Smart Baseline Engine for auto-detecting contribution speeds
   - Three-zone UI: Strategy Dashboard + Velocity Slider + Horizon List
   - Sandbox simulation with real-time what-if analysis
   - One-click strategy deployment to Cash Flow settings
   - Transaction history integration for behavioral analysis

5. **Workspace Sync**
   - Binders (groups) now sync across workspaces
   - Improved StreamBuilder initialization to prevent loading spinners

### Adaptive Layout Pattern (Standard across onboarding)
```dart
LayoutBuilder(
  builder: (context, constraints) {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: IntrinsicHeight(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Content here
                const Spacer(), // Pushes button to bottom
                // Button here
              ],
            ),
          ),
        ),
      ),
    );
  },
)
```

---

## Next Context Update
When updating this file next time, include:
- New commits after the onboarding overhaul
- Any new features or bug fixes
- Architecture changes or refactors
- Breaking changes or migrations
