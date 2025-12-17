// lib/models/pay_day_settings.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class PayDaySettings {
  final String userId;
  final double? lastPayAmount; // Last amount user got paid (auto-saved)
  final String payFrequency; // 'weekly', 'biweekly', 'monthly'
  final int? payDayOfMonth; // 1-31 (for monthly frequency)
  final int? payDayOfWeek; // 1-7 (Monday-Sunday, for weekly)
  final DateTime? lastPayDate; // When they last ran Pay Day
  final String? defaultAccountId; // Which account receives Pay Day deposits

  PayDaySettings({
    required this.userId,
    this.lastPayAmount,
    this.payFrequency = 'monthly',
    this.payDayOfMonth,
    this.payDayOfWeek,
    this.lastPayDate,
    this.defaultAccountId,
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
  }) {
    return PayDaySettings(
      userId: userId,
      lastPayAmount: lastPayAmount ?? this.lastPayAmount,
      payFrequency: payFrequency ?? this.payFrequency,
      payDayOfMonth: payDayOfMonth ?? this.payDayOfMonth,
      payDayOfWeek: payDayOfWeek ?? this.payDayOfWeek,
      lastPayDate: lastPayDate ?? this.lastPayDate,
      defaultAccountId: defaultAccountId ?? this.defaultAccountId,
    );
  }

  DateTime? getNextPayDate() {
    if (lastPayDate == null) return null;

    switch (payFrequency) {
      case 'weekly':
        return lastPayDate!.add(const Duration(days: 7));
      case 'biweekly':
        return lastPayDate!.add(const Duration(days: 14));
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

  @override
  String toString() {
    return 'PayDaySettings(userId: $userId, lastPay: $lastPayAmount, frequency: $payFrequency)';
  }
}
