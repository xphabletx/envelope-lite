// lib/screens/stats_history_screen.dart
// COMPLETE REDESIGN - Modern UI with all original functionality

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/envelope.dart';
import '../models/envelope_group.dart';
import '../models/transaction.dart';
import '../services/envelope_repo.dart';
import '../providers/font_provider.dart';

enum StatsViewMode { combined, envelopes, groups }

class StatsHistoryScreen extends StatefulWidget {
  const StatsHistoryScreen({
    super.key,
    required this.repo,
    this.initialEnvelopeIds,
    this.initialGroupIds,
    this.initialStart,
    this.initialEnd,
    this.myOnlyDefault = false,
    this.title,
    this.filterTransactionTypes,
  });

  final EnvelopeRepo repo;
  final Set<String>? initialEnvelopeIds;
  final Set<String>? initialGroupIds;
  final DateTime? initialStart;
  final DateTime? initialEnd;
  final bool myOnlyDefault;
  final String? title;
  final Set<TransactionType>? filterTransactionTypes;

  @override
  State<StatsHistoryScreen> createState() => _StatsHistoryScreenState();
}

class _StatsHistoryScreenState extends State<StatsHistoryScreen> {
  final currency = NumberFormat.currency(symbol: '£');
  final selectedIds = <String>{};
  StatsViewMode _viewMode = StatsViewMode.combined;
  late bool myOnly;
  late DateTime start;
  late DateTime end;
  bool _didApplyExplicitInitialSelection = false;

  @override
  void initState() {
    super.initState();
    myOnly = widget.myOnlyDefault;
    start =
        widget.initialStart ??
        DateTime.now().subtract(const Duration(days: 30));
    final defaultEnd = DateTime.now();
    final providedEnd = widget.initialEnd ?? defaultEnd;
    end = DateTime(
      providedEnd.year,
      providedEnd.month,
      providedEnd.day,
      23,
      59,
      59,
      999,
    );

    final hasExplicit =
        (widget.initialEnvelopeIds != null &&
            widget.initialEnvelopeIds!.isNotEmpty) ||
        (widget.initialGroupIds != null && widget.initialGroupIds!.isNotEmpty);

    if (hasExplicit) {
      selectedIds
        ..clear()
        ..addAll(widget.initialEnvelopeIds ?? const <String>{})
        ..addAll(widget.initialGroupIds ?? const <String>{});
      _didApplyExplicitInitialSelection = true;
    }
  }

  Future<void> _pickRange() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: start, end: end),
    );
    if (r != null) {
      setState(() {
        start = DateTime(r.start.year, r.start.month, r.start.day);
        end = DateTime(r.end.year, r.end.month, r.end.day, 23, 59, 59, 999);
      });
    }
  }

  void _showSelectionSheet<T>({
    required String title,
    required List<T> items,
    required String Function(T) getId,
    required Future<String> Function(T) getLabel,
  }) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              return Column(
                children: [
                  // Drag handle
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.3,
                        ),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: fontProvider.getTextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Select/Deselect buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: () {
                              setModalState(() {
                                setState(() {
                                  _didApplyExplicitInitialSelection = true;
                                  selectedIds.addAll(items.map(getId));
                                });
                              });
                            },
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              'Select All',
                              style: fontProvider.getTextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setModalState(() {
                                setState(() {
                                  _didApplyExplicitInitialSelection = true;
                                  for (var item in items) {
                                    selectedIds.remove(getId(item));
                                  }
                                });
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              'Deselect All',
                              style: fontProvider.getTextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // List
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final id = getId(item);
                        final isSelected = selectedIds.contains(id);

                        return FutureBuilder<String>(
                          future: getLabel(item),
                          builder: (context, snapshot) {
                            final label = snapshot.data ?? '...';
                            return _selectionTile(
                              label: label,
                              selected: isSelected,
                              onChanged: (v) {
                                setModalState(() {
                                  setState(() {
                                    _didApplyExplicitInitialSelection = true;
                                    if (v) {
                                      selectedIds.add(id);
                                    } else {
                                      selectedIds.remove(id);
                                    }
                                  });
                                });
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title ?? 'Statistics & History';
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            style: fontProvider.getTextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<Envelope>>(
        stream: widget.repo.envelopesStream(),
        builder: (_, sEnv) {
          final envelopes = sEnv.data ?? const <Envelope>[];

          return StreamBuilder<List<EnvelopeGroup>>(
            stream: widget.repo.groupsStream,
            builder: (_, sGrp) {
              final groups = sGrp.data ?? const <EnvelopeGroup>[];

              return StreamBuilder<List<Transaction>>(
                stream: widget.repo.transactionsStream,
                builder: (_, sTx) {
                  final txs = sTx.data ?? const <Transaction>[];

                  // Auto-select all if no explicit selection
                  if (!_didApplyExplicitInitialSelection &&
                      selectedIds.isEmpty &&
                      (envelopes.isNotEmpty || groups.isNotEmpty)) {
                    selectedIds
                      ..clear()
                      ..addAll(envelopes.map((e) => e.id))
                      ..addAll(groups.map((g) => g.id));
                  }

                  final filteredEnvelopes = myOnly
                      ? envelopes
                            .where((e) => e.userId == widget.repo.currentUserId)
                            .toList()
                      : envelopes;

                  final filteredGroups = myOnly
                      ? groups
                            .where((g) => g.userId == widget.repo.currentUserId)
                            .toList()
                      : groups;

                  final selectedGroupIds = selectedIds
                      .where((id) => groups.any((g) => g.id == id))
                      .toSet();
                  final selectedEnvelopeIds = selectedIds
                      .where((id) => envelopes.any((e) => e.id == id))
                      .toSet();

                  // Calculate chosen envelopes based on view mode
                  List<Envelope> chosen;
                  if (_viewMode == StatsViewMode.envelopes) {
                    chosen = filteredEnvelopes
                        .where((e) => selectedEnvelopeIds.contains(e.id))
                        .toList();
                  } else if (_viewMode == StatsViewMode.groups) {
                    chosen = filteredEnvelopes
                        .where(
                          (e) =>
                              e.groupId != null &&
                              selectedGroupIds.contains(e.groupId),
                        )
                        .toList();
                  } else {
                    chosen = filteredEnvelopes
                        .where(
                          (e) =>
                              selectedEnvelopeIds.contains(e.id) ||
                              (e.groupId != null &&
                                  selectedGroupIds.contains(e.groupId)),
                        )
                        .toList();
                  }

                  final envMap = {for (final e in envelopes) e.id: e.name};
                  final chosenIds = chosen.map((e) => e.id).toSet();

                  // Filter transactions
                  final shownTxs = txs.where((t) {
                    final inChosen = chosenIds.contains(t.envelopeId);
                    final inRange =
                        !t.date.isBefore(start) && t.date.isBefore(end);
                    final typeMatch = widget.filterTransactionTypes == null ||
                        widget.filterTransactionTypes!.contains(t.type);
                    return inChosen && inRange && typeMatch;
                  }).toList()..sort((a, b) => b.date.compareTo(a.date));

                  // Calculate stats
                  final double totalTarget = chosen.fold(
                    0.0,
                    (s, e) => s + (e.targetAmount ?? 0),
                  );
                  final double totalSaved = chosen.fold(
                    0.0,
                    (s, e) => s + e.currentAmount,
                  );
                  final double pct = totalTarget > 0
                      ? (totalSaved / totalTarget).clamp(0.0, 1.0) * 100
                      : 0.0;

                  // Calculate transaction stats (only for shown transaction types)
                  final showDeposits = widget.filterTransactionTypes == null ||
                      widget.filterTransactionTypes!.contains(
                        TransactionType.deposit,
                      );
                  final showWithdrawals = widget.filterTransactionTypes == null ||
                      widget.filterTransactionTypes!.contains(
                        TransactionType.withdrawal,
                      );
                  final showTransfers = widget.filterTransactionTypes == null ||
                      widget.filterTransactionTypes!.contains(
                        TransactionType.transfer,
                      );

                  final double totDep = showDeposits
                      ? shownTxs
                            .where((t) => t.type == TransactionType.deposit)
                            .fold(0.0, (s, t) => s + t.amount)
                      : 0.0;
                  final double totWdr = showWithdrawals
                      ? shownTxs
                            .where((t) => t.type == TransactionType.withdrawal)
                            .fold(0.0, (s, t) => s + t.amount)
                      : 0.0;
                  final double totTrnOut = showTransfers
                      ? shownTxs
                            .where(
                              (t) =>
                                  t.type == TransactionType.transfer &&
                                  t.transferDirection == TransferDirection.out_,
                            )
                            .fold(0.0, (s, t) => s + t.amount)
                      : 0.0;

                  final envSelectedCount = filteredEnvelopes
                      .where((e) => selectedIds.contains(e.id))
                      .length;
                  final grpSelectedCount = filteredGroups
                      .where((g) => selectedIds.contains(g.id))
                      .length;

                  return CustomScrollView(
                    slivers: [
                      // Date Range Card
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: _DateRangeCard(
                            start: start,
                            end: end,
                            myOnly: myOnly,
                            onDateTap: _pickRange,
                            onToggleMyOnly: (v) => setState(() => myOnly = v),
                          ),
                        ),
                      ),

                      // Filter Buttons
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: _FilterButton(
                                  icon: Icons.mail_outline,
                                  label: 'Envelopes',
                                  count: envSelectedCount,
                                  onPressed: () =>
                                      _showSelectionSheet<Envelope>(
                                        title: 'Select Envelopes',
                                        items: filteredEnvelopes,
                                        getId: (e) => e.id,
                                        getLabel: (e) async {
                                          final isMyEnvelope =
                                              e.userId ==
                                              widget.repo.currentUserId;
                                          final owner = await widget.repo
                                              .getUserDisplayName(e.userId);
                                          return isMyEnvelope
                                              ? e.name
                                              : '$owner - ${e.name}';
                                        },
                                      ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _FilterButton(
                                  icon: Icons.folder_open,
                                  label: 'Binders',
                                  count: grpSelectedCount,
                                  onPressed: () =>
                                      _showSelectionSheet<EnvelopeGroup>(
                                        title: 'Select Binders',
                                        items: filteredGroups,
                                        getId: (g) => g.id,
                                        getLabel: (g) async => g.name,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // View Mode Chips
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Wrap(
                            spacing: 8,
                            children: [
                              _viewModeChip(StatsViewMode.combined, 'Combined'),
                              _viewModeChip(
                                StatsViewMode.envelopes,
                                'Envelopes',
                              ),
                              _viewModeChip(StatsViewMode.groups, 'Binders'),
                            ],
                          ),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 16)),

                      // Summary Card
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _SummaryCard(
                            viewMode: _viewMode,
                            count: chosen.length,
                            totalTarget: totalTarget,
                            totalSaved: totalSaved,
                            progress: pct,
                          ),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 16)),

                      // Transaction Stats Card
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _TransactionStatsCard(
                            start: start,
                            end: end,
                            deposited: totDep,
                            withdrawn: totWdr,
                            transferred: totTrnOut,
                          ),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 24)),

                      // Ledger Header
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Icon(
                                Icons.receipt_long,
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Transaction History',
                                style: fontProvider.getTextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${shownTxs.length}',
                                style: fontProvider.getTextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 12)),

                      // Transaction List
                      if (shownTxs.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 64,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No transactions found',
                                  style: fontProvider.getTextStyle(
                                    fontSize: 18,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Try adjusting your filters',
                                  style: fontProvider.getTextStyle(
                                    fontSize: 14,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final t = shownTxs[index];
                              return FutureBuilder<Map<String, String>>(
                                future: _getUserNamesForTransaction(t),
                                builder: (context, snapshot) {
                                  final userNames = snapshot.data ?? {};
                                  return _TransactionTile(
                                    transaction: t,
                                    envMap: envMap,
                                    envelopes: envelopes,
                                    userNames: userNames,
                                    currentUserId: widget.repo.currentUserId,
                                  );
                                },
                              );
                            }, childCount: shownTxs.length),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _viewModeChip(StatsViewMode mode, String label) {
    final isSelected = _viewMode == mode;
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (v) {
        if (v) setState(() => _viewMode = mode);
      },
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      selectedColor: theme.colorScheme.secondary,
      labelStyle: fontProvider.getTextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: isSelected ? Colors.white : theme.colorScheme.onSurface,
      ),
      side: BorderSide(
        color: isSelected
            ? theme.colorScheme.secondary
            : theme.colorScheme.outline,
        width: 2,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _selectionTile({
    required String label,
    required bool selected,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!selected),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withValues(alpha: 0.2),
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  border: Border.all(
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                    width: 2,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: fontProvider.getTextStyle(
                    fontSize: 16,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Map<String, String>> _getUserNamesForTransaction(Transaction t) async {
    final Map<String, String> names = {};

    if (t.type == TransactionType.transfer) {
      if (t.sourceOwnerId != null) {
        names['source'] = await widget.repo.getUserDisplayName(
          t.sourceOwnerId!,
        );
      }
      if (t.targetOwnerId != null) {
        names['target'] = await widget.repo.getUserDisplayName(
          t.targetOwnerId!,
        );
      }
    } else {
      if (t.ownerId != null) {
        names['owner'] = await widget.repo.getUserDisplayName(t.ownerId!);
      }
    }

    return names;
  }
}

// EXTRACTED WIDGETS FOR BETTER ORGANIZATION

class _DateRangeCard extends StatelessWidget {
  const _DateRangeCard({
    required this.start,
    required this.end,
    required this.myOnly,
    required this.onDateTap,
    required this.onToggleMyOnly,
  });

  final DateTime start;
  final DateTime end;
  final bool myOnly;
  final VoidCallback onDateTap;
  final ValueChanged<bool> onToggleMyOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return Material(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onDateTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_today,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date Range',
                      style: fontProvider.getTextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${DateFormat('MMM d').format(start)} - ${DateFormat('MMM d, yyyy').format(end)}',
                      style: fontProvider.getTextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Mine only',
                    style: fontProvider.getTextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  Switch(
                    value: myOnly,
                    activeTrackColor: theme.colorScheme.secondary,
                    onChanged: onToggleMyOnly,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.icon,
    required this.label,
    required this.count,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        side: BorderSide(color: theme.colorScheme.outline, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '$label ($count)',
              style: fontProvider.getTextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.viewMode,
    required this.count,
    required this.totalTarget,
    required this.totalSaved,
    required this.progress,
  });

  final StatsViewMode viewMode;
  final int count;
  final double totalTarget;
  final double totalSaved;
  final double progress;

  String get _title {
    switch (viewMode) {
      case StatsViewMode.combined:
        return 'Combined Summary';
      case StatsViewMode.envelopes:
        return 'Envelopes Only';
      case StatsViewMode.groups:
        return 'Binders Only';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final currency = NumberFormat.currency(symbol: '£');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.secondary.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.pie_chart,
                color: theme.colorScheme.secondary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _title,
                style: fontProvider.getTextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.secondary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count',
                  style: fontProvider.getTextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _StatRow(label: 'Target', value: currency.format(totalTarget)),
          _StatRow(
            label: 'Saved',
            value: currency.format(totalSaved),
            bold: true,
          ),
          _StatRow(
            label: 'Progress',
            value: '${progress.toStringAsFixed(1)}%',
            bold: true,
            color: progress >= 100 ? Colors.green : theme.colorScheme.secondary,
          ),
        ],
      ),
    );
  }
}

class _TransactionStatsCard extends StatelessWidget {
  const _TransactionStatsCard({
    required this.start,
    required this.end,
    required this.deposited,
    required this.withdrawn,
    required this.transferred,
  });

  final DateTime start;
  final DateTime end;
  final double deposited;
  final double withdrawn;
  final double transferred;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final currency = NumberFormat.currency(symbol: '£');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Transaction Summary',
                style: fontProvider.getTextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${DateFormat('MMM d').format(start)} - ${DateFormat('MMM d').format(end)}',
            style: fontProvider.getTextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          _StatRow(
            label: 'Deposited',
            value: currency.format(deposited),
            bold: true,
            color: Colors.green.shade700,
            icon: Icons.arrow_downward,
          ),
          _StatRow(
            label: 'Withdrawn',
            value: currency.format(withdrawn),
            color: Colors.red.shade700,
            icon: Icons.arrow_upward,
          ),
          _StatRow(
            label: 'Transferred Out',
            value: currency.format(transferred),
            color: Colors.blue.shade700,
            icon: Icons.swap_horiz,
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.color,
    this.icon,
  });

  final String label;
  final String value;
  final bool bold;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: fontProvider.getTextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          Text(
            value,
            style: fontProvider.getTextStyle(
              fontSize: 16,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color ?? theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.envMap,
    required this.envelopes,
    required this.userNames,
    required this.currentUserId,
  });

  final Transaction transaction;
  final Map<String, String> envMap;
  final List<Envelope> envelopes;
  final Map<String, String> userNames;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final currency = NumberFormat.currency(symbol: '£');

    final t = transaction;
    final envName = envMap[t.envelopeId] ?? 'Unknown';
    final isTransfer = t.type == TransactionType.transfer;
    final isMyEnvelope =
        envelopes
            .firstWhere(
              (e) => e.id == t.envelopeId,
              orElse: () => Envelope(id: '', name: '', userId: ''),
            )
            .userId ==
        currentUserId;

    // Build title
    String title;
    String? subtitle = t.description.isNotEmpty ? t.description : null;

    if (isTransfer) {
      final sourceOwner = userNames['source'] ?? 'Unknown';
      final targetOwner = userNames['target'] ?? 'Unknown';
      final sourceName = t.sourceEnvelopeName ?? 'Unknown';
      final targetName = t.targetEnvelopeName ?? 'Unknown';
      title = '$sourceOwner: $sourceName → $targetOwner: $targetName';
    } else {
      final ownerName = userNames['owner'] ?? '';
      final prefix = isMyEnvelope ? '' : '$ownerName: ';
      if (t.type == TransactionType.deposit) {
        title = '${prefix}Deposit to $envName';
      } else {
        title = '${prefix}Withdrawal from $envName';
      }
    }

    // Get color and icon
    Color color;
    IconData iconData;
    String amountStr;

    if (t.type == TransactionType.deposit) {
      color = Colors.green.shade700;
      iconData = Icons.arrow_downward;
      amountStr = '+${currency.format(t.amount)}';
    } else if (t.type == TransactionType.withdrawal) {
      color = Colors.red.shade700;
      iconData = Icons.arrow_upward;
      amountStr = '-${currency.format(t.amount)}';
    } else {
      color = Colors.blue.shade700;
      iconData = Icons.swap_horiz;
      amountStr = '→${currency.format(t.amount)}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, color: color, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: fontProvider.getTextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: fontProvider.getTextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amountStr,
                style: fontProvider.getTextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('MMM dd').format(t.date),
                style: fontProvider.getTextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
