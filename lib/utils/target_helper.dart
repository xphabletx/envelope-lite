import '../models/envelope.dart';

class TargetHelper {
  /// Returns a formatted string explaining the target status
  /// e.g. "Save £50/week to reach target"
  static String getSuggestionText(Envelope envelope) {
    if (envelope.targetAmount == null || envelope.targetDate == null) {
      return "Set a target date to see tracking.";
    }

    final now = DateTime.now();
    final target = envelope.targetDate!;

    // Check if target is in the past
    if (target.isBefore(now)) {
      if (envelope.currentAmount >= envelope.targetAmount!) {
        return "Target reached! 🎉";
      } else {
        return "Target date passed.";
      }
    }

    final daysRemaining = target.difference(now).inDays;
    final amountNeeded = envelope.targetAmount! - envelope.currentAmount;

    if (amountNeeded <= 0) return "Target reached! 🎉";
    if (daysRemaining <= 0) return "Due today!";

    // Logic: If > 60 days, show Monthly. If > 14 days, show Weekly. Else Daily.
    if (daysRemaining > 60) {
      final months = daysRemaining / 30;
      final perMonth = amountNeeded / months;
      return "Save ${perMonth.toStringAsFixed(2)} / month";
    } else if (daysRemaining > 14) {
      final weeks = daysRemaining / 7;
      final perWeek = amountNeeded / weeks;
      return "Save ${perWeek.toStringAsFixed(2)} / week";
    } else {
      final perDay = amountNeeded / daysRemaining;
      return "Save ${perDay.toStringAsFixed(2)} / day";
    }
  }

  static int getDaysRemaining(Envelope envelope) {
    if (envelope.targetDate == null) return 0;
    return envelope.targetDate!.difference(DateTime.now()).inDays;
  }
}
