import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import '../models/scheduled_payment.dart';
import 'hive_service.dart';

class ScheduledPaymentRepo {
  ScheduledPaymentRepo(this._db, this._userId, {String? workspaceId}) {
    // Initialize Hive box
    _paymentBox = HiveService.getBox<ScheduledPayment>('scheduledPayments');
    _workspaceId = workspaceId;
  }

  final FirebaseFirestore _db;
  final String _userId;
  late final Box<ScheduledPayment> _paymentBox;
  String? _workspaceId;

  bool get _inWorkspace => _workspaceId != null && _workspaceId!.isNotEmpty;

  // Collection reference for user's scheduled payments
  CollectionReference<Map<String, dynamic>> _collection() {
    return _db
        .collection('users')
        .doc(_userId)
        .collection('solo')
        .doc('data')
        .collection('scheduledPayments');
  }

  // Get all scheduled payments
  Future<List<ScheduledPayment>> getAllScheduledPayments() async {
    final snapshot = await _collection().get();
    return snapshot.docs
        .map((doc) => ScheduledPayment.fromFirestore(doc))
        .toList();
  }

  // Stream all scheduled payments for current user
  Stream<List<ScheduledPayment>> get scheduledPaymentsStream {
    // Always use Hive for scheduled payments (they're user-specific, not workspace-shared)
    debugPrint('[ScheduledPaymentRepo] 📦 Setting up Hive stream');

    // Emit initial state immediately
    final initialPayments = _paymentBox.values
        .where((payment) => payment.userId == _userId)
        .toList();
    initialPayments.sort((a, b) => a.startDate.compareTo(b.startDate));
    debugPrint('[ScheduledPaymentRepo] ✅ Initial state: ${initialPayments.length} payments from Hive');

    // Then listen for changes
    return Stream.value(initialPayments).asBroadcastStream().concatWith([
      _paymentBox.watch().map((_) {
        final payments = _paymentBox.values
            .where((payment) => payment.userId == _userId)
            .toList();
        payments.sort((a, b) => a.startDate.compareTo(b.startDate));
        debugPrint('[ScheduledPaymentRepo] ✅ Emitting ${payments.length} payments from Hive');
        return payments;
      })
    ]);
  }

  // Get single scheduled payment
  Future<ScheduledPayment?> getScheduledPayment(String id) async {
    final doc = await _collection().doc(id).get();
    if (!doc.exists) return null;
    return ScheduledPayment.fromFirestore(doc);
  }

  // Create new scheduled payment
  Future<String> createScheduledPayment({
    String? envelopeId,
    String? groupId,
    required String name,
    String? description,
    required double amount,
    required DateTime startDate,
    required int frequencyValue,
    required PaymentFrequencyUnit frequencyUnit,
    required String colorName,
    required int colorValue,
    bool isAutomatic = false,
    ScheduledPaymentType paymentType = ScheduledPaymentType.fixedAmount,
  }) async {
    // Special case: Allow "Pay Day" (income) entries without envelope/group
    final isPayDayEntry = name.contains('Pay Day') || name.contains('💰');

    // Validate that either envelope or group is set (unless it's a pay day entry)
    if (!isPayDayEntry && envelopeId == null && groupId == null) {
      throw ArgumentError('Must provide either envelopeId or groupId');
    }

    if (envelopeId != null && groupId != null) {
      throw ArgumentError('Cannot provide both envelopeId and groupId');
    }

    final doc = _collection().doc();

    final payment = ScheduledPayment(
      id: doc.id,
      userId: _userId,
      envelopeId: envelopeId,
      groupId: groupId,
      name: name,
      description: description,
      amount: amount,
      startDate: startDate,
      frequencyValue: frequencyValue,
      frequencyUnit: frequencyUnit,
      colorName: colorName,
      colorValue: colorValue,
      isAutomatic: isAutomatic,
      createdAt: DateTime.now(),
      paymentType: paymentType,
    );

    // ALWAYS write to Hive (scheduled payments are user-specific)
    await _paymentBox.put(doc.id, payment);
    debugPrint('[ScheduledPaymentRepo] ✅ Scheduled payment saved to Hive: ${doc.id}');

    // Note: Scheduled payments are typically user-specific and not shared in workspaces
    // So we skip Firebase sync for now

    return doc.id;
  }

  // Update scheduled payment
  Future<void> updateScheduledPayment({
    required String id,
    String? name,
    String? description,
    double? amount,
    DateTime? startDate,
    int? frequencyValue,
    PaymentFrequencyUnit? frequencyUnit,
    String? colorName,
    int? colorValue,
    bool? isAutomatic,
    ScheduledPaymentType? paymentType,
  }) async {
    // Get current payment from Hive
    final payment = _paymentBox.get(id);
    if (payment == null) {
      throw Exception('Scheduled payment not found: $id');
    }

    // Create updated payment
    final updatedPayment = ScheduledPayment(
      id: payment.id,
      userId: payment.userId,
      envelopeId: payment.envelopeId,
      groupId: payment.groupId,
      name: name ?? payment.name,
      description: description ?? payment.description,
      amount: amount ?? payment.amount,
      startDate: startDate ?? payment.startDate,
      frequencyValue: frequencyValue ?? payment.frequencyValue,
      frequencyUnit: frequencyUnit ?? payment.frequencyUnit,
      colorName: colorName ?? payment.colorName,
      colorValue: colorValue ?? payment.colorValue,
      isAutomatic: isAutomatic ?? payment.isAutomatic,
      createdAt: payment.createdAt,
      lastExecuted: payment.lastExecuted,
      paymentType: paymentType ?? payment.paymentType,
    );

    // ALWAYS write to Hive
    await _paymentBox.put(id, updatedPayment);
    debugPrint('[ScheduledPaymentRepo] ✅ Scheduled payment updated in Hive: $id');
  }

  // Delete scheduled payment
  Future<void> deleteScheduledPayment(String id) async {
    await _paymentBox.delete(id);
    debugPrint('[ScheduledPaymentRepo] ✅ Scheduled payment deleted from Hive: $id');
  }

  // Mark payment as executed (updates lastExecuted)
  Future<void> markPaymentExecuted(String id) async {
    // Get current payment from Hive
    final payment = _paymentBox.get(id);
    if (payment == null) {
      throw Exception('Scheduled payment not found: $id');
    }

    // Create updated payment with new lastExecuted
    final updatedPayment = ScheduledPayment(
      id: payment.id,
      userId: payment.userId,
      envelopeId: payment.envelopeId,
      groupId: payment.groupId,
      name: payment.name,
      description: payment.description,
      amount: payment.amount,
      startDate: payment.startDate,
      frequencyValue: payment.frequencyValue,
      frequencyUnit: payment.frequencyUnit,
      colorName: payment.colorName,
      colorValue: payment.colorValue,
      isAutomatic: payment.isAutomatic,
      createdAt: payment.createdAt,
      lastExecuted: DateTime.now(),
    );

    await _paymentBox.put(id, updatedPayment);
    debugPrint('[ScheduledPaymentRepo] ✅ Scheduled payment marked as executed: $id');
  }

  // Get all payments due today or earlier (for auto-execution)
  Future<List<ScheduledPayment>> getDuePayments() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final allPayments = _paymentBox.values
        .where((payment) => payment.userId == _userId)
        .toList();

    // Filter for payments due today or earlier
    return allPayments.where((payment) {
      final dueDate = payment.nextDueDate;
      return !dueDate.isAfter(today);
    }).toList();
  }

  // Get all automatic payments due today (for auto-execution)
  Future<List<ScheduledPayment>> getAutomaticPaymentsDueToday() async {
    final duePayments = await getDuePayments();
    return duePayments.where((p) => p.isAutomatic).toList();
  }

  // Get payments for specific envelope
  Stream<List<ScheduledPayment>> getPaymentsForEnvelope(String envelopeId) {
    return _collection()
        .where('envelopeId', isEqualTo: envelopeId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ScheduledPayment.fromFirestore(doc))
              .toList(),
        );
  }

  // Get payments for specific group
  Stream<List<ScheduledPayment>> getPaymentsForGroup(String groupId) {
    return _collection()
        .where('groupId', isEqualTo: groupId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ScheduledPayment.fromFirestore(doc))
              .toList(),
        );
  }

  // Delete all payments for an envelope (when envelope is deleted)
  Future<void> deletePaymentsForEnvelope(String envelopeId) async {
    // Delete from Hive first
    final paymentsToDelete = _paymentBox.values
        .where((payment) => payment.envelopeId == envelopeId)
        .toList();

    for (final payment in paymentsToDelete) {
      await _paymentBox.delete(payment.id);
    }
    debugPrint('[ScheduledPaymentRepo] ✅ Deleted ${paymentsToDelete.length} payments from Hive for envelope');

    // ONLY delete from Firebase if in workspace mode
    if (_inWorkspace) {
      final snapshot = await _collection()
          .where('envelopeId', isEqualTo: envelopeId)
          .get();

      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      debugPrint('[ScheduledPaymentRepo] ✅ Deleted payments from Firebase workspace');
    } else {
      debugPrint('[ScheduledPaymentRepo] ⏭️ Skipping Firebase delete (solo mode)');
    }
  }

  // Delete all payments for a group (when group is deleted)
  Future<void> deletePaymentsForGroup(String groupId) async {
    // Delete from Hive first
    final paymentsToDelete = _paymentBox.values
        .where((payment) => payment.groupId == groupId)
        .toList();

    for (final payment in paymentsToDelete) {
      await _paymentBox.delete(payment.id);
    }
    debugPrint('[ScheduledPaymentRepo] ✅ Deleted ${paymentsToDelete.length} payments from Hive for group');

    // ONLY delete from Firebase if in workspace mode
    if (_inWorkspace) {
      final snapshot = await _collection()
          .where('groupId', isEqualTo: groupId)
          .get();

      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      debugPrint('[ScheduledPaymentRepo] ✅ Deleted payments from Firebase workspace');
    } else {
      debugPrint('[ScheduledPaymentRepo] ⏭️ Skipping Firebase delete (solo mode)');
    }
  }

  // Execute a scheduled payment (create transaction in envelope/group)
  // This should be called by EnvelopeRepo to maintain transaction logic
  // We just mark it as executed here
  Future<void> executePayment(String paymentId) async {
    await markPaymentExecuted(paymentId);
  }

  // Get upcoming payments within a date range
  Future<List<ScheduledPayment>> getPaymentsInRange(
    DateTime start,
    DateTime end,
  ) async {
    final snapshot = await _collection().get();
    final allPayments = snapshot.docs
        .map((doc) => ScheduledPayment.fromFirestore(doc))
        .toList();

    return allPayments.where((payment) {
      final dueDate = payment.nextDueDate;
      return !dueDate.isBefore(start) && !dueDate.isAfter(end);
    }).toList();
  }
}
