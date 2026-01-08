// lib/providers/pay_day_cockpit_provider.dart
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/envelope.dart';
import '../models/envelope_group.dart';
import '../models/account.dart';
import '../models/pay_day_settings.dart';
import '../models/scheduled_payment.dart';
import '../services/envelope_repo.dart';
import '../services/group_repo.dart';
import '../services/account_repo.dart';
import '../services/scheduled_payment_repo.dart';

enum CockpitPhase {
  amountEntry,
  strategyReview,
  stuffingExecution,
  success,
}

enum StuffingStage {
  silver, // Cash flow allocations
  gold,   // Boost allocations
  complete,
}

class PayDayCockpitProvider extends ChangeNotifier {
  final EnvelopeRepo envelopeRepo;
  final GroupRepo groupRepo;
  final AccountRepo accountRepo;
  final ScheduledPaymentRepo scheduledPaymentRepo;
  final String userId;

  PayDayCockpitProvider({
    required this.envelopeRepo,
    required this.groupRepo,
    required this.accountRepo,
    required this.scheduledPaymentRepo,
    required this.userId,
  });

  // Phase management
  CockpitPhase _currentPhase = CockpitPhase.amountEntry;
  CockpitPhase get currentPhase => _currentPhase;

  // Mode detection
  bool _isAccountMode = false;
  bool get isAccountMode => _isAccountMode;
  String? _defaultAccountId;
  String? get defaultAccountId => _defaultAccountId;
  Account? _defaultAccount;
  Account? get defaultAccount => _defaultAccount;

  // Amount Entry (Phase 1)
  double _externalInflow = 0.0;
  double get externalInflow => _externalInflow;

  // Strategy Review (Phase 2)
  List<Envelope> _allEnvelopes = [];
  List<EnvelopeGroup> _allBinders = [];
  final Map<String, double> _allocations = {}; // envelopeId -> amount
  final Set<String> _temporarilyAddedBinderIds = {};

  List<Envelope> get allEnvelopes => _allEnvelopes;
  List<EnvelopeGroup> get allBinders => _allBinders;
  Map<String, double> get allocations => _allocations;

  // Autopilot reserves (calculated from cash flow enabled items)
  double _autopilotReserve = 0.0;
  double get autopilotReserve => _autopilotReserve;

  // Autopilot upcoming payments (scheduled payments due before next pay day)
  double _autopilotUpcoming = 0.0;
  double get autopilotUpcoming => _autopilotUpcoming;
  final List<ScheduledPayment> _upcomingPayments = [];
  List<ScheduledPayment> get upcomingPayments => _upcomingPayments;
  final Map<String, bool> _autopilotPreparedness = {}; // envelopeId -> isPrepared
  Map<String, bool> get autopilotPreparedness => _autopilotPreparedness;

  double get availableFuel => _externalInflow - _autopilotReserve;
  double get unallocatedFuel => availableFuel - _manualAllocations;

  // Manual allocations (user-added stuffing beyond autopilot)
  double _manualAllocations = 0.0;
  double get manualAllocations => _manualAllocations;

  // Warning state
  bool get isOverAllocated => unallocatedFuel < 0;
  bool get isDippingIntoReserves => (_autopilotReserve + _manualAllocations) > _externalInflow;

  // Stuffing Execution (Phase 3)
  int _currentStuffingBinderIndex = -1;
  int _currentStuffingEnvelopeIndex = -1;
  final Map<String, double> _stuffingProgress = {}; // envelopeId -> stuffed amount
  int _currentEnvelopeAnimationIndex = -1; // Current envelope being animated
  StuffingStage _stuffingStage = StuffingStage.silver;
  double _accountDepositProgress = 0.0; // Track visual progress of account deposit animation

  int get currentStuffingBinderIndex => _currentStuffingBinderIndex;
  int get currentStuffingEnvelopeIndex => _currentStuffingEnvelopeIndex;
  Map<String, double> get stuffingProgress => _stuffingProgress;
  int get currentEnvelopeAnimationIndex => _currentEnvelopeAnimationIndex;
  StuffingStage get stuffingStage => _stuffingStage;
  double get accountDepositProgress => _accountDepositProgress;

  // Success (Phase 4)
  List<EnvelopeHorizonImpact> _topHorizons = [];
  List<EnvelopeHorizonImpact> get topHorizons => _topHorizons;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  // ============================================================================
  // INITIALIZATION
  // ============================================================================

  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Check if user has any accounts (determines mode)
      final accounts = await accountRepo.accountsStream().first;
      final userAccounts = accounts.where((a) => !a.id.startsWith('_')).toList();
      _isAccountMode = userAccounts.isNotEmpty;

      // Find default account if in account mode
      if (_isAccountMode) {
        final defaultAccount = userAccounts.firstWhere(
          (a) => a.isDefault,
          orElse: () => userAccounts.first,
        );
        _defaultAccountId = defaultAccount.id;
        _defaultAccount = defaultAccount;
      }

      // Load PayDaySettings for expected pay amount pre-fill
      final payDayBox = Hive.box<PayDaySettings>('payDaySettings');
      final settings = payDayBox.get(userId);

      // Pre-fill expected pay amount if available
      if (settings?.expectedPayAmount != null && settings!.expectedPayAmount! > 0) {
        _externalInflow = settings.expectedPayAmount!;
      }

      // Load all envelopes and binders
      final envelopeBox = Hive.box<Envelope>('envelopes');
      _allEnvelopes = envelopeBox.values
          .where((e) =>
              e.userId == userId &&
              !e.id.startsWith('_account_available_'))
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      final groupBox = Hive.box<EnvelopeGroup>('groups');
      _allBinders = groupBox.values
          .where((g) => g.userId == userId)
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      // Initialize allocations with cash flow enabled envelopes
      _calculateAutopilotAllocations();

      // Calculate upcoming autopilot payments
      await _calculateUpcomingAutopilotPayments();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to initialize: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  void _calculateAutopilotAllocations() {
    _allocations.clear();
    _autopilotReserve = 0.0;

    for (final env in _allEnvelopes) {
      if (env.cashFlowEnabled && env.cashFlowAmount != null && env.cashFlowAmount! > 0) {
        _allocations[env.id] = env.cashFlowAmount!;
        _autopilotReserve += env.cashFlowAmount!;
      }
    }
  }

  Future<void> _calculateUpcomingAutopilotPayments() async {
    _upcomingPayments.clear();
    _autopilotUpcoming = 0.0;
    _autopilotPreparedness.clear();

    try {
      // Get pay day settings to determine next pay day
      final payDayBox = Hive.box<PayDaySettings>('payDaySettings');
      final settings = payDayBox.get(userId);

      if (settings == null || settings.lastPayDate == null) {
        return; // No pay settings configured yet
      }

      final DateTime lastPayDate = settings.lastPayDate!;
      final String frequency = settings.payFrequency;

      // Calculate next pay day based on frequency
      DateTime nextPayDay;
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

      final now = DateTime.now();

      // Get all scheduled payments
      final allPayments = await scheduledPaymentRepo.scheduledPaymentsStream.first;

      // Filter payments due before next pay day
      for (final payment in allPayments) {
        if (payment.nextDueDate.isBefore(nextPayDay) && payment.nextDueDate.isAfter(now)) {
          _upcomingPayments.add(payment);
          _autopilotUpcoming += payment.amount;

          // Check preparedness: does the envelope have enough balance?
          if (payment.envelopeId != null) {
            final envelope = _allEnvelopes.firstWhere(
              (e) => e.id == payment.envelopeId,
              orElse: () => Envelope(
                id: payment.envelopeId!,
                name: '',
                userId: userId,
                currentAmount: 0,
              ),
            );

            _autopilotPreparedness[payment.envelopeId!] = envelope.currentAmount >= payment.amount;
          }
        }
      }
    } catch (e) {
      debugPrint('[PayDayCockpit] Error calculating autopilot payments: $e');
    }
  }

  // ============================================================================
  // PHASE 1: AMOUNT ENTRY
  // ============================================================================

  void updateExternalInflow(double amount) {
    _externalInflow = amount;
    notifyListeners();
  }

  void proceedToStrategyReview() {
    if (_externalInflow <= 0) {
      _error = 'Please enter a valid amount';
      notifyListeners();
      return;
    }

    _currentPhase = CockpitPhase.strategyReview;
    _error = null;
    notifyListeners();
  }

  // ============================================================================
  // PHASE 2: STRATEGY REVIEW
  // ============================================================================

  void toggleEnvelope(String envelopeId, double? cashFlowAmount) {
    final envelope = _allEnvelopes.firstWhere((e) => e.id == envelopeId);

    if (_allocations.containsKey(envelopeId)) {
      final removedAmount = _allocations[envelopeId]!;
      _allocations.remove(envelopeId);

      // Recalculate if this was an autopilot item
      if (envelope.cashFlowEnabled && envelope.cashFlowAmount != null) {
        _autopilotReserve -= envelope.cashFlowAmount!;
      } else {
        _manualAllocations -= removedAmount;
      }
    } else {
      final amount = cashFlowAmount ?? 0.0;
      _allocations[envelopeId] = amount;

      // Check if this is autopilot or manual
      if (envelope.cashFlowEnabled && envelope.cashFlowAmount != null) {
        _autopilotReserve += envelope.cashFlowAmount!;
      } else {
        _manualAllocations += amount;
      }
    }

    notifyListeners();
  }

  void updateEnvelopeAllocation(String envelopeId, double amount) {
    final envelope = _allEnvelopes.firstWhere((e) => e.id == envelopeId);
    final oldAmount = _allocations[envelopeId] ?? 0.0;

    if (amount > 0) {
      _allocations[envelopeId] = amount;

      // Update autopilot or manual tracking
      if (envelope.cashFlowEnabled && envelope.cashFlowAmount != null) {
        _autopilotReserve = _autopilotReserve - oldAmount + amount;
      } else {
        _manualAllocations = _manualAllocations - oldAmount + amount;
      }
    } else {
      _allocations.remove(envelopeId);

      if (envelope.cashFlowEnabled && envelope.cashFlowAmount != null) {
        _autopilotReserve -= oldAmount;
      } else {
        _manualAllocations -= oldAmount;
      }
    }

    notifyListeners();
  }

  void addTemporaryBinder(String binderId) {
    _temporarilyAddedBinderIds.add(binderId);

    // Add all envelopes in this binder with their cash flow amounts
    final binderEnvelopes = _allEnvelopes.where((e) => e.groupId == binderId);
    for (final env in binderEnvelopes) {
      if (env.cashFlowEnabled && env.cashFlowAmount != null && env.cashFlowAmount! > 0) {
        _allocations[env.id] = env.cashFlowAmount!;
        _autopilotReserve += env.cashFlowAmount!;
      }
    }

    notifyListeners();
  }

  bool canProceedToStuffing() {
    if (_allocations.isEmpty) return false;
    // Allow over-allocation but warn
    return true;
  }

  void proceedToStuffing() {
    if (!canProceedToStuffing()) {
      _error = 'Please select at least one envelope to allocate';
      notifyListeners();
      return;
    }

    _currentPhase = CockpitPhase.stuffingExecution;
    _error = null;
    _stuffingProgress.clear();
    _organizeEnvelopesForStuffing();
    notifyListeners();
  }

  // Organize envelopes into binder groups for stuffing animation
  final List<BinderStuffingGroup> _binderGroups = [];
  final List<Envelope> _ungroupedEnvelopes = [];

  List<BinderStuffingGroup> get binderGroups => _binderGroups;
  List<Envelope> get ungroupedEnvelopes => _ungroupedEnvelopes;

  void _organizeEnvelopesForStuffing() {
    _binderGroups.clear();
    _ungroupedEnvelopes.clear();

    // Get envelopes that are allocated
    final envelopesToStuff = _allEnvelopes.where((e) => _allocations.containsKey(e.id)).toList();

    // Group by binder
    final binderMap = <String, List<Envelope>>{};
    for (final env in envelopesToStuff) {
      if (env.groupId != null) {
        binderMap.putIfAbsent(env.groupId!, () => []).add(env);
      } else {
        _ungroupedEnvelopes.add(env);
      }
    }

    // Create binder groups
    for (final entry in binderMap.entries) {
      final binder = _allBinders.firstWhere((b) => b.id == entry.key);
      _binderGroups.add(BinderStuffingGroup(
        binder: binder,
        envelopes: entry.value,
      ));
    }
  }

  // ============================================================================
  // PHASE 3: STUFFING EXECUTION
  // ============================================================================

  Future<void> executeStuffing({Map<String, double>? boosts}) async {
    try {
      // Step 0: INITIAL PAUSE - Show the money flow hierarchy clearly
      await Future.delayed(const Duration(milliseconds: 4000));

      // Step 1: Animate deposit to account if in account mode (source → account)
      if (_isAccountMode && _defaultAccountId != null) {
        // VISUAL ONLY: Animate the transfer over 3 seconds with incremental updates
        final steps = 30; // 30 updates over 3 seconds = 100ms per step
        final incrementPerStep = _externalInflow / steps;

        _accountDepositProgress = 0.0;
        for (var i = 0; i < steps; i++) {
          _accountDepositProgress += incrementPerStep;
          notifyListeners(); // Trigger UI update to show visual progress
          await Future.delayed(const Duration(milliseconds: 100));
        }

        // ACTUAL TRANSACTION: Make the real deposit once after animation
        await accountRepo.deposit(
          _defaultAccountId!,
          _externalInflow,
          description: 'Pay Day Deposit',
        );
        notifyListeners();

        // Small pause after account fill
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Step 2: SILVER STAGE - Animate cash flow allocations
      _stuffingStage = StuffingStage.silver;
      notifyListeners();

      final allocationEntries = _allocations.entries.toList();
      final totalEnvelopes = allocationEntries.length;

      if (totalEnvelopes > 0) {
        // Calculate delay per envelope to total ~9 seconds for silver (60% of 15s)
        final delayPerEnvelope = 9000 ~/ totalEnvelopes; // in milliseconds
        final minDelay = 600; // minimum 600ms per envelope
        final maxDelay = 1500; // maximum 1500ms per envelope
        final effectiveDelay = delayPerEnvelope.clamp(minDelay, maxDelay);

        for (var i = 0; i < allocationEntries.length; i++) {
          final entry = allocationEntries[i];
          final envelopeId = entry.key;
          final amount = entry.value;

          // Update current envelope being animated
          _currentEnvelopeAnimationIndex = i;

          // Animate the progress for this envelope
          _stuffingProgress[envelopeId] = amount;
          notifyListeners();

          // Wait before moving to next envelope (except for the last one)
          if (i < allocationEntries.length - 1) {
            await Future.delayed(Duration(milliseconds: effectiveDelay));
          }
        }
      }

      // Step 3: GOLD STAGE - Animate boost allocations (if any)
      if (boosts != null && boosts.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 1000));

        _stuffingStage = StuffingStage.gold;
        notifyListeners();

        // Sort boost entries so we animate them in the order they appear in the UI
        final boostEntries = boosts.entries.toList();
        final totalBoosts = boostEntries.length;
        // Calculate delay for gold stage to total ~8 seconds with more deliberate pacing
        final boostDelay = (8000 ~/ totalBoosts).clamp(1200, 3000);

        // Create a new animation index counter for gold stage (0-based within boosted items)
        for (var i = 0; i < boostEntries.length; i++) {
          final entry = boostEntries[i];
          final envelopeId = entry.key;
          final boostAmount = entry.value;

          // Set current envelope index to match the position in the gold stage list (0, 1, 2, ...)
          _currentEnvelopeAnimationIndex = i;

          // Add boost to existing stuffing
          final currentAmount = _stuffingProgress[envelopeId] ?? 0.0;
          _stuffingProgress[envelopeId] = currentAmount + boostAmount;
          notifyListeners();

          if (i < boostEntries.length - 1) {
            await Future.delayed(Duration(milliseconds: boostDelay));
          }
        }

        // Pause after last gold envelope to let users appreciate the final boost
        await Future.delayed(Duration(milliseconds: boostDelay));
      }

      // Step 4: Actually perform the allocations to envelopes
      _stuffingStage = StuffingStage.complete;
      notifyListeners();

      for (final entry in _stuffingProgress.entries) {
        final envelopeId = entry.key;
        final amount = entry.value;

        if (_isAccountMode && _defaultAccountId != null) {
          // INTERNAL transfer: Account → Envelope
          await accountRepo.transferToEnvelope(
            accountId: _defaultAccountId!,
            envelopeId: envelopeId,
            amount: amount,
            description: 'Cash Flow',
            date: DateTime.now(),
            envelopeRepo: envelopeRepo,
          );
        } else {
          // EXTERNAL deposit: Virtual income
          await envelopeRepo.deposit(
            envelopeId: envelopeId,
            amount: amount,
            description: 'Cash Flow',
            date: DateTime.now(),
          );
        }
      }

      // Calculate top horizons impacted
      _calculateTopHorizons();

      // Update PayDaySettings
      await _updatePayDaySettings();

      // Final pause before success screen
      await Future.delayed(const Duration(milliseconds: 1200));

      _currentPhase = CockpitPhase.success;
      notifyListeners();
    } catch (e) {
      _error = 'Stuffing failed: $e';
      notifyListeners();
    }
  }

  void updateStuffingProgress(int binderIndex, int envelopeIndex) {
    _currentStuffingBinderIndex = binderIndex;
    _currentStuffingEnvelopeIndex = envelopeIndex;
    notifyListeners();
  }

  // ============================================================================
  // PHASE 4: SUCCESS
  // ============================================================================

  void _calculateTopHorizons() {
    final impacts = <EnvelopeHorizonImpact>[];

    for (final entry in _allocations.entries) {
      final envelope = _allEnvelopes.firstWhere((e) => e.id == entry.key);
      final stuffedAmount = entry.value;

      if (envelope.targetAmount != null &&
          envelope.targetDate != null &&
          envelope.cashFlowAmount != null &&
          envelope.cashFlowAmount! > 0) {

        final velocity = envelope.cashFlowAmount!;
        final oldBalance = envelope.currentAmount;
        final newBalance = oldBalance + stuffedAmount;

        final oldDaysToTarget = (envelope.targetAmount! - oldBalance) / (velocity / 30.44);
        final newDaysToTarget = (envelope.targetAmount! - newBalance) / (velocity / 30.44);

        final daysSaved = (oldDaysToTarget - newDaysToTarget).round();

        if (daysSaved > 0) {
          impacts.add(EnvelopeHorizonImpact(
            envelope: envelope,
            daysSaved: daysSaved,
            stuffedAmount: stuffedAmount,
          ));
        }
      }
    }

    // Sort by days saved (descending) and take top 3
    impacts.sort((a, b) => b.daysSaved.compareTo(a.daysSaved));
    _topHorizons = impacts.take(3).toList();
  }

  Future<void> _updatePayDaySettings() async {
    try {
      final payDayBox = Hive.box<PayDaySettings>('payDaySettings');

      // Key is userId (matching PayDaySettingsService pattern)
      final existingSettings = payDayBox.get(userId);

      final updatedSettings = existingSettings?.copyWith(
        lastPayAmount: _externalInflow,
        lastPayDate: DateTime.now(),
        defaultAccountId: _defaultAccountId,
      ) ?? PayDaySettings(
        userId: userId,
        lastPayAmount: _externalInflow,
        lastPayDate: DateTime.now(),
        defaultAccountId: _defaultAccountId,
        payFrequency: 'monthly',
      );

      await payDayBox.put(userId, updatedSettings);
    } catch (e) {
      // Error updating pay day settings
    }
  }

  // ============================================================================
  // REAL-TIME CALCULATIONS (for Phase 3 UI)
  // ============================================================================

  double calculateRealTimeProgress(Envelope envelope, double currentStuffing) {
    if (envelope.targetAmount == null || envelope.targetAmount == 0) return 0.0;
    return ((envelope.currentAmount + currentStuffing) / envelope.targetAmount!).clamp(0.0, 1.0);
  }

  String calculateDaysSaved(Envelope envelope, double currentStuffing) {
    if (envelope.targetAmount == null) return "";

    final monthlyVelocity = envelope.cashFlowAmount ?? 0.0;
    if (monthlyVelocity <= 0) {
      return "First fueling: Time Machine initializing...";
    }

    final oldDays = (envelope.targetAmount! - envelope.currentAmount) / (monthlyVelocity / 30.44);
    final newDays = (envelope.targetAmount! - (envelope.currentAmount + currentStuffing)) / (monthlyVelocity / 30.44);

    final difference = (oldDays - newDays).round();
    return difference > 0 ? "🔥 $difference days closer" : "";
  }

  // ============================================================================
  // UTILITY
  // ============================================================================

  void reset() {
    _currentPhase = CockpitPhase.amountEntry;
    _externalInflow = 0.0;
    _allocations.clear();
    _temporarilyAddedBinderIds.clear();
    _autopilotReserve = 0.0;
    _manualAllocations = 0.0;
    _stuffingProgress.clear();
    _topHorizons.clear();
    _error = null;
    notifyListeners();
  }
}

// Helper class for organizing binders during stuffing
class BinderStuffingGroup {
  final EnvelopeGroup binder;
  final List<Envelope> envelopes;

  BinderStuffingGroup({
    required this.binder,
    required this.envelopes,
  });
}

// Helper class for tracking horizon impact
class EnvelopeHorizonImpact {
  final Envelope envelope;
  final int daysSaved;
  final double stuffedAmount;

  EnvelopeHorizonImpact({
    required this.envelope,
    required this.daysSaved,
    required this.stuffedAmount,
  });
}
