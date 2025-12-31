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
