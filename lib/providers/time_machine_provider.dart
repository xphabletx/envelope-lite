// lib/providers/time_machine_provider.dart
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/projection.dart';
import '../models/envelope.dart';
import '../models/account.dart';
import '../models/transaction.dart';

class TimeMachineProvider extends ChangeNotifier {
  bool _isActive = false;
  DateTime? _futureDate;
  DateTime? _entryDate; // Date when user entered time machine
  ProjectionResult? _projectionData;

  // Humorous sci-fi error messages
  static final List<String> _blockedMessages = [
    '⏰ Time Paradox Detected! The Time Machine forbids intentional paradoxes.',
    '🚫 Temporal Violation! You cannot alter events that haven\'t occurred yet.',
    '⚠️ Causality Error! Return to the present to make changes.',
    '🔒 Timeline Protected! Modifications disabled in projection mode.',
  ];

  bool get isActive => _isActive;
  DateTime? get futureDate => _futureDate;
  DateTime? get entryDate => _entryDate;
  ProjectionResult? get projectionData => _projectionData;

  /// Enter Time Machine mode with projection data
  void enterTimeMachine({
    required DateTime targetDate,
    required ProjectionResult projection,
  }) {
    debugPrint('[TimeMachine] ========================================');
    debugPrint('[TimeMachine] ENTERING TIME MACHINE MODE');
    debugPrint('[TimeMachine] Entry Date: ${DateTime.now()}');
    debugPrint('[TimeMachine] Target Date: $targetDate');
    debugPrint('[TimeMachine] Account Projections: ${projection.accountProjections.length}');
    debugPrint('[TimeMachine] Timeline Events: ${projection.timeline.length}');
    debugPrint('[TimeMachine] ========================================');

    _isActive = true;
    _entryDate = DateTime.now(); // Record when user entered time machine
    _futureDate = targetDate;
    _projectionData = projection;
    notifyListeners();

    debugPrint('[TimeMachine] ✅ Time Machine activated, listeners notified');
  }

  /// Exit Time Machine mode and return to present
  void exitTimeMachine() {
    debugPrint('[TimeMachine] ========================================');
    debugPrint('[TimeMachine] EXITING TIME MACHINE MODE');
    debugPrint('[TimeMachine] Returning to present');
    debugPrint('[TimeMachine] ========================================');

    _isActive = false;
    _entryDate = null;
    _futureDate = null;
    _projectionData = null;
    notifyListeners();

    debugPrint('[TimeMachine] ✅ Time Machine deactivated, listeners notified');
  }

  /// Get projected balance for an envelope
  double? getProjectedEnvelopeBalance(String envelopeId) {
    if (!_isActive || _projectionData == null) {
      debugPrint('[TimeMachine] getProjectedEnvelopeBalance($envelopeId): inactive');
      return null;
    }

    // Search through all account projections for this envelope
    for (final accountProj in _projectionData!.accountProjections.values) {
      for (final envProj in accountProj.envelopeProjections) {
        if (envProj.envelopeId == envelopeId) {
          debugPrint('[TimeMachine] ✅ Found projection for envelope $envelopeId:');
          debugPrint('[TimeMachine]   Current: ${envProj.currentAmount}');
          debugPrint('[TimeMachine]   Projected: ${envProj.projectedAmount}');
          debugPrint('[TimeMachine]   Change: ${envProj.changeAmount}');
          return envProj.projectedAmount;
        }
      }
    }

    debugPrint('[TimeMachine] ⚠️ No projection found for envelope $envelopeId');
    return null;
  }

  /// Get projected balance for an account
  double? getProjectedAccountBalance(String accountId) {
    if (!_isActive || _projectionData == null) {
      debugPrint('[TimeMachine] getProjectedAccountBalance($accountId): inactive');
      return null;
    }

    final projection = _projectionData!.accountProjections[accountId];
    if (projection != null) {
      debugPrint('[TimeMachine] ✅ Found projection for account $accountId:');
      debugPrint('[TimeMachine]   Projected Balance: ${projection.projectedBalance}');
      debugPrint('[TimeMachine]   Assigned: ${projection.assignedAmount}');
      debugPrint('[TimeMachine]   Available: ${projection.availableAmount}');
      return projection.projectedBalance;
    }

    debugPrint('[TimeMachine] ⚠️ No projection found for account $accountId');
    return null;
  }

  /// Get "future transactions" for an envelope (scheduled payments that will execute)
  List<Transaction> getFutureTransactions(String envelopeId) {
    if (!_isActive || _projectionData == null) {
      debugPrint('[TimeMachine::EnvelopeDetail] getFutureTransactions($envelopeId): inactive');
      return [];
    }

    debugPrint('[TimeMachine::EnvelopeDetail] Getting future transactions for envelope $envelopeId');

    // Use the comprehensive getAllProjectedTransactions method, then filter by envelope
    final allProjected = getAllProjectedTransactions(includeTransfers: true);

    // Filter to this specific envelope
    final envelopeTransactions = allProjected.where((tx) => tx.envelopeId == envelopeId).toList();

    debugPrint('[TimeMachine::EnvelopeDetail] Returning ${envelopeTransactions.length} future transactions for envelope $envelopeId');
    return envelopeTransactions;
  }

  /// Build a modified envelope with projected balance
  Envelope getProjectedEnvelope(Envelope realEnvelope) {
    if (!_isActive) {
      debugPrint('[TimeMachine] getProjectedEnvelope(${realEnvelope.name}): inactive, returning real envelope');
      return realEnvelope;
    }

    final projectedBalance = getProjectedEnvelopeBalance(realEnvelope.id);
    if (projectedBalance == null) {
      debugPrint('[TimeMachine] getProjectedEnvelope(${realEnvelope.name}): no projection, returning real envelope');
      return realEnvelope;
    }

    debugPrint('[TimeMachine] ✅ Projecting envelope ${realEnvelope.name}: ${realEnvelope.currentAmount} → $projectedBalance');

    return Envelope(
      id: realEnvelope.id,
      name: realEnvelope.name,
      userId: realEnvelope.userId,
      currentAmount: projectedBalance,
      targetAmount: realEnvelope.targetAmount,
      targetDate: realEnvelope.targetDate,
      groupId: realEnvelope.groupId,
      emoji: realEnvelope.emoji,
      iconType: realEnvelope.iconType,
      iconValue: realEnvelope.iconValue,
      iconColor: realEnvelope.iconColor,
      subtitle: realEnvelope.subtitle,
      autoFillEnabled: realEnvelope.autoFillEnabled,
      autoFillAmount: realEnvelope.autoFillAmount,
      isShared: realEnvelope.isShared,
      linkedAccountId: realEnvelope.linkedAccountId,
    );
  }

  /// Build a modified account with projected balance
  Account getProjectedAccount(Account realAccount) {
    if (!_isActive) {
      debugPrint('[TimeMachine] getProjectedAccount(${realAccount.name}): inactive, returning real account');
      return realAccount;
    }

    final projectedBalance = getProjectedAccountBalance(realAccount.id);
    if (projectedBalance == null) {
      debugPrint('[TimeMachine] getProjectedAccount(${realAccount.name}): no projection, returning real account');
      return realAccount;
    }

    debugPrint('[TimeMachine] ✅ Projecting account ${realAccount.name}: ${realAccount.currentBalance} → $projectedBalance');

    return Account(
      id: realAccount.id,
      name: realAccount.name,
      currentBalance: projectedBalance,
      userId: realAccount.userId,
      emoji: realAccount.emoji,
      colorName: realAccount.colorName,
      createdAt: realAccount.createdAt,
      lastUpdated: realAccount.lastUpdated,
      isDefault: realAccount.isDefault,
      isShared: realAccount.isShared,
      workspaceId: realAccount.workspaceId,
      iconType: realAccount.iconType,
      iconValue: realAccount.iconValue,
      iconColor: realAccount.iconColor,
      accountType: realAccount.accountType,
      creditLimit: realAccount.creditLimit,
    );
  }

  /// Generate ALL projected transactions across all envelopes
  /// Includes pay days, auto-fills, scheduled payments, and optionally transfers
  List<Transaction> getAllProjectedTransactions({
    bool includeTransfers = true,
  }) {
    if (!_isActive || _projectionData == null) {
      debugPrint('[TimeMachine::Projection] getAllProjectedTransactions: inactive');
      return [];
    }

    debugPrint('[TimeMachine::Projection] ========================================');
    debugPrint('[TimeMachine::Projection] Generating ALL projected transactions');
    debugPrint('[TimeMachine::Projection] Total timeline events: ${_projectionData!.timeline.length}');
    debugPrint('[TimeMachine::Projection] Include transfers: $includeTransfers');
    debugPrint('[TimeMachine::Projection] ========================================');

    final futureTransactions = <Transaction>[];
    final now = DateTime.now();

    for (final event in _projectionData!.timeline) {
      // Only include events between now and future date
      if (event.date.isAfter(now) && event.date.isBefore(_futureDate!)) {

        // Determine transaction type based on event
        TransactionType txType;
        String description = event.description;

        if (event.type == 'transfer') {
          if (!includeTransfers) {
            debugPrint('[TimeMachine::Projection] ⏭️ Skipping transfer event: $description');
            continue;
          }
          txType = TransactionType.transfer;
        } else if (event.type == 'pay_day') {
          // Pay day is a deposit to the account
          txType = TransactionType.deposit;
          description = event.description; // Already set to "PAY DAY!"
        } else if (event.type == 'scheduled_payment') {
          txType = TransactionType.scheduledPayment;
          description = event.description; // Use scheduled payment name
        } else if (event.type == 'auto_fill') {
          // Auto-fill is a DEPOSIT to envelope from account (pay day auto-fill)
          txType = TransactionType.deposit;
          description = event.description; // Already formatted as "Auto-fill deposit from [Account Name]"
        } else if (event.type == 'account_auto_fill') {
          // Account auto-fill is a DEPOSIT to target account from default account
          txType = TransactionType.deposit;
          description = event.description; // Already formatted as "Auto-fill deposit from [Default Account]"
        } else if (event.type == 'envelope_auto_fill_withdrawal') {
          // Withdrawal from account for envelope auto-fill
          txType = TransactionType.withdrawal;
          description = event.description; // Already formatted as "[Envelope Name] - Withdrawal auto-fill"
        } else if (event.type == 'account_auto_fill_withdrawal') {
          // Withdrawal from default account for account-to-account auto-fill
          txType = TransactionType.withdrawal;
          description = event.description; // Already formatted as "[Account Name] - Withdrawal auto-fill"
        } else if (event.isCredit) {
          txType = TransactionType.deposit;
        } else {
          txType = TransactionType.withdrawal;
        }

        // Create synthetic transaction
        final tx = Transaction(
          id: 'future_${event.date.millisecondsSinceEpoch}_${event.envelopeId}',
          userId: '',
          envelopeId: event.envelopeId ?? '',
          type: txType,
          amount: event.amount,
          description: description,
          date: event.date,
          isFuture: true, // Mark as projected
        );

        futureTransactions.add(tx);
        debugPrint('[TimeMachine::Projection] ✅ Added: ${event.type} - $description on ${event.date}');
      }
    }

    // Sort by date descending (newest first)
    futureTransactions.sort((a, b) => b.date.compareTo(a.date));

    debugPrint('[TimeMachine::Projection] ========================================');
    debugPrint('[TimeMachine::Projection] Generated ${futureTransactions.length} projected transactions');
    debugPrint('[TimeMachine::Projection] ========================================');

    return futureTransactions;
  }

  /// Get projected transactions filtered by date range
  List<Transaction> getProjectedTransactionsForDateRange(
    DateTime start,
    DateTime end, {
    bool includeTransfers = true,
  }) {
    if (!_isActive || _projectionData == null) {
      debugPrint('[TimeMachine::Projection] getProjectedTransactionsForDateRange: inactive');
      return [];
    }

    debugPrint('[TimeMachine::Projection] ========================================');
    debugPrint('[TimeMachine::Projection] Getting projected transactions for date range');
    debugPrint('[TimeMachine::Projection] Start: $start');
    debugPrint('[TimeMachine::Projection] End: $end');
    debugPrint('[TimeMachine::Projection] Include transfers: $includeTransfers');
    debugPrint('[TimeMachine::Projection] ========================================');

    final allProjected = getAllProjectedTransactions(
      includeTransfers: includeTransfers,
    );

    final filtered = allProjected.where((tx) {
      return tx.date.isAfter(start.subtract(const Duration(milliseconds: 1))) &&
             tx.date.isBefore(end.add(const Duration(milliseconds: 1)));
    }).toList();

    debugPrint('[TimeMachine::Projection] Filtered to ${filtered.length} transactions in date range');
    return filtered;
  }

  /// Calculate projected account balances at a specific date in the timeline
  Map<String, double> getProjectedAccountBalancesAtDate(DateTime date) {
    if (!_isActive || _projectionData == null) {
      debugPrint('[TimeMachine::Projection] getProjectedAccountBalancesAtDate: inactive');
      return {};
    }

    debugPrint('[TimeMachine::Projection] ========================================');
    debugPrint('[TimeMachine::Projection] Calculating account balances at date: $date');
    debugPrint('[TimeMachine::Projection] ========================================');

    final balances = <String, double>{};

    // Get all events up to the target date
    final relevantEvents = _projectionData!.timeline.where((event) {
      return event.date.isBefore(date.add(const Duration(milliseconds: 1)));
    }).toList();

    debugPrint('[TimeMachine::Projection] Found ${relevantEvents.length} events before $date');

    // Start with current account balances from projection data
    for (final entry in _projectionData!.accountProjections.entries) {
      final accountId = entry.key;
      final projection = entry.value;

      // Start with the original balance
      double balance = projection.projectedBalance;

      // We need to reverse-calculate by subtracting future events
      // This is a simplified approach - in reality, we'd need to replay events
      // For now, just use the projected balance if date matches future date
      if (date.isAtSameMomentAs(_futureDate!)) {
        balances[accountId] = balance;
        debugPrint('[TimeMachine::Projection] Account $accountId at future date: $balance');
      } else {
        // For intermediate dates, we'd need more complex calculation
        // For now, return current balances
        balances[accountId] = projection.projectedBalance;
        debugPrint('[TimeMachine::Projection] Account $accountId (approximation): $balance');
      }
    }

    debugPrint('[TimeMachine::Projection] ========================================');
    debugPrint('[TimeMachine::Projection] Calculated ${balances.length} account balances');
    debugPrint('[TimeMachine::Projection] ========================================');

    return balances;
  }

  /// Check if modifications should be blocked (time machine is active)
  bool shouldBlockModifications() {
    final blocked = _isActive;
    if (blocked) {
      debugPrint('[TimeMachine::ReadOnly] ⛔ Modification blocked - Time Machine is active');
    }
    return blocked;
  }

  /// Get a humorous sci-fi themed error message for blocked actions
  String getBlockedActionMessage() {
    final random = math.Random();
    final message = _blockedMessages[random.nextInt(_blockedMessages.length)];
    debugPrint('[TimeMachine::ReadOnly] Blocked action message: $message');
    return message;
  }
}
