// lib/models/insight_data.dart
// Data model for Insight financial planning calculations

class InsightData {
  // HORIZON - Savings goal / wealth building
  bool horizonEnabled;
  double? horizonAmount;
  DateTime? horizonDate;

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

  InsightData({
    this.horizonEnabled = false,
    this.horizonAmount,
    this.horizonDate,
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
      final dateStr = horizonDate != null
          ? ' by ${horizonDate!.day}/${horizonDate!.month}/${horizonDate!.year}'
          : '';
      parts.add('🎯 Horizon: $currencySymbol${horizonAmount!.toStringAsFixed(2)}$dateStr');
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
  }) {
    return InsightData(
      horizonEnabled: horizonEnabled ?? this.horizonEnabled,
      horizonAmount: horizonAmount ?? this.horizonAmount,
      horizonDate: horizonDateCleared == true ? null : (horizonDate ?? this.horizonDate),
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
      warningMessage: warningMessage ?? this.warningMessage,
    );
  }

  @override
  String toString() {
    return 'InsightData(horizon: $horizonAmount, autopilot: $autopilotEnabled, cashFlow: $effectiveCashFlow)';
  }
}
