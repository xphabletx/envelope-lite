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
import 'envelope/envelopes_detail_screen.dart';
import 'stats_history_screen.dart';
import '../providers/font_provider.dart';
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
  final currency = NumberFormat.currency(symbol: '£');
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
  void _nextMonth() => setState(
    () => _viewingMonth = DateTime(_viewingMonth.year, _viewingMonth.month + 1),
  );
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

    final binderColors = _getBinderColors(
      widget.group.colorIndex,
      themeProvider.currentThemeId,
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
            return Scaffold(
              backgroundColor: binderColors.paperColor,
              body: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 140,
                    pinned: true,
                    backgroundColor: binderColors.binderColor,
                    scrolledUnderElevation: 0,
                    elevation: 0,
                    flexibleSpace: FlexibleSpaceBar(
                      titlePadding: const EdgeInsets.only(left: 60, bottom: 16),
                      title: Text(
                        widget.group.name,
                        style: fontProvider.getTextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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
                                  color: theme.colorScheme.onSurface
                                      .withAlpha(153),
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
                            Builder(builder: (context) {
                              final HSLColor hslColor =
                                  HSLColor.fromColor(binderColors.binderColor);
                              final HSLColor lighterColor = hslColor
                                  .withLightness(
                                      (hslColor.lightness + 0.4).clamp(0.0, 1.0));
                              final Color lightGroupColor =
                                  lighterColor.toColor();
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: LinearProgressIndicator(
                                  value: totTarget > 0
                                      ? (totSaved / totTarget).clamp(0.0, 1.0)
                                      : 0.0,
                                  minHeight: 12,
                                  backgroundColor: lightGroupColor,
                                  valueColor: AlwaysStoppedAnimation(
                                      binderColors.binderColor),
                                ),
                              );
                            }),
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
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
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
        border: Border.all(
          color: theme.colorScheme.outline.withAlpha(51),
        ),
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