// lib/screens/envelope/multi_target_screen.dart
// Context-aware target screen supporting single/multiple envelopes and binders

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/envelope.dart';
import '../../models/envelope_group.dart';
import '../../services/envelope_repo.dart';
import '../../services/group_repo.dart';
import '../../services/account_repo.dart';
import '../../providers/font_provider.dart';
import '../../providers/locale_provider.dart';
import '../../utils/target_helper.dart';

enum TargetScreenMode {
  singleEnvelope,  // From envelope detail
  multiEnvelope,   // From budget overview or multi-selection
  binderFiltered,  // From binder target chip
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
  final List<String>? initialEnvelopeIds;  // Pre-selected envelope IDs
  final String? initialGroupId;             // Filter by binder/group
  final TargetScreenMode mode;
  final String? title;                      // Custom title

  @override
  State<MultiTargetScreen> createState() => _MultiTargetScreenState();
}

class _MultiTargetScreenState extends State<MultiTargetScreen> {
  final Set<String> _selectedEnvelopeIds = {};
  final Map<String, double> _contributionAllocations = {}; // envelopeId -> percentage (0-100)
  final Map<String, String> _envelopeFrequencies = {}; // envelopeId -> frequency
  final TextEditingController _totalContributionController = TextEditingController();
  String _defaultFrequency = 'monthly';
  bool _showCalculator = false;

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
          return '${envelope.name} Target';
        }
        return 'Target Progress';
      case TargetScreenMode.binderFiltered:
        return 'Binder Targets';
      case TargetScreenMode.multiEnvelope:
        return 'All Targets';
    }
  }

  List<Envelope> _getFilteredEnvelopes(List<Envelope> allEnvelopes) {
    // Filter by group if specified
    var filtered = widget.initialGroupId != null
        ? allEnvelopes.where((e) => e.groupId == widget.initialGroupId).toList()
        : allEnvelopes;

    // Only show envelopes with targets
    return filtered.where((e) => e.targetAmount != null && e.targetAmount! > 0).toList();
  }

  void _initializeAllocations(List<Envelope> targetEnvelopes) {
    if (_selectedEnvelopeIds.isEmpty || _contributionAllocations.isNotEmpty) return;

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
      final otherEnvelopes = _selectedEnvelopeIds.where((id) => id != envelopeId).toList();
      if (otherEnvelopes.isNotEmpty) {
        final adjustmentPerEnvelope = -difference / otherEnvelopes.length;
        for (var otherId in otherEnvelopes) {
          final current = _contributionAllocations[otherId] ?? 0;
          _contributionAllocations[otherId] = (current + adjustmentPerEnvelope).clamp(0.0, 100.0);
        }
      }

      // Normalize to ensure total is exactly 100%
      _normalizeAllocations();
    });
  }

  void _normalizeAllocations() {
    if (_selectedEnvelopeIds.isEmpty) return;

    final total = _contributionAllocations.values.fold(0.0, (sum, v) => sum + v);
    if (total == 0) return;

    final factor = 100.0 / total;
    for (var id in _selectedEnvelopeIds) {
      _contributionAllocations[id] = (_contributionAllocations[id] ?? 0) * factor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);
    final locale = Provider.of<LocaleProvider>(context);

    return StreamBuilder<List<Envelope>>(
      stream: widget.envelopeRepo.envelopesStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final allEnvelopes = snapshot.data!;
        final targetEnvelopes = _getFilteredEnvelopes(allEnvelopes);

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
              _getScreenTitle(allEnvelopes),
              style: fontProvider.getTextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: targetEnvelopes.isEmpty
              ? _buildEmptyState(theme, fontProvider)
              : _buildContent(targetEnvelopes, theme, fontProvider, locale),
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
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Hint text for multi-select
        if (widget.mode != TargetScreenMode.singleEnvelope)
          _buildHintText(theme, fontProvider),

        // Overall Progress Summary
        _buildProgressSummary(targetEnvelopes, theme, fontProvider, locale),
        const SizedBox(height: 24),

        // Envelope List with Selection
        _buildEnvelopeList(targetEnvelopes, theme, fontProvider, locale),
        const SizedBox(height: 24),

        // Contribution Calculator
        if (_selectedEnvelopeIds.isNotEmpty)
          _buildContributionCalculator(targetEnvelopes, theme, fontProvider, locale),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildHintText(ThemeData theme, FontProvider fontProvider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withAlpha(77),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.secondary.withAlpha(77),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: theme.colorScheme.secondary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tap to select envelopes for contribution calculation',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSummary(
    List<Envelope> targetEnvelopes,
    ThemeData theme,
    FontProvider fontProvider,
    LocaleProvider locale,
  ) {
    final selectedEnvelopes = targetEnvelopes
        .where((e) => _selectedEnvelopeIds.contains(e.id))
        .toList();

    final envelopesToShow = selectedEnvelopes.isNotEmpty
        ? selectedEnvelopes
        : targetEnvelopes;

    final totalTarget = envelopesToShow.fold(0.0, (sum, e) => sum + (e.targetAmount ?? 0));
    final totalCurrent = envelopesToShow.fold(0.0, (sum, e) => sum + e.currentAmount);
    final progress = totalTarget > 0 ? (totalCurrent / totalTarget).clamp(0.0, 1.0) : 0.0;
    final remaining = totalTarget - totalCurrent;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.primaryContainer.withAlpha(128),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withAlpha(51),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.track_changes,
            size: 48,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            selectedEnvelopes.isNotEmpty
                ? '${selectedEnvelopes.length} Selected'
                : '${targetEnvelopes.length} Targets',
            style: fontProvider.getTextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            locale.formatCurrency(totalCurrent),
            style: fontProvider.getTextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.primary,
            ),
          ),
          Text(
            'of ${locale.formatCurrency(totalTarget)}',
            style: fontProvider.getTextStyle(
              fontSize: 18,
              color: theme.colorScheme.onPrimaryContainer.withAlpha(204),
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: theme.colorScheme.onPrimaryContainer.withAlpha(51),
              valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${(progress * 100).toStringAsFixed(1)}% complete',
            style: fontProvider.getTextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          Text(
            '${locale.formatCurrency(remaining)} remaining',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onPrimaryContainer.withAlpha(179),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnvelopeList(
    List<Envelope> targetEnvelopes,
    ThemeData theme,
    FontProvider fontProvider,
    LocaleProvider locale,
  ) {
    return StreamBuilder<List<EnvelopeGroup>>(
      stream: widget.envelopeRepo.groupsStream,
      builder: (context, groupSnapshot) {
        final groups = groupSnapshot.data ?? [];

        // Group envelopes by binder
        final Map<String?, List<Envelope>> envelopesByGroup = {};
        for (var envelope in targetEnvelopes) {
          envelopesByGroup.putIfAbsent(envelope.groupId, () => []).add(envelope);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Target Envelopes',
              style: fontProvider.getTextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...envelopesByGroup.entries.map((entry) {
              final groupId = entry.key;
              final envelopes = entry.value;
              final group = groups.firstWhere(
                (g) => g.id == groupId,
                orElse: () => EnvelopeGroup(
                  id: 'unknown',
                  name: 'Ungrouped',
                  userId: '',
                ),
              );

              return _buildBinderSection(
                group,
                envelopes,
                theme,
                fontProvider,
                locale,
              );
            }),
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
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              group.getIconWidget(theme, size: 20),
              const SizedBox(width: 8),
              Text(
                group.name,
                style: fontProvider.getTextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        ...envelopes.map((envelope) => _buildEnvelopeTile(
          envelope,
          theme,
          fontProvider,
          locale,
        )),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildEnvelopeTile(
    Envelope envelope,
    ThemeData theme,
    FontProvider fontProvider,
    LocaleProvider locale,
  ) {
    final isSelected = _selectedEnvelopeIds.contains(envelope.id);
    final progress = envelope.targetAmount! > 0
        ? (envelope.currentAmount / envelope.targetAmount!).clamp(0.0, 1.0)
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
                          TargetHelper.getSuggestionText(envelope, locale.currencySymbol),
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
    // This is a placeholder - will be completed in next iteration
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calculate,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Contribution Calculator',
                  style: fontProvider.getTextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Advanced calculator with per-envelope allocation coming next...',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withAlpha(179),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
