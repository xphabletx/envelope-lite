// lib/models/envelope_group.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class EnvelopeGroup {
  final String id;
  final String name;
  final String userId;

  // OLD: Single emoji field (keep for backwards compatibility)
  final String? emoji;

  // NEW: Icon system (same as Envelope)
  final String? iconType; // 'emoji', 'materialIcon', 'companyLogo'
  final String? iconValue; // emoji char, icon name, or domain
  final int? iconColor; // For material icons (Color.value)

  final int colorIndex;
  final bool payDayEnabled;
  final bool isShared;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  EnvelopeGroup({
    required this.id,
    required this.name,
    required this.userId,
    this.emoji,
    this.iconType,
    this.iconValue,
    this.iconColor,
    this.colorIndex = 0,
    this.payDayEnabled = false,
    this.isShared = true,
    this.createdAt,
    this.updatedAt,
  });

  factory EnvelopeGroup.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return EnvelopeGroup(
      id: doc.id,
      name: data?['name'] ?? '',
      userId: data?['userId'] ?? '',
      emoji: data?['emoji'],
      iconType: data?['iconType'],
      iconValue: data?['iconValue'],
      iconColor: data?['iconColor'],
      colorIndex: data?['colorIndex'] ?? 0,
      payDayEnabled: data?['payDayEnabled'] ?? false,
      isShared: data?['isShared'] ?? true,
      createdAt: data?['createdAt'] != null
          ? (data!['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data?['updatedAt'] != null
          ? (data!['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'userId': userId,
      'emoji': emoji,
      'iconType': iconType,
      'iconValue': iconValue,
      'iconColor': iconColor,
      'colorIndex': colorIndex,
      'payDayEnabled': payDayEnabled,
      'isShared': isShared,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  EnvelopeGroup copyWith({
    String? id,
    String? name,
    String? userId,
    String? emoji,
    String? iconType,
    String? iconValue,
    int? iconColor,
    int? colorIndex,
    bool? payDayEnabled,
    bool? isShared,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EnvelopeGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      userId: userId ?? this.userId,
      emoji: emoji ?? this.emoji,
      iconType: iconType ?? this.iconType,
      iconValue: iconValue ?? this.iconValue,
      iconColor: iconColor ?? this.iconColor,
      colorIndex: colorIndex ?? this.colorIndex,
      payDayEnabled: payDayEnabled ?? this.payDayEnabled,
      isShared: isShared ?? this.isShared,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
