// lib/models/transaction.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'transaction.g.dart';

/// Transaction Impact: Does this cross the wall?
@HiveType(typeId: 105)
enum TransactionImpact {
  @HiveField(0)
  external, // Crosses the wall (changes net worth)
  @HiveField(1)
  internal, // Stays inside (just moves location)
}

/// Transaction Direction: Which way is money flowing?
@HiveType(typeId: 106)
enum TransactionDirection {
  @HiveField(0)
  inflow, // Money coming in (income, pay day)
  @HiveField(1)
  outflow, // Money going out (spending, bills)
  @HiveField(2)
  move, // Money moving between locations (internal only)
}

/// Source/Destination Type
@HiveType(typeId: 107)
enum SourceType {
  @HiveField(0)
  envelope,
  @HiveField(1)
  account,
  @HiveField(2)
  external, // Money from/to outside the system
}

// LEGACY ENUMS - Keep for backwards compatibility
@HiveType(typeId: 100)
enum TransactionType {
  @HiveField(0)
  deposit,
  @HiveField(1)
  withdrawal,
  @HiveField(2)
  transfer,
  @HiveField(3)
  scheduledPayment,
}

@HiveType(typeId: 104)
enum TransferDirection {
  @HiveField(0)
  in_,
  @HiveField(1)
  out_,
}

@HiveType(typeId: 3)
class Transaction {
  @HiveField(0)
  final String id; // doc id

  @HiveField(1)
  final String envelopeId; // owner envelope of this row

  @HiveField(2)
  final TransactionType type; // deposit/withdrawal/transfer

  @HiveField(3)
  final double amount;

  @HiveField(4)
  final DateTime date; // server or client date

  @HiveField(5)
  final String description;

  @HiveField(6)
  final String userId;

  @HiveField(7)
  final bool isFuture; // Mark projected/future transactions (not stored in Firestore)

  // --- Transfer-specific fields (null for non-transfers) ---
  @HiveField(8)
  final String? transferPeerEnvelopeId; // the other envelope in the transfer

  @HiveField(9)
  final String? transferLinkId; // shared id linking the pair

  @HiveField(10)
  final TransferDirection? transferDirection; // in_ (credit) or out_ (debit)

  // --- Owner/envelope metadata for rich display ---
  @HiveField(11)
  final String? ownerId; // Owner of THIS envelope (for deposit/withdrawal)

  @HiveField(12)
  final String? sourceOwnerId; // Owner of source envelope (for transfers)

  @HiveField(13)
  final String? targetOwnerId; // Owner of target envelope (for transfers)

  @HiveField(14)
  final String? sourceEnvelopeName; // Name of source envelope (for transfers)

  @HiveField(15)
  final String? targetEnvelopeName; // Name of target envelope (for transfers)

  @HiveField(16)
  final String? sourceOwnerDisplayName; // Display name of source owner

  @HiveField(17)
  final String? targetOwnerDisplayName; // Display name of target owner

  // NEW: Sync tracking fields (nullable for backward compatibility)
  @HiveField(18)
  final bool? isSynced;

  @HiveField(19)
  final DateTime? lastUpdated;

  // NEW: Account tracking (nullable for backward compatibility - envelope transactions won't have this)
  @HiveField(20)
  final String? accountId;

  // NEW PHILOSOPHY FIELDS: Define the EXTERNAL/INTERNAL nature
  @HiveField(21)
  final TransactionImpact? impact; // external or internal (nullable for backwards compatibility)

  @HiveField(22)
  final TransactionDirection? direction; // inflow, outflow, or move (nullable for backwards compatibility)

  // Source (where money came FROM)
  @HiveField(23)
  final String? sourceId; // Envelope/Account ID or null if external

  @HiveField(24)
  final SourceType? sourceType; // envelope, account, or external

  // Destination (where money went TO)
  @HiveField(25)
  final String? destinationId; // Envelope/Account ID or null if external

  @HiveField(26)
  final SourceType? destinationType; // envelope, account, or external

  Transaction({
    required this.id,
    required this.envelopeId,
    required this.type,
    required this.amount,
    required this.date,
    required this.description,
    required this.userId,
    this.transferPeerEnvelopeId,
    this.transferLinkId,
    this.transferDirection,
    this.ownerId,
    this.sourceOwnerId,
    this.targetOwnerId,
    this.sourceEnvelopeName,
    this.targetEnvelopeName,
    this.sourceOwnerDisplayName,
    this.targetOwnerDisplayName,
    this.isFuture = false,
    this.isSynced,
    this.lastUpdated,
    this.accountId,
    this.impact,
    this.direction,
    this.sourceId,
    this.sourceType,
    this.destinationId,
    this.destinationType,
  });

  // Convenience getters
  bool get isExternal => impact == TransactionImpact.external;
  bool get isInternal => impact == TransactionImpact.internal;
  bool get isInflow => direction == TransactionDirection.inflow;
  bool get isOutflow => direction == TransactionDirection.outflow;
  bool get isMove => direction == TransactionDirection.move;

  // Get human-readable action text
  String getActionText() {
    if (isExternal && isInflow) {
      return description.contains('Pay Day') ? 'Pay Day Deposit' : 'Income';
    } else if (isExternal && isOutflow) {
      return description.contains('Autopilot') ? 'Autopilot Payment' : 'Spent';
    } else if (isInternal && isMove) {
      if (description.contains('Cash Flow')) {
        return 'Cash Flow';
      } else if (description.contains('Autopilot')) {
        return 'Autopilot Transfer';
      } else {
        return 'Transfer';
      }
    }
    // Fallback for legacy transactions without impact/direction
    return description;
  }

  // Get impact badge text
  String getImpactBadge() {
    if (impact == null) return 'LEGACY'; // For old transactions
    return isExternal ? 'EXTERNAL' : 'INTERNAL';
  }

  Map<String, dynamic> toMap() {
    return {
      'envelopeId': envelopeId,
      'accountId': accountId,
      'type': type.name,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'description': description,
      'userId': userId,
      'transferPeerEnvelopeId': transferPeerEnvelopeId,
      'transferLinkId': transferLinkId,
      'transferDirection': transferDirection?.name,
      'ownerId': ownerId,
      'sourceOwnerId': sourceOwnerId,
      'targetOwnerId': targetOwnerId,
      'sourceEnvelopeName': sourceEnvelopeName,
      'targetEnvelopeName': targetEnvelopeName,
      'sourceOwnerDisplayName': sourceOwnerDisplayName,
      'targetOwnerDisplayName': targetOwnerDisplayName,
      'isSynced': isSynced ?? true, // Default to synced for Firebase data
      'lastUpdated': Timestamp.fromDate(lastUpdated ?? DateTime.now()),
      // New philosophy fields
      'impact': impact?.name,
      'direction': direction?.name,
      'sourceId': sourceId,
      'sourceType': sourceType?.name,
      'destinationId': destinationId,
      'destinationType': destinationType?.name,
      // Note: isFuture is not saved to Firestore (used only for UI projections)
    };
  }

  factory Transaction.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return Transaction(
      id: doc.id,
      envelopeId: data['envelopeId'] as String,
      accountId: data['accountId'] as String?,
      type: _parseType(data['type']),
      amount: (data['amount'] as num).toDouble(),
      date: (data['date'] as Timestamp).toDate(),
      description: (data['description'] ?? '') as String,
      userId: (data['userId'] ?? '') as String,
      transferPeerEnvelopeId: data['transferPeerEnvelopeId'] as String?,
      transferLinkId: data['transferLinkId'] as String?,
      transferDirection: _parseDirection(data['transferDirection']),
      ownerId: data['ownerId'] as String?,
      sourceOwnerId: data['sourceOwnerId'] as String?,
      targetOwnerId: data['targetOwnerId'] as String?,
      sourceEnvelopeName: data['sourceEnvelopeName'] as String?,
      targetEnvelopeName: data['targetEnvelopeName'] as String?,
      sourceOwnerDisplayName: data['sourceOwnerDisplayName'] as String?,
      targetOwnerDisplayName: data['targetOwnerDisplayName'] as String?,
      isFuture: false, // Real transactions from Firestore are never future
      isSynced: (data['isSynced'] as bool?) ?? true, // Firestore data is already synced
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      impact: _parseImpact(data['impact']),
      direction: _parseTransactionDirection(data['direction']),
      sourceId: data['sourceId'] as String?,
      sourceType: _parseSourceType(data['sourceType']),
      destinationId: data['destinationId'] as String?,
      destinationType: _parseSourceType(data['destinationType']),
    );
  }

  static TransactionType _parseType(dynamic v) {
    final s = (v ?? '').toString();
    return TransactionType.values.firstWhere(
      (e) => e.name == s,
      orElse: () => TransactionType.deposit,
    );
  }

  static TransferDirection? _parseDirection(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    try {
      return TransferDirection.values.firstWhere((e) => e.name == s);
    } catch (_) {
      return null;
    }
  }

  static TransactionImpact? _parseImpact(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    try {
      return TransactionImpact.values.firstWhere((e) => e.name == s);
    } catch (_) {
      return null;
    }
  }

  static TransactionDirection? _parseTransactionDirection(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    try {
      return TransactionDirection.values.firstWhere((e) => e.name == s);
    } catch (_) {
      return null;
    }
  }

  static SourceType? _parseSourceType(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    try {
      return SourceType.values.firstWhere((e) => e.name == s);
    } catch (_) {
      return null;
    }
  }
}
