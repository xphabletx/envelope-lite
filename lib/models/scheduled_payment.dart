// lib/models/scheduled_payment.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'scheduled_payment.g.dart';

@HiveType(typeId: 102)
enum PaymentFrequencyUnit {
  @HiveField(0)
  days,
  @HiveField(1)
  weeks,
  @HiveField(2)
  months,
  @HiveField(3)
  years,
}

@HiveType(typeId: 103)
enum ScheduledPaymentType {
  @HiveField(0)
  fixedAmount,
  @HiveField(1)
  envelopeBalance,
}

@HiveType(typeId: 4)
class ScheduledPayment {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String userId;

  @HiveField(2)
  final String? envelopeId;

  @HiveField(3)
  final String? groupId;

  @HiveField(4)
  final String name; // Display name (e.g., "Rent", "Subscriptions")

  @HiveField(5)
  final String? description;

  @HiveField(6)
  final double amount;

  @HiveField(7)
  final DateTime startDate;

  @HiveField(8)
  final int frequencyValue; // e.g., 1, 2, 3

  @HiveField(9)
  final PaymentFrequencyUnit frequencyUnit; // days, weeks, months, years

  @HiveField(10)
  final String colorName; // e.g., "Blusher", "Moody Sky"

  @HiveField(11)
  final int colorValue; // Actual color int value

  @HiveField(12)
  final bool isAutomatic; // Auto-execute on due date

  @HiveField(13)
  final DateTime? lastExecuted; // Track last execution

  @HiveField(14)
  final DateTime createdAt;

  // NEW: Dynamic payment type support
  @HiveField(15)
  final ScheduledPaymentType paymentType;

  @HiveField(16)
  final String? paymentEnvelopeId; // Envelope to pull payment amount from

  ScheduledPayment({
    required this.id,
    required this.userId,
    this.envelopeId,
    this.groupId,
    required this.name,
    this.description,
    required this.amount,
    required this.startDate,
    required this.frequencyValue,
    required this.frequencyUnit,
    required this.colorName,
    required this.colorValue,
    this.isAutomatic = false,
    this.lastExecuted,
    required this.createdAt,
    this.paymentType = ScheduledPaymentType.fixedAmount,
    this.paymentEnvelopeId,
  });

  // Get next due date based on last execution or start date
  DateTime get nextDueDate {
    final baseDate = lastExecuted ?? startDate;

    if (lastExecuted == null) {
      return startDate;
    }

    switch (frequencyUnit) {
      case PaymentFrequencyUnit.days:
        return baseDate.add(Duration(days: frequencyValue));
      case PaymentFrequencyUnit.weeks:
        return baseDate.add(Duration(days: frequencyValue * 7));
      case PaymentFrequencyUnit.months:
        return DateTime(
          baseDate.year,
          baseDate.month + frequencyValue,
          baseDate.day,
        );
      case PaymentFrequencyUnit.years:
        return DateTime(
          baseDate.year + frequencyValue,
          baseDate.month,
          baseDate.day,
        );
    }
  }

  // Format frequency string with proper grammar
  String get frequencyString {
    final unit = frequencyValue == 1
        ? frequencyUnit.name.substring(
            0,
            frequencyUnit.name.length - 1,
          ) // Remove 's'
        : frequencyUnit.name;

    return frequencyValue == 1 ? 'Every $unit' : 'Every $frequencyValue $unit';
  }

  bool get isEnvelopePayment => envelopeId != null;
  bool get isGroupPayment => groupId != null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'envelopeId': envelopeId,
      'groupId': groupId,
      'name': name,
      'description': description,
      'amount': amount,
      'startDate': Timestamp.fromDate(startDate),
      'frequencyValue': frequencyValue,
      'frequencyUnit': frequencyUnit.name,
      'colorName': colorName,
      'colorValue': colorValue,
      'isAutomatic': isAutomatic,
      'lastExecuted': lastExecuted != null
          ? Timestamp.fromDate(lastExecuted!)
          : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'paymentType': paymentType.name,
      'paymentEnvelopeId': paymentEnvelopeId,
    };
  }

  factory ScheduledPayment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Parse payment type
    final typeString = data['paymentType'] as String?;
    final paymentType = typeString == 'envelopeBalance'
        ? ScheduledPaymentType.envelopeBalance
        : ScheduledPaymentType.fixedAmount;

    return ScheduledPayment(
      id: doc.id,
      userId: data['userId'] ?? '',
      envelopeId: data['envelopeId'],
      groupId: data['groupId'],
      name: data['name'] ?? '',
      description: data['description'],
      amount: (data['amount'] ?? 0.0).toDouble(),
      startDate: (data['startDate'] as Timestamp).toDate(),
      frequencyValue: data['frequencyValue'] ?? 1,
      frequencyUnit: PaymentFrequencyUnit.values.firstWhere(
        (e) => e.name == data['frequencyUnit'],
        orElse: () => PaymentFrequencyUnit.months,
      ),
      colorName: data['colorName'] ?? 'Blusher',
      colorValue: data['colorValue'] ?? 0xFFF8BBD0,
      isAutomatic: data['isAutomatic'] ?? false,
      lastExecuted: data['lastExecuted'] != null
          ? (data['lastExecuted'] as Timestamp).toDate()
          : null,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      paymentType: paymentType,
      paymentEnvelopeId: data['paymentEnvelopeId'],
    );
  }

  ScheduledPayment copyWith({
    String? id,
    String? userId,
    String? envelopeId,
    String? groupId,
    String? name,
    String? description,
    double? amount,
    DateTime? startDate,
    int? frequencyValue,
    PaymentFrequencyUnit? frequencyUnit,
    String? colorName,
    int? colorValue,
    bool? isAutomatic,
    DateTime? lastExecuted,
    DateTime? createdAt,
    ScheduledPaymentType? paymentType,
    String? paymentEnvelopeId,
  }) {
    return ScheduledPayment(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      envelopeId: envelopeId ?? this.envelopeId,
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      startDate: startDate ?? this.startDate,
      frequencyValue: frequencyValue ?? this.frequencyValue,
      frequencyUnit: frequencyUnit ?? this.frequencyUnit,
      colorName: colorName ?? this.colorName,
      colorValue: colorValue ?? this.colorValue,
      isAutomatic: isAutomatic ?? this.isAutomatic,
      lastExecuted: lastExecuted ?? this.lastExecuted,
      createdAt: createdAt ?? this.createdAt,
      paymentType: paymentType ?? this.paymentType,
      paymentEnvelopeId: paymentEnvelopeId ?? this.paymentEnvelopeId,
    );
  }
}

// Calendar color palette
class CalendarColors {
  static const colors = {
    'Blusher': 0xFFF8BBD0,
    'Rose Gold': 0xFFE91E63,
    'Salon Tan': 0xFFFF9800,
    'Latte': 0xFF8D6E63,
    'Mint Sorbet': 0xFF4DB6AC,
    'Sage Garden': 0xFF66BB6A,
    'Moody Sky': 0xFF42A5F5,
    'Twilight': 0xFF5C6BC0,
    'Lavender Dream': 0xFF9C27B0,
    'Graphite': 0xFF757575,
    'Coral Sunset': 0xFFFF7043,
    'Buttercream': 0xFFFDD835,
  };

  static List<String> get colorNames => colors.keys.toList();

  static int getColorValue(String name) => colors[name] ?? 0xFFF8BBD0;

  static String getColorName(int value) {
    return colors.entries
        .firstWhere(
          (entry) => entry.value == value,
          orElse: () => const MapEntry('Blusher', 0xFFF8BBD0),
        )
        .key;
  }
}
