// lib/models/scheduled_payment.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentFrequencyUnit { days, weeks, months, years }

class ScheduledPayment {
  final String id;
  final String userId;
  final String? envelopeId;
  final String? groupId;
  final String name; // Display name (e.g., "Rent", "Subscriptions")
  final String? description;
  final double amount;
  final DateTime startDate;
  final int frequencyValue; // e.g., 1, 2, 3
  final PaymentFrequencyUnit frequencyUnit; // days, weeks, months, years
  final String colorName; // e.g., "Blusher", "Moody Sky"
  final int colorValue; // Actual color int value
  final bool isAutomatic; // Auto-execute on due date
  final DateTime? lastExecuted; // Track last execution
  final DateTime createdAt;

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
    };
  }

  factory ScheduledPayment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

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
