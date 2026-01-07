// lib/screens/envelope/multi_target_screen.dart
// Horizon Navigator - Dynamic financial simulator for envelope targets
// Features: Temporal progress sync, weighted average calculations, sandbox contribution engine

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/envelope.dart';
import '../../models/envelope_group.dart';
import '../../models/transaction.dart';
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

  // Sandbox Engine: Virtual reach dates for simulation
  final Map<String, DateTime> _virtualReachDates = {};
  final Map<String, bool> _onTrackStatus = {}; // Track if envelope is on track

  // NEW: Smart Baseline Engine state
  final Map<String, double> _envelopeBaselines = {}; // envelopeId -> detected monthly baseline
  double _baselineTotal = 0.0; // Total detected baseline (monthly)
  double _velocityMultiplier = 1.0; // Slider multiplier (0.0 to 2.0)
  bool _manualOverride = false; // True when user types manually
  bool _baselineCalculated = false; // Track if baseline has been calculated

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

  /// Smart Baseline Engine: Auto-detect contribution speed for each envelope
  /// Priority:
  /// 1. Cash Flow amount (if enabled)
  /// 2. Most recent EXTERNAL inflow transaction
  /// 3. Zero (stalled)
  void _calculateBaseline(List<Envelope> selectedEnvelopes) {
    if (_baselineCalculated) return; // Only calculate once

    debugPrint('[HorizonNavigator-Baseline] ========================================');
    debugPrint('[HorizonNavigator-Baseline] Calculating baseline for ${selectedEnvelopes.length} envelopes');

    _envelopeBaselines.clear();
    double total = 0.0;

    for (var envelope in selectedEnvelopes) {
      double speed = 0.0;
      String source = 'None (stalled)';

      // Priority 1: Cash Flow
      if (envelope.cashFlowEnabled && (envelope.cashFlowAmount ?? 0) > 0) {
        speed = envelope.cashFlowAmount!;
        source = 'Cash Flow';
      } else {
        // Priority 2: Transaction history (most recent external inflow)
        final transactions = widget.envelopeRepo.getTransactionsForEnvelopeSync(envelope.id);

        // Sort by date descending (most recent first)
        transactions.sort((a, b) => b.date.compareTo(a.date));

        // Find most recent external inflow
        for (var tx in transactions) {
          if (tx.impact == TransactionImpact.external &&
              tx.direction == TransactionDirection.inflow) {
            speed = tx.amount;
            source = 'Recent Transaction (${tx.date})';
            break;
          }
        }
      }

      // Normalize to monthly frequency
      final monthlySpeed = _normalizeToMonthly(speed, _defaultFrequency);
      _envelopeBaselines[envelope.id] = monthlySpeed;
      total += monthlySpeed;

      debugPrint('[HorizonNavigator-Baseline] ${envelope.name}:');
      debugPrint('[HorizonNavigator-Baseline]   Source: $source');
      debugPrint('[HorizonNavigator-Baseline]   Raw Speed: $speed ($_defaultFrequency)');
      debugPrint('[HorizonNavigator-Baseline]   Monthly Speed: $monthlySpeed');
    }

    _baselineTotal = total;
    _baselineCalculated = true;

    debugPrint('[HorizonNavigator-Baseline] ---');
    debugPrint('[HorizonNavigator-Baseline] Total Baseline: $total/month');
    debugPrint('[HorizonNavigator-Baseline] ========================================');

    // Pre-fill the total contribution controller with baseline
    if (total > 0) {
      _totalContributionController.text = total.toStringAsFixed(2);
    }
  }

  /// Normalize any amount to monthly based on frequency
  /// Uses average days per month (30.44) for more accurate conversion
  double _normalizeToMonthly(double amount, String frequency) {
    const averageDaysPerMonth = 30.44; // 365.25 / 12 (accounting for leap years)

    switch (frequency) {
      case 'daily':
        return amount * averageDaysPerMonth; // More accurate than 30
      case 'weekly':
        return amount * (averageDaysPerMonth / 7); // ~4.35 weeks per month
      case 'biweekly':
        return amount * (averageDaysPerMonth / 14); // ~2.17 fortnights per month
      case 'monthly':
        return amount;
      default:
        return amount;
    }
  }

  /// Calculate time saved between baseline and current strategy
  Map<String, int> _calculateTimeSaved(List<Envelope> envelopes) {
    debugPrint('[HorizonNavigator-TimeSaved] ========================================');
    debugPrint('[HorizonNavigator-TimeSaved] Calculating time saved for ${envelopes.where((e) => _selectedEnvelopeIds.contains(e.id)).length} envelopes');

    int totalDaysSaved = 0;
    final Map<String, int> perEnvelopeDaysSaved = {};

    for (var envelope in envelopes) {
      if (!_selectedEnvelopeIds.contains(envelope.id)) continue;

      final baselineSpeed = _envelopeBaselines[envelope.id] ?? 0.0;
      final totalContribution = double.tryParse(_totalContributionController.text) ?? 0;
      final allocation = _contributionAllocations[envelope.id] ?? 0;
      final newSpeed = totalContribution * (allocation / 100);

      final remaining = (envelope.targetAmount ?? 0) - envelope.currentAmount;

      debugPrint('[HorizonNavigator-TimeSaved] ${envelope.name}:');
      debugPrint('[HorizonNavigator-TimeSaved]   Remaining: $remaining');
      debugPrint('[HorizonNavigator-TimeSaved]   Baseline Speed: $baselineSpeed/month');
      debugPrint('[HorizonNavigator-TimeSaved]   New Speed: $newSpeed/month (${allocation.toStringAsFixed(1)}% of $totalContribution)');

      if (remaining <= 0 || baselineSpeed <= 0 || newSpeed <= 0) {
        debugPrint('[HorizonNavigator-TimeSaved]   Skipped (invalid values)');
        continue;
      }

      // Calculate days with baseline speed (using average month length)
      const averageDaysPerMonth = 30.44; // 365.25 / 12
      final baselineDays = (remaining / baselineSpeed * averageDaysPerMonth).ceil();

      // Calculate days with new speed (using average month length)
      final newDays = (remaining / newSpeed * averageDaysPerMonth).ceil();

      final daysSaved = baselineDays - newDays;
      perEnvelopeDaysSaved[envelope.id] = daysSaved;
      totalDaysSaved += daysSaved;

      debugPrint('[HorizonNavigator-TimeSaved]   Baseline Days: $baselineDays');
      debugPrint('[HorizonNavigator-TimeSaved]   New Days: $newDays');
      debugPrint('[HorizonNavigator-TimeSaved]   Days Saved: $daysSaved');
    }

    debugPrint('[HorizonNavigator-TimeSaved] ---');
    debugPrint('[HorizonNavigator-TimeSaved] Total Days Saved: $totalDaysSaved');
    debugPrint('[HorizonNavigator-TimeSaved] ========================================');

    return {
      'total': totalDaysSaved,
      ...perEnvelopeDaysSaved,
    };
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
    if (_selectedEnvelopeIds.isEmpty || _contributionAllocations.isNotEmpty) {
      return;
    }

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

    debugPrint('[HorizonNavigator-Allocation] Normalizing allocations: total=$total');

    if (total == 0) {
      // Edge case: All allocations are 0, distribute equally
      debugPrint('[HorizonNavigator-Allocation] All allocations are 0, distributing equally');
      final equalPercentage = 100.0 / _selectedEnvelopeIds.length;
      for (var id in _selectedEnvelopeIds) {
        _contributionAllocations[id] = equalPercentage;
      }
      return;
    }

    final factor = 100.0 / total;
    for (var id in _selectedEnvelopeIds) {
      _contributionAllocations[id] =
          (_contributionAllocations[id] ?? 0) * factor;
    }

    // Verify total is exactly 100%
    final newTotal = _contributionAllocations.values.fold(0.0, (sum, v) => sum + v);
    debugPrint('[HorizonNavigator-Allocation] Normalized total: $newTotal%');
  }

  /// Sandbox Engine: Simulate horizon reach dates based on contribution inputs
  /// This is a "what-if" calculator that doesn't modify Hive data
  void _simulateHorizon(List<Envelope> allEnvelopes) {
    final totalContribution = double.tryParse(_totalContributionController.text) ?? 0;

    if (totalContribution <= 0) {
      // Clear simulations if no contribution
      _virtualReachDates.clear();
      _onTrackStatus.clear();
      return;
    }

    for (var id in _selectedEnvelopeIds) {
      final envelope = allEnvelopes.firstWhere(
        (e) => e.id == id,
        orElse: () => allEnvelopes.first,
      );

      // Skip if no target amount set
      if (envelope.targetAmount == null || envelope.targetAmount! <= 0) {
        continue;
      }

      // Calculate allocated contribution for this envelope
      final allocationPercentage = _contributionAllocations[id] ?? 0;
      final envelopeContribution = totalContribution * (allocationPercentage / 100);

      // Calculate remaining amount to reach target
      final remaining = envelope.targetAmount! - envelope.currentAmount;

      if (remaining <= 0) {
        // Already reached target
        _virtualReachDates[id] = DateTime.now();
        _onTrackStatus[id] = true;
        continue;
      }

      if (envelopeContribution <= 0) {
        // No contribution allocated - stalled
        _onTrackStatus[id] = false;
        continue;
      }

      // Calculate frequency days
      final frequency = _envelopeFrequencies[id] ?? _defaultFrequency;
      final daysPerContribution = _getDaysPerFrequency(frequency);

      // Calculate contributions needed
      final contributionsNeeded = (remaining / envelopeContribution).ceil();
      final daysToTarget = contributionsNeeded * daysPerContribution;

      // Calculate virtual reach date
      final reachDate = DateTime.now().add(Duration(days: daysToTarget));
      _virtualReachDates[id] = reachDate;

      // Check if on track (will reach before target date)
      if (envelope.targetDate != null) {
        _onTrackStatus[id] = reachDate.isBefore(envelope.targetDate!) ||
            _isSameDay(reachDate, envelope.targetDate!);
      } else {
        _onTrackStatus[id] = true; // No deadline, so always "on track"
      }
    }
  }

  /// Helper: Check if two dates are the same day
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
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

            // Calculate baseline on first render with selected envelopes
            if (_selectedEnvelopeIds.isNotEmpty && !_baselineCalculated) {
              final selectedEnvelopes = targetEnvelopes
                  .where((e) => _selectedEnvelopeIds.contains(e.id))
                  .toList();
              if (selectedEnvelopes.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  setState(() {
                    _calculateBaseline(selectedEnvelopes);
                  });
                });
              }
            }

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
            Icons.wb_twilight,
            size: 64,
            color: theme.colorScheme.onSurface.withAlpha(77),
          ),
          const SizedBox(height: 16),
          Text(
            'No Horizon Envelopes',
            style: fontProvider.getTextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withAlpha(179),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Set horizons in envelope settings',
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

  /// ZONE A: Strategy Dashboard - The Vision
  /// High-contrast card showing current strategy status and impact
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

    // FIXED: Weighted Average Amount Progress
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

    // FIXED: Calculate Average Time Progress across all selected horizons
    double? timeProgress;
    int? daysRemaining;
    final referenceDate = timeMachine.isActive ? timeMachine.futureDate! : DateTime.now();

    // Calculate average time progress using TargetHelper for consistency
    final envelopesWithDates = envelopesToShow.where((e) => e.targetDate != null).toList();
    if (envelopesWithDates.isNotEmpty) {
      double totalTimeProgress = 0.0;
      int totalDaysRemaining = 0;

      for (var envelope in envelopesWithDates) {
        // Use unified TargetHelper calculation
        final envTimeProgress = TargetHelper.calculateTimeProgress(
          envelope,
          referenceDate: referenceDate,
        );
        totalTimeProgress += envTimeProgress;
        totalDaysRemaining += TargetHelper.getDaysRemaining(
          envelope,
          projectedDate: referenceDate,
        );
      }

      // Average time progress
      timeProgress = totalTimeProgress / envelopesWithDates.length;
      daysRemaining = (totalDaysRemaining / envelopesWithDates.length).round();
    }

    // Find both earliest (next deadline) and latest (financial freedom) target dates
    DateTime? earliestTargetDate;
    DateTime? latestTargetDate;
    for (var envelope in envelopesWithDates) {
      if (envelope.targetDate != null) {
        // Earliest (next deadline)
        if (earliestTargetDate == null ||
            envelope.targetDate!.isBefore(earliestTargetDate)) {
          earliestTargetDate = envelope.targetDate;
        }
        // Latest (financial freedom date)
        if (latestTargetDate == null ||
            envelope.targetDate!.isAfter(latestTargetDate)) {
          latestTargetDate = envelope.targetDate;
        }
      }
    }

    // Calculate time saved with current strategy
    final timeSaved = _calculateTimeSaved(envelopesToShow);
    final totalDaysSaved = timeSaved['total'] ?? 0;

    // Determine if on track (all envelopes meeting their targets)
    bool allOnTrack = true;
    if (envelopesWithDates.isNotEmpty) {
      for (var envelope in envelopesWithDates) {
        final isOnTrack = _onTrackStatus[envelope.id] ?? true;
        if (!isOnTrack) {
          allOnTrack = false;
          break;
        }
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
                    Icons.wb_twilight,
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

          // NEW: Financial Freedom Date & Strategy Status
          if (latestTargetDate != null || totalDaysSaved != 0) ...[
            const SizedBox(height: 16),

            // Strategy Status Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Financial Freedom Date (if multiple targets)
                if (latestTargetDate != null && envelopesWithDates.length > 1)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.celebration_outlined,
                              size: 14,
                              color: theme.colorScheme.onPrimaryContainer.withAlpha(179),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Financial Freedom',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onPrimaryContainer.withAlpha(179),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${latestTargetDate.day}/${latestTargetDate.month}/${latestTargetDate.year}',
                          style: fontProvider.getTextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                // On Track / Behind Status
                if (envelopesWithDates.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: allOnTrack
                          ? theme.colorScheme.secondary.withAlpha(51)
                          : theme.colorScheme.error.withAlpha(51),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: allOnTrack
                            ? theme.colorScheme.secondary.withAlpha(128)
                            : theme.colorScheme.error.withAlpha(128),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          allOnTrack ? Icons.check_circle : Icons.warning_amber_rounded,
                          size: 16,
                          color: allOnTrack
                              ? theme.colorScheme.secondary
                              : theme.colorScheme.error,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          allOnTrack ? 'On Track' : 'Behind Schedule',
                          style: fontProvider.getTextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: allOnTrack
                                ? theme.colorScheme.secondary
                                : theme.colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            // Strategy Delta (Time Saved)
            if (totalDaysSaved != 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: totalDaysSaved > 0
                      ? theme.colorScheme.secondary.withAlpha(26)
                      : theme.colorScheme.error.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      totalDaysSaved > 0
                          ? Icons.trending_up
                          : Icons.trending_down,
                      size: 18,
                      color: totalDaysSaved > 0
                          ? theme.colorScheme.secondary
                          : theme.colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        totalDaysSaved > 0
                            ? 'Strategy saves ${_formatDays(totalDaysSaved)}'
                            : 'Strategy adds ${_formatDays(totalDaysSaved.abs())}',
                        style: fontProvider.getTextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: totalDaysSaved > 0
                              ? theme.colorScheme.secondary
                              : theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// Format days into human-readable time periods
  String _formatDays(int days) {
    if (days == 0) return 'today';
    if (days == 1) return '1 day';
    if (days < 7) return '$days days';
    if (days < 30) {
      final weeks = (days / 7).round();
      return weeks == 1 ? '1 week' : '$weeks weeks';
    }
    if (days < 365) {
      final months = (days / 30).round();
      return months == 1 ? '1 month' : '$months months';
    }
    final years = (days / 365).round();
    return years == 1 ? '1 year' : '$years years';
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
          'Horizon Navigator',
          style: fontProvider.getTextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          'Simulate contributions for ${selectedEnvelopes.length} envelope${selectedEnvelopes.length == 1 ? '' : 's'}',
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
                      // Mark as manual override when user types directly
                      _manualOverride = true;

                      // Auto-expand all envelope projections when a valid amount is entered
                      final amount = double.tryParse(value);
                      if (amount != null && amount > 0) {
                        _expandedEnvelopeProjections.addAll(
                          _selectedEnvelopeIds,
                        );

                        // Update velocity multiplier to match manual input (clamp to slider range)
                        if (_baselineTotal > 0) {
                          _velocityMultiplier = (amount / _baselineTotal).clamp(0.0, 2.0);
                        }
                      }
                      // Run sandbox simulation
                      _simulateHorizon(targetEnvelopes);
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
                      // Re-run sandbox simulation with new frequency
                      _simulateHorizon(targetEnvelopes);
                    });
                  },
                ),
                const SizedBox(height: 24),

                // NEW: Velocity Slider - Quick Strategy Booster
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.secondaryContainer.withAlpha(51),
                        theme.colorScheme.secondaryContainer.withAlpha(26),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.secondary.withAlpha(77),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.speed,
                            size: 20,
                            color: theme.colorScheme.secondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Strategy Booster',
                            style: fontProvider.getTextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Current baseline display
                      if (_baselineTotal > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.analytics_outlined,
                                size: 14,
                                color: theme.colorScheme.onSurface.withAlpha(179),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Current Baseline: ${locale.formatCurrency(_baselineTotal)}/mo detected',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface.withAlpha(179),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Velocity Multiplier Slider
                      Row(
                        children: [
                          Text(
                            '0%',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withAlpha(128),
                            ),
                          ),
                          Expanded(
                            child: Slider(
                              value: _velocityMultiplier,
                              min: 0.0,
                              max: 2.0,
                              divisions: 8,
                              label: '+${((_velocityMultiplier - 1.0) * 100).round()}%',
                              onChanged: _baselineTotal > 0 ? (value) {
                                setState(() {
                                  _velocityMultiplier = value;
                                  _manualOverride = false;

                                  // Calculate new total based on multiplier
                                  final newTotal = _baselineTotal * value;
                                  _totalContributionController.text = newTotal.toStringAsFixed(2);

                                  // Re-run simulation
                                  _simulateHorizon(targetEnvelopes);
                                });
                              } : null,
                            ),
                          ),
                          Text(
                            '+100%',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withAlpha(128),
                            ),
                          ),
                        ],
                      ),

                      // Multiplier display
                      Center(
                        child: Text(
                          _velocityMultiplier == 1.0
                              ? 'Baseline Strategy'
                              : _velocityMultiplier < 1.0
                                  ? '${((_velocityMultiplier - 1.0) * 100).round()}% slower'
                                  : '+${((_velocityMultiplier - 1.0) * 100).round()}% faster',
                          style: fontProvider.getTextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _velocityMultiplier == 1.0
                                ? theme.colorScheme.onSurface
                                : _velocityMultiplier < 1.0
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Per-Envelope Allocation
                Text(
                  'Horizon Velocity',
                  style: fontProvider.getTextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Adjust contribution speed to reach each horizon',
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

                // NEW: Commit Strategy Button
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => _commitStrategy(selectedEnvelopes, theme, fontProvider),
                  icon: const Icon(Icons.save),
                  label: Text(
                    'Commit Strategy to Cash Flow',
                    style: fontProvider.getTextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    backgroundColor: theme.colorScheme.secondary,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Saves your strategy to each envelope\'s Cash Flow settings',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withAlpha(128),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Commit the simulated strategy to actual Cash Flow settings
  Future<void> _commitStrategy(
    List<Envelope> selectedEnvelopes,
    ThemeData theme,
    FontProvider fontProvider,
  ) async {
    final totalContribution = double.tryParse(_totalContributionController.text) ?? 0;

    if (totalContribution <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a valid contribution amount'),
          backgroundColor: theme.colorScheme.error,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Commit Strategy?',
          style: fontProvider.getTextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will update Cash Flow settings for all selected envelopes:',
            ),
            const SizedBox(height: 12),
            ...selectedEnvelopes.map((envelope) {
              final allocation = _contributionAllocations[envelope.id] ?? 0;
              final amount = totalContribution * (allocation / 100);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    envelope.getIconWidget(theme, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        envelope.name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      Provider.of<LocaleProvider>(context, listen: false)
                          .formatCurrency(amount),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer.withAlpha(51),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Cash Flow will be enabled and set to these monthly amounts',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.secondary,
            ),
            child: const Text('Commit'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Apply changes to all selected envelopes
    for (var envelope in selectedEnvelopes) {
      final allocation = _contributionAllocations[envelope.id] ?? 0;
      final amount = totalContribution * (allocation / 100);

      // Update envelope with new Cash Flow settings
      await widget.envelopeRepo.updateEnvelope(
        envelopeId: envelope.id,
        cashFlowEnabled: true,
        cashFlowAmount: amount,
      );
    }

    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Strategy committed! ${selectedEnvelopes.length} envelope${selectedEnvelopes.length == 1 ? '' : 's'} updated.',
          ),
          backgroundColor: theme.colorScheme.secondary,
          action: SnackBarAction(
            label: 'Done',
            textColor: theme.colorScheme.onSecondary,
            onPressed: () {},
          ),
        ),
      );
    }
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

                    // Check if on track vs behind schedule
                    () {
                      final isOnTrack = _onTrackStatus[envelope.id] ?? true;
                      final virtualReachDate = _virtualReachDates[envelope.id];

                      return Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isOnTrack
                              ? theme.colorScheme.secondaryContainer.withAlpha(51)
                              : theme.colorScheme.errorContainer.withAlpha(51),
                          borderRadius: BorderRadius.circular(8),
                          border: !isOnTrack
                              ? Border.all(
                                  color: theme.colorScheme.error.withAlpha(128),
                                  width: 1.5,
                                )
                              : null,
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isOnTrack ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                                      size: 16,
                                      color: isOnTrack
                                          ? theme.colorScheme.secondary
                                          : theme.colorScheme.error,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isOnTrack
                                          ? 'Horizon in ${_getSmartTimePeriod(contributionsNeeded, frequency)}'
                                          : 'Behind Schedule',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isOnTrack
                                            ? theme.colorScheme.onSecondaryContainer
                                            : theme.colorScheme.error,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  virtualReachDate != null
                                      ? '${virtualReachDate.day}/${virtualReachDate.month}/${virtualReachDate.year}'
                                      : '${targetDate.day}/${targetDate.month}/${targetDate.year}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isOnTrack
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.error,
                                  ),
                                ),
                              ],
                            ),
                            if (!isOnTrack && envelope.targetDate != null && virtualReachDate != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Target: ${envelope.targetDate!.day}/${envelope.targetDate!.month}/${envelope.targetDate!.year} • ${virtualReachDate.difference(envelope.targetDate!).inDays} days late',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.colorScheme.error.withAlpha(179),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }(),
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

  /// Get approximate days per frequency for horizon calculations
  /// Monthly uses average to account for varying month lengths
  int _getDaysPerFrequency(String frequency) {
    switch (frequency) {
      case 'daily':
        return 1;
      case 'weekly':
        return 7;
      case 'biweekly':
        return 14;
      case 'monthly':
        return 30; // Keep as 30 for UI simplicity (average 30.44 used in financial calcs)
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
