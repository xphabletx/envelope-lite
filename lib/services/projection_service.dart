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

    print('\n========== PROJECTION CALCULATION START ==========');
    print('Target Date: $targetDate');
    print('Current Date: $now');
    print('Days ahead: ${targetDate.difference(now).inDays}');

    if (targetDate.isBefore(now)) {
      throw ArgumentError('Target date must be in the future');
    }

    // --- 1. SETUP STATE ---
    print('\n--- 1. INITIAL STATE SETUP ---');
    final accountBalances = <String, double>{};
    for (final a in accounts) {
      accountBalances[a.id] = a.currentBalance;
      print('Account "${a.name}" (${a.id}): £${a.currentBalance.toStringAsFixed(2)}');
    }

    final envelopeBalances = <String, double>{};
    for (final e in envelopes) {
      final isEnabled = scenario?.envelopeEnabled[e.id] ?? true;
      if (!isEnabled) {
        print('Envelope "${e.name}" DISABLED - skipping');
        continue;
      }
      envelopeBalances[e.id] = e.currentAmount;
      print('Envelope "${e.name}" (${e.id}): £${e.currentAmount.toStringAsFixed(2)} (auto-fill: ${e.autoFillEnabled ? "£${e.autoFillAmount?.toStringAsFixed(2) ?? '0'}" : "OFF"})');
    }

    final events = <ProjectionEvent>[];

    // --- 2. GENERATE TIMELINE ---
    print('\n--- 2. TIMELINE GENERATION ---');
    final payAmount =
        scenario?.customPayAmount ?? paySettings.lastPayAmount ?? 0;
    final payFrequency =
        scenario?.customPayFrequency ?? paySettings.payFrequency;

    print('Pay Amount: £${payAmount.toStringAsFixed(2)}');
    print('Pay Frequency: $payFrequency');

    String defaultAccountId = '';
    if (paySettings.defaultAccountId != null) {
      defaultAccountId = paySettings.defaultAccountId!;
    } else if (accounts.isNotEmpty) {
      defaultAccountId = accounts.first.id;
    }
    print('Default Pay Account ID: $defaultAccountId');

    double totalSpentAmount = 0.0; // Track money that leaves the system

    // Generate pay days
    print('\nGenerating pay day events...');
    final payDates = _getPayDaysBetween(
      now,
      targetDate,
      payFrequency,
      paySettings,
    );
    print('Found ${payDates.length} pay dates between now and target date');

    for (final date in payDates) {
      print('  Pay day event: $date - £${payAmount.toStringAsFixed(2)}');
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
    print('\nGenerating scheduled payment events...');
    for (final payment in scheduledPayments) {
      final occurrences = _getOccurrencesBetween(now, targetDate, payment);
      print('  Scheduled payment "${payment.name}": ${occurrences.length} occurrences');
      for (final date in occurrences) {
        if (payment.envelopeId != null) {
          final isEnabled =
              scenario?.envelopeEnabled[payment.envelopeId] ?? true;
          if (!isEnabled) {
            print('    Skipping occurrence on $date (envelope disabled)');
            continue;
          }
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

        print('    Scheduled payment event: $date - "${payment.name}" £${payment.amount.toStringAsFixed(2)} (envelope: ${envelopeName ?? "none"})');
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
    print('\nGenerating temporary expense events...');
    if (scenario != null) {
      for (final temp in scenario.temporaryEnvelopes) {
        if (temp.effectiveDate.isAfter(now) &&
            temp.effectiveDate.isBefore(targetDate)) {
          print('  Temp expense event: ${temp.effectiveDate} - "${temp.name}" £${temp.amount.toStringAsFixed(2)}');
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
    print('\n--- 3. PROCESSING TIMELINE ---');
    events.sort((a, b) => a.date.compareTo(b.date));
    print('Total events to process: ${events.length}');

    for (final event in events) {
      print('\n[${event.date}] Processing: ${event.type} - ${event.description} £${event.amount.toStringAsFixed(2)}');

      if (event.type == 'pay_day') {
        final sourceAccountId = event.accountId;

        // Step 1: Income arrives
        if (sourceAccountId != null &&
            accountBalances.containsKey(sourceAccountId)) {
          final oldBalance = accountBalances[sourceAccountId] ?? 0;
          accountBalances[sourceAccountId] = oldBalance + event.amount;
          print('  STEP 1 - Income: Account balance ${oldBalance.toStringAsFixed(2)} + ${event.amount.toStringAsFixed(2)} = ${accountBalances[sourceAccountId]!.toStringAsFixed(2)}');
        }

        // Step 2: Auto-fill envelopes
        print('  STEP 2 - Auto-fill envelopes:');
        for (final envelope in envelopes) {
          if (scenario?.envelopeEnabled[envelope.id] == false) {
            print('    Envelope "${envelope.name}" - DISABLED, skipping');
            continue;
          }

          if (!envelope.autoFillEnabled) {
            print('    Envelope "${envelope.name}" - auto-fill OFF, skipping');
            continue;
          }

          final autoFillAmount = envelope.autoFillAmount ?? 0;

          if (autoFillAmount <= 0) {
            print('    Envelope "${envelope.name}" - auto-fill amount £0, skipping');
            continue;
          }

          final targetAccountId = envelope.linkedAccountId ?? sourceAccountId;

          // Update envelope
          final oldEnvBalance = envelopeBalances[envelope.id] ?? 0;
          envelopeBalances[envelope.id] = oldEnvBalance + autoFillAmount;
          print('    Envelope "${envelope.name}": ${oldEnvBalance.toStringAsFixed(2)} + ${autoFillAmount.toStringAsFixed(2)} = ${envelopeBalances[envelope.id]!.toStringAsFixed(2)}');

          // Deduct from account
          if (sourceAccountId != null && targetAccountId != null) {
            if (sourceAccountId != targetAccountId) {
              // Transfer to different account
              final oldSourceBal = accountBalances[sourceAccountId] ?? 0;
              final oldTargetBal = accountBalances[targetAccountId] ?? 0;
              accountBalances[sourceAccountId] = oldSourceBal - autoFillAmount;
              accountBalances[targetAccountId] = oldTargetBal + autoFillAmount;
              print('      Transfer: Source account ${oldSourceBal.toStringAsFixed(2)} - ${autoFillAmount.toStringAsFixed(2)} = ${accountBalances[sourceAccountId]!.toStringAsFixed(2)}');
              print('      Transfer: Target account ${oldTargetBal.toStringAsFixed(2)} + ${autoFillAmount.toStringAsFixed(2)} = ${accountBalances[targetAccountId]!.toStringAsFixed(2)}');
            } else {
              // Same account - assign
              final oldAcctBal = accountBalances[sourceAccountId] ?? 0;
              accountBalances[sourceAccountId] = oldAcctBal - autoFillAmount;
              print('      Assign: Account ${oldAcctBal.toStringAsFixed(2)} - ${autoFillAmount.toStringAsFixed(2)} = ${accountBalances[sourceAccountId]!.toStringAsFixed(2)}');
            }
          }
        }
      } else if (!event.isCredit) {
        // Scheduled payment or temp expense
        if (event.envelopeId != null) {
          // Deduct from envelope
          final oldBal = envelopeBalances[event.envelopeId!] ?? 0;
          envelopeBalances[event.envelopeId!] = oldBal - event.amount;
          print('  PAYMENT from envelope "${event.envelopeName}": ${oldBal.toStringAsFixed(2)} - ${event.amount.toStringAsFixed(2)} = ${envelopeBalances[event.envelopeId!]!.toStringAsFixed(2)}');

          // Track as money that LEFT the system (paid to external entity)
          totalSpentAmount += event.amount;
          print('  SPENT tracking: Total spent is now £${totalSpentAmount.toStringAsFixed(2)}');
        } else if (event.type == 'temporary_expense') {
          // Temp expenses deduct from account
          if (event.accountId != null &&
              accountBalances.containsKey(event.accountId!)) {
            final oldBal = accountBalances[event.accountId!] ?? 0;
            accountBalances[event.accountId!] = oldBal - event.amount;
            print('  TEMP EXPENSE from account: ${oldBal.toStringAsFixed(2)} - ${event.amount.toStringAsFixed(2)} = ${accountBalances[event.accountId!]!.toStringAsFixed(2)}');

            // Track as spent
            totalSpentAmount += event.amount;
            print('  SPENT tracking: Total spent is now £${totalSpentAmount.toStringAsFixed(2)}');
          }
        }
      }
    }

    // --- 4. BUILD RESULTS ---
    print('\n--- 4. BUILDING FINAL RESULTS ---');
    final accountProjections = <String, AccountProjection>{};
    double totalAvailable = 0;
    double totalAssigned = 0;

    for (final account in accounts) {
      final finalBalance =
          accountBalances[account.id] ?? account.currentBalance;
      print('\nAccount "${account.name}": Final balance = £${finalBalance.toStringAsFixed(2)}');

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
        print('  Envelope "${env.name}": £${projectedEnvBalance.toStringAsFixed(2)}');

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
      print('  Total in envelopes: £${accountAssignedTotal.toStringAsFixed(2)}');
      print('  Available (unallocated): £${available.toStringAsFixed(2)}');

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

    print('\n========== FINAL TOTALS ==========');
    print('Total Available (unallocated): £${totalAvailable.toStringAsFixed(2)}');
    print('Total Assigned (in envelopes): £${totalAssigned.toStringAsFixed(2)}');
    print('Total Balance (available + assigned): £${(totalAvailable + totalAssigned).toStringAsFixed(2)}');
    print('Total Spent (paid to bills): £${totalSpentAmount.toStringAsFixed(2)}');
    print('Total in System: £${(totalAvailable + totalAssigned).toStringAsFixed(2)}');
    print('========== CALCULATION COMPLETE ==========\n');

    return ProjectionResult(
      projectionDate: targetDate,
      accountProjections: accountProjections,
      timeline: events,
      totalAvailable: totalAvailable,
      totalAssigned: totalAssigned,
      totalSpent: totalSpentAmount,
    );
  }

  static List<DateTime> _getPayDaysBetween(
    DateTime start,
    DateTime end,
    String frequency,
    PayDaySettings settings,
  ) {
    print('\n  >>> _getPayDaysBetween DEBUG <<<');
    print('  Start: $start');
    print('  End: $end');
    print('  Frequency: $frequency');
    print('  Last pay date: ${settings.lastPayDate}');
    print('  Pay day of month: ${settings.payDayOfMonth}');

    final payDays = <DateTime>[];

    if (frequency == 'monthly') {
      if (settings.payDayOfMonth == null) {
        print('  ERROR: Pay day of month is null for monthly frequency');
        return payDays;
      }

      DateTime current;

      if (settings.lastPayDate != null) {
        // Start checking from next month after last pay
        print('  MONTHLY: Starting from next month after last pay date');
        current = _clampDate(
          settings.lastPayDate!.year,
          settings.lastPayDate!.month + 1,
          settings.payDayOfMonth!,
        );
        print('  Initial current date: $current');
      } else {
        // Start from this month
        print('  MONTHLY: No last pay date, starting from this month');
        current = _clampDate(start.year, start.month, settings.payDayOfMonth!);
        print('  Initial current date: $current');
        // If today is past pay day, start next month
        if (current.isBefore(start)) {
          print('  Current is before start, moving to next month');
          current = _clampDate(
            start.year,
            start.month + 1,
            settings.payDayOfMonth!,
          );
          print('  Updated current date: $current');
        }
      }

      // Add payments while strictly before or on end date
      print('  Fast-forwarding to start date if needed...');
      while (current.isBefore(start)) {
        print('    Skipping $current (before start)');
        current = _clampDate(
          current.year,
          current.month + 1,
          settings.payDayOfMonth!,
        );
      }

      print('  Adding pay dates in range...');
      while (!current.isAfter(end)) {
        if (!current.isBefore(start)) {
          print('    Adding pay date: $current');
          payDays.add(current);
        }
        current = _clampDate(
          current.year,
          current.month + 1,
          settings.payDayOfMonth!,
        );
      }
      print('  Finished monthly calculation. Total pay dates: ${payDays.length}');
    } else if (frequency == 'biweekly') {
      if (settings.lastPayDate == null) {
        print('  ERROR: Last pay date is null for biweekly frequency');
        return payDays;
      }
      print('  BIWEEKLY: Starting from last pay date + 14 days');
      var current = settings.lastPayDate!.add(const Duration(days: 14));
      print('  Initial current date: $current');

      print('  Fast-forwarding to start date if needed...');
      while (current.isBefore(start)) {
        print('    Skipping $current (before start)');
        current = current.add(const Duration(days: 14));
      }

      print('  Adding pay dates in range...');
      while (!current.isAfter(end)) {
        print('    Adding pay date: $current');
        payDays.add(current);
        current = current.add(const Duration(days: 14));
      }
      print('  Finished biweekly calculation. Total pay dates: ${payDays.length}');
    } else if (frequency == 'weekly') {
      if (settings.lastPayDate == null) {
        print('  ERROR: Last pay date is null for weekly frequency');
        return payDays;
      }
      print('  WEEKLY: Starting from last pay date + 7 days');
      var current = settings.lastPayDate!.add(const Duration(days: 7));
      print('  Initial current date: $current');

      print('  Fast-forwarding to start date if needed...');
      while (current.isBefore(start)) {
        print('    Skipping $current (before start)');
        current = current.add(const Duration(days: 7));
      }

      print('  Adding pay dates in range...');
      while (!current.isAfter(end)) {
        print('    Adding pay date: $current');
        payDays.add(current);
        current = current.add(const Duration(days: 7));
      }
      print('  Finished weekly calculation. Total pay dates: ${payDays.length}');
    }

    print('  >>> Returning ${payDays.length} pay dates <<<\n');
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
