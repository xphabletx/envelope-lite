import 'package:flutter/material.dart';
import '../../../models/envelope.dart';
import '../../../providers/font_provider.dart';
import '../../../providers/locale_provider.dart';
import '../../../providers/time_machine_provider.dart';
import '../../../providers/horizon_controller.dart';
import '../../../utils/target_helper.dart';

class HorizonSummaryCard extends StatelessWidget {
  final List<Envelope> envelopesToShow;
  final HorizonController controller;
  final FontProvider fontProvider;
  final LocaleProvider locale;
  final TimeMachineProvider timeMachine;

  const HorizonSummaryCard({
    super.key,
    required this.envelopesToShow,
    required this.controller,
    required this.fontProvider,
    required this.locale,
    required this.timeMachine,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final referenceDate = timeMachine.isActive
        ? timeMachine.futureDate!
        : DateTime.now();

    // Calculate Amount Progress
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
    final exceeded = remaining < 0 ? remaining.abs() : 0.0;

    // Calculate Time Progress & Dates
    DateTime? earliestTargetDate;
    DateTime? latestTargetDate;
    double totalTimeProgress = 0.0;
    int totalDaysRemaining = 0;
    final envelopesWithDates = envelopesToShow
        .where((e) => e.targetDate != null)
        .toList();

    for (var envelope in envelopesWithDates) {
      totalTimeProgress += TargetHelper.calculateTimeProgress(
        envelope,
        referenceDate: referenceDate,
      );
      totalDaysRemaining += TargetHelper.getDaysRemaining(
        envelope,
        projectedDate: referenceDate,
      );

      if (earliestTargetDate == null ||
          envelope.targetDate!.isBefore(earliestTargetDate)) {
        earliestTargetDate = envelope.targetDate;
      }
      if (latestTargetDate == null ||
          envelope.targetDate!.isAfter(latestTargetDate)) {
        latestTargetDate = envelope.targetDate;
      }
    }

    final avgTimeProgress = envelopesWithDates.isNotEmpty
        ? totalTimeProgress / envelopesWithDates.length
        : null;
    final avgDaysRemaining = envelopesWithDates.isNotEmpty
        ? (totalDaysRemaining / envelopesWithDates.length).round()
        : null;

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
          _buildHeader(theme, avgDaysRemaining),
          const SizedBox(height: 12),
          _buildAmountSection(
            theme,
            totalCurrent,
            totalTarget,
            progress,
            remaining,
            exceeded,
          ),
          if (avgTimeProgress != null) ...[
            const SizedBox(height: 16),
            _buildTimeSection(theme, avgTimeProgress, earliestTargetDate),
          ],
          if (latestTargetDate != null) ...[
            const SizedBox(height: 16),
            _buildStrategyFooter(
              theme,
              latestTargetDate,
              envelopesWithDates.length,
            ),
          ],
        ],
      ),
    );
  }

  // --- Sub-Components (Ported for Cleanliness) ---

  Widget _buildHeader(ThemeData theme, int? daysLeft) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.wb_twilight, size: 24, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              '${envelopesToShow.length} Horizons',
              style: fontProvider.getTextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
        if (daysLeft != null && daysLeft > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary.withAlpha(77),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${daysLeft}d left',
              style: fontProvider.getTextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAmountSection(
    ThemeData theme,
    double current,
    double target,
    double progress,
    double left,
    double over,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                    color: theme.colorScheme.onPrimaryContainer.withAlpha(179),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  locale.formatCurrency(current),
                  style: fontProvider.getTextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ],
            ),
            Text(
              'of ${locale.formatCurrency(target)}',
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
            backgroundColor: theme.colorScheme.onPrimaryContainer.withAlpha(51),
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
            Text(
              over > 0
                  ? '+${locale.formatCurrency(over)}'
                  : '${locale.formatCurrency(left)} left',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeSection(
    ThemeData theme,
    double timeProgress,
    DateTime? nextDeadline,
  ) {
    return Column(
      children: [
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
            backgroundColor: theme.colorScheme.onPrimaryContainer.withAlpha(51),
            valueColor: AlwaysStoppedAnimation(theme.colorScheme.secondary),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${(timeProgress * 100).toStringAsFixed(1)}% elapsed',
              style: const TextStyle(fontSize: 12),
            ),
            if (nextDeadline != null)
              Text(
                '${nextDeadline.day}/${nextDeadline.month}/${nextDeadline.year}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildStrategyFooter(
    ThemeData theme,
    DateTime freedomDate,
    int count,
  ) {
    // Logic for "On Track" status is now handled by checking the controller state
    bool allOnTrack = true;
    for (var env in envelopesToShow) {
      if (!(controller.onTrackStatus[env.id] ?? true)) {
        allOnTrack = false;
        break;
      }
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (count > 1)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Financial Freedom',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onPrimaryContainer.withAlpha(179),
                ),
              ),
              Text(
                '${freedomDate.day}/${freedomDate.month}/${freedomDate.year}',
                style: fontProvider.getTextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.secondary,
                ),
              ),
            ],
          ),
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
            ),
          ),
          child: Row(
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
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
