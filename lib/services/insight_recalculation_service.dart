// lib/services/insight_recalculation_service.dart
// Service for recalculating Insight cash flow after Autopilot payments execute
// This enables dynamic "catch-up" amounts that adjust automatically

import 'package:flutter/foundation.dart';
import 'envelope_repo.dart';
import 'pay_day_settings_service.dart';
import 'scheduled_payment_repo.dart';
import 'notification_repo.dart';
import '../models/pay_day_settings.dart';
import '../models/scheduled_payment.dart';
import '../models/app_notification.dart';
import '../models/envelope.dart';

class InsightRecalculationService {
  /// Recalculates Insight cash flow for an envelope after Autopilot execution.
  ///
  /// This handles the dynamic "catch-up" scenario where:
  /// - Initial setup might need $15 NOW (bill due before payday)
  /// - After first bill, ongoing amount adjusts to $12.50/paycheck
  ///
  /// Returns true if recalculation was performed and cash flow updated.
  Future<bool> recalculateAfterAutopilot({
    required String envelopeId,
    required String userId,
    required EnvelopeRepo envelopeRepo,
    required ScheduledPaymentRepo paymentRepo,
    required NotificationRepo notificationRepo,
  }) async {
    try {
      debugPrint('[InsightRecalc] 🔄 Starting recalculation for envelope $envelopeId');

      // 1. Get the envelope with current balance (after autopilot deduction)
      final envelope = envelopeRepo.getEnvelopeSync(envelopeId);
      if (envelope == null) {
        debugPrint('[InsightRecalc] ⚠️ Envelope not found');
        return false;
      }

      // 2. Check if envelope has cash flow enabled
      if (!envelope.cashFlowEnabled) {
        debugPrint('[InsightRecalc] ⚠️ Cash flow not enabled, skipping');
        return false;
      }

      // 3. Get Pay Day settings
      final payDayService = PayDaySettingsService(null, userId);
      final payDaySettings = await payDayService.getPayDaySettings();

      if (payDaySettings == null) {
        debugPrint('[InsightRecalc] ⚠️ No Pay Day settings found');
        return false;
      }

      // 4. Get scheduled payments for this envelope
      final scheduledPayments = await paymentRepo.getPaymentsForEnvelope(envelopeId).first;
      final autopilotPayments = scheduledPayments
          .where((p) => p.isAutomatic && p.paymentType == ScheduledPaymentType.fixedAmount)
          .toList();

      if (autopilotPayments.isEmpty) {
        debugPrint('[InsightRecalc] ⚠️ No autopilot payments found');
        return false;
      }

      // 5. Get the next autopilot payment
      final nextPayment = _getNextScheduledPayment(autopilotPayments);
      if (nextPayment == null) {
        debugPrint('[InsightRecalc] ⚠️ No upcoming autopilot payment');
        return false;
      }

      // Convert frequency to string format
      final billFrequency = _convertFrequencyToString(
        nextPayment.frequencyValue,
        nextPayment.frequencyUnit,
      );

      debugPrint('[InsightRecalc] 📊 Recalculating for:');
      debugPrint('[InsightRecalc]   Current balance: \$${envelope.currentAmount}');
      debugPrint('[InsightRecalc]   Bill amount: \$${nextPayment.amount}');
      debugPrint('[InsightRecalc]   Next bill date: ${nextPayment.nextDueDate}');
      debugPrint('[InsightRecalc]   Bill frequency: $billFrequency');
      debugPrint('[InsightRecalc]   Pay frequency: ${payDaySettings.payFrequency}');

      // 6. Calculate new cash flow amount
      final calculation = _calculateCashFlow(
        startingAmount: envelope.currentAmount,
        billAmount: nextPayment.amount,
        billFrequency: billFrequency,
        nextBillDate: nextPayment.nextDueDate,
        payDaySettings: payDaySettings,
      );

      if (calculation == null) {
        debugPrint('[InsightRecalc] ⚠️ Calculation failed');
        return false;
      }

      final oldCashFlow = envelope.cashFlowAmount ?? 0.0;
      final newCashFlow = calculation['recommendedCashFlow'] as double;

      // 7. Check if we've reached steady state
      final isInSteadyState = calculation['isInSteadyState'] as bool;
      final payPeriodsPerCycle = calculation['payPeriodsPerCycle'] as int;

      debugPrint('[InsightRecalc] 💰 Results:');
      debugPrint('[InsightRecalc]   Old cash flow: \$$oldCashFlow');
      debugPrint('[InsightRecalc]   New cash flow: \$$newCashFlow');
      debugPrint('[InsightRecalc]   Steady state: $isInSteadyState');
      debugPrint('[InsightRecalc]   Pay periods per cycle: $payPeriodsPerCycle');

      // 8. Only notify if amount changed significantly (more than $0.01)
      if ((newCashFlow - oldCashFlow).abs() < 0.01) {
        debugPrint('[InsightRecalc] ✅ No significant change, skipping notification');
        return false;
      }

      // 9. DO NOT auto-update - just create notification with suggestion
      // User will approve the change via notification action
      debugPrint('[InsightRecalc] 💡 Calculated new cash flow: \$$oldCashFlow → \$$newCashFlow (SUGGESTION ONLY)');

      // 10. Create notification with suggested change
      final periodsText = payPeriodsPerCycle == 1 ? 'paycheck' : '$payPeriodsPerCycle paychecks';
      final billAmountFormatted = nextPayment.amount.toStringAsFixed(2);
      final mathExplanation = '\$$billAmountFormatted ÷ $payPeriodsPerCycle = \$${newCashFlow.toStringAsFixed(2)}/paycheck';

      await notificationRepo.createNotification(
        type: NotificationType.scheduledPaymentProcessed, // Reuse existing type
        title: '💡 Autopilot Update: ${envelope.name}',
        message: isInSteadyState
            ? '✅ Bill paid: \$${billAmountFormatted}\n\n'
              '📊 Suggested Cash Flow: \$${newCashFlow.toStringAsFixed(2)}/paycheck\n'
              'Why? You have $periodsText between bills.\n'
              '$mathExplanation\n\n'
              '(Steady state reached)'
            : '✅ Bill paid: \$${billAmountFormatted}\n\n'
              '📊 Suggested Cash Flow: \$${newCashFlow.toStringAsFixed(2)}/paycheck\n'
              'Why? You have $periodsText between bills.\n'
              '$mathExplanation',
        metadata: {
          'envelopeId': envelope.id,
          'envelopeName': envelope.name,
          'oldCashFlow': oldCashFlow,
          'suggestedCashFlow': newCashFlow,
          'billAmount': nextPayment.amount,
          'periodsPerCycle': payPeriodsPerCycle,
          'isInSteadyState': isInSteadyState,
          'reason': 'autopilot_recalculation_suggestion',
          'requiresUserApproval': true, // Flag for Phase 2
        },
      );

      return true;
    } catch (e) {
      debugPrint('[InsightRecalc] ❌ Error during recalculation: $e');
      return false;
    }
  }

  /// Get the next scheduled payment occurrence
  ScheduledPayment? _getNextScheduledPayment(
    List<ScheduledPayment> payments,
  ) {
    if (payments.isEmpty) return null;

    // Sort by next due date
    final sorted = List<ScheduledPayment>.from(payments)
      ..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));

    return sorted.first;
  }

  /// Convert ScheduledPayment frequency to string format used by Insight
  String _convertFrequencyToString(int value, PaymentFrequencyUnit unit) {
    // Handle common cases
    if (value == 1) {
      switch (unit) {
        case PaymentFrequencyUnit.weeks:
          return 'weekly';
        case PaymentFrequencyUnit.months:
          return 'monthly';
        case PaymentFrequencyUnit.years:
          return 'yearly';
        case PaymentFrequencyUnit.days:
          return 'weekly'; // Default to weekly for 1 day
      }
    }

    if (value == 2 && unit == PaymentFrequencyUnit.weeks) {
      return 'biweekly';
    }

    if (value == 4 && unit == PaymentFrequencyUnit.weeks) {
      return 'fourweekly';
    }

    // Default fallback
    return 'monthly';
  }

  /// Calculate cash flow based on current state
  Map<String, dynamic>? _calculateCashFlow({
    required double startingAmount,
    required double billAmount,
    required String billFrequency,
    required DateTime nextBillDate,
    required PayDaySettings payDaySettings,
  }) {
    final now = DateTime.now();
    final nextPayDate = payDaySettings.nextPayDate ?? now;

    // Calculate pay periods until next bill
    final payPeriodsUntilBill = _calculatePayPeriods(
      nextPayDate,
      nextBillDate,
      payDaySettings.payFrequency,
    );

    debugPrint('[InsightRecalc] 📊 Calculation details:');
    debugPrint('[InsightRecalc]   Next payday: $nextPayDate');
    debugPrint('[InsightRecalc]   Next bill date: $nextBillDate');
    debugPrint('[InsightRecalc]   Pay periods until bill: $payPeriodsUntilBill');

    // Calculate the gap (how much we need to save)
    final gap = billAmount - startingAmount;
    debugPrint('[InsightRecalc]   Gap to save: \$$gap');

    // Calculate pay periods per bill cycle (for ongoing amount)
    final payPeriodsPerCycle = _getPayPeriodsPerBillCycle(
      payDaySettings.payFrequency,
      billFrequency,
    );

    debugPrint('[InsightRecalc]   Pay periods per cycle: $payPeriodsPerCycle');

    // Determine if we're in steady state
    // Steady state = we have at least one full cycle's worth of paydays before the bill
    final isInSteadyState = payPeriodsUntilBill >= payPeriodsPerCycle;

    double recommendedCashFlow;

    if (gap <= 0) {
      // Already have enough - just maintain the balance
      recommendedCashFlow = billAmount / payPeriodsPerCycle.toDouble();
      debugPrint('[InsightRecalc]   No gap - maintaining: \$$recommendedCashFlow/paycheck');
    } else if (payPeriodsUntilBill <= 0) {
      // Bill is due immediately or overdue - need full gap now
      recommendedCashFlow = gap;
      debugPrint('[InsightRecalc]   Bill due now - need full gap: \$$recommendedCashFlow');
    } else if (isInSteadyState) {
      // In steady state - use sustainable ongoing amount
      recommendedCashFlow = billAmount / payPeriodsPerCycle.toDouble();
      debugPrint('[InsightRecalc]   Steady state - ongoing amount: \$$recommendedCashFlow/paycheck');
    } else {
      // Setup phase - need catch-up amount
      recommendedCashFlow = gap / payPeriodsUntilBill.toDouble();
      debugPrint('[InsightRecalc]   Setup phase - catch-up amount: \$$recommendedCashFlow/paycheck');
    }

    return {
      'recommendedCashFlow': recommendedCashFlow,
      'isInSteadyState': isInSteadyState,
      'payPeriodsUntilBill': payPeriodsUntilBill,
      'payPeriodsPerCycle': payPeriodsPerCycle,
      'gap': gap,
    };
  }

  /// Calculate number of pay periods between two dates
  int _calculatePayPeriods(
    DateTime startDate,
    DateTime endDate,
    String payFrequency,
  ) {
    if (endDate.isBefore(startDate) || endDate.isAtSameMomentAs(startDate)) {
      return 0;
    }

    int periods = 0;
    DateTime currentDate = startDate;

    while (currentDate.isBefore(endDate)) {
      periods++;
      currentDate = PayDaySettings.calculateNextPayDate(currentDate, payFrequency);

      // Safety check
      if (periods > 1000) break;
    }

    return periods;
  }

  /// Get how many pay periods occur per bill cycle
  int _getPayPeriodsPerBillCycle(String payFrequency, String billFrequency) {
    const daysPerWeek = 7.0;
    const daysPerMonth = 30.44;
    const daysPerYear = 365.25;

    double payDays = 0;
    switch (payFrequency) {
      case 'weekly':
        payDays = daysPerWeek;
        break;
      case 'biweekly':
        payDays = daysPerWeek * 2;
        break;
      case 'fourweekly':
        payDays = daysPerWeek * 4;
        break;
      case 'monthly':
        payDays = daysPerMonth;
        break;
    }

    double billDays = 0;
    switch (billFrequency) {
      case 'weekly':
        billDays = daysPerWeek;
        break;
      case 'biweekly':
        billDays = daysPerWeek * 2;
        break;
      case 'fourweekly':
        billDays = daysPerWeek * 4;
        break;
      case 'monthly':
        billDays = daysPerMonth;
        break;
      case 'yearly':
        billDays = daysPerYear;
        break;
    }

    if (payDays == 0) return 1;
    return (billDays / payDays).ceil();
  }

  /// Recalculate projected arrival dates for percentage-based allocations
  /// Triggered when income changes or commitments are modified
  Future<void> recalculatePercentageAllocations({
    required String userId,
    required EnvelopeRepo repo,
  }) async {
    debugPrint('[InsightRecalc] 🔄 Checking percentage-based allocations for recalculation');

    // Get all envelopes
    final envelopes = await repo.envelopesStream().first;

    // Filter to only percentage-based envelopes with dynamic recalculation enabled
    final percentageEnvelopes = envelopes.where((env) =>
      env.horizonMode == HorizonAllocationMode.percentage &&
      env.enableDynamicRecalculation == true &&
      env.allocationPercentage != null &&
      env.targetAmount != null
    ).toList();

    if (percentageEnvelopes.isEmpty) {
      debugPrint('[InsightRecalc] No percentage-based envelopes to recalculate');
      return;
    }

    // Get current pay settings
    final payDayService = PayDaySettingsService(null, userId);
    final paySettings = await payDayService.getPayDaySettings();

    if (paySettings == null || paySettings.expectedPayAmount == null) {
      debugPrint('[InsightRecalc] ⚠️ No pay settings found, skipping recalculation');
      return;
    }

    final currentAvailableIncome = await _calculateCurrentAvailableIncome(repo, paySettings);

    for (final envelope in percentageEnvelopes) {
      final lastKnownIncome = envelope.lastKnownAvailableIncome ?? 0.0;
      final incomeChange = (currentAvailableIncome - lastKnownIncome).abs();
      final changeThreshold = lastKnownIncome * 0.05; // 5% threshold

      if (incomeChange > changeThreshold) {
        debugPrint('[InsightRecalc] 💰 Income changed by \$${incomeChange.toStringAsFixed(2)} for ${envelope.name}');

        // Recalculate projected date
        final contributionPerPay = currentAvailableIncome * (envelope.allocationPercentage! / 100);
        final gap = envelope.targetAmount! - envelope.currentAmount;

        if (gap > 0 && contributionPerPay > 0) {
          final periodsNeeded = (gap / contributionPerPay).ceil();
          final newProjectedDate = _calculateProjectedDate(
            paySettings.nextPayDate ?? DateTime.now(),
            periodsNeeded,
            paySettings.payFrequency,
          );

          // Check if date changed significantly (> 7 days)
          final oldDate = envelope.projectedArrivalDate ?? DateTime.now();
          final daysDifference = newProjectedDate.difference(oldDate).inDays.abs();

          if (daysDifference > 7) {
            debugPrint('[InsightRecalc] 📅 Projected date changed by $daysDifference days');

            // Update envelope
            await repo.updateEnvelope(
              envelopeId: envelope.id,
              projectedArrivalDate: newProjectedDate,
              lastKnownAvailableIncome: currentAvailableIncome,
            );

            debugPrint('[InsightRecalc] ✅ Updated ${envelope.name} with new projected date: ${newProjectedDate.day}/${newProjectedDate.month}/${newProjectedDate.year}');
          }
        }
      }
    }
  }

  Future<double> _calculateCurrentAvailableIncome(
    EnvelopeRepo repo,
    PayDaySettings paySettings,
  ) async {
    // Calculate total existing commitments
    final envelopes = await repo.envelopesStream().first;
    final commitments = envelopes
        .where((env) => env.cashFlowEnabled && env.cashFlowAmount != null)
        .fold<double>(0.0, (sum, env) => sum + env.cashFlowAmount!);

    return (paySettings.expectedPayAmount ?? 0.0) - commitments;
  }

  DateTime _calculateProjectedDate(DateTime start, int periods, String frequency) {
    DateTime projected = start;
    for (int i = 0; i < periods; i++) {
      switch (frequency) {
        case 'weekly':
          projected = projected.add(const Duration(days: 7));
          break;
        case 'biweekly':
          projected = projected.add(const Duration(days: 14));
          break;
        case 'fourweekly':
          projected = projected.add(const Duration(days: 28));
          break;
        case 'monthly':
          projected = DateTime(projected.year, projected.month + 1, projected.day);
          break;
      }
    }
    return projected;
  }
}
