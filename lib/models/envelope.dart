// lib/models/envelope.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Envelope {
  final String id;
  String name;
  final String userId;
  double currentAmount;
  double? targetAmount;
  DateTime? targetDate;
  String? groupId;
  final String? emoji;
  final String? subtitle;
  final bool autoFillEnabled;
  final double? autoFillAmount;
  final bool isShared;
  final String? linkedAccountId;

  Envelope({
    required this.id,
    required this.name,
    required this.userId,
    this.currentAmount = 0.0,
    this.targetAmount,
    this.targetDate,
    this.groupId,
    this.emoji,
    this.subtitle,
    this.autoFillEnabled = false,
    this.autoFillAmount,
    this.isShared = true,
    this.linkedAccountId,
  });

  Envelope copyWith({
    String? id,
    String? name,
    String? userId,
    double? currentAmount,
    double? targetAmount,
    DateTime? targetDate,
    String? groupId,
    String? emoji,
    String? subtitle,
    bool? autoFillEnabled,
    double? autoFillAmount,
    bool? isShared,
    String? linkedAccountId,
  }) {
    return Envelope(
      id: id ?? this.id,
      name: name ?? this.name,
      userId: userId ?? this.userId,
      currentAmount: currentAmount ?? this.currentAmount,
      targetAmount: targetAmount ?? this.targetAmount,
      targetDate: targetDate ?? this.targetDate,
      groupId: groupId ?? this.groupId,
      emoji: emoji ?? this.emoji,
      subtitle: subtitle ?? this.subtitle,
      autoFillEnabled: autoFillEnabled ?? this.autoFillEnabled,
      autoFillAmount: autoFillAmount ?? this.autoFillAmount,
      isShared: isShared ?? this.isShared,
      linkedAccountId: linkedAccountId ?? this.linkedAccountId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'userId': userId,
      'currentAmount': currentAmount,
      'targetAmount': targetAmount,
      'targetDate': targetDate != null ? Timestamp.fromDate(targetDate!) : null,
      'groupId': groupId,
      'emoji': emoji,
      'subtitle': subtitle,
      'autoFillEnabled': autoFillEnabled,
      'autoFillAmount': autoFillAmount,
      'isShared': isShared,
      'linkedAccountId': linkedAccountId,
    };
  }

  factory Envelope.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Envelope ${doc.id} has no data');
    }

    // Helper to safely convert int/double/String to double
    double toDouble(dynamic v, {double fallback = 0.0}) {
      if (v == null) return fallback;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? fallback;
      return fallback;
    }

    return Envelope(
      id: doc.id,
      name: (data['name'] as String?) ?? '',
      userId: (data['userId'] as String?) ?? '',
      currentAmount: toDouble(data['currentAmount'], fallback: 0.0),
      targetAmount: (data['targetAmount'] == null)
          ? null
          : toDouble(data['targetAmount']),
      targetDate: (data['targetDate'] as Timestamp?)?.toDate(),
      groupId: data['groupId'] as String?,
      emoji: data['emoji'] as String?,
      subtitle: data['subtitle'] as String?,
      autoFillEnabled: (data['autoFillEnabled'] as bool?) ?? false,
      autoFillAmount: (data['autoFillAmount'] == null)
          ? null
          : toDouble(data['autoFillAmount']),
      isShared: (data['isShared'] as bool?) ?? true,
      linkedAccountId: data['linkedAccountId'] as String?,
    );
  }
}
