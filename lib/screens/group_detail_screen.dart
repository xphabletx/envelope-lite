import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/envelope.dart';
import '../models/envelope_group.dart';
import '../models/transaction.dart';
import '../services/envelope_repo.dart';
import '../services/group_repo.dart';
import '../widgets/envelope_tile.dart';
import '../widgets/group_editor.dart' as editor;
import 'envelope/envelopes_detail_screen.dart';
import 'stats_history_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  const GroupDetailScreen({
    super.key,
    required this.group,
    required this.groupRepo,
    required this.envelopeRepo,
  });

  final EnvelopeGroup group;
  final GroupRepo groupRepo;
  final EnvelopeRepo envelopeRepo;

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final currency = NumberFormat.currency(symbol: '£');

  bool isMulti = false;
  final selected = <String>{};

  // Month navigation
  late DateTime _viewingMonth;

  @override
  void initState() {
    super.initState();
    _viewingMonth = DateTime.now();
  }

  void _previousMonth() {
    setState(() {
      _viewingMonth = DateTime(_viewingMonth.year, _viewingMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _viewingMonth = DateTime(_viewingMonth.year, _viewingMonth.month + 1);
    });
  }

  void _goToCurrentMonth() {
    setState(() {
      _viewingMonth = DateTime.now();
    });
  }

  bool _isCurrentMonth() {
    final now = DateTime.now();
    return _viewingMonth.year == now.year && _viewingMonth.month == now.month;
  }

  void _toggle(String id) {
    setState(() {
      if (selected.contains(id)) {
        selected.remove(id);
      } else {
        selected.add(id);
      }
      isMulti = selected.isNotEmpty;
      if (!isMulti) selected.clear();
    });
  }

  Future<void> _openSettings() async {
    await editor.showGroupEditor(
      context: context,
      groupRepo: widget.groupRepo,
      envelopeRepo: widget.envelopeRepo,
      group: widget.group,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupColor = GroupColors.getThemedColor(
      widget.group.colorName ?? 'Primary',
      theme.colorScheme,
    );

    return StreamBuilder<List<Envelope>>(
      stream: widget.envelopeRepo.envelopesStream(),
      builder: (_, sEnv) {
        final envs = sEnv.data ?? [];
        final inGroup = envs.where((e) => e.groupId == widget.group.id).toList()
          ..sort((a, b) => a.name.compareTo(b.name));

        final totTarget = inGroup.fold<double>(
          0,
          (s, e) => s + (e.targetAmount ?? 0),
        );
        final totSaved = inGroup.fold<double>(0, (s, e) => s + e.currentAmount);
        final pct = totTarget > 0 ? (totSaved / totTarget) * 100 : 0.0;

        return StreamBuilder<List<Transaction>>(
          stream: widget.envelopeRepo.transactionsStream,
          builder: (_, sTx) {
            final txs = sTx.data ?? [];
            final groupIds = inGroup.map((e) => e.id).toSet();

            // Filter transactions for the viewing month
            final monthStart = DateTime(
              _viewingMonth.year,
              _viewingMonth.month,
              1,
            );
            final monthEnd = DateTime(
              _viewingMonth.year,
              _viewingMonth.month + 1,
              0,
              23,
              59,
              59,
            );

            final shownTxs = txs.where((t) {
              final inChosen = groupIds.contains(t.envelopeId);
              final inRange =
                  t.date.isAfter(
                    monthStart.subtract(const Duration(seconds: 1)),
                  ) &&
                  t.date.isBefore(monthEnd.add(const Duration(seconds: 1)));
              return inChosen && inRange;
            }).toList()..sort((a, b) => b.date.compareTo(a.date));

            final totDep = shownTxs
                .where((t) => t.type == TransactionType.deposit)
                .fold<double>(0, (s, t) => s + t.amount);
            final totWdr = shownTxs
                .where((t) => t.type == TransactionType.withdrawal)
                .fold<double>(0, (s, t) => s + t.amount);

            return Scaffold(
              backgroundColor: theme.scaffoldBackgroundColor,
              body: CustomScrollView(
                slivers: [
                  // Gorgeous App Bar
                  SliverAppBar(
                    expandedHeight: 200,
                    pinned: true,
                    backgroundColor: groupColor,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [groupColor, groupColor.withAlpha(204)],
                          ),
                        ),
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withAlpha(51),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 3,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          widget.group.emoji ?? '📁',
                                          style: const TextStyle(fontSize: 36),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            widget.group.name,
                                            style: GoogleFonts.caveat(
                                              fontSize: 38,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          Text(
                                            '${inGroup.length} envelopes',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    actions: [
                      // Stats/History button
                      IconButton(
                        icon: const Icon(Icons.bar_chart, color: Colors.white),
                        tooltip: 'View full history',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => StatsHistoryScreen(
                                repo: widget.envelopeRepo,
                                initialGroupIds: {widget.group.id},
                                title: '${widget.group.name} - History',
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings, color: Colors.white),
                        onPressed: _openSettings,
                        tooltip: 'Group Settings',
                      ),
                    ],
                  ),

                  // Stats Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: groupColor.withAlpha(51),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _StatColumn(
                                  label: 'Total Saved',
                                  value: currency.format(totSaved),
                                  color: groupColor,
                                  large: true,
                                ),
                                _StatColumn(
                                  label: 'Target',
                                  value: currency.format(totTarget),
                                  color: theme.colorScheme.onSurface.withAlpha(
                                    179,
                                  ),
                                ),
                                _StatColumn(
                                  label: 'Progress',
                                  value: '${pct.toStringAsFixed(0)}%',
                                  color: groupColor,
                                  large: true,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: LinearProgressIndicator(
                                value: totTarget > 0
                                    ? (totSaved / totTarget).clamp(0.0, 1.0)
                                    : 0.0,
                                minHeight: 12,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation(groupColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Envelopes Section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: [
                          Text(
                            'Envelopes',
                            style: GoogleFonts.caveat(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const Spacer(),
                          if (isMulti)
                            TextButton(
                              onPressed: () => setState(() {
                                selected.clear();
                                isMulti = false;
                              }),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.caveat(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  if (inGroup.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.mail_outline,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No envelopes in this group',
                                style: GoogleFonts.caveat(
                                  fontSize: 24,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap settings to add envelopes',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList.separated(
                        itemBuilder: (_, i) {
                          final e = inGroup[i];
                          final isSel = selected.contains(e.id);
                          return EnvelopeTile(
                            envelope: e,
                            allEnvelopes: envs,
                            isSelected: isSel,
                            onLongPress: () => _toggle(e.id),
                            onTap: isMulti
                                ? () => _toggle(e.id)
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => EnvelopeDetailScreen(
                                          envelopeId: e.id,
                                          repo: widget.envelopeRepo,
                                        ),
                                      ),
                                    );
                                  },
                            repo: widget.envelopeRepo,
                            isMultiSelectMode: isMulti,
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemCount: inGroup.length,
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // Month navigation bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildMonthNavigationBar(theme),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 12)),

                  // Transactions stats for the month
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.outline.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _StatColumn(
                              label: 'Deposited',
                              value: currency.format(totDep),
                              color: Colors.green.shade700,
                            ),
                            _StatColumn(
                              label: 'Withdrawn',
                              value: currency.format(totWdr),
                              color: Colors.red.shade700,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // Transactions Section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Text(
                        'Transactions',
                        style: GoogleFonts.caveat(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),

                  if (shownTxs.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No transactions this month',
                                style: GoogleFonts.caveat(
                                  fontSize: 24,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList.separated(
                        itemBuilder: (_, i) {
                          final t = shownTxs[i];
                          final envName = _envName(t.envelopeId, inGroup);
                          final label = switch (t.type) {
                            TransactionType.deposit => 'Deposit → $envName',
                            TransactionType.withdrawal =>
                              'Withdrawal → $envName',
                            TransactionType.transfer =>
                              (t.transferDirection == TransferDirection.in_)
                                  ? 'Transfer From ${_envName(t.transferPeerEnvelopeId, inGroup)}'
                                  : 'Transfer To ${_envName(t.transferPeerEnvelopeId, inGroup)}',
                          };
                          final color = _col(t);
                          final signed = _signed(t);
                          final icon = _icon(t);

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: color.withAlpha(26),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(icon, color: color, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        label,
                                        style: GoogleFonts.caveat(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (t.description.isNotEmpty)
                                        Text(
                                          t.description,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: theme.colorScheme.onSurface
                                                .withAlpha(153),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      signed,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: color,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      DateFormat('MMM dd').format(t.date),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: theme.colorScheme.onSurface
                                            .withAlpha(128),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemCount: shownTxs.length,
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 96)),
                ],
              ),
              floatingActionButton: isMulti
                  ? FloatingActionButton.extended(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      icon: const Icon(Icons.delete_forever),
                      label: Text(
                        'Delete (${selected.length})',
                        style: GoogleFonts.caveat(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () async {
                        await widget.envelopeRepo.deleteEnvelopes(selected);
                        setState(() {
                          selected.clear();
                          isMulti = false;
                        });
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Envelopes deleted')),
                        );
                      },
                    )
                  : FloatingActionButton.extended(
                      backgroundColor: groupColor,
                      foregroundColor: Colors.white,
                      icon: const Icon(Icons.settings),
                      label: Text(
                        'Edit Group',
                        style: GoogleFonts.caveat(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: _openSettings,
                    ),
            );
          },
        );
      },
    );
  }

  // Month navigation bar with arrows
  Widget _buildMonthNavigationBar(ThemeData theme) {
    final monthName = DateFormat('MMMM yyyy').format(_viewingMonth);
    final isCurrentMonth = _isCurrentMonth();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          // Previous month button
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _previousMonth,
            color: theme.colorScheme.primary,
          ),

          // Current month label (tappable to return to current month)
          Expanded(
            child: InkWell(
              onTap: isCurrentMonth ? null : _goToCurrentMonth,
              child: Column(
                children: [
                  Text(
                    monthName,
                    style: GoogleFonts.caveat(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (!isCurrentMonth)
                    Text(
                      'Tap to return to current month',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
          ),

          // Next month button (disabled if current or future)
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: isCurrentMonth ? null : _nextMonth,
            color: isCurrentMonth
                ? theme.colorScheme.onSurface.withOpacity(0.3)
                : theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }

  String _envName(String? id, List<Envelope> inGroup) {
    if (id == null) return 'Unknown';
    return inGroup
        .firstWhere(
          (e) => e.id == id,
          orElse: () => Envelope(id: '', name: 'Unknown', userId: ''),
        )
        .name;
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

  IconData _icon(Transaction t) {
    switch (t.type) {
      case TransactionType.deposit:
        return Icons.arrow_downward;
      case TransactionType.withdrawal:
        return Icons.arrow_upward;
      case TransactionType.transfer:
        return Icons.swap_horiz;
    }
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool large;

  const _StatColumn({
    required this.label,
    required this.value,
    required this.color,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.caveat(
            fontSize: large ? 24 : 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
