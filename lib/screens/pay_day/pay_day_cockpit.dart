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
    final binderHorizonValue = binderEnvelopes.where((e) => e.targetAmount != null).fold(0.0, (sum, env) =>
      sum + (env.targetAmount ?? 0.0)
    );

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
                          '${currency.format(binderCashFlow)} cash flow • $binderHorizon horizons (${currency.format(binderHorizonValue)})',
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
    final boostPercentage = _horizonBoosts[envelope.id] ?? 0.0;
    final hasBoost = boostPercentage > 0;
    final isExpanded = _expandedEnvelopeIds[envelope.id] ?? false;

    // Calculate boost amount for THIS envelope only
    final boostAmount = currentAmount * boostPercentage;
    final totalAllocation = currentAmount + boostAmount;

    return Container(
      margin: EdgeInsets.only(
        left: inBinder ? 16 : 0,
        right: inBinder ? 16 : 0,
        bottom: inBinder ? 12 : 0,
      ),
      padding: const EdgeInsets.all(12),
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
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Compact header row: Checkbox + Icon + Name + Amount + Edit + Expand
          InkWell(
            onTap: () {
              setState(() {
                _expandedEnvelopeIds[envelope.id] = !isExpanded;
              });
            },
            child: Row(
              children: [
                // Checkbox for selection
                Checkbox(
                  value: isIncluded,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _tempAllocations[envelope.id] = envelope.cashFlowAmount ?? 0.0;
                      } else {
                        _tempAllocations.remove(envelope.id);
                        _horizonBoosts.remove(envelope.id);
                        _expandedEnvelopeIds[envelope.id] = false;
                      }
                    });
                  },
                ),
                const SizedBox(width: 8),
                envelope.getIconWidget(theme, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        envelope.name,
                        style: fontProvider.getTextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            currency.format(currentAmount),
                            style: fontProvider.getTextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (hasBoost) ...[
                            const SizedBox(width: 4),
                            Text(
                              '+ ${currency.format(boostAmount)}',
                              style: fontProvider.getTextStyle(
                                fontSize: 13,
                                color: Colors.amber.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Edit button
                if (isIncluded)
                  IconButton(
                    icon: Icon(Icons.edit, size: 20, color: theme.colorScheme.primary),
                    onPressed: () => _showEnvelopeSettingsModal(envelope, currency),
                    tooltip: 'Edit amount',
                  ),
                // Horizon indicator
                if (envelope.targetAmount != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: HorizonProgress(
                      percentage: ((envelope.currentAmount + totalAllocation) / envelope.targetAmount!).clamp(0.0, 1.0),
                      size: 40,
                    ),
                  ),
                // Expand/collapse indicator
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ],
            ),
          ),

          // Expanded details
          if (isExpanded) ...[
            const Divider(height: 16),

            // Detail rows in compact format
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                children: [
                  // Current Balance
                  _buildCompactDetailRow(
                    '💰',
                    'Current',
                    currency.format(envelope.currentAmount),
                    theme,
                    fontProvider,
                  ),
                  const SizedBox(height: 8),

                  // Horizon Target (if exists)
                  if (envelope.targetAmount != null) ...[
                    _buildCompactDetailRow(
                      '🎯',
                      'Horizon',
                      currency.format(envelope.targetAmount!),
                      theme,
                      fontProvider,
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Temporary change indicator
                  if (_tempAllocations[envelope.id] != (envelope.cashFlowAmount ?? 0.0))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_note, size: 14, color: Colors.blue.shade700),
                          const SizedBox(width: 6),
                          Text(
                            'Temporary change: ${_tempAllocations[envelope.id]! > (envelope.cashFlowAmount ?? 0.0) ? '+' : ''}${currency.format(_tempAllocations[envelope.id]! - (envelope.cashFlowAmount ?? 0.0))}',
                            style: fontProvider.getTextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (_tempAllocations[envelope.id] != (envelope.cashFlowAmount ?? 0.0))
                    const SizedBox(height: 12),

                  // Boost section (only for horizons)
                  if (envelope.targetAmount != null) ...[
                    Row(
                      children: [
                        Checkbox(
                          value: hasBoost,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _horizonBoosts[envelope.id] = 0.5; // Start at 50%
                              } else {
                                _horizonBoosts.remove(envelope.id);
                              }
                            });
                          },
                        ),
                        Text(
                          '🚀 Boost',
                          style: fontProvider.getTextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    // Boost controls (when active)
                    if (hasBoost) ...[
                      const SizedBox(height: 8),
                      _buildBoostSlider(envelope, theme, fontProvider, currency),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactDetailRow(String emoji, String label, String value, ThemeData theme, FontProvider fontProvider) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Text(
          label,
          style: fontProvider.getTextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: fontProvider.getTextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildBoostSlider(Envelope envelope, ThemeData theme, FontProvider fontProvider, NumberFormat currency) {
    final boostPercent = _horizonBoosts[envelope.id] ?? 0.0;
    final currentAmount = _tempAllocations[envelope.id] ?? 0.0;
    final boostAmount = currentAmount * boostPercent;

    // Calculate days to target (baseline and with boost)
    final monthlyVelocity = envelope.cashFlowAmount ?? 0.0;
    int baselineDays = 0;
    int boostedDays = 0;
    int daysSaved = 0;

    if (envelope.targetAmount != null && monthlyVelocity > 0) {
      final remainingWithoutBoost = envelope.targetAmount! - (envelope.currentAmount + currentAmount);
      final remainingWithBoost = envelope.targetAmount! - (envelope.currentAmount + currentAmount + boostAmount);

      baselineDays = (remainingWithoutBoost / (monthlyVelocity / 30.44)).round().clamp(0, 999999);
      boostedDays = (remainingWithBoost / (monthlyVelocity / 30.44)).round().clamp(0, 999999);
      daysSaved = (baselineDays - boostedDays).clamp(0, 999999);
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
          // Show baseline and boosted days
          if (baselineDays > 0)
            Column(
              children: [
                Text(
                  'Baseline: $baselineDays days',
                  style: fontProvider.getTextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
                if (daysSaved > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '🔥 $daysSaved days closer → $boostedDays days',
                    style: fontProvider.getTextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange,
                    ),
                  ),
                ],
              ],
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
    final locale = Provider.of<LocaleProvider>(context, listen: false);
    final currentAmount = _tempAllocations[envelope.id] ?? envelope.cashFlowAmount ?? 0.0;
    final amountController = TextEditingController(text: currentAmount.toStringAsFixed(2));

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Edit Cash Flow Amount',
                    style: fontProvider.getTextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Input field with calculator chip
                  SmartTextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: fontProvider.getTextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                    decoration: InputDecoration(
                      prefixText: '${locale.currencySymbol} ',
                      prefixStyle: fontProvider.getTextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
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
                            if (result != null) {
                              amountController.text = result;
                            }
                          },
                          tooltip: 'Open Calculator',
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Info note about temporary changes
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Changes are temporary for this pay day only. Make permanent changes in envelope settings.',
                            style: fontProvider.getTextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final newAmount = double.tryParse(amountController.text.replaceAll(',', '')) ?? 0.0;
                    if (newAmount > 0) {
                      setState(() {
                        _tempAllocations[envelope.id] = newAmount;
                      });
                    }
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
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
                  // Create a copy of temp allocations to avoid concurrent modification
                  final allocationsToApply = Map<String, double>.from(_tempAllocations);

                  // Apply boosts to the copy (individual boost per envelope)
                  final boostsToApply = Map<String, double>.from(_horizonBoosts);
                  for (final entry in boostsToApply.entries) {
                    final envelopeId = entry.key;
                    final percentage = entry.value;
                    final currentAllocation = allocationsToApply[envelopeId] ?? 0.0;
                    final boostAmount = currentAllocation * percentage;

                    if (boostAmount > 0) {
                      allocationsToApply[envelopeId] = currentAllocation + boostAmount;
                    }
                  }

                  // First, clear all provider allocations to start fresh
                  final allEnvelopeIds = _provider.allEnvelopes.map((e) => e.id).toList();
                  for (final id in allEnvelopeIds) {
                    if (_provider.allocations.containsKey(id) && !allocationsToApply.containsKey(id)) {
                      _provider.updateEnvelopeAllocation(id, 0.0);
                    }
                  }

                  // Now sync allocations (with boosts) back to provider
                  for (final entry in allocationsToApply.entries) {
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

    // Get envelopes being stuffed (from allocations)
    final envelopesBeingStuffed = provider.allocations.entries
        .map((e) => provider.allEnvelopes.firstWhere((env) => env.id == e.key))
        .where((env) => env.targetAmount != null) // Only horizons
        .toList();

    return Column(
      children: [
        // Light Source (The Account/Pool) at the top
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                Colors.amber.shade100,
                Colors.yellow.shade50,
                theme.colorScheme.surface,
              ],
            ),
          ),
          child: Column(
            children: [
              // Animated glowing money icon
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 1500),
                tween: Tween(begin: 0.8, end: 1.0),
                curve: Curves.easeInOut,
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withValues(alpha: 0.5),
                            blurRadius: 40 * scale,
                            spreadRadius: 10 * scale,
                          ),
                        ],
                      ),
                      child: const Text(
                        '💡',
                        style: TextStyle(fontSize: 60),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Text(
                provider.isAccountMode
                    ? 'Light from ${provider.defaultAccount?.name ?? "Account"}'
                    : 'Light from Horizon Pool',
                style: fontProvider.getTextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                currency.format(provider.externalInflow),
                style: fontProvider.getTextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),

        // Waterfall effect - light flowing down to horizons
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: envelopesBeingStuffed.length,
            itemBuilder: (context, index) {
              final envelope = envelopesBeingStuffed[index];
              final stuffedAmount = provider.stuffingProgress[envelope.id] ?? 0.0;
              final targetAmount = provider.allocations[envelope.id] ?? 0.0;
              final isStuffed = stuffedAmount >= targetAmount;

              return TweenAnimationBuilder<double>(
                key: ValueKey(envelope.id),
                duration: Duration(milliseconds: 500 + (index * 200)),
                tween: Tween(begin: 0.0, end: isStuffed ? 1.0 : 0.0),
                curve: Curves.easeInOut,
                builder: (context, progress, child) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      children: [
                        // Light beam flowing down
                        if (progress > 0)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: 40,
                            width: 4,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.amber.shade300.withValues(alpha: 0.8),
                                  Colors.amber.shade500.withValues(alpha: progress),
                                ],
                              ),
                            ),
                          ),

                        // Horizon being filled
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isStuffed
                                ? theme.colorScheme.primaryContainer
                                : theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isStuffed
                                  ? Colors.amber.shade700
                                  : theme.colorScheme.outlineVariant,
                              width: isStuffed ? 2 : 1,
                            ),
                            boxShadow: isStuffed
                                ? [
                                    BoxShadow(
                                      color: Colors.amber.shade300.withValues(alpha: 0.5),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : [],
                          ),
                          child: Row(
                            children: [
                              envelope.getIconWidget(theme, size: 40),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      envelope.name,
                                      style: fontProvider.getTextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    // Filling progress bar
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: (stuffedAmount / targetAmount).clamp(0.0, 1.0),
                                        minHeight: 6,
                                        backgroundColor: Colors.grey.shade200,
                                        valueColor: AlwaysStoppedAnimation(
                                          Colors.amber.shade600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    currency.format(stuffedAmount),
                                    style: fontProvider.getTextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isStuffed
                                          ? Colors.green.shade700
                                          : theme.colorScheme.primary,
                                    ),
                                  ),
                                  if (isStuffed)
                                    const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                      size: 24,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
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
