// lib/services/scheduled_payment_processor.dart
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'envelope_repo.dart';
import 'scheduled_payment_repo.dart';
import 'notification_repo.dart';
import '../models/app_notification.dart';
import '../models/scheduled_payment.dart';
import '../models/envelope.dart';

class ScheduledPaymentProcessingResult {
  final int processedCount;
  final double totalAmount;
  final List<String> processedPaymentNames;
  final List<ScheduledPaymentError> errors;

  ScheduledPaymentProcessingResult({
    required this.processedCount,
    required this.totalAmount,
    required this.processedPaymentNames,
    required this.errors,
  });
}

class ScheduledPaymentError {
  final String paymentName;
  final String envelopeName;
  final double amount;
  final String reason;

  ScheduledPaymentError({
    required this.paymentName,
    required this.envelopeName,
    required this.amount,
    required this.reason,
  });
}

class ScheduledPaymentProcessor {
  Future<ScheduledPaymentProcessingResult> processAutomaticPayments({
    required String userId,
    required EnvelopeRepo envelopeRepo,
    required ScheduledPaymentRepo paymentRepo,
    required NotificationRepo notificationRepo,
  }) async {
    final currency = NumberFormat.currency(symbol: '£');

    int processedCount = 0;
    double totalAmount = 0.0;
    List<String> processedPaymentNames = [];
    List<ScheduledPaymentError> errors = [];

    try {
      // Get all automatic payments that are due
      final duePayments = await paymentRepo.getAutomaticPaymentsDueToday();

      if (duePayments.isEmpty) {
        debugPrint('No automatic payments due');
        return ScheduledPaymentProcessingResult(
          processedCount: 0,
          totalAmount: 0.0,
          processedPaymentNames: [],
          errors: [],
        );
      }

      debugPrint('Processing ${duePayments.length} automatic payments');

      // Get all envelopes once to avoid repeated queries
      final allEnvelopes = await envelopeRepo.envelopesStream().first;

      for (final payment in duePayments) {
        try {
          // Handle envelope-based payments
          if (payment.envelopeId != null) {
            // Try to find the envelope, skip if it doesn't exist (deleted)
            final envelope = allEnvelopes
                .cast<Envelope?>()
                .firstWhere(
                  (e) => e?.id == payment.envelopeId,
                  orElse: () => null,
                );

            // If envelope was deleted, skip this payment and log it
            if (envelope == null) {
              debugPrint('Skipped: ${payment.name} - envelope no longer exists (deleted)');
              errors.add(ScheduledPaymentError(
                paymentName: payment.name,
                envelopeName: 'Deleted Envelope',
                amount: payment.amount,
                reason: 'The linked envelope has been deleted',
              ));
              continue;
            }

            // Determine the amount to deduct based on payment type
            double amountToDeduct;
            String description;

            if (payment.paymentType == ScheduledPaymentType.envelopeBalance) {
              // Use the entire envelope balance
              amountToDeduct = envelope.currentAmount;
              description = 'Scheduled Payment (Envelope Balance): ${payment.name}';

              // Skip if envelope is empty
              if (amountToDeduct <= 0) {
                debugPrint('Skipped: ${payment.name} - envelope is empty');
                // Still mark as executed so it moves to next occurrence
                await paymentRepo.markPaymentExecuted(payment.id);
                continue;
              }
            } else {
              // Use the fixed amount
              amountToDeduct = payment.amount;
              description = 'Scheduled Payment: ${payment.name}';

              // Check if envelope has sufficient balance
              if (envelope.currentAmount < amountToDeduct) {
                final error = ScheduledPaymentError(
                  paymentName: payment.name,
                  envelopeName: envelope.name,
                  amount: amountToDeduct,
                  reason:
                      'Insufficient balance (${currency.format(envelope.currentAmount)} available)',
                );
                errors.add(error);

                // Create notification for failed payment
                await notificationRepo.createNotification(
                  type: NotificationType.scheduledPaymentFailed,
                  title: 'Payment Failed',
                  message:
                      '${payment.name} failed - insufficient balance in ${envelope.name}',
                  metadata: {
                    'paymentId': payment.id,
                    'paymentName': payment.name,
                    'envelopeId': envelope.id,
                    'envelopeName': envelope.name,
                    'amount': amountToDeduct,
                    'availableBalance': envelope.currentAmount,
                  },
                );

                debugPrint('Failed: ${payment.name} - insufficient balance');
                continue;
              }
            }

            // Process withdrawal (deduction)
            await envelopeRepo.withdraw(
              envelopeId: payment.envelopeId!,
              amount: amountToDeduct,
              description: description,
              date: DateTime.now(),
              isScheduledPayment: true,
            );

            // Mark as executed
            await paymentRepo.markPaymentExecuted(payment.id);

            processedCount++;
            totalAmount += amountToDeduct;
            processedPaymentNames.add(payment.name);

            debugPrint(
              'Processed: ${payment.name} - ${currency.format(amountToDeduct)}',
            );
          }
          // Handle group-based payments (future implementation)
          else if (payment.groupId != null) {
            debugPrint('Group-based scheduled payments not yet implemented');
            // TODO: Implement proportional withdrawal from group envelopes
          }
        } catch (e) {
          debugPrint('Error processing payment ${payment.name}: $e');

          final error = ScheduledPaymentError(
            paymentName: payment.name,
            envelopeName: 'Unknown',
            amount: payment.amount,
            reason: e.toString(),
          );
          errors.add(error);

          // Create notification for unexpected error
          await notificationRepo.createNotification(
            type: NotificationType.scheduledPaymentFailed,
            title: 'Payment Error',
            message: '${payment.name} failed - ${e.toString()}',
            metadata: {
              'paymentId': payment.id,
              'paymentName': payment.name,
              'amount': payment.amount,
              'error': e.toString(),
            },
          );
        }
      }

      // Create success notification if any payments were processed
      if (processedCount > 0) {
        await notificationRepo.createNotification(
          type: NotificationType.scheduledPaymentProcessed,
          title: 'Payments Processed',
          message:
              '$processedCount payment${processedCount > 1 ? 's' : ''} processed (${currency.format(totalAmount)})',
          metadata: {
            'count': processedCount,
            'totalAmount': totalAmount,
            'paymentNames': processedPaymentNames,
          },
        );
      }

      return ScheduledPaymentProcessingResult(
        processedCount: processedCount,
        totalAmount: totalAmount,
        processedPaymentNames: processedPaymentNames,
        errors: errors,
      );
    } catch (e) {
      debugPrint('Fatal error in processAutomaticPayments: $e');
      rethrow;
    }
  }
}
