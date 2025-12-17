// lib/services/auto_payment_service.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class AutoPaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Checks for due payments and processes them.
  /// Returns the number of transactions created.
  Future<int> processDuePayments(String userId) async {
    final now = DateTime.now();
    int processedCount = 0;

    try {
      // Query scheduled items where nextOccurrence is in the past
      final querySnapshot = await _firestore
          .collection('scheduled_payments')
          .where('userId', isEqualTo: userId)
          .where('nextOccurrence', isLessThanOrEqualTo: Timestamp.fromDate(now))
          .get();

      if (querySnapshot.docs.isEmpty) return 0;

      final batch = _firestore.batch();

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final envelopeId = data['envelopeId'];

        // Safety check: ensure envelope exists (in case it was deleted manually)
        final envelopeRef = _firestore.doc(
          'users/$userId/solo/data/envelopes/$envelopeId',
        );
        final envelopeSnap = await envelopeRef.get();

        if (!envelopeSnap.exists) {
          // If envelope is gone, delete the scheduled payment to stop errors
          batch.delete(doc.reference);
          continue;
        }

        final amount = (data['amount'] ?? 0.0).toDouble();
        final type = data['type']; // 'deposit' or 'withdrawal'
        final description = data['description'] ?? 'Scheduled Payment';
        final frequency = data['frequency'];

        DateTime nextDate = (data['nextOccurrence'] as Timestamp).toDate();

        // Catch-up Loop: Process all missed occurrences up to now
        while (nextDate.isBefore(now)) {
          processedCount++;

          // 1. Create Transaction Record
          final txId = const Uuid().v4();
          final txRef = _firestore.doc(
            'users/$userId/solo/data/transactions/$txId',
          );

          batch.set(txRef, {
            'id': txId,
            'envelopeId': envelopeId,
            'type': type,
            'amount': amount,
            'date': Timestamp.fromDate(
              nextDate,
            ), // Backdated to when it SHOULD have happened
            'description': '$description (Auto)',
            'userId': userId,
            'createdAt': FieldValue.serverTimestamp(),
          });

          // 2. Update Envelope Balance
          // Note: using increment is safer for concurrent updates
          final balanceChange = type == 'deposit' ? amount : -amount;
          batch.update(envelopeRef, {
            'currentAmount': FieldValue.increment(balanceChange),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // 3. Calculate next occurrence
          nextDate = _calculateNextDate(nextDate, frequency);
        }

        // 4. Update the Schedule Document
        batch.update(doc.reference, {
          'lastOccurrence': FieldValue.serverTimestamp(),
          'nextOccurrence': Timestamp.fromDate(nextDate),
        });
      }

      await batch.commit();
      return processedCount;
    } catch (e) {
      debugPrint("Error processing auto-payments: $e");
      return 0;
    }
  }

  DateTime _calculateNextDate(DateTime current, String frequency) {
    switch (frequency) {
      case 'daily':
        return current.add(const Duration(days: 1));
      case 'weekly':
        return current.add(const Duration(days: 7));
      case 'biweekly':
        return current.add(const Duration(days: 14));
      case 'monthly':
        // Handle month overflow (e.g. Jan 31 -> Feb 28)
        final targetMonth = current.month + 1;
        final targetYear = current.year + (targetMonth > 12 ? 1 : 0);
        final normalizedMonth = targetMonth > 12 ? 1 : targetMonth;

        final lastDayOfTargetMonth = DateTime(
          targetYear,
          normalizedMonth + 1,
          0,
        ).day;
        final targetDay = current.day > lastDayOfTargetMonth
            ? lastDayOfTargetMonth
            : current.day;

        return DateTime(targetYear, normalizedMonth, targetDay);

      case 'yearly':
        return DateTime(current.year + 1, current.month, current.day);
      default:
        return current.add(const Duration(days: 30));
    }
  }
}
