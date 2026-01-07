// lib/screens/pay_day/pay_day_cockpit.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../providers/pay_day_cockpit_provider.dart';
import '../../providers/font_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/envelope_repo.dart';
import '../../services/group_repo.dart';
import '../../services/account_repo.dart';
import '../../models/envelope.dart';
import '../../models/envelope_group.dart';
import '../../widgets/common/smart_text_field.dart';
import '../../widgets/horizon_progress.dart';
import '../../utils/calculator_helper.dart';
import 'add_to_pay_day_modal.dart';

class PayDayCockpit extends StatefulWidget {
  const PayDayCockpit({
    super.key,
    required this.repo,
    required this.groupRepo,
    required this.accountRepo,
  });

  final EnvelopeRepo repo;
  final GroupRepo groupRepo;
  final AccountRepo accountRepo;

  @override
  State<PayDayCockpit> createState() => _PayDayCockpitState();
}

class _PayDayCockpitState extends State<PayDayCockpit> {
  late PayDayCockpitProvider _provider;
  final TextEditingController _amountController = TextEditingController(text: '0.00');
  final FocusNode _amountFocus = FocusNode();
  Timer? _debounceTimer;

  // Horizon boost tracking
  final Map<String, double> _horizonBoosts = {}; // envelopeId -> percentage (0.0-1.0)
  final Map<String, bool> _boostExpanded = {}; // envelopeId -> expanded state

  // Temporary allocations (edits for this pay day only)
  final Map<String, double> _tempAllocations = {}; // envelopeId -> amount

  // Collapsible binders
  final Set<String> _expandedBinderIds = {};

  // Collapsible envelopes within binders (envelopeId -> isExpanded)
  final Map<String, bool> _expandedEnvelopeIds = {};

  @override
  void initState() {
    super.initState();
    _provider = PayDayCockpitProvider(
      envelopeRepo: widget.repo,
      groupRepo: widget.groupRepo,
      accountRepo: widget.accountRepo,
      userId: widget.repo.currentUserId,
    );
    _provider.initialize().then((_) {
      if (_provider.externalInflow > 0) {
        setState(() {
          _amountController.text = _provider.externalInflow.toStringAsFixed(2);
        });
      }
      // Initialize temp allocations when entering Phase 2
      _syncTempAllocations();
    });

    // Listen for phase changes to sync temp allocations
    _provider.addListener(_onProviderUpdate);
  }

  void _onProviderUpdate() {
    if (_provider.currentPhase == CockpitPhase.strategyReview) {
      _syncTempAllocations();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocus.dispose();
    _debounceTimer?.cancel();
    _provider.removeListener(_onProviderUpdate);
    _provider.dispose();
    super.dispose();
  }

  void _onAmountChanged(String value) {
    // Debounce the updates (50ms as specified)
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 50), () {
      final amount = double.tryParse(value.replaceAll(',', '')) ?? 0.0;
      _provider.updateExternalInflow(amount);
    });
  }

  void _syncTempAllocations() {
    if (!mounted) return;

    setState(() {
      // Copy provider allocations to temp allocations
      _tempAllocations.clear();
      _tempAllocations.addAll(_provider.allocations);
    });
  }

  // ============================================================================
  // CALCULATION HELPERS
  // ============================================================================

  double _calculateTotalCashFlow() {
    return _tempAllocations.values.fold(0.0, (sum, amount) => sum + amount);
  }

  double _calculateTotalBoost() {
    double total = 0.0;
    for (final entry in _horizonBoosts.entries) {
      final envelopeId = entry.key;
      final percentage = entry.value;
      final baseAmount = _tempAllocations[envelopeId] ?? 0.0;
      total += baseAmount * percentage;
    }
    return total;
  }

  double _calculateReserve() {
    final totalCashFlow = _calculateTotalCashFlow();
    final totalBoost = _calculateTotalBoost();
    return _provider.externalInflow - totalCashFlow - totalBoost;
  }

  // ============================================================================
  // PHASE 2 UI HELPERS
  // ============================================================================

  Widget _buildTopStatsBar(ThemeData theme, FontProvider fontProvider) {
    final locale = Provider.of<LocaleProvider>(context);
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);

    final totalCashFlow = _calculateTotalCashFlow();
    final totalBoost = _calculateTotalBoost();
    final reserve = _calculateReserve();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatChip(
            '💰',
            'Income',
            currency.format(_provider.externalInflow),
            theme.colorScheme.primary,
            fontProvider,
          ),
          _buildStatChip(
            '🔄',
            'Cash Flow',
            currency.format(totalCashFlow),
            theme.colorScheme.secondary,
            fontProvider,
          ),
          _buildStatChip(
            '🚀',
            'Boost',
            currency.format(totalBoost),
            Colors.amber.shade700,
            fontProvider,
          ),
          _buildStatChip(
            '🏦',
            'Reserve',
            currency.format(reserve),
            reserve < 0 ? Colors.red.shade700 : Colors.green.shade700,
            fontProvider,
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(
    String emoji,
    String label,
    String value,
    Color color,
    FontProvider fontProvider,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          emoji,
          style: const TextStyle(fontSize: 20),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: fontProvider.getTextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: fontProvider.getTextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
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
        e.groupId == b.id && _tempAllocations.containsKey(e.id)
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
    final binderEnvelopes = _provider.allEnvelopes.where((e) => e.groupId == binder.id && _tempAllocations.containsKey(e.id)).toList();

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
                          '${currency.format(binderCashFlow)} cash flow • $binderHorizon horizons',
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
      e.groupId == null && _tempAllocations.containsKey(e.id)
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
    final isExpanded = inBinder ? (_expandedEnvelopeIds[envelope.id] ?? false) : true;

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
          // Header row: Checkbox + Icon + Name + Cash Flow + Expand/Collapse (if in binder)
          Row(
            children: [
              // Large checkbox for selection
              Transform.scale(
                scale: 1.3,
                child: Checkbox(
                  value: isIncluded,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        // Add envelope with its cash flow amount
                        _tempAllocations[envelope.id] = envelope.cashFlowAmount ?? 0.0;
                      } else {
                        // Remove envelope
                        _tempAllocations.remove(envelope.id);
                        _horizonBoosts.remove(envelope.id);
                        _boostExpanded.remove(envelope.id);
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              envelope.getIconWidget(theme, size: 40),
              const SizedBox(width: 12),
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
                    // Show cash flow in collapsed state
                    if (!isExpanded) ...[
                      const SizedBox(height: 4),
                      Text(
                        currency.format(currentAmount),
                        style: fontProvider.getTextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Expand/collapse button for envelopes in binders
              if (inBinder)
                IconButton(
                  icon: Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: theme.colorScheme.primary,
                  ),
                  onPressed: () {
                    setState(() {
                      _expandedEnvelopeIds[envelope.id] = !isExpanded;
                    });
                  },
                  tooltip: isExpanded ? 'Collapse' : 'Expand',
                ),
              // Horizon progress for non-binder envelopes or expanded state
              if (!inBinder && envelope.targetAmount != null)
                HorizonProgress(
                  percentage: (envelope.currentAmount / envelope.targetAmount!).clamp(0.0, 1.0),
                  size: 50,
                ),
            ],
          ),

          // Expanded details (only show when expanded)
          if (isExpanded) ...[
            const SizedBox(height: 16),

          // Detail rows: Current, Cash Flow (with settings button), Horizon
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current Amount
              _buildDetailRow('💰', 'Current', currency.format(envelope.currentAmount), theme, fontProvider),
              const SizedBox(height: 8),

              // Cash Flow Amount (non-editable, with settings button)
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
                  const Spacer(),
                  Text(
                    currency.format(currentAmount),
                    style: fontProvider.getTextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.settings, size: 20, color: theme.colorScheme.primary),
                    onPressed: () => _showEnvelopeSettingsModal(envelope, currency),
                    tooltip: 'Edit amount',
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
          ], // Close if (isExpanded)
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

  Widget _buildBoostSlider(Envelope envelope, ThemeData theme, FontProvider fontProvider, NumberFormat currency) {
    final boostPercent = _horizonBoosts[envelope.id] ?? 0.0;
    final totalCashFlow = _calculateTotalCashFlow();
    final totalBoost = _calculateTotalBoost();
    final availableFuel = _provider.externalInflow - totalCashFlow - totalBoost;
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

  Widget _buildAddItemButton(ThemeData theme, FontProvider fontProvider) {
    return OutlinedButton.icon(
      onPressed: _showAddItemModal,
      icon: const Icon(Icons.add_circle_outline),
      label: Text(
        'Add Item',
        style: fontProvider.getTextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Future<void> _showAddItemModal() async {
    // Get already displayed items
    final alreadyDisplayedEnvelopes = _tempAllocations.keys.toSet();
    final alreadyDisplayedBinders = _expandedBinderIds.toSet();

    final result = await showModalBottomSheet<PayDayAddition>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddToPayDayModal(
        allEnvelopes: _provider.allEnvelopes,
        allGroups: _provider.allBinders,
        alreadyDisplayedEnvelopes: alreadyDisplayedEnvelopes,
        alreadyDisplayedBinders: alreadyDisplayedBinders,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        if (result.binderId != null) {
          // Add binder and expand it
          _expandedBinderIds.add(result.binderId!);

          // Add all envelopes in this binder with their cash flow amounts
          final binderEnvelopes = _provider.allEnvelopes.where((e) => e.groupId == result.binderId);
          for (final env in binderEnvelopes) {
            if (env.cashFlowEnabled && env.cashFlowAmount != null && env.cashFlowAmount! > 0) {
              _tempAllocations[env.id] = env.cashFlowAmount!;
            }
          }
        } else if (result.envelopeId != null) {
          // Add individual envelope
          final envelope = _provider.allEnvelopes.firstWhere((e) => e.id == result.envelopeId);
          final amount = result.customAmount ?? envelope.cashFlowAmount ?? 0.0;
          if (amount > 0) {
            _tempAllocations[envelope.id] = amount;
          }
        }
      });
    }
  }

  Future<void> _showEnvelopeSettingsModal(Envelope envelope, NumberFormat currency) async {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final currentAmount = _tempAllocations[envelope.id] ?? envelope.cashFlowAmount ?? 0.0;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              envelope.getIconWidget(theme, size: 32),
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
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Cash Flow Amount',
                style: fontProvider.getTextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Current: ${currency.format(currentAmount)}',
                style: fontProvider.getTextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                final result = await CalculatorHelper.showCalculator(context);
                if (result != null && mounted) {
                  final newAmount = double.tryParse(result) ?? 0.0;
                  setState(() {
                    if (newAmount > 0) {
                      _tempAllocations[envelope.id] = newAmount;
                    }
                  });
                }
              },
              icon: const Icon(Icons.calculate),
              label: const Text('Edit Amount'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);

    return ChangeNotifierProvider<PayDayCockpitProvider>.value(
      value: _provider,
      child: Consumer<PayDayCockpitProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return Scaffold(
              backgroundColor: theme.scaffoldBackgroundColor,
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          return Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            appBar: _buildAppBar(theme, fontProvider, provider),
            body: _buildPhaseContent(theme, fontProvider, provider),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    ThemeData theme,
    FontProvider fontProvider,
    PayDayCockpitProvider provider,
  ) {
    String title = 'Pay Day Cockpit';
    switch (provider.currentPhase) {
      case CockpitPhase.amountEntry:
        title = 'External Inflow';
        break;
      case CockpitPhase.strategyReview:
        title = 'Strategy Review';
        break;
      case CockpitPhase.stuffingExecution:
        title = 'Fueling Horizons';
        break;
      case CockpitPhase.success:
        title = 'Future Recalibrated';
        break;
    }

    return AppBar(
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.pop(context),
        tooltip: 'Close',
      ),
      title: Text(
        title,
        style: fontProvider.getTextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildPhaseContent(
    ThemeData theme,
    FontProvider fontProvider,
    PayDayCockpitProvider provider,
  ) {
    switch (provider.currentPhase) {
      case CockpitPhase.amountEntry:
        return _buildPhase1AmountEntry(theme, fontProvider, provider);
      case CockpitPhase.strategyReview:
        return _buildPhase2StrategyReview(theme, fontProvider, provider);
      case CockpitPhase.stuffingExecution:
        return _buildPhase3StuffingExecution(theme, fontProvider, provider);
      case CockpitPhase.success:
        return _buildPhase4Success(theme, fontProvider, provider);
    }
  }

  // ==========================================================================
  // PHASE 1: AMOUNT ENTRY (The Source)
  // ==========================================================================

  Widget _buildPhase1AmountEntry(
    ThemeData theme,
    FontProvider fontProvider,
    PayDayCockpitProvider provider,
  ) {
    final locale = Provider.of<LocaleProvider>(context);
    final media = MediaQuery.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: media.size.height * 0.05),

            // Money icon "Outside the Wall"
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.green.shade300,
                  width: 3,
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    '💰',
                    style: TextStyle(fontSize: 100),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'OUTSIDE THE WALL',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Title
            Text(
              'External Inflow',
              style: fontProvider.getTextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Subtitle
            Text(
              provider.isAccountMode
                  ? 'Money arriving to ${provider.defaultAccount?.name ?? 'your account'}'
                  : 'Money arriving to the Horizon Pool',
              style: fontProvider.getTextStyle(
                fontSize: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 48),

            // Amount input with FittedBox
            SizedBox(
              height: 120,
              child: FittedBox(
                fit: BoxFit.contain,
                child: IntrinsicWidth(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 200,
                      maxWidth: 600,
                    ),
                    child: SmartTextField(
                      controller: _amountController,
                      focusNode: _amountFocus,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: fontProvider.getTextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.secondary,
                      ),
                      onChanged: _onAmountChanged,
                      decoration: InputDecoration(
                    prefixText: '${locale.currencySymbol} ',
                    prefixStyle: fontProvider.getTextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.secondary,
                    ),
                    suffixIcon: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.calculate,
                          color: theme.colorScheme.onPrimary,
                        ),
                        onPressed: () async {
                          final result = await CalculatorHelper.showCalculator(context);
                          if (result != null && mounted) {
                            setState(() {
                              _amountController.text = result;
                              _onAmountChanged(result);
                            });
                          }
                        },
                        tooltip: 'Open Calculator',
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 3,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                  ),
                  onTap: () {
                    _amountController.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: _amountController.text.length,
                    );
                  },
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 48),

            // Mode indicator
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    provider.isAccountMode ? Icons.account_balance : Icons.wallet,
                    color: theme.colorScheme.primary,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      provider.isAccountMode
                          ? 'Account Mode: Money flows to ${provider.defaultAccount?.name ?? 'account'}, then to envelopes'
                          : 'Simple Mode: Money flows directly to Horizon Pool',
                      style: fontProvider.getTextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),

            // Continue button
            FilledButton(
              onPressed: () => provider.proceedToStrategyReview(),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                backgroundColor: theme.colorScheme.secondary,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      'Review Strategy',
                      style: fontProvider.getTextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.arrow_forward,
                    size: 28,
                    color: Colors.white,
                  ),
                ],
              ),
            ),

            if (provider.error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Text(
                  provider.error!,
                  style: TextStyle(
                    color: Colors.red.shade900,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // PHASE 2: STRATEGY REVIEW (The Filter)
  // ==========================================================================

  Widget _buildPhase2StrategyReview(
    ThemeData theme,
    FontProvider fontProvider,
    PayDayCockpitProvider provider,
  ) {
    final locale = Provider.of<LocaleProvider>(context);
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);

    return Column(
      children: [
        // Top Stats Bar (Sticky)
        _buildTopStatsBar(theme, fontProvider),

        // Scrollable content
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Binders section
              ..._buildBindersSection(theme, fontProvider, currency),

              if (_buildBindersSection(theme, fontProvider, currency).isNotEmpty)
                const SizedBox(height: 24),

              // Individual envelopes section
              ..._buildIndividualEnvelopesSection(theme, fontProvider, currency),

              if (_buildIndividualEnvelopesSection(theme, fontProvider, currency).isNotEmpty)
                const SizedBox(height: 24),

              // Add Item button
              _buildAddItemButton(theme, fontProvider),

              const SizedBox(height: 24),

              // Fuel the Horizons button (at bottom of list)
              FilledButton(
                onPressed: () {
                  // First, clear all provider allocations to start fresh
                  final allEnvelopeIds = _provider.allEnvelopes.map((e) => e.id).toList();
                  for (final id in allEnvelopeIds) {
                    if (_provider.allocations.containsKey(id) && !_tempAllocations.containsKey(id)) {
                      _provider.updateEnvelopeAllocation(id, 0.0);
                    }
                  }

                  // Apply boosts to temp allocations first
                  for (final entry in _horizonBoosts.entries) {
                    final envelopeId = entry.key;
                    final percentage = entry.value;
                    final totalCashFlow = _calculateTotalCashFlow();
                    final totalBoost = _calculateTotalBoost();
                    final availableFuel = _provider.externalInflow - totalCashFlow - totalBoost;
                    final boostAmount = availableFuel * percentage;

                    if (boostAmount > 0) {
                      final currentAllocation = _tempAllocations[envelopeId] ?? 0.0;
                      _tempAllocations[envelopeId] = currentAllocation + boostAmount;
                    }
                  }

                  // Now sync temp allocations back to provider (including boosts)
                  for (final entry in _tempAllocations.entries) {
                    _provider.updateEnvelopeAllocation(entry.key, entry.value);
                  }

                  provider.proceedToStuffing();
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  backgroundColor: theme.colorScheme.secondary,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        'Fuel the Horizons',
                        style: fontProvider.getTextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.rocket_launch,
                      size: 28,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // PHASE 3: STUFFING EXECUTION (The Waterfall)
  // ==========================================================================

  Widget _buildPhase3StuffingExecution(
    ThemeData theme,
    FontProvider fontProvider,
    PayDayCockpitProvider provider,
  ) {
    // Start the execution immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (provider.currentPhase == CockpitPhase.stuffingExecution) {
        provider.executeStuffing();
      }
    });

    final locale = Provider.of<LocaleProvider>(context);
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);

    // Calculate total stuffed so far
    double totalStuffed = 0;
    for (final entry in provider.allocations.entries) {
      totalStuffed += entry.value;
    }

    final remaining = provider.externalInflow - totalStuffed;
    final isOverBudget = remaining < 0;

    return Column(
      children: [
        // Waterfall Drainage Header (Sticky)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isOverBudget
                  ? [Colors.red.shade100, Colors.red.shade50]
                  : [
                      Colors.blue.shade50,
                      Colors.green.shade50,
                    ],
            ),
            border: Border(
              bottom: BorderSide(
                color: isOverBudget ? Colors.red.shade700 : Colors.blue.shade600,
                width: 3,
              ),
            ),
          ),
          child: Column(
            children: [
              // Animated draining fuel
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.water_drop,
                    color: isOverBudget ? Colors.red.shade700 : Colors.blue.shade600,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unallocated Fuel',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 600),
                        tween: Tween(begin: provider.externalInflow, end: remaining),
                        builder: (context, value, child) {
                          return Text(
                            currency.format(value),
                            style: fontProvider.getTextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: value < 0 ? Colors.red.shade700 : Colors.green.shade700,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),

              // Progress bar
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (totalStuffed / provider.externalInflow).clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation(
                    isOverBudget ? Colors.red.shade600 : Colors.blue.shade600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Stuffing progress message
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Fueling your horizons...',
            style: fontProvider.getTextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),

        // Progress indicator
        const Expanded(
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // PHASE 4: SUCCESS (Future Recalibrated)
  // ==========================================================================

  Widget _buildPhase4Success(
    ThemeData theme,
    FontProvider fontProvider,
    PayDayCockpitProvider provider,
  ) {
    final locale = Provider.of<LocaleProvider>(context);
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);

    return SafeArea(
      child: Padding(
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
              child: const Text(
                '⏰',
                style: TextStyle(fontSize: 80),
              ),
            ),

            const SizedBox(height: 32),

            // Success message
            Text(
              'Future Recalibrated',
              style: fontProvider.getTextStyle(
                fontSize: 36,
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

            const SizedBox(height: 40),

            // Top 3 horizons moved forward
            if (provider.topHorizons.isNotEmpty) ...[
              Text(
                'Top Horizons Advanced',
                style: fontProvider.getTextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              ...provider.topHorizons.map((impact) => _buildHorizonImpactCard(
                theme,
                fontProvider,
                currency,
                impact,
              )),
            ],

            const Spacer(),

            // Done button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.secondary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Done!',
                  style: fontProvider.getTextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizonImpactCard(
    ThemeData theme,
    FontProvider fontProvider,
    NumberFormat currency,
    EnvelopeHorizonImpact impact,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Text(
            impact.envelope.emoji ?? '📨',
            style: const TextStyle(fontSize: 32),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  impact.envelope.name,
                  style: fontProvider.getTextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '🔥 ${impact.daysSaved} days closer',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Text(
            currency.format(impact.stuffedAmount),
            style: fontProvider.getTextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
