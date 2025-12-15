// lib/screens/stats_history_screen.dart
// THEME & FONT FIXES ONLY - All other logic preserved from original

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
  });

  final EnvelopeRepo repo;
  final Set<String>? initialEnvelopeIds;
  final Set<String>? initialGroupIds;
  final DateTime? initialStart;
  final DateTime? initialEnd;
  final bool myOnlyDefault;
  final String? title;

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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: fontProvider.getTextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            color: theme.colorScheme.onSurface,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: theme.colorScheme.outline),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
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
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Select All',
                                style: fontProvider.getTextStyle(),
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
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Deselect All',
                                style: fontProvider.getTextStyle(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final id = getId(item);
                        final isSelected = selectedIds.contains(id);

                        return FutureBuilder<String>(
                          future: getLabel(item),
                          builder: (context, snapshot) {
                            final label = snapshot.data ?? '...';
                            return _circleRow(
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
      appBar: AppBar(
        title: Text(
          title,
          style: fontProvider.getTextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            tooltip: 'Pick date range',
            onPressed: _pickRange,
            icon: Icon(Icons.calendar_month, color: theme.colorScheme.primary),
          ),
        ],
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
                  final shownTxs = txs.where((t) {
                    final inChosen = chosenIds.contains(t.envelopeId);
                    final inRange =
                        !t.date.isBefore(start) && t.date.isBefore(end);
                    return inChosen && inRange;
                  }).toList()..sort((a, b) => b.date.compareTo(a.date));

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

                  final double totDep = shownTxs
                      .where((t) => t.type == TransactionType.deposit)
                      .fold(0.0, (s, t) => s + t.amount);
                  final double totWdr = shownTxs
                      .where((t) => t.type == TransactionType.withdrawal)
                      .fold(0.0, (s, t) => s + t.amount);
                  final double totTrnOut = shownTxs
                      .where(
                        (t) =>
                            t.type == TransactionType.transfer &&
                            t.transferDirection == TransferDirection.out_,
                      )
                      .fold(0.0, (s, t) => s + t.amount);

                  final envSelectedCount = filteredEnvelopes
                      .where((e) => selectedIds.contains(e.id))
                      .length;
                  final grpSelectedCount = filteredGroups
                      .where((g) => selectedIds.contains(g.id))
                      .length;

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Date Range',
                                    style: fontProvider.getTextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                  Text(
                                    '${DateFormat('MMM d, yyyy').format(start)} — ${DateFormat('MMM d, yyyy').format(end)}',
                                    style: fontProvider.getTextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  'Mine only',
                                  style: fontProvider.getTextStyle(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                Switch(
                                  value: myOnly,
                                  activeColor: theme.colorScheme.primary,
                                  onChanged: (v) => setState(() => myOnly = v),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const Divider(height: 24),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: Icon(
                                  Icons.mail_outline,
                                  size: 20,
                                  color: theme.colorScheme.primary,
                                ),
                                label: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Envelopes ($envSelectedCount)',
                                    style: fontProvider.getTextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                    horizontal: 8,
                                  ),
                                  side: BorderSide(
                                    color: theme.colorScheme.outline,
                                    width: 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () => _showSelectionSheet<Envelope>(
                                  title: 'Filter Envelopes',
                                  items: filteredEnvelopes,
                                  getId: (e) => e.id,
                                  getLabel: (e) async {
                                    final isMyEnvelope =
                                        e.userId == widget.repo.currentUserId;
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
                              child: OutlinedButton.icon(
                                icon: Icon(
                                  Icons.folder_open,
                                  size: 20,
                                  color: theme.colorScheme.primary,
                                ),
                                label: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Groups ($grpSelectedCount)',
                                    style: fontProvider.getTextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                    horizontal: 8,
                                  ),
                                  side: BorderSide(
                                    color: theme.colorScheme.outline,
                                    width: 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () =>
                                    _showSelectionSheet<EnvelopeGroup>(
                                      title: 'Filter Groups',
                                      items: filteredGroups,
                                      getId: (g) => g.id,
                                      getLabel: (g) async => g.name,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8.0,
                            runSpacing: 8.0,
                            children: [
                              _viewModeChip(StatsViewMode.combined, 'Combined'),
                              _viewModeChip(
                                StatsViewMode.envelopes,
                                'Envelopes',
                              ),
                              _viewModeChip(StatsViewMode.groups, 'Groups'),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: theme.colorScheme.outline.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _sectionHeader(
                                    _getSummaryTitle(chosen.length),
                                  ),
                                  const SizedBox(height: 8),
                                  _kv(
                                    'Total Target',
                                    currency.format(totalTarget),
                                  ),
                                  _kv(
                                    'Total Saved',
                                    currency.format(totalSaved),
                                    bold: true,
                                  ),
                                  _kv(
                                    'Progress',
                                    '${pct.toStringAsFixed(1)}%',
                                    bold: true,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            _sectionHeader(
                              'Transactions (${DateFormat('MMM d').format(start)} - ${DateFormat('MMM d').format(end)})',
                            ),
                            const SizedBox(height: 8),
                            _kv(
                              'Total Deposited',
                              currency.format(totDep),
                              bold: true,
                              color: Colors.green.shade700,
                            ),
                            _kv(
                              'Total Withdrawn',
                              currency.format(totWdr),
                              color: Colors.red.shade700,
                            ),
                            _kv(
                              'Transferred Out',
                              currency.format(totTrnOut),
                              color: Colors.blue.shade700,
                            ),

                            const Divider(height: 32),

                            _sectionHeader('Ledger'),
                            if (shownTxs.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(32),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.receipt_long_outlined,
                                        size: 48,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.3),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No transactions found',
                                        style: fontProvider.getTextStyle(
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              ...shownTxs.map((t) {
                                return FutureBuilder<Map<String, String>>(
                                  future: _getUserNamesForTransaction(t),
                                  builder: (context, snapshot) {
                                    final userNames = snapshot.data ?? {};
                                    final envName =
                                        envMap[t.envelopeId] ?? 'Unknown';
                                    final isTransfer =
                                        t.type == TransactionType.transfer;
                                    final isMyEnvelope =
                                        envelopes
                                            .firstWhere(
                                              (e) => e.id == t.envelopeId,
                                              orElse: () => Envelope(
                                                id: '',
                                                name: '',
                                                userId: '',
                                              ),
                                            )
                                            .userId ==
                                        widget.repo.currentUserId;

                                    String title;
                                    String? subtitle = t.description.isNotEmpty
                                        ? t.description
                                        : null;

                                    if (isTransfer) {
                                      final sourceOwner =
                                          userNames['source'] ?? 'Unknown';
                                      final targetOwner =
                                          userNames['target'] ?? 'Unknown';
                                      final sourceName =
                                          t.sourceEnvelopeName ?? 'Unknown';
                                      final targetName =
                                          t.targetEnvelopeName ?? 'Unknown';
                                      title =
                                          '$sourceOwner: $sourceName → $targetOwner: $targetName';
                                    } else {
                                      final ownerName =
                                          userNames['owner'] ?? '';
                                      final prefix = isMyEnvelope
                                          ? ''
                                          : '$ownerName: ';
                                      if (t.type == TransactionType.deposit) {
                                        title = '${prefix}Deposit on $envName';
                                      } else {
                                        title =
                                            '${prefix}Withdrawal on $envName';
                                      }
                                    }

                                    final amountStr = _signed(t);
                                    final color = _col(t);

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surface,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: theme.colorScheme.outline
                                              .withValues(alpha: 0.2),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: color.withValues(
                                                alpha: 0.1,
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              isTransfer
                                                  ? Icons.swap_horiz
                                                  : (t.type ==
                                                            TransactionType
                                                                .deposit
                                                        ? Icons.arrow_downward
                                                        : Icons.arrow_upward),
                                              color: color,
                                              size: 16,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  title,
                                                  style: fontProvider
                                                      .getTextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: theme
                                                            .colorScheme
                                                            .onSurface,
                                                      ),
                                                ),
                                                if (subtitle != null)
                                                  Text(
                                                    subtitle,
                                                    style: fontProvider
                                                        .getTextStyle(
                                                          fontSize: 12,
                                                          color: theme
                                                              .colorScheme
                                                              .onSurface
                                                              .withValues(
                                                                alpha: 0.5,
                                                              ),
                                                        ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                amountStr,
                                                style: fontProvider
                                                    .getTextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: color,
                                                      fontSize: 15,
                                                    ),
                                              ),
                                              Text(
                                                DateFormat(
                                                  'MMM dd',
                                                ).format(t.date),
                                                style: fontProvider
                                                    .getTextStyle(
                                                      fontSize: 11,
                                                      color: theme
                                                          .colorScheme
                                                          .onSurface
                                                          .withValues(
                                                            alpha: 0.4,
                                                          ),
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              }),
                          ],
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
      selectedColor: theme.colorScheme.primary,
      labelStyle: fontProvider.getTextStyle(
        color: isSelected
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected
            ? theme.colorScheme.primary
            : theme.colorScheme.outline,
      ),
    );
  }

  String _getSummaryTitle(int count) {
    switch (_viewMode) {
      case StatsViewMode.combined:
        return 'Combined Summary ($count Envelopes)';
      case StatsViewMode.envelopes:
        return 'Envelopes Summary ($count Selected)';
      case StatsViewMode.groups:
        return 'Groups Summary ($count via Groups)';
    }
  }

  Widget _sectionHeader(String s) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    return Text(
      s,
      style: fontProvider.getTextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurface,
      ),
    );
  }

  Widget _kv(String k, String v, {bool bold = false, Color? color}) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            k,
            style: fontProvider.getTextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          Text(
            v,
            style: fontProvider.getTextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color ?? theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleRow({
    required String label,
    required bool selected,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    return InkWell(
      onTap: () => onChanged(!selected),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  ? Icon(
                      Icons.check,
                      size: 16,
                      color: theme.colorScheme.onPrimary,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: fontProvider.getTextStyle(
                  fontSize: 16,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _signed(Transaction t) {
    switch (t.type) {
      case TransactionType.deposit:
        return '+${currency.format(t.amount)}';
      case TransactionType.withdrawal:
        return '-${currency.format(t.amount)}';
      case TransactionType.transfer:
        return '→${currency.format(t.amount)}';
    }
  }

  Color _col(Transaction t) {
    switch (t.type) {
      case TransactionType.deposit:
        return Colors.green.shade700;
      case TransactionType.withdrawal:
        return Colors.red.shade700;
      case TransactionType.transfer:
        return Colors.blue.shade700;
    }
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
