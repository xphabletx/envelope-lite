import 'package:flutter/material.dart';
import '../models/envelope.dart';
import '../services/envelope_repo.dart';
import '../services/account_repo.dart';
import '../services/scheduled_payment_repo.dart'; // NEW
import '../utils/target_helper.dart';

class HorizonController extends ChangeNotifier {
  final EnvelopeRepo envelopeRepo;
  final AccountRepo accountRepo;
  final ScheduledPaymentRepo scheduledRepo;

  HorizonController({
    required this.envelopeRepo,
    required this.accountRepo,
    required this.scheduledRepo,
  });

  // --- State Variables ---
  Set<String> selectedEnvelopeIds = {};
  Map<String, double> contributionAmounts =
      {}; // Now using raw amounts, not percentages
  Map<String, double> envelopeBaselines = {};
  double velocityPercentage = 0.0; // Slider: -100 to +100 (0 is baseline)

  // Available Funds State
  double accountBalance = 0.0;
  double cashflowReserve = 0.0;
  double autopilotCoverage = 0.0;
  double availableForBoost = 0.0;

  // Simulation State
  Map<String, DateTime> virtualReachDates = {};
  Map<String, bool> onTrackStatus = {};

// NEW: Single-envelope specific logic from target_screen.dart
  bool isSavingGoal = true; // From legacy 'TargetType'
  DateTime? customTargetDate;
  
  /// Ported from target_screen.dart: Calculates how much is needed 
  /// per month to hit a specific date
  double calculateRequiredMonthly(Envelope envelope, DateTime targetDate) {
    final remaining = (envelope.targetAmount ?? 0) - envelope.currentAmount;
    if (remaining <= 0) return 0;
    
    final months = (targetDate.difference(DateTime.now()).inDays / 30.44);
    return months > 0 ? remaining / months : remaining;
  }

  /// NEW: Update the envelope settings in the repo (The 'Save' action)
  Future<void> saveTargetSettings(String envelopeId, double amount, DateTime? date) async {
    await envelopeRepo.updateEnvelope(
      envelopeId: envelopeId,
      targetAmount: amount,
      targetDate: date,
    );
    notifyListeners();
  }
}

  /// Logic: Detect baseline monthly speed for selected envelopes
  void calculateBaselines(List<Envelope> selectedEnvelopes) {
    envelopeBaselines.clear();
    for (var envelope in selectedEnvelopes) {
      double speed = 0.0;

      if (envelope.cashFlowEnabled && (envelope.cashFlowAmount ?? 0) > 0) {
        speed = envelope.cashFlowAmount!; // Priority 1: Cash Flow
      } else {
        // Priority 2: Most recent external inflow
        final txs = envelopeRepo.getTransactionsForEnvelopeSync(envelope.id);
        txs.sort((a, b) => b.date.compareTo(a.date));
        final recentInflow = txs.firstWhere(
          (tx) =>
              tx.impact == TransactionImpact.external &&
              tx.direction == TransactionDirection.inflow,
          orElse: () => null,
        );
        speed = recentInflow?.amount ?? 0.0;
      }
      envelopeBaselines[envelope.id] = speed;
    }
    notifyListeners();
  }

  /// Logic: The new Velocity Engine
  /// Applies a percentage increase/decrease to the detected baseline
  void applyVelocityAdjustment(double percentChange) {
    velocityPercentage = percentChange;
    final multiplier = 1 + (percentChange / 100);

    for (var id in selectedEnvelopeIds) {
      final baseline = envelopeBaselines[id] ?? 0.0;
      contributionAmounts[id] = baseline * multiplier;
    }
    _runSimulations();
    notifyListeners();
  }

  /// Logic: Autopilot Preparedness Check (NEW)
  /// Checks if the user actually has enough unassigned cash for upcoming bills
  Future<void> refreshAvailableFunds() async {
    // 1. Get real account balance
    // 2. Subtract sum of current cashflow strategy
    // 3. Subtract upcoming ScheduledPayments (autopilot)
    // 4. Update availableForBoost
    // ... Implementation detail will go here ...
    notifyListeners();
  }

  void _runSimulations() {
    // Ported from multi_target_screen.dart
    // Calculates virtualReachDates based on contributionAmounts
  }
}
