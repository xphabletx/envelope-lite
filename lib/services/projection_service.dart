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
      if (!isEnabled) {
        continue;
      }
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

    double totalSpentAmount = 0.0; // Track money that leaves the system

    // Generate pay days
    final payDates = _getPayDaysBetween(
      now,
      targetDate,
      payFrequency,
      paySettings,
    );

    for (final date in payDates) {

      // Create pay_day event (income arrives in account)
      // Auto-fill to envelopes and accounts is handled during pay_day event processing
      final defaultAccountName = accounts
          .where((a) => a.id == defaultAccountId)
          .map((a) => a.name)
          .firstOrNull ?? 'Main';

      events.add(
        ProjectionEvent(
          date: date,
          type: 'pay_day',
          description: 'PAY DAY!',
          amount: payAmount,
          isCredit: true,
          accountId: defaultAccountId,
          accountName: defaultAccountName,
          isExternal: true, // EXTERNAL inflow - money from employer
          direction: 'inflow',
        ),
      );

      // Note: Account-to-account cash flow transfers have been removed from the Account model
    }

    // Generate scheduled payments
    for (final payment in scheduledPayments) {
      // Check if there's a date override for this payment
      final hasOverride = scenario?.scheduledPaymentDateOverrides.containsKey(payment.id) ?? false;

      List<DateTime> occurrences;
      if (hasOverride) {
        final overrideDate = scenario!.scheduledPaymentDateOverrides[payment.id]!;
        // Use only the override date instead of regular occurrences
        occurrences = (overrideDate.isAfter(now) && !overrideDate.isAfter(targetDate))
            ? [overrideDate]
            : [];
      } else {
        occurrences = _getOccurrencesBetween(now, targetDate, payment);
      }

      for (final date in occurrences) {
        if (payment.envelopeId != null) {
          final isEnabled =
              scenario?.envelopeEnabled[payment.envelopeId] ?? true;
          if (!isEnabled) {
            continue;
          }
        }

        String? envelopeName;
        String? linkedAccountId;

        if (payment.envelopeId != null) {
          final env = envelopes
              .where((e) => e.id == payment.envelopeId)
              .firstOrNull;

          // Skip this payment if the envelope no longer exists (orphaned data)
          if (env == null) {
            continue;
          }

          envelopeName = env.name;
          linkedAccountId = env.linkedAccountId;
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
            isExternal: true, // EXTERNAL outflow - bill payment leaving system
            direction: 'outflow',
          ),
        );
      }
    }

    // Add temporary income/expense events
    if (scenario != null) {
      for (final temp in scenario.temporaryEnvelopes) {
        final tempOccurrences = _getTemporaryOccurrences(temp, now, targetDate);

        for (final date in tempOccurrences) {

          if (temp.isIncome) {
            // Temporary income creates a pay_day event (will trigger auto-fill)
            events.add(
              ProjectionEvent(
                date: date,
                type: 'temporary_income',
                description: temp.name,
                amount: temp.amount,
                isCredit: true,
                accountId: defaultAccountId,
                accountName: accounts
                    .where((a) => a.id == defaultAccountId)
                    .map((a) => a.name)
                    .firstOrNull ?? 'Main',
                isExternal: true, // EXTERNAL inflow - temporary income
                direction: 'inflow',
              ),
            );
          } else {
            // Temporary expense deducts from account
            events.add(
              ProjectionEvent(
                date: date,
                type: 'temporary_expense',
                description: temp.name,
                amount: temp.amount,
                isCredit: false,
                envelopeId: null,
                accountId: temp.linkedAccountId ?? defaultAccountId,
                accountName: 'Temporary',
                isExternal: true, // EXTERNAL outflow - temporary expense
                direction: 'outflow',
              ),
            );
          }
        }
      }
    }

    // --- 3. PROCESS TIMELINE ---
    events.sort((a, b) => a.date.compareTo(b.date));

    // Track when each envelope reaches its target
    final envelopeTargetAchievedDate = <String, DateTime>{};

    // Collect auto-fill events separately to avoid concurrent modification
    final autoFillEvents = <ProjectionEvent>[];

    for (final event in events) {

      if (event.type == 'pay_day' || event.type == 'temporary_income') {
        final sourceAccountId = event.accountId;

        // Step 1: Income arrives
        if (sourceAccountId != null &&
            accountBalances.containsKey(sourceAccountId)) {
          final oldBalance = accountBalances[sourceAccountId] ?? 0;
          accountBalances[sourceAccountId] = oldBalance + event.amount;
        }

        // Step 2: Cash flow envelopes
        for (final envelope in envelopes) {
          if (scenario?.envelopeEnabled[envelope.id] == false) {
            continue;
          }

          // Check for envelope setting overrides in scenario
          final settingOverride = scenario?.envelopeSettings[envelope.id];
          final cashFlowEnabled = settingOverride?.cashFlowEnabled ?? envelope.cashFlowEnabled;
          final cashFlowAmount = settingOverride?.cashFlowAmount ?? envelope.cashFlowAmount ?? 0;

          if (!cashFlowEnabled) {
            continue;
          }

          if (settingOverride?.cashFlowAmount != null) {
          }

          if (cashFlowAmount <= 0) {
            continue;
          }

          final targetAccountId = envelope.linkedAccountId ?? sourceAccountId;

          // Update envelope
          final oldEnvBalance = envelopeBalances[envelope.id] ?? 0;
          envelopeBalances[envelope.id] = oldEnvBalance + cashFlowAmount;

          // Check if envelope reached its target for the first time
          final targetAmount = envelope.targetAmount;
          if (targetAmount != null && targetAmount > 0 && !envelopeTargetAchievedDate.containsKey(envelope.id)) {
            final newBalance = envelopeBalances[envelope.id]!;
            if (newBalance >= targetAmount) {
              envelopeTargetAchievedDate[envelope.id] = event.date;
            }
          }

          // Create cash_flow event for envelope transaction history (deposit to envelope)
          final sourceAccountName = accounts
              .where((a) => a.id == sourceAccountId)
              .map((a) => a.name)
              .firstOrNull ?? 'Main';

          // Deposit to envelope
          autoFillEvents.add(
            ProjectionEvent(
              date: event.date,
              type: 'cash_flow',
              description: 'Cash flow from $sourceAccountName',
              amount: cashFlowAmount,
              isCredit: true, // Credit to envelope
              envelopeId: envelope.id,
              envelopeName: envelope.name,
              accountId: sourceAccountId,
              accountName: sourceAccountName,
              isExternal: false, // INTERNAL move - account to envelope
              direction: 'move',
            ),
          );

          // Withdrawal from account (for account transaction history)
          autoFillEvents.add(
            ProjectionEvent(
              date: event.date,
              type: 'envelope_cash_flow_withdrawal',
              description: 'Cash flow to ${envelope.name}',
              amount: cashFlowAmount,
              isCredit: false, // Debit from account
              envelopeId: '', // Account-level transaction (no envelope)
              accountId: sourceAccountId,
              accountName: sourceAccountName,
              isExternal: false, // INTERNAL move - account to envelope
              direction: 'move',
            ),
          );

          // Deduct from account
          if (sourceAccountId != null && targetAccountId != null) {
            if (sourceAccountId != targetAccountId) {
              // Transfer to different account
              final oldSourceBal = accountBalances[sourceAccountId] ?? 0;
              final oldTargetBal = accountBalances[targetAccountId] ?? 0;
              accountBalances[sourceAccountId] = oldSourceBal - cashFlowAmount;
              accountBalances[targetAccountId] = oldTargetBal + cashFlowAmount;
            } else {
              // Same account - assign
              final oldAcctBal = accountBalances[sourceAccountId] ?? 0;
              accountBalances[sourceAccountId] = oldAcctBal - cashFlowAmount;
            }
          }
        }
      } else if (!event.isCredit) {
        // Scheduled payment or temp expense
        if (event.envelopeId != null) {
          // Deduct from envelope
          final oldBal = envelopeBalances[event.envelopeId!] ?? 0;
          envelopeBalances[event.envelopeId!] = oldBal - event.amount;

          // Track as money that LEFT the system (paid to external entity)
          totalSpentAmount += event.amount;
        } else if (event.type == 'temporary_expense') {
          // Temp expenses deduct from account
          if (event.accountId != null &&
              accountBalances.containsKey(event.accountId!)) {
            final oldBal = accountBalances[event.accountId!] ?? 0;
            accountBalances[event.accountId!] = oldBal - event.amount;

            // Track as spent
            totalSpentAmount += event.amount;
          }
        }
      }
    }

    // Add cash flow events to timeline for transaction history visibility
    events.addAll(autoFillEvents);

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

        // Calculate target achievement metrics
        final targetAmount = env.targetAmount ?? 0;
        final hasTarget = targetAmount > 0;
        final willMeetTarget = projectedEnvBalance >= targetAmount;
        final targetDate = env.targetDate;
        final targetAchievedDate = envelopeTargetAchievedDate[env.id];

        // Calculate overachievement
        double? overachievementAmount;
        if (hasTarget && willMeetTarget) {
          overachievementAmount = projectedEnvBalance - targetAmount;
        }

        // Calculate days until target achieved (from now)
        int? daysUntilTarget;
        if (targetAchievedDate != null) {
          daysUntilTarget = targetAchievedDate.difference(now).inDays;
        }

        // Calculate days before/after target date when achieved
        int? daysBeforeTargetDate;
        if (targetDate != null && targetAchievedDate != null) {
          daysBeforeTargetDate = targetDate.difference(targetAchievedDate).inDays;
        }

        if (hasTarget) {
          if (targetDate != null) {
          }
          if (targetAchievedDate != null) {
            if (daysBeforeTargetDate != null) {
              if (daysBeforeTargetDate > 0) {
              } else if (daysBeforeTargetDate < 0) {
              } else {
              }
            }
            if (overachievementAmount != null && overachievementAmount > 0) {
            }
          } else if (willMeetTarget) {
          } else {
          }
        }

        envProjections.add(
          EnvelopeProjection(
            envelopeId: env.id,
            envelopeName: env.name,
            emoji: env.emoji,
            iconType: env.iconType,
            iconValue: env.iconValue,
            currentAmount: env.currentAmount,
            projectedAmount: projectedEnvBalance,
            targetAmount: targetAmount,
            hasTarget: hasTarget,
            willMeetTarget: willMeetTarget,
            targetDate: targetDate,
            targetAchievedDate: targetAchievedDate,
            overachievementAmount: overachievementAmount,
            daysUntilTarget: daysUntilTarget,
            daysBeforeTargetDate: daysBeforeTargetDate,
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

    // Handle envelopes without linked accounts (for users who don't use accounts)
    final unlinkedEnvelopes = envelopes
        .where((e) => e.linkedAccountId == null || e.linkedAccountId!.isEmpty)
        .toList();

    if (unlinkedEnvelopes.isNotEmpty) {

      final unlinkedEnvProjections = <EnvelopeProjection>[];
      double unlinkedAssignedTotal = 0;

      for (final env in unlinkedEnvelopes) {
        if (scenario?.envelopeEnabled[env.id] == false) {
          continue;
        }

        double projectedEnvBalance =
            envelopeBalances[env.id] ?? env.currentAmount;

        if (scenario?.envelopeOverrides.containsKey(env.id) == true) {
          projectedEnvBalance = scenario!.envelopeOverrides[env.id]!;
        }

        unlinkedAssignedTotal += projectedEnvBalance;

        // Calculate target achievement metrics
        final targetAmount = env.targetAmount ?? 0;
        final hasTarget = targetAmount > 0;
        final willMeetTarget = projectedEnvBalance >= targetAmount;
        final targetDate = env.targetDate;
        final targetAchievedDate = envelopeTargetAchievedDate[env.id];

        // Calculate overachievement
        double? overachievementAmount;
        if (hasTarget && willMeetTarget) {
          overachievementAmount = projectedEnvBalance - targetAmount;
        }

        // Calculate days until target achieved (from now)
        int? daysUntilTarget;
        if (targetAchievedDate != null) {
          daysUntilTarget = targetAchievedDate.difference(now).inDays;
        }

        // Calculate days before/after target date when achieved
        int? daysBeforeTargetDate;
        if (targetDate != null && targetAchievedDate != null) {
          daysBeforeTargetDate = targetDate.difference(targetAchievedDate).inDays;
        }

        if (hasTarget) {
          if (targetDate != null) {
          }
          if (targetAchievedDate != null) {
            if (daysBeforeTargetDate != null) {
              if (daysBeforeTargetDate > 0) {
              } else if (daysBeforeTargetDate < 0) {
              } else {
              }
            }
            if (overachievementAmount != null && overachievementAmount > 0) {
            }
          } else if (willMeetTarget) {
          } else {
          }
        }

        unlinkedEnvProjections.add(
          EnvelopeProjection(
            envelopeId: env.id,
            envelopeName: env.name,
            emoji: env.emoji,
            iconType: env.iconType,
            iconValue: env.iconValue,
            currentAmount: env.currentAmount,
            projectedAmount: projectedEnvBalance,
            targetAmount: targetAmount,
            hasTarget: hasTarget,
            willMeetTarget: willMeetTarget,
            targetDate: targetDate,
            targetAchievedDate: targetAchievedDate,
            overachievementAmount: overachievementAmount,
            daysUntilTarget: daysUntilTarget,
            daysBeforeTargetDate: daysBeforeTargetDate,
          ),
        );
      }

      // Create a virtual "Unlinked" account projection to hold these envelopes
      if (unlinkedEnvProjections.isNotEmpty) {
        accountProjections['__unlinked__'] = AccountProjection(
          accountId: '__unlinked__',
          accountName: 'Unlinked Envelopes',
          projectedBalance: unlinkedAssignedTotal,
          assignedAmount: unlinkedAssignedTotal,
          availableAmount: 0, // No "available" money for unlinked envelopes
          envelopeProjections: unlinkedEnvProjections,
        );

        totalAssigned += unlinkedAssignedTotal;
      }
    }


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

    final payDays = <DateTime>[];

    if (frequency == 'monthly') {
      if (settings.payDayOfMonth == null) {
        return payDays;
      }

      DateTime current;

      // Prefer nextPayDate over lastPayDate for accuracy
      if (settings.nextPayDate != null) {
        current = settings.nextPayDate!;

        // If nextPayDate is in the past, move to next month
        if (current.isBefore(start)) {
          current = _clampDate(
            start.year,
            start.month,
            settings.payDayOfMonth!,
          );
          if (current.isBefore(start)) {
            current = _clampDate(
              start.year,
              start.month + 1,
              settings.payDayOfMonth!,
            );
          }
        }
      } else if (settings.lastPayDate != null) {
        // Fallback to lastPayDate if nextPayDate not set
        current = _clampDate(
          settings.lastPayDate!.year,
          settings.lastPayDate!.month,
          settings.payDayOfMonth!,
        );

        // If this pay date is before or equal to last pay date, move to next month
        if (!current.isAfter(settings.lastPayDate!)) {
          current = _clampDate(
            current.year,
            current.month + 1,
            settings.payDayOfMonth!,
          );
        } else {
        }
      } else {
        // No reference date at all - start from current month
        current = _clampDate(start.year, start.month, settings.payDayOfMonth!);
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
      DateTime current;

      // Prefer nextPayDate
      if (settings.nextPayDate != null) {
        current = settings.nextPayDate!;
      } else if (settings.lastPayDate != null) {
        current = settings.lastPayDate!.add(const Duration(days: 14));
      } else {
        return payDays;
      }

      while (current.isBefore(start)) {
        current = current.add(const Duration(days: 14));
      }

      while (!current.isAfter(end)) {
        payDays.add(current);
        current = current.add(const Duration(days: 14));
      }
    } else if (frequency == 'weekly') {
      DateTime current;

      // Prefer nextPayDate
      if (settings.nextPayDate != null) {
        current = settings.nextPayDate!;
      } else if (settings.lastPayDate != null) {
        current = settings.lastPayDate!.add(const Duration(days: 7));
      } else {
        return payDays;
      }

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

  /// Generate occurrences for temporary income/expense
  static List<DateTime> _getTemporaryOccurrences(
    TemporaryEnvelope temp,
    DateTime start,
    DateTime end,
  ) {
    final occurrences = <DateTime>[];

    // One-time item
    if (temp.isOneTime) {
      if (temp.startDate.isAfter(start) &&
          !temp.startDate.isAfter(end)) {
        occurrences.add(temp.startDate);
      }
      return occurrences;
    }

    // Recurring item
    var current = temp.startDate;

    // Fast forward to start if needed
    while (current.isBefore(start)) {
      current = _getNextTemporaryOccurrence(current, temp.frequency!);
    }

    // Add occurrences within range
    while (!current.isAfter(end)) {
      // Check if within end date (if specified)
      if (temp.endDate != null && current.isAfter(temp.endDate!)) {
        break;
      }

      if (!current.isBefore(start)) {
        occurrences.add(current);
      }

      current = _getNextTemporaryOccurrence(current, temp.frequency!);
    }

    return occurrences;
  }

  /// Calculate next occurrence for temporary item based on frequency
  static DateTime _getNextTemporaryOccurrence(
    DateTime current,
    String frequency,
  ) {
    switch (frequency) {
      case 'weekly':
        return current.add(const Duration(days: 7));
      case 'biweekly':
        return current.add(const Duration(days: 14));
      case 'monthly':
        return _clampDate(current.year, current.month + 1, current.day);
      default:
        return current.add(const Duration(days: 7)); // Default to weekly
    }
  }
}
