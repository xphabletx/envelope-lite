// lib/services/envelope_repo.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';
import '../models/envelope.dart';
import '../models/envelope_group.dart';
import '../models/transaction.dart';
import 'package:rxdart/rxdart.dart';
import 'hive_service.dart';

/// Firestore repo (canonical storage is always user/solo),
/// with optional workspace *context* tagging on writes.
class EnvelopeRepo {
  EnvelopeRepo.firebase(this._db, {String? workspaceId, required String userId})
    : _workspaceId = (workspaceId?.isEmpty ?? true) ? null : workspaceId,
      _userId = userId {
    // Initialize Hive boxes
    _envelopeBox = HiveService.getBox<Envelope>('envelopes');
    _groupBox = HiveService.getBox<EnvelopeGroup>('groups');
    _transactionBox = HiveService.getBox<Transaction>('transactions');
  }

  final fs.FirebaseFirestore _db;
  final String _userId;
  String? _workspaceId; // null => Solo mode

  // Hive boxes for offline-first storage
  late final Box<Envelope> _envelopeBox;
  late final Box<EnvelopeGroup> _groupBox;
  late final Box<Transaction> _transactionBox;

  final Map<String, String> _userDisplayNameCache = {};

  // --------- Public getters ----------
  fs.FirebaseFirestore get db => _db;
  String get currentUserId => _userId;
  String? get workspaceId => _workspaceId;
  bool get inWorkspace => _workspaceId != null && _workspaceId!.isNotEmpty;

  // --------- Canonical user-scoped collections ----------
  fs.DocumentReference<Map<String, dynamic>> _docRootUser() =>
      _db.collection('users').doc(_userId).collection('solo').doc('data');

  fs.CollectionReference<Map<String, dynamic>> _colEnvelopes() =>
      _docRootUser().collection('envelopes');

  fs.CollectionReference<Map<String, dynamic>> _colGroups() =>
      _docRootUser().collection('groups');

  fs.CollectionReference<Map<String, dynamic>> _colTxs() =>
      _docRootUser().collection('transactions');

  // --------- Workspace registry (read-only index for discovery) ----------
  fs.CollectionReference<Map<String, dynamic>> _colRegistryEnvelopes() {
    if (!inWorkspace) {
      throw StateError(
        'Registry is only available inside a workspace context.',
      );
    }
    return _db
        .collection('workspaces')
        .doc(_workspaceId!)
        .collection('registry')
        .doc('v1')
        .collection('envelopes');
  }

  Future<void> _upsertRegistryForEnvelope({
    required String envelopeId,
    required String envelopeName,
    required double currentAmount,
    required String ownerId,
    required String ownerDisplayName,
  }) async {
    if (!inWorkspace) return;
    final ref = _colRegistryEnvelopes().doc(envelopeId);
    await ref.set({
      'id': envelopeId,
      'ownerId': ownerId,
      'ownerDisplayName': ownerDisplayName,
      'envelopeName': envelopeName,
      'currentAmount': currentAmount,
      'updatedAt': fs.FieldValue.serverTimestamp(),
    }, fs.SetOptions(merge: true));
  }

  Future<void> _removeRegistryForEnvelope(String envelopeId) async {
    if (!inWorkspace) return;
    await _colRegistryEnvelopes().doc(envelopeId).delete().catchError((_) {});
  }

  // Fetch display name for a user (with caching and nickname support)
  Future<String> getUserDisplayName(String userId) async {
    if (_userDisplayNameCache.containsKey(userId)) {
      return _userDisplayNameCache[userId]!;
    }

    try {
      final currentUserDoc = await _db.collection('users').doc(_userId).get();
      if (currentUserDoc.exists) {
        final nicknames =
            (currentUserDoc.data()?['nicknames'] as Map<String, dynamic>?) ??
            {};
        final nickname = nicknames[userId] as String?;
        if (nickname != null && nickname.isNotEmpty) {
          _userDisplayNameCache[userId] = nickname;
          return nickname;
        }
      }
    } catch (e) {
      // Fall through
    }

    try {
      final userDoc = await _db.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final displayName =
            (userDoc.data()?['displayName'] as String?) ?? 'Unknown User';
        _userDisplayNameCache[userId] = displayName;
        return displayName;
      }
    } catch (e) {
      // Silently fail
    }

    _userDisplayNameCache[userId] = 'Unknown User';
    return 'Unknown User';
  }

  void clearUserDisplayNameCache(String userId) {
    _userDisplayNameCache.remove(userId);
  }

  bool isMyEnvelope(Envelope envelope) => envelope.userId == _userId;

  /// Auto-fix for stale workspace state
  Future<void> _clearStaleWorkspace() async {
    try {
      print('[EnvelopeRepo] Clearing stale workspace $_workspaceId for user $_userId');

      // Clear from user's profile
      await _db.collection('users').doc(_userId).set({
        'activeWorkspaceId': null,
      }, fs.SetOptions(merge: true));

      // Clear from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('active_workspace_id');
      await prefs.remove('last_workspace_id');
      await prefs.remove('last_workspace_name');

      // Update local state
      _workspaceId = null;

      print('[EnvelopeRepo] Stale workspace cleared successfully');
    } catch (e) {
      print('[EnvelopeRepo] Error clearing stale workspace: $e');
    }
  }

  /// Stream registry entries (for transfer pickers, etc.)
  Stream<List<Map<String, dynamic>>> get workspaceRegistryStream {
    if (!inWorkspace) {
      return Stream.value(const <Map<String, dynamic>>[]);
    }
    return _colRegistryEnvelopes()
        .orderBy('ownerDisplayName')
        .orderBy('envelopeName')
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
  }

  // --------------------------------- Streams ---------------------------------
  /// Get envelopes stream with optional partner filtering
  Stream<List<Envelope>> envelopesStream({bool showPartnerEnvelopes = true}) {
    if (!inWorkspace) {
      // Solo mode: Use Hive's watch() stream (only emits when data changes)
      debugPrint('[EnvelopeRepo] 📦 Setting up Hive stream (solo mode)');

      // Emit initial state immediately
      final initialEnvelopes = _envelopeBox.values
          .where((env) => env.userId == _userId)
          .toList();
      debugPrint('[EnvelopeRepo] ✅ Initial state: ${initialEnvelopes.length} envelopes from Hive');

      // Then listen for changes
      return Stream.value(initialEnvelopes).asBroadcastStream().concatWith([
        _envelopeBox.watch().map((_) {
          final envelopes = _envelopeBox.values
              .where((env) => env.userId == _userId)
              .toList();
          debugPrint('[EnvelopeRepo] ✅ Emitting ${envelopes.length} envelopes from Hive');
          return envelopes;
        })
      ]);
    }

    return _db.collection('workspaces').doc(_workspaceId).snapshots().switchMap(
      (workspaceSnap) {
        if (!workspaceSnap.exists) return Stream.value(<Envelope>[]);

        final workspaceData = workspaceSnap.data();
        final members =
            (workspaceData?['members'] as Map<String, dynamic>?) ?? {};

        // CRITICAL: Check if current user is still a member
        if (!members.containsKey(_userId)) {
          print('[EnvelopeRepo] User $_userId is not a member of workspace $_workspaceId. Returning empty list.');
          // Auto-fix: Clear the stale workspace ID
          _clearStaleWorkspace();
          return Stream.value(<Envelope>[]);
        }

        if (members.isEmpty) return Stream.value(<Envelope>[]);

        final memberIds = showPartnerEnvelopes
            ? members.keys.toList()
            : [_userId];

        final memberStreams = memberIds.map((memberId) {
          return _db
              .collection('users')
              .doc(memberId)
              .collection('solo')
              .doc('data')
              .collection('envelopes')
              .orderBy('createdAt', descending: false)
              .snapshots()
              .map((snap) {
                return snap.docs
                    .map((doc) => Envelope.fromFirestore(doc))
                    .where((env) => env.userId == _userId || env.isShared)
                    .toList();
              });
        }).toList();

        return CombineLatestStream.list(
          memberStreams,
        ).map((listOfLists) => listOfLists.expand((list) => list).toList());
      },
    );
  }

  Stream<List<Envelope>> get envelopesStreamAll =>
      envelopesStream(showPartnerEnvelopes: true);

  Stream<List<EnvelopeGroup>> get groupsStream {
    if (!inWorkspace) {
      // Solo mode: Use Hive's watch() stream (only emits when data changes)
      debugPrint('[EnvelopeRepo] 📦 Setting up Hive groups stream (solo mode)');

      // Emit initial state immediately
      final initialGroups = _groupBox.values
          .where((group) => group.userId == _userId)
          .toList();
      debugPrint('[EnvelopeRepo] ✅ Initial state: ${initialGroups.length} groups from Hive');

      // Then listen for changes
      return Stream.value(initialGroups).asBroadcastStream().concatWith([
        _groupBox.watch().map((_) {
          final groups = _groupBox.values
              .where((group) => group.userId == _userId)
              .toList();
          debugPrint('[EnvelopeRepo] ✅ Emitting ${groups.length} groups from Hive');
          return groups;
        })
      ]);
    }

    // For workspace mode, read from all members' solo groups (filtered by isShared)
    return _db.collection('workspaces').doc(_workspaceId).snapshots().switchMap(
      (workspaceSnap) {
        if (!workspaceSnap.exists) return Stream.value(<EnvelopeGroup>[]);

        final workspaceData = workspaceSnap.data();
        final members = (workspaceData?['members'] as Map<String, dynamic>?) ?? {};

        // CRITICAL: Check if current user is still a member
        if (!members.containsKey(_userId)) {
          print('[EnvelopeRepo] User $_userId is not a member of workspace $_workspaceId (groups). Returning empty list.');
          return Stream.value(<EnvelopeGroup>[]);
        }

        if (members.isEmpty) return Stream.value(<EnvelopeGroup>[]);

        final memberIds = members.keys.toList();

        // Stream groups from each member's solo collection
        final memberStreams = memberIds.map((memberId) {
          return _db
              .collection('users')
              .doc(memberId)
              .collection('solo')
              .doc('data')
              .collection('groups')
              .orderBy('createdAt', descending: false)
              .snapshots()
              .map((snap) {
                return snap.docs
                    .map((doc) => EnvelopeGroup.fromFirestore(doc))
                    .where((group) => group.userId == _userId || group.isShared)
                    .toList();
              });
        }).toList();

        return CombineLatestStream.list(
          memberStreams,
        ).map((listOfLists) => listOfLists.expand((list) => list).toList());
      },
    );
  }

  /// Get transactions for a specific envelope
  Stream<List<Transaction>> transactionsForEnvelope(String envelopeId) {
    return transactionsStream.map(
      (allTxs) => allTxs.where((tx) => tx.envelopeId == envelopeId).toList(),
    );
  }

  Stream<List<Transaction>> get transactionsStream {
    if (!inWorkspace) {
      // Solo mode: Use Hive's watch() stream (only emits when data changes)
      debugPrint('[EnvelopeRepo] 📦 Setting up Hive transactions stream (solo mode)');

      // Emit initial state immediately
      final initialTxs = _transactionBox.values
          .where((tx) => tx.userId == _userId)
          .toList();
      initialTxs.sort((a, b) => b.date.compareTo(a.date)); // Newest first
      debugPrint('[EnvelopeRepo] ✅ Initial state: ${initialTxs.length} transactions from Hive');

      // Then listen for changes
      return Stream.value(initialTxs).asBroadcastStream().concatWith([
        _transactionBox.watch().map((_) {
          final txs = _transactionBox.values
              .where((tx) => tx.userId == _userId)
              .toList();
          txs.sort((a, b) => b.date.compareTo(a.date)); // Newest first
          debugPrint('[EnvelopeRepo] ✅ Emitting ${txs.length} transactions from Hive');
          return txs;
        })
      ]);
    }

    return _db.collection('workspaces').doc(_workspaceId).snapshots().asyncMap((
      workspaceSnap,
    ) async {
      if (!workspaceSnap.exists) return <Transaction>[];

      final workspaceData = workspaceSnap.data();
      final members =
          (workspaceData?['members'] as Map<String, dynamic>?) ?? {};

      // CRITICAL: Check if current user is still a member
      if (!members.containsKey(_userId)) {
        print('[EnvelopeRepo] User $_userId is not a member of workspace $_workspaceId (transactions). Returning empty list.');
        return <Transaction>[];
      }

      if (members.isEmpty) return <Transaction>[];

      final List<Transaction> allTransactions = [];

      for (final memberId in members.keys) {
        final memberTxsSnap = await _db
            .collection('users')
            .doc(memberId)
            .collection('solo')
            .doc('data')
            .collection('transactions')
            .orderBy('date', descending: true)
            .get();

        for (final doc in memberTxsSnap.docs) {
          allTransactions.add(Transaction.fromFirestore(doc));
        }
      }

      allTransactions.sort((a, b) => b.date.compareTo(a.date));
      return allTransactions;
    });
  }

  // ------------------------------ Workspace ----------------------------------
  Future<void> setWorkspace(String? newWorkspaceId) async {
    print('[EnvelopeRepo] DEBUG: Setting workspace to: $newWorkspaceId');
    _workspaceId = (newWorkspaceId?.isEmpty ?? true) ? null : newWorkspaceId;

    await _db.collection('users').doc(_userId).set({
      'workspaceId': _workspaceId,
      'updatedAt': fs.FieldValue.serverTimestamp(),
    }, fs.SetOptions(merge: true));
  }

  // -------------------------------- Envelopes --------------------------------
  Future<void> deleteEnvelopes(Iterable<String> ids) async {
    debugPrint('[EnvelopeRepo] DEBUG BULK DELETE:');
    final idList = ids.toList();
    debugPrint('  - Deleting ${idList.length} envelopes');
    debugPrint('  - Envelope IDs: $idList');
    debugPrint('  - inWorkspace: $inWorkspace');

    // STEP 1: Delete from Hive first
    debugPrint('[EnvelopeRepo] 📦 STEP 1: Deleting from Hive...');
    for (final id in idList) {
      // Delete transactions for this envelope
      final txsToDelete = _transactionBox.values
          .where((tx) => tx.envelopeId == id)
          .map((tx) => tx.id)
          .toList();

      debugPrint('  - Envelope $id: Deleting ${txsToDelete.length} transactions from Hive');
      for (final txId in txsToDelete) {
        await _transactionBox.delete(txId);
      }

      // Delete the envelope itself
      await _envelopeBox.delete(id);
      debugPrint('  - Envelope $id: Deleted from Hive');
    }
    debugPrint('[EnvelopeRepo] ✅ All ${idList.length} envelopes deleted from Hive');

    // STEP 2: Delete from Firebase (if in workspace mode)
    if (inWorkspace) {
      debugPrint('[EnvelopeRepo] 🔥 STEP 2: Deleting from Firebase workspace...');

      // Delete envelopes
      debugPrint('[EnvelopeRepo] 🔥 Deleting envelope documents...');
      final b1 = _db.batch();
      for (final id in idList) {
        b1.delete(_colEnvelopes().doc(id));
      }
      await b1.commit();
      debugPrint('[EnvelopeRepo] ✅ ${idList.length} envelope documents deleted from Firebase');

      // Delete transactions in chunks
      debugPrint('[EnvelopeRepo] 🔥 Deleting transactions...');
      int totalTxDeleted = 0;
      for (var i = 0; i < idList.length; i += 10) {
        final chunk = idList.sublist(
          i,
          (i + 10 > idList.length) ? idList.length : i + 10,
        );
        final snap = await _colTxs().where('envelopeId', whereIn: chunk).get();
        debugPrint('  - Chunk ${i ~/ 10 + 1}: Found ${snap.docs.length} transactions');
        final b = _db.batch();
        for (final d in snap.docs) {
          b.delete(d.reference);
        }
        await b.commit();
        totalTxDeleted += snap.docs.length;
      }
      debugPrint('[EnvelopeRepo] ✅ $totalTxDeleted transactions deleted from Firebase');

      // Remove from registry
      debugPrint('[EnvelopeRepo] 🔥 Removing from registry...');
      for (final id in idList) {
        await _removeRegistryForEnvelope(id);
      }
      debugPrint('[EnvelopeRepo] ✅ Registry entries removed');
    } else {
      debugPrint('[EnvelopeRepo] ⏭️ Skipping Firebase (solo mode)');
    }

    debugPrint('[EnvelopeRepo] ✅ BULK DELETE COMPLETE for ${idList.length} envelopes');
  }

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
    print('[EnvelopeRepo] DEBUG: Creating envelope with name: $name');
    final doc = _colEnvelopes().doc();

    final user = FirebaseAuth.instance.currentUser;
    final ownerDisplayName = user?.displayName ?? (user?.email ?? 'Me');

    // Create Envelope object
    final envelope = Envelope(
      id: doc.id,
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
      isShared: inWorkspace,
    );

    // ALWAYS write to Hive (primary storage)
    await _envelopeBox.put(doc.id, envelope);
    debugPrint('[EnvelopeRepo] ✅ Envelope saved to Hive: ${doc.id}');

    // ONLY write to Firebase if in workspace mode
    if (inWorkspace) {
      final data = {
        'id': doc.id,
        'name': name,
        'userId': _userId,
        'ownerId': _userId,
        'ownerDisplayName': ownerDisplayName,
        'currentAmount': startingAmount,
        'targetAmount': targetAmount,
        'targetDate': targetDate != null ? fs.Timestamp.fromDate(targetDate) : null,
        'groupId': groupId,
        'subtitle': subtitle,
        'emoji': emoji,
        'iconType': iconType,
        'iconValue': iconValue,
        'iconColor': iconColor,
        'autoFillEnabled': autoFillEnabled,
        'autoFillAmount': autoFillAmount,
        'linkedAccountId': linkedAccountId,
        'isShared': inWorkspace,
        'workspaceId': _workspaceId,
        'createdAt': fs.FieldValue.serverTimestamp(),
        'updatedAt': fs.FieldValue.serverTimestamp(),
      };

      await doc.set(data);
      debugPrint('[EnvelopeRepo] ✅ Envelope synced to Firebase workspace');
    } else {
      debugPrint('[EnvelopeRepo] ⏭️ Skipping Firebase (solo mode)');
    }

    if (startingAmount > 0) {
      final txDoc = _colTxs().doc();
      final transaction = Transaction(
        id: txDoc.id,
        envelopeId: doc.id,
        type: TransactionType.deposit,
        amount: startingAmount,
        date: DateTime.now(),
        description: 'Initial balance',
        userId: _userId,
      );

      // ALWAYS write to Hive
      await _transactionBox.put(txDoc.id, transaction);
      debugPrint('[EnvelopeRepo] ✅ Initial transaction saved to Hive');

      // ONLY write to Firebase if in workspace mode
      if (inWorkspace) {
        await txDoc.set({
          'id': txDoc.id,
          'envelopeId': doc.id,
          'type': TransactionType.deposit.name,
          'amount': startingAmount,
          'date': fs.FieldValue.serverTimestamp(),
          'description': 'Initial balance',
          'userId': _userId,
          'workspaceId': _workspaceId,
          'ownerId': _userId,
          'ownerDisplayName': ownerDisplayName,
          'transferPeerEnvelopeId': null,
          'transferLinkId': null,
          'transferDirection': null,
          'sourceOwnerId': null,
          'sourceOwnerDisplayName': null,
          'sourceEnvelopeName': null,
          'targetOwnerId': null,
          'targetOwnerDisplayName': null,
          'targetEnvelopeName': null,
          'emoji': null,
          'subtitle': subtitle,
          'autoFillEnabled': autoFillEnabled,
          'autoFillAmount': autoFillAmount,
        });
        debugPrint('[EnvelopeRepo] ✅ Initial transaction synced to Firebase');
      }
    }

    if (inWorkspace) {
      await _upsertRegistryForEnvelope(
        envelopeId: doc.id,
        envelopeName: name,
        currentAmount: startingAmount,
        ownerId: _userId,
        ownerDisplayName: ownerDisplayName,
      );
    }

    return doc.id;
  }

  Future<void> updateEnvelope({
    required String envelopeId,
    String? name,
    double? targetAmount,
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
    // DEBUG: Check workspace status
    final prefs = await SharedPreferences.getInstance();
    final workspaceId = prefs.getString('active_workspace_id');

    debugPrint('[EnvelopeRepo] DEBUG UPDATE:');
    debugPrint('  - Envelope ID: $envelopeId');
    debugPrint('  - WorkspaceId from prefs: ${workspaceId ?? "NULL"}');
    debugPrint('  - _workspaceId field: ${_workspaceId ?? "NULL"}');
    debugPrint('  - inWorkspace flag: $inWorkspace');

    // Get current envelope from Hive
    final envelope = _envelopeBox.get(envelopeId);
    if (envelope == null) {
      debugPrint('[EnvelopeRepo] ❌ Envelope not found in Hive: $envelopeId');
      throw Exception('Envelope not found: $envelopeId');
    }

    // Create updated envelope
    final updatedEnvelope = Envelope(
      id: envelope.id,
      name: name ?? envelope.name,
      userId: envelope.userId,
      currentAmount: envelope.currentAmount,
      targetAmount: targetAmount ?? envelope.targetAmount,
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

    // ALWAYS write to Hive
    await _envelopeBox.put(envelopeId, updatedEnvelope);
    debugPrint('[EnvelopeRepo] ✅ Envelope updated in Hive: $envelopeId');

    // Check Firebase sync
    if (inWorkspace && _workspaceId != null) {
      debugPrint('[EnvelopeRepo] 🔥 Syncing to Firebase workspace: $_workspaceId');
      try {
        final updateData = <String, dynamic>{
          'updatedAt': fs.FieldValue.serverTimestamp(),
        };
        if (name != null) updateData['name'] = name;
        if (groupId != null) updateData['groupId'] = groupId;
        if (targetAmount != null) updateData['targetAmount'] = targetAmount;
        if (emoji != null) updateData['emoji'] = emoji;
        if (iconType != null) updateData['iconType'] = iconType;
        if (iconValue != null) updateData['iconValue'] = iconValue;
        if (iconColor != null) updateData['iconColor'] = iconColor;
        if (subtitle != null) updateData['subtitle'] = subtitle;
        if (autoFillEnabled != null) {
          updateData['autoFillEnabled'] = autoFillEnabled;
        }
        if (autoFillAmount != null) updateData['autoFillAmount'] = autoFillAmount;
        if (isShared != null) updateData['isShared'] = isShared;
        if (linkedAccountId != null) {
          updateData['linkedAccountId'] = linkedAccountId;
        }

        await _colEnvelopes().doc(envelopeId).update(updateData);
        debugPrint('[EnvelopeRepo] ✅ Firebase sync successful');

        // Update registry
        final snap = await _colEnvelopes().doc(envelopeId).get();
        final d = snap.data();
        if (d != null) {
          final user = FirebaseAuth.instance.currentUser;
          final ownerDisplayName =
              (d['ownerDisplayName'] as String?) ??
              (user?.displayName ?? (user?.email ?? 'Me'));

          await _upsertRegistryForEnvelope(
            envelopeId: envelopeId,
            envelopeName: (d['name'] as String?) ?? 'Unnamed',
            currentAmount: (d['currentAmount'] as num?)?.toDouble() ?? 0.0,
            ownerId: (d['ownerId'] as String?) ?? _userId,
            ownerDisplayName: ownerDisplayName,
          );
        }
      } catch (e) {
        debugPrint('[EnvelopeRepo] ❌ Firebase sync failed: $e');
      }
    } else if (inWorkspace && _workspaceId == null) {
      debugPrint('[EnvelopeRepo] ⚠️ inWorkspace is TRUE but _workspaceId is NULL!');
      debugPrint('[EnvelopeRepo] ⚠️ This is a bug - workspace status is stale');
    } else {
      debugPrint('[EnvelopeRepo] ⏭️ Skipping Firebase (solo mode)');
    }
  }

  Future<void> updateGroupMembership({
    required String groupId,
    required Set<String> newEnvelopeIds,
    required Stream<List<Envelope>> allEnvelopesStream,
  }) async {
    final currentSnap = await _colEnvelopes()
        .where('groupId', isEqualTo: groupId)
        .get();

    final currentIds = currentSnap.docs.map((d) => d.id).toSet();

    final toRemove = currentIds.difference(newEnvelopeIds);
    final toAddOrKeep = newEnvelopeIds;

    Future<void> applyBatchLocal(
      Iterable<String> ids,
      Map<String, dynamic> data,
    ) async {
      if (ids.isEmpty) return;
      final b = _db.batch();
      for (final id in ids) {
        b.update(_colEnvelopes().doc(id), data);
      }
      await b.commit();
    }

    await applyBatchLocal(toRemove, {
      'groupId': null,
      'updatedAt': fs.FieldValue.serverTimestamp(),
    });

    await applyBatchLocal(toAddOrKeep, {
      'groupId': groupId,
      'updatedAt': fs.FieldValue.serverTimestamp(),
    });
  }

  // --------------------------- Transactions ----------------------------
  Future<void> recordTransaction(
    Transaction tx, {
    Envelope? from,
    Envelope? to,
    fs.WriteBatch? externalBatch, // New optional parameter
  }) async {
    final batch = externalBatch ?? _db.batch(); // Use external batch if provided, otherwise create new

    final actorId = _userId;
    final actorName =
        FirebaseAuth.instance.currentUser?.displayName ??
        (FirebaseAuth.instance.currentUser?.email ?? 'Someone');

    if (tx.type == TransactionType.transfer && from != null && to != null) {
      final linkId = _db.collection('_links').doc().id;

      final fromOwnerId = from.userId;
      final toOwnerId = to.userId;

      final fromOwnerName = (fromOwnerId == actorId) ? actorName : '';
      final toOwnerName = (toOwnerId == actorId) ? actorName : '';

      final outRef = _colTxs().doc();
      batch.set(outRef, {
        'id': outRef.id,
        'envelopeId': from.id,
        'type': TransactionType.transfer.name,
        'amount': tx.amount,
        'date': fs.FieldValue.serverTimestamp(),
        'description': tx.description,
        'userId': actorId,
        'workspaceId': _workspaceId,
        'ownerId': fromOwnerId,
        'ownerDisplayName': fromOwnerName,
        'transferPeerEnvelopeId': to.id,
        'transferLinkId': linkId,
        'transferDirection': TransferDirection.out_.name,
        'sourceOwnerId': fromOwnerId,
        'sourceOwnerDisplayName': fromOwnerName,
        'sourceEnvelopeName': from.name,
        'targetOwnerId': toOwnerId,
        'targetOwnerDisplayName': toOwnerName,
        'targetEnvelopeName': to.name,
      });

      final inRef = _colTxs().doc();
      batch.set(inRef, {
        'id': inRef.id,
        'envelopeId': to.id,
        'type': TransactionType.transfer.name,
        'amount': tx.amount,
        'date': fs.FieldValue.serverTimestamp(),
        'description': tx.description,
        'userId': actorId,
        'workspaceId': _workspaceId,
        'ownerId': toOwnerId,
        'ownerDisplayName': toOwnerName,
        'transferPeerEnvelopeId': from.id,
        'transferLinkId': linkId,
        'transferDirection': TransferDirection.in_.name,
        'sourceOwnerId': fromOwnerId,
        'sourceOwnerDisplayName': fromOwnerName,
        'sourceEnvelopeName': from.name,
        'targetOwnerId': toOwnerId,
        'targetOwnerDisplayName': toOwnerName,
        'targetEnvelopeName': to.name,
      });



      if (externalBatch == null) {
        await batch.commit();
      }



      return;
    }

    String ownerIdForSingle = actorId;
    String ownerNameForSingle = actorName;

    if (from != null) {
      ownerIdForSingle = from.userId;
      ownerNameForSingle = (from.userId == actorId) ? actorName : '';
    }

    final txRef = _colTxs().doc();
    batch.set(txRef, {
      'id': txRef.id,
      'envelopeId': tx.envelopeId,
      'type': tx.type.name,
      'amount': tx.amount,
      'date': fs.FieldValue.serverTimestamp(),
      'description': tx.description,
      'userId': actorId,
      'workspaceId': _workspaceId,
      'ownerId': ownerIdForSingle,
      'ownerDisplayName': ownerNameForSingle,
      'sourceOwnerId': null,
      'sourceOwnerDisplayName': null,
      'sourceEnvelopeName': null,
      'targetOwnerId': null,
      'targetOwnerDisplayName': null,
      'targetEnvelopeName': null,
      'transferPeerEnvelopeId': null,
      'transferLinkId': null,
      'transferDirection': null,
    });



    if (externalBatch == null) {
      await batch.commit();
    }


  }

  // ============= MODAL HELPER METHODS =============

  /// Get single envelope as stream (for live updates in settings)
  Stream<Envelope> envelopeStream(String envelopeId) {
    if (!inWorkspace) {
      // Solo mode: Use Hive's watch() stream (only emits when data changes)
      debugPrint('[EnvelopeRepo] 📦 Setting up Hive stream for envelope: $envelopeId');

      // Emit initial state immediately
      final initialEnvelope = _envelopeBox.get(envelopeId);
      if (initialEnvelope == null) {
        throw Exception('Envelope not found: $envelopeId');
      }
      debugPrint('[EnvelopeRepo] ✅ Initial state: ${initialEnvelope.name} (\$${initialEnvelope.currentAmount})');

      // Then listen for changes to this specific key
      return Stream.value(initialEnvelope).asBroadcastStream().concatWith([
        _envelopeBox.watch(key: envelopeId).map((_) {
          final envelope = _envelopeBox.get(envelopeId);
          if (envelope == null) {
            throw Exception('Envelope not found: $envelopeId');
          }
          debugPrint('[EnvelopeRepo] ✅ Emitting envelope update: ${envelope.name} (\$${envelope.currentAmount})');
          return envelope;
        })
      ]);
    }

    // Workspace mode: Stream from Firebase
    return _colEnvelopes()
        .doc(envelopeId)
        .snapshots()
        .asyncMap((doc) async {
      // If found in user's collection, return it
      if (doc.exists) {
        return Envelope.fromFirestore(doc);
      }

      // If not found and in workspace, check partner envelopes
      if (inWorkspace && _workspaceId != null) {
        final workspaceSnap = await _db.collection('workspaces').doc(_workspaceId).get();
        if (workspaceSnap.exists) {
          final workspaceData = workspaceSnap.data();
          final members = (workspaceData?['members'] as Map<String, dynamic>?) ?? {};

          // Search in each member's collection
          for (final memberId in members.keys) {
            if (memberId == _userId) continue; // Already checked above

            final partnerDoc = await _db
                .collection('users')
                .doc(memberId)
                .collection('solo')
                .doc('data')
                .collection('envelopes')
                .doc(envelopeId)
                .get();

            if (partnerDoc.exists) {
              return Envelope.fromFirestore(partnerDoc);
            }
          }
        }
      }

      // If still not found, throw error
      throw Exception('Envelope not found');
    });
  }

  /// Delete an envelope
  Future<void> deleteEnvelope(String envelopeId) async {
    debugPrint('[EnvelopeRepo] DEBUG DELETE:');
    debugPrint('  - Envelope ID: $envelopeId');
    debugPrint('  - Method called: deleteEnvelope');

    // Check if envelope exists in Hive
    final envelope = _envelopeBox.get(envelopeId);
    debugPrint('  - Envelope found in Hive: ${envelope != null}');

    if (envelope == null) {
      debugPrint('[EnvelopeRepo] ❌ Envelope not found in Hive: $envelopeId');
      throw Exception('Envelope not found: $envelopeId');
    }

    debugPrint('  - Envelope name: ${envelope.name}');
    debugPrint('  - Envelope userId: ${envelope.userId}');
    debugPrint('  - Current userId: $_userId');

    // Check workspace status
    final prefs = await SharedPreferences.getInstance();
    final workspaceId = prefs.getString('active_workspace_id');
    debugPrint('  - WorkspaceId from prefs: ${workspaceId ?? "NULL"}');
    debugPrint('  - _workspaceId field: ${_workspaceId ?? "NULL"}');
    debugPrint('  - inWorkspace flag: $inWorkspace');

    // 1. Delete all transactions for this envelope from Hive
    debugPrint('[EnvelopeRepo] 📦 Deleting transactions from Hive...');
    final txsToDelete = _transactionBox.values
        .where((tx) => tx.envelopeId == envelopeId)
        .map((tx) => tx.id)
        .toList();
    debugPrint('  - Found ${txsToDelete.length} transactions to delete');

    for (final txId in txsToDelete) {
      await _transactionBox.delete(txId);
    }
    debugPrint('[EnvelopeRepo] ✅ Deleted ${txsToDelete.length} transactions from Hive');

    // 2. Delete the envelope from Hive
    debugPrint('[EnvelopeRepo] 📦 Deleting envelope from Hive...');
    try {
      await _envelopeBox.delete(envelopeId);
      debugPrint('[EnvelopeRepo] ✅ Envelope deleted from Hive: $envelopeId');
    } catch (e) {
      debugPrint('[EnvelopeRepo] ❌ Error deleting from Hive: $e');
      rethrow;
    }

    // 3. If in workspace mode, also delete from Firebase
    if (inWorkspace && _workspaceId != null) {
      debugPrint('[EnvelopeRepo] 🔥 Deleting from Firebase workspace: $_workspaceId');
      try {
        final batch = _db.batch();

        // Delete all transactions for this envelope
        debugPrint('[EnvelopeRepo] 🔥 Querying Firebase transactions...');
        final txSnapshot = await _colTxs()
            .where('envelopeId', isEqualTo: envelopeId)
            .get();
        debugPrint('  - Found ${txSnapshot.docs.length} Firebase transactions');

        for (final doc in txSnapshot.docs) {
          batch.delete(doc.reference);
        }

        // Delete all scheduled payments for this envelope
        debugPrint('[EnvelopeRepo] 🔥 Querying Firebase scheduled payments...');
        final paymentSnapshot = await _docRootUser()
            .collection('scheduledPayments')
            .where('envelopeId', isEqualTo: envelopeId)
            .get();
        debugPrint('  - Found ${paymentSnapshot.docs.length} Firebase scheduled payments');

        for (final doc in paymentSnapshot.docs) {
          batch.delete(doc.reference);
        }

        // Remove envelope from any groups (update envelopeIds array)
        debugPrint('[EnvelopeRepo] 🔥 Querying Firebase groups...');
        final groupsSnapshot = await _colGroups()
            .get();
        debugPrint('  - Found ${groupsSnapshot.docs.length} Firebase groups');

        for (final doc in groupsSnapshot.docs) {
          final data = doc.data();
          final envelopeIds = (data['envelopeIds'] as List<dynamic>?)?.cast<String>() ?? [];

          if (envelopeIds.contains(envelopeId)) {
            debugPrint('  - Removing envelope from group: ${doc.id}');
            batch.update(doc.reference, {
              'envelopeIds': envelopeIds.where((id) => id != envelopeId).toList(),
              'updatedAt': fs.FieldValue.serverTimestamp(),
            });
          }
        }

        // Delete the envelope itself
        debugPrint('[EnvelopeRepo] 🔥 Deleting envelope document from Firebase...');
        batch.delete(_colEnvelopes().doc(envelopeId));

        debugPrint('[EnvelopeRepo] 🔥 Committing Firebase batch...');
        await batch.commit();
        debugPrint('[EnvelopeRepo] ✅ Envelope deleted from Firebase workspace');

        // Remove from registry
        debugPrint('[EnvelopeRepo] 🔥 Removing from registry...');
        await _removeRegistryForEnvelope(envelopeId);
        debugPrint('[EnvelopeRepo] ✅ Removed from registry');
      } catch (e) {
        debugPrint('[EnvelopeRepo] ❌ Firebase delete failed: $e');
        // Don't rethrow - Hive delete succeeded
      }
    } else if (inWorkspace && _workspaceId == null) {
      debugPrint('[EnvelopeRepo] ⚠️ inWorkspace is TRUE but _workspaceId is NULL!');
      debugPrint('[EnvelopeRepo] ⚠️ This is a bug - workspace status is stale');
    } else {
      debugPrint('[EnvelopeRepo] ⏭️ Skipping Firebase (solo mode)');
    }

    debugPrint('[EnvelopeRepo] ✅ DELETE COMPLETE for envelope: $envelopeId');
  }

  /// Deposit money into envelope
  Future<void> deposit({
    required String envelopeId,
    required double amount,
    required String description,
    DateTime? date,
  }) async {
    // Get envelope from Hive
    final envelope = _envelopeBox.get(envelopeId);
    if (envelope == null) {
      throw Exception('Envelope not found: $envelopeId');
    }

    // Create transaction
    final txId = _db.collection('_temp').doc().id; // Generate ID
    final tx = Transaction(
      id: txId,
      envelopeId: envelopeId,
      type: TransactionType.deposit,
      amount: amount,
      date: date ?? DateTime.now(),
      description: description,
      userId: _userId,
    );

    // Update envelope in Hive
    final updatedEnvelope = Envelope(
      id: envelope.id,
      name: envelope.name,
      userId: envelope.userId,
      currentAmount: envelope.currentAmount + amount,
      targetAmount: envelope.targetAmount,
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

    await _envelopeBox.put(envelopeId, updatedEnvelope);
    await _transactionBox.put(txId, tx);
    debugPrint('[EnvelopeRepo] ✅ Deposit saved to Hive: +\$$amount');

    // Sync to Firebase if in workspace
    if (inWorkspace) {
      final batch = _db.batch();
      await recordTransaction(tx, externalBatch: batch);
      batch.update(_colEnvelopes().doc(envelopeId), {
        'currentAmount': fs.FieldValue.increment(amount),
        'updatedAt': fs.FieldValue.serverTimestamp(),
      });
      await batch.commit();
      debugPrint('[EnvelopeRepo] ✅ Deposit synced to Firebase workspace');

      await _upsertRegistryForEnvelope(
        envelopeId: envelope.id,
        envelopeName: envelope.name,
        currentAmount: envelope.currentAmount + amount,
        ownerId: envelope.userId,
        ownerDisplayName: await getUserDisplayName(envelope.userId),
      );
    }
  }

  /// Withdraw money from envelope
  Future<void> withdraw({
    required String envelopeId,
    required double amount,
    required String description,
    DateTime? date,
  }) async {
    // Get envelope from Hive
    final envelope = _envelopeBox.get(envelopeId);
    if (envelope == null) {
      throw Exception('Envelope not found: $envelopeId');
    }

    if (envelope.currentAmount < amount) {
      throw Exception('Insufficient funds in envelope');
    }

    // Create transaction
    final txId = _db.collection('_temp').doc().id;
    final tx = Transaction(
      id: txId,
      envelopeId: envelopeId,
      type: TransactionType.withdrawal,
      amount: amount,
      date: date ?? DateTime.now(),
      description: description,
      userId: _userId,
    );

    // Update envelope in Hive
    final updatedEnvelope = Envelope(
      id: envelope.id,
      name: envelope.name,
      userId: envelope.userId,
      currentAmount: envelope.currentAmount - amount,
      targetAmount: envelope.targetAmount,
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

    await _envelopeBox.put(envelopeId, updatedEnvelope);
    await _transactionBox.put(txId, tx);
    debugPrint('[EnvelopeRepo] ✅ Withdrawal saved to Hive: -\$$amount');

    // Sync to Firebase if in workspace
    if (inWorkspace) {
      final batch = _db.batch();
      await recordTransaction(tx, externalBatch: batch);
      batch.update(_colEnvelopes().doc(envelopeId), {
        'currentAmount': fs.FieldValue.increment(-amount),
        'updatedAt': fs.FieldValue.serverTimestamp(),
      });
      await batch.commit();
      debugPrint('[EnvelopeRepo] ✅ Withdrawal synced to Firebase workspace');

      await _upsertRegistryForEnvelope(
        envelopeId: envelope.id,
        envelopeName: envelope.name,
        currentAmount: envelope.currentAmount - amount,
        ownerId: envelope.userId,
        ownerDisplayName: await getUserDisplayName(envelope.userId),
      );
    }
  }

  /// Transfer money between envelopes
  Future<void> transfer({
    required String fromEnvelopeId,
    required String toEnvelopeId,
    required double amount,
    required String description,
    DateTime? date,
  }) async {
    print('[EnvelopeRepo] DEBUG: Transferring $amount from $fromEnvelopeId to $toEnvelopeId');

    // Fetch from envelope (always from current user's collection for transfers initiated by user)
    final fromDoc = await _colEnvelopes().doc(fromEnvelopeId).get();
    if (!fromDoc.exists) {
      throw Exception('Source envelope not found');
    }
    final fromEnvelope = Envelope.fromFirestore(fromDoc);

    // Fetch to envelope - could be from current user OR partner's collection
    Envelope? toEnvelope;
    fs.DocumentSnapshot<Map<String, dynamic>>? toDoc;

    // First try current user's collection
    toDoc = await _colEnvelopes().doc(toEnvelopeId).get();
    if (toDoc.exists) {
      toEnvelope = Envelope.fromFirestore(toDoc);
    } else if (inWorkspace && _workspaceId != null) {
      // If not found and in workspace, check partner envelopes
      final workspaceSnap = await _db.collection('workspaces').doc(_workspaceId).get();
      if (workspaceSnap.exists) {
        final workspaceData = workspaceSnap.data();
        final members = (workspaceData?['members'] as Map<String, dynamic>?) ?? {};

        // Search in each member's collection
        for (final memberId in members.keys) {
          if (memberId == _userId) continue; // Already checked above

          final partnerDoc = await _db
              .collection('users')
              .doc(memberId)
              .collection('solo')
              .doc('data')
              .collection('envelopes')
              .doc(toEnvelopeId)
              .get();

          if (partnerDoc.exists) {
            toEnvelope = Envelope.fromFirestore(partnerDoc);
            toDoc = partnerDoc;
            break;
          }
        }
      }
    }

    if (toEnvelope == null) {
      throw Exception('Target envelope not found');
    }

    if (fromEnvelope.currentAmount < amount) {
      throw Exception('Insufficient funds in source envelope');
    }

    final tx = Transaction(
      id: '',
      envelopeId: fromEnvelopeId,
      type: TransactionType.transfer,
      amount: amount,
      date: date ?? DateTime.now(),
      description: description,
      userId: _userId,
    );

    final batch = _db.batch(); // Create a single batch for all operations

    await recordTransaction(
      tx,
      from: fromEnvelope,
      to: toEnvelope,
      externalBatch: batch, // Pass the batch to recordTransaction
    );

    // Update from envelope in its owner's collection
    final fromEnvelopeRef = _db
        .collection('users')
        .doc(fromEnvelope.userId)
        .collection('solo')
        .doc('data')
        .collection('envelopes')
        .doc(fromEnvelopeId);

    batch.update(fromEnvelopeRef, {
      'currentAmount': fs.FieldValue.increment(-amount),
      'updatedAt': fs.FieldValue.serverTimestamp(),
    });

    // Update to envelope in its owner's collection
    final toEnvelopeRef = _db
        .collection('users')
        .doc(toEnvelope.userId)
        .collection('solo')
        .doc('data')
        .collection('envelopes')
        .doc(toEnvelopeId);

    batch.update(toEnvelopeRef, {
      'currentAmount': fs.FieldValue.increment(amount),
      'updatedAt': fs.FieldValue.serverTimestamp(),
    });

    await batch.commit(); // Commit the single batch

    if (inWorkspace) {
      await _upsertRegistryForEnvelope(
        envelopeId: fromEnvelope.id,
        envelopeName: fromEnvelope.name,
        currentAmount: fromEnvelope.currentAmount - amount,
        ownerId: fromEnvelope.userId,
        ownerDisplayName: await getUserDisplayName(fromEnvelope.userId),
      );

      await _upsertRegistryForEnvelope(
        envelopeId: toEnvelope.id,
        envelopeName: toEnvelope.name,
        currentAmount: toEnvelope.currentAmount + amount,
        ownerId: toEnvelope.userId,
        ownerDisplayName: await getUserDisplayName(toEnvelope.userId),
      );
    }
  }

  Future<void> commitInChunks<T>(
    List<T> items,
    void Function(fs.WriteBatch b, T item) addWrite, {
    int maxOps = 400,
  }) async {
    var i = 0;
    while (i < items.length) {
      final end = (i + maxOps > items.length) ? items.length : i + maxOps;
      final batch = _db.batch();
      for (final item in items.sublist(i, end)) {
        addWrite(batch, item);
      }
      await batch.commit();
      i = end;
    }
  }

  // ============= EXPORT / HELPER METHODS =============

  /// Fetch all envelopes once (for CSV export)
  Future<List<Envelope>> getAllEnvelopes() {
    return envelopesStream().first;
  }

  Stream<List<Envelope>> unlinkedEnvelopesStream() {
    return envelopesStream().map((envelopes) =>
        envelopes.where((e) => e.linkedAccountId == null).toList());
  }

  Future<void> linkEnvelopesToAccount(
      List<String> envelopeIds, String accountId) async {
    final batch = _db.batch();
    for (final envelopeId in envelopeIds) {
      batch.update(_colEnvelopes().doc(envelopeId), {
        'linkedAccountId': accountId,
        'updatedAt': fs.FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  /// Fetch all transactions once (for CSV export)
  Future<List<Transaction>> getAllTransactions() {
    return transactionsStream.first;
  }

  /// Fetch transactions for a specific envelope once
  Future<List<Transaction>> getTransactions(String envelopeId) {
    return transactionsForEnvelope(envelopeId).first;
  }
}
