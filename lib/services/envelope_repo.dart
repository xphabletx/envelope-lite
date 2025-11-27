// lib/services/envelope_repo.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/envelope.dart';
import '../models/envelope_group.dart';
import '../models/transaction.dart';
import 'package:rxdart/rxdart.dart';
import 'dart:ui' as ui;

/// Firestore repo (canonical storage is always user/solo),
/// with optional workspace *context* tagging on writes.
/// Nothing is ever "moved" when switching workspaces, so
/// envelopes, groups, and transactions persist across modes.
///
/// Notes:
/// - We DO write `ownerDisplayName` into Firestore (so history
///   can render names), but we DO NOT read it from Envelope
///   objects (your Envelope model doesn't expose it). This
///   prevents undefined getter errors.
/// - Streams read only from canonical user scope.
/// - Workspace is used for tagging/filtering only.
/// - Includes a workspace "registry" (read-only index) so members
///   can discover each other's envelopes for transfers.
///
/// Registry path:
/// workspaces/{workspaceId}/registry/v1/envelopes/{envelopeId}
class EnvelopeRepo {
  EnvelopeRepo.firebase(this._db, {String? workspaceId, required String userId})
    : _workspaceId = (workspaceId?.isEmpty ?? true) ? null : workspaceId,
      _userId = userId;

  final fs.FirebaseFirestore _db;
  final String _userId;
  String? _workspaceId; // null => Solo mode

  final Map<String, String> _userDisplayNameCache = {};
  final Map<String, String> _userNicknameCache =
      {}; // For future nickname feature

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

  // Fetch display name for a user (with caching)
  // Fetch display name for a user (with caching and nickname support)
  Future<String> getUserDisplayName(String userId) async {
    // Check cache first
    if (_userDisplayNameCache.containsKey(userId)) {
      return _userDisplayNameCache[userId]!;
    }

    // Check if current user has set a nickname for this person
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
      // Fall through to regular display name
    }

    // Fetch actual display name from user's document
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

  // Clear cached display name (call when nickname changes)
  void clearUserDisplayNameCache(String userId) {
    _userDisplayNameCache.remove(userId);
  }

  // Check if envelope belongs to current user
  bool isMyEnvelope(Envelope envelope) => envelope.userId == _userId;

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
  Stream<List<Envelope>> get envelopesStream {
    // Solo mode: just return own envelopes
    if (!inWorkspace) {
      return _colEnvelopes()
          .orderBy('createdAt', descending: false)
          .snapshots()
          .map(
            (s) => s.docs
                .map(
                  (d) => Envelope.fromFirestore(
                    d as fs.DocumentSnapshot<Map<String, dynamic>>,
                  ),
                )
                .toList(),
          );
    }

    // Workspace mode: combine streams from all members
    return _db.collection('workspaces').doc(_workspaceId).snapshots().switchMap(
      (workspaceSnap) {
        if (!workspaceSnap.exists) {
          return Stream.value(<Envelope>[]);
        }

        final workspaceData = workspaceSnap.data();
        final members =
            (workspaceData?['members'] as Map<String, dynamic>?) ?? {};

        if (members.isEmpty) {
          return Stream.value(<Envelope>[]);
        }

        // Create a stream for each member's envelopes
        final memberStreams = members.keys.map((memberId) {
          return _db
              .collection('users')
              .doc(memberId)
              .collection('solo')
              .doc('data')
              .collection('envelopes')
              .orderBy('createdAt', descending: false)
              .snapshots()
              .map(
                (snap) => snap.docs
                    .map((doc) => Envelope.fromFirestore(doc))
                    .toList(),
              );
        }).toList();

        // Combine all member streams into one
        return CombineLatestStream.list(
          memberStreams,
        ).map((listOfLists) => listOfLists.expand((list) => list).toList());
      },
    );
  }

  Stream<List<EnvelopeGroup>> get groupsStream {
    return _colGroups()
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (s) => s.docs.map((doc) {
            final data = doc.data();
            return EnvelopeGroup(
              id: doc.id,
              name: (data['name'] ?? 'Unnamed Group') as String,
              userId:
                  (data['ownerId'] ?? data['userId'] ?? 'unknown') as String,
            );
          }).toList(),
        );
  }

  Stream<List<Transaction>> get transactionsStream {
    // Solo mode: just your transactions
    if (!inWorkspace) {
      return _colTxs()
          .orderBy('date', descending: true)
          .snapshots()
          .map(
            (s) => s.docs
                .map(
                  (d) => Transaction.fromFirestore(
                    d as fs.DocumentSnapshot<Map<String, dynamic>>,
                  ),
                )
                .toList(),
          );
    }

    // Workspace mode: fetch transactions from all workspace members
    return _db.collection('workspaces').doc(_workspaceId).snapshots().asyncMap((
      workspaceSnap,
    ) async {
      if (!workspaceSnap.exists) return <Transaction>[];

      final workspaceData = workspaceSnap.data();
      final members =
          (workspaceData?['members'] as Map<String, dynamic>?) ?? {};

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

      // Sort all transactions by date
      allTransactions.sort((a, b) => b.date.compareTo(a.date));

      return allTransactions;
    });
  }

  // ------------------------------ Workspace ----------------------------------
  /// Switch workspace context. Storage stays user-scoped; we just tag future
  /// writes with workspaceId for context/filtering.
  Future<void> setWorkspace(String? newWorkspaceId) async {
    _workspaceId = (newWorkspaceId?.isEmpty ?? true) ? null : newWorkspaceId;

    // Store the workspaceId on the user document so we know they're in a workspace
    await _db.collection('users').doc(_userId).set({
      'workspaceId': _workspaceId,
      'updatedAt': fs.FieldValue.serverTimestamp(),
    }, fs.SetOptions(merge: true));
  }

  // -------------------------------- Envelopes --------------------------------
  Future<void> deleteEnvelopes(Iterable<String> ids) async {
    final idList = ids.toList();

    // 1) delete envelopes
    final b1 = _db.batch();
    for (final id in idList) {
      b1.delete(_colEnvelopes().doc(id));
    }
    await b1.commit();

    // 2) delete related transactions in chunks (whereIn limit 10)
    for (var i = 0; i < idList.length; i += 10) {
      final chunk = idList.sublist(
        i,
        (i + 10 > idList.length) ? idList.length : i + 10,
      );
      final snap = await _colTxs().where('envelopeId', whereIn: chunk).get();
      final b = _db.batch();
      for (final d in snap.docs) {
        b.delete(d.reference);
      }
      await b.commit();
    }

    // 3) remove registry entries if applicable
    if (inWorkspace) {
      for (final id in idList) {
        await _removeRegistryForEnvelope(id);
      }
    }
  }

  Future<String> createEnvelope({
    required String name,
    required double startingAmount,
    double? targetAmount,
    String? groupId,
    String? subtitle,
    bool autoFillEnabled = false,
    double? autoFillAmount,
  }) async {
    final doc = _colEnvelopes().doc();

    final user = FirebaseAuth.instance.currentUser;
    final ownerDisplayName = user?.displayName ?? (user?.email ?? 'Me');

    final data = {
      'id': doc.id,
      'name': name,
      'userId': _userId, // legacy field your models already read
      'ownerId': _userId, // explicit owner
      'ownerDisplayName': ownerDisplayName, // for history rendering
      'currentAmount': startingAmount,
      'targetAmount': targetAmount,
      'groupId': groupId,
      'isShared': inWorkspace, // true when created while viewing a workspace
      'workspaceId': _workspaceId, // context only
      'createdAt': fs.FieldValue.serverTimestamp(),
      'updatedAt': fs.FieldValue.serverTimestamp(),
    };

    await doc.set(data);

    // initial balance transaction (if any)
    if (startingAmount > 0) {
      final txDoc = _colTxs().doc();
      await txDoc.set({
        'id': txDoc.id,
        'envelopeId': doc.id,
        'type': TransactionType.deposit.name,
        'amount': startingAmount,
        'date': fs.FieldValue.serverTimestamp(),
        'description': 'Initial balance',
        // actor
        'userId': _userId,
        'workspaceId': _workspaceId,
        // envelope owner for this tx
        'ownerId': _userId,
        'ownerDisplayName': ownerDisplayName,
        // transfer enrich fields (null for deposit)
        'transferPeerEnvelopeId': null,
        'transferLinkId': null,
        'transferDirection': null,
        'sourceOwnerId': null,
        'sourceOwnerDisplayName': null,
        'sourceEnvelopeName': null,
        'targetOwnerId': null,
        'targetOwnerDisplayName': null,
        'targetEnvelopeName': null,
        'emoji': null, // defaults to null
        'subtitle': subtitle,
        'autoFillEnabled': autoFillEnabled,
        'autoFillAmount': autoFillAmount,
      });
    }

    // keep registry up-to-date while in a workspace
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
    String? emoji, // ADD THIS
    String? subtitle, // ADD THIS
    String? groupId,
    bool? autoFillEnabled,
    double? autoFillAmount,
  }) async {
    final updateData = <String, dynamic>{
      'updatedAt': fs.FieldValue.serverTimestamp(),
    };
    if (name != null) updateData['name'] = name;
    if (groupId != null) updateData['groupId'] = groupId;
    if (targetAmount != null) updateData['targetAmount'] = targetAmount;
    if (emoji != null) updateData['emoji'] = emoji; // ADD THIS
    if (subtitle != null) updateData['subtitle'] = subtitle; // ADD THIS
    if (autoFillEnabled != null)
      updateData['autoFillEnabled'] = autoFillEnabled;
    if (autoFillAmount != null) updateData['autoFillAmount'] = autoFillAmount;

    await _colEnvelopes().doc(envelopeId).update(updateData);

    // refresh registry snapshot if in workspace
    if (inWorkspace) {
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
    }
  }

  /// Update group membership for multiple envelopes (chunked whereIn).
  /// Per requirement: collaborators may add/remove *any* envelope to groups.
  Future<void> updateGroupMembership({
    required String groupId,
    required Set<String> newEnvelopeIds,
    required Stream<List<Envelope>> allEnvelopesStream, // API parity
  }) async {
    // 1) Fetch current members of this group
    final currentSnap = await _colEnvelopes()
        .where('groupId', isEqualTo: groupId)
        .get();

    final currentIds = currentSnap.docs.map((d) => d.id).toSet();

    // 2) Compute deltas
    final toRemove = currentIds.difference(newEnvelopeIds);
    final toAddOrKeep = newEnvelopeIds;

    // 3) Helper to apply updates
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

    // 4) Clear old members
    await applyBatchLocal(toRemove, {
      'groupId': null,
      'updatedAt': fs.FieldValue.serverTimestamp(),
    });

    // 5) Add/retain members
    await applyBatchLocal(toAddOrKeep, {
      'groupId': groupId,
      'updatedAt': fs.FieldValue.serverTimestamp(),
    });

    // Registry doesn't change here (envelope name/amount unchanged).
  }

  // --------------------------- Transactions ----------------------------

  /// Writes:
  /// - Deposit/Withdrawal: single tx doc + balance update.
  /// - Transfer: TWO linked tx docs (out + in) + update BOTH balances.
  ///
  /// Adds rich owner/envelope metadata so you can render:
  /// “Transfer from 'Alice' Recreation to 'Bob' Takeaway … £10”
  Future<void> recordTransaction(
    Transaction tx, {
    Envelope? from,
    Envelope? to,
  }) async {
    final batch = _db.batch();

    // The actor performing the action now.
    final actorId = _userId;
    final actorName =
        FirebaseAuth.instance.currentUser?.displayName ??
        (FirebaseAuth.instance.currentUser?.email ?? 'Someone');

    if (tx.type == TransactionType.transfer && from != null && to != null) {
      // Link both legs
      final linkId = _db.collection('_links').doc().id;

      // Owners of the envelopes (these are Envelope.userId fields)
      final fromOwnerId = from.userId;
      final toOwnerId = to.userId;

      // We don't have Envelope.ownerDisplayName on the model; use safe fallbacks.
      final fromOwnerName = (fromOwnerId == actorId) ? actorName : '';
      final toOwnerName = (toOwnerId == actorId) ? actorName : '';

      // -------- OUT leg (source envelope) --------
      final outRef = _colTxs().doc();
      batch.set(outRef, {
        'id': outRef.id,
        'envelopeId': from.id,
        'type': TransactionType.transfer.name,
        'amount': tx.amount,
        'date': fs.FieldValue.serverTimestamp(),
        'description': tx.description,
        // actor who executed the transfer
        'userId': actorId,
        // workspace context (for filtering/reporting)
        'workspaceId': _workspaceId,

        // envelope owner for THIS leg (source)
        'ownerId': fromOwnerId,
        'ownerDisplayName': fromOwnerName,

        // transfer linkage + direction
        'transferPeerEnvelopeId': to.id,
        'transferLinkId': linkId,
        'transferDirection': TransferDirection.out_.name,

        // rich cross-party labels
        'sourceOwnerId': fromOwnerId,
        'sourceOwnerDisplayName': fromOwnerName,
        'sourceEnvelopeName': from.name,
        'targetOwnerId': toOwnerId,
        'targetOwnerDisplayName': toOwnerName,
        'targetEnvelopeName': to.name,
      });

      // -------- IN leg (target envelope) --------
      final inRef = _colTxs().doc();
      batch.set(inRef, {
        'id': inRef.id,
        'envelopeId': to.id,
        'type': TransactionType.transfer.name,
        'amount': tx.amount,
        'date': fs.FieldValue.serverTimestamp(),
        'description': tx.description,
        // actor who executed the transfer
        'userId': actorId,
        'workspaceId': _workspaceId,

        // envelope owner for THIS leg (target)
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

      // Update both balances (values already mutated on Envelope models)
      // Update both balances in their respective owner's collections
      batch.update(
        _db
            .collection('users')
            .doc(fromOwnerId)
            .collection('solo')
            .doc('data')
            .collection('envelopes')
            .doc(from.id),
        {
          'currentAmount': from.currentAmount,
          'updatedAt': fs.FieldValue.serverTimestamp(),
        },
      );

      batch.update(
        _db
            .collection('users')
            .doc(toOwnerId)
            .collection('solo')
            .doc('data')
            .collection('envelopes')
            .doc(to.id),
        {
          'currentAmount': to.currentAmount,
          'updatedAt': fs.FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();

      // keep registry amounts current if in workspace
      if (inWorkspace) {
        // We don't read ownerDisplayName from Envelope model
        // (supply empty or actorName when appropriate).
        await _upsertRegistryForEnvelope(
          envelopeId: from.id,
          envelopeName: from.name,
          currentAmount: from.currentAmount,
          ownerId: from.userId,
          ownerDisplayName: fromOwnerName,
        );
        await _upsertRegistryForEnvelope(
          envelopeId: to.id,
          envelopeName: to.name,
          currentAmount: to.currentAmount,
          ownerId: to.userId,
          ownerDisplayName: toOwnerName,
        );
      }

      return;
    }

    // ---------------- Deposit / Withdrawal ----------------
    // Try to capture envelope owner as well; if `from` is null,
    // use actor as fallback.
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
      // actor
      'userId': actorId,
      'workspaceId': _workspaceId,

      // envelope owner for this tx (single leg)
      'ownerId': ownerIdForSingle,
      'ownerDisplayName': ownerNameForSingle,

      // not a transfer => null the transfer fields
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

    if (from != null) {
      batch.update(_colEnvelopes().doc(from.id), {
        'currentAmount': from.currentAmount,
        'updatedAt': fs.FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    // keep registry amounts current if in workspace (for the single envelope)
    if (inWorkspace && from != null) {
      await _upsertRegistryForEnvelope(
        envelopeId: from.id,
        envelopeName: from.name,
        currentAmount: from.currentAmount,
        ownerId: from.userId,
        ownerDisplayName: ownerNameForSingle,
      );
    }
  }

  // ------------------------- (Optional) Utilities -------------------------

  /// Helper to commit large lists in safe chunks.
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
}
