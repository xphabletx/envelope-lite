// lib/models/account.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Account {
  final String id;
  final String name;
  final double currentBalance;
  final String userId;
  final String? emoji;
  final String? colorName;
  final DateTime createdAt;
  final DateTime lastUpdated;
  final bool isDefault; // Main account that receives Pay Day deposits
  final bool isShared; // For workspace mode
  final String? workspaceId;

  Account({
    required this.id,
    required this.name,
    required this.currentBalance,
    required this.userId,
    this.emoji,
    this.colorName,
    required this.createdAt,
    required this.lastUpdated,
    this.isDefault = false,
    this.isShared = false,
    this.workspaceId,
  });

  factory Account.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Account(
      id: doc.id,
      name: data['name'] as String? ?? 'Unnamed Account',
      currentBalance: (data['currentBalance'] as num?)?.toDouble() ?? 0.0,
      userId: data['userId'] as String? ?? '',
      emoji: data['emoji'] as String?,
      colorName: data['colorName'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastUpdated:
          (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isDefault: data['isDefault'] as bool? ?? false,
      isShared: data['isShared'] as bool? ?? false,
      workspaceId: data['workspaceId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name,
      'currentBalance': currentBalance,
      'userId': userId,
      'emoji': emoji,
      'colorName': colorName,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'isDefault': isDefault,
      'isShared': isShared,
      'workspaceId': workspaceId,
    };
  }

  Account copyWith({
    String? name,
    double? currentBalance,
    String? emoji,
    String? colorName,
    DateTime? lastUpdated,
    bool? isDefault,
    bool? isShared,
  }) {
    return Account(
      id: id,
      name: name ?? this.name,
      currentBalance: currentBalance ?? this.currentBalance,
      userId: userId,
      emoji: emoji ?? this.emoji,
      colorName: colorName ?? this.colorName,
      createdAt: createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isDefault: isDefault ?? this.isDefault,
      isShared: isShared ?? this.isShared,
      workspaceId: workspaceId,
    );
  }

  @override
  String toString() {
    return 'Account(id: $id, name: $name, balance: $currentBalance, isDefault: $isDefault)';
  }
}
