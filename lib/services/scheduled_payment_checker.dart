import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'envelope_repo.dart';
import 'scheduled_payment_repo.dart';
import 'notification_repo.dart';
import '../models/app_notification.dart';
import '../models/scheduled_payment.dart';
import '../models/envelope.dart';

/// Service that checks for upcoming scheduled payments and warns users
/// about insufficient funds BEFORE the payment is due.
///
/// This proactive system runs daily to alert users 24 hours before
/// a payment fails, giving them time to add funds to envelopes.
class ScheduledPaymentChecker {
  /// Checks for scheduled payments due tomorrow and creates warnings
  /// for any payments that will fail due to insufficient funds.
  ///
  /// Returns the number of warnings created.
  Future<int> checkUpcomingPayments({
    required String userId,
    required EnvelopeRepo envelopeRepo,
    required ScheduledPaymentRepo paymentRepo,
    required NotificationRepo notificationRepo,
  }) async {
    final currency = NumberFormat.currency(symbol: '£');
    int warningsCreated = 0;

    try {
      // Get all automatic payments due tomorrow
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final upcomingPayments = await paymentRepo.getPaymentsDueOnDate(tomorrow);

      if (upcomingPayments.isEmpty) {
        debugPrint('[ScheduledPaymentChecker] No payments due tomorrow');
        return 0;
      }

      debugPrint('[ScheduledPaymentChecker] Checking ${upcomingPayments.length} payments due tomorrow');

      // Get all envelopes once to avoid repeated queries
      final allEnvelopes = await envelopeRepo.envelopesStream().first;

      for (final payment in upcomingPayments) {
        try {
          // Only check envelope-based payments (skip group-based for now)
          if (payment.envelopeId == null) continue;

          // Find the envelope
          final envelope = allEnvelopes
              .cast<Envelope?>()
              .firstWhere(
                (e) => e?.id == payment.envelopeId,
                orElse: () => null,
              );

          // If envelope was deleted, create a warning
          if (envelope == null) {
            await notificationRepo.createNotification(
              type: NotificationType.scheduledPaymentFailed,
              title: 'Payment Warning',
              message: 'Tomorrow: ${payment.name} cannot be processed - envelope was deleted',
              metadata: {
                'paymentId': payment.id,
                'paymentName': payment.name,
                'reason': 'envelope_deleted',
                'dueDate': tomorrow.toIso8601String(),
              },
            );
            warningsCreated++;
            debugPrint('[ScheduledPaymentChecker] ⚠️ Warning: ${payment.name} - envelope deleted');
            continue;
          }

          // Determine the amount that will be deducted
          double amountToDeduct;

          if (payment.paymentType == ScheduledPaymentType.envelopeBalance) {
            // For envelope balance payments, check if envelope has any balance
            amountToDeduct = envelope.currentAmount;

            // Skip if envelope will have balance to pay
            if (amountToDeduct > 0) {
              debugPrint('[ScheduledPaymentChecker] ✅ ${payment.name} - envelope balance OK');
              continue;
            }

            // Warn about empty envelope
            await notificationRepo.createNotification(
              type: NotificationType.scheduledPaymentFailed,
              title: 'Low Balance Warning',
              message: 'Tomorrow: ${payment.name} will be skipped - ${envelope.name} is empty',
              metadata: {
                'paymentId': payment.id,
                'paymentName': payment.name,
                'envelopeId': envelope.id,
                'envelopeName': envelope.name,
                'currentBalance': envelope.currentAmount,
                'paymentType': 'envelope_balance',
                'dueDate': tomorrow.toIso8601String(),
              },
            );
            warningsCreated++;
            debugPrint('[ScheduledPaymentChecker] ⚠️ Warning: ${payment.name} - envelope empty');

          } else {
            // Fixed amount payment
            amountToDeduct = payment.amount;

            // Check if envelope has sufficient balance
            if (envelope.currentAmount >= amountToDeduct) {
              debugPrint('[ScheduledPaymentChecker] ✅ ${payment.name} - sufficient funds');
              continue;
            }

            // Create warning notification for insufficient funds
            final shortfall = amountToDeduct - envelope.currentAmount;

            await notificationRepo.createNotification(
              type: NotificationType.scheduledPaymentFailed,
              title: 'Insufficient Funds Warning',
              message: 'Tomorrow: ${payment.name} will fail - ${envelope.name} needs ${currency.format(shortfall)} more',
              metadata: {
                'paymentId': payment.id,
                'paymentName': payment.name,
                'envelopeId': envelope.id,
                'envelopeName': envelope.name,
                'requiredAmount': amountToDeduct,
                'currentBalance': envelope.currentAmount,
                'shortfall': shortfall,
                'dueDate': tomorrow.toIso8601String(),
              },
            );
            warningsCreated++;

            debugPrint(
              '[ScheduledPaymentChecker] ⚠️ Warning: ${payment.name} - '
              'needs ${currency.format(amountToDeduct)}, '
              'has ${currency.format(envelope.currentAmount)}',
            );
          }
        } catch (e) {
          debugPrint('[ScheduledPaymentChecker] Error checking payment ${payment.name}: $e');
          // Continue checking other payments even if one fails
        }
      }

      if (warningsCreated > 0) {
        debugPrint('[ScheduledPaymentChecker] Created $warningsCreated warning(s)');
      } else {
        debugPrint('[ScheduledPaymentChecker] All payments have sufficient funds');
      }

      return warningsCreated;
    } catch (e) {
      debugPrint('[ScheduledPaymentChecker] Fatal error in checkUpcomingPayments: $e');
      rethrow;
    }
  }

  /// Checks for low balance warnings for recurring payments in the next 7 days.
  ///
  /// This is a more proactive check that looks ahead at the entire week
  /// and warns about envelopes that might run low based on recurring payments.
  Future<int> checkWeeklyProjections({
    required String userId,
    required EnvelopeRepo envelopeRepo,
    required ScheduledPaymentRepo paymentRepo,
    required NotificationRepo notificationRepo,
  }) async {
    final currency = NumberFormat.currency(symbol: '£');
    int warningsCreated = 0;

    try {
      final today = DateTime.now();
      final nextWeek = today.add(const Duration(days: 7));

      // Get all automatic payments in the next 7 days
      final upcomingPayments = await paymentRepo.getPaymentsBetweenDates(
        today,
        nextWeek,
      );

      if (upcomingPayments.isEmpty) {
        return 0;
      }

      // Get all envelopes
      final allEnvelopes = await envelopeRepo.envelopesStream().first;

      // Group payments by envelope to calculate total upcoming deductions
      final Map<String, List<ScheduledPayment>> paymentsByEnvelope = {};

      for (final payment in upcomingPayments) {
        if (payment.envelopeId != null) {
          paymentsByEnvelope.putIfAbsent(payment.envelopeId!, () => []);
          paymentsByEnvelope[payment.envelopeId!]!.add(payment);
        }
      }

      // Check each envelope's projected balance
      for (final entry in paymentsByEnvelope.entries) {
        final envelopeId = entry.key;
        final payments = entry.value;

        final envelope = allEnvelopes
            .cast<Envelope?>()
            .firstWhere(
              (e) => e?.id == envelopeId,
              orElse: () => null,
            );

        if (envelope == null) continue;

        // Calculate total upcoming payments for this envelope
        double totalUpcoming = 0;
        for (final payment in payments) {
          if (payment.paymentType == ScheduledPaymentType.fixedAmount) {
            totalUpcoming += payment.amount;
          }
          // Skip envelope balance type as they adjust to available balance
        }

        // Check if envelope will be depleted
        if (totalUpcoming > 0 && envelope.currentAmount < totalUpcoming) {
          final shortfall = totalUpcoming - envelope.currentAmount;

          await notificationRepo.createNotification(
            type: NotificationType.scheduledPaymentFailed,
            title: 'Weekly Budget Alert',
            message: '${envelope.name} has ${payments.length} payment(s) this week but is short ${currency.format(shortfall)}',
            metadata: {
              'envelopeId': envelope.id,
              'envelopeName': envelope.name,
              'totalUpcoming': totalUpcoming,
              'currentBalance': envelope.currentAmount,
              'shortfall': shortfall,
              'paymentCount': payments.length,
              'weekStart': today.toIso8601String(),
              'weekEnd': nextWeek.toIso8601String(),
            },
          );
          warningsCreated++;

          debugPrint(
            '[ScheduledPaymentChecker] 📊 Weekly alert: ${envelope.name} - '
            '${payments.length} payments totaling ${currency.format(totalUpcoming)}, '
            'current balance ${currency.format(envelope.currentAmount)}',
          );
        }
      }

      return warningsCreated;
    } catch (e) {
      debugPrint('[ScheduledPaymentChecker] Error in checkWeeklyProjections: $e');
      rethrow;
    }
  }
}
