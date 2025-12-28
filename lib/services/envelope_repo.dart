// lib/services/envelope_repo.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import '../models/envelope.dart';
import '../models/envelope_group.dart';
import '../models/transaction.dart' as models;
import 'hive_service.dart';

/// Envelope repository - Hive-first architecture
///
/// SOLO MODE:
/// - 100% Hive (local storage)
/// - ZERO Firebase writes
/// - Fast, offline, private
///
/// WORKSPACE MODE:
/// - Hive as primary storage (local-first)
/// - Firebase sync for collaboration:
///   * Envelopes (so partner can see/edit)
///   * Partner transfers only (paper trail)
/// - Everything else stays local (accounts, groups, scheduled payments, settings)
class EnvelopeRepo {
  final String _userId;
  final bool _inWorkspace;
  final String? _workspaceId;

  final Box<Envelope> _envelopeBox;
  final Box<EnvelopeGroup> _groupBox;
  final Box<models.Transaction> _transactionBox;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  EnvelopeRepo.firebase(
    FirebaseFirestore db, {
    String? workspaceId,
    required String userId,
  })  : _userId = userId,
        _inWorkspace = (workspaceId != null && workspaceId.isNotEmpty),
        _workspaceId = (workspaceId?.isEmpty ?? true) ? null : workspaceId,
        _envelopeBox = HiveService.getBox<Envelope>('envelopes'),
        _groupBox = HiveService.getBox<EnvelopeGroup>('groups'),
        _transactionBox = HiveService.getBox<models.Transaction>('transactions') {
    debugPrint('[EnvelopeRepo] Initialized:');
    debugPrint('  User: $_userId');
    debugPrint('  Workspace: ${_inWorkspace ? workspaceId : "SOLO MODE"}');
  }

  // --------- Public getters ----------
  FirebaseFirestore get db => _firestore;
  String get currentUserId => _userId;
  String? get workspaceId => _workspaceId;
  bool get inWorkspace => _inWorkspace;

  bool isMyEnvelope(Envelope envelope) => envelope.userId == _userId;

  // ==================== STREAMS ====================

  /// Envelopes stream
  /// - Solo: Pure Hive
  /// - Workspace: Firebase sync + Hive cache
  Stream<List<Envelope>> envelopesStream({bool showPartnerEnvelopes = true}) {
    if (!_inWorkspace) {
      // SOLO MODE: Pure Hive
      debugPrint('[EnvelopeRepo] 📦 Solo mode: streaming from Hive only');

      final initial = _envelopeBox.values
          .where((env) => env.userId == _userId)
          .toList();

      debugPrint('[EnvelopeRepo] ✅ Initial: ${initial.length} envelopes from Hive');

      return Stream.value(initial).asBroadcastStream().concatWith([
        _envelopeBox.watch().map((_) {
          final envelopes = _envelopeBox.values
              .where((env) => env.userId == _userId)
              .toList();

          debugPrint('[EnvelopeRepo] ✅ Emitting ${envelopes.length} envelopes from Hive');
          return envelopes;
        })
      ]);

    } else {
      // WORKSPACE MODE: Firebase sync from workspace envelopes collection
      debugPrint('[EnvelopeRepo] 🤝 Workspace mode: syncing with Firebase workspace/$_workspaceId');

      return _firestore
          .collection('workspaces')
          .doc(_workspaceId)
          .collection('envelopes')
          .orderBy('createdAt', descending: false)
          .snapshots()
          .asyncMap((snapshot) async {
            final List<Envelope> allEnvelopes = [];

            for (final doc in snapshot.docs) {
              final envelope = Envelope.fromFirestore(doc);

              // Filter based on showPartnerEnvelopes flag
              if (showPartnerEnvelopes || envelope.userId == _userId) {
                allEnvelopes.add(envelope);
                // Cache to Hive for offline access
                await _envelopeBox.put(envelope.id, envelope);
              }
            }

            debugPrint('[EnvelopeRepo] ✅ Synced ${allEnvelopes.length} envelopes from workspace');
            return allEnvelopes;
          });
    }
  }

  Stream<List<Envelope>> get envelopesStreamAll =>
      envelopesStream(showPartnerEnvelopes: true);

  /// Single envelope stream (for live updates)
  Stream<Envelope> envelopeStream(String id) {
    if (!_inWorkspace) {
      // SOLO MODE: Hive only
      final initial = _envelopeBox.get(id);
      if (initial == null) {
        throw Exception('Envelope not found: $id');
      }

      return Stream.value(initial).asBroadcastStream().concatWith([
        _envelopeBox.watch(key: id).map((_) {
          final envelope = _envelopeBox.get(id);
          if (envelope == null) {
            throw Exception('Envelope not found: $id');
          }
          return envelope;
        })
      ]);

    } else {
      // WORKSPACE MODE: Firebase sync from workspace collection
      return _firestore
          .collection('workspaces')
          .doc(_workspaceId)
          .collection('envelopes')
          .doc(id)
          .snapshots()
          .asyncMap((doc) async {
            if (!doc.exists) {
              throw Exception('Envelope not found: $id');
            }

            final envelope = Envelope.fromFirestore(doc);
            await _envelopeBox.put(id, envelope);

            return envelope;
          });
    }
  }

  /// Groups stream (ALWAYS local only - no workspace sync)
  Stream<List<EnvelopeGroup>> get groupsStream {
    debugPrint('[EnvelopeRepo] 📦 Streaming groups from Hive (local only)');

    final initial = _groupBox.values
        .where((g) => g.userId == _userId)
        .toList();

    return Stream.value(initial).asBroadcastStream().concatWith([
      _groupBox.watch().map((_) {
        return _groupBox.values
            .where((g) => g.userId == _userId)
            .toList();
      })
    ]);
  }

  /// Transactions stream (ALWAYS local only)
  /// Exception: Partner transfers are synced separately
  Stream<List<models.Transaction>> get transactionsStream {
    debugPrint('[EnvelopeRepo] 📦 Streaming transactions from Hive (local only)');

    final initial = _transactionBox.values
        .where((tx) => tx.userId == _userId)
        .toList();
    initial.sort((a, b) => b.date.compareTo(a.date)); // Newest first

    return Stream.value(initial).asBroadcastStream().concatWith([
      _transactionBox.watch().map((_) {
        final txs = _transactionBox.values
            .where((tx) => tx.userId == _userId)
            .toList();
        txs.sort((a, b) => b.date.compareTo(a.date)); // Newest first
        return txs;
      })
    ]);
  }

  Stream<List<models.Transaction>> transactionsForEnvelope(String envelopeId) {
    return transactionsStream.map(
      (allTxs) => allTxs.where((tx) => tx.envelopeId == envelopeId).toList(),
    );
  }

  // ==================== CREATE ====================

  /// Create envelope
  Future<String> createEnvelope({
    required String name,
    required double startingAmount,
    double? targetAmount,
    DateTime? targetDate,
    String? groupId,
    String? subtitle,
    String? emoji,
    String? iconType,
    String? iconValue,
    int? iconColor,
    bool autoFillEnabled = false,
    double? autoFillAmount,
    String? linkedAccountId,
  }) async {
    debugPrint('[EnvelopeRepo] Creating envelope: $name');

    final id = _firestore.collection('_temp').doc().id;

    final envelope = Envelope(
      id: id,
      name: name,
      userId: _userId,
      currentAmount: startingAmount,
      targetAmount: targetAmount,
      targetDate: targetDate,
      groupId: groupId,
      subtitle: subtitle,
      emoji: emoji,
      iconType: iconType,
      iconValue: iconValue,
      iconColor: iconColor,
      autoFillEnabled: autoFillEnabled,
      autoFillAmount: autoFillAmount,
      linkedAccountId: linkedAccountId,
      isShared: _inWorkspace,
    );

    // ALWAYS write to Hive first (primary storage)
    await _envelopeBox.put(id, envelope);
    debugPrint('[EnvelopeRepo] ✅ Saved to Hive');

    // Only sync to Firebase if in workspace mode
    if (_inWorkspace && _workspaceId != null) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        final ownerDisplayName = user?.displayName ?? (user?.email ?? 'Me');

        await _firestore
            .collection('workspaces')
            .doc(_workspaceId)
            .collection('envelopes')
            .doc(id)
            .set({
          'id': id,
          'name': name,
          'userId': _userId,
          'ownerId': _userId,
          'ownerDisplayName': ownerDisplayName,
          'currentAmount': startingAmount,
          'targetAmount': targetAmount,
          'targetDate': targetDate != null ? Timestamp.fromDate(targetDate) : null,
          'groupId': groupId,
          'subtitle': subtitle,
          'emoji': emoji,
          'iconType': iconType,
          'iconValue': iconValue,
          'iconColor': iconColor,
          'autoFillEnabled': autoFillEnabled,
          'autoFillAmount': autoFillAmount,
          'linkedAccountId': linkedAccountId,
          'isShared': true,
          'workspaceId': _workspaceId,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        debugPrint('[EnvelopeRepo] ✅ Synced to Firebase workspace');
      } catch (e) {
        debugPrint('[EnvelopeRepo] ⚠️ Firebase sync failed: $e');
        // Don't throw - Hive save succeeded, Firebase is just sync
      }
    } else {
      debugPrint('[EnvelopeRepo] ⏭️ Solo mode: skipping Firebase sync');
    }

    // Create initial transaction if needed
    if (startingAmount > 0) {
      final txId = _firestore.collection('_temp').doc().id;
      final transaction = models.Transaction(
        id: txId,
        envelopeId: id,
        type: models.TransactionType.deposit,
        amount: startingAmount,
        date: DateTime.now(),
        description: 'Initial balance',
        userId: _userId,
      );

      await _transactionBox.put(txId, transaction);
      debugPrint('[EnvelopeRepo] ✅ Initial transaction saved to Hive');
    }

    return id;
  }

  // ==================== UPDATE ====================

  /// Update envelope
  Future<void> updateEnvelope({
    required String envelopeId,
    String? name,
    double? targetAmount,
    DateTime? targetDate,
    String? emoji,
    String? iconType,
    String? iconValue,
    int? iconColor,
    String? subtitle,
    String? groupId,
    bool? autoFillEnabled,
    double? autoFillAmount,
    bool? isShared,
    String? linkedAccountId,
  }) async {
    debugPrint('[EnvelopeRepo] Updating envelope: $envelopeId');

    final envelope = _envelopeBox.get(envelopeId);
    if (envelope == null) {
      throw Exception('Envelope not found: $envelopeId');
    }

    // Create updated envelope
    final updatedEnvelope = Envelope(
      id: envelope.id,
      name: name ?? envelope.name,
      userId: envelope.userId,
      currentAmount: envelope.currentAmount,
      targetAmount: targetAmount ?? envelope.targetAmount,
      targetDate: targetDate ?? envelope.targetDate,
      groupId: groupId ?? envelope.groupId,
      subtitle: subtitle ?? envelope.subtitle,
      emoji: emoji ?? envelope.emoji,
      iconType: iconType ?? envelope.iconType,
      iconValue: iconValue ?? envelope.iconValue,
      iconColor: iconColor ?? envelope.iconColor,
      autoFillEnabled: autoFillEnabled ?? envelope.autoFillEnabled,
      autoFillAmount: autoFillAmount ?? envelope.autoFillAmount,
      linkedAccountId: linkedAccountId ?? envelope.linkedAccountId,
      isShared: isShared ?? envelope.isShared,
      isDebtEnvelope: envelope.isDebtEnvelope,
      startingDebt: envelope.startingDebt,
      termStartDate: envelope.termStartDate,
      termMonths: envelope.termMonths,
      monthlyPayment: envelope.monthlyPayment,
    );

    await _envelopeBox.put(envelopeId, updatedEnvelope);
    debugPrint('[EnvelopeRepo] ✅ Updated in Hive');

    // Only sync to Firebase if in workspace mode
    if (_inWorkspace && _workspaceId != null) {
      try {
        final updateData = <String, dynamic>{
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (name != null) updateData['name'] = name;
        if (groupId != null) updateData['groupId'] = groupId;
        if (targetAmount != null) updateData['targetAmount'] = targetAmount;
        if (targetDate != null) updateData['targetDate'] = Timestamp.fromDate(targetDate);
        if (emoji != null) updateData['emoji'] = emoji;
        if (iconType != null) updateData['iconType'] = iconType;
        if (iconValue != null) updateData['iconValue'] = iconValue;
        if (iconColor != null) updateData['iconColor'] = iconColor;
        if (subtitle != null) updateData['subtitle'] = subtitle;
        if (autoFillEnabled != null) updateData['autoFillEnabled'] = autoFillEnabled;
        if (autoFillAmount != null) updateData['autoFillAmount'] = autoFillAmount;
        if (isShared != null) updateData['isShared'] = isShared;
        if (linkedAccountId != null) updateData['linkedAccountId'] = linkedAccountId;

        await _firestore
            .collection('workspaces')
            .doc(_workspaceId)
            .collection('envelopes')
            .doc(envelopeId)
            .update(updateData);

        debugPrint('[EnvelopeRepo] ✅ Synced update to Firebase workspace');
      } catch (e) {
        debugPrint('[EnvelopeRepo] ⚠️ Firebase sync failed: $e');
        // Don't throw - Hive update succeeded
      }
    } else {
      debugPrint('[EnvelopeRepo] ⏭️ Solo mode: skipping Firebase sync');
    }
  }

  // ==================== DELETE ====================

  /// Delete envelope
  Future<void> deleteEnvelope(String id) async {
    debugPrint('[EnvelopeRepo] Deleting envelope: $id');

    // Delete transactions from Hive
    final txsToDelete = _transactionBox.values
        .where((tx) => tx.envelopeId == id)
        .map((tx) => tx.id)
        .toList();

    for (final txId in txsToDelete) {
      await _transactionBox.delete(txId);
    }
    debugPrint('[EnvelopeRepo] ✅ Deleted ${txsToDelete.length} transactions from Hive');

    // Delete envelope from Hive
    await _envelopeBox.delete(id);
    debugPrint('[EnvelopeRepo] ✅ Deleted from Hive');

    // Only sync to Firebase if in workspace mode
    if (_inWorkspace && _workspaceId != null) {
      try {
        await _firestore
            .collection('workspaces')
            .doc(_workspaceId)
            .collection('envelopes')
            .doc(id)
            .delete();

        debugPrint('[EnvelopeRepo] ✅ Deleted from Firebase workspace');
      } catch (e) {
        debugPrint('[EnvelopeRepo] ⚠️ Firebase delete failed: $e');
        // Don't throw - Hive delete succeeded
      }
    } else {
      debugPrint('[EnvelopeRepo] ⏭️ Solo mode: skipping Firebase sync');
    }
  }

  Future<void> deleteEnvelopes(Iterable<String> ids) async {
    for (final id in ids) {
      await deleteEnvelope(id);
    }
  }

  // ==================== TRANSACTIONS ====================

  Future<void> _createTransaction(models.Transaction transaction) async {
    // ALWAYS save to Hive (local paper trail)
    await _transactionBox.put(transaction.id, transaction);
    debugPrint('[EnvelopeRepo] ✅ Transaction saved to Hive');

    // If workspace AND partner transfer, sync to Firebase
    final isPartnerTransfer = _inWorkspace &&
        transaction.type == models.TransactionType.transfer &&
        transaction.sourceOwnerId != null &&
        transaction.targetOwnerId != null &&
        transaction.sourceOwnerId != transaction.targetOwnerId;

    if (isPartnerTransfer && _workspaceId != null) {
      try {
        await _firestore
            .collection('workspaces')
            .doc(_workspaceId)
            .collection('transfers')
            .doc(transaction.id)
            .set({
          'id': transaction.id,
          'envelopeId': transaction.envelopeId,
          'type': transaction.type.name,
          'amount': transaction.amount,
          'date': Timestamp.fromDate(transaction.date),
          'description': transaction.description,
          'userId': transaction.userId,
          'transferDirection': transaction.transferDirection?.name,
          'transferPeerEnvelopeId': transaction.transferPeerEnvelopeId,
          'transferLinkId': transaction.transferLinkId,
          'sourceOwnerId': transaction.sourceOwnerId,
          'targetOwnerId': transaction.targetOwnerId,
          'sourceEnvelopeName': transaction.sourceEnvelopeName,
          'targetEnvelopeName': transaction.targetEnvelopeName,
        });

        debugPrint('[EnvelopeRepo] ✅ Partner transfer synced to Firebase');
      } catch (e) {
        debugPrint('[EnvelopeRepo] ⚠️ Transfer sync failed: $e');
      }
    }
  }

  // ==================== OPERATIONS ====================

  /// Deposit
  Future<void> deposit({
    required String envelopeId,
    required double amount,
    required String description,
    DateTime? date,
  }) async {
    final envelope = _envelopeBox.get(envelopeId);
    if (envelope == null) throw Exception('Envelope not found');

    final updatedEnvelope = Envelope(
      id: envelope.id,
      name: envelope.name,
      userId: envelope.userId,
      currentAmount: envelope.currentAmount + amount,
      targetAmount: envelope.targetAmount,
      targetDate: envelope.targetDate,
      groupId: envelope.groupId,
      subtitle: envelope.subtitle,
      emoji: envelope.emoji,
      iconType: envelope.iconType,
      iconValue: envelope.iconValue,
      iconColor: envelope.iconColor,
      autoFillEnabled: envelope.autoFillEnabled,
      autoFillAmount: envelope.autoFillAmount,
      linkedAccountId: envelope.linkedAccountId,
      isShared: envelope.isShared,
      isDebtEnvelope: envelope.isDebtEnvelope,
      startingDebt: envelope.startingDebt,
      termStartDate: envelope.termStartDate,
      termMonths: envelope.termMonths,
      monthlyPayment: envelope.monthlyPayment,
    );

    final transaction = models.Transaction(
      id: _firestore.collection('_temp').doc().id,
      envelopeId: envelopeId,
      userId: _userId,
      type: models.TransactionType.deposit,
      amount: amount,
      date: date ?? DateTime.now(),
      description: description,
    );

    await _envelopeBox.put(envelopeId, updatedEnvelope);
    await _createTransaction(transaction);

    // Sync envelope amount to Firebase if in workspace
    if (_inWorkspace && _workspaceId != null) {
      try {
        await _firestore
            .collection('workspaces')
            .doc(_workspaceId)
            .collection('envelopes')
            .doc(envelopeId)
            .update({
          'currentAmount': updatedEnvelope.currentAmount,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('[EnvelopeRepo] ✅ Synced amount to Firebase workspace');
      } catch (e) {
        debugPrint('[EnvelopeRepo] ⚠️ Failed to sync amount: $e');
      }
    } else {
      debugPrint('[EnvelopeRepo] ⏭️ Solo mode: skipping Firebase sync');
    }

    debugPrint('[EnvelopeRepo] ✅ Deposit: +£$amount to ${envelope.name}');
  }

  /// Withdraw
  Future<void> withdraw({
    required String envelopeId,
    required double amount,
    required String description,
    DateTime? date,
  }) async {
    final envelope = _envelopeBox.get(envelopeId);
    if (envelope == null) throw Exception('Envelope not found');

    if (envelope.currentAmount < amount) {
      throw Exception('Insufficient funds');
    }

    final updatedEnvelope = Envelope(
      id: envelope.id,
      name: envelope.name,
      userId: envelope.userId,
      currentAmount: envelope.currentAmount - amount,
      targetAmount: envelope.targetAmount,
      targetDate: envelope.targetDate,
      groupId: envelope.groupId,
      subtitle: envelope.subtitle,
      emoji: envelope.emoji,
      iconType: envelope.iconType,
      iconValue: envelope.iconValue,
      iconColor: envelope.iconColor,
      autoFillEnabled: envelope.autoFillEnabled,
      autoFillAmount: envelope.autoFillAmount,
      linkedAccountId: envelope.linkedAccountId,
      isShared: envelope.isShared,
      isDebtEnvelope: envelope.isDebtEnvelope,
      startingDebt: envelope.startingDebt,
      termStartDate: envelope.termStartDate,
      termMonths: envelope.termMonths,
      monthlyPayment: envelope.monthlyPayment,
    );

    final transaction = models.Transaction(
      id: _firestore.collection('_temp').doc().id,
      envelopeId: envelopeId,
      userId: _userId,
      type: models.TransactionType.withdrawal,
      amount: amount,
      date: date ?? DateTime.now(),
      description: description,
    );

    await _envelopeBox.put(envelopeId, updatedEnvelope);
    await _createTransaction(transaction);

    // Sync envelope amount to Firebase if in workspace
    if (_inWorkspace && _workspaceId != null) {
      try {
        await _firestore
            .collection('workspaces')
            .doc(_workspaceId)
            .collection('envelopes')
            .doc(envelopeId)
            .update({
          'currentAmount': updatedEnvelope.currentAmount,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('[EnvelopeRepo] ✅ Synced amount to Firebase workspace');
      } catch (e) {
        debugPrint('[EnvelopeRepo] ⚠️ Failed to sync amount: $e');
      }
    } else {
      debugPrint('[EnvelopeRepo] ⏭️ Solo mode: skipping Firebase sync');
    }

    debugPrint('[EnvelopeRepo] ✅ Withdrawal: -£$amount from ${envelope.name}');
  }

  /// Transfer between envelopes
  Future<void> transfer({
    required String fromEnvelopeId,
    required String toEnvelopeId,
    required double amount,
    required String description,
    DateTime? date,
  }) async {
    final sourceEnv = _envelopeBox.get(fromEnvelopeId);
    final targetEnv = _envelopeBox.get(toEnvelopeId);

    if (sourceEnv == null || targetEnv == null) {
      throw Exception('Envelope not found');
    }

    if (sourceEnv.currentAmount < amount) {
      throw Exception('Insufficient funds');
    }

    // Update envelopes
    final updatedSource = Envelope(
      id: sourceEnv.id,
      name: sourceEnv.name,
      userId: sourceEnv.userId,
      currentAmount: sourceEnv.currentAmount - amount,
      targetAmount: sourceEnv.targetAmount,
      targetDate: sourceEnv.targetDate,
      groupId: sourceEnv.groupId,
      subtitle: sourceEnv.subtitle,
      emoji: sourceEnv.emoji,
      iconType: sourceEnv.iconType,
      iconValue: sourceEnv.iconValue,
      iconColor: sourceEnv.iconColor,
      autoFillEnabled: sourceEnv.autoFillEnabled,
      autoFillAmount: sourceEnv.autoFillAmount,
      linkedAccountId: sourceEnv.linkedAccountId,
      isShared: sourceEnv.isShared,
      isDebtEnvelope: sourceEnv.isDebtEnvelope,
      startingDebt: sourceEnv.startingDebt,
      termStartDate: sourceEnv.termStartDate,
      termMonths: sourceEnv.termMonths,
      monthlyPayment: sourceEnv.monthlyPayment,
    );

    final updatedTarget = Envelope(
      id: targetEnv.id,
      name: targetEnv.name,
      userId: targetEnv.userId,
      currentAmount: targetEnv.currentAmount + amount,
      targetAmount: targetEnv.targetAmount,
      targetDate: targetEnv.targetDate,
      groupId: targetEnv.groupId,
      subtitle: targetEnv.subtitle,
      emoji: targetEnv.emoji,
      iconType: targetEnv.iconType,
      iconValue: targetEnv.iconValue,
      iconColor: targetEnv.iconColor,
      autoFillEnabled: targetEnv.autoFillEnabled,
      autoFillAmount: targetEnv.autoFillAmount,
      linkedAccountId: targetEnv.linkedAccountId,
      isShared: targetEnv.isShared,
      isDebtEnvelope: targetEnv.isDebtEnvelope,
      startingDebt: targetEnv.startingDebt,
      termStartDate: targetEnv.termStartDate,
      termMonths: targetEnv.termMonths,
      monthlyPayment: targetEnv.monthlyPayment,
    );

    await _envelopeBox.put(fromEnvelopeId, updatedSource);
    await _envelopeBox.put(toEnvelopeId, updatedTarget);

    // Create linked transactions
    final transferLinkId = _firestore.collection('_temp').doc().id;

    final outTransaction = models.Transaction(
      id: _firestore.collection('_temp').doc().id,
      envelopeId: fromEnvelopeId,
      userId: _userId,
      type: models.TransactionType.transfer,
      amount: amount,
      date: date ?? DateTime.now(),
      description: description,
      transferDirection: models.TransferDirection.out_,
      transferPeerEnvelopeId: toEnvelopeId,
      transferLinkId: transferLinkId,
      sourceOwnerId: sourceEnv.userId,
      targetOwnerId: targetEnv.userId,
      sourceEnvelopeName: sourceEnv.name,
      targetEnvelopeName: targetEnv.name,
    );

    final inTransaction = models.Transaction(
      id: _firestore.collection('_temp').doc().id,
      envelopeId: toEnvelopeId,
      userId: _userId,
      type: models.TransactionType.transfer,
      amount: amount,
      date: date ?? DateTime.now(),
      description: description,
      transferDirection: models.TransferDirection.in_,
      transferPeerEnvelopeId: fromEnvelopeId,
      transferLinkId: transferLinkId,
      sourceOwnerId: sourceEnv.userId,
      targetOwnerId: targetEnv.userId,
      sourceEnvelopeName: sourceEnv.name,
      targetEnvelopeName: targetEnv.name,
    );

    await _createTransaction(outTransaction);
    await _createTransaction(inTransaction);

    // Sync envelope amounts to Firebase if in workspace
    if (_inWorkspace && _workspaceId != null) {
      try {
        await _firestore
            .collection('workspaces')
            .doc(_workspaceId)
            .collection('envelopes')
            .doc(fromEnvelopeId)
            .update({
          'currentAmount': updatedSource.currentAmount,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        await _firestore
            .collection('workspaces')
            .doc(_workspaceId)
            .collection('envelopes')
            .doc(toEnvelopeId)
            .update({
          'currentAmount': updatedTarget.currentAmount,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('[EnvelopeRepo] ✅ Synced amounts to Firebase workspace');
      } catch (e) {
        debugPrint('[EnvelopeRepo] ⚠️ Failed to sync amounts: $e');
      }
    } else {
      debugPrint('[EnvelopeRepo] ⏭️ Solo mode: skipping Firebase sync');
    }

    debugPrint('[EnvelopeRepo] ✅ Transfer: £$amount from ${sourceEnv.name} → ${targetEnv.name}');
  }

  // ==================== GROUP MANAGEMENT ====================

  Future<void> updateGroupMembership({
    required String groupId,
    required Set<String> newEnvelopeIds,
    required Stream<List<Envelope>> allEnvelopesStream,
  }) async {
    // Get current envelopes in this group from Hive
    final allEnvelopes = _envelopeBox.values.toList();
    final currentIds = allEnvelopes
        .where((e) => e.groupId == groupId)
        .map((e) => e.id)
        .toSet();

    final toRemove = currentIds.difference(newEnvelopeIds);
    final toAddOrKeep = newEnvelopeIds;

    // Groups are ALWAYS local only - update Hive only
    for (final id in toRemove) {
      final envelope = _envelopeBox.get(id);
      if (envelope != null) {
        final updated = Envelope(
          id: envelope.id,
          name: envelope.name,
          userId: envelope.userId,
          currentAmount: envelope.currentAmount,
          targetAmount: envelope.targetAmount,
          targetDate: envelope.targetDate,
          groupId: null, // Remove from group
          emoji: envelope.emoji,
          iconType: envelope.iconType,
          iconValue: envelope.iconValue,
          iconColor: envelope.iconColor,
          subtitle: envelope.subtitle,
          autoFillEnabled: envelope.autoFillEnabled,
          autoFillAmount: envelope.autoFillAmount,
          isShared: envelope.isShared,
          linkedAccountId: envelope.linkedAccountId,
          isDebtEnvelope: envelope.isDebtEnvelope,
          startingDebt: envelope.startingDebt,
          termStartDate: envelope.termStartDate,
          termMonths: envelope.termMonths,
          monthlyPayment: envelope.monthlyPayment,
        );
        await _envelopeBox.put(id, updated);
      }
    }

    for (final id in toAddOrKeep) {
      final envelope = _envelopeBox.get(id);
      if (envelope != null) {
        final updated = Envelope(
          id: envelope.id,
          name: envelope.name,
          userId: envelope.userId,
          currentAmount: envelope.currentAmount,
          targetAmount: envelope.targetAmount,
          targetDate: envelope.targetDate,
          groupId: groupId, // Add to group
          emoji: envelope.emoji,
          iconType: envelope.iconType,
          iconValue: envelope.iconValue,
          iconColor: envelope.iconColor,
          subtitle: envelope.subtitle,
          autoFillEnabled: envelope.autoFillEnabled,
          autoFillAmount: envelope.autoFillAmount,
          isShared: envelope.isShared,
          linkedAccountId: envelope.linkedAccountId,
          isDebtEnvelope: envelope.isDebtEnvelope,
          startingDebt: envelope.startingDebt,
          termStartDate: envelope.termStartDate,
          termMonths: envelope.termMonths,
          monthlyPayment: envelope.monthlyPayment,
        );
        await _envelopeBox.put(id, updated);
      }
    }

    debugPrint('[EnvelopeRepo] ✅ Updated group membership in Hive (local only)');
  }

  // ==================== WORKSPACE ====================

  Future<void> setWorkspace(String? newWorkspaceId) async {
    debugPrint('[EnvelopeRepo] Setting workspace to: $newWorkspaceId');

    await _firestore.collection('users').doc(_userId).set({
      'workspaceId': newWorkspaceId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ==================== HELPERS ====================

  Future<List<Envelope>> getAllEnvelopes() {
    return envelopesStream().first;
  }

  Stream<List<Envelope>> unlinkedEnvelopesStream() {
    return envelopesStream().map((envelopes) =>
        envelopes.where((e) => e.linkedAccountId == null).toList());
  }

  Future<void> linkEnvelopesToAccount(
      List<String> envelopeIds, String accountId) async {
    for (final envelopeId in envelopeIds) {
      final envelope = _envelopeBox.get(envelopeId);
      if (envelope != null) {
        final updated = Envelope(
          id: envelope.id,
          name: envelope.name,
          userId: envelope.userId,
          currentAmount: envelope.currentAmount,
          targetAmount: envelope.targetAmount,
          targetDate: envelope.targetDate,
          groupId: envelope.groupId,
          emoji: envelope.emoji,
          iconType: envelope.iconType,
          iconValue: envelope.iconValue,
          iconColor: envelope.iconColor,
          subtitle: envelope.subtitle,
          autoFillEnabled: envelope.autoFillEnabled,
          autoFillAmount: envelope.autoFillAmount,
          isShared: envelope.isShared,
          linkedAccountId: accountId,
          isDebtEnvelope: envelope.isDebtEnvelope,
          startingDebt: envelope.startingDebt,
          termStartDate: envelope.termStartDate,
          termMonths: envelope.termMonths,
          monthlyPayment: envelope.monthlyPayment,
        );
        await _envelopeBox.put(envelopeId, updated);
      }
    }
    debugPrint('[EnvelopeRepo] ✅ Linked ${envelopeIds.length} envelopes to account');

    // Sync to Firebase if in workspace
    if (_inWorkspace && _workspaceId != null) {
      for (final envelopeId in envelopeIds) {
        try {
          await _firestore
              .collection('workspaces')
              .doc(_workspaceId)
              .collection('envelopes')
              .doc(envelopeId)
              .update({
            'linkedAccountId': accountId,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint('[EnvelopeRepo] ⚠️ Failed to sync link: $e');
        }
      }
      debugPrint('[EnvelopeRepo] ✅ Synced links to Firebase workspace');
    } else {
      debugPrint('[EnvelopeRepo] ⏭️ Solo mode: skipping Firebase sync');
    }
  }

  Future<List<models.Transaction>> getAllTransactions() {
    return transactionsStream.first;
  }

  Future<List<models.Transaction>> getTransactions(String envelopeId) {
    return transactionsForEnvelope(envelopeId).first;
  }

  /// Get display name or nickname for a user
  Future<String> getUserDisplayName(String userId) async {
    try {
      // First check if current user has a nickname for this person
      final currentUserDoc = await _firestore
          .collection('users')
          .doc(_userId)
          .get();
      final currentUserData = currentUserDoc.data();
      final nicknames =
          (currentUserData?['nicknames'] as Map<String, dynamic>?) ?? {};
      final nickname = (nicknames[userId] as String?)?.trim();

      if (nickname != null && nickname.isNotEmpty) {
        return nickname;
      }

      // Fall back to their display name
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      final displayName = (userData?['displayName'] as String?)?.trim();

      return displayName ?? 'Unknown User';
    } catch (e) {
      debugPrint('[EnvelopeRepo] Error getting user display name: $e');
      return 'Unknown User';
    }
  }
}
