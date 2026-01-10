// lib/models/insight_data.dart
// Data model for Insight financial planning calculations

import 'envelope.dart';

class InsightData {
  // HORIZON - Savings goal / wealth building
  bool horizonEnabled;
  double? horizonAmount;
  DateTime? horizonDate;

  // NEW: Percentage allocation mode support
  HorizonAllocationMode? horizonMode;
  double? horizonPercentage;  // User's selected percentage
  double? horizonFixedAmount;  // User's selected fixed amount per payday (for fixed amount mode)
  DateTime? projectedArrivalDate;  // Calculated arrival date
  double? projectedMonthlyContribution;  // Calculated contribution amount

  // AUTOPILOT - Recurring bills
  bool autopilotEnabled;
  double? autopilotAmount;
  String autopilotFrequency; // 'weekly', 'biweekly', 'monthly', 'yearly'
  int? autopilotDayOfMonth; // For monthly (1-31)
  DateTime? autopilotFirstDate; // For non-monthly or specific start date
  bool autopilotAutoExecute;

  // CASH FLOW - Calculated savings plan
  bool cashFlowEnabled;
  double? calculatedCashFlow; // Auto-calculated amount
  double? manualCashFlowOverride; // User can override with manual amount

  // METADATA - Calculation insights
  int? payPeriodsToHorizon;
  int? payPeriodsToAutopilot;
  double? percentageOfIncome;
  double? availableIncome;
  bool isAffordable;
  String? warningMessage;

  // COVERAGE - Smart autopilot analysis when starting amount >= bill amount
  int? autopilotPaymentsCovered; // Number of payments fully covered by starting amount
  bool? autopilotAlwaysCovered; // True if cash flow always keeps balance above bill amount
  String? coverageSuggestion; // Intelligent suggestion based on coverage analysis

  // DYNAMIC RECALCULATION - Setup phase support for bills due before payday
  double? initialCatchUpAmount; // One-time "NOW" amount needed to reach first bill
  double? ongoingCashFlow; // Sustainable "NEXT" amount after first bill is paid
  bool isInSetupPhase; // True until first bill payment creates steady state
  DateTime? setupPhaseEndDate; // When setup phase ends (first autopilot payment date)
  int? payPeriodsUntilSteadyState; // How many pay periods until steady state achieved

  InsightData({
    this.horizonEnabled = false,
    this.horizonAmount,
    this.horizonDate,
    this.horizonMode,
    this.horizonPercentage,
    this.horizonFixedAmount,
    this.projectedArrivalDate,
    this.projectedMonthlyContribution,
    this.autopilotEnabled = false,
    this.autopilotAmount,
    this.autopilotFrequency = 'monthly',
    this.autopilotDayOfMonth,
    this.autopilotFirstDate,
    this.autopilotAutoExecute = true, // CHANGED: Default to true
    this.cashFlowEnabled = true, // CHANGED: Default to true
    this.calculatedCashFlow,
    this.manualCashFlowOverride,
    this.payPeriodsToHorizon,
    this.payPeriodsToAutopilot,
    this.percentageOfIncome,
    this.availableIncome,
    this.isAffordable = true,
    this.warningMessage,
    this.autopilotPaymentsCovered,
    this.autopilotAlwaysCovered,
    this.coverageSuggestion,
    this.initialCatchUpAmount,
    this.ongoingCashFlow,
    this.isInSetupPhase = false,
    this.setupPhaseEndDate,
    this.payPeriodsUntilSteadyState,
  });

  /// Get the effective cash flow amount (manual override takes precedence)
  double? get effectiveCashFlow {
    if (manualCashFlowOverride != null && manualCashFlowOverride! > 0) {
      return manualCashFlowOverride;
    }
    return calculatedCashFlow;
  }

  /// Check if user is using manual override
  bool get isManualOverride {
    return manualCashFlowOverride != null && manualCashFlowOverride! > 0;
  }

  /// Check if any insight data is configured
  bool get hasAnyData {
    return (horizonEnabled && horizonAmount != null && horizonAmount! > 0) ||
        (autopilotEnabled && autopilotAmount != null && autopilotAmount! > 0);
  }

  /// Get a summary string for collapsed state
  String getSummary(String currencySymbol) {
    final parts = <String>[];

    if (cashFlowEnabled && effectiveCashFlow != null && effectiveCashFlow! > 0) {
      final percentage = percentageOfIncome != null
          ? ' (${percentageOfIncome!.toStringAsFixed(1)}%)'
          : '';
      parts.add('💰 Cash Flow: $currencySymbol${effectiveCashFlow!.toStringAsFixed(2)}/paycheck$percentage');
    }

    if (horizonEnabled && horizonAmount != null && horizonAmount! > 0) {
      if (horizonMode == HorizonAllocationMode.percentage && horizonPercentage != null) {
        final projectedStr = projectedArrivalDate != null
            ? ' → arrive by ${projectedArrivalDate!.day}/${projectedArrivalDate!.month}/${projectedArrivalDate!.year}'
            : '';
        parts.add('🎯 Horizon: ${horizonPercentage!.toStringAsFixed(0)}% of income$projectedStr');
      } else if (horizonMode == HorizonAllocationMode.fixedAmount) {
        final projectedStr = projectedArrivalDate != null
            ? ' → arrive by ${projectedArrivalDate!.day}/${projectedArrivalDate!.month}/${projectedArrivalDate!.year}'
            : '';
        final amountStr = calculatedCashFlow != null
            ? '$currencySymbol${calculatedCashFlow!.toStringAsFixed(2)}/payday'
            : '';
        parts.add('🎯 Horizon: $amountStr$projectedStr');
      } else {
        // Date mode
        final dateStr = horizonDate != null
            ? ' by ${horizonDate!.day}/${horizonDate!.month}/${horizonDate!.year}'
            : '';
        parts.add('🎯 Horizon: $currencySymbol${horizonAmount!.toStringAsFixed(2)}$dateStr');
      }
    }

    if (autopilotEnabled && autopilotAmount != null && autopilotAmount! > 0) {
      final freqLabel = _getFrequencyLabel(autopilotFrequency);
      parts.add('⚡ Autopilot: $currencySymbol${autopilotAmount!.toStringAsFixed(2)} $freqLabel');
    }

    return parts.isEmpty ? 'Tap to set up savings & bills' : parts.join('\n');
  }

  String _getFrequencyLabel(String frequency) {
    switch (frequency) {
      case 'weekly':
        return 'weekly';
      case 'biweekly':
        return 'bi-weekly';
      case 'fourweekly':
        return 'every 4 weeks';
      case 'monthly':
        return 'monthly';
      case 'yearly':
        return 'yearly';
      default:
        return frequency;
    }
  }

  InsightData copyWith({
    bool? horizonEnabled,
    double? horizonAmount,
    DateTime? horizonDate,
    bool? horizonDateCleared,
    HorizonAllocationMode? horizonMode,
    double? horizonPercentage,
    double? horizonFixedAmount,
    DateTime? projectedArrivalDate,
    double? projectedMonthlyContribution,
    bool? autopilotEnabled,
    double? autopilotAmount,
    String? autopilotFrequency,
    int? autopilotDayOfMonth,
    DateTime? autopilotFirstDate,
    bool? autopilotFirstDateCleared,
    bool? autopilotAutoExecute,
    bool? cashFlowEnabled,
    double? calculatedCashFlow,
    double? manualCashFlowOverride,
    bool? manualOverrideCleared,
    int? payPeriodsToHorizon,
    int? payPeriodsToAutopilot,
    double? percentageOfIncome,
    double? availableIncome,
    bool? isAffordable,
    String? warningMessage,
    int? autopilotPaymentsCovered,
    bool? autopilotAlwaysCovered,
    String? coverageSuggestion,
    double? initialCatchUpAmount,
    double? ongoingCashFlow,
    bool? isInSetupPhase,
    DateTime? setupPhaseEndDate,
    bool? setupPhaseEndDateCleared,
    int? payPeriodsUntilSteadyState,
    bool updateWarning = true, // Flag to indicate we're explicitly updating the warning
  }) {

    final newData = InsightData(
      horizonEnabled: horizonEnabled ?? this.horizonEnabled,
      horizonAmount: horizonAmount ?? this.horizonAmount,
      horizonDate: horizonDateCleared == true ? null : (horizonDate ?? this.horizonDate),
      horizonMode: horizonMode ?? this.horizonMode,
      horizonPercentage: horizonPercentage ?? this.horizonPercentage,
      horizonFixedAmount: horizonFixedAmount ?? this.horizonFixedAmount,
      projectedArrivalDate: projectedArrivalDate ?? this.projectedArrivalDate,
      projectedMonthlyContribution: projectedMonthlyContribution ?? this.projectedMonthlyContribution,
      autopilotEnabled: autopilotEnabled ?? this.autopilotEnabled,
      autopilotAmount: autopilotAmount ?? this.autopilotAmount,
      autopilotFrequency: autopilotFrequency ?? this.autopilotFrequency,
      autopilotDayOfMonth: autopilotDayOfMonth ?? this.autopilotDayOfMonth,
      autopilotFirstDate: autopilotFirstDateCleared == true
          ? null
          : (autopilotFirstDate ?? this.autopilotFirstDate),
      autopilotAutoExecute: autopilotAutoExecute ?? this.autopilotAutoExecute,
      cashFlowEnabled: cashFlowEnabled ?? this.cashFlowEnabled,
      calculatedCashFlow: calculatedCashFlow ?? this.calculatedCashFlow,
      manualCashFlowOverride: manualOverrideCleared == true
          ? null
          : (manualCashFlowOverride ?? this.manualCashFlowOverride),
      payPeriodsToHorizon: payPeriodsToHorizon ?? this.payPeriodsToHorizon,
      payPeriodsToAutopilot: payPeriodsToAutopilot ?? this.payPeriodsToAutopilot,
      percentageOfIncome: percentageOfIncome ?? this.percentageOfIncome,
      availableIncome: availableIncome ?? this.availableIncome,
      isAffordable: isAffordable ?? this.isAffordable,
      // Use new warning value when explicitly updating (even if null), otherwise keep old value
      warningMessage: updateWarning ? warningMessage : (warningMessage ?? this.warningMessage),
      autopilotPaymentsCovered: autopilotPaymentsCovered ?? this.autopilotPaymentsCovered,
      autopilotAlwaysCovered: autopilotAlwaysCovered ?? this.autopilotAlwaysCovered,
      coverageSuggestion: coverageSuggestion ?? this.coverageSuggestion,
      initialCatchUpAmount: initialCatchUpAmount ?? this.initialCatchUpAmount,
      ongoingCashFlow: ongoingCashFlow ?? this.ongoingCashFlow,
      isInSetupPhase: isInSetupPhase ?? this.isInSetupPhase,
      setupPhaseEndDate: setupPhaseEndDateCleared == true
          ? null
          : (setupPhaseEndDate ?? this.setupPhaseEndDate),
      payPeriodsUntilSteadyState: payPeriodsUntilSteadyState ?? this.payPeriodsUntilSteadyState,
    );

    return newData;
  }

  @override
  String toString() {
    return 'InsightData(horizon: $horizonAmount, autopilot: $autopilotEnabled, cashFlow: $effectiveCashFlow)';
  }
}
