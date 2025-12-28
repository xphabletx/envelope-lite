// lib/providers/time_machine_provider.dart
import 'package:flutter/foundation.dart';
import '../models/projection.dart';
import '../models/envelope.dart';
import '../models/account.dart';
import '../models/transaction.dart';

class TimeMachineProvider extends ChangeNotifier {
  bool _isActive = false;
  DateTime? _futureDate;
  ProjectionResult? _projectionData;

  bool get isActive => _isActive;
  DateTime? get futureDate => _futureDate;
  ProjectionResult? get projectionData => _projectionData;

  /// Enter Time Machine mode with projection data
  void enterTimeMachine({
    required DateTime targetDate,
    required ProjectionResult projection,
  }) {
    debugPrint('[TimeMachine] ========================================');
    debugPrint('[TimeMachine] ENTERING TIME MACHINE MODE');
    debugPrint('[TimeMachine] Target Date: $targetDate');
    debugPrint('[TimeMachine] Account Projections: ${projection.accountProjections.length}');
    debugPrint('[TimeMachine] Timeline Events: ${projection.timeline.length}');
    debugPrint('[TimeMachine] ========================================');

    _isActive = true;
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
      debugPrint('[TimeMachine] getFutureTransactions($envelopeId): inactive');
      return [];
    }

    debugPrint('[TimeMachine] Getting future transactions for envelope $envelopeId');
    debugPrint('[TimeMachine] Total timeline events: ${_projectionData!.timeline.length}');

    final futureTransactions = <Transaction>[];

    // Convert projection events into transaction objects
    final now = DateTime.now();
    for (final event in _projectionData!.timeline) {
      // Only show events between now and future date
      if (event.date.isAfter(now) &&
          event.date.isBefore(_futureDate!) &&
          event.envelopeId == envelopeId) {

        // Determine transaction type based on event
        TransactionType txType;
        if (event.isCredit) {
          txType = TransactionType.deposit;
        } else {
          txType = TransactionType.withdrawal;
        }

        // Create synthetic transaction
        final tx = Transaction(
          id: 'future_${event.date.millisecondsSinceEpoch}_$envelopeId',
          userId: '',
          envelopeId: envelopeId,
          type: txType,
          amount: event.amount,
          description: '${event.description} (Projected)',
          date: event.date,
          isFuture: true, // Mark as future/projected
        );

        futureTransactions.add(tx);
        debugPrint('[TimeMachine] ✅ Added future transaction: ${event.description} on ${event.date}');
      }
    }

    // Sort by date descending (newest first)
    futureTransactions.sort((a, b) => b.date.compareTo(a.date));

    debugPrint('[TimeMachine] Returning ${futureTransactions.length} future transactions');
    return futureTransactions;
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
}
