import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/scheduled_payment.dart';

class ScheduledPaymentRepo {
  ScheduledPaymentRepo(this._db, this._userId);

  final FirebaseFirestore _db;
  final String _userId;

  // Collection reference for user's scheduled payments
  CollectionReference<Map<String, dynamic>> _collection() {
    return _db
        .collection('users')
        .doc(_userId)
        .collection('solo')
        .doc('data')
        .collection('scheduledPayments');
  }

  // Stream all scheduled payments for current user
  Stream<List<ScheduledPayment>> get scheduledPaymentsStream {
    return _collection()
        .orderBy('startDate', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ScheduledPayment.fromFirestore(doc))
              .toList(),
        );
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
  }) async {
    // Validate that either envelope or group is set
    if (envelopeId == null && groupId == null) {
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
    );

    await doc.set(payment.toMap());
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
  }) async {
    final updateData = <String, dynamic>{};

    if (name != null) updateData['name'] = name;
    if (description != null) updateData['description'] = description;
    if (amount != null) updateData['amount'] = amount;
    if (startDate != null) {
      updateData['startDate'] = Timestamp.fromDate(startDate);
    }
    if (frequencyValue != null) updateData['frequencyValue'] = frequencyValue;
    if (frequencyUnit != null) updateData['frequencyUnit'] = frequencyUnit.name;
    if (colorName != null) updateData['colorName'] = colorName;
    if (colorValue != null) updateData['colorValue'] = colorValue;
    if (isAutomatic != null) updateData['isAutomatic'] = isAutomatic;

    if (updateData.isEmpty) return;

    await _collection().doc(id).update(updateData);
  }

  // Delete scheduled payment
  Future<void> deleteScheduledPayment(String id) async {
    await _collection().doc(id).delete();
  }

  // Mark payment as executed (updates lastExecuted)
  Future<void> markPaymentExecuted(String id) async {
    await _collection().doc(id).update({
      'lastExecuted': Timestamp.fromDate(DateTime.now()),
    });
  }

  // Get all payments due today or earlier (for auto-execution)
  Future<List<ScheduledPayment>> getDuePayments() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final snapshot = await _collection().get();
    final allPayments = snapshot.docs
        .map((doc) => ScheduledPayment.fromFirestore(doc))
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
    final snapshot = await _collection()
        .where('envelopeId', isEqualTo: envelopeId)
        .get();

    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // Delete all payments for a group (when group is deleted)
  Future<void> deletePaymentsForGroup(String groupId) async {
    final snapshot = await _collection()
        .where('groupId', isEqualTo: groupId)
        .get();

    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
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
