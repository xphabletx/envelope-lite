// lib/models/pay_day_settings.dart
import 'package:cloud_firestore/cloud_firestore.dart';
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
  });

  factory PayDaySettings.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      return PayDaySettings(userId: doc.id);
    }

    return PayDaySettings(
      userId: doc.id,
      lastPayAmount: (data['lastPayAmount'] as num?)?.toDouble(),
      payFrequency: data['payFrequency'] as String? ?? 'monthly',
      payDayOfMonth: data['payDayOfMonth'] as int?,
      payDayOfWeek: data['payDayOfWeek'] as int?,
      lastPayDate: (data['lastPayDate'] as Timestamp?)?.toDate(),
      defaultAccountId: data['defaultAccountId'] as String?,
      nextPayDate: (data['nextPayDate'] as Timestamp?)?.toDate(),
      expectedPayAmount: (data['expectedPayAmount'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'lastPayAmount': lastPayAmount,
      'payFrequency': payFrequency,
      'payDayOfMonth': payDayOfMonth,
      'payDayOfWeek': payDayOfWeek,
      'lastPayDate': lastPayDate != null
          ? Timestamp.fromDate(lastPayDate!)
          : null,
      'defaultAccountId': defaultAccountId,
      'nextPayDate': nextPayDate != null
          ? Timestamp.fromDate(nextPayDate!)
          : null,
      'expectedPayAmount': expectedPayAmount,
      'updatedAt': FieldValue.serverTimestamp(),
    };
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

  @override
  String toString() {
    return 'PayDaySettings(userId: $userId, lastPay: $lastPayAmount, frequency: $payFrequency)';
  }
}
