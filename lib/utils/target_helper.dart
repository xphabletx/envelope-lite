// lib/utils/target_helper.dart
import 'package:flutter/foundation.dart';
import '../models/envelope.dart';

class TargetHelper {
  /// Returns a formatted string explaining the target status
  /// e.g. "Save £50.00 / week"
  ///
  /// Time Machine Support:
  /// - [projectedAmount]: The projected balance at the target date (from time machine)
  /// - [projectedDate]: The date being projected to (from time machine)
  ///
  /// When in time machine mode, this calculates progress based on projected values
  static String getSuggestionText(
    Envelope envelope,
    String currencySymbol, {
    double? projectedAmount,
    DateTime? projectedDate,
  }) {
    if (envelope.targetAmount == null || envelope.targetDate == null) {
      return "Set a target date to see tracking.";
    }

    // Use projected values if provided (time machine mode), otherwise use current values
    final currentAmount = projectedAmount ?? envelope.currentAmount;
    final referenceDate = projectedDate ?? DateTime.now();
    final target = envelope.targetDate!;

    // TIME MACHINE MODE: If we're viewing a future date
    if (projectedDate != null && projectedAmount != null) {
      return _getTimeMachineText(
        targetAmount: envelope.targetAmount!,
        targetDate: target,
        projectedAmount: projectedAmount,
        projectedDate: projectedDate,
        currencySymbol: currencySymbol,
      );
    }

    // REGULAR MODE: Standard target tracking
    // Check if target is in the past
    if (target.isBefore(referenceDate)) {
      if (currentAmount >= envelope.targetAmount!) {
        return "Target reached! 🎉";
      } else {
        return "Target date passed.";
      }
    }

    final daysRemaining = target.difference(referenceDate).inDays;
    final amountNeeded = envelope.targetAmount! - currentAmount;

    if (amountNeeded <= 0) return "Target reached! 🎉";
    if (daysRemaining <= 0) return "Due today!";

    // Logic: If > 60 days, show Monthly. If > 14 days, show Weekly. Else Daily.
    if (daysRemaining > 60) {
      final months = daysRemaining / 30;
      final perMonth = amountNeeded / months;
      return "Save $currencySymbol${perMonth.toStringAsFixed(2)} / month";
    } else if (daysRemaining > 14) {
      final weeks = daysRemaining / 7;
      final perWeek = amountNeeded / weeks;
      return "Save $currencySymbol${perWeek.toStringAsFixed(2)} / week";
    } else {
      final perDay = amountNeeded / daysRemaining;
      return "Save $currencySymbol${perDay.toStringAsFixed(2)} / day";
    }
  }

  /// Time machine specific target text
  static String _getTimeMachineText({
    required double targetAmount,
    required DateTime targetDate,
    required double projectedAmount,
    required DateTime projectedDate,
    required String currencySymbol,
  }) {
    debugPrint('[TargetHelper] ========================================');
    debugPrint('[TargetHelper] Calculating time machine text:');
    debugPrint('[TargetHelper]   Target Amount: $targetAmount');
    debugPrint('[TargetHelper]   Target Date: $targetDate');
    debugPrint('[TargetHelper]   Projected Amount: $projectedAmount');
    debugPrint('[TargetHelper]   Projected Date (viewing): $projectedDate');
    debugPrint('[TargetHelper]   Amount Met: ${projectedAmount >= targetAmount}');

    // Case 1: Projected date is exactly on target date
    if (_isSameDay(projectedDate, targetDate)) {
      if (projectedAmount >= targetAmount) {
        debugPrint('[TargetHelper]   Result: Will reach target on time!');
        debugPrint('[TargetHelper] ========================================');
        return "Will reach target on time! 🎉";
      } else {
        final shortfall = targetAmount - projectedAmount;
        debugPrint('[TargetHelper]   Result: Will be short by $shortfall');
        debugPrint('[TargetHelper] ========================================');
        return "Will be $currencySymbol${shortfall.toStringAsFixed(2)} short";
      }
    }

    // Case 2: Projected date is beyond target date
    if (projectedDate.isAfter(targetDate)) {
      debugPrint('[TargetHelper]   Viewing date is AFTER target date');
      if (projectedAmount >= targetAmount) {
        // Calculate when target was/will be reached
        // NOTE: This calculates days between viewing date and target DATE (not achievement date)
        final daysAfter = projectedDate.difference(targetDate).inDays;
        debugPrint('[TargetHelper]   Days after target DATE: $daysAfter');
        debugPrint('[TargetHelper]   Calculation: projectedDate ($projectedDate) - targetDate ($targetDate) = $daysAfter days');

        if (daysAfter == 0) {
          debugPrint('[TargetHelper]   Result: Target reached on due date!');
          debugPrint('[TargetHelper] ========================================');
          return "Target reached on due date! 🎉";
        } else if (daysAfter == 1) {
          debugPrint('[TargetHelper]   Result: Target reached 1 day ago');
          debugPrint('[TargetHelper] ========================================');
          return "Target reached 1 day ago 🎉";
        } else if (daysAfter < 30) {
          debugPrint('[TargetHelper]   Result: Target reached $daysAfter days ago');
          debugPrint('[TargetHelper] ========================================');
          return "Target reached $daysAfter days ago 🎉";
        } else {
          final monthsAfter = (daysAfter / 30).round();
          debugPrint('[TargetHelper]   Result: Target reached ${monthsAfter}mo ago');
          debugPrint('[TargetHelper] ========================================');
          return "Target reached ${monthsAfter}mo ago 🎉";
        }
      } else {
        final shortfall = targetAmount - projectedAmount;
        final daysOverdue = projectedDate.difference(targetDate).inDays;
        debugPrint('[TargetHelper]   Result: Will be short by $shortfall ($daysOverdue days overdue)');
        debugPrint('[TargetHelper] ========================================');
        return "Will be $currencySymbol${shortfall.toStringAsFixed(2)} short (${daysOverdue}d overdue)";
      }
    }

    // Case 3: Projected date is before target date
    if (projectedAmount >= targetAmount) {
      final daysEarly = targetDate.difference(projectedDate).inDays;
      if (daysEarly == 0) {
        return "On track to meet target! 🎉";
      } else if (daysEarly == 1) {
        return "Will reach target 1 day early! 🎉";
      } else if (daysEarly < 30) {
        return "Will reach target ${daysEarly}d early! 🎉";
      } else {
        final monthsEarly = (daysEarly / 30).round();
        return "Will reach target ${monthsEarly}mo early! 🎉";
      }
    } else {
      // Still progressing toward target
      final remaining = targetAmount - projectedAmount;
      final daysUntilTarget = targetDate.difference(projectedDate).inDays;

      if (daysUntilTarget <= 0) {
        return "On track, $currencySymbol${remaining.toStringAsFixed(2)} to go";
      } else if (daysUntilTarget < 7) {
        final perDay = remaining / daysUntilTarget;
        return "Need $currencySymbol${perDay.toStringAsFixed(2)}/day for ${daysUntilTarget}d";
      } else if (daysUntilTarget < 60) {
        final weeks = daysUntilTarget / 7;
        final perWeek = remaining / weeks;
        return "Need $currencySymbol${perWeek.toStringAsFixed(2)}/week";
      } else {
        final months = daysUntilTarget / 30;
        final perMonth = remaining / months;
        return "Need $currencySymbol${perMonth.toStringAsFixed(2)}/month";
      }
    }
  }

  static int getDaysRemaining(Envelope envelope, {DateTime? projectedDate}) {
    if (envelope.targetDate == null) return 0;
    final referenceDate = projectedDate ?? DateTime.now();
    return envelope.targetDate!.difference(referenceDate).inDays;
  }

  /// Get target progress percentage (0.0 to 1.0+)
  /// Returns > 1.0 if target is exceeded
  static double getProgress(Envelope envelope, {double? projectedAmount}) {
    if (envelope.targetAmount == null || envelope.targetAmount == 0) return 0.0;
    final amount = projectedAmount ?? envelope.currentAmount;
    return amount / envelope.targetAmount!;
  }

  /// Get amount exceeded beyond target (0 if not exceeded)
  static double getExceededAmount(Envelope envelope, {double? projectedAmount}) {
    if (envelope.targetAmount == null) return 0.0;
    final amount = projectedAmount ?? envelope.currentAmount;
    final exceeded = amount - envelope.targetAmount!;
    return exceeded > 0 ? exceeded : 0.0;
  }

  /// Check if target is met
  static bool isTargetMet(Envelope envelope, {double? projectedAmount}) {
    if (envelope.targetAmount == null) return false;
    final amount = projectedAmount ?? envelope.currentAmount;
    return amount >= envelope.targetAmount!;
  }

  /// Helper to check if two dates are the same day
  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
