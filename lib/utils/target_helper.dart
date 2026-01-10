// lib/utils/target_helper.dart
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
      return "Set a horizon date to see tracking.";
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
    // Check if horizon is in the past
    if (target.isBefore(referenceDate)) {
      if (currentAmount >= envelope.targetAmount!) {
        return "Horizon reached! ✨";
      } else {
        return "Horizon date passed.";
      }
    }

    final daysRemaining = target.difference(referenceDate).inDays;
    final amountNeeded = envelope.targetAmount! - currentAmount;

    if (amountNeeded <= 0) return "Horizon reached! ✨";
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

    // Case 1: Projected date is exactly on horizon date
    if (_isSameDay(projectedDate, targetDate)) {
      if (projectedAmount >= targetAmount) {
        return "Will reach horizon on time! ✨";
      } else {
        final shortfall = targetAmount - projectedAmount;
        return "Will be $currencySymbol${shortfall.toStringAsFixed(2)} short";
      }
    }

    // Case 2: Projected date is beyond horizon date
    if (projectedDate.isAfter(targetDate)) {
      if (projectedAmount >= targetAmount) {
        // Calculate when horizon was/will be reached
        // NOTE: This calculates days between viewing date and horizon DATE (not achievement date)
        final daysAfter = projectedDate.difference(targetDate).inDays;

        if (daysAfter == 0) {
          return "Horizon reached on due date! ✨";
        } else if (daysAfter == 1) {
          return "Horizon reached 1 day ago 🌅";
        } else if (daysAfter < 30) {
          return "Horizon reached $daysAfter days ago 🌅";
        } else {
          final monthsAfter = (daysAfter / 30).round();
          return "Horizon reached ${monthsAfter}mo ago 🌅";
        }
      } else {
        final shortfall = targetAmount - projectedAmount;
        final daysOverdue = projectedDate.difference(targetDate).inDays;
        return "Will be $currencySymbol${shortfall.toStringAsFixed(2)} short (${daysOverdue}d overdue)";
      }
    }

    // Case 3: Projected date is before horizon date
    if (projectedAmount >= targetAmount) {
      final daysEarly = targetDate.difference(projectedDate).inDays;
      if (daysEarly == 0) {
        return "On track to meet horizon! ✨";
      } else if (daysEarly == 1) {
        return "Will reach horizon 1 day early! ✨";
      } else if (daysEarly < 30) {
        return "Will reach horizon ${daysEarly}d early! ✨";
      } else {
        final monthsEarly = (daysEarly / 30).round();
        return "Will reach horizon ${monthsEarly}mo early! ✨";
      }
    } else {
      // Still progressing toward horizon
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

  /// Calculate granular time progress using microsecond precision
  /// Synchronized with ModernEnvelopeHeaderCard logic for consistent display
  ///
  /// Returns a value between 0.0 and 1.0 representing time elapsed
  static double calculateTimeProgress(
    Envelope envelope, {
    DateTime? referenceDate,
  }) {
    if (envelope.targetDate == null) return 0.0;

    final reference = referenceDate ?? DateTime.now();

    // Determine start date based on user's selected type
    DateTime startDate;
    final targetStartDateType = envelope.targetStartDateType ?? TargetStartDateType.fromToday;

    switch (targetStartDateType) {
      case TargetStartDateType.fromToday:
        // Start from beginning of TODAY (actual current date, not time machine date)
        final actualToday = DateTime.now();
        startDate = DateTime(
          actualToday.year,
          actualToday.month,
          actualToday.day,
          0, 0, 1,
        );
        break;

      case TargetStartDateType.fromEnvelopeCreation:
        // Use envelope creation date, or fallback to lastUpdated, or today
        if (envelope.createdAt != null) {
          startDate = DateTime(
            envelope.createdAt!.year,
            envelope.createdAt!.month,
            envelope.createdAt!.day,
            0, 0, 1,
          );
        } else if (envelope.lastUpdated != null) {
          // Fallback for legacy envelopes without createdAt
          startDate = DateTime(
            envelope.lastUpdated!.year,
            envelope.lastUpdated!.month,
            envelope.lastUpdated!.day,
            0, 0, 1,
          );
        } else {
          // Ultimate fallback - use today
          startDate = DateTime(
            reference.year,
            reference.month,
            reference.day,
            0, 0, 1,
          );
        }
        break;

      case TargetStartDateType.customDate:
        // Use custom date if provided, otherwise fallback to today
        if (envelope.customTargetStartDate != null) {
          startDate = DateTime(
            envelope.customTargetStartDate!.year,
            envelope.customTargetStartDate!.month,
            envelope.customTargetStartDate!.day,
            0, 0, 1,
          );
        } else {
          // Fallback if custom date not set
          startDate = DateTime(
            reference.year,
            reference.month,
            reference.day,
            0, 0, 1,
          );
        }
        break;
    }

    // Target date at midnight + 1 second (00:00:01)
    final targetWithTime = DateTime(
      envelope.targetDate!.year,
      envelope.targetDate!.month,
      envelope.targetDate!.day,
      0, 0, 1,
    );

    // FIXED: For date-based targets, calculate progress using whole days only
    // Normalize reference date to start of day to avoid intra-day time affecting progress
    final referenceDayStart = DateTime(
      reference.year,
      reference.month,
      reference.day,
      0, 0, 1,
    );

    // Calculate using whole days (not microseconds) for date-based targets
    final totalDuration = targetWithTime.difference(startDate);
    final elapsedDuration = referenceDayStart.difference(startDate);

    // DEBUG: Log time progress calculation with detailed breakdown

    // Progress based on whole days (date-based targets should not care about time of day)
    final progress = totalDuration.inDays > 0
        ? (elapsedDuration.inDays / totalDuration.inDays).clamp(0.0, 1.0)
        : 0.0;


    return progress;
  }

  /// Get the effective start date for a target envelope
  /// Used for displaying start date in UI
  static DateTime? getTargetStartDate(Envelope envelope) {
    if (envelope.targetDate == null) return null;

    final targetStartDateType = envelope.targetStartDateType ?? TargetStartDateType.fromToday;

    switch (targetStartDateType) {
      case TargetStartDateType.fromToday:
        final actualToday = DateTime.now();
        return DateTime(
          actualToday.year,
          actualToday.month,
          actualToday.day,
          0, 0, 1,
        );

      case TargetStartDateType.fromEnvelopeCreation:
        if (envelope.createdAt != null) {
          return DateTime(
            envelope.createdAt!.year,
            envelope.createdAt!.month,
            envelope.createdAt!.day,
            0, 0, 1,
          );
        } else if (envelope.lastUpdated != null) {
          return DateTime(
            envelope.lastUpdated!.year,
            envelope.lastUpdated!.month,
            envelope.lastUpdated!.day,
            0, 0, 1,
          );
        } else {
          final now = DateTime.now();
          return DateTime(now.year, now.month, now.day, 0, 0, 1);
        }

      case TargetStartDateType.customDate:
        if (envelope.customTargetStartDate != null) {
          return DateTime(
            envelope.customTargetStartDate!.year,
            envelope.customTargetStartDate!.month,
            envelope.customTargetStartDate!.day,
            0, 0, 1,
          );
        } else {
          final now = DateTime.now();
          return DateTime(now.year, now.month, now.day, 0, 0, 1);
        }
    }
  }
}
