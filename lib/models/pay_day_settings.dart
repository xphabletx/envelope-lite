// lib/models/pay_day_settings.dart
import 'package:hive/hive.dart';

part 'pay_day_settings.g.dart';

@HiveType(typeId: 5)
class PayDaySettings {
  @HiveField(0)
  final String userId;

  @HiveField(1)
  final double? lastPayAmount; // Last amount user got paid (auto-saved)

  @HiveField(2)
  final String payFrequency; // 'weekly', 'biweekly', 'monthly', 'fourweekly'

  @HiveField(3)
  final int? payDayOfMonth; // 1-31 (for monthly frequency)

  @HiveField(4)
  final int? payDayOfWeek; // 1-7 (Monday-Sunday, for weekly)

  @HiveField(5)
  final DateTime? lastPayDate; // When they last ran Pay Day

  @HiveField(6)
  final String? defaultAccountId; // Which account receives Pay Day deposits

  @HiveField(7)
  final DateTime? nextPayDate; // Next expected pay date

  @HiveField(8)
  final double? expectedPayAmount; // Expected regular pay amount (take-home)

  @HiveField(9)
  final bool adjustForWeekends; // Move pay day to Friday if falls on weekend

  PayDaySettings({
    required this.userId,
    this.lastPayAmount,
    this.payFrequency = 'monthly',
    this.payDayOfMonth,
    this.payDayOfWeek,
    this.lastPayDate,
    this.defaultAccountId,
    this.nextPayDate,
    this.expectedPayAmount,
    this.adjustForWeekends = true,
  });

  /// Adjusts pay day to Friday if it falls on weekend
  DateTime adjustForWeekend(DateTime date) {
    // If Saturday (6), move back 1 day to Friday
    if (date.weekday == DateTime.saturday) {
      return date.subtract(const Duration(days: 1));
    }
    // If Sunday (7), move back 2 days to Friday
    if (date.weekday == DateTime.sunday) {
      return date.subtract(const Duration(days: 2));
    }
    // Weekday - no adjustment needed
    return date;
  }

  /// Calculate next pay date with weekend adjustment
  DateTime? getNextPayDateAdjusted() {
    final nextDate = getNextPayDate();
    if (nextDate == null) return null;
    return adjustForWeekend(nextDate);
  }

  PayDaySettings copyWith({
    double? lastPayAmount,
    String? payFrequency,
    int? payDayOfMonth,
    int? payDayOfWeek,
    DateTime? lastPayDate,
    String? defaultAccountId,
    DateTime? nextPayDate,
    double? expectedPayAmount,
    bool? adjustForWeekends,
  }) {
    return PayDaySettings(
      userId: userId,
      lastPayAmount: lastPayAmount ?? this.lastPayAmount,
      payFrequency: payFrequency ?? this.payFrequency,
      payDayOfMonth: payDayOfMonth ?? this.payDayOfMonth,
      payDayOfWeek: payDayOfWeek ?? this.payDayOfWeek,
      lastPayDate: lastPayDate ?? this.lastPayDate,
      defaultAccountId: defaultAccountId ?? this.defaultAccountId,
      nextPayDate: nextPayDate ?? this.nextPayDate,
      expectedPayAmount: expectedPayAmount ?? this.expectedPayAmount,
      adjustForWeekends: adjustForWeekends ?? this.adjustForWeekends,
    );
  }

  DateTime? getNextPayDate() {
    // If nextPayDate is explicitly set, use that
    if (nextPayDate != null) return nextPayDate;

    // Otherwise calculate from lastPayDate
    if (lastPayDate == null) return null;

    switch (payFrequency) {
      case 'weekly':
        return lastPayDate!.add(const Duration(days: 7));
      case 'biweekly':
        return lastPayDate!.add(const Duration(days: 14));
      case 'fourweekly':
        return lastPayDate!.add(const Duration(days: 28));
      case 'monthly':
        if (payDayOfMonth == null) return null;
        final nextMonth = DateTime(
          lastPayDate!.year,
          lastPayDate!.month + 1,
          payDayOfMonth!,
        );
        return nextMonth;
      default:
        return null;
    }
  }

  /// Calculate the next pay date from a given date based on frequency
  static DateTime calculateNextPayDate(DateTime startDate, String frequency) {
    switch (frequency) {
      case 'weekly':
        return startDate.add(const Duration(days: 7));
      case 'biweekly':
        return startDate.add(const Duration(days: 14));
      case 'fourweekly':
        return startDate.add(const Duration(days: 28));
      case 'monthly':
        return DateTime(
          startDate.year,
          startDate.month + 1,
          startDate.day,
        );
      default:
        return startDate;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'lastPayAmount': lastPayAmount,
      'payFrequency': payFrequency,
      'payDayOfMonth': payDayOfMonth,
      'payDayOfWeek': payDayOfWeek,
      'lastPayDate': lastPayDate?.millisecondsSinceEpoch,
      'defaultAccountId': defaultAccountId,
      'nextPayDate': nextPayDate?.millisecondsSinceEpoch,
      'expectedPayAmount': expectedPayAmount,
      'adjustForWeekends': adjustForWeekends,
    };
  }

  factory PayDaySettings.fromFirestore(Map<String, dynamic> data) {
    return PayDaySettings(
      userId: data['userId'] as String,
      lastPayAmount: data['lastPayAmount'] as double?,
      payFrequency: data['payFrequency'] as String? ?? 'monthly',
      payDayOfMonth: data['payDayOfMonth'] as int?,
      payDayOfWeek: data['payDayOfWeek'] as int?,
      lastPayDate: data['lastPayDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['lastPayDate'] as int)
          : null,
      defaultAccountId: data['defaultAccountId'] as String?,
      nextPayDate: data['nextPayDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['nextPayDate'] as int)
          : null,
      expectedPayAmount: data['expectedPayAmount'] as double?,
      adjustForWeekends: data['adjustForWeekends'] as bool? ?? true,
    );
  }

  @override
  String toString() {
    return 'PayDaySettings(userId: $userId, lastPay: $lastPayAmount, frequency: $payFrequency)';
  }
}
