// lib/screens/pay_day/cockpit_preview.dart
//
// 🚀 Mission Control Cockpit - Real Integration
//
// The Intricate Experience:
// Phase 1: External Income Entry + Mode Selection
// Phase 2: Strategy Review (Cash Flow + Horizon Boosts)
// Phase 3: Waterfall Execution (Account Fill → Silver Autopilot → Gold Boost)
// Phase 4: Future Recalibrated (Mission Report with metrics)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math' as math;

import '../../models/envelope.dart';
import '../../models/envelope_group.dart';
import '../../providers/pay_day_cockpit_provider.dart';
import '../../providers/font_provider.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/horizon_progress.dart';
import '../../widgets/common/smart_text_field.dart';
import '../../utils/calculator_helper.dart';
import 'add_to_pay_day_modal.dart';

enum CockpitPhaseUI {
  inflowEntry,
  strategyReview,
  waterfallExecution,
  futureRecalibrated,
}

enum WaterfallStage {
  accountFill,
  silverAutopilot,
  goldBoost,
  complete,
}

class CockpitPreview extends StatefulWidget {
  const CockpitPreview({super.key});

  @override
  State<CockpitPreview> createState() => _CockpitPreviewState();
}

class _CockpitPreviewState extends State<CockpitPreview> {
  late PayDayCockpitProvider _provider;
  final TextEditingController _amountController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // UI State
  CockpitPhaseUI _currentPhaseUI = CockpitPhaseUI.inflowEntry;
  WaterfallStage _waterfallStage = WaterfallStage.accountFill;

  // Horizon boost tracking
  final Map<String, double> _horizonBoosts = {}; // envelopeId -> percentage (0.0-1.0)
  final Map<String, bool> _boostExpanded = {}; // envelopeId -> expanded

  // Allocation tracking (temporary edits for this pay day)
  final Map<String, double> _tempAllocations = {}; // envelopeId -> amount
  final Map<String, TextEditingController> _controllers = {}; // envelopeId -> controller

  // Animation state for waterfall
  double _accountFillProgress = 0.0;
  final Map<String, double> _stuffingProgress = {}; // envelopeId -> stuffed amount
  int _currentEnvelopeIndex = -1;

  // Collapsible binders
  final Set<String> _expandedBinderIds = {};

  @override
  void initState() {
    super.initState();
    _provider = Provider.of<PayDayCockpitProvider>(context, listen: false);
    _initializeProvider();
  }

  Future<void> _initializeProvider() async {
    await _provider.initialize();

    // Pre-fill amount if available
    if (_provider.externalInflow > 0) {
      _amountController.text = _provider.externalInflow.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _scrollController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          '🚀 Mission Control',
          style: fontProvider.getTextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
      body: _buildPhaseContent(),
    );
  }

  Widget _buildPhaseContent() {
    switch (_currentPhaseUI) {
      case CockpitPhaseUI.inflowEntry:
        return _buildPhase1InflowEntry();
      case CockpitPhaseUI.strategyReview:
        return _buildPhase2StrategyReview();
      case CockpitPhaseUI.waterfallExecution:
        return _buildPhase3WaterfallExecution();
      case CockpitPhaseUI.futureRecalibrated:
        return _buildPhase4FutureRecalibrated();
    }
  }

  // ==========================================================================
  // PHASE 1: EXTERNAL INCOME ENTRY + MODE SELECTION
  // ==========================================================================

  Widget _buildPhase1InflowEntry() {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);
    final locale = Provider.of<LocaleProvider>(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),

          // Infinite Sun Header
          _InfiniteSunHeader(),

          const SizedBox(height: 32),

          Text(
            'External Income',
            style: fontProvider.getTextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),

          const SizedBox(height: 24),

          // Amount input with calculator
          SmartTextField(
            controller: _amountController,
            labelText: 'Income Amount',
            prefix: Text(locale.currencySymbol),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (value) {
              final amount = double.tryParse(value) ?? 0.0;
              _provider.updateExternalInflow(amount);
            },
          ),

          const SizedBox(height: 32),

          // Mode indicator
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _provider.isAccountMode ? Icons.account_balance : Icons.attach_money,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _provider.isAccountMode
                      ? 'Account Mode: Income → ${_provider.defaultAccount?.name ?? "Account"} → Envelopes'
                      : 'Simple Mode: Income → Envelopes',
                    style: fontProvider.getTextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Continue button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final amount = double.tryParse(_amountController.text) ?? 0.0;
                if (amount > 0) {
                  _provider.updateExternalInflow(amount);
                  setState(() {
                    _currentPhaseUI = CockpitPhaseUI.strategyReview;
                    // Initialize temp allocations with provider allocations
                    _tempAllocations.clear();
                    _tempAllocations.addAll(_provider.allocations);
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid amount')),
                  );
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 20),
              ),
              child: Text(
                'Review Strategy',
                style: fontProvider.getTextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // PHASE 2: STRATEGY REVIEW (ENHANCED)
  // ==========================================================================

  Widget _buildPhase2StrategyReview() {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);
    final locale = Provider.of<LocaleProvider>(context);
    final currency = NumberFormat.currency(symbol: locale.currencySymbol, decimalDigits: 0);

    // Calculate totals
    final totalIncome = _provider.externalInflow;
    final cashFlowTotal = _tempAllocations.values.fold(0.0, (sum, amount) => sum + amount);
    final boostTotal = _horizonBoosts.entries.fold(0.0, (sum, entry) {
      return sum + ((totalIncome - cashFlowTotal) * entry.value);
    });
    final remaining = totalIncome - cashFlowTotal - boostTotal;

    return Column(
      children: [
        // Top stats bar (sticky)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatChip('💰', 'Income', currency.format(totalIncome), theme, fontProvider),
              _buildStatChip('⚡', 'Cash Flow', currency.format(cashFlowTotal), theme, fontProvider),
              _buildStatChip('🚀', 'Boost', currency.format(boostTotal), theme, fontProvider),
              _buildStatChip('💵', 'Reserve', currency.format(remaining), theme, fontProvider, isWarning: remaining < 0),
            ],
          ),
        ),

        // Scrollable content
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Binders section
              ..._buildBindersSection(theme, fontProvider, currency),

              const SizedBox(height: 24),

              // Individual envelopes section
              ..._buildIndividualEnvelopesSection(theme, fontProvider, currency),

              const SizedBox(height: 16),

              // Add Item button
              OutlinedButton.icon(
                onPressed: () => _showAddItemModal(),
                icon: const Icon(Icons.add_circle_outline),
                label: Text(
                  'Add Item to Pay Day',
                  style: fontProvider.getTextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                ),
              ),

              const SizedBox(height: 24),

              // Fuel the Horizons button (at bottom of list)
              FilledButton(
                onPressed: () => _startWaterfallAnimation(),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                ),
                child: Text(
                  '🎯 Fuel the Horizons!',
                  style: fontProvider.getTextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip(String icon, String label, String value, ThemeData theme, FontProvider fontProvider, {bool isWarning = false}) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          label,
          style: fontProvider.getTextStyle(
            fontSize: 10,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        Text(
          value,
          style: fontProvider.getTextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isWarning ? Colors.red : theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildBindersSection(ThemeData theme, FontProvider fontProvider, NumberFormat currency) {
    final widgets = <Widget>[];

    // Get binders that have envelopes in allocations
    final bindersWithAllocations = _provider.allBinders.where((b) {
      return _provider.allEnvelopes.any((e) =>
        e.groupId == b.id && _provider.allocations.containsKey(e.id)
      );
    }).toList();

    if (bindersWithAllocations.isEmpty) return widgets;

    widgets.add(
      Text(
        'Binders',
        style: fontProvider.getTextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
    widgets.add(const SizedBox(height: 12));

    for (final binder in bindersWithAllocations) {
      widgets.add(_buildBinderCard(binder, theme, fontProvider, currency));
      widgets.add(const SizedBox(height: 12));
    }

    return widgets;
  }

  Widget _buildBinderCard(EnvelopeGroup binder, ThemeData theme, FontProvider fontProvider, NumberFormat currency) {
    final isExpanded = _expandedBinderIds.contains(binder.id);
    final binderEnvelopes = _provider.allEnvelopes.where((e) => e.groupId == binder.id).toList();

    // Calculate binder stats
    final binderCashFlow = binderEnvelopes.fold(0.0, (sum, env) =>
      sum + (_tempAllocations[env.id] ?? 0.0)
    );
    final binderHorizon = binderEnvelopes.where((e) => e.targetAmount != null).length;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // Binder header
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedBinderIds.remove(binder.id);
                } else {
                  _expandedBinderIds.add(binder.id);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  binder.getIconWidget(theme, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          binder.name,
                          style: fontProvider.getTextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${binderEnvelopes.length} envelopes • ${currency.format(binderCashFlow)} cash flow • $binderHorizon horizons',
                          style: fontProvider.getTextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),

          // Envelopes in binder (when expanded)
          if (isExpanded) ...[
            const Divider(height: 1),
            ...binderEnvelopes.map((env) => _buildEnvelopeCard(env, theme, fontProvider, currency, inBinder: true)),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildIndividualEnvelopesSection(ThemeData theme, FontProvider fontProvider, NumberFormat currency) {
    final widgets = <Widget>[];

    // Get individual envelopes (not in binders, but in allocations)
    final individualEnvelopes = _provider.allEnvelopes.where((e) =>
      e.groupId == null && _provider.allocations.containsKey(e.id)
    ).toList();

    if (individualEnvelopes.isEmpty) return widgets;

    widgets.add(
      Text(
        'Envelopes',
        style: fontProvider.getTextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
    widgets.add(const SizedBox(height: 12));

    for (final env in individualEnvelopes) {
      widgets.add(_buildEnvelopeCard(env, theme, fontProvider, currency));
      widgets.add(const SizedBox(height: 12));
    }

    return widgets;
  }

  Widget _buildEnvelopeCard(Envelope envelope, ThemeData theme, FontProvider fontProvider, NumberFormat currency, {bool inBinder = false}) {
    final isIncluded = _tempAllocations.containsKey(envelope.id);
    final currentAmount = _tempAllocations[envelope.id] ?? envelope.cashFlowAmount ?? 0.0;
    final hasBoost = _horizonBoosts.containsKey(envelope.id) && (_horizonBoosts[envelope.id] ?? 0) > 0;

    // Get or create controller for this envelope
    if (!_controllers.containsKey(envelope.id)) {
      _controllers[envelope.id] = TextEditingController(text: currentAmount.toStringAsFixed(2));
    }

    return Container(
      margin: EdgeInsets.only(
        left: inBinder ? 16 : 0,
        right: inBinder ? 16 : 0,
        bottom: inBinder ? 12 : 0,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isIncluded
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
          : theme.colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasBoost
            ? Colors.amber.shade700
            : (isIncluded
              ? theme.colorScheme.primary.withValues(alpha: 0.5)
              : Colors.grey.withValues(alpha: 0.3)),
          width: hasBoost ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: Icon + Name + Horizon Progress
          Row(
            children: [
              envelope.getIconWidget(theme, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  envelope.name,
                  style: fontProvider.getTextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (envelope.targetAmount != null)
                HorizonProgress(
                  percentage: (envelope.currentAmount / envelope.targetAmount!).clamp(0.0, 1.0),
                  size: 50,
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Detail rows: Current, Cash Flow, Horizon
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current Amount
              _buildDetailRow('💰', 'Current', currency.format(envelope.currentAmount), theme, fontProvider),
              const SizedBox(height: 8),

              // Cash Flow Amount (editable with calculator)
              Row(
                children: [
                  const Text('⚡', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    'Cash Flow',
                    style: fontProvider.getTextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SmartTextField(
                      controller: _controllers[envelope.id]!,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      suffix: IconButton(
                        icon: const Icon(Icons.calculate, size: 20),
                        onPressed: () async {
                          final result = await CalculatorHelper.showCalculator(context);
                          if (result != null) {
                            final newAmount = double.tryParse(result) ?? 0.0;
                            setState(() {
                              _controllers[envelope.id]!.text = newAmount.toStringAsFixed(2);
                              if (newAmount > 0) {
                                _tempAllocations[envelope.id] = newAmount;
                              } else {
                                _tempAllocations.remove(envelope.id);
                              }
                            });
                          }
                        },
                      ),
                      onChanged: (value) {
                        final newAmount = double.tryParse(value) ?? 0.0;
                        setState(() {
                          if (newAmount > 0) {
                            _tempAllocations[envelope.id] = newAmount;
                          } else {
                            _tempAllocations.remove(envelope.id);
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Horizon (if exists)
              if (envelope.targetAmount != null)
                _buildDetailRow('🎯', 'Horizon', currency.format(envelope.targetAmount!), theme, fontProvider),
            ],
          ),

          const SizedBox(height: 12),

          // Temporary allocation indicator
          if (_tempAllocations.containsKey(envelope.id) &&
              _tempAllocations[envelope.id] != (envelope.cashFlowAmount ?? 0.0))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_note, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Temporary: ${currency.format(_tempAllocations[envelope.id]!)}',
                    style: fontProvider.getTextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(${_tempAllocations[envelope.id]! > (envelope.cashFlowAmount ?? 0.0) ? '+' : ''}${currency.format(_tempAllocations[envelope.id]! - (envelope.cashFlowAmount ?? 0.0))})',
                    style: fontProvider.getTextStyle(
                      fontSize: 11,
                      color: _tempAllocations[envelope.id]! > (envelope.cashFlowAmount ?? 0.0)
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),

          if (_tempAllocations.containsKey(envelope.id) &&
              _tempAllocations[envelope.id] != (envelope.cashFlowAmount ?? 0.0))
            const SizedBox(height: 12),

          // Boost checkbox (only for envelopes with horizons)
          if (envelope.targetAmount != null) ...[
            Row(
              children: [
                Checkbox(
                  value: _boostExpanded[envelope.id] ?? false,
                  onChanged: (value) {
                    // Don't allow boost if amount was decreased
                    if (value == true && _tempAllocations.containsKey(envelope.id)) {
                      final tempAmount = _tempAllocations[envelope.id]!;
                      final originalAmount = envelope.cashFlowAmount ?? 0.0;
                      if (tempAmount < originalAmount) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cannot boost when decreasing cash flow amount'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                    }

                    setState(() {
                      _boostExpanded[envelope.id] = value ?? false;
                      if (!value!) {
                        _horizonBoosts.remove(envelope.id);
                      }
                    });
                  },
                ),
                const Text('🚀 Boost?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),

            // Boost slider (inline expansion)
            if (_boostExpanded[envelope.id] ?? false) ...[
              const SizedBox(height: 8),
              _buildBoostSlider(envelope, theme, fontProvider, currency),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String emoji, String label, String value, ThemeData theme, FontProvider fontProvider) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        Text(
          label,
          style: fontProvider.getTextStyle(
            fontSize: 14,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: fontProvider.getTextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildEnvelopeStat(String label, String value, ThemeData theme, FontProvider fontProvider, {bool isEditable = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: fontProvider.getTextStyle(
                fontSize: 10,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            if (isEditable) ...[
              const SizedBox(width: 4),
              Icon(Icons.edit, size: 12, color: theme.colorScheme.primary),
            ],
          ],
        ),
        Text(
          value,
          style: fontProvider.getTextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildBoostSlider(Envelope envelope, ThemeData theme, FontProvider fontProvider, NumberFormat currency) {
    final boostPercent = _horizonBoosts[envelope.id] ?? 0.0;
    final availableFuel = _provider.externalInflow - _tempAllocations.values.fold(0.0, (sum, amt) => sum + amt);
    final boostAmount = availableFuel * boostPercent;

    // Calculate days saved
    final monthlyVelocity = envelope.cashFlowAmount ?? 0.0;
    int daysSaved = 0;
    if (envelope.targetAmount != null && monthlyVelocity > 0) {
      final currentStuffed = _tempAllocations[envelope.id] ?? 0.0;
      final oldDays = (envelope.targetAmount! - (envelope.currentAmount + currentStuffed)) / (monthlyVelocity / 30.44);
      final newDays = (envelope.targetAmount! - (envelope.currentAmount + currentStuffed + boostAmount)) / (monthlyVelocity / 30.44);
      daysSaved = (oldDays - newDays).round().clamp(0, 999999);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade50, Colors.orange.shade50],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade700),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '${(boostPercent * 100).toInt()}%',
                style: fontProvider.getTextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade900,
                ),
              ),
              const Spacer(),
              if (boostAmount > 0)
                Text(
                  currency.format(boostAmount),
                  style: fontProvider.getTextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                  ),
                ),
            ],
          ),
          Slider(
            value: boostPercent,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            activeColor: Colors.amber.shade700,
            inactiveColor: Colors.grey.shade300,
            onChanged: (value) {
              setState(() {
                _horizonBoosts[envelope.id] = value;
              });
            },
          ),
          if (daysSaved > 0)
            Text(
              '🔥 $daysSaved days closer',
              style: fontProvider.getTextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showCalculatorForEnvelope(Envelope envelope) async {
    final result = await CalculatorHelper.showCalculator(context);

    if (result != null) {
      final newAmount = double.tryParse(result) ?? 0.0;
      setState(() {
        if (newAmount > 0) {
          _tempAllocations[envelope.id] = newAmount;
        } else {
          _tempAllocations.remove(envelope.id);
        }
      });
    }
  }

  Future<void> _showAddItemModal() async {
    // Get all envelopes and binders from provider
    final allEnvelopes = _provider.allEnvelopes;
    final allBinders = _provider.allBinders;

    // Track what's already displayed
    final displayedEnvelopes = _provider.allocations.keys.toSet();
    final displayedBinders = _expandedBinderIds.toSet();

    final result = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return AddToPayDayModal(
          allEnvelopes: allEnvelopes,
          allGroups: allBinders,
          alreadyDisplayedEnvelopes: displayedEnvelopes,
          alreadyDisplayedBinders: displayedBinders,
        );
      },
    );

    if (result != null && result is PayDayAddition) {
      setState(() {
        if (result.binderId != null) {
          // Add binder - expand it to show its envelopes
          _expandedBinderIds.add(result.binderId!);
        } else if (result.envelopeId != null) {
          // Add individual envelope with default cash flow amount
          final envelope = allEnvelopes.firstWhere((e) => e.id == result.envelopeId);
          if (envelope.cashFlowEnabled && envelope.cashFlowAmount != null) {
            _tempAllocations[envelope.id] = envelope.cashFlowAmount!;
          }
        }
      });
    }
  }

  // ==========================================================================
  // PHASE 3: WATERFALL EXECUTION
  // ==========================================================================

  Future<void> _startWaterfallAnimation() async {
    setState(() {
      _currentPhaseUI = CockpitPhaseUI.waterfallExecution;
      _waterfallStage = WaterfallStage.accountFill;
      _stuffingProgress.clear();
      _accountFillProgress = 0.0;
      _currentEnvelopeIndex = -1;
    });

    // Account fill (if account mode)
    if (_provider.isAccountMode && _provider.defaultAccount != null) {
      await _animateAccountFill();
    }

    // Silver stage (autopilot)
    await _animateSilverAutopilot();

    // Gold stage (boosts)
    if (_horizonBoosts.values.any((v) => v > 0)) {
      setState(() {
        _waterfallStage = WaterfallStage.goldBoost;
      });

      // 2-second pause with gold stage message
      await Future.delayed(const Duration(milliseconds: 2000));

      await _animateGoldBoosts();
    }

    // Complete
    setState(() {
      _waterfallStage = WaterfallStage.complete;
      _currentPhaseUI = CockpitPhaseUI.futureRecalibrated;
    });
  }

  Future<void> _animateAccountFill() async {
    for (int i = 0; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 150));
      if (mounted) {
        setState(() {
          _accountFillProgress = i / 10.0;
        });
      }
    }
  }

  Future<void> _animateSilverAutopilot() async {
    setState(() {
      _waterfallStage = WaterfallStage.silverAutopilot;
    });

    final envelopesToStuff = _provider.allEnvelopes.where((e) => _tempAllocations.containsKey(e.id)).toList();

    for (int idx = 0; idx < envelopesToStuff.length; idx++) {
      final env = envelopesToStuff[idx];
      final targetAmount = _tempAllocations[env.id]!;

      setState(() {
        _currentEnvelopeIndex = idx;
      });

      // Auto-scroll to current envelope
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          idx * 180.0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }

      // Animate filling
      for (int step = 0; step <= 10; step++) {
        await Future.delayed(const Duration(milliseconds: 150));
        if (mounted) {
          setState(() {
            _stuffingProgress[env.id] = (step / 10.0) * targetAmount;
          });
        }
      }
    }
  }

  Future<void> _animateGoldBoosts() async {
    final boostedEnvelopes = _horizonBoosts.entries.where((e) => e.value > 0).toList();
    final availableFuel = _provider.externalInflow - _tempAllocations.values.fold(0.0, (sum, amt) => sum + amt);

    for (final entry in boostedEnvelopes) {
      final envelopeId = entry.key;
      final boostPercent = entry.value;
      final boostAmount = availableFuel * boostPercent;
      final currentStuffed = _stuffingProgress[envelopeId] ?? 0.0;

      // Find index
      final envelopesToStuff = _provider.allEnvelopes.where((e) => _tempAllocations.containsKey(e.id)).toList();
      final idx = envelopesToStuff.indexWhere((e) => e.id == envelopeId);

      if (idx != -1) {
        setState(() {
          _currentEnvelopeIndex = idx;
        });

        // Animate gold boost
        for (int step = 0; step <= 10; step++) {
          await Future.delayed(const Duration(milliseconds: 200));
          if (mounted) {
            setState(() {
              _stuffingProgress[envelopeId] = currentStuffed + (step / 10.0) * boostAmount;
            });
          }
        }
      }
    }
  }

  Widget _buildPhase3WaterfallExecution() {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);

    return Column(
      children: [
        // Account fill display (if account mode)
        if (_provider.isAccountMode && _provider.defaultAccount != null && _waterfallStage == WaterfallStage.accountFill) ...[
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Depositing to ${_provider.defaultAccount!.name}',
                    style: fontProvider.getTextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: 200,
                    child: LinearProgressIndicator(
                      value: _accountFillProgress,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        // Envelope list
        if (_waterfallStage == WaterfallStage.silverAutopilot || _waterfallStage == WaterfallStage.goldBoost) ...[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _waterfallStage == WaterfallStage.goldBoost
                ? '✨ Gold Boost Active'
                : '⚡ Filling Envelopes',
              style: fontProvider.getTextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _waterfallStage == WaterfallStage.goldBoost
                  ? Colors.amber.shade700
                  : theme.colorScheme.primary,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _provider.allEnvelopes.where((e) => _tempAllocations.containsKey(e.id)).length,
              itemBuilder: (context, index) {
                final envelope = _provider.allEnvelopes.where((e) => _tempAllocations.containsKey(e.id)).toList()[index];
                final isActive = _currentEnvelopeIndex == index;
                final isGoldStage = _waterfallStage == WaterfallStage.goldBoost && _horizonBoosts.containsKey(envelope.id);
                final currentStuffed = _stuffingProgress[envelope.id] ?? 0.0;

                return _buildWaterfallEnvelopeTile(envelope, isActive, isGoldStage, currentStuffed, theme, fontProvider);
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWaterfallEnvelopeTile(Envelope envelope, bool isActive, bool isGoldStage, double currentStuffed, ThemeData theme, FontProvider fontProvider) {
    final locale = Provider.of<LocaleProvider>(context);
    final currency = NumberFormat.currency(symbol: locale.currencySymbol, decimalDigits: 0);
    final progress = envelope.targetAmount != null && envelope.targetAmount! > 0
      ? ((envelope.currentAmount + currentStuffed) / envelope.targetAmount!).clamp(0.0, 1.0)
      : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isGoldStage
          ? Colors.amber.shade100.withValues(alpha: 0.5)
          : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
            ? (isGoldStage ? Colors.amber.shade700 : theme.colorScheme.primary)
            : Colors.grey.shade300,
          width: isActive ? 3 : 1,
        ),
        boxShadow: isGoldStage && isActive
          ? [
              BoxShadow(
                color: Colors.amber.shade400.withValues(alpha: 0.6),
                blurRadius: 20,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.amber.shade600.withValues(alpha: 0.3),
                blurRadius: 40,
                spreadRadius: 5,
              ),
            ]
          : null,
      ),
      child: Row(
        children: [
          envelope.getIconWidget(theme, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  envelope.name,
                  style: fontProvider.getTextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isGoldStage)
                  Text(
                    '✨ GOLD BOOST ACTIVE',
                    style: fontProvider.getTextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade900,
                    ),
                  ),
                const SizedBox(height: 8),
                // Animated stuffing progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: currentStuffed / (_tempAllocations[envelope.id] ?? 1),
                    minHeight: 12,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(
                      isGoldStage ? Colors.amber.shade600 : theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${currency.format(currentStuffed)} / ${currency.format(_tempAllocations[envelope.id] ?? 0)}',
                  style: fontProvider.getTextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (envelope.targetAmount != null)
            HorizonProgress(percentage: progress, size: 50),
        ],
      ),
    );
  }

  // ==========================================================================
  // PHASE 4: FUTURE RECALIBRATED
  // ==========================================================================

  Widget _buildPhase4FutureRecalibrated() {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),

          Text(
            '🎉 Mission Complete!',
            style: fontProvider.getTextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          Text(
            'Your Horizons are now closer',
            style: fontProvider.getTextStyle(
              fontSize: 20,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),

          const Spacer(),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 20),
              ),
              child: Text(
                'Done',
                style: fontProvider.getTextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
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

class _InfiniteSunHeader extends StatefulWidget {
  @override
  State<_InfiniteSunHeader> createState() => _InfiniteSunHeaderState();
}

class _InfiniteSunHeaderState extends State<_InfiniteSunHeader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
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
        return Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.amber.shade300,
                Colors.orange.shade400,
                Colors.deepOrange.shade500,
              ],
              stops: [0.3, 0.6, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withValues(alpha: 0.5 + 0.3 * math.sin(_controller.value * 2 * math.pi)),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
        );
      },
    );
  }
}
