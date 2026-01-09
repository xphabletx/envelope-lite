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

      debugPrint('[InsightRecalc] 💰 Results:');
      debugPrint('[InsightRecalc]   Old cash flow: \$$oldCashFlow');
      debugPrint('[InsightRecalc]   New cash flow: \$$newCashFlow');
      debugPrint('[InsightRecalc]   Steady state: $isInSteadyState');

      // 8. Only update if amount changed significantly (more than $0.01)
      if ((newCashFlow - oldCashFlow).abs() < 0.01) {
        debugPrint('[InsightRecalc] ✅ No significant change, skipping update');
        return false;
      }

      // 9. Update envelope's cash flow amount
      await envelopeRepo.updateEnvelope(
        envelopeId: envelope.id,
        cashFlowAmount: newCashFlow,
      );

      debugPrint('[InsightRecalc] ✅ Updated cash flow: \$$oldCashFlow → \$$newCashFlow');

      // 10. Create notification
      await notificationRepo.createNotification(
        type: NotificationType.scheduledPaymentProcessed, // Reuse existing type
        title: 'Cash Flow Updated',
        message: isInSteadyState
            ? '${envelope.name}: Cash flow adjusted to \$${newCashFlow.toStringAsFixed(2)}/paycheck (steady state reached)'
            : '${envelope.name}: Cash flow adjusted to \$${newCashFlow.toStringAsFixed(2)}/paycheck',
        metadata: {
          'envelopeId': envelope.id,
          'envelopeName': envelope.name,
          'oldCashFlow': oldCashFlow,
          'newCashFlow': newCashFlow,
          'isInSteadyState': isInSteadyState,
          'reason': 'autopilot_recalculation',
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
}
