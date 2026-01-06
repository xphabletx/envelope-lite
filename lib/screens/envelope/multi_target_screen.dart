// lib/screens/envelope/multi_target_screen.dart
// Context-aware target screen supporting single/multiple envelopes and binders

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/envelope.dart';
import '../../models/envelope_group.dart';
import '../../services/envelope_repo.dart';
import '../../services/group_repo.dart';
import '../../services/account_repo.dart';
import '../../providers/font_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/time_machine_provider.dart';
import '../../utils/target_helper.dart';
import '../../utils/calculator_helper.dart';
import '../../widgets/time_machine_indicator.dart';
import '../../../widgets/common/smart_text_field.dart';

enum TargetScreenMode {
  singleEnvelope, // From envelope detail
  multiEnvelope, // From budget overview or multi-selection
  binderFiltered, // From binder target chip
}

class MultiTargetScreen extends StatefulWidget {
  const MultiTargetScreen({
    super.key,
    required this.envelopeRepo,
    required this.groupRepo,
    required this.accountRepo,
    this.initialEnvelopeIds,
    this.initialGroupId,
    this.mode = TargetScreenMode.multiEnvelope,
    this.title,
  });

  final EnvelopeRepo envelopeRepo;
  final GroupRepo groupRepo;
  final AccountRepo accountRepo;
  final List<String>? initialEnvelopeIds; // Pre-selected envelope IDs
  final String? initialGroupId; // Filter by binder/group
  final TargetScreenMode mode;
  final String? title; // Custom title

  @override
  State<MultiTargetScreen> createState() => _MultiTargetScreenState();
}

class _MultiTargetScreenState extends State<MultiTargetScreen> {
  final Set<String> _selectedEnvelopeIds = {};
  final Map<String, double> _contributionAllocations =
      {}; // envelopeId -> percentage (0-100)
  final Map<String, String> _envelopeFrequencies =
      {}; // envelopeId -> frequency
  final TextEditingController _totalContributionController =
      TextEditingController();
  String _defaultFrequency = 'monthly';
  bool _showCalculator = false;
  final Set<String> _expandedBinderIds = {}; // Track which binders are expanded
  final Set<String> _expandedEnvelopeProjections =
      {}; // Track which envelope projections are expanded
  List<EnvelopeGroup> _cachedGroups =
      []; // Cache groups to prevent "Unknown Binder" during rebuilds

  @override
  void initState() {
    super.initState();
    // Pre-select initial envelopes if provided
    if (widget.initialEnvelopeIds != null) {
      _selectedEnvelopeIds.addAll(widget.initialEnvelopeIds!);
    }
  }

  @override
  void dispose() {
    _totalContributionController.dispose();
    super.dispose();
  }

  String _getScreenTitle(List<Envelope> allEnvelopes) {
    if (widget.title != null) return widget.title!;

    switch (widget.mode) {
      case TargetScreenMode.singleEnvelope:
        if (_selectedEnvelopeIds.length == 1) {
          final envelope = allEnvelopes.firstWhere(
            (e) => e.id == _selectedEnvelopeIds.first,
            orElse: () => allEnvelopes.first,
          );
          return '${envelope.name} Horizon';
        }
        return 'Horizon Progress';
      case TargetScreenMode.binderFiltered:
        return 'Binder Horizons';
      case TargetScreenMode.multiEnvelope:
        return 'All Horizons';
    }
  }

  List<Envelope> _getFilteredEnvelopes(List<Envelope> allEnvelopes) {
    // Filter by group if specified
    var filtered = widget.initialGroupId != null
        ? allEnvelopes.where((e) => e.groupId == widget.initialGroupId).toList()
        : allEnvelopes;

    // Only show envelopes with targets
    return filtered
        .where((e) => e.targetAmount != null && e.targetAmount! > 0)
        .toList();
  }

  void _initializeAllocations(List<Envelope> targetEnvelopes) {
    if (_selectedEnvelopeIds.isEmpty || _contributionAllocations.isNotEmpty)
      return;

    final count = _selectedEnvelopeIds.length;
    final equalPercentage = count > 0 ? 100.0 / count : 0.0;

    for (var id in _selectedEnvelopeIds) {
      _contributionAllocations[id] = equalPercentage;
      _envelopeFrequencies[id] = _defaultFrequency;
    }
  }

  void _updateAllocation(String envelopeId, double newPercentage) {
    if (!_selectedEnvelopeIds.contains(envelopeId)) return;

    setState(() {
      final oldPercentage = _contributionAllocations[envelopeId] ?? 0;
      final difference = newPercentage - oldPercentage;

      // Update this envelope's percentage
      _contributionAllocations[envelopeId] = newPercentage;

      // Distribute the difference among other selected envelopes
      final otherEnvelopes = _selectedEnvelopeIds
          .where((id) => id != envelopeId)
          .toList();
      if (otherEnvelopes.isNotEmpty) {
        final adjustmentPerEnvelope = -difference / otherEnvelopes.length;
        for (var otherId in otherEnvelopes) {
          final current = _contributionAllocations[otherId] ?? 0;
          _contributionAllocations[otherId] = (current + adjustmentPerEnvelope)
              .clamp(0.0, 100.0);
        }
      }

      // Normalize to ensure total is exactly 100%
      _normalizeAllocations();
    });
  }

  void _normalizeAllocations() {
    if (_selectedEnvelopeIds.isEmpty) return;

    final total = _contributionAllocations.values.fold(
      0.0,
      (sum, v) => sum + v,
    );
    if (total == 0) return;

    final factor = 100.0 / total;
    for (var id in _selectedEnvelopeIds) {
      _contributionAllocations[id] =
          (_contributionAllocations[id] ?? 0) * factor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);
    final locale = Provider.of<LocaleProvider>(context);

    return Consumer<TimeMachineProvider>(
      builder: (context, timeMachine, child) {
        return StreamBuilder<List<Envelope>>(
          stream: widget.envelopeRepo.envelopesStream(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final allEnvelopes = snapshot.data!;

            // Apply time machine projections to envelopes
            final projectedEnvelopes = allEnvelopes.map((envelope) {
              return timeMachine.getProjectedEnvelope(envelope);
            }).toList();

            final targetEnvelopes = _getFilteredEnvelopes(projectedEnvelopes);

            // Auto-select all if in single mode and no selection
            if (widget.mode == TargetScreenMode.singleEnvelope &&
                _selectedEnvelopeIds.isEmpty &&
                targetEnvelopes.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                setState(() {
                  _selectedEnvelopeIds.add(targetEnvelopes.first.id);
                });
              });
            }

            _initializeAllocations(targetEnvelopes);

            return Scaffold(
              appBar: AppBar(
                title: Text(
                  _getScreenTitle(projectedEnvelopes),
                  style: fontProvider.getTextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              body: Column(
                children: [
                  // Time Machine Indicator
                  const TimeMachineIndicator(),

                  // Main content
                  Expanded(
                    child: targetEnvelopes.isEmpty
                        ? _buildEmptyState(theme, fontProvider)
                        : _buildContent(
                            targetEnvelopes,
                            theme,
                            fontProvider,
                            locale,
                            timeMachine,
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme, FontProvider fontProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.track_changes,
            size: 64,
            color: theme.colorScheme.onSurface.withAlpha(77),
          ),
          const SizedBox(height: 16),
          Text(
            'No Target Envelopes',
            style: fontProvider.getTextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withAlpha(179),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Set targets in envelope settings',
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSurface.withAlpha(128),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    List<Envelope> targetEnvelopes,
    ThemeData theme,
    FontProvider fontProvider,
    LocaleProvider locale,
    TimeMachineProvider timeMachine,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Contribution Calculator (if selected)
        if (_selectedEnvelopeIds.isNotEmpty) ...[
          _buildContributionCalculator(
            targetEnvelopes,
            theme,
            fontProvider,
            locale,
          ),
          const SizedBox(height: 16),
        ],

        // Overall Progress Summary
        _buildProgressSummary(
          targetEnvelopes,
          theme,
          fontProvider,
          locale,
          timeMachine,
        ),
        const SizedBox(height: 24),

        // Envelope List with Selection
        _buildEnvelopeList(
          targetEnvelopes,
          theme,
          fontProvider,
          locale,
          timeMachine,
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildProgressSummary(
    List<Envelope> targetEnvelopes,
    ThemeData theme,
    FontProvider fontProvider,
    LocaleProvider locale,
    TimeMachineProvider timeMachine,
  ) {
    final selectedEnvelopes = targetEnvelopes
        .where((e) => _selectedEnvelopeIds.contains(e.id))
        .toList();

    final envelopesToShow = selectedEnvelopes.isNotEmpty
        ? selectedEnvelopes
        : targetEnvelopes;

    final totalTarget = envelopesToShow.fold(
      0.0,
      (sum, e) => sum + (e.targetAmount ?? 0),
    );
    final totalCurrent = envelopesToShow.fold(
      0.0,
      (sum, e) => sum + e.currentAmount,
    );
    final progress = totalTarget > 0
        ? (totalCurrent / totalTarget).clamp(0.0, 1.0)
        : 0.0;
    final remaining = totalTarget - totalCurrent;

    // Calculate if exceeded in time machine mode
    final exceeded = remaining < 0 ? remaining.abs() : 0.0;

    // Calculate earliest target date
    DateTime? earliestTargetDate;
    for (var envelope in envelopesToShow) {
      if (envelope.targetDate != null) {
        if (earliestTargetDate == null ||
            envelope.targetDate!.isBefore(earliestTargetDate)) {
          earliestTargetDate = envelope.targetDate;
        }
      }
    }

    // Calculate time progress
    double? timeProgress;
    int? daysRemaining;
    if (earliestTargetDate != null) {
      final now = DateTime.now();
      final referenceDate = timeMachine.isActive ? timeMachine.futureDate! : now;

      // Calculate time progress: from now to target date
      // In time machine mode, show how much time has "elapsed" from today to the viewing date
      final totalDays = earliestTargetDate.difference(now).inDays;
      final daysPassed = timeMachine.isActive
          ? referenceDate.difference(now).inDays
          : 0; // In normal mode, we haven't elapsed any time yet
      daysRemaining = earliestTargetDate.difference(referenceDate).inDays;

      if (totalDays > 0) {
        timeProgress = (daysPassed / totalDays).clamp(0.0, 1.0);
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.primaryContainer.withAlpha(128),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withAlpha(51),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header row with icon and count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.track_changes,
                    size: 24,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    selectedEnvelopes.isNotEmpty
                        ? '${selectedEnvelopes.length} Selected'
                        : targetEnvelopes.length == 1
                            ? '1 Horizon'
                            : '${targetEnvelopes.length} Horizons',
                    style: fontProvider.getTextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
              if (daysRemaining != null && daysRemaining > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withAlpha(77),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${daysRemaining}d left',
                    style: fontProvider.getTextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Amount Progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Amount Progress',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onPrimaryContainer.withAlpha(
                        179,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    locale.formatCurrency(totalCurrent),
                    style: fontProvider.getTextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                ],
              ),
              Text(
                'of ${locale.formatCurrency(totalTarget)}',
                style: fontProvider.getTextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onPrimaryContainer.withAlpha(204),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: theme.colorScheme.onPrimaryContainer.withAlpha(
                51,
              ),
              valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).toStringAsFixed(1)}% complete',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.secondary,
                ),
              ),
              if (exceeded > 0)
                Text(
                  '+${locale.formatCurrency(exceeded)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                )
              else
                Text(
                  '${locale.formatCurrency(remaining)} left',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onPrimaryContainer.withAlpha(179),
                  ),
                ),
            ],
          ),

          // Time Progress (if available)
          if (timeProgress != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Time Progress',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onPrimaryContainer.withAlpha(179),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: timeProgress,
                minHeight: 8,
                backgroundColor: theme.colorScheme.onPrimaryContainer.withAlpha(
                  51,
                ),
                valueColor: AlwaysStoppedAnimation(theme.colorScheme.secondary),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(timeProgress * 100).toStringAsFixed(1)}% of time elapsed',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onPrimaryContainer.withAlpha(179),
                  ),
                ),
                if (earliestTargetDate != null)
                  Text(
                    '${earliestTargetDate.day}/${earliestTargetDate.month}/${earliestTargetDate.year}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEnvelopeList(
    List<Envelope> targetEnvelopes,
    ThemeData theme,
    FontProvider fontProvider,
    LocaleProvider locale,
    TimeMachineProvider timeMachine,
  ) {
    return StreamBuilder<List<EnvelopeGroup>>(
      stream: widget.envelopeRepo.groupsStream,
      builder: (context, groupSnapshot) {
        // Cache groups when available to prevent "Unknown Binder" during rebuilds
        if (groupSnapshot.hasData && groupSnapshot.data!.isNotEmpty) {
          _cachedGroups = groupSnapshot.data!;
        }
        final groups = _cachedGroups;

        // Group envelopes by binder
        final Map<String?, List<Envelope>> envelopesByGroup = {};
        for (var envelope in targetEnvelopes) {
          envelopesByGroup
              .putIfAbsent(envelope.groupId, () => [])
              .add(envelope);
        }

        // Separate binders from ungrouped envelopes
        final binderEntries = envelopesByGroup.entries
            .where((e) => e.key != null)
            .toList();
        final ungroupedEnvelopes = envelopesByGroup[null] ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Horizon Envelopes',
              style: fontProvider.getTextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Binders first
            ...binderEntries.map((entry) {
              final groupId = entry.key!;
              final envelopes = entry.value;
              final group = groups.firstWhere(
                (g) => g.id == groupId,
                orElse: () => EnvelopeGroup(
                  id: groupId,
                  name: 'Unknown Binder',
                  userId: '',
                ),
              );

              return _buildBinderSection(
                group,
                envelopes,
                theme,
                fontProvider,
                locale,
                timeMachine,
              );
            }),

            // Individual/ungrouped envelopes after binders
            if (ungroupedEnvelopes.isNotEmpty) ...[
              if (binderEntries.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Divider(
                    color: theme.colorScheme.outline.withAlpha(77),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Individual Envelopes',
                  style: fontProvider.getTextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface.withAlpha(179),
                  ),
                ),
              ),
              ...ungroupedEnvelopes.map(
                (envelope) => _buildEnvelopeTile(
                  envelope,
                  theme,
                  fontProvider,
                  locale,
                  timeMachine,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildBinderSection(
    EnvelopeGroup group,
    List<Envelope> envelopes,
    ThemeData theme,
    FontProvider fontProvider,
    LocaleProvider locale,
    TimeMachineProvider timeMachine,
  ) {
    final isExpanded = _expandedBinderIds.contains(group.id);

    // Calculate combined stats
    final totalTarget = envelopes.fold(
      0.0,
      (sum, e) => sum + (e.targetAmount ?? 0),
    );
    final totalCurrent = envelopes.fold(0.0, (sum, e) => sum + e.currentAmount);
    final progress = totalTarget > 0
        ? (totalCurrent / totalTarget).clamp(0.0, 1.0)
        : 0.0;

    // Calculate earliest target date for time progress
    DateTime? earliestTargetDate;
    for (var envelope in envelopes) {
      if (envelope.targetDate != null) {
        if (earliestTargetDate == null ||
            envelope.targetDate!.isBefore(earliestTargetDate)) {
          earliestTargetDate = envelope.targetDate;
        }
      }
    }

    // Count unique target dates for elegant handling
    final targetDates = envelopes
        .where((e) => e.targetDate != null)
        .map((e) => e.targetDate!)
        .toSet();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedBinderIds.remove(group.id);
                } else {
                  _expandedBinderIds.add(group.id);
                }
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Header row
                  Row(
                    children: [
                      group.getIconWidget(theme, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.name,
                              style: fontProvider.getTextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${envelopes.length} envelope${envelopes.length == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface.withAlpha(
                                  179,
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
                  const SizedBox(height: 16),

                  // Combined stats
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        locale.formatCurrency(totalCurrent),
                        style: fontProvider.getTextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Text(
                        'of ${locale.formatCurrency(totalTarget)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface.withAlpha(179),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Amount progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(
                        theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Progress percentage and time info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${(progress * 100).toStringAsFixed(1)}% complete',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      if (earliestTargetDate != null)
                        Row(
                          children: [
                            if (targetDates.length > 1)
                              Text(
                                '${targetDates.length} dates • ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface.withAlpha(
                                    179,
                                  ),
                                ),
                              ),
                            Icon(
                              Icons.calendar_today,
                              size: 12,
                              color: theme.colorScheme.onSurface.withAlpha(179),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${earliestTargetDate.day}/${earliestTargetDate.month}/${earliestTargetDate.year}',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface.withAlpha(
                                  179,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Expanded envelope list
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  Divider(color: theme.colorScheme.outline.withAlpha(77)),
                  const SizedBox(height: 8),
                  ...envelopes.map(
                    (envelope) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildEnvelopeTile(
                        envelope,
                        theme,
                        fontProvider,
                        locale,
                        timeMachine,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEnvelopeTile(
    Envelope envelope,
    ThemeData theme,
    FontProvider fontProvider,
    LocaleProvider locale,
    TimeMachineProvider timeMachine,
  ) {
    final isSelected = _selectedEnvelopeIds.contains(envelope.id);

    // Use time machine projected amount if available
    final displayAmount =
        envelope.currentAmount; // Already projected via getProjectedEnvelope
    final progress = envelope.targetAmount! > 0
        ? (displayAmount / envelope.targetAmount!).clamp(0.0, 1.0)
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.outline.withAlpha(77),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: widget.mode != TargetScreenMode.singleEnvelope
            ? () {
                setState(() {
                  if (isSelected) {
                    _selectedEnvelopeIds.remove(envelope.id);
                    _contributionAllocations.remove(envelope.id);
                    _envelopeFrequencies.remove(envelope.id);
                    if (_selectedEnvelopeIds.isNotEmpty) {
                      _normalizeAllocations();
                    }
                  } else {
                    _selectedEnvelopeIds.add(envelope.id);
                    final count = _selectedEnvelopeIds.length;
                    // Reset all to equal percentages
                    final equalPercentage = 100.0 / count;
                    for (var id in _selectedEnvelopeIds) {
                      _contributionAllocations[id] = equalPercentage;
                      _envelopeFrequencies[id] ??= _defaultFrequency;
                    }
                  }
                });
              }
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  envelope.getIconWidget(theme, size: 24),
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
                        Text(
                          TargetHelper.getSuggestionText(
                            envelope,
                            locale.currencySymbol,
                            projectedAmount: timeMachine.isActive
                                ? envelope.currentAmount
                                : null,
                            projectedDate: timeMachine.futureDate,
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withAlpha(179),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.mode != TargetScreenMode.singleEnvelope)
                    Checkbox(
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedEnvelopeIds.add(envelope.id);
                            final count = _selectedEnvelopeIds.length;
                            final equalPercentage = 100.0 / count;
                            for (var id in _selectedEnvelopeIds) {
                              _contributionAllocations[id] = equalPercentage;
                              _envelopeFrequencies[id] ??= _defaultFrequency;
                            }
                          } else {
                            _selectedEnvelopeIds.remove(envelope.id);
                            _contributionAllocations.remove(envelope.id);
                            _envelopeFrequencies.remove(envelope.id);
                            if (_selectedEnvelopeIds.isNotEmpty) {
                              _normalizeAllocations();
                            }
                          }
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    locale.formatCurrency(envelope.currentAmount),
                    style: fontProvider.getTextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    locale.formatCurrency(envelope.targetAmount!),
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withAlpha(179),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(progress * 100).toStringAsFixed(1)}% complete',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withAlpha(179),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContributionCalculator(
    List<Envelope> targetEnvelopes,
    ThemeData theme,
    FontProvider fontProvider,
    LocaleProvider locale,
  ) {
    final selectedEnvelopes = targetEnvelopes
        .where((e) => _selectedEnvelopeIds.contains(e.id))
        .toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        initiallyExpanded: _showCalculator,
        onExpansionChanged: (expanded) {
          setState(() => _showCalculator = expanded);
        },
        leading: Icon(Icons.calculate, color: theme.colorScheme.primary),
        title: Text(
          'Target Horizon',
          style: fontProvider.getTextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          'Plan contributions for ${selectedEnvelopes.length} envelope${selectedEnvelopes.length == 1 ? '' : 's'}',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Total Contribution Amount Input
                SmartTextField(
                  controller: _totalContributionController,
                  decoration: InputDecoration(
                    labelText: 'Total Contribution Amount',
                    labelStyle: fontProvider.getTextStyle(fontSize: 16),
                    prefixText: '${locale.currencySymbol} ',
                    hintText: '500.00',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
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
                          final result = await CalculatorHelper.showCalculator(
                            context,
                          );
                          if (result != null) {
                            _totalContributionController.text = result;
                            setState(() {
                              // Auto-expand all envelope projections when amount is calculated
                              _expandedEnvelopeProjections.addAll(
                                _selectedEnvelopeIds,
                              );
                            });
                          }
                        },
                        tooltip: 'Calculator',
                      ),
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onTap: () {
                    _totalContributionController.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: _totalContributionController.text.length,
                    );
                  },
                  onChanged: (value) {
                    setState(() {
                      // Auto-expand all envelope projections when a valid amount is entered
                      final amount = double.tryParse(value);
                      if (amount != null && amount > 0) {
                        _expandedEnvelopeProjections.addAll(
                          _selectedEnvelopeIds,
                        );
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Default Frequency Selector
                DropdownButtonFormField<String>(
                  initialValue: _defaultFrequency,
                  decoration: InputDecoration(
                    labelText: 'Default Frequency',
                    labelStyle: fontProvider.getTextStyle(fontSize: 16),
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'daily', child: Text('Daily')),
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    DropdownMenuItem(
                      value: 'biweekly',
                      child: Text('Every 2 weeks'),
                    ),
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _defaultFrequency = value!;
                      // Update ALL envelope frequencies to match the new default
                      for (var id in _selectedEnvelopeIds) {
                        _envelopeFrequencies[id] = value;
                      }
                    });
                  },
                ),
                const SizedBox(height: 24),

                // Per-Envelope Allocation
                Text(
                  'Contribution Allocation',
                  style: fontProvider.getTextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Adjust how the total contribution is split between envelopes',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withAlpha(179),
                  ),
                ),
                const SizedBox(height: 16),

                ...selectedEnvelopes.map((envelope) {
                  final totalAmount =
                      double.tryParse(_totalContributionController.text) ?? 0;
                  return _buildEnvelopeAllocationTile(
                    envelope,
                    theme,
                    fontProvider,
                    locale,
                    totalAmount,
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnvelopeAllocationTile(
    Envelope envelope,
    ThemeData theme,
    FontProvider fontProvider,
    LocaleProvider locale,
    double totalAmount,
  ) {
    final percentage = _contributionAllocations[envelope.id] ?? 0;
    final envelopeAmount = totalAmount * (percentage / 100);
    final frequency = _envelopeFrequencies[envelope.id] ?? _defaultFrequency;
    final isExpanded = _expandedEnvelopeProjections.contains(envelope.id);

    // Calculate projection
    final remaining = (envelope.targetAmount ?? 0) - envelope.currentAmount;
    final contributionsNeeded = envelopeAmount > 0
        ? (remaining / envelopeAmount).ceil()
        : 0;
    final daysPerContribution = _getDaysPerFrequency(frequency);
    final daysToTarget = contributionsNeeded * daysPerContribution;
    final targetDate = DateTime.now().add(Duration(days: daysToTarget));

    final frequencyLabel = _getFrequencyLabel(frequency);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: Column(
        children: [
          // Main tile content
          InkWell(
            onTap: totalAmount > 0 && remaining > 0
                ? () {
                    setState(() {
                      if (isExpanded) {
                        _expandedEnvelopeProjections.remove(envelope.id);
                      } else {
                        _expandedEnvelopeProjections.add(envelope.id);
                      }
                    });
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      envelope.getIconWidget(theme, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          envelope.name,
                          style: fontProvider.getTextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: fontProvider.getTextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      if (totalAmount > 0 && remaining > 0)
                        Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                          color: theme.colorScheme.primary,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Percentage Slider
                  Slider(
                    value: percentage.clamp(0.0, 100.0),
                    min: 0,
                    max: 100,
                    divisions: 100,
                    label: '${percentage.toStringAsFixed(1)}%',
                    onChanged: (value) {
                      _updateAllocation(envelope.id, value);
                    },
                  ),

                  // Amount Display and Frequency
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Amount',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface.withAlpha(
                                  179,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () => _showAmountInput(
                                envelope,
                                theme,
                                fontProvider,
                                locale,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer
                                      .withAlpha(77),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: theme.colorScheme.primary.withAlpha(
                                      77,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      locale.formatCurrency(envelopeAmount),
                                      style: fontProvider.getTextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.edit_outlined,
                                      size: 14,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Frequency Display (read-only, controlled by global default)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Frequency',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface.withAlpha(
                                  179,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: theme.colorScheme.outline.withAlpha(
                                    77,
                                  ),
                                ),
                              ),
                              child: Text(
                                frequencyLabel,
                                style: fontProvider.getTextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Quick projection summary (always visible)
                  if (totalAmount > 0 && remaining > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer.withAlpha(
                          51,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Horizon in ${_getSmartTimePeriod(contributionsNeeded, frequency)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                          Text(
                            '${targetDate.day}/${targetDate.month}/${targetDate.year}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Expanded projection details
          if (isExpanded && totalAmount > 0 && remaining > 0)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  Divider(color: theme.colorScheme.outline.withAlpha(77)),
                  const SizedBox(height: 8),
                  _buildProjectionRow(
                    'Remaining',
                    locale.formatCurrency(remaining),
                    fontProvider,
                  ),
                  _buildProjectionRow(
                    'Per $frequencyLabel',
                    locale.formatCurrency(envelopeAmount),
                    fontProvider,
                  ),
                  _buildProjectionRow(
                    'Contributions needed',
                    '$contributionsNeeded',
                    fontProvider,
                  ),
                  _buildProjectionRow(
                    'Days to horizon',
                    '$daysToTarget days',
                    fontProvider,
                  ),
                  _buildProjectionRow(
                    'Horizon reached by',
                    '${targetDate.day}/${targetDate.month}/${targetDate.year}',
                    fontProvider,
                    valueColor: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _getFrequencyLabel(String frequency) {
    switch (frequency) {
      case 'daily':
        return 'Day';
      case 'weekly':
        return 'Week';
      case 'biweekly':
        return 'Fortnight';
      case 'monthly':
        return 'Month';
      default:
        return frequency;
    }
  }

  /// Smart time period formatter that chooses the most natural time unit
  /// and returns properly formatted string with singular/plural forms
  String _getSmartTimePeriod(int contributionsNeeded, String frequency) {
    final daysPerContribution = _getDaysPerFrequency(frequency);
    final totalDays = contributionsNeeded * daysPerContribution;

    // Convert to the most natural time unit
    if (totalDays == 0) {
      return 'Today';
    }

    // For 1 day
    if (totalDays == 1) {
      return '1 Day';
    }

    // For less than a week, use days
    if (totalDays < 7) {
      return '$totalDays Days';
    }

    // For exactly 1 week
    if (totalDays == 7) {
      return '1 Week';
    }

    // For exactly 2 weeks (fortnight)
    if (totalDays == 14) {
      return '1 Fortnight';
    }

    // For exactly 4 weeks (1 month)
    if (totalDays == 28 || totalDays == 30 || totalDays == 31) {
      return '1 Month';
    }

    // For 8 weeks (2 months)
    if (totalDays >= 56 && totalDays <= 62) {
      return '2 Months';
    }

    // For 12 weeks (3 months)
    if (totalDays >= 84 && totalDays <= 93) {
      return '3 Months';
    }

    // For less than 4 weeks but more than 2 weeks, use weeks
    if (totalDays < 28) {
      final weeks = (totalDays / 7).round();
      return weeks == 1 ? '1 Week' : '$weeks Weeks';
    }

    // For 4-12 weeks, check if it's close to months
    if (totalDays < 90) {
      final months = (totalDays / 30).round();
      if (months == 0) {
        // Too short for months, use weeks
        final weeks = (totalDays / 7).round();
        return weeks == 1 ? '1 Week' : '$weeks Weeks';
      } else if (months == 1) {
        return '1 Month';
      } else {
        return '$months Months';
      }
    }

    // For 3+ months, use months
    final months = (totalDays / 30).round();
    if (months < 12) {
      return months == 1 ? '1 Month' : '$months Months';
    }

    // For 12+ months, use years
    final years = (totalDays / 365).round();
    if (years == 1) {
      return '1 Year';
    } else {
      return '$years Years';
    }
  }

  void _showAmountInput(
    Envelope envelope,
    ThemeData theme,
    FontProvider fontProvider,
    LocaleProvider locale,
  ) {
    final controller = TextEditingController();
    final totalAmount = double.tryParse(_totalContributionController.text) ?? 0;
    final currentPercentage = _contributionAllocations[envelope.id] ?? 0;
    final currentAmount = totalAmount * (currentPercentage / 100);
    controller.text = currentAmount.toStringAsFixed(2);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          envelope.name,
          style: fontProvider.getTextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter contribution amount', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            SmartTextField(
              controller: controller,
              autofocus: false,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '${locale.currencySymbol} ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onTap: () {
                // Select all text on tap
                controller.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: controller.text.length,
                );
              },
              onSubmitted: (_) {
                FocusScope.of(dialogContext).unfocus();
                _applyAmountChange(
                  dialogContext,
                  envelope.id,
                  controller.text,
                  totalAmount,
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              FocusScope.of(dialogContext).unfocus();
              Navigator.pop(dialogContext);
            },
            child: Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              FocusScope.of(dialogContext).unfocus();
              _applyAmountChange(
                dialogContext,
                envelope.id,
                controller.text,
                totalAmount,
              );
            },
            child: Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _applyAmountChange(
    BuildContext dialogContext,
    String envelopeId,
    String amountText,
    double totalAmount,
  ) {
    final amount = double.tryParse(amountText);

    // Validate amount
    if (amount == null || totalAmount <= 0) {
      Navigator.pop(dialogContext);
      return;
    }

    // Check if amount exceeds total
    if (amount > totalAmount) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Amount cannot exceed total contribution (${Provider.of<LocaleProvider>(context, listen: false).formatCurrency(totalAmount)})',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
      return; // Don't close dialog, let user fix the amount
    }

    // Valid amount - close dialog and apply
    Navigator.pop(dialogContext);

    final newPercentage = (amount / totalAmount) * 100;
    setState(() {
      _updateAllocation(envelopeId, newPercentage);
    });
  }

  int _getDaysPerFrequency(String frequency) {
    switch (frequency) {
      case 'daily':
        return 1;
      case 'weekly':
        return 7;
      case 'biweekly':
        return 14;
      case 'monthly':
        return 30;
      default:
        return 30;
    }
  }

  Widget _buildProjectionRow(
    String label,
    String value,
    FontProvider fontProvider, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: fontProvider.getTextStyle(fontSize: 12)),
          Text(
            value,
            style: fontProvider.getTextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
