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

    _isActive = true;
    _entryDate = DateTime.now(); // Record when user entered time machine
    _futureDate = targetDate;
    _projectionData = projection;
    notifyListeners();

  }

  /// Exit Time Machine mode and return to present
  void exitTimeMachine() {

    _isActive = false;
    _entryDate = null;
    _futureDate = null;
    _projectionData = null;
    notifyListeners();

  }

  /// Get projected balance for an envelope
  double? getProjectedEnvelopeBalance(String envelopeId) {
    if (!_isActive || _projectionData == null) {
      // Silent when inactive (this is expected during normal operation)
      return null;
    }

    // Search through all account projections for this envelope
    for (final accountProj in _projectionData!.accountProjections.values) {
      for (final envProj in accountProj.envelopeProjections) {
        if (envProj.envelopeId == envelopeId) {
          // Success case - silenced to reduce log noise
          return envProj.projectedAmount;
        }
      }
    }

    // Only log if we're active but can't find the projection (this might indicate an error)
    return null;
  }

  /// Get the date when an envelope's target was achieved (if it has been)
  DateTime? getTargetAchievedDate(String envelopeId) {
    if (!_isActive || _projectionData == null) {
      return null;
    }

    // Search through all account projections for this envelope
    for (final accountProj in _projectionData!.accountProjections.values) {
      for (final envProj in accountProj.envelopeProjections) {
        if (envProj.envelopeId == envelopeId) {
          return envProj.targetAchievedDate;
        }
      }
    }

    return null;
  }

  /// Get projected balance for an account
  double? getProjectedAccountBalance(String accountId) {
    if (!_isActive || _projectionData == null) {
      // Silent when inactive (this is expected during normal operation)
      return null;
    }

    final projection = _projectionData!.accountProjections[accountId];
    if (projection != null) {
      // Success case - silenced to reduce log noise
      return projection.projectedBalance;
    }

    // Only log if we're active but can't find the projection (this might indicate an error)
    return null;
  }

  /// Get "future transactions" for an envelope (scheduled payments that will execute)
  List<Transaction> getFutureTransactions(String envelopeId) {
    if (!_isActive || _projectionData == null) {
      // Silent when inactive (this is expected during normal operation)
      return [];
    }

    // Use the comprehensive getAllProjectedTransactions method, then filter by envelope
    final allProjected = getAllProjectedTransactions(includeTransfers: true);

    // Filter to this specific envelope
    final envelopeTransactions = allProjected.where((tx) => tx.envelopeId == envelopeId).toList();

    // Success case - silenced to reduce log noise
    return envelopeTransactions;
  }

  /// Build a modified envelope with projected balance
  Envelope getProjectedEnvelope(Envelope realEnvelope) {
    if (!_isActive) {
      // Silent when inactive (this is expected during normal operation)
      return realEnvelope;
    }

    final projectedBalance = getProjectedEnvelopeBalance(realEnvelope.id);
    if (projectedBalance == null) {
      // Silent when no projection exists (this is expected during normal operation)
      return realEnvelope;
    }

    // Success case - silenced to reduce log noise

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
      cashFlowEnabled: realEnvelope.cashFlowEnabled,
      cashFlowAmount: realEnvelope.cashFlowAmount,
      isShared: realEnvelope.isShared,
      linkedAccountId: realEnvelope.linkedAccountId,
    );
  }

  /// Build a modified account with projected balance
  Account getProjectedAccount(Account realAccount) {
    if (!_isActive) {
      return realAccount;
    }

    final projectedBalance = getProjectedAccountBalance(realAccount.id);
    if (projectedBalance == null) {
      return realAccount;
    }


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
      return [];
    }


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
      }
    }

    // Sort by date descending (newest first)
    futureTransactions.sort((a, b) => b.date.compareTo(a.date));


    return futureTransactions;
  }

  /// Get projected transactions filtered by date range
  List<Transaction> getProjectedTransactionsForDateRange(
    DateTime start,
    DateTime end, {
    bool includeTransfers = true,
  }) {
    if (!_isActive || _projectionData == null) {
      return [];
    }


    final allProjected = getAllProjectedTransactions(
      includeTransfers: includeTransfers,
    );

    final filtered = allProjected.where((tx) {
      return tx.date.isAfter(start.subtract(const Duration(milliseconds: 1))) &&
             tx.date.isBefore(end.add(const Duration(milliseconds: 1)));
    }).toList();

    return filtered;
  }

  /// Calculate projected account balances at a specific date in the timeline
  Map<String, double> getProjectedAccountBalancesAtDate(DateTime date) {
    if (!_isActive || _projectionData == null) {
      return {};
    }


    final balances = <String, double>{};

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
      } else {
        // For intermediate dates, we'd need more complex calculation
        // For now, return current balances
        balances[accountId] = projection.projectedBalance;
      }
    }


    return balances;
  }

  /// Check if modifications should be blocked (time machine is active)
  bool shouldBlockModifications() {
    final blocked = _isActive;
    if (blocked) {
    }
    return blocked;
  }

  /// Get a humorous sci-fi themed error message for blocked actions
  String getBlockedActionMessage() {
    final random = math.Random();
    final message = _blockedMessages[random.nextInt(_blockedMessages.length)];
    return message;
  }
}
