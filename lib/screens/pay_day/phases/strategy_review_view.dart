// lib/screens/pay_day/phases/strategy_review_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../providers/pay_day_cockpit_provider.dart';
import '../../../providers/font_provider.dart';
import '../../../providers/locale_provider.dart';
import '../../../models/envelope.dart';
import '../../../models/envelope_group.dart';
import '../../../widgets/common/smart_text_field.dart';
import '../../../widgets/horizon_progress.dart';
import '../../../utils/calculator_helper.dart';
import '../add_to_pay_day_modal.dart';

class StrategyReviewView extends StatefulWidget {
  final Map<String, double> tempAllocations;
  final Map<String, double> horizonBoosts;
  final Map<String, double> calculatedBoosts;
  final Set<String> expandedBinderIds;
  final Map<String, bool> expandedEnvelopeIds;
  final Function(Map<String, double>, Map<String, double>) onFuelHorizons;

  const StrategyReviewView({
    super.key,
    required this.tempAllocations,
    required this.horizonBoosts,
    required this.calculatedBoosts,
    required this.expandedBinderIds,
    required this.expandedEnvelopeIds,
    required this.onFuelHorizons,
  });

  @override
  State<StrategyReviewView> createState() => _StrategyReviewViewState();
}

class _StrategyReviewViewState extends State<StrategyReviewView> {
  @override
  void initState() {
    super.initState();
    // Sync temp allocations on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.tempAllocations.isEmpty) {
        final provider = context.read<PayDayCockpitProvider>();
        widget.tempAllocations.addAll(provider.allocations);
      }
    });
  }

  double _calculateTotalCashFlow() {
    return widget.tempAllocations.values.fold(0.0, (sum, amount) => sum + amount);
  }

  double _calculateTotalBoost() {
    double total = 0.0;
    for (final entry in widget.horizonBoosts.entries) {
      final envelopeId = entry.key;
      final percentage = entry.value;
      final baseAmount = widget.tempAllocations[envelopeId] ?? 0.0;
      total += baseAmount * percentage;
    }
    return total;
  }

  double _calculateReserve(PayDayCockpitProvider provider) {
    final totalCashFlow = _calculateTotalCashFlow();
    final totalBoost = _calculateTotalBoost();
    return provider.externalInflow - totalCashFlow - totalBoost;
  }

  String _formatCompactCurrency(double amount, String symbol) {
    final absAmount = amount.abs();
    final isNegative = amount < 0;
    final prefix = isNegative ? '-' : '';

    if (absAmount >= 1000000) {
      // Millions: £1.22M
      final millions = absAmount / 1000000;
      return '$prefix$symbol${millions.toStringAsFixed(2)}M';
    } else if (absAmount >= 1000) {
      // Thousands: £1.12K - always 2 decimals
      final thousands = absAmount / 1000;
      return '$prefix$symbol${thousands.toStringAsFixed(2)}K';
    } else {
      // Less than 1000: show full amount
      return '$prefix$symbol${absAmount.toStringAsFixed(2)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PayDayCockpitProvider>();
    final theme = Theme.of(context);
    final fontProvider = context.read<FontProvider>();
    final locale = context.read<LocaleProvider>();
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);

    return Column(
      children: [
        // Top Stats Bar (Sticky)
        _buildTopStatsBar(theme, fontProvider, provider, locale),

        // Scrollable content
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Binders section
              ..._buildBindersSection(theme, fontProvider, currency, provider),

              if (_buildBindersSection(
                theme,
                fontProvider,
                currency,
                provider,
              ).isNotEmpty)
                const SizedBox(height: 24),

              // Individual envelopes section
              ..._buildIndividualEnvelopesSection(
                theme,
                fontProvider,
                currency,
                provider,
              ),

              if (_buildIndividualEnvelopesSection(
                theme,
                fontProvider,
                currency,
                provider,
              ).isNotEmpty)
                const SizedBox(height: 24),

              // Add Item button
              _buildAddItemButton(theme, fontProvider, provider),

              const SizedBox(height: 24),

              // Fuel the Horizons button (at bottom of list)
              FilledButton(
                onPressed: () => _handleFuelingHorizons(provider),
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

  void _handleFuelingHorizons(PayDayCockpitProvider provider) {
    // Calculate base allocations (what will be shown in silver stage)
    final baseAllocations = <String, double>{};

    // Calculate boosts (both explicit slider boosts AND implicit increases)
    final calculatedBoosts = <String, double>{};

    for (final entry in widget.tempAllocations.entries) {
      final envelopeId = entry.key;
      final tempAmount = entry.value;
      final envelope = provider.allEnvelopes.firstWhere(
        (e) => e.id == envelopeId,
      );
      final baselineAmount = envelope.cashFlowAmount ?? 0.0;
      final hasCashFlow = envelope.cashFlowEnabled && baselineAmount > 0;

      // Check if there's an explicit boost slider value
      final hasExplicitBoost =
          widget.horizonBoosts.containsKey(envelopeId) &&
          (widget.horizonBoosts[envelopeId] ?? 0) > 0;

      // Implicit boost logic: ONLY for cash-flow-enabled envelopes with a horizon
      // For manual additions to non-cash-flow envelopes, treat the whole amount as base
      final canHaveImplicitBoost =
          hasCashFlow && envelope.targetAmount != null;
      final implicitBoost =
          canHaveImplicitBoost && tempAmount > baselineAmount
          ? (tempAmount - baselineAmount)
          : 0.0;

      if (implicitBoost > 0) {
        // Implicit boost: base is baseline, boost is the increase
        baseAllocations[envelopeId] = baselineAmount;
        calculatedBoosts[envelopeId] = implicitBoost;

        // If there's ALSO an explicit boost, add it on top
        if (hasExplicitBoost) {
          final sliderBoostPercentage = widget.horizonBoosts[envelopeId]!;
          final sliderBoostAmount = baselineAmount * sliderBoostPercentage;
          calculatedBoosts[envelopeId] = implicitBoost + sliderBoostAmount;
        }
      } else {
        // No implicit boost, use temp amount as base
        baseAllocations[envelopeId] = tempAmount;

        // Add explicit boost if exists (only for envelopes with horizons)
        if (hasExplicitBoost && envelope.targetAmount != null) {
          final sliderBoostPercentage = widget.horizonBoosts[envelopeId]!;
          final sliderBoostAmount = tempAmount * sliderBoostPercentage;
          calculatedBoosts[envelopeId] = sliderBoostAmount;
        }
      }
    }

    // Store calculated boosts for Phase 3 animation
    widget.calculatedBoosts.clear();
    widget.calculatedBoosts.addAll(calculatedBoosts);

    // Sync to provider: ONLY base amounts (boosts are passed separately to executeStuffing)
    final allEnvelopeIds = provider.allEnvelopes.map((e) => e.id).toList();
    for (final id in allEnvelopeIds) {
      if (!baseAllocations.containsKey(id)) {
        provider.updateEnvelopeAllocation(id, 0.0);
      } else {
        final base = baseAllocations[id] ?? 0.0;
        // Only pass the base amount to provider allocations
        // Boosts will be added separately during Phase 3 animation
        provider.updateEnvelopeAllocation(id, base);
      }
    }

    // Call callback and proceed
    widget.onFuelHorizons(baseAllocations, calculatedBoosts);
    provider.proceedToStuffing();
  }

  Widget _buildTopStatsBar(
    ThemeData theme,
    FontProvider fontProvider,
    PayDayCockpitProvider provider,
    LocaleProvider locale,
  ) {
    final totalCashFlow = _calculateTotalCashFlow();
    final totalBoost = _calculateTotalBoost();
    final reserve = _calculateReserve(provider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatChip(
            '💰',
            'Income',
            _formatCompactCurrency(
              provider.externalInflow,
              locale.currencySymbol,
            ),
            theme.colorScheme.primary,
            fontProvider,
          ),
          _buildStatChip(
            '🔄',
            'Cash Flow',
            _formatCompactCurrency(totalCashFlow, locale.currencySymbol),
            theme.colorScheme.secondary,
            fontProvider,
          ),
          _buildStatChip(
            '⏰',
            'Autopilot',
            _formatCompactCurrency(
              provider.autopilotUpcoming,
              locale.currencySymbol,
            ),
            provider.autopilotUpcoming > 0
                ? Colors.deepPurple.shade600
                : Colors.grey.shade600,
            fontProvider,
          ),
          _buildStatChip(
            '🚀',
            'Boost',
            _formatCompactCurrency(totalBoost, locale.currencySymbol),
            Colors.amber.shade700,
            fontProvider,
          ),
          _buildStatChip(
            '🏦',
            'Reserve',
            _formatCompactCurrency(reserve, locale.currencySymbol),
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
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          label,
          style: fontProvider.getTextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: fontProvider.getTextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }

  List<Widget> _buildBindersSection(
    ThemeData theme,
    FontProvider fontProvider,
    NumberFormat currency,
    PayDayCockpitProvider provider,
  ) {
    final widgets = <Widget>[];

    // Get binders that have envelopes in allocations
    final bindersWithAllocations = provider.allBinders.where((b) {
      return provider.allEnvelopes.any(
        (e) => e.groupId == b.id && widget.tempAllocations.containsKey(e.id),
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
      widgets.add(_buildBinderCard(binder, theme, fontProvider, currency, provider));
      widgets.add(const SizedBox(height: 12));
    }

    return widgets;
  }

  Widget _buildBinderCard(
    EnvelopeGroup binder,
    ThemeData theme,
    FontProvider fontProvider,
    NumberFormat currency,
    PayDayCockpitProvider provider,
  ) {
    final isExpanded = widget.expandedBinderIds.contains(binder.id);
    final binderEnvelopes = provider.allEnvelopes
        .where(
          (e) => e.groupId == binder.id && widget.tempAllocations.containsKey(e.id),
        )
        .toList();

    // Calculate binder stats
    final binderCashFlow = binderEnvelopes.fold(
      0.0,
      (sum, env) => sum + (widget.tempAllocations[env.id] ?? 0.0),
    );
    final binderHorizon = binderEnvelopes
        .where((e) => e.targetAmount != null)
        .length;
    final binderHorizonValue = binderEnvelopes
        .where((e) => e.targetAmount != null)
        .fold(0.0, (sum, env) => sum + (env.targetAmount ?? 0.0));

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          // Binder header
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  widget.expandedBinderIds.remove(binder.id);
                } else {
                  widget.expandedBinderIds.add(binder.id);
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${currency.format(binderCashFlow)} cash flow • $binderHorizon horizons (${currency.format(binderHorizonValue)})',
                          style: fontProvider.getTextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
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
            ...binderEnvelopes.map(
              (env) => _buildEnvelopeCard(
                env,
                theme,
                fontProvider,
                currency,
                provider,
                inBinder: true,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildIndividualEnvelopesSection(
    ThemeData theme,
    FontProvider fontProvider,
    NumberFormat currency,
    PayDayCockpitProvider provider,
  ) {
    final widgets = <Widget>[];

    // Get individual envelopes (not in binders, but in allocations)
    final individualEnvelopes = provider.allEnvelopes
        .where((e) => e.groupId == null && widget.tempAllocations.containsKey(e.id))
        .toList();

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
      widgets.add(_buildEnvelopeCard(env, theme, fontProvider, currency, provider));
      widgets.add(const SizedBox(height: 12));
    }

    return widgets;
  }

  Widget _buildEnvelopeCard(
    Envelope envelope,
    ThemeData theme,
    FontProvider fontProvider,
    NumberFormat currency,
    PayDayCockpitProvider provider, {
    bool inBinder = false,
  }) {
    final isIncluded = widget.tempAllocations.containsKey(envelope.id);
    final currentAmount =
        widget.tempAllocations[envelope.id] ?? envelope.cashFlowAmount ?? 0.0;
    final baselineAmount = envelope.cashFlowAmount ?? 0.0;
    final isDecreasedAmount = currentAmount < baselineAmount;

    // Disable boost slider if amount was decreased
    final boostPercentage = isDecreasedAmount
        ? 0.0
        : (widget.horizonBoosts[envelope.id] ?? 0.0);
    final hasBoost = boostPercentage > 0;
    final isExpanded = widget.expandedEnvelopeIds[envelope.id] ?? false;

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
                widget.expandedEnvelopeIds[envelope.id] = !isExpanded;
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
                        widget.tempAllocations[envelope.id] =
                            envelope.cashFlowAmount ?? 0.0;
                      } else {
                        widget.tempAllocations.remove(envelope.id);
                        widget.horizonBoosts.remove(envelope.id);
                        widget.expandedEnvelopeIds[envelope.id] = false;
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
                          Flexible(
                            child: Text(
                              currency.format(currentAmount),
                              style: fontProvider.getTextStyle(
                                fontSize: 14,
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasBoost) ...[
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '+ ${currency.format(boostAmount)}',
                                style: fontProvider.getTextStyle(
                                  fontSize: 13,
                                  color: Colors.amber.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
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
                    icon: Icon(
                      Icons.edit,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    onPressed: () =>
                        _showEnvelopeSettingsModal(envelope, currency, provider),
                    tooltip: 'Edit amount',
                  ),
                // Horizon indicator
                if (envelope.targetAmount != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: HorizonProgress(
                      percentage:
                          ((envelope.currentAmount + totalAllocation) /
                                  envelope.targetAmount!)
                              .clamp(0.0, 1.0),
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
                  if (widget.tempAllocations[envelope.id] !=
                      (envelope.cashFlowAmount ?? 0.0))
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.edit_note,
                            size: 14,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Temporary change: ${widget.tempAllocations[envelope.id]! > (envelope.cashFlowAmount ?? 0.0) ? '+' : ''}${currency.format(widget.tempAllocations[envelope.id]! - (envelope.cashFlowAmount ?? 0.0))}',
                            style: fontProvider.getTextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (widget.tempAllocations[envelope.id] !=
                      (envelope.cashFlowAmount ?? 0.0))
                    const SizedBox(height: 12),

                  // Boost section (only for horizons)
                  if (envelope.targetAmount != null) ...[
                    Row(
                      children: [
                        Checkbox(
                          value: hasBoost,
                          onChanged: isDecreasedAmount
                              ? null
                              : (value) {
                                  setState(() {
                                    if (value == true) {
                                      widget.horizonBoosts[envelope.id] =
                                          0.5; // Start at 50%
                                    } else {
                                      widget.horizonBoosts.remove(envelope.id);
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
                      _buildBoostSlider(
                        envelope,
                        theme,
                        fontProvider,
                        currency,
                      ),
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

  Widget _buildCompactDetailRow(
    String emoji,
    String label,
    String value,
    ThemeData theme,
    FontProvider fontProvider,
  ) {
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

  Widget _buildBoostSlider(
    Envelope envelope,
    ThemeData theme,
    FontProvider fontProvider,
    NumberFormat currency,
  ) {
    final boostPercent = widget.horizonBoosts[envelope.id] ?? 0.0;
    final currentAmount = widget.tempAllocations[envelope.id] ?? 0.0;
    final boostAmount = currentAmount * boostPercent;

    // Calculate days to target (baseline and with boost)
    final monthlyVelocity = envelope.cashFlowAmount ?? 0.0;
    int baselineDays = 0;
    int boostedDays = 0;
    int daysSaved = 0;

    if (envelope.targetAmount != null && monthlyVelocity > 0) {
      final remainingWithoutBoost =
          envelope.targetAmount! - (envelope.currentAmount + currentAmount);
      final remainingWithBoost =
          envelope.targetAmount! -
          (envelope.currentAmount + currentAmount + boostAmount);

      baselineDays = (remainingWithoutBoost / (monthlyVelocity / 30.44))
          .round()
          .clamp(0, 999999);
      boostedDays = (remainingWithBoost / (monthlyVelocity / 30.44))
          .round()
          .clamp(0, 999999);
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
                widget.horizonBoosts[envelope.id] = value;
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

  Widget _buildAddItemButton(
    ThemeData theme,
    FontProvider fontProvider,
    PayDayCockpitProvider provider,
  ) {
    return OutlinedButton.icon(
      onPressed: () => _showAddItemModal(provider),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _showAddItemModal(PayDayCockpitProvider provider) async {
    // Get already displayed items
    final alreadyDisplayedEnvelopes = widget.tempAllocations.keys.toSet();
    final alreadyDisplayedBinders = widget.expandedBinderIds.toSet();

    final result = await showModalBottomSheet<PayDayAddition>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddToPayDayModal(
        allEnvelopes: provider.allEnvelopes,
        allGroups: provider.allBinders,
        alreadyDisplayedEnvelopes: alreadyDisplayedEnvelopes,
        alreadyDisplayedBinders: alreadyDisplayedBinders,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        // Add all selected binders
        for (final binderId in result.binderIds) {
          // Add binder and expand it
          widget.expandedBinderIds.add(binderId);

          // Add all envelopes in this binder with their cash flow amounts
          final binderEnvelopes = provider.allEnvelopes.where(
            (e) => e.groupId == binderId,
          );
          for (final env in binderEnvelopes) {
            if (env.cashFlowEnabled &&
                env.cashFlowAmount != null &&
                env.cashFlowAmount! > 0) {
              widget.tempAllocations[env.id] = env.cashFlowAmount!;
            }
          }
        }

        // Add all selected individual envelopes
        for (final envelopeId in result.envelopeIds) {
          final envelope = provider.allEnvelopes.firstWhere(
            (e) => e.id == envelopeId,
          );
          final amount = result.customAmount ?? envelope.cashFlowAmount ?? 0.0;
          // Add to allocations even if amount is 0, so user can manually set it
          widget.tempAllocations[envelope.id] = amount;
        }
      });
    }
  }

  Future<void> _showEnvelopeSettingsModal(
    Envelope envelope,
    NumberFormat currency,
    PayDayCockpitProvider provider,
  ) async {
    final theme = Theme.of(context);
    final fontProvider = context.read<FontProvider>();
    final locale = context.read<LocaleProvider>();
    final currentAmount =
        widget.tempAllocations[envelope.id] ?? envelope.cashFlowAmount ?? 0.0;
    final baselineAmount = envelope.cashFlowAmount ?? 0.0;
    final amountController = TextEditingController(
      text: currentAmount.toStringAsFixed(2),
    );

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final inputAmount =
                double.tryParse(amountController.text.replaceAll(',', '')) ??
                0.0;
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
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Edit Cash Flow Amount',
                      style: fontProvider.getTextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
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
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
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
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
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
                              final result =
                                  await CalculatorHelper.showCalculator(
                                    context,
                                  );
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
                        setModalState(
                          () {},
                        ); // Rebuild to update boost indicator
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
                            colors: [
                              Colors.amber.shade50,
                              Colors.orange.shade50,
                            ],
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
                            Icon(
                              Icons.warning_amber,
                              size: 20,
                              color: Colors.orange.shade700,
                            ),
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
                          Icon(
                            Icons.info_outline,
                            size: 20,
                            color: Colors.blue.shade700,
                          ),
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
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final newAmount =
                        double.tryParse(
                          amountController.text.replaceAll(',', ''),
                        ) ??
                        0.0;
                    if (newAmount > 0) {
                      setState(() {
                        widget.tempAllocations[envelope.id] = newAmount;
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
}
