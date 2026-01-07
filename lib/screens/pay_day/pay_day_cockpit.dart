// lib/screens/pay_day/pay_day_cockpit.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math' as math;
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

  // Calculated boosts to pass to Phase 3 (both implicit and explicit)
  final Map<String, double> _calculatedBoosts = {}; // envelopeId -> absolute boost amount

  // Collapsible binders
  final Set<String> _expandedBinderIds = {};

  // Collapsible envelopes within binders (envelopeId -> isExpanded)
  final Map<String, bool> _expandedEnvelopeIds = {};

  // Animation state for waterfall (Phase 3)
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _envelopeKeys = {}; // index -> GlobalKey for auto-scroll
  bool _hasScrolledToTopForGold = false; // Track if we've scrolled to top for gold stage
  double _initialAccountBalance = 0.0; // Store the account balance before Phase 3 starts
  bool _hasStartedExecution = false; // Track if we've started the stuffing execution to prevent duplicates

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

    // Reset execution flag when phase changes away from stuffingExecution
    if (_provider.currentPhase != CockpitPhase.stuffingExecution) {
      _hasStartedExecution = false;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocus.dispose();
    _debounceTimer?.cancel();
    _scrollController.dispose();
    _envelopeKeys.clear();
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

  double _calculateRemainingSource(PayDayCockpitProvider provider) {
    if (provider.isAccountMode && provider.defaultAccount != null) {
      // In account mode: use visual animation progress for account deposit
      final accountDepositProgress = provider.accountDepositProgress;
      final envelopesStuffed = provider.stuffingProgress.values.fold(0.0, (sum, amount) => sum + amount);
      return provider.externalInflow - accountDepositProgress - envelopesStuffed;
    } else {
      // In non-account mode, source decreases as envelopes fill
      final totalStuffedSoFar = provider.stuffingProgress.values.fold(0.0, (sum, amount) => sum + amount);
      return provider.externalInflow - totalStuffedSoFar;
    }
  }

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
    final baselineAmount = envelope.cashFlowAmount ?? 0.0;
    final isDecreasedAmount = currentAmount < baselineAmount;

    // Disable boost slider if amount was decreased
    final boostPercentage = isDecreasedAmount ? 0.0 : (_horizonBoosts[envelope.id] ?? 0.0);
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
                          onChanged: isDecreasedAmount ? null : (value) {
                            setState(() {
                              if (value == true) {
                                _horizonBoosts[envelope.id] = 0.5; // Start at 50%
                              } else {
                                _horizonBoosts.remove(envelope.id);
                              }
                            });
                          },
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '🚀 Boost',
                                style: fontProvider.getTextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDecreasedAmount ? Colors.grey : null,
                                ),
                              ),
                              if (isDecreasedAmount)
                                Text(
                                  'Disabled (amount reduced)',
                                  style: fontProvider.getTextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Boost controls (when active)
                    if (hasBoost && !isDecreasedAmount) ...[
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
    final baselineAmount = envelope.cashFlowAmount ?? 0.0;
    final amountController = TextEditingController(text: currentAmount.toStringAsFixed(2));

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final inputAmount = double.tryParse(amountController.text.replaceAll(',', '')) ?? 0.0;
            final isIncrease = inputAmount > baselineAmount;
            final isDecrease = inputAmount < baselineAmount;
            final difference = inputAmount - baselineAmount;

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
                  const SizedBox(height: 8),
                  // Baseline reference
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Standard Cash Flow:',
                          style: fontProvider.getTextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        Text(
                          currency.format(baselineAmount),
                          style: fontProvider.getTextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
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
                              setModalState(() {
                                amountController.text = result;
                              });
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
                    onChanged: (value) {
                      setModalState(() {}); // Rebuild to update boost indicator
                    },
                    onTap: () {
                      // Select all text on tap
                      amountController.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: amountController.text.length,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  // Boost indicator (if increase)
                  if (isIncrease) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.amber.shade50, Colors.orange.shade50],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade700),
                      ),
                      child: Row(
                        children: [
                          const Text('🚀', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'BOOST DETECTED',
                                  style: fontProvider.getTextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                                Text(
                                  'Extra ${currency.format(difference)} will fuel this envelope in the Gold Boost stage!',
                                  style: fontProvider.getTextStyle(
                                    fontSize: 12,
                                    color: Colors.amber.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  // Warning (if decrease)
                  if (isDecrease) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber, size: 20, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Reduced by ${currency.format(difference.abs())}. Boost slider disabled when reducing cash flow.',
                              style: fontProvider.getTextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
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
                  // Calculate base allocations (what will be shown in silver stage)
                  final baseAllocations = <String, double>{};

                  // Calculate boosts (both explicit slider boosts AND implicit increases)
                  final calculatedBoosts = <String, double>{};

                  for (final entry in _tempAllocations.entries) {
                    final envelopeId = entry.key;
                    final tempAmount = entry.value;
                    final envelope = _provider.allEnvelopes.firstWhere((e) => e.id == envelopeId);
                    final baselineAmount = envelope.cashFlowAmount ?? 0.0;

                    // Check if this is an increase (implicit boost)
                    final implicitBoost = tempAmount > baselineAmount ? (tempAmount - baselineAmount) : 0.0;

                    // Check if there's an explicit boost slider value
                    final hasExplicitBoost = _horizonBoosts.containsKey(envelopeId) && (_horizonBoosts[envelopeId] ?? 0) > 0;

                    if (implicitBoost > 0) {
                      // Implicit boost: base is baseline, boost is the increase
                      baseAllocations[envelopeId] = baselineAmount;
                      calculatedBoosts[envelopeId] = implicitBoost;

                      // If there's ALSO an explicit boost, add it on top
                      if (hasExplicitBoost) {
                        final sliderBoostPercentage = _horizonBoosts[envelopeId]!;
                        final sliderBoostAmount = baselineAmount * sliderBoostPercentage;
                        calculatedBoosts[envelopeId] = implicitBoost + sliderBoostAmount;
                      }
                    } else {
                      // No implicit boost, use temp amount as base
                      baseAllocations[envelopeId] = tempAmount;

                      // Add explicit boost if exists
                      if (hasExplicitBoost) {
                        final sliderBoostPercentage = _horizonBoosts[envelopeId]!;
                        final sliderBoostAmount = tempAmount * sliderBoostPercentage;
                        calculatedBoosts[envelopeId] = sliderBoostAmount;
                      }
                    }
                  }

                  // Store calculated boosts for Phase 3 animation
                  _calculatedBoosts.clear();
                  _calculatedBoosts.addAll(calculatedBoosts);

                  // Sync to provider: base + boost combined
                  final allEnvelopeIds = _provider.allEnvelopes.map((e) => e.id).toList();
                  for (final id in allEnvelopeIds) {
                    if (!baseAllocations.containsKey(id)) {
                      _provider.updateEnvelopeAllocation(id, 0.0);
                    } else {
                      final base = baseAllocations[id] ?? 0.0;
                      final boost = calculatedBoosts[id] ?? 0.0;
                      _provider.updateEnvelopeAllocation(id, base + boost);
                    }
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
    // Start the execution immediately with boosts (only once!)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (provider.currentPhase == CockpitPhase.stuffingExecution &&
          !_hasStartedExecution) {
        _hasStartedExecution = true;
        // Store initial account balance before animation starts
        if (provider.isAccountMode && provider.defaultAccount != null) {
          _initialAccountBalance = provider.defaultAccount!.currentBalance;
        }
        // Use the pre-calculated boosts (both implicit and explicit)
        provider.executeStuffing(boosts: _calculatedBoosts);
      }
    });

    final locale = Provider.of<LocaleProvider>(context);
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);

    // Get current stage
    final isGoldStage = provider.stuffingStage == StuffingStage.gold;
    final isComplete = provider.stuffingStage == StuffingStage.complete;

    // Get envelopes to display based on stage
    List<Envelope> envelopesBeingStuffed;

    if (isGoldStage || isComplete) {
      // GOLD STAGE or COMPLETE: Show ONLY boosted envelopes
      // Keep showing gold list during complete stage to avoid visual glitch
      envelopesBeingStuffed = provider.allocations.entries
          .where((e) => _calculatedBoosts.containsKey(e.key) && (_calculatedBoosts[e.key] ?? 0) > 0)
          .map((e) => provider.allEnvelopes.firstWhere((env) => env.id == e.key))
          .toList();

      // If no boosts, show all envelopes (fallback for complete stage)
      if (envelopesBeingStuffed.isEmpty) {
        envelopesBeingStuffed = provider.allocations.entries
            .map((e) => provider.allEnvelopes.firstWhere((env) => env.id == e.key))
            .toList();
      }
    } else {
      // SILVER STAGE: Show all envelopes in normal order
      envelopesBeingStuffed = provider.allocations.entries
          .map((e) => provider.allEnvelopes.firstWhere((env) => env.id == e.key))
          .toList();
    }

    // Calculate overall progress (how many envelopes completed)
    final totalEnvelopes = envelopesBeingStuffed.length;
    final completedEnvelopes = provider.currentEnvelopeAnimationIndex + 1;
    final overallProgress = totalEnvelopes > 0 ? (completedEnvelopes / totalEnvelopes).clamp(0.0, 1.0) : 0.0;

    // Scroll to top when gold stage starts
    if (isGoldStage && !_hasScrolledToTopForGold && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          );
          _hasScrolledToTopForGold = true;
        }
      });
    }

    // Reset scroll flag only when returning to silver stage (not during complete)
    if (!isGoldStage && !isComplete) {
      _hasScrolledToTopForGold = false;
    }

    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
          children: [
            // Glowing Sun Header - Redesigned (smaller, shows decreasing amount)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  // Smaller custom painted sun that gets brighter
                  _GlowingSun(brightness: overallProgress, size: 60),
                  const SizedBox(height: 12),
                  Text(
                    'Source of Income',
                    style: fontProvider.getTextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // AnimatedSwitcher for smooth number updates (decreasing amount)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    child: Text(
                      currency.format(_calculateRemainingSource(provider)),
                      key: ValueKey<double>(_calculateRemainingSource(provider)),
                      style: fontProvider.getTextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Account tier (if hasAccount)
            if (provider.isAccountMode && provider.defaultAccount != null) ...[
              // Waterfall connector from sun to account
              Center(
                child: Container(
                  height: 40,
                  width: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.amber.shade300.withValues(alpha: overallProgress),
                        Colors.amber.shade500.withValues(alpha: overallProgress * 0.5),
                      ],
                    ),
                  ),
                ),
              ),

              // Account container - Redesigned to look like account cards with increasing balance
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Account icon from provider
                    provider.defaultAccount!.getIconWidget(theme, size: 32),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider.defaultAccount!.name,
                          style: fontProvider.getTextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // AnimatedSwitcher for smooth number updates (increasing balance)
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (Widget child, Animation<double> animation) {
                            return FadeTransition(opacity: animation, child: child);
                          },
                          child: Text(
                            currency.format(_initialAccountBalance + provider.accountDepositProgress),
                            key: ValueKey<double>(_initialAccountBalance + provider.accountDepositProgress),
                            style: fontProvider.getTextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Waterfall connector from account to envelopes
              Center(
                child: Container(
                  height: 40,
                  width: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.blue.shade400.withValues(alpha: overallProgress),
                        Colors.amber.shade500.withValues(alpha: overallProgress * 0.5),
                      ],
                    ),
                  ),
                ),
              ),
            ] else ...[
              // Direct waterfall from source to envelopes (no account)
              Center(
                child: Container(
                  height: 40,
                  width: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.amber.shade300.withValues(alpha: overallProgress),
                        Colors.amber.shade500.withValues(alpha: overallProgress * 0.5),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            // Stage indicator
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                isGoldStage ? '✨ Gold Boost Active' : '⚡ Filling Envelopes',
                style: fontProvider.getTextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isGoldStage ? Colors.amber.shade700 : theme.colorScheme.primary,
                ),
              ),
            ),

            // All envelopes in a column with padding
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                // Generate all envelope widgets
                ...List.generate(envelopesBeingStuffed.length, (index) {
                  final envelope = envelopesBeingStuffed[index];
                  final stuffedAmount = provider.stuffingProgress[envelope.id] ?? 0.0;
                  final targetAmount = provider.allocations[envelope.id] ?? 0.0;
                  final isActive = provider.currentEnvelopeAnimationIndex == index;
                  final fillProgress = targetAmount > 0 ? (stuffedAmount / targetAmount).clamp(0.0, 1.0) : 0.0;
                  final horizonProgress = envelope.targetAmount != null && envelope.targetAmount! > 0
                      ? ((envelope.currentAmount + stuffedAmount) / envelope.targetAmount!).clamp(0.0, 1.0)
                      : 0.0;

                  // Check if this envelope is getting gold boost (from calculated boosts)
                  final hasBoost = _calculatedBoosts.containsKey(envelope.id) && (_calculatedBoosts[envelope.id] ?? 0) > 0;
                  final isGoldActive = isGoldStage && isActive && hasBoost;

                  // Determine if this envelope has completed or is ahead of current animation
                  final isCompleted = index < provider.currentEnvelopeAnimationIndex;
                  final isPending = index > provider.currentEnvelopeAnimationIndex;

                  // Create or get GlobalKey for this envelope
                  _envelopeKeys.putIfAbsent(index, () => GlobalKey());

                  // Auto-scroll to active envelope
                  if (isActive) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final keyContext = _envelopeKeys[index]?.currentContext;
                      if (keyContext != null && _scrollController.hasClients) {
                        Scrollable.ensureVisible(
                          keyContext,
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                          alignment: 0.3, // Position at 30% from top of viewport
                        );
                      }
                    });
                  }

                  return AnimatedContainer(
                    key: _envelopeKeys[index],
                    duration: const Duration(milliseconds: 400),
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: isGoldActive
                          ? LinearGradient(
                              colors: [
                                Colors.amber.shade50,
                                Colors.orange.shade100,
                              ],
                            )
                          : (isActive && !isGoldStage
                              ? LinearGradient(
                                  colors: [
                                    Colors.blue.shade50,
                                    Colors.cyan.shade50,
                                  ],
                                )
                              : null),
                      color: isGoldActive || (isActive && !isGoldStage)
                          ? null
                          : (isCompleted
                              ? theme.colorScheme.surfaceContainerHigh
                              : (isPending
                                  ? theme.colorScheme.surface.withValues(alpha: 0.5)
                                  : theme.colorScheme.surfaceContainerHighest)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isGoldActive
                            ? Colors.amber.shade700
                            : (isActive && !isGoldStage
                                ? Colors.blue.shade600
                                : (isCompleted
                                    ? Colors.green.shade400
                                    : Colors.grey.shade300)),
                        width: isActive ? 3 : 1,
                      ),
                      boxShadow: isGoldActive
                          ? [
                              BoxShadow(
                                color: Colors.amber.shade400.withValues(alpha: 0.6),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ]
                          : (isActive && !isGoldStage
                              ? [
                                  BoxShadow(
                                    color: Colors.blue.shade400.withValues(alpha: 0.4),
                                    blurRadius: 15,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null),
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
                              const SizedBox(height: 8),
                              // Animated stuffing progress bar with gradual filling animation
                              TweenAnimationBuilder<double>(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeInOut,
                                tween: Tween<double>(
                                  begin: 0.0,
                                  end: fillProgress,
                                ),
                                builder: (context, animatedProgress, child) {
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Stack(
                                      children: [
                                        LinearProgressIndicator(
                                          value: animatedProgress,
                                          minHeight: 12,
                                          backgroundColor: Colors.grey.shade200,
                                          valueColor: const AlwaysStoppedAnimation(Colors.transparent),
                                        ),
                                        // Light-filled progress
                                        FractionallySizedBox(
                                          widthFactor: animatedProgress,
                                          child: Container(
                                            height: 12,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: isGoldActive
                                                    ? [
                                                        Colors.amber.shade200,
                                                        Colors.amber.shade400,
                                                        Colors.orange.shade500,
                                                      ]
                                                    : [
                                                        Colors.amber.shade300,
                                                        Colors.yellow.shade400,
                                                        Colors.amber.shade500,
                                                      ],
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: isGoldActive
                                                      ? Colors.amber.withValues(alpha: 0.8)
                                                      : Colors.amber.withValues(alpha: 0.5),
                                                  blurRadius: isGoldActive ? 12 : 8,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              if (isGoldActive)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '✨ GOLD BOOST',
                                    style: fontProvider.getTextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber.shade900,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                '${currency.format(stuffedAmount)} / ${currency.format(targetAmount)}',
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
                          AnimatedOpacity(
                            opacity: isActive ? 1.0 : (isCompleted ? 0.9 : 0.6),
                            duration: const Duration(milliseconds: 300),
                            child: Transform.scale(
                              scale: isActive ? 1.1 : 1.0,
                              child: TweenAnimationBuilder<double>(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeInOut,
                                tween: Tween<double>(
                                  begin: 0.0,
                                  end: horizonProgress,
                                ),
                                builder: (context, animatedHorizonProgress, child) {
                                  return HorizonProgress(percentage: animatedHorizonProgress, size: 50);
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
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

    // Calculate mission statistics
    final totalDistributed = provider.stuffingProgress.values.fold(0.0, (sum, amount) => sum + amount);
    final envelopesFunded = provider.stuffingProgress.length;
    final totalDaysSaved = provider.topHorizons.fold(0, (sum, impact) => sum + impact.daysSaved);

    // Count envelopes with horizons
    final envelopesWithHorizons = provider.stuffingProgress.keys.where((id) {
      final env = provider.allEnvelopes.firstWhere((e) => e.id == id);
      return env.targetAmount != null;
    }).length;

    // Calculate average days saved per horizon
    final avgDaysSaved = envelopesWithHorizons > 0
        ? (totalDaysSaved / envelopesWithHorizons).round()
        : 0;

    // Count how many envelopes got boost (from calculated boosts)
    final boostedCount = _calculatedBoosts.entries.where((e) => e.value > 0).length;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),

            // Mission Accomplished Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.green.shade50,
                    Colors.green.shade100,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.shade400, width: 2),
              ),
              child: Column(
                children: [
                  const Text(
                    '🎯',
                    style: TextStyle(fontSize: 60),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'MISSION ACCOMPLISHED',
                    style: fontProvider.getTextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade900,
                    ).copyWith(letterSpacing: 1.2),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Future Successfully Recalibrated',
                    style: fontProvider.getTextStyle(
                      fontSize: 16,
                      color: Colors.green.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Key Statistics Grid
            Text(
              'Mission Statistics',
              style: fontProvider.getTextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),

            // 2x2 Grid of stats
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    '💰',
                    'Total Distributed',
                    currency.format(totalDistributed),
                    Colors.green,
                    theme,
                    fontProvider,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    '📨',
                    'Envelopes Funded',
                    '$envelopesFunded',
                    Colors.blue,
                    theme,
                    fontProvider,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    '🔥',
                    'Total Days Saved',
                    '$totalDaysSaved days',
                    Colors.orange,
                    theme,
                    fontProvider,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    '🚀',
                    'Boosted Horizons',
                    '$boostedCount',
                    Colors.amber,
                    theme,
                    fontProvider,
                  ),
                ),
              ],
            ),

            if (avgDaysSaved > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade50, Colors.indigo.shade50],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('⚡', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Column(
                      children: [
                        Text(
                          'Average Acceleration',
                          style: fontProvider.getTextStyle(
                            fontSize: 12,
                            color: Colors.purple.shade700,
                          ),
                        ),
                        Text(
                          '$avgDaysSaved days per horizon',
                          style: fontProvider.getTextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple.shade900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Top 3 horizons moved forward
            if (provider.topHorizons.isNotEmpty) ...[
              Text(
                'Top Horizon Impacts',
                style: fontProvider.getTextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              ...provider.topHorizons.asMap().entries.map((entry) {
                final index = entry.key;
                final impact = entry.value;
                return _buildHorizonImpactCard(
                  theme,
                  fontProvider,
                  currency,
                  impact,
                  rank: index + 1,
                );
              }),
            ],

            const SizedBox(height: 32),

            // Done button
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.secondary,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Return to Base',
                style: fontProvider.getTextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String emoji,
    String label,
    String value,
    MaterialColor color,
    ThemeData theme,
    FontProvider fontProvider,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.shade50,
            color.shade100,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade300),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Text(
            label,
            style: fontProvider.getTextStyle(
              fontSize: 11,
              color: color.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: fontProvider.getTextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color.shade900,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHorizonImpactCard(
    ThemeData theme,
    FontProvider fontProvider,
    NumberFormat currency,
    EnvelopeHorizonImpact impact, {
    int? rank,
  }) {
    // Medal colors based on rank
    Color? medalColor;
    String? medal;
    if (rank != null) {
      switch (rank) {
        case 1:
          medalColor = Colors.amber.shade700;
          medal = '🥇';
          break;
        case 2:
          medalColor = Colors.grey.shade600;
          medal = '🥈';
          break;
        case 3:
          medalColor = Colors.brown.shade600;
          medal = '🥉';
          break;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: rank != null && rank <= 3
            ? LinearGradient(
                colors: [
                  medalColor?.withValues(alpha: 0.1) ?? theme.colorScheme.surfaceContainerHighest,
                  theme.colorScheme.surfaceContainerHighest,
                ],
              )
            : null,
        color: rank == null ? theme.colorScheme.surfaceContainerHighest : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: medalColor ?? theme.colorScheme.primary.withValues(alpha: 0.3),
          width: rank != null && rank <= 3 ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          if (medal != null) ...[
            Text(
              medal,
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(width: 8),
          ],
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
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '🔥 ${impact.daysSaved} days closer',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      currency.format(impact.stuffedAmount),
                      style: fontProvider.getTextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
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

/// Animated glowing sun that gets brighter as stuffing progresses
class _GlowingSun extends StatefulWidget {
  final double brightness; // 0.0 to 1.0
  final double size; // Size of the sun

  const _GlowingSun({required this.brightness, this.size = 120});

  @override
  State<_GlowingSun> createState() => _GlowingSunState();
}

class _GlowingSunState extends State<_GlowingSun> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulseValue = _pulseController.value;
        final brightness = widget.brightness.clamp(0.3, 1.0); // Minimum 30% brightness

        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _SunPainter(
            brightness: brightness,
            pulse: pulseValue,
          ),
        );
      },
    );
  }
}

class _SunPainter extends CustomPainter {
  final double brightness; // 0.0 to 1.0
  final double pulse; // 0.0 to 1.0 for animation

  _SunPainter({required this.brightness, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width / 3;

    // Outer glow (multiple layers for intense brightness)
    for (int i = 5; i > 0; i--) {
      final glowRadius = baseRadius + (i * 15 * brightness) + (pulse * 5);
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            Color.lerp(Colors.yellow.shade200, Colors.white, brightness * 0.8)!.withValues(alpha: 0.1 * brightness),
            Colors.transparent,
          ],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: glowRadius));

      canvas.drawCircle(center, glowRadius, glowPaint);
    }

    // Core sun with gradient
    final sunPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Color.lerp(Colors.yellow.shade100, Colors.white, brightness * 0.9)!,
          Color.lerp(Colors.yellow.shade400, Colors.amber.shade200, brightness * 0.5)!,
          Color.lerp(Colors.orange.shade500, Colors.amber.shade600, brightness * 0.3)!,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: baseRadius));

    canvas.drawCircle(center, baseRadius, sunPaint);

    // Sun rays (more prominent with higher brightness)
    final rayCount = 12;
    final rayPaint = Paint()
      ..color = Color.lerp(Colors.yellow.shade300, Colors.white, brightness * 0.7)!.withValues(alpha: 0.6 * brightness)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < rayCount; i++) {
      final angle = (i * 2 * math.pi / rayCount) + (pulse * math.pi / 6);
      final rayStart = baseRadius + 5;
      final rayEnd = baseRadius + 15 + (brightness * 10);

      final startX = center.dx + rayStart * math.cos(angle);
      final startY = center.dy + rayStart * math.sin(angle);
      final endX = center.dx + rayEnd * math.cos(angle);
      final endY = center.dy + rayEnd * math.sin(angle);

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), rayPaint);
    }

    // Inner bright core (gets brighter)
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: brightness * 0.9),
          Colors.white.withValues(alpha: brightness * 0.3),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: baseRadius * 0.5));

    canvas.drawCircle(center, baseRadius * 0.5, corePaint);
  }

  @override
  bool shouldRepaint(_SunPainter oldDelegate) {
    return oldDelegate.brightness != brightness || oldDelegate.pulse != pulse;
  }
}
