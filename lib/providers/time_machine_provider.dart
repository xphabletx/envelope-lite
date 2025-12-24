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
    _isActive = true;
    _futureDate = targetDate;
    _projectionData = projection;
    notifyListeners();
  }

  /// Exit Time Machine mode and return to present
  void exitTimeMachine() {
    _isActive = false;
    _futureDate = null;
    _projectionData = null;
    notifyListeners();
  }

  /// Get projected balance for an envelope
  double? getProjectedEnvelopeBalance(String envelopeId) {
    if (!_isActive || _projectionData == null) return null;

    // Search through all account projections for this envelope
    for (final accountProj in _projectionData!.accountProjections.values) {
      for (final envProj in accountProj.envelopeProjections) {
        if (envProj.envelopeId == envelopeId) {
          return envProj.projectedAmount;
        }
      }
    }
    return null;
  }

  /// Get projected balance for an account
  double? getProjectedAccountBalance(String accountId) {
    if (!_isActive || _projectionData == null) return null;

    return _projectionData!.accountProjections[accountId]?.projectedBalance;
  }

  /// Get "future transactions" for an envelope (scheduled payments that will execute)
  List<Transaction> getFutureTransactions(String envelopeId) {
    if (!_isActive || _projectionData == null) return [];

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
      }
    }

    // Sort by date descending (newest first)
    futureTransactions.sort((a, b) => b.date.compareTo(a.date));

    return futureTransactions;
  }

  /// Build a modified envelope with projected balance
  Envelope getProjectedEnvelope(Envelope realEnvelope) {
    if (!_isActive) return realEnvelope;

    final projectedBalance = getProjectedEnvelopeBalance(realEnvelope.id);
    if (projectedBalance == null) return realEnvelope;

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
    if (!_isActive) return realAccount;

    final projectedBalance = getProjectedAccountBalance(realAccount.id);
    if (projectedBalance == null) return realAccount;

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
    );
  }
}
