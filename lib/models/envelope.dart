// lib/models/envelope.dart
// Defines the Envelope data structure, which is shared and used by the repository.
import 'package:cloud_firestore/cloud_firestore.dart';

class Envelope {
  final String id;
  String name;
  final String userId; // The UID of the person who created the envelope
  double currentAmount;
  double? targetAmount; // Optional target
  DateTime? targetDate; // NEW: Optional target date
  String? groupId;
  final String? emoji;
  final String? subtitle;
  final bool
  autoFillEnabled; // NEW: Is this envelope included in Pay Day auto-fill?
  final double?
  autoFillAmount; // NEW: Amount to add on Pay Day (user must set manually)

  // NOTE: isShared is determined by the workspace model, but included for simplicity
  final bool isShared;

  Envelope({
    required this.id,
    required this.name,
    required this.userId,
    this.currentAmount = 0.0,
    this.targetAmount,
    this.targetDate, // NEW
    this.groupId,
    this.emoji,
    this.subtitle,
    this.autoFillEnabled = false, // Default to not auto-filling
    this.autoFillAmount, // Default to null (must be set by user)
    this.isShared = true,
  });

  Envelope copyWith({
    String? id,
    String? name,
    String? userId,
    double? currentAmount,
    double? targetAmount,
    DateTime? targetDate, // NEW
    String? groupId,
    String? emoji,
    String? subtitle,
    bool? autoFillEnabled,
    double? autoFillAmount,
    bool? isShared,
  }) {
    return Envelope(
      id: id ?? this.id,
      name: name ?? this.name,
      userId: userId ?? this.userId,
      currentAmount: currentAmount ?? this.currentAmount,
      targetAmount: targetAmount ?? this.targetAmount,
      targetDate: targetDate ?? this.targetDate, // NEW
      groupId: groupId ?? this.groupId,
      emoji: emoji ?? this.emoji,
      subtitle: subtitle ?? this.subtitle,
      autoFillEnabled: autoFillEnabled ?? this.autoFillEnabled,
      autoFillAmount: autoFillAmount ?? this.autoFillAmount,
      isShared: isShared ?? this.isShared,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'userId': userId,
      'currentAmount': currentAmount,
      'targetAmount': targetAmount,
      'targetDate': targetDate != null
          ? Timestamp.fromDate(targetDate!)
          : null, // NEW
      'groupId': groupId,
      'emoji': emoji,
      'subtitle': subtitle,
      'autoFillEnabled': autoFillEnabled,
      'autoFillAmount': autoFillAmount,
      'isShared': isShared,
    };
  }

  factory Envelope.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Envelope ${doc.id} has no data');
    }

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
      targetDate: (data['targetDate'] as Timestamp?)?.toDate(), // NEW
      groupId: data['groupId'] as String?,
      emoji: data['emoji'] as String?,
      subtitle: data['subtitle'] as String?,
      autoFillEnabled: (data['autoFillEnabled'] as bool?) ?? false,
      autoFillAmount: (data['autoFillAmount'] == null)
          ? null
          : toDouble(data['autoFillAmount']),
      isShared: (data['isShared'] as bool?) ?? true,
    );
  }
}
