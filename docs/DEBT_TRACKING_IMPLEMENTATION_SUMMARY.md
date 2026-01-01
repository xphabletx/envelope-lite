# Debt Tracking Implementation Summary

## Overview
This document summarizes the implementation of critical debt tracking features for Stuffrite (Stuffrite). The changes enable users to track debt payoff alongside savings goals, with visual progress indicators and time-based targets.

---

## ✅ COMPLETED: Data Model Updates

### 1. Envelope Model ([lib/models/envelope.dart](lib/models/envelope.dart))

**New Fields Added:**
```dart
// Debt tracking
@HiveField(20) final bool isDebtEnvelope;           // Marks envelope as debt tracker
@HiveField(21) final double? startingDebt;           // Original debt (e.g., -£5,000)

// Time-based loan terms
@HiveField(22) final DateTime? termStartDate;       // When loan started
@HiveField(23) final int? termMonths;                // Total term length (36 months)
@HiveField(24) final double? monthlyPayment;         // Expected monthly payment
```

**New Helper Methods:**
- `bool get isDebt` - Whether envelope has negative balance
- `double? get debtPayoffProgress` - Percentage of debt paid off (0.0-1.0)
- `double get remainingDebt` - Remaining debt amount (absolute value)
- `double get amountPaidOff` - Total amount paid from starting debt
- `double? get termProgress` - Percentage of term elapsed (0.0-1.0)
- `int? get monthsRemaining` - Months left in payment term
- `DateTime? get expectedCompletionDate` - When debt should be paid off
- `bool? get isOnTrack` - Whether payments are on schedule (90% threshold)

**Example Usage:**
```dart
// Create debt envelope
final creditCard = Envelope(
  id: uuid.v4(),
  name: 'Visa Credit Card',
  userId: userId,
  currentAmount: -3000.0,           // Current debt
  isDebtEnvelope: true,
  startingDebt: -5000.0,            // Started with £5k debt
  termStartDate: DateTime(2024, 1, 1),
  termMonths: 24,                   // 2-year payoff plan
  monthlyPayment: 250.0,
);

// Check progress
print('${creditCard.debtPayoffProgress! * 100}% paid off');  // "40% paid off"
print('${creditCard.monthsRemaining} months remaining');      // "18 months remaining"
print(creditCard.isOnTrack! ? 'On track!' : 'Behind schedule');
```

---

### 2. Account Model ([lib/models/account.dart](lib/models/account.dart))

**New Enum:**
```dart
@HiveType(typeId: 101)
enum AccountType {
  @HiveField(0) bankAccount,
  @HiveField(1) creditCard,
}
```

**New Fields Added:**
```dart
@HiveField(14) final AccountType accountType;   // Bank vs credit card
@HiveField(15) final double? creditLimit;        // Credit card limit
```

**New Helper Methods:**
- `bool get isCreditCard` - Whether this is a credit card account
- `bool get isDebt` - Whether account has negative balance
- `double get availableCredit` - Remaining credit available
- `double get creditUtilization` - Utilization percentage (0.0-1.0)

**Example Usage:**
```dart
// Create credit card account
final mastercard = Account(
  id: uuid.v4(),
  name: 'Mastercard',
  userId: userId,
  currentBalance: -2500.0,        // Owes £2,500
  accountType: AccountType.creditCard,
  creditLimit: 5000.0,
  createdAt: DateTime.now(),
  lastUpdated: DateTime.now(),
);

// Check credit status
print('Available: £${mastercard.availableCredit}');            // "£2,500"
print('Utilization: ${mastercard.creditUtilization * 100}%');  // "50%"
```

---

### 3. ScheduledPayment Model ([lib/models/scheduled_payment.dart](lib/models/scheduled_payment.dart))

**New Enum:**
```dart
@HiveType(typeId: 103)
enum ScheduledPaymentType {
  @HiveField(0) fixedAmount,      // Pay fixed amount (existing behavior)
  @HiveField(1) envelopeBalance,  // Pay full envelope balance
}
```

**New Fields Added:**
```dart
@HiveField(15) final ScheduledPaymentType paymentType;
@HiveField(16) final String? paymentEnvelopeId;  // Envelope to pull amount from
```

**Example Usage:**
```dart
// Fixed amount payment (traditional)
final rent = ScheduledPayment(
  id: uuid.v4(),
  userId: userId,
  name: 'Rent',
  amount: 1200.0,                         // Always pay £1,200
  paymentType: ScheduledPaymentType.fixedAmount,
  // ... other fields
);

// Dynamic envelope balance payment (NEW!)
final creditCardPayment = ScheduledPayment(
  id: uuid.v4(),
  userId: userId,
  name: 'Credit Card Payment',
  amount: 0.0,                            // Not used
  paymentType: ScheduledPaymentType.envelopeBalance,
  paymentEnvelopeId: 'cc-payment-envelope-id',  // Pay whatever is in this envelope
  // ... other fields
);
```

**Use Case:** User saves money throughout the month in a "Credit Card Payment" envelope. On payment day, the full balance is paid automatically, then the envelope is reset to £0.

---

## 🔧 BUILD SYSTEM

### Hive Adapters Regenerated
All model changes have been compiled with:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

**Status:** ✅ Complete - All adapters generated successfully

---

## 📋 REMAINING UI WORK

The following UI components need to be updated to support the new debt tracking features:

### 1. Envelope Tile Widget
**File:** [lib/widgets/envelope_tile.dart](lib/widgets/envelope_tile.dart)
**Changes Needed:**
- Add color coding for debt (red for negative balances)
- Display debt payoff progress instead of savings progress when `isDebtEnvelope == true`
- Show debt indicator icon (e.g., `Icons.trending_down`)

### 2. Envelope Detail Screen
**File:** [lib/screens/envelope/envelopes_detail_screen.dart](lib/screens/envelope/envelopes_detail_screen.dart)
**Changes Needed:**
- Add "Debt Payoff Progress" card showing:
  - Starting debt
  - Current debt
  - Amount paid off
  - Progress bar with percentage
- Add "Payment Term Progress" card showing:
  - Time elapsed / remaining
  - Expected completion date
  - On-track status indicator
  - Monthly payment info

### 3. Envelope Creator/Settings
**Files:**
- [lib/widgets/envelope_creator.dart](lib/widgets/envelope_creator.dart)
- [lib/screens/envelope/envelope_settings_sheet.dart](lib/screens/envelope/envelope_settings_sheet.dart)

**Changes Needed:**
- Add "Envelope Type" toggle (Savings vs Debt)
- When debt selected:
  - Show "Starting Debt Amount" field
  - Ensure currentAmount initializes to negative
- Add "Set Payment Term" toggle
- When term enabled:
  - Start date picker
  - Term length (years/months input)
  - Monthly payment amount
  - Summary display

### 4. Account Creation UI
**File:** [lib/screens/accounts/*](lib/screens/accounts/)
**Changes Needed:**
- Add account type selector (Bank Account vs Credit Card)
- When credit card selected:
  - Show "Credit Limit" field
  - Show "Current Balance" (allow negative)
  - Display credit utilization summary
  - Show available credit calculation

### 5. Account Detail Screen
**File:** [lib/screens/accounts/*](lib/screens/accounts/)
**Changes Needed:**
- For credit cards, show:
  - Current balance (red if negative)
  - Credit limit
  - Available credit
  - Utilization bar with color coding:
    - Green: 0-30%
    - Orange: 30-70%
    - Red: >70%
  - Utilization warning messages

### 6. Scheduled Payment UI
**File:** [lib/screens/add_scheduled_payment_screen.dart](lib/screens/add_scheduled_payment_screen.dart)
**Changes Needed:**
- Add payment type selector (Fixed Amount vs Envelope Balance)
- When "Envelope Balance" selected:
  - Hide amount input
  - Show envelope dropdown to select payment envelope
  - Display explanation text
  - Show current envelope balance as preview

### 7. Scheduled Payment Processor
**File:** Search for scheduled payment processing service
**Changes Needed:**
- Update payment execution to:
  1. Check `paymentType`
  2. If `envelopeBalance`, fetch amount from `paymentEnvelopeId`
  3. Process payment with dynamic amount
  4. Clear payment envelope after processing

---

## 🎨 UI DESIGN GUIDELINES

### Color Coding
- **Debt (negative):** Red text and icons
- **Goal reached:** Green text and icons
- **In progress:** Orange/amber text
- **On track:** Green indicators
- **Behind schedule:** Orange/red warnings

### Progress Indicators
- **Debt payoff:** Show inverse progress (debt decreasing = progress increasing)
- **Time-based:** Separate progress bar for term elapsed
- **Dual progress:** Some envelopes may show both debt payoff AND time progress

### Amount Formatting
```dart
String formatAmount(double amount) {
  final abs = amount.abs();
  final formatted = NumberFormat.currency(symbol: '£').format(abs);
  return amount < 0 ? '-$formatted' : formatted;
}
```

---

## 🧪 TESTING CHECKLIST

### Negative Balances
- [ ] Create debt envelope with -£5,000 starting balance
- [ ] Add payment (£100) → Balance updates to -£4,900
- [ ] Pie chart shows debt reduction progress (inverse)
- [ ] Red text displays for negative amounts

### Time Targets
- [ ] Create envelope with 36-month term
- [ ] Progress bar shows months elapsed
- [ ] Expected completion date calculates correctly
- [ ] "On track" indicator works with monthly payments

### Dynamic Scheduled Payments
- [ ] Create payment with fixed amount → processes correctly
- [ ] Create payment with envelope balance → fetches dynamic amount
- [ ] Payment envelope clears to £0 after processing
- [ ] Preview shows current envelope balance

### Credit Card Accounts
- [ ] Create credit card with £5k limit, -£2k balance
- [ ] Available credit shows £3k
- [ ] Utilization shows 40%
- [ ] Color changes based on utilization thresholds

### Edge Cases
- [ ] Debt payoff exceeds 100% (overpayment)
- [ ] Payment term with £0 monthly payment
- [ ] Envelope balance payment when envelope is empty
- [ ] Negative balance in bank account (overdraft)

---

## 📊 EXAMPLE USER FLOWS

### Flow 1: Credit Card Debt Payoff
1. User creates credit card account:
   - Type: Credit Card
   - Balance: -£3,000
   - Limit: £5,000

2. User creates debt envelope:
   - Name: "Visa Payoff"
   - Type: Debt
   - Starting Debt: -£3,000
   - Term: 18 months
   - Monthly Payment: £180

3. User creates payment envelope:
   - Name: "Credit Card Payment"
   - Type: Savings
   - User adds money throughout month

4. User creates scheduled payment:
   - Type: Envelope Balance
   - Payment Envelope: "Credit Card Payment"
   - Frequency: Monthly
   - Auto-execute: Yes

5. Each month:
   - Scheduled payment pulls full balance from payment envelope
   - Applies to debt envelope (reduces negative balance)
   - Payment envelope resets to £0
   - User sees progress: "12% paid off, 16 months remaining"

### Flow 2: Car Loan Tracking
1. User creates debt envelope:
   - Name: "Car Loan"
   - Type: Debt
   - Starting Debt: -£15,000
   - Term: 60 months (5 years)
   - Monthly Payment: £300
   - Start Date: Jan 1, 2024

2. Each month user makes payment:
   - Current balance: -£15,000 → -£14,700
   - Progress: "2% paid off, 59 months remaining"
   - Status: "✅ On track with payments"

3. After 12 months:
   - Current balance: -£11,400
   - Progress: "24% paid off, 48 months remaining"
   - Time progress: "20% of term elapsed"

---

## 🚀 DEPLOYMENT NOTES

### Database Migration
- All new fields have default values (backwards compatible)
- Existing envelopes: `isDebtEnvelope = false`
- Existing accounts: `accountType = bankAccount`
- Existing payments: `paymentType = fixedAmount`
- No migration script required

### Feature Flags
Consider adding a feature flag for gradual rollout:
```dart
static const bool DEBT_TRACKING_ENABLED = true;
```

### Marketing Impact
These features enable:
- "Debt-free journey" testimonials
- Before/after progress screenshots
- Credit score improvement tracking
- Visual payoff timelines for social media

---

## 📝 IMPLEMENTATION NOTES

### Why Two Progress Bars?
1. **Debt Progress:** Shows how much of the original debt has been paid
2. **Time Progress:** Shows how much of the loan term has elapsed

These can diverge:
- Paying extra → Debt progress ahead of time progress ✅
- Paying less → Debt progress behind time progress ⚠️

### Envelope Balance Payments
Perfect for:
- Credit cards (variable balance)
- Utility bills (variable amounts)
- Savings transfers (pay whatever you saved)

### Credit Utilization
Keeping utilization <30% is ideal for credit scores. The color-coded indicator helps users stay healthy.

---

## 🎯 SUCCESS METRICS

Track these metrics after launch:
- % of users creating debt envelopes
- Average debt reduction over 3/6/12 months
- Engagement with time-based targets
- Usage of envelope balance payments
- Credit card account adoption

---

## 🐛 KNOWN LIMITATIONS

1. **No partial payments in envelope balance mode**
   - Current: Pays full envelope balance
   - Future: Add "Pay up to X% of balance" option

2. **No debt consolidation tracking**
   - Current: Each debt is separate
   - Future: Link multiple debts to show combined progress

3. **No interest calculation**
   - Current: Simple balance tracking
   - Future: Add APR field and calculate interest accrual

4. **No payment history forecasting**
   - Current: Only shows current status
   - Future: Project payoff date based on actual payment history

---

## 📞 NEXT STEPS

1. **Implement UI changes** (see "Remaining UI Work" section)
2. **Add analytics** to track feature adoption
3. **Write tests** for debt calculation helpers
4. **User testing** with debt payoff scenarios
5. **Documentation** in user-facing help center
6. **Marketing assets** showcasing debt tracking

---

**Document Version:** 1.0
**Last Updated:** 2025-12-26
**Implementation Status:** Models ✅ | UI ⏳ | Testing ⏳
