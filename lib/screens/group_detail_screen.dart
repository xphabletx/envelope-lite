// lib/screens/group_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/envelope.dart';
import '../models/envelope_group.dart';
import '../models/transaction.dart';
import '../services/envelope_repo.dart';
import '../services/group_repo.dart';
import '../widgets/envelope_tile.dart';
import '../widgets/group_editor.dart' as editor;
import '../widgets/time_machine_indicator.dart';
import 'envelope/envelopes_detail_screen.dart';
import 'envelope/envelope_transaction_list.dart';
import 'stats_history_screen.dart';
import '../providers/font_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/time_machine_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_themes.dart';

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
  bool isMulti = false;
  final selected = <String>{};
  late DateTime _viewingMonth;

  @override
  void initState() {
    super.initState();
    _viewingMonth = DateTime.now();
  }

  BinderColorOption _getBinderColors(int colorIndex, String themeId) {
    final themeColors = ThemeBinderColors.getColorsForTheme(themeId);
    if (colorIndex >= 0 && colorIndex < themeColors.length) {
      return themeColors[colorIndex];
    }
    return themeColors.first;
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

  // Month nav methods...
  void _previousMonth() => setState(
    () => _viewingMonth = DateTime(_viewingMonth.year, _viewingMonth.month - 1),
  );

  void _nextMonth() {
    final timeMachine = Provider.of<TimeMachineProvider>(context, listen: false);
    final nextMonth = DateTime(_viewingMonth.year, _viewingMonth.month + 1);

    // If time machine is active, check if next month exceeds projection date
    if (timeMachine.isActive && timeMachine.futureDate != null) {
      if (nextMonth.isAfter(timeMachine.futureDate!)) {
        debugPrint('[TimeMachine::GroupDetailScreen] Month Navigation:');
        debugPrint('[TimeMachine::GroupDetailScreen]   Blocked navigation beyond ${timeMachine.futureDate}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot navigate beyond projection date (${DateFormat('MMM yyyy').format(timeMachine.futureDate!)})'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }
    }

    setState(() => _viewingMonth = nextMonth);
  }

  void _goToCurrentMonth() => setState(() => _viewingMonth = DateTime.now());

  bool _isCurrentMonth() {
    final now = DateTime.now();
    return _viewingMonth.year == now.year && _viewingMonth.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final locale = Provider.of<LocaleProvider>(context, listen: false);
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);

    final binderColors = _getBinderColors(
      widget.group.colorIndex,
      themeProvider.currentThemeId,
    );

    return Consumer<TimeMachineProvider>(
      builder: (context, timeMachine, _) {
        return StreamBuilder<List<Envelope>>(
          stream: widget.envelopeRepo.envelopesStream(),
          builder: (_, sEnv) {
            final envs = sEnv.data ?? [];
            var inGroup = envs.where((e) => e.groupId == widget.group.id).toList()
              ..sort((a, b) => a.name.compareTo(b.name));

            // Use projected envelopes if time machine is active
            if (timeMachine.isActive) {
              inGroup = inGroup.map((env) => timeMachine.getProjectedEnvelope(env)).toList();
              debugPrint('[TimeMachine::GroupDetailScreen] Binder Totals:');
              debugPrint('[TimeMachine::GroupDetailScreen]   Using projected envelope balances');
            }

            final totTarget = inGroup.fold<double>(
              0,
              (s, e) => s + (e.targetAmount ?? 0),
            );
            final totSaved = inGroup.fold<double>(0, (s, e) => s + e.currentAmount);
            final pct = totTarget > 0 ? (totSaved / totTarget) * 100 : 0.0;

            if (timeMachine.isActive) {
              debugPrint('[TimeMachine::GroupDetailScreen]   Total Saved: $totSaved');
              debugPrint('[TimeMachine::GroupDetailScreen]   Total Target: $totTarget');
            }

        return StreamBuilder<List<Transaction>>(
          stream: widget.envelopeRepo.transactionsStream,
          builder: (_, sTx) {
            return Scaffold(
              backgroundColor: binderColors.paperColor,
              body: CustomScrollView(
                slivers: [
                  // Time Machine Indicator at the top
                  const SliverToBoxAdapter(
                    child: TimeMachineIndicator(),
                  ),

                  SliverAppBar(
                    expandedHeight: 140,
                    pinned: true,
                    backgroundColor: binderColors.binderColor,
                    scrolledUnderElevation: 0,
                    elevation: 0,
                    flexibleSpace: FlexibleSpaceBar(
                      titlePadding: const EdgeInsets.only(left: 60, bottom: 16),
                      title: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          widget.group.name,
                          style: fontProvider.getTextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      background: Container(
                        color: binderColors.binderColor,
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 50, 16, 0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(51),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      widget.group.emoji ?? '📁',
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${inGroup.length} envelopes',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w500,
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
                      IconButton(
                        icon: const Icon(Icons.bar_chart, color: Colors.white),
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
                      ),
                    ],
                  ),
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
                              color: binderColors.binderColor.withAlpha(25),
                              blurRadius: 10,
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
                                  color: binderColors.binderColor,
                                  large: true,
                                ),
                                _StatColumn(
                                  label: 'Target',
                                  value: currency.format(totTarget),
                                  color: theme.colorScheme.onSurface.withAlpha(
                                    153,
                                  ),
                                ),
                                _StatColumn(
                                  label: 'Progress',
                                  value: '${pct.toStringAsFixed(0)}%',
                                  color: binderColors.binderColor,
                                  large: true,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Builder(
                              builder: (context) {
                                final HSLColor hslColor = HSLColor.fromColor(
                                  binderColors.binderColor,
                                );
                                final HSLColor lighterColor = hslColor
                                    .withLightness(0.85)
                                    .withSaturation(
                                      (hslColor.saturation * 0.3).clamp(0.0, 1.0),
                                    );
                                final Color lightGroupColor = lighterColor
                                    .toColor();
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: LinearProgressIndicator(
                                    value: totTarget > 0
                                        ? (totSaved / totTarget).clamp(0.0, 1.0)
                                        : 0.0,
                                    minHeight: 12,
                                    backgroundColor: lightGroupColor,
                                    valueColor: AlwaysStoppedAnimation(
                                      binderColors.binderColor,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: [
                          Text(
                            'Envelopes',
                            style: fontProvider.getTextStyle(
                              fontSize: 28,
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
                                style: fontProvider.getTextStyle(
                                  fontSize: 16,
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
                          child: Text(
                            'No envelopes in this group',
                            style: fontProvider.getTextStyle(
                              fontSize: 20,
                              color: Colors.grey.shade600,
                            ),
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
                                    // Prevent access to partner's envelopes
                                    if (e.userId !=
                                        widget.envelopeRepo.currentUserId) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "You cannot view details of your partner's envelopes",
                                          ),
                                        ),
                                      );
                                      return;
                                    }
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
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemCount: inGroup.length,
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildMonthNavigationBar(theme),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  // Transaction History Section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Recent Activity',
                        style: fontProvider.getTextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Builder(
                        builder: (context) {
                          final allTx = sTx.data ?? [];
                          // Get envelope IDs in this group
                          final envelopeIds = inGroup.map((e) => e.id).toSet();

                          // Filter transactions for envelopes in this group
                          var groupTx = allTx
                              .where((tx) => envelopeIds.contains(tx.envelopeId))
                              .toList()
                            ..sort((a, b) => b.date.compareTo(a.date));

                          // If time machine is active, add projected transactions
                          if (timeMachine.isActive) {
                            final projectedTx = timeMachine.getAllProjectedTransactions(includeTransfers: true)
                                .where((tx) => envelopeIds.contains(tx.envelopeId))
                                .toList();

                            debugPrint('[TimeMachine::GroupDetailScreen] Transaction History:');
                            debugPrint('[TimeMachine::GroupDetailScreen]   Real transactions: ${groupTx.length}');
                            debugPrint('[TimeMachine::GroupDetailScreen]   Projected transactions: ${projectedTx.length}');

                            groupTx = [...groupTx, ...projectedTx]
                              ..sort((a, b) => b.date.compareTo(a.date));

                            debugPrint('[TimeMachine::GroupDetailScreen]   Merged total: ${groupTx.length}');
                          }

                          // Filter by viewing month
                          final monthStart = DateTime(_viewingMonth.year, _viewingMonth.month, 1);
                          final monthEnd = DateTime(_viewingMonth.year, _viewingMonth.month + 1, 0, 23, 59, 59);

                          final monthTx = groupTx
                              .where((tx) =>
                                  tx.date.isAfter(monthStart.subtract(const Duration(milliseconds: 1))) &&
                                  tx.date.isBefore(monthEnd.add(const Duration(milliseconds: 1))))
                              .toList();

                          if (monthTx.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(40),
                              child: Center(
                                child: Text(
                                  'No transactions this month',
                                  style: fontProvider.getTextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            );
                          }

                          return EnvelopeTransactionList(
                            transactions: monthTx,
                            onTransactionTap: null,
                          );
                        },
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            );
          },
        );
          },
        );
      },
    );
  }

  Widget _buildMonthNavigationBar(ThemeData theme) {
    final monthName = DateFormat('MMMM yyyy').format(_viewingMonth);
    final isCurrentMonth = _isCurrentMonth();
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withAlpha(51)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _previousMonth,
            color: theme.colorScheme.primary,
          ),
          Expanded(
            child: InkWell(
              onTap: isCurrentMonth ? null : _goToCurrentMonth,
              child: Column(
                children: [
                  Text(
                    monthName,
                    style: fontProvider.getTextStyle(
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
                        color: theme.colorScheme.onSurface.withAlpha(128),
                      ),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: isCurrentMonth ? null : _nextMonth,
            color: isCurrentMonth
                ? theme.colorScheme.onSurface.withAlpha(77)
                : theme.colorScheme.primary,
          ),
        ],
      ),
    );
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
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
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
          style: fontProvider.getTextStyle(
            fontSize: large ? 24 : 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}