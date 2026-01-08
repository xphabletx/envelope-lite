import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/envelope.dart';
import '../models/pay_day_settings.dart';
import '../services/envelope_repo.dart';
import '../services/account_repo.dart';
import '../services/scheduled_payment_repo.dart';

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
  Map<String, double> contributionAmounts = {}; // Dollar amounts, not percentages
  Map<String, double> envelopeBaselines = {}; // Detected cashflow baselines
  double velocityPercentage = 0.0; // Slider: -100 to +100 (0 is baseline)

  // Available Funds State
  double accountBalance = 0.0;
  double cashflowReserve = 0.0;
  double autopilotCoverage = 0.0;
  double availableForBoost = 0.0;

  // Simulation State
  Map<String, DateTime> virtualReachDates = {};
  Map<String, bool> onTrackStatus = {};

  // Single-envelope specific logic from target_screen.dart
  bool isSavingGoal = true; // From legacy 'TargetType'
  DateTime? customTargetDate;

  /// Calculates how much is needed per month to hit a specific date
  double calculateRequiredMonthly(Envelope envelope, DateTime targetDate) {
    final remaining = (envelope.targetAmount ?? 0) - envelope.currentAmount;
    if (remaining <= 0) return 0;

    final months = (targetDate.difference(DateTime.now()).inDays / 30.44);
    return months > 0 ? remaining / months : remaining;
  }

  /// Update the envelope settings in the repo (The 'Save' action)
  Future<void> saveTargetSettings(String envelopeId, double amount, DateTime? date) async {
    await envelopeRepo.updateEnvelope(
      envelopeId: envelopeId,
      targetAmount: amount,
      targetDate: date,
    );
    notifyListeners();
  }

  /// Detect baseline monthly speed for selected envelopes
  Future<void> calculateBaselines(List<Envelope> selectedEnvelopes) async {
    envelopeBaselines.clear();
    cashflowReserve = 0.0;

    for (var envelope in selectedEnvelopes) {
      double speed = 0.0;

      // Priority 1: Use cashflow if enabled
      if (envelope.cashFlowEnabled && (envelope.cashFlowAmount ?? 0) > 0) {
        speed = envelope.cashFlowAmount!;
        cashflowReserve += speed;
      }

      envelopeBaselines[envelope.id] = speed;
      contributionAmounts[envelope.id] = speed; // Initialize to baseline
    }

    await refreshAvailableFunds();
    _runSimulations();
    notifyListeners();
  }

  /// The new Velocity Engine
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

  /// Autopilot Preparedness Check
  /// Formula: availableForBoost = accountBalance - cashflowReserve - autopilotCoverage
  Future<void> refreshAvailableFunds() async {
    debugPrint('[HorizonController] ======== REFRESH AVAILABLE FUNDS START ========');

    try {
      // 1. Get account balance (available balance from the special envelope)
      final envelopes = await envelopeRepo.envelopesStream().first;
      final accounts = await accountRepo.accountsStream().first;
      final userAccounts = accounts.where((a) => !a.id.startsWith('_')).toList();

      accountBalance = 0.0;
      if (userAccounts.isNotEmpty) {
        final defaultAccount = userAccounts.firstWhere(
          (a) => a.isDefault,
          orElse: () => userAccounts.first,
        );

        // Find the available balance envelope (ID pattern: _account_available_{accountId})
        final availableEnvelopeId = '_account_available_${defaultAccount.id}';
        final availableEnvelope = envelopes.firstWhere(
          (e) => e.id == availableEnvelopeId,
          orElse: () => Envelope(
            id: availableEnvelopeId,
            name: 'Available',
            userId: envelopeRepo.currentUserId,
            currentAmount: 0,
          ),
        );

        accountBalance = availableEnvelope.currentAmount;
      }
      debugPrint('[HorizonController] Account balance: $accountBalance');

      // 2. cashflowReserve is already calculated in calculateBaselines
      debugPrint('[HorizonController] Cashflow reserve: $cashflowReserve');

      // 3. Calculate autopilot coverage (upcoming scheduled payments)
      await _calculateAutopilotCoverage();
      debugPrint('[HorizonController] Autopilot coverage: $autopilotCoverage');

      // 4. Calculate available funds
      availableForBoost = accountBalance - cashflowReserve - autopilotCoverage;
      if (availableForBoost < 0) availableForBoost = 0.0;

      debugPrint('[HorizonController] Available for boost: $availableForBoost');
      debugPrint('[HorizonController] ======== REFRESH AVAILABLE FUNDS END ========');
    } catch (e, stack) {
      debugPrint('[HorizonController] ERROR refreshing funds: $e');
      debugPrint('[HorizonController] Stack: $stack');
    }
  }

  /// Calculate how much is needed for upcoming autopilot payments
  Future<void> _calculateAutopilotCoverage() async {
    autopilotCoverage = 0.0;

    try {
      // Get pay day settings to determine next pay day
      final payDayBox = Hive.box<PayDaySettings>('payDaySettings');
      final settings = payDayBox.get(envelopeRepo.currentUserId);

      if (settings == null) {
        debugPrint('[HorizonController] No pay day settings - skipping autopilot');
        return;
      }

      // Determine next pay day
      DateTime? nextPayDay = settings.nextPayDate;
      if (nextPayDay == null && settings.lastPayDate != null) {
        final lastPayDate = settings.lastPayDate!;
        final frequency = settings.payFrequency;

        // Calculate next pay day based on frequency
        switch (frequency.toLowerCase()) {
          case 'weekly':
            nextPayDay = lastPayDate.add(const Duration(days: 7));
            break;
          case 'biweekly':
            nextPayDay = lastPayDate.add(const Duration(days: 14));
            break;
          case 'semimonthly':
            nextPayDay = lastPayDate.add(const Duration(days: 15));
            break;
          case 'monthly':
            nextPayDay = DateTime(
              lastPayDate.month == 12 ? lastPayDate.year + 1 : lastPayDate.year,
              lastPayDate.month == 12 ? 1 : lastPayDate.month + 1,
              lastPayDate.day,
            );
            break;
          default:
            nextPayDay = lastPayDate.add(const Duration(days: 30));
        }
      }

      if (nextPayDay == null) {
        debugPrint('[HorizonController] Could not determine next pay day');
        return;
      }

      // Get scheduled payments due before next pay day
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final nextPayDayNormalized = DateTime(nextPayDay.year, nextPayDay.month, nextPayDay.day);

      final allPayments = await scheduledRepo.scheduledPaymentsStream.first;
      final envelopes = await envelopeRepo.envelopesStream().first;

      debugPrint('[HorizonController] Checking ${allPayments.length} scheduled payments');

      for (final payment in allPayments) {
        final paymentDate = DateTime(
          payment.nextDueDate.year,
          payment.nextDueDate.month,
          payment.nextDueDate.day,
        );

        // Include payments due after today and before next pay day
        if (paymentDate.isAfter(today) && !paymentDate.isAfter(nextPayDayNormalized)) {
          // Check if envelope has sufficient balance
          if (payment.envelopeId != null) {
            final envelope = envelopes.firstWhere(
              (e) => e.id == payment.envelopeId,
              orElse: () => Envelope(
                id: payment.envelopeId!,
                name: '',
                userId: envelopeRepo.currentUserId,
                currentAmount: 0,
              ),
            );

            // If envelope doesn't have enough, add to autopilot coverage
            if (envelope.currentAmount < payment.amount) {
              final shortfall = payment.amount - envelope.currentAmount;
              autopilotCoverage += shortfall;
              debugPrint('[HorizonController]   "${payment.name}": shortfall \$$shortfall');
            }
          }
        }
      }
    } catch (e, stack) {
      debugPrint('[HorizonController] ERROR calculating autopilot: $e');
      debugPrint('[HorizonController] Stack: $stack');
    }
  }

  /// Run simulations to calculate virtual reach dates and on-track status
  void _runSimulations() {
    virtualReachDates.clear();
    onTrackStatus.clear();

    for (var id in selectedEnvelopeIds) {
      // Placeholders - will be calculated when we have the actual envelope data
      virtualReachDates[id] = DateTime.now();
      onTrackStatus[id] = true;
    }
  }

  /// Calculate reach date for a specific envelope
  DateTime calculateReachDate(Envelope envelope) {
    final contribution = contributionAmounts[envelope.id] ?? 0.0;
    final remaining = (envelope.targetAmount ?? 0) - envelope.currentAmount;

    if (remaining <= 0 || contribution <= 0) {
      return DateTime.now();
    }

    final monthsNeeded = remaining / contribution;
    final daysNeeded = (monthsNeeded * 30.44).round();

    return DateTime.now().add(Duration(days: daysNeeded));
  }

  /// Check if envelope is on track to reach target by target date
  bool isOnTrack(Envelope envelope) {
    if (envelope.targetDate == null) return true;

    final reachDate = calculateReachDate(envelope);
    return !reachDate.isAfter(envelope.targetDate!);
  }
}
