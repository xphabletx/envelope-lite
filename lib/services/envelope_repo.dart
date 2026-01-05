// lib/services/envelope_repo.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import 'package:rxdart/rxdart.dart';
import '../models/envelope.dart';
import '../models/envelope_group.dart';
import '../models/transaction.dart' as models;
import '../models/scheduled_payment.dart';
import 'hive_service.dart';
import 'sync_manager.dart';
import 'pay_day_settings_service.dart';

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
  final SyncManager _syncManager = SyncManager();

  // Track active Firestore stream subscriptions for proper cleanup
  final List<StreamSubscription> _activeSubscriptions = [];
  bool _disposed = false;

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
    // GUARD: Don't initialize if user is not authenticated
    if (FirebaseAuth.instance.currentUser == null) {
      return;
    }
  }

  /// Dispose and cancel all active Firestore stream subscriptions
  ///
  /// CRITICAL: Call this before logging out to prevent PERMISSION_DENIED errors
  /// from Firestore streams trying to access data after auth state changes
  void dispose() {
    if (_disposed) {
      return;
    }

    for (final subscription in _activeSubscriptions) {
      subscription.cancel();
    }
    _activeSubscriptions.clear();
    _disposed = true;
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
    // GUARD: Return empty stream if user is not authenticated (during logout)
    if (FirebaseAuth.instance.currentUser == null) {
      return Stream.value([]);
    }

    if (!_inWorkspace) {
      // SOLO MODE: Pure Hive
      final initial = _envelopeBox.values
          .where((env) => env.userId == _userId)
          .toList();

      return Stream.value(initial).asBroadcastStream().concatWith([
        _envelopeBox.watch().map((_) {
          final envelopes = _envelopeBox.values
              .where((env) => env.userId == _userId)
              .toList();

          return envelopes;
        })
      ]);

    } else {
      // WORKSPACE MODE: Firebase sync from workspace envelopes collection

      return _firestore
          .collection('workspaces')
          .doc(_workspaceId)
          .collection('envelopes')
          .orderBy('createdAt', descending: false)
          .snapshots()
          .handleError((error) {
            // Handle PERMISSION_DENIED errors gracefully (happens after logout)
            // Return empty list to allow graceful degradation
            return const Stream<List<Envelope>>.empty();
          })
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

            return allEnvelopes;
          })
          .handleError((error) {
            // Catch any errors during asyncMap as well
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
            // Envelope was deleted - close the stream gracefully
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
          .handleError((error) {
            // Handle PERMISSION_DENIED errors gracefully (happens after logout)
          })
          .asyncMap((doc) async {
            if (!doc.exists) {
              throw Exception('Envelope not found: $id');
            }

            final envelope = Envelope.fromFirestore(doc);
            await _envelopeBox.put(id, envelope);

            return envelope;
          })
          .handleError((error) {
          });
    }
  }

  /// Groups stream (ALWAYS local only - no workspace sync)
  Stream<List<EnvelopeGroup>> get groupsStream {
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

  // ==================== SYNCHRONOUS DATA ACCESS ====================
  // These methods provide instant access to Hive data without streams
  // Used as initialData for StreamBuilders to eliminate UI lag

  /// Get all envelopes synchronously from Hive
  /// Returns filtered list based on userId and optionally workspaceId
  List<Envelope> getEnvelopesSync({bool showPartnerEnvelopes = true}) {
    final envelopes = _envelopeBox.values
        .where((env) {
          // Filter by userId in solo mode
          if (!_inWorkspace) {
            return env.userId == _userId;
          }
          // In workspace mode, filter based on showPartnerEnvelopes flag
          return showPartnerEnvelopes || env.userId == _userId;
        })
        .toList();

    return envelopes;
  }

  /// Get single envelope synchronously from Hive
  Envelope? getEnvelopeSync(String id) {
    return _envelopeBox.get(id);
  }

  /// Get all transactions synchronously from Hive
  List<models.Transaction> getTransactionsSync() {
    return _transactionBox.values
        .where((tx) => tx.userId == _userId)
        .toList();
  }

  /// Get transactions for specific envelope synchronously
  List<models.Transaction> getTransactionsForEnvelopeSync(String envelopeId) {
    return _transactionBox.values
        .where((tx) => tx.envelopeId == envelopeId && tx.userId == _userId)
        .toList();
  }

  /// Get all groups synchronously from Hive
  List<EnvelopeGroup> getGroupsSync() {
    return _groupBox.values
        .where((group) => group.userId == _userId)
        .toList();
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
    final id = _firestore.collection('_temp').doc().id;
    final now = DateTime.now();

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
      isSynced: false, // Mark as pending sync
      lastUpdated: now,
      createdAt: now, // Capture creation timestamp for accurate target date progress
    );

    // ALWAYS write to Hive first (primary storage)
    await _envelopeBox.put(id, envelope);

    // Background sync (fire-and-forget, non-blocking)
    // SOLO MODE: Syncs to /users/{userId}/envelopes
    // WORKSPACE MODE: Syncs to /workspaces/{workspaceId}/envelopes
    _syncManager.pushEnvelope(envelope, _workspaceId, _userId);


    // Create initial transaction if needed
    if (startingAmount > 0) {
      final txId = _firestore.collection('_temp').doc().id;
      final transaction = models.Transaction(
        id: txId,
        envelopeId: id,
        type: models.TransactionType.deposit,
        amount: startingAmount,
        date: now,
        description: 'Initial balance',
        userId: _userId,
        isSynced: false,
        lastUpdated: now,
      );

      await _transactionBox.put(txId, transaction);
    }

    return id;
  }

  // ==================== UPDATE ====================

  /// Update envelope
  ///
  /// IMPORTANT: Parameters are nullable to support partial updates.
  /// To explicitly set a field to null (e.g., unlink an account), pass the parameter explicitly.
  /// Fields not provided will retain their current values.
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
    bool updateLinkedAccountId = false, // Flag to explicitly update linkedAccountId (including to null)
    bool updateTargetAmount = false, // Flag to explicitly update targetAmount (including to null)
    bool updateTargetDate = false, // Flag to explicitly update targetDate (including to null)
    TargetStartDateType? targetStartDateType,
    DateTime? customTargetStartDate,
    bool updateTargetStartDateType = false, // Flag to explicitly update targetStartDateType (including to null)
    bool updateCustomTargetStartDate = false, // Flag to explicitly update customTargetStartDate (including to null)
  }) async {
    final envelope = _envelopeBox.get(envelopeId);
    if (envelope == null) {
      throw Exception('Envelope not found: $envelopeId');
    }

    // Create updated envelope with sync metadata
    // Use the explicit flags to allow setting fields to null
    final now = DateTime.now();

    late Envelope updatedEnvelope;
    try {
      updatedEnvelope = Envelope(
        id: envelope.id,
        name: name ?? envelope.name,
        userId: envelope.userId,
        currentAmount: envelope.currentAmount,
        targetAmount: updateTargetAmount ? targetAmount : envelope.targetAmount,
        targetDate: updateTargetDate ? targetDate : envelope.targetDate,
        groupId: groupId ?? envelope.groupId,
        subtitle: subtitle ?? envelope.subtitle,
        emoji: emoji ?? envelope.emoji,
        iconType: iconType ?? envelope.iconType,
        iconValue: iconValue ?? envelope.iconValue,
        iconColor: iconColor ?? envelope.iconColor,
        autoFillEnabled: autoFillEnabled ?? envelope.autoFillEnabled,
        autoFillAmount: autoFillAmount ?? envelope.autoFillAmount,
        linkedAccountId: updateLinkedAccountId ? linkedAccountId : envelope.linkedAccountId,
        isShared: isShared ?? envelope.isShared,
        isDebtEnvelope: envelope.isDebtEnvelope,
        startingDebt: envelope.startingDebt,
        termStartDate: envelope.termStartDate,
        termMonths: envelope.termMonths,
        monthlyPayment: envelope.monthlyPayment,
        isSynced: false, // Mark as pending sync
        lastUpdated: now,
        createdAt: envelope.createdAt, // Preserve creation timestamp
        targetStartDateType: updateTargetStartDateType ? targetStartDateType : envelope.targetStartDateType,
        customTargetStartDate: updateCustomTargetStartDate ? customTargetStartDate : envelope.customTargetStartDate,
      );

      await _envelopeBox.put(envelopeId, updatedEnvelope);
    } catch (e) {
      rethrow;
    }

    // Background sync (fire-and-forget, non-blocking)
    _syncManager.pushEnvelope(updatedEnvelope, _workspaceId, _userId);
  }

  // ==================== DELETE ====================

  /// Delete envelope
  Future<void> deleteEnvelope(String id) async {
    // Delete transactions from Hive
    final txsToDelete = _transactionBox.values
        .where((tx) => tx.envelopeId == id)
        .map((tx) => tx.id)
        .toList();

    for (final txId in txsToDelete) {
      await _transactionBox.delete(txId);
    }

    // Delete scheduled payments linked to this envelope from Hive
    final scheduledPaymentBox = HiveService.getBox<ScheduledPayment>('scheduledPayments');
    final paymentsToDelete = scheduledPaymentBox.values
        .where((payment) => payment.envelopeId == id)
        .map((payment) => payment.id)
        .toList();

    for (final paymentId in paymentsToDelete) {
      await scheduledPaymentBox.delete(paymentId);
    }

    // Delete envelope from Hive
    await _envelopeBox.delete(id);

    // Background sync deletion (fire-and-forget, non-blocking)
    _syncManager.deleteEnvelope(id, _workspaceId, _userId);
  }

  Future<void> deleteEnvelopes(Iterable<String> ids) async {
    for (final id in ids) {
      await deleteEnvelope(id);
    }
  }

  /// Clean up orphaned scheduled payments (for existing data migration)
  /// Call this during app initialization to remove scheduled payments
  /// that reference deleted envelopes
  Future<int> cleanupOrphanedScheduledPayments() async {
    final scheduledPaymentBox = HiveService.getBox<ScheduledPayment>('scheduledPayments');

    // Get all valid envelope IDs
    final validEnvelopeIds = _envelopeBox.values
        .where((env) => env.userId == _userId)
        .map((env) => env.id)
        .toSet();

    // Find orphaned scheduled payments
    final orphanedPayments = scheduledPaymentBox.values
        .where((payment) =>
            payment.userId == _userId &&
            payment.envelopeId != null &&
            !validEnvelopeIds.contains(payment.envelopeId))
        .toList();

    // Delete them
    int deletedCount = 0;
    for (final payment in orphanedPayments) {
      await scheduledPaymentBox.delete(payment.id);
      deletedCount++;
    }

    return deletedCount;
  }

  // ==================== TRANSACTIONS ====================

  Future<void> _createTransaction(models.Transaction transaction) async {
    // CRITICAL: Never persist future/projected transactions from TimeMachine
    if (transaction.isFuture) {
      return; // TimeMachine projections must never be saved
    }

    // ALWAYS save to Hive (local paper trail)
    await _transactionBox.put(transaction.id, transaction);

    // Determine if this is a partner transfer (only relevant in workspace mode)
    final isPartnerTransfer = _inWorkspace &&
        transaction.type == models.TransactionType.transfer &&
        transaction.sourceOwnerId != null &&
        transaction.targetOwnerId != null &&
        transaction.sourceOwnerId != transaction.targetOwnerId;

    // Background sync (fire-and-forget, non-blocking)
    // SOLO MODE: Syncs ALL transactions to /users/{userId}/transactions
    // WORKSPACE MODE: Syncs ONLY partner transfers to /workspaces/{workspaceId}/transfers
    _syncManager.pushTransaction(transaction, _workspaceId, _userId, isPartnerTransfer);
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

    // 1. Update Hive IMMEDIATELY (instant UI update)
    final now = DateTime.now();
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
      isSynced: false, // Mark as pending sync
      lastUpdated: now,
      createdAt: envelope.createdAt,
      targetStartDateType: envelope.targetStartDateType,
      customTargetStartDate: envelope.customTargetStartDate,
    );

    // 2. Create transaction in Hive
    final transaction = models.Transaction(
      id: _firestore.collection('_temp').doc().id,
      envelopeId: envelopeId,
      userId: _userId,
      type: models.TransactionType.deposit,
      amount: amount,
      date: date ?? now,
      description: description,
      isSynced: false,
      lastUpdated: now,
    );

    await _envelopeBox.put(envelopeId, updatedEnvelope);
    await _createTransaction(transaction);

    // 3. Background sync (fire-and-forget, non-blocking)
    _syncManager.pushEnvelope(updatedEnvelope, _workspaceId, _userId);
  }

  /// Withdraw
  Future<void> withdraw({
    required String envelopeId,
    required double amount,
    required String description,
    DateTime? date,
    bool isScheduledPayment = false,
  }) async {
    final envelope = _envelopeBox.get(envelopeId);
    if (envelope == null) {
      throw Exception('Envelope not found');
    }

    if (envelope.currentAmount < amount) {
      throw Exception(
        'Insufficient funds in ${envelope.name}. '
        'Available: £${envelope.currentAmount.toStringAsFixed(2)}, '
        'Required: £${amount.toStringAsFixed(2)}',
      );
    }

    // 1. Update Hive IMMEDIATELY (instant UI update)
    final now = DateTime.now();
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
      isSynced: false, // Mark as pending sync
      lastUpdated: now,
      createdAt: envelope.createdAt,
      targetStartDateType: envelope.targetStartDateType,
      customTargetStartDate: envelope.customTargetStartDate,
    );

    // 2. Create transaction in Hive
    final transaction = models.Transaction(
      id: _firestore.collection('_temp').doc().id,
      envelopeId: envelopeId,
      userId: _userId,
      type: isScheduledPayment
          ? models.TransactionType.scheduledPayment
          : models.TransactionType.withdrawal,
      amount: amount,
      date: date ?? now,
      description: description,
      isSynced: false,
      lastUpdated: now,
    );

    await _envelopeBox.put(envelopeId, updatedEnvelope);
    await _createTransaction(transaction);

    // 3. Background sync (fire-and-forget, non-blocking)
    _syncManager.pushEnvelope(updatedEnvelope, _workspaceId, _userId);
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
      throw Exception(
        'Insufficient funds in ${sourceEnv.name}. '
        'Available: £${sourceEnv.currentAmount.toStringAsFixed(2)}, '
        'Required: £${amount.toStringAsFixed(2)}',
      );
    }

    // 1. Update envelopes in Hive IMMEDIATELY (instant UI update)
    final now = DateTime.now();
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
      isSynced: false, // Mark as pending sync
      lastUpdated: now,
      createdAt: sourceEnv.createdAt,
      targetStartDateType: sourceEnv.targetStartDateType,
      customTargetStartDate: sourceEnv.customTargetStartDate,
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
      isSynced: false, // Mark as pending sync
      lastUpdated: now,
      createdAt: targetEnv.createdAt,
      targetStartDateType: targetEnv.targetStartDateType,
      customTargetStartDate: targetEnv.customTargetStartDate,
    );

    await _envelopeBox.put(fromEnvelopeId, updatedSource);
    await _envelopeBox.put(toEnvelopeId, updatedTarget);

    // 2. Create linked transactions in Hive
    final transferLinkId = _firestore.collection('_temp').doc().id;

    final outTransaction = models.Transaction(
      id: _firestore.collection('_temp').doc().id,
      envelopeId: fromEnvelopeId,
      userId: _userId,
      type: models.TransactionType.transfer,
      amount: amount,
      date: date ?? now,
      description: description,
      transferDirection: models.TransferDirection.out_,
      transferPeerEnvelopeId: toEnvelopeId,
      transferLinkId: transferLinkId,
      sourceOwnerId: sourceEnv.userId,
      targetOwnerId: targetEnv.userId,
      sourceEnvelopeName: sourceEnv.name,
      targetEnvelopeName: targetEnv.name,
      isSynced: false,
      lastUpdated: now,
    );

    final inTransaction = models.Transaction(
      id: _firestore.collection('_temp').doc().id,
      envelopeId: toEnvelopeId,
      userId: _userId,
      type: models.TransactionType.transfer,
      amount: amount,
      date: date ?? now,
      description: description,
      transferDirection: models.TransferDirection.in_,
      transferPeerEnvelopeId: fromEnvelopeId,
      transferLinkId: transferLinkId,
      sourceOwnerId: sourceEnv.userId,
      targetOwnerId: targetEnv.userId,
      sourceEnvelopeName: sourceEnv.name,
      targetEnvelopeName: targetEnv.name,
      isSynced: false,
      lastUpdated: now,
    );

    await _createTransaction(outTransaction);
    await _createTransaction(inTransaction);

    // 3. Background sync (fire-and-forget, non-blocking)
    _syncManager.pushEnvelope(updatedSource, _workspaceId, _userId);
    _syncManager.pushEnvelope(updatedTarget, _workspaceId, _userId);
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
          createdAt: envelope.createdAt,
          targetStartDateType: envelope.targetStartDateType,
          customTargetStartDate: envelope.customTargetStartDate,
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
          createdAt: envelope.createdAt,
          targetStartDateType: envelope.targetStartDateType,
          customTargetStartDate: envelope.customTargetStartDate,
        );
        await _envelopeBox.put(id, updated);
      }
    }
  }

  // ==================== WORKSPACE ====================

  Future<void> setWorkspace(String? newWorkspaceId) async {
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
    final now = DateTime.now();

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
          isSynced: false, // Mark as pending sync
          lastUpdated: now,
          createdAt: envelope.createdAt,
          targetStartDateType: envelope.targetStartDateType,
          customTargetStartDate: envelope.customTargetStartDate,
        );
        await _envelopeBox.put(envelopeId, updated);

        // Background sync (fire-and-forget, non-blocking)
        _syncManager.pushEnvelope(updated, _workspaceId, _userId);
      }
    }
  }

  Future<List<models.Transaction>> getAllTransactions() {
    return transactionsStream.first;
  }

  Future<List<models.Transaction>> getTransactions(String envelopeId) {
    return transactionsForEnvelope(envelopeId).first;
  }

  // ==================== ACCOUNT LINKING METHODS ====================

  /// Get envelopes linked to a specific account
  Stream<List<Envelope>> getEnvelopesLinkedToAccount(String accountId) {
    return envelopesStream().map((envelopes) =>
        envelopes.where((e) => e.linkedAccountId == accountId).toList());
  }

  /// Get all envelopes with auto-fill but NO account link (Budget Mode leftovers)
  Future<List<Envelope>> getUnlinkedAutoFillEnvelopes() async {
    final envelopes = await getAllEnvelopes();
    return envelopes
        .where((e) => e.autoFillEnabled && e.linkedAccountId == null)
        .toList();
  }

  /// Get all auto-fill envelopes (for Budget Mode)
  Future<List<Envelope>> getAutoFillEnvelopes() async {
    final envelopes = await getAllEnvelopes();
    return envelopes.where((e) => e.autoFillEnabled).toList();
  }

  /// Bulk link envelopes to an account
  Future<void> bulkLinkToAccount(List<String> envelopeIds, String accountId) async {
    await linkEnvelopesToAccount(envelopeIds, accountId);
  }

  /// Unlink all envelopes from an account (when account deleted)
  Future<void> unlinkFromAccount(String accountId) async {
    final envelopes = await getAllEnvelopes();
    final linkedEnvelopes =
        envelopes.where((e) => e.linkedAccountId == accountId);

    for (final envelope in linkedEnvelopes) {
      await updateEnvelope(
        envelopeId: envelope.id,
        linkedAccountId: null,
        updateLinkedAccountId: true,
        autoFillEnabled: false, // Disable auto-fill when unlinking
      );
    }
  }

  /// Add money to envelope (used by pay day processor)
  Future<void> addMoney(
    String envelopeId,
    double amount, {
    String? description,
  }) async {
    await deposit(
      envelopeId: envelopeId,
      amount: amount,
      description: description ?? 'Auto-fill',
    );
  }

  /// Validate envelope before saving
  /// Returns error message if invalid, null if valid
  Future<String?> validateEnvelope(Envelope envelope) async {
    // Check if we're in Account Mirror Mode
    final payDayService = PayDaySettingsService(_firestore, _userId);
    final settings = await payDayService.getSettings();
    final isAccountMirrorMode = settings?.defaultAccountId != null;

    // If auto-fill enabled in Account Mirror Mode, MUST have linked account
    if (envelope.autoFillEnabled &&
        isAccountMirrorMode &&
        envelope.linkedAccountId == null) {
      return 'Please link this envelope to an account for auto-fill';
    }

    return null; // Valid
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
      return 'Unknown User';
    }
  }
}
