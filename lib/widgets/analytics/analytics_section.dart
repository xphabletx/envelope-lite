import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/analytics_data.dart';
import '../../models/transaction.dart';
import '../../models/envelope.dart';
import '../../models/envelope_group.dart';
import '../../providers/font_provider.dart';
import './spending_donut_chart.dart';

class AnalyticsSection extends StatefulWidget {
  const AnalyticsSection({
    super.key,
    required this.transactions,
    required this.envelopes,
    required this.groups,
    required this.dateRange,
    required this.onDateRangeChange,
    this.initialFilter,
    this.timeMachineDate,
  });

  final List<Transaction> transactions;
  final List<Envelope> envelopes;
  final List<EnvelopeGroup> groups;
  final DateTimeRange dateRange;
  final Function(DateTimeRange) onDateRangeChange;
  final AnalyticsFilter? initialFilter;
  final DateTime? timeMachineDate; // If in time machine mode, this is the projection date

  @override
  State<AnalyticsSection> createState() => _AnalyticsSectionState();
}

class _AnalyticsSectionState extends State<AnalyticsSection> {
  late AnalyticsFilter _filter;
  AnalyticsPeriod _period = AnalyticsPeriod.thisMonth;
  String? _drilledDownBinderId;

  @override
  void initState() {
    super.initState();
    // Initialize filter from widget parameter or default to cashOut
    _filter = widget.initialFilter ?? AnalyticsFilter.cashOut;
    // Check if the provided date range matches any standard period
    // If not, it's a custom range (e.g., from time machine)
    _period = _detectPeriodFromDateRange(widget.dateRange);
  }

  AnalyticsPeriod _detectPeriodFromDateRange(DateTimeRange range) {
    // Check each standard period to see if it matches the provided range
    // Use time machine date as reference if available
    final referenceDate = widget.timeMachineDate;

    for (final period in [
      AnalyticsPeriod.thisMonth,
      AnalyticsPeriod.last3Months,
      AnalyticsPeriod.last6Months,
      AnalyticsPeriod.thisYear,
      AnalyticsPeriod.allTime,
    ]) {
      final periodRange = period.getDateRange(referenceDate: referenceDate);
      // Check if the dates match (within same day)
      if (_isSameDay(range.start, periodRange.start) &&
          _isSameDay(range.end, periodRange.end)) {
        return period;
      }
    }
    // If no match, it's a custom period
    return AnalyticsPeriod.custom;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _applyPeriod(AnalyticsPeriod period) {
    setState(() {
      _period = period;
      if (period != AnalyticsPeriod.custom) {
        // Use time machine date as reference when calculating date range
        final referenceDate = widget.timeMachineDate;
        widget.onDateRangeChange(period.getDateRange(referenceDate: referenceDate));
      }
    });
  }

  Future<void> _pickCustomRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: widget.dateRange,
    );

    if (range != null) {
      setState(() {
        _period = AnalyticsPeriod.custom;
      });
      widget.onDateRangeChange(range);
    }
  }

  List<ChartSegment> _calculateSegments() {
    if (_drilledDownBinderId != null) {
      // Show envelopes in this binder
      return _calculateEnvelopeSegments(_drilledDownBinderId!);
    } else {
      // Show binders
      return _calculateBinderSegments();
    }
  }

  List<ChartSegment> _calculateBinderSegments() {
    final binderTotals = <String, double>{};

    // Calculate totals per binder
    for (final tx in widget.transactions) {
      final envelope = widget.envelopes.firstWhere(
        (e) => e.id == tx.envelopeId,
        orElse: () => Envelope(id: '', name: '', userId: ''),
      );

      if (envelope.id.isEmpty) continue;

      final binderId = envelope.groupId ?? 'ungrouped';

      // Apply filter
      double amount = 0;
      switch (_filter) {
        case AnalyticsFilter.cashIn:
          if (tx.type == TransactionType.deposit) {
            amount = tx.amount;
          }
          break;
        case AnalyticsFilter.cashOut:
          if (tx.type == TransactionType.withdrawal || tx.type == TransactionType.scheduledPayment) {
            amount = tx.amount;
          }
          break;
        case AnalyticsFilter.net:
          if (tx.type == TransactionType.deposit) {
            amount = tx.amount;
          } else if (tx.type == TransactionType.withdrawal || tx.type == TransactionType.scheduledPayment) {
            amount = -tx.amount;
          }
          break;
        case AnalyticsFilter.growth:
          // Growth = current balance (not calculated from transactions)
          // Skip for now - will implement in Beta
          break;
      }

      binderTotals[binderId] = (binderTotals[binderId] ?? 0) + amount.abs();
    }

    // Convert to segments
    final segments = <ChartSegment>[];
    final colors = _getChartColors();
    int colorIndex = 0;

    for (final entry in binderTotals.entries) {
      final binderId = entry.key;
      final amount = entry.value;

      if (amount <= 0) continue;

      String name;
      String? emoji;

      if (binderId == 'ungrouped') {
        name = 'Individual Envelopes';
        emoji = '📨';
      } else {
        final binder = widget.groups.firstWhere(
          (g) => g.id == binderId,
          orElse: () => EnvelopeGroup(id: '', name: 'Unknown', userId: ''),
        );
        name = binder.name;
        emoji = binder.emoji;
      }

      segments.add(ChartSegment(
        id: binderId,
        name: name,
        amount: amount,
        color: colors[colorIndex % colors.length],
        emoji: emoji,
        isBinder: true,
      ));

      colorIndex++;
    }

    // Sort by amount descending
    segments.sort((a, b) => b.amount.compareTo(a.amount));

    return segments;
  }

  List<ChartSegment> _calculateEnvelopeSegments(String binderId) {
    final envelopeTotals = <String, double>{};

    // Get envelopes in this binder
    final envelopesInBinder = binderId == 'ungrouped'
        ? widget.envelopes.where((e) => e.groupId == null).toList()
        : widget.envelopes.where((e) => e.groupId == binderId).toList();

    // Calculate totals per envelope
    for (final tx in widget.transactions) {
      if (!envelopesInBinder.any((e) => e.id == tx.envelopeId)) continue;

      double amount = 0;
      switch (_filter) {
        case AnalyticsFilter.cashIn:
          if (tx.type == TransactionType.deposit) {
            amount = tx.amount;
          }
          break;
        case AnalyticsFilter.cashOut:
          if (tx.type == TransactionType.withdrawal || tx.type == TransactionType.scheduledPayment) {
            amount = tx.amount;
          }
          break;
        case AnalyticsFilter.net:
          if (tx.type == TransactionType.deposit) {
            amount = tx.amount;
          } else if (tx.type == TransactionType.withdrawal || tx.type == TransactionType.scheduledPayment) {
            amount = -tx.amount;
          }
          break;
        case AnalyticsFilter.growth:
          break;
      }

      envelopeTotals[tx.envelopeId] =
          (envelopeTotals[tx.envelopeId] ?? 0) + amount.abs();
    }

    // Convert to segments
    final segments = <ChartSegment>[];
    final colors = _getChartColors();
    int colorIndex = 0;

    for (final entry in envelopeTotals.entries) {
      final envelopeId = entry.key;
      final amount = entry.value;

      if (amount <= 0) continue;

      final envelope = widget.envelopes.firstWhere(
        (e) => e.id == envelopeId,
        orElse: () => Envelope(id: '', name: '', userId: ''),
      );

      if (envelope.id.isEmpty) continue;

      segments.add(ChartSegment(
        id: envelopeId,
        name: envelope.name,
        amount: amount,
        color: colors[colorIndex % colors.length],
        emoji: envelope.emoji,
        isBinder: false,
        parentBinderId: binderId,
      ));

      colorIndex++;
    }

    segments.sort((a, b) => b.amount.compareTo(a.amount));

    return segments;
  }

  List<Color> _getChartColors() {
    return [
      const Color(0xFFE91E63), // Pink
      const Color(0xFF9C27B0), // Purple
      const Color(0xFF673AB7), // Deep Purple
      const Color(0xFF3F51B5), // Indigo
      const Color(0xFF2196F3), // Blue
      const Color(0xFF00BCD4), // Cyan
      const Color(0xFF009688), // Teal
      const Color(0xFF4CAF50), // Green
      const Color(0xFFFF9800), // Orange
      const Color(0xFFFF5722), // Deep Orange
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    final segments = _calculateSegments();
    final total = segments.fold(0.0, (sum, s) => sum + s.amount);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.analytics,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Spending Breakdown',
                style: fontProvider.getTextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Filter Toggle Buttons
          _FilterToggle(
            filter: _filter,
            onFilterChanged: (f) => setState(() => _filter = f),
          ),

          const SizedBox(height: 16),

          // Period Selector
          _PeriodSelector(
            period: _period,
            dateRange: widget.dateRange,
            onPeriodChanged: _applyPeriod,
            onCustomTap: _pickCustomRange,
          ),

          const SizedBox(height: 24),

          // Donut Chart
          SpendingDonutChart(
            segments: segments,
            total: total,
            isDrilledDown: _drilledDownBinderId != null,
            onSegmentTap: (segment) {
              if (segment.isBinder) {
                setState(() {
                  _drilledDownBinderId = segment.id;
                });
              }
            },
            onBackTap: _drilledDownBinderId != null
                ? () => setState(() => _drilledDownBinderId = null)
                : null,
          ),
        ],
      ),
    );
  }
}

// HELPER WIDGETS

class _FilterToggle extends StatelessWidget {
  const _FilterToggle({
    required this.filter,
    required this.onFilterChanged,
  });

  final AnalyticsFilter filter;
  final Function(AnalyticsFilter) onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return Row(
      children: [
        Expanded(
          child: _filterButton(
            label: 'Cash In',
            icon: Icons.arrow_downward,
            isSelected: filter == AnalyticsFilter.cashIn,
            onTap: () => onFilterChanged(AnalyticsFilter.cashIn),
            theme: theme,
            fontProvider: fontProvider,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _filterButton(
            label: 'Cash Out',
            icon: Icons.arrow_upward,
            isSelected: filter == AnalyticsFilter.cashOut,
            onTap: () => onFilterChanged(AnalyticsFilter.cashOut),
            theme: theme,
            fontProvider: fontProvider,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _filterButton(
            label: 'Net',
            icon: Icons.swap_horiz,
            isSelected: filter == AnalyticsFilter.net,
            onTap: () => onFilterChanged(AnalyticsFilter.net),
            theme: theme,
            fontProvider: fontProvider,
          ),
        ),
      ],
    );
  }

  Widget _filterButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeData theme,
    required FontProvider fontProvider,
  }) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: isSelected
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceContainerHighest,
        foregroundColor: isSelected
            ? Colors.white
            : theme.colorScheme.onSurface,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18),
          const SizedBox(height: 4),
          Text(
            label,
            style: fontProvider.getTextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.period,
    required this.dateRange,
    required this.onPeriodChanged,
    required this.onCustomTap,
  });

  final AnalyticsPeriod period;
  final DateTimeRange dateRange;
  final Function(AnalyticsPeriod) onPeriodChanged;
  final VoidCallback onCustomTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AnalyticsPeriod.values.map((p) {
        final isSelected = period == p;

        if (p == AnalyticsPeriod.custom) {
          return ChoiceChip(
            label: Text(
              period == AnalyticsPeriod.custom
                  ? '${DateFormat('MMM d').format(dateRange.start)} - ${DateFormat('MMM d').format(dateRange.end)}'
                  : p.label,
            ),
            selected: isSelected,
            onSelected: (_) => onCustomTap(),
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            selectedColor: theme.colorScheme.secondary,
            labelStyle: fontProvider.getTextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isSelected
                  ? Colors.white
                  : theme.colorScheme.onSurface,
            ),
          );
        }

        return ChoiceChip(
          label: Text(p.label),
          selected: isSelected,
          onSelected: (_) => onPeriodChanged(p),
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          selectedColor: theme.colorScheme.secondary,
          labelStyle: fontProvider.getTextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isSelected
                ? Colors.white
                : theme.colorScheme.onSurface,
          ),
        );
      }).toList(),
    );
  }
}
