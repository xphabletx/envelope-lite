// lib/services/scheduled_payment_repo.dart
import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import '../models/scheduled_payment.dart';
import 'hive_service.dart';

/// Scheduled Payment repository - PURE HIVE (No Firebase sync)
///
/// Scheduled payments are ALWAYS local-only, even in workspace mode.
/// They are never synced to Firebase or shared with workspace partners.
class ScheduledPaymentRepo {
  ScheduledPaymentRepo(this._userId, {String? workspaceId}) {
    _paymentBox = HiveService.getBox<ScheduledPayment>('scheduledPayments');
    _workspaceId = workspaceId;
  }

  final String _userId;
  late final Box<ScheduledPayment> _paymentBox;
  String? _workspaceId;

  // ignore: unused_element
  bool get _inWorkspace => _workspaceId != null && _workspaceId!.isNotEmpty;

  // ======================= GETTERS =======================

  /// Get all scheduled payments
  Future<List<ScheduledPayment>> getAllScheduledPayments() async {
    return _paymentBox.values
        .where((payment) => payment.userId == _userId)
        .toList();
  }

  /// Stream all scheduled payments
  Stream<List<ScheduledPayment>> get scheduledPaymentsStream {
    debugPrint('[ScheduledPaymentRepo] 📦 Streaming from Hive (local only)');

    final initialPayments = _paymentBox.values
        .where((payment) => payment.userId == _userId)
        .toList();
    initialPayments.sort((a, b) => a.startDate.compareTo(b.startDate));

    return Stream.value(initialPayments).asBroadcastStream().concatWith([
      _paymentBox.watch().map((_) {
        final payments = _paymentBox.values
            .where((payment) => payment.userId == _userId)
            .toList();
        payments.sort((a, b) => a.startDate.compareTo(b.startDate));
        return payments;
      })
    ]);
  }

  /// Get single scheduled payment
  Future<ScheduledPayment?> getScheduledPayment(String id) async {
    return _paymentBox.get(id);
  }

  // ======================= CREATE =======================

  /// Create scheduled payment
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

    final id = DateTime.now().millisecondsSinceEpoch.toString();

    final payment = ScheduledPayment(
      id: id,
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

    await _paymentBox.put(id, payment);
    debugPrint('[ScheduledPaymentRepo] ✅ Scheduled payment created in Hive: $name');

    return id;
  }

  // ======================= UPDATE =======================

  /// Update scheduled payment
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
    final payment = _paymentBox.get(id);
    if (payment == null) {
      throw Exception('Scheduled payment not found: $id');
    }

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

    await _paymentBox.put(id, updatedPayment);
    debugPrint('[ScheduledPaymentRepo] ✅ Scheduled payment updated in Hive: $id');
  }

  // ======================= DELETE =======================

  /// Delete scheduled payment
  Future<void> deleteScheduledPayment(String id) async {
    await _paymentBox.delete(id);
    debugPrint('[ScheduledPaymentRepo] ✅ Scheduled payment deleted from Hive: $id');
  }

  // ======================= MARK EXECUTED =======================

  /// Mark payment as executed (updates lastExecuted)
  Future<void> markPaymentExecuted(String id) async {
    final payment = _paymentBox.get(id);
    if (payment == null) {
      throw Exception('Scheduled payment not found: $id');
    }

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

  // ======================= QUERIES =======================

  /// Get all payments due today or earlier (for auto-execution)
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

  /// Get all automatic payments due today (for auto-execution)
  Future<List<ScheduledPayment>> getAutomaticPaymentsDueToday() async {
    final duePayments = await getDuePayments();
    return duePayments.where((p) => p.isAutomatic).toList();
  }

  /// Get payments for specific envelope
  Stream<List<ScheduledPayment>> getPaymentsForEnvelope(String envelopeId) {
    // Emit initial data immediately
    final initialPayments = _paymentBox.values
        .where((payment) => payment.userId == _userId && payment.envelopeId == envelopeId)
        .toList();

    return Stream.value(initialPayments).asBroadcastStream().concatWith([
      _paymentBox.watch().map((_) {
        return _paymentBox.values
            .where((payment) => payment.userId == _userId && payment.envelopeId == envelopeId)
            .toList();
      })
    ]);
  }

  /// Get payments for specific group
  Stream<List<ScheduledPayment>> getPaymentsForGroup(String groupId) {
    // Emit initial data immediately
    final initialPayments = _paymentBox.values
        .where((payment) => payment.userId == _userId && payment.groupId == groupId)
        .toList();

    return Stream.value(initialPayments).asBroadcastStream().concatWith([
      _paymentBox.watch().map((_) {
        return _paymentBox.values
            .where((payment) => payment.userId == _userId && payment.groupId == groupId)
            .toList();
      })
    ]);
  }

  /// Delete all payments for an envelope (when envelope is deleted)
  Future<void> deletePaymentsForEnvelope(String envelopeId) async {
    final paymentsToDelete = _paymentBox.values
        .where((payment) => payment.envelopeId == envelopeId)
        .toList();

    for (final payment in paymentsToDelete) {
      await _paymentBox.delete(payment.id);
    }
    debugPrint('[ScheduledPaymentRepo] ✅ Deleted ${paymentsToDelete.length} payments from Hive');
  }

  /// Delete all payments for a group (when group is deleted)
  Future<void> deletePaymentsForGroup(String groupId) async {
    final paymentsToDelete = _paymentBox.values
        .where((payment) => payment.groupId == groupId)
        .toList();

    for (final payment in paymentsToDelete) {
      await _paymentBox.delete(payment.id);
    }
    debugPrint('[ScheduledPaymentRepo] ✅ Deleted ${paymentsToDelete.length} payments from Hive');
  }

  /// Execute a scheduled payment (create transaction in envelope/group)
  Future<void> executePayment(String paymentId) async {
    await markPaymentExecuted(paymentId);
  }

  /// Get upcoming payments within a date range
  Future<List<ScheduledPayment>> getPaymentsInRange(
    DateTime start,
    DateTime end,
  ) async {
    final allPayments = _paymentBox.values
        .where((payment) => payment.userId == _userId)
        .toList();

    return allPayments.where((payment) {
      final dueDate = payment.nextDueDate;
      return !dueDate.isBefore(start) && !dueDate.isAfter(end);
    }).toList();
  }
}
