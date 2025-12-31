// lib/models/transaction.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'transaction.g.dart';

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
  });

  Map<String, dynamic> toMap() {
    return {
      'envelopeId': envelopeId,
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
}
