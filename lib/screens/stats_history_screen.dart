// lib/screens/stats_history_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/envelope.dart';
import '../models/envelope_group.dart';
import '../models/transaction.dart';
import '../services/envelope_repo.dart';

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

  /// Data source
  final EnvelopeRepo repo;

  /// (Optional) Preselect specific envelope IDs
  final Set<String>? initialEnvelopeIds;

  /// (Optional) Preselect specific group IDs
  final Set<String>? initialGroupIds;

  /// (Optional) Initial range start (defaults to now - 30d)
  final DateTime? initialStart;

  /// (Optional) Initial range end (defaults to now)
  final DateTime? initialEnd;

  /// (Optional) Initial "mine only" toggle
  final bool myOnlyDefault;

  /// (Optional) Custom screen title
  final String? title;

  @override
  State<StatsHistoryScreen> createState() => _StatsHistoryScreenState();
}

class _StatsHistoryScreenState extends State<StatsHistoryScreen> {
  final currency = NumberFormat.currency(symbol: '£');

  /// Selection: can contain envelope IDs and/or group IDs
  final selectedIds = <String>{};

  /// Toggle to filter by current user
  late bool myOnly;

  /// Date range (inclusive of end day)
  late DateTime start;
  late DateTime end;

  /// One-time flag so we don’t overwrite preselection after streams arrive
  bool _didApplyExplicitInitialSelection = false;

  @override
  void initState() {
    super.initState();

    myOnly = widget.myOnlyDefault;

    // Default date range if not provided
    start =
        (widget.initialStart ??
        DateTime.now().subtract(const Duration(days: 30)));
    // Include entire end day by setting time to 23:59:59.999
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

    // If caller provided explicit selections, apply now and lock the init path
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

  @override
  Widget build(BuildContext context) {
    final title = widget.title ?? 'Statistics & History';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Pick date range',
            onPressed: _pickRange,
            icon: const Icon(Icons.calendar_month),
          ),
        ],
      ),
      body: StreamBuilder<List<Envelope>>(
        stream: widget.repo.envelopesStream,
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

                  // If no explicit preselection and nothing has been selected yet,
                  // default to "everything selected" once data arrives.
                  if (!_didApplyExplicitInitialSelection &&
                      selectedIds.isEmpty &&
                      (envelopes.isNotEmpty || groups.isNotEmpty)) {
                    selectedIds
                      ..clear()
                      ..addAll(envelopes.map((e) => e.id))
                      ..addAll(groups.map((g) => g.id));
                  }

                  // Filters
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

                  // Determine selection composition
                  final selectedGroupIds = selectedIds
                      .where((id) => groups.any((g) => g.id == id))
                      .toSet();
                  final selectedEnvelopeIds = selectedIds
                      .where((id) => envelopes.any((e) => e.id == id))
                      .toSet();

                  // Final set of envelopes "in scope": directly selected OR members of selected groups
                  final chosen = <Envelope>[
                    for (final e in filteredEnvelopes)
                      if (selectedEnvelopeIds.contains(e.id) ||
                          (e.groupId != null &&
                              selectedGroupIds.contains(e.groupId)))
                        e,
                  ];

                  final envMap = {for (final e in envelopes) e.id: e.name};

                  // Transaction filter
                  final chosenIds = chosen.map((e) => e.id).toSet();
                  final shownTxs = txs.where((t) {
                    final inChosen = chosenIds.contains(t.envelopeId);
                    final inRange =
                        !t.date.isBefore(start) && t.date.isBefore(end);
                    return inChosen && inRange;
                  }).toList()..sort((a, b) => b.date.compareTo(a.date));

                  // Summary metrics
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

                  return Column(
                    children: [
                      // Top controls
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${DateFormat('MMM d, yyyy').format(start)} — ${DateFormat('MMM d, yyyy').format(end)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text('Mine only'),
                            Switch(
                              value: myOnly,
                              activeColor: Colors.black,
                              onChanged: (v) => setState(() => myOnly = v),
                            ),
                          ],
                        ),
                      ),

                      // Selection actions
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            FilledButton.tonal(
                              onPressed: () {
                                setState(() {
                                  _didApplyExplicitInitialSelection =
                                      true; // <-- add

                                  selectedIds
                                    ..clear()
                                    ..addAll(envelopes.map((e) => e.id))
                                    ..addAll(groups.map((g) => g.id));
                                });
                              },
                              child: const Text('Select All'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _didApplyExplicitInitialSelection =
                                      true; // <-- add
                                  selectedIds.clear();
                                });
                              },
                              child: const Text('Deselect All'),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Body
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          children: [
                            // Envelope selectors
                            Text(
                              'Envelopes',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            ...filteredEnvelopes.map((e) {
                              final isMyEnvelope =
                                  e.userId == widget.repo.currentUserId;
                              return FutureBuilder<String>(
                                future: widget.repo.getUserDisplayName(
                                  e.userId,
                                ),
                                builder: (context, snapshot) {
                                  final ownerName = snapshot.data ?? '';
                                  final displayLabel = isMyEnvelope
                                      ? e.name
                                      : '$ownerName - ${e.name}';

                                  return _circleRow(
                                    label: displayLabel,
                                    selected: selectedIds.contains(e.id),
                                    onChanged: (v) => setState(() {
                                      _didApplyExplicitInitialSelection = true;
                                      v
                                          ? selectedIds.add(e.id)
                                          : selectedIds.remove(e.id);
                                    }),
                                  );
                                },
                              );
                            }),

                            const Divider(height: 24),

                            // Group selectors
                            Text(
                              'Groups',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            ...filteredGroups.map(
                              (g) => _circleRow(
                                label: '${g.name} (Group)',
                                selected: selectedIds.contains(g.id),
                                onChanged: (v) => setState(() {
                                  _didApplyExplicitInitialSelection =
                                      true; // <-- add

                                  v
                                      ? selectedIds.add(g.id)
                                      : selectedIds.remove(g.id);
                                }),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Summary
                            _sectionHeader(
                              'Summary for ${chosen.length} Envelopes',
                            ),
                            _kv(
                              'Total Target Amount',
                              currency.format(totalTarget),
                            ),
                            _kv(
                              'Total Saved Amount',
                              currency.format(totalSaved),
                              bold: true,
                            ),
                            _kv(
                              'Percent Towards Target',
                              '${pct.toStringAsFixed(1)}%',
                              bold: true,
                            ),

                            const Divider(height: 24),

                            // Totals in range
                            _sectionHeader(
                              'Transactions (${DateFormat('MMM d').format(start)} - ${DateFormat('MMM d').format(end)})',
                            ),
                            _kv(
                              'Total Deposited',
                              currency.format(totDep),
                              bold: true,
                            ),
                            _kv('Total Withdrawn', currency.format(totWdr)),
                            _kv(
                              'Total Transferred Out',
                              currency.format(totTrnOut),
                            ),
                            const SizedBox(height: 8),
                            const Divider(),

                            // Details
                            _sectionHeader('Transaction Details'),
                            if (shownTxs.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(24),
                                child: Center(
                                  child: Text(
                                    'No transactions in this range.',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
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
                                      // Show source and target with owner names
                                      final sourceOwner =
                                          userNames['source'] ?? 'Unknown';
                                      final targetOwner =
                                          userNames['target'] ?? 'Unknown';
                                      final sourceName =
                                          t.sourceEnvelopeName ?? 'Unknown';
                                      final targetName =
                                          t.targetEnvelopeName ?? 'Unknown';

                                      if (t.transferDirection ==
                                          TransferDirection.in_) {
                                        // Money coming IN
                                        title =
                                            '$sourceOwner: $sourceName → $targetOwner: $targetName';
                                      } else {
                                        // Money going OUT
                                        title =
                                            '$sourceOwner: $sourceName → $targetOwner: $targetName';
                                      }
                                    } else {
                                      // Deposit or Withdrawal
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

                                    return ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        title,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      subtitle: subtitle != null
                                          ? Text(
                                              subtitle,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            )
                                          : null,
                                      trailing: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            amountStr,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: color,
                                            ),
                                          ),
                                          Text(
                                            DateFormat(
                                              'MMM dd, HH:mm',
                                            ).format(t.date),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
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

  // ——— UI helpers ———

  Widget _sectionHeader(String s) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      s,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    ),
  );

  Widget _kv(String k, String v, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k, style: TextStyle(color: Colors.grey.shade700)),
        Text(
          v,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    ),
  );

  Widget _circleRow({
    required String label,
    required bool selected,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!selected),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Checkbox(
              value: selected,
              onChanged: (v) => onChanged(v ?? false),
              shape: const CircleBorder(),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              activeColor: Colors.black,
            ),
            const SizedBox(width: 6),
            Expanded(child: Text(label)),
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
        // neutral arrow — amount shown positive here
        return '→${currency.format(t.amount)}';
    }
  }

  Color _col(Transaction t) {
    switch (t.type) {
      case TransactionType.deposit:
        return Colors.green.shade800;
      case TransactionType.withdrawal:
        return Colors.red.shade800;
      case TransactionType.transfer:
        return Colors.blue.shade800;
    }
  }

  Future<Map<String, String>> _getUserNamesForTransaction(Transaction t) async {
    final Map<String, String> names = {};

    if (t.type == TransactionType.transfer) {
      // Get both source and target owner names
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
      // Get single owner name for deposit/withdrawal
      if (t.ownerId != null) {
        names['owner'] = await widget.repo.getUserDisplayName(t.ownerId!);
      }
    }

    return names;
  }
}
