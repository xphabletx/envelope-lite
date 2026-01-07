// lib/screens/pay_day/cockpit_preview.dart
//
// STANDALONE MISSION CONTROL PREVIEW
// A self-contained visual sandbox for the Pay Day Cockpit experience.
// This file is completely disconnected from Hive and project repositories.
//
// The Intricate Experience:
// Phase 1: External Inflow Entry (The Infinite Sun)
// Phase 2: Strategy Review (Add Horizon Boosts, see live Days Saved)
// Phase 3: Waterfall Execution (Sequential Reservoir → Silver Autopilot → Gold Easter Egg)
// Phase 4: Future Recalibrated (Mission Report with metrics)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math' as math;

// ============================================================================
// MOCK MODELS
// ============================================================================

class MockEnvelope {
  final String id;
  final String name;
  final String emoji;
  final double currentAmount;
  final double? targetAmount;
  final DateTime? targetDate;
  final double? cashFlowAmount;
  final bool cashFlowEnabled;
  final String? groupId;
  final bool isNeed; // Cash Flow vs Horizon

  MockEnvelope({
    required this.id,
    required this.name,
    required this.emoji,
    required this.currentAmount,
    this.targetAmount,
    this.targetDate,
    this.cashFlowAmount,
    required this.cashFlowEnabled,
    this.groupId,
    required this.isNeed,
  });

  MockEnvelope copyWith({
    double? currentAmount,
    double? cashFlowAmount,
  }) {
    return MockEnvelope(
      id: id,
      name: name,
      emoji: emoji,
      currentAmount: currentAmount ?? this.currentAmount,
      targetAmount: targetAmount,
      targetDate: targetDate,
      cashFlowAmount: cashFlowAmount ?? this.cashFlowAmount,
      cashFlowEnabled: cashFlowEnabled,
      groupId: groupId,
      isNeed: isNeed,
    );
  }
}

class MockBinder {
  final String id;
  final String name;
  final String emoji;

  MockBinder({
    required this.id,
    required this.name,
    required this.emoji,
  });
}

class MockAccount {
  final String id;
  final String name;
  final double balance;

  MockAccount({
    required this.id,
    required this.name,
    required this.balance,
  });
}

// ============================================================================
// MOCK PROVIDER (State Machine)
// ============================================================================

enum CockpitPhase {
  inflowEntry,
  strategyReview,
  waterfallExecution,
  futureRecalibrated,
}

enum WaterfallStage {
  accountFill, // Account mode only
  silverAutopilot, // Stage 1: Fill to autopilot targets
  goldBoost, // Stage 2: Easter egg - boost horizons
  complete,
}

class MockPayDayCockpitProvider extends ChangeNotifier {
  // Phase management
  CockpitPhase _currentPhase = CockpitPhase.inflowEntry;
  CockpitPhase get currentPhase => _currentPhase;

  // Mode
  final bool _isAccountMode = true;
  bool get isAccountMode => _isAccountMode;
  MockAccount? _account;
  MockAccount? get account => _account;

  // Inflow
  double _externalInflow = 0.0;
  double get externalInflow => _externalInflow;

  // Data
  List<MockEnvelope> _allEnvelopes = [];
  List<MockBinder> _allBinders = [];
  final Map<String, double> _allocations = {}; // envelopeId -> amount

  List<MockEnvelope> get allEnvelopes => _allEnvelopes;
  List<MockBinder> get allBinders => _allBinders;
  Map<String, double> get allocations => _allocations;

  // Calculated values
  double _autopilotReserve = 0.0;
  double get autopilotReserve => _autopilotReserve;
  double get availableFuel => _externalInflow - _autopilotReserve;

  // Waterfall animation state
  WaterfallStage _waterfallStage = WaterfallStage.accountFill;
  WaterfallStage get waterfallStage => _waterfallStage;
  double _accountFillProgress = 0.0;
  double get accountFillProgress => _accountFillProgress;
  int _currentEnvelopeIndex = -1;
  int get currentEnvelopeIndex => _currentEnvelopeIndex;
  final Map<String, double> _stuffingProgress = {}; // envelopeId -> stuffed amount
  Map<String, double> get stuffingProgress => _stuffingProgress;

  // Success metrics
  int _totalDaysSaved = 0;
  int get totalDaysSaved => _totalDaysSaved;
  double _fuelEfficiency = 0.0; // % of inflow used
  double get fuelEfficiency => _fuelEfficiency;
  double _horizonAdvancement = 0.0; // Total % points moved
  double get horizonAdvancement => _horizonAdvancement;

  MockPayDayCockpitProvider() {
    _initializeMockData();
  }

  void _initializeMockData() {
    // Mock account
    _account = MockAccount(
      id: 'acc_1',
      name: 'Checking Account',
      balance: 5000.0,
    );

    // Mock binders
    _allBinders = [
      MockBinder(id: 'binder_essentials', name: 'Essentials', emoji: '🏠'),
      MockBinder(id: 'binder_dreams', name: 'Dreams', emoji: '✨'),
    ];

    // Mock envelopes (2 Needs, 3 Dreams)
    _allEnvelopes = [
      // NEEDS (Cash Flow enabled)
      MockEnvelope(
        id: 'env_rent',
        name: 'Rent',
        emoji: '🏡',
        currentAmount: 0.0,
        targetAmount: 2000.0,
        targetDate: DateTime.now().add(const Duration(days: 30)),
        cashFlowAmount: 2000.0,
        cashFlowEnabled: true,
        groupId: 'binder_essentials',
        isNeed: true,
      ),
      MockEnvelope(
        id: 'env_groceries',
        name: 'Groceries',
        emoji: '🛒',
        currentAmount: 150.0,
        targetAmount: 600.0,
        targetDate: DateTime.now().add(const Duration(days: 30)),
        cashFlowAmount: 600.0,
        cashFlowEnabled: true,
        groupId: 'binder_essentials',
        isNeed: true,
      ),
      // DREAMS (Horizon targets)
      MockEnvelope(
        id: 'env_vacation',
        name: 'Dream Vacation',
        emoji: '🏖️',
        currentAmount: 1200.0,
        targetAmount: 5000.0,
        targetDate: DateTime.now().add(const Duration(days: 180)),
        cashFlowAmount: 500.0,
        cashFlowEnabled: true,
        groupId: 'binder_dreams',
        isNeed: false,
      ),
      MockEnvelope(
        id: 'env_car',
        name: 'New Car Fund',
        emoji: '🚗',
        currentAmount: 3000.0,
        targetAmount: 15000.0,
        targetDate: DateTime.now().add(const Duration(days: 365)),
        cashFlowAmount: 800.0,
        cashFlowEnabled: true,
        groupId: 'binder_dreams',
        isNeed: false,
      ),
      MockEnvelope(
        id: 'env_emergency',
        name: 'Emergency Fund',
        emoji: '🚨',
        currentAmount: 5000.0,
        targetAmount: 10000.0,
        targetDate: DateTime.now().add(const Duration(days: 270)),
        cashFlowAmount: 300.0,
        cashFlowEnabled: true,
        groupId: null,
        isNeed: false,
      ),
    ];

    // Initialize allocations with cash flow enabled envelopes
    _calculateAutopilotAllocations();
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

  // ========================================================================
  // PHASE 1: INFLOW ENTRY
  // ========================================================================

  void updateExternalInflow(double amount) {
    _externalInflow = amount;
    notifyListeners();
  }

  void proceedToStrategyReview() {
    if (_externalInflow <= 0) return;
    _currentPhase = CockpitPhase.strategyReview;
    notifyListeners();
  }

  // ========================================================================
  // PHASE 2: STRATEGY REVIEW
  // ========================================================================

  void toggleEnvelope(String envelopeId) {
    final envelope = _allEnvelopes.firstWhere((e) => e.id == envelopeId);

    if (_allocations.containsKey(envelopeId)) {
      _allocations.remove(envelopeId);

      if (envelope.cashFlowEnabled && envelope.cashFlowAmount != null) {
        _autopilotReserve -= envelope.cashFlowAmount!;
      }
    } else {
      final amount = envelope.cashFlowAmount ?? 0.0;
      _allocations[envelopeId] = amount;

      if (envelope.cashFlowEnabled && envelope.cashFlowAmount != null) {
        _autopilotReserve += envelope.cashFlowAmount!;
      }
    }

    notifyListeners();
  }

  void addBinder(String binderId) {
    final binderEnvelopes = _allEnvelopes.where((e) => e.groupId == binderId);
    for (final env in binderEnvelopes) {
      if (!_allocations.containsKey(env.id) &&
          env.cashFlowEnabled &&
          env.cashFlowAmount != null &&
          env.cashFlowAmount! > 0) {
        _allocations[env.id] = env.cashFlowAmount!;
        _autopilotReserve += env.cashFlowAmount!;
      }
    }
    notifyListeners();
  }

  String calculateDaysSaved(MockEnvelope envelope) {
    if (envelope.targetAmount == null || envelope.targetAmount == 0) return "";

    final monthlyVelocity = envelope.cashFlowAmount ?? 0.0;
    if (monthlyVelocity <= 0) {
      return "First fueling: Time Machine initializing...";
    }

    final stuffedAmount = _allocations[envelope.id] ?? 0.0;
    final oldDays = (envelope.targetAmount! - envelope.currentAmount) / (monthlyVelocity / 30.44);
    final newDays = (envelope.targetAmount! - (envelope.currentAmount + stuffedAmount)) / (monthlyVelocity / 30.44);

    final difference = (oldDays - newDays).round();
    return difference > 0 ? "🔥 $difference days closer" : "";
  }

  void proceedToWaterfall() {
    if (_allocations.isEmpty) return;
    _currentPhase = CockpitPhase.waterfallExecution;
    _waterfallStage = _isAccountMode ? WaterfallStage.accountFill : WaterfallStage.silverAutopilot;
    _stuffingProgress.clear();
    notifyListeners();
    _startWaterfallAnimation();
  }

  // ========================================================================
  // PHASE 3: WATERFALL EXECUTION (THE MAGIC)
  // ========================================================================

  Future<void> _startWaterfallAnimation() async {
    // STAGE 0: Fill Account Reservoir (if account mode)
    if (_isAccountMode) {
      await _animateAccountFill();
      _waterfallStage = WaterfallStage.silverAutopilot;
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // STAGE 1: Silver Stream - Fill to Autopilot Targets
    await _animateSilverStream();
    _waterfallStage = WaterfallStage.goldBoost;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 800));

    // STAGE 2: Gold Boost - Easter Egg (if fuel remains)
    if (availableFuel > 0) {
      await _animateGoldBoost();
    }

    _waterfallStage = WaterfallStage.complete;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 1000));

    // Calculate success metrics
    _calculateSuccessMetrics();
    _currentPhase = CockpitPhase.futureRecalibrated;
    notifyListeners();
  }

  Future<void> _animateAccountFill() async {
    // Animate account filling from 0 to 100%
    for (int i = 0; i <= 20; i++) {
      _accountFillProgress = i / 20.0;
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<void> _animateSilverStream() async {
    final envelopesToStuff = _allEnvelopes.where((e) => _allocations.containsKey(e.id)).toList();

    for (int i = 0; i < envelopesToStuff.length; i++) {
      _currentEnvelopeIndex = i;
      final envelope = envelopesToStuff[i];
      final targetAmount = _allocations[envelope.id]!;

      // Animate filling this envelope
      for (int step = 0; step <= 10; step++) {
        _stuffingProgress[envelope.id] = (step / 10.0) * targetAmount;
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 80));
      }
    }
  }

  Future<void> _animateGoldBoost() async {
    // Distribute available fuel proportionally to horizons (non-needs with targets)
    final horizonEnvelopes = _allEnvelopes
        .where((e) => !e.isNeed && e.targetAmount != null && _allocations.containsKey(e.id))
        .toList();

    if (horizonEnvelopes.isEmpty) return;

    final fuelPerHorizon = availableFuel / horizonEnvelopes.length;

    for (final envelope in horizonEnvelopes) {
      final currentStuffed = _stuffingProgress[envelope.id] ?? 0.0;
      final boostAmount = fuelPerHorizon;

      // Animate the gold boost
      for (int step = 0; step <= 10; step++) {
        _stuffingProgress[envelope.id] = currentStuffed + (step / 10.0) * boostAmount;
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  void _calculateSuccessMetrics() {
    _totalDaysSaved = 0;
    double totalStuffed = 0.0;
    double totalHorizonProgress = 0.0;

    for (final entry in _stuffingProgress.entries) {
      final envelope = _allEnvelopes.firstWhere((e) => e.id == entry.key);
      final stuffedAmount = entry.value;
      totalStuffed += stuffedAmount;

      // Calculate days saved
      if (envelope.targetAmount != null &&
          envelope.cashFlowAmount != null &&
          envelope.cashFlowAmount! > 0) {
        final monthlyVelocity = envelope.cashFlowAmount!;
        final oldDays = (envelope.targetAmount! - envelope.currentAmount) / (monthlyVelocity / 30.44);
        final newDays = (envelope.targetAmount! - (envelope.currentAmount + stuffedAmount)) / (monthlyVelocity / 30.44);
        final daysSaved = (oldDays - newDays).round();
        if (daysSaved > 0) {
          _totalDaysSaved += daysSaved;
        }

        // Calculate horizon advancement (% points)
        if (!envelope.isNeed && envelope.targetAmount! > 0) {
          final progressGained = (stuffedAmount / envelope.targetAmount!) * 100;
          totalHorizonProgress += progressGained;
        }
      }
    }

    _fuelEfficiency = (totalStuffed / _externalInflow) * 100;
    _horizonAdvancement = totalHorizonProgress;
  }

  // ========================================================================
  // PHASE 4: SUCCESS
  // ========================================================================

  void reset() {
    _currentPhase = CockpitPhase.inflowEntry;
    _externalInflow = 0.0;
    _waterfallStage = WaterfallStage.accountFill;
    _accountFillProgress = 0.0;
    _currentEnvelopeIndex = -1;
    _stuffingProgress.clear();
    _initializeMockData();
    notifyListeners();
  }
}

// ============================================================================
// MAIN PREVIEW SCREEN
// ============================================================================

class CockpitPreview extends StatefulWidget {
  const CockpitPreview({super.key});

  @override
  State<CockpitPreview> createState() => _CockpitPreviewState();
}

class _CockpitPreviewState extends State<CockpitPreview> {
  late MockPayDayCockpitProvider _provider;
  final TextEditingController _amountController = TextEditingController(text: '4200.00');

  @override
  void initState() {
    super.initState();
    _provider = MockPayDayCockpitProvider();
    _provider.updateExternalInflow(4200.0);
    _provider.addListener(_onProviderUpdate);
  }

  @override
  void dispose() {
    _provider.removeListener(_onProviderUpdate);
    _provider.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _onProviderUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mission Control Preview',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {
                _provider.reset();
                _amountController.text = '4200.00';
                _provider.updateExternalInflow(4200.0);
              });
            },
            tooltip: 'Reset Demo',
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        child: _buildPhaseContent(),
      ),
    );
  }

  Widget _buildPhaseContent() {
    switch (_provider.currentPhase) {
      case CockpitPhase.inflowEntry:
        return _buildPhase1InflowEntry();
      case CockpitPhase.strategyReview:
        return _buildPhase2StrategyReview();
      case CockpitPhase.waterfallExecution:
        return _buildPhase3WaterfallExecution();
      case CockpitPhase.futureRecalibrated:
        return _buildPhase4FutureRecalibrated();
    }
  }

  // ==========================================================================
  // PHASE 1: INFLOW ENTRY (THE INFINITE SUN)
  // ==========================================================================

  Widget _buildPhase1InflowEntry() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),

          // THE INFINITE SUN
          InfiniteSunHeader(intensity: _provider.externalInflow / 5000.0),

          const SizedBox(height: 40),

          // Title
          Text(
            'External Inflow',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          Text(
            _provider.isAccountMode
                ? 'Money arriving to ${_provider.account?.name ?? 'account'}'
                : 'Money arriving to the Horizon Pool',
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          // Amount input
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.secondary,
            ),
            onChanged: (value) {
              final amount = double.tryParse(value.replaceAll(',', '')) ?? 0.0;
              _provider.updateExternalInflow(amount);
            },
            decoration: InputDecoration(
              prefixText: '\$ ',
              prefixStyle: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.secondary,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: theme.colorScheme.primary, width: 3),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            ),
          ),

          const SizedBox(height: 32),

          // Mode indicator
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  _provider.isAccountMode ? Icons.account_balance : Icons.wallet,
                  color: theme.colorScheme.primary,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _provider.isAccountMode
                        ? 'Account Mode: Money flows to ${_provider.account?.name ?? 'account'} first, then to envelopes'
                        : 'Simple Mode: Money flows directly to Horizon Pool',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Continue button
          FilledButton(
            onPressed: _provider.externalInflow > 0 ? () => _provider.proceedToStrategyReview() : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
              backgroundColor: theme.colorScheme.secondary,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Review Strategy', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                SizedBox(width: 12),
                Icon(Icons.arrow_forward, size: 24, color: Colors.white),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // PHASE 2: STRATEGY REVIEW (HORIZON BOOSTS)
  // ==========================================================================

  Widget _buildPhase2StrategyReview() {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Waterfall Header (Sticky)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
              ],
            ),
            border: Border(bottom: BorderSide(color: theme.colorScheme.primary, width: 3)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMetricColumn('Total Inflow', '\$${_provider.externalInflow.toStringAsFixed(0)}', Colors.green.shade700),
                  _buildMetricColumn('Autopilot Reserve', '\$${_provider.autopilotReserve.toStringAsFixed(0)}', Colors.orange.shade700),
                  _buildMetricColumn('Available Fuel', '\$${_provider.availableFuel.toStringAsFixed(0)}', theme.colorScheme.secondary),
                ],
              ),
            ],
          ),
        ),

        // Scrollable content
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Review your cash flow strategy. These allocations happen automatically.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 16),

              Text(
                '${_provider.allocations.length} envelopes ready for fueling',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
              ),

              const SizedBox(height: 16),

              // Envelope rows with live Days Saved
              ..._provider.allEnvelopes.where((e) => _provider.allocations.containsKey(e.id)).map((envelope) {
                final daysSaved = _provider.calculateDaysSaved(envelope);
                final allocation = _provider.allocations[envelope.id]!;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Text(envelope.emoji, style: const TextStyle(fontSize: 32)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              envelope.name,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            if (daysSaved.isNotEmpty)
                              Text(
                                daysSaved,
                                style: TextStyle(fontSize: 14, color: Colors.orange.shade700, fontWeight: FontWeight.bold),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        '\$${allocation.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 16),

              // Add Horizon Boosts button
              OutlinedButton.icon(
                onPressed: () => _showAddBoostModal(),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Add Horizon Boosts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),

        // Bottom button
        Container(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _provider.allocations.isNotEmpty ? () => _provider.proceedToWaterfall() : null,
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.secondary,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.rocket_launch, size: 28, color: Colors.white),
                SizedBox(width: 12),
                Text('Fuel the Horizons!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricColumn(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  void _showAddBoostModal() {
    final availableEnvelopes = _provider.allEnvelopes.where((e) => !_provider.allocations.containsKey(e.id)).toList();
    final availableBinders = _provider.allBinders;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Add Horizon Boost', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
            const SizedBox(height: 16),
            if (availableBinders.isNotEmpty) ...[
              const Text('Binders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ...availableBinders.map((binder) => ListTile(
                    leading: Text(binder.emoji, style: const TextStyle(fontSize: 24)),
                    title: Text(binder.name),
                    trailing: const Icon(Icons.add),
                    onTap: () {
                      _provider.addBinder(binder.id);
                      Navigator.pop(context);
                    },
                  )),
            ],
            if (availableEnvelopes.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Envelopes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ...availableEnvelopes.map((env) => ListTile(
                    leading: Text(env.emoji, style: const TextStyle(fontSize: 24)),
                    title: Text(env.name),
                    trailing: const Icon(Icons.add),
                    onTap: () {
                      _provider.toggleEnvelope(env.id);
                      Navigator.pop(context);
                    },
                  )),
            ],
            if (availableEnvelopes.isEmpty && availableBinders.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Text('All items already added!', style: TextStyle(fontSize: 18, color: Colors.grey)),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================================================
  // PHASE 3: WATERFALL EXECUTION (THE DUAL-STAGE MAGIC)
  // ==========================================================================

  Widget _buildPhase3WaterfallExecution() {
    return Stack(
      children: [
        // Background gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.blue.shade900,
                Colors.purple.shade900,
                Colors.black,
              ],
            ),
          ),
        ),

        Column(
          children: [
            // Infinite Sun at top (pulsing)
            const SizedBox(height: 40),
            InfiniteSunHeader(intensity: 1.0, isPulsing: true),

            const SizedBox(height: 20),

            // Reservoir (Account Mode)
            if (_provider.isAccountMode) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                ),
                child: Stack(
                  children: [
                    // Filling animation
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: double.infinity,
                      height: 80 * _provider.accountFillProgress,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade300.withValues(alpha: 0.6), Colors.blue.shade500.withValues(alpha: 0.8)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    Center(
                      child: Text(
                        '${_provider.account?.name ?? 'Account'} Reservoir',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Envelope list with waterfall
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _provider.allEnvelopes.where((e) => _provider.allocations.containsKey(e.id)).length,
                itemBuilder: (context, index) {
                  final envelope = _provider.allEnvelopes.where((e) => _provider.allocations.containsKey(e.id)).toList()[index];
                  final targetAllocation = _provider.allocations[envelope.id]!;
                  final currentStuffed = _provider.stuffingProgress[envelope.id] ?? 0.0;
                  final isActive = _provider.currentEnvelopeIndex == index;
                  final isGoldStage = _provider.waterfallStage == WaterfallStage.goldBoost && !envelope.isNeed;

                  return StuffingEnvelopeRowCockpit(
                    envelope: envelope,
                    targetAllocation: targetAllocation,
                    currentStuffed: currentStuffed,
                    isActive: isActive,
                    isGoldStage: isGoldStage,
                  );
                },
              ),
            ),
          ],
        ),

        // Light particles
        if (_provider.waterfallStage == WaterfallStage.silverAutopilot || _provider.waterfallStage == WaterfallStage.goldBoost)
          Positioned.fill(
            child: CustomPaint(
              painter: LightParticlesPainter(
                isGold: _provider.waterfallStage == WaterfallStage.goldBoost,
              ),
            ),
          ),
      ],
    );
  }

  // ==========================================================================
  // PHASE 4: FUTURE RECALIBRATED (MISSION REPORT)
  // ==========================================================================

  Widget _buildPhase4FutureRecalibrated() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Time Machine Icon
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.2),
                  theme.colorScheme.secondary.withValues(alpha: 0.2),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Text('⏰', style: TextStyle(fontSize: 80)),
          ),

          const SizedBox(height: 32),

          Text(
            'Future Recalibrated',
            style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          const Text(
            'Your Horizons are now closer',
            style: TextStyle(fontSize: 20, color: Colors.grey),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 40),

          // Metrics
          _buildSuccessMetric('Days Saved', _provider.totalDaysSaved.toString(), Icons.access_time, Colors.orange),
          const SizedBox(height: 16),
          _buildSuccessMetric('Fuel Efficiency', '${_provider.fuelEfficiency.toStringAsFixed(1)}%', Icons.local_gas_station, Colors.blue),
          const SizedBox(height: 16),
          _buildSuccessMetric('Horizon Advancement', '${_provider.horizonAdvancement.toStringAsFixed(1)}% pts', Icons.trending_up, Colors.green),

          const Spacer(),

          // Done button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                setState(() {
                  _provider.reset();
                  _amountController.text = '4200.00';
                  _provider.updateExternalInflow(4200.0);
                });
              },
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.secondary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Start New Mission', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessMetric(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 40, color: color),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// CUSTOM WIDGETS
// ============================================================================

// THE INFINITE SUN (Radiant Pulsing Gradient)
class InfiniteSunHeader extends StatefulWidget {
  final double intensity; // 0.0 to 1.0
  final bool isPulsing;

  const InfiniteSunHeader({super.key, required this.intensity, this.isPulsing = false});

  @override
  State<InfiniteSunHeader> createState() => _InfiniteSunHeaderState();
}

class _InfiniteSunHeaderState extends State<InfiniteSunHeader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    if (widget.isPulsing) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulseScale = widget.isPulsing ? 1.0 + (_controller.value * 0.1) : 1.0;
        return Transform.scale(
          scale: pulseScale,
          child: Container(
            height: 150,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Color.lerp(Colors.yellow.shade200, Colors.yellow.shade500, widget.intensity.clamp(0.0, 1.0))!,
                  Color.lerp(Colors.orange.shade300, Colors.orange.shade700, widget.intensity.clamp(0.0, 1.0))!,
                  Color.lerp(Colors.red.shade200, Colors.red.shade600, widget.intensity.clamp(0.0, 1.0))!,
                ],
              ),
              borderRadius: BorderRadius.circular(100),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: widget.intensity.clamp(0.0, 0.6)),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: const Center(
              child: Text(
                '☀️',
                style: TextStyle(fontSize: 80),
              ),
            ),
          ),
        );
      },
    );
  }
}

// STUFFING ENVELOPE ROW (with Horizon Progress integration)
class StuffingEnvelopeRowCockpit extends StatelessWidget {
  final MockEnvelope envelope;
  final double targetAllocation;
  final double currentStuffed;
  final bool isActive;
  final bool isGoldStage;

  const StuffingEnvelopeRowCockpit({
    super.key,
    required this.envelope,
    required this.targetAllocation,
    required this.currentStuffed,
    required this.isActive,
    required this.isGoldStage,
  });

  @override
  Widget build(BuildContext context) {
    final progress = envelope.targetAmount != null && envelope.targetAmount! > 0
        ? ((envelope.currentAmount + currentStuffed) / envelope.targetAmount!).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive
            ? (isGoldStage ? Colors.amber.withValues(alpha: 0.2) : Colors.blue.withValues(alpha: 0.2))
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? (isGoldStage ? Colors.amber : Colors.blue.shade300)
              : Colors.white.withValues(alpha: 0.1),
          width: isActive ? 3 : 1,
        ),
      ),
      child: Row(
        children: [
          Text(envelope.emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  envelope.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                // Horizon Progress Sun (if has target)
                if (envelope.targetAmount != null) HorizonProgressWidget(percentage: progress, size: 50),
                if (isGoldStage && !envelope.isNeed)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '✨ GOLD BOOST ACTIVE',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.amber.shade300),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '\$${currentStuffed.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isGoldStage ? Colors.amber.shade300 : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// HORIZON PROGRESS WIDGET (Embedded Sun Rising)
class HorizonProgressWidget extends StatelessWidget {
  final double percentage;
  final double size;

  const HorizonProgressWidget({super.key, required this.percentage, this.size = 60});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _HorizonPainter(percentage: percentage),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(bottom: size * 0.08),
            child: Text(
              '${(percentage * 100).toInt()}%',
              style: TextStyle(
                fontSize: size * 0.18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HorizonPainter extends CustomPainter {
  final double percentage;

  _HorizonPainter({required this.percentage});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.45;
    final horizonY = center.dy + (radius * 0.15);

    // Glow
    if (percentage > 0.05) {
      final glowPaint = Paint()
        ..color = const Color(0xFFD4AF37).withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(Offset(center.dx, horizonY), radius * percentage, glowPaint);
    }

    // Sun
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, horizonY));

    final sunPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          Color(0xFF8B6F47),
          Color(0xFFD4AF37),
          Color(0xFFFFD700),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    final verticalShift = radius * (1.0 - percentage);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(center.dx, horizonY + verticalShift), radius: radius),
      math.pi,
      math.pi,
      true,
      sunPaint,
    );
    canvas.restore();

    // Horizon line
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(center.dx - radius, horizonY),
      Offset(center.dx + radius, horizonY),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(_HorizonPainter oldDelegate) => oldDelegate.percentage != percentage;
}

// LIGHT PARTICLES PAINTER (Waterfall animation)
class LightParticlesPainter extends CustomPainter {
  final bool isGold;

  LightParticlesPainter({required this.isGold});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isGold ? Colors.amber.shade300 : Colors.blue.shade300).withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    // Draw falling particles
    for (int i = 0; i < 20; i++) {
      final x = (i / 20) * size.width;
      final y = (size.height * 0.3) + (i % 5) * 40;
      canvas.drawCircle(Offset(x, y), 4, paint);
    }
  }

  @override
  bool shouldRepaint(LightParticlesPainter oldDelegate) => oldDelegate.isGold != isGold;
}
