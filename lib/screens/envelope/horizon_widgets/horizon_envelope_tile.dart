import 'package:flutter/material.dart';
import '../../../models/envelope.dart';
import '../../../providers/font_provider.dart';
import '../../../providers/locale_provider.dart';
import '../horizon_controller.dart';

class HorizonEnvelopeTile extends StatelessWidget {
  final Envelope envelope;
  final HorizonController controller;
  final FontProvider fontProvider;
  final LocaleProvider locale;
  final bool isSelected;
  final VoidCallback? onToggleSelection;

  const HorizonEnvelopeTile({
    super.key,
    required this.envelope,
    required this.controller,
    required this.fontProvider,
    required this.locale,
    this.isSelected = false,
    this.onToggleSelection,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amount = controller.contributionAmounts[envelope.id] ?? 0.0;
    final remaining = (envelope.targetAmount ?? 0) - envelope.currentAmount;
    final progress = (envelope.targetAmount ?? 0) > 0
        ? (envelope.currentAmount / envelope.targetAmount!).clamp(0.0, 1.0)
        : 0.0;

    // Calculate projection based on the current controller speed
    final monthsToTarget = amount > 0 ? (remaining / amount) : 0.0;
    final projectedDate = DateTime.now().add(
      Duration(days: (monthsToTarget * 30.44).round()),
    );
    final isOnTrack = controller.onTrackStatus[envelope.id] ?? true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ExpansionTile(
        key: PageStorageKey(envelope.id),
        shape: const Border(),
        leading: envelope.getIconWidget(theme, size: 24),
        title: Text(
          envelope.name,
          style: fontProvider.getTextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        trailing: Checkbox(
          value: isSelected,
          onChanged: (_) => onToggleSelection?.call(),
        ),
        subtitle: _buildMiniProgress(theme, progress),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                const Divider(),
                _buildStatRow(
                  'Target Amount',
                  locale.formatCurrency(envelope.targetAmount ?? 0),
                ),
                _buildStatRow(
                  'Monthly Speed',
                  locale.formatCurrency(amount),
                  isPrimary: true,
                ),
                const SizedBox(height: 12),
                _buildProjectionBadge(
                  theme,
                  isOnTrack,
                  projectedDate,
                  monthsToTarget,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniProgress(ThemeData theme, double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${(progress * 100).toStringAsFixed(1)}% complete',
          style: const TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value, {bool isPrimary = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(
            value,
            style: fontProvider.getTextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isPrimary ? Colors.blue : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectionBadge(
    ThemeData theme,
    bool onTrack,
    DateTime date,
    double months,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: onTrack
            ? theme.colorScheme.secondaryContainer.withAlpha(50)
            : theme.colorScheme.errorContainer.withAlpha(50),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(onTrack ? Icons.event_available : Icons.event_busy, size: 16),
          const SizedBox(width: 8),
          Text(
            'Horizon: ${date.day}/${date.month}/${date.year} (~${months.toStringAsFixed(1)} mo)',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
