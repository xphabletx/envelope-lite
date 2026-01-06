import 'package:flutter/material.dart';

enum AnalyticsFilter { cashIn, cashOut, net, growth }

enum AnalyticsPeriod {
  thisMonth,
  last3Months,
  last6Months,
  thisYear,
  allTime,
  custom,
}

extension AnalyticsPeriodExtension on AnalyticsPeriod {
  String get label {
    switch (this) {
      case AnalyticsPeriod.thisMonth:
        return 'This Month';
      case AnalyticsPeriod.last3Months:
        return 'Last 3 Months';
      case AnalyticsPeriod.last6Months:
        return 'Last 6 Months';
      case AnalyticsPeriod.thisYear:
        return 'This Year';
      case AnalyticsPeriod.allTime:
        return 'All Time';
      case AnalyticsPeriod.custom:
        return 'Custom';
    }
  }

  DateTimeRange getDateRange({DateTime? referenceDate}) {
    // Use reference date (for time machine) or current date
    final now = referenceDate ?? DateTime.now();
    switch (this) {
      case AnalyticsPeriod.thisMonth:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999),
        );
      case AnalyticsPeriod.last3Months:
        return DateTimeRange(
          start: DateTime(now.year, now.month - 3, now.day),
          end: now,
        );
      case AnalyticsPeriod.last6Months:
        return DateTimeRange(
          start: DateTime(now.year, now.month - 6, now.day),
          end: now,
        );
      case AnalyticsPeriod.thisYear:
        return DateTimeRange(
          start: DateTime(now.year, 1, 1),
          end: now,
        );
      case AnalyticsPeriod.allTime:
        return DateTimeRange(
          start: DateTime(2020, 1, 1), // Far past date
          end: now,
        );
      case AnalyticsPeriod.custom:
        return DateTimeRange(start: now, end: now); // Will be overridden
    }
  }
}

/// Data for a single segment in the donut chart
class ChartSegment {
  final String id; // Binder ID or Envelope ID
  final String name;
  final double amount;
  final Color color;
  final String? emoji;
  final bool isBinder;
  final String? parentBinderId; // If this is an envelope, which binder?

  ChartSegment({
    required this.id,
    required this.name,
    required this.amount,
    required this.color,
    this.emoji,
    this.isBinder = true,
    this.parentBinderId,
  });

  double getPercentage(double total) {
    if (total <= 0) return 0;
    return (amount / total) * 100;
  }
}

/// Horizon Strategy Stats - The "Wall" Philosophy Metrics
class HorizonStrategyStats {
  /// Total external inflow (money entering the system)
  final double externalInflow;

  /// Total external outflow (money leaving the system)
  final double externalOutflow;

  /// Net Impact (Income - Spending)
  final double netImpact;

  /// Efficiency ratio (what % of income was saved)
  final double efficiency;

  /// Total internal moves to Horizon envelopes (targetAmount != null)
  final double horizonVelocity;

  /// Total remaining gap across all Horizon envelopes
  final double totalHorizonGap;

  /// Horizon Impact: % of gap closed this period
  final double horizonImpact;

  /// Fixed Bills (external outflow from debt envelopes or autopilot)
  final double fixedBills;

  /// Discretionary spending (external outflow, non-fixed)
  final double discretionary;

  /// Internal moves to non-Horizon envelopes
  final double liquidCash;

  HorizonStrategyStats({
    required this.externalInflow,
    required this.externalOutflow,
    required this.netImpact,
    required this.efficiency,
    required this.horizonVelocity,
    required this.totalHorizonGap,
    required this.horizonImpact,
    required this.fixedBills,
    required this.discretionary,
    required this.liquidCash,
  });

  /// Get strategy feedback message based on efficiency
  String get strategyFeedback {
    // No Inflow/Outflow: Ready to launch state
    if (externalInflow == 0 && externalOutflow == 0) {
      return "🚀 Ready to Launch: Your financial story begins with your first transaction.";
    }

    // No Inflow but has Outflow: High friction warning
    if (externalInflow == 0 && externalOutflow > 0) {
      return "⚠️ High Friction: You have spending recorded with no income baseline.";
    }

    // Has Inflow, assess efficiency
    if (efficiency > 0.2) {
      return "🚀 High Efficiency: You're fueling your Horizons fast!";
    }
    if (efficiency > 0) {
      return "✅ Stable: You're living within your means.";
    }

    // Only show warning if we have inflow but spending exceeds it
    return "⚠️ Caution: Spending is outpacing your Inflow.";
  }

  /// Get feedback color based on efficiency
  Color getFeedbackColor(Color greenColor, Color goldColor, Color redColor) {
    if (efficiency > 0.2) return greenColor;
    if (efficiency > 0) return goldColor;
    return redColor;
  }

  /// Get Horizon Impact message
  String getHorizonImpactMessage() {
    // No horizons set (gap is 0 because there are no targets)
    if (totalHorizonGap == 0 && horizonVelocity == 0) {
      return "No Horizons Set: Define a goal in an envelope to track your progress.";
    }

    // All horizons reached
    if (totalHorizonGap <= 0 && horizonVelocity > 0) {
      return "🎉 All Horizons Reached!";
    }

    // Has horizons but no velocity this period
    if (horizonVelocity <= 0 && totalHorizonGap > 0) {
      return "No progress this period — Start moving funds to close the gap";
    }

    // Normal case: show progress percentage
    return "You closed ${horizonImpact.toStringAsFixed(1)}% of your savings gap this period";
  }

  /// Check if spending exceeded income (deficit)
  bool get isDeficit => externalOutflow > externalInflow;

  /// Calculate income allocation percentages for progress bar
  Map<String, double> getIncomeAllocation() {
    if (externalInflow <= 0) {
      return {'spent': 0, 'horizons': 0, 'liquid': 0};
    }

    double spentPercent = (externalOutflow / externalInflow).clamp(0.0, 1.0);
    double horizonsPercent = (horizonVelocity / externalInflow).clamp(0.0, 1.0 - spentPercent);
    double liquidPercent = (liquidCash / externalInflow).clamp(0.0, 1.0 - spentPercent - horizonsPercent);

    return {
      'spent': spentPercent,
      'horizons': horizonsPercent,
      'liquid': liquidPercent,
    };
  }
}
