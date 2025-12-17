// lib/models/transaction.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType { deposit, withdrawal, transfer }

enum TransferDirection { in_, out_ } // only used for transfers

class Transaction {
  final String id; // doc id
  final String envelopeId; // owner envelope of this row
  final TransactionType type; // deposit/withdrawal/transfer
  final double amount;
  final DateTime date; // server or client date
  final String description;
  final String userId;

  // --- Transfer-specific fields (null for non-transfers) ---
  final String? transferPeerEnvelopeId; // the other envelope in the transfer
  final String? transferLinkId; // shared id linking the pair
  final TransferDirection? transferDirection; // in_ (credit) or out_ (debit)

  // --- Owner/envelope metadata for rich display ---
  final String? ownerId; // Owner of THIS envelope (for deposit/withdrawal)
  final String? sourceOwnerId; // Owner of source envelope (for transfers)
  final String? targetOwnerId; // Owner of target envelope (for transfers)
  final String? sourceEnvelopeName; // Name of source envelope (for transfers)
  final String? targetEnvelopeName; // Name of target envelope (for transfers)
  final String? sourceOwnerDisplayName; // Display name of source owner
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
