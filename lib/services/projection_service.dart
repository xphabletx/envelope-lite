// lib/services/projection_service.dart
import '../models/account.dart';
import '../models/envelope.dart';
import '../models/scheduled_payment.dart';
import '../models/pay_day_settings.dart';
import '../models/projection.dart';

class ProjectionService {
  static Future<ProjectionResult> calculateProjection({
    required DateTime targetDate,
    required List<Account> accounts,
    required List<Envelope> envelopes,
    required List<ScheduledPayment> scheduledPayments,
    required PayDaySettings paySettings,
    ProjectionScenario? scenario,
  }) async {
    final now = DateTime.now();

    if (targetDate.isBefore(now)) {
      throw ArgumentError('Target date must be in the future');
    }

    // --- 1. SETUP STATE ---
    final accountBalances = <String, double>{};
    for (final a in accounts) {
      accountBalances[a.id] = a.currentBalance;
    }

    final envelopeBalances = <String, double>{};
    for (final e in envelopes) {
      final isEnabled = scenario?.envelopeEnabled[e.id] ?? true;
      if (!isEnabled) continue;
      envelopeBalances[e.id] = e.currentAmount;
    }

    final events = <ProjectionEvent>[];

    // --- 2. GENERATE TIMELINE ---
    final payAmount =
        scenario?.customPayAmount ?? paySettings.lastPayAmount ?? 0;
    final payFrequency =
        scenario?.customPayFrequency ?? paySettings.payFrequency;

    String defaultAccountId = '';
    if (paySettings.defaultAccountId != null) {
      defaultAccountId = paySettings.defaultAccountId!;
    } else if (accounts.isNotEmpty) {
      defaultAccountId = accounts.first.id;
    }

    // Generate pay days
    final payDates = _getPayDaysBetween(
      now,
      targetDate,
      payFrequency,
      paySettings,
    );

    for (final date in payDates) {
      events.add(
        ProjectionEvent(
          date: date,
          type: 'pay_day',
          description: 'Pay Day',
          amount: payAmount,
          isCredit: true,
          accountId: defaultAccountId,
          accountName:
              accounts
                  .where((a) => a.id == defaultAccountId)
                  .map((a) => a.name)
                  .firstOrNull ??
              'Main',
        ),
      );
    }

    // Generate scheduled payments
    for (final payment in scheduledPayments) {
      final occurrences = _getOccurrencesBetween(now, targetDate, payment);
      for (final date in occurrences) {
        if (payment.envelopeId != null) {
          final isEnabled =
              scenario?.envelopeEnabled[payment.envelopeId] ?? true;
          if (!isEnabled) continue;
        }

        String? envelopeName;
        String? linkedAccountId;

        if (payment.envelopeId != null) {
          final env = envelopes
              .where((e) => e.id == payment.envelopeId)
              .firstOrNull;
          envelopeName = env?.name;
          linkedAccountId = env?.linkedAccountId;
        }

        events.add(
          ProjectionEvent(
            date: date,
            type: 'scheduled_payment',
            description: payment.name,
            amount: payment.amount,
            isCredit: false,
            envelopeId: payment.envelopeId,
            envelopeName: envelopeName,
            accountId: linkedAccountId,
            accountName: null,
          ),
        );
      }
    }

    // Add temporary expenses
    if (scenario != null) {
      for (final temp in scenario.temporaryEnvelopes) {
        if (temp.effectiveDate.isAfter(now) &&
            temp.effectiveDate.isBefore(targetDate)) {
          events.add(
            ProjectionEvent(
              date: temp.effectiveDate,
              type: 'temporary_expense',
              description: temp.name,
              amount: temp.amount,
              isCredit: false,
              envelopeId: null,
              accountId: temp.linkedAccountId,
              accountName: 'Temporary',
            ),
          );
        }
      }
    }

    // --- 3. PROCESS TIMELINE ---
    events.sort((a, b) => a.date.compareTo(b.date));

    for (final event in events) {
      if (event.type == 'pay_day') {
        final sourceAccountId = event.accountId;

        // Step 1: Income arrives
        if (sourceAccountId != null &&
            accountBalances.containsKey(sourceAccountId)) {
          accountBalances[sourceAccountId] =
              (accountBalances[sourceAccountId] ?? 0) + event.amount;
        }

        // Step 2: Auto-fill envelopes
        for (final envelope in envelopes) {
          if (scenario?.envelopeEnabled[envelope.id] == false) continue;

          if (!envelope.autoFillEnabled) {
            continue;
          }

          final autoFillAmount = envelope.autoFillAmount ?? 0;

          if (autoFillAmount <= 0) {
            continue;
          }

          final targetAccountId = envelope.linkedAccountId ?? sourceAccountId;

          // Update envelope
          envelopeBalances[envelope.id] =
              (envelopeBalances[envelope.id] ?? 0) + autoFillAmount;

          // Deduct from account
          if (sourceAccountId != null && targetAccountId != null) {
            if (sourceAccountId != targetAccountId) {
              // Transfer to different account
              accountBalances[sourceAccountId] =
                  (accountBalances[sourceAccountId] ?? 0) - autoFillAmount;
              accountBalances[targetAccountId] =
                  (accountBalances[targetAccountId] ?? 0) + autoFillAmount;
            } else {
              // Same account - assign
              accountBalances[sourceAccountId] =
                  (accountBalances[sourceAccountId] ?? 0) - autoFillAmount;
            }
          }
        }
      } else if (!event.isCredit) {
        // Scheduled payment or temp expense
        if (event.envelopeId != null) {
          // Deduct from envelope only
          final oldBal = envelopeBalances[event.envelopeId!] ?? 0;
          envelopeBalances[event.envelopeId!] = oldBal - event.amount;
        } else if (event.type == 'temporary_expense') {
          // Temp expenses deduct from account
          if (event.accountId != null &&
              accountBalances.containsKey(event.accountId!)) {
            accountBalances[event.accountId!] =
                (accountBalances[event.accountId!] ?? 0) - event.amount;
          }
        }
      }
    }

    // --- 4. BUILD RESULTS ---
    final accountProjections = <String, AccountProjection>{};
    double totalAvailable = 0;
    double totalAssigned = 0;

    for (final account in accounts) {
      final finalBalance =
          accountBalances[account.id] ?? account.currentBalance;
      final linkedEnvelopes = envelopes
          .where((e) => e.linkedAccountId == account.id)
          .toList();

      final envProjections = <EnvelopeProjection>[];
      double accountAssignedTotal = 0;

      for (final env in linkedEnvelopes) {
        if (scenario?.envelopeEnabled[env.id] == false) continue;

        double projectedEnvBalance =
            envelopeBalances[env.id] ?? env.currentAmount;

        if (scenario?.envelopeOverrides.containsKey(env.id) == true) {
          projectedEnvBalance = scenario!.envelopeOverrides[env.id]!;
        }

        accountAssignedTotal += projectedEnvBalance;

        envProjections.add(
          EnvelopeProjection(
            envelopeId: env.id,
            envelopeName: env.name,
            emoji: env.emoji,
            iconType: env.iconType,
            iconValue: env.iconValue,
            currentAmount: env.currentAmount,
            projectedAmount: projectedEnvBalance,
            targetAmount: env.targetAmount ?? 0,
            hasTarget: (env.targetAmount ?? 0) > 0,
            willMeetTarget: projectedEnvBalance >= (env.targetAmount ?? 0),
          ),
        );
      }

      final available = finalBalance - accountAssignedTotal;

      accountProjections[account.id] = AccountProjection(
        accountId: account.id,
        accountName: account.name,
        projectedBalance: finalBalance,
        assignedAmount: accountAssignedTotal,
        availableAmount: available,
        envelopeProjections: envProjections,
      );

      totalAvailable += available;
      totalAssigned += accountAssignedTotal;
    }

    return ProjectionResult(
      projectionDate: targetDate,
      accountProjections: accountProjections,
      timeline: events,
      totalAvailable: totalAvailable,
      totalAssigned: totalAssigned,
    );
  }

  static List<DateTime> _getPayDaysBetween(
    DateTime start,
    DateTime end,
    String frequency,
    PayDaySettings settings,
  ) {
    final payDays = <DateTime>[];

    if (frequency == 'monthly') {
      if (settings.payDayOfMonth == null) return payDays;

      DateTime current;

      if (settings.lastPayDate != null) {
        // Start checking from next month after last pay
        current = _clampDate(
          settings.lastPayDate!.year,
          settings.lastPayDate!.month + 1,
          settings.payDayOfMonth!,
        );
      } else {
        // Start from this month
        current = _clampDate(start.year, start.month, settings.payDayOfMonth!);
        // If today is past pay day, start next month
        if (current.isBefore(start)) {
          current = _clampDate(
            start.year,
            start.month + 1,
            settings.payDayOfMonth!,
          );
        }
      }

      // Add payments while strictly before or on end date
      while (current.isBefore(start)) {
        current = _clampDate(
          current.year,
          current.month + 1,
          settings.payDayOfMonth!,
        );
      }

      while (!current.isAfter(end)) {
        if (!current.isBefore(start)) {
          payDays.add(current);
        }
        current = _clampDate(
          current.year,
          current.month + 1,
          settings.payDayOfMonth!,
        );
      }
    } else if (frequency == 'biweekly') {
      if (settings.lastPayDate == null) return payDays;
      var current = settings.lastPayDate!.add(const Duration(days: 14));
      while (current.isBefore(start)) {
        current = current.add(const Duration(days: 14));
      }
      while (!current.isAfter(end)) {
        payDays.add(current);
        current = current.add(const Duration(days: 14));
      }
    } else if (frequency == 'weekly') {
      if (settings.lastPayDate == null) return payDays;
      var current = settings.lastPayDate!.add(const Duration(days: 7));
      while (current.isBefore(start)) {
        current = current.add(const Duration(days: 7));
      }
      while (!current.isAfter(end)) {
        payDays.add(current);
        current = current.add(const Duration(days: 7));
      }
    }
    return payDays;
  }

  static List<DateTime> _getOccurrencesBetween(
    DateTime start,
    DateTime end,
    ScheduledPayment payment,
  ) {
    final occurrences = <DateTime>[];
    var current = payment.nextDueDate;
    while (!current.isAfter(end)) {
      if (!current.isBefore(start)) {
        occurrences.add(current);
      }
      current = _getNextOccurrence(
        current,
        payment.frequencyValue,
        payment.frequencyUnit,
      );
    }
    return occurrences;
  }

  static DateTime _getNextOccurrence(
    DateTime current,
    int freqValue,
    PaymentFrequencyUnit freqUnit,
  ) {
    switch (freqUnit) {
      case PaymentFrequencyUnit.days:
        return current.add(Duration(days: freqValue));
      case PaymentFrequencyUnit.weeks:
        return current.add(Duration(days: 7 * freqValue));
      case PaymentFrequencyUnit.months:
        return _clampDate(current.year, current.month + freqValue, current.day);
      case PaymentFrequencyUnit.years:
        return _clampDate(current.year + freqValue, current.month, current.day);
    }
  }

  /// Ensures date doesn't overflow (e.g., Feb 31 becomes Feb 28)
  static DateTime _clampDate(int year, int month, int day) {
    // Calculate effective year and month handling month overflow/underflow
    var effectiveYear = year + (month - 1) ~/ 12;
    var effectiveMonth = (month - 1) % 12 + 1;

    final daysInMonth = DateTime(effectiveYear, effectiveMonth + 1, 0).day;
    final clampedDay = day > daysInMonth ? daysInMonth : day;

    return DateTime(effectiveYear, effectiveMonth, clampedDay);
  }
}
