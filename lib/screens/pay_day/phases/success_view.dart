// lib/screens/pay_day/phases/success_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../providers/pay_day_cockpit_provider.dart';
import '../../../providers/font_provider.dart';
import '../../../providers/locale_provider.dart';
import '../../../models/envelope.dart';
import '../../../utils/pay_day_phrases.dart';

class SuccessView extends StatefulWidget {
  final Map<String, double> calculatedBoosts;

  const SuccessView({
    super.key,
    required this.calculatedBoosts,
  });

  @override
  State<SuccessView> createState() => _SuccessViewState();
}

class _SuccessViewState extends State<SuccessView> {
  late final String _paydayPhrase;

  @override
  void initState() {
    super.initState();
    _paydayPhrase = PayDayPhrases.getRandom(); // Generate once on entry
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PayDayCockpitProvider>();
    final theme = Theme.of(context);
    final fontProvider = context.read<FontProvider>();
    final locale = context.read<LocaleProvider>();
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);

    // Calculate mission statistics
    final totalDistributed = provider.stuffingProgress.values.fold(
      0.0,
      (sum, amount) => sum + amount,
    );
    final envelopesFunded = provider.stuffingProgress.length;
    final totalDaysSaved = provider.topHorizons.fold(
      0,
      (sum, impact) => sum + impact.daysSaved,
    );

    // Count envelopes with horizons
    final envelopesWithHorizons = provider.stuffingProgress.keys.where((id) {
      final env = provider.allEnvelopes.firstWhere((e) => e.id == id);
      return env.targetAmount != null;
    }).length;

    // Calculate average days saved per horizon
    final avgDaysSaved = envelopesWithHorizons > 0
        ? (totalDaysSaved / envelopesWithHorizons).round()
        : 0;

    // Count how many envelopes got boost (from calculated boosts)
    final boostedCount = widget.calculatedBoosts.entries
        .where((e) => e.value > 0)
        .length;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),

            // PayDay Phrase with random message
            Text(
              _paydayPhrase,
              style: fontProvider.getTextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Mission Accomplished Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade50, Colors.green.shade100],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.shade400, width: 2),
              ),
              child: Column(
                children: [
                  const Text('🎯', style: TextStyle(fontSize: 60)),
                  const SizedBox(height: 12),
                  Text(
                    'MISSION ACCOMPLISHED',
                    style: fontProvider
                        .getTextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade900,
                        )
                        .copyWith(letterSpacing: 1.2),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Future Successfully Recalibrated',
                    style: fontProvider.getTextStyle(
                      fontSize: 16,
                      color: Colors.green.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Key Statistics Grid
            Text(
              'Mission Statistics',
              style: fontProvider.getTextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),

            // 2x2 Grid of stats
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    '💰',
                    'Total Distributed',
                    currency.format(totalDistributed),
                    Colors.green,
                    theme,
                    fontProvider,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    '📨',
                    'Envelopes Funded',
                    '$envelopesFunded',
                    Colors.blue,
                    theme,
                    fontProvider,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    '🔥',
                    'Total Days Saved',
                    '$totalDaysSaved days',
                    Colors.orange,
                    theme,
                    fontProvider,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    '🚀',
                    'Boosted Horizons',
                    '$boostedCount',
                    Colors.amber,
                    theme,
                    fontProvider,
                  ),
                ),
              ],
            ),

            if (avgDaysSaved > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade50, Colors.indigo.shade50],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('⚡', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Column(
                      children: [
                        Text(
                          'Average Acceleration',
                          style: fontProvider.getTextStyle(
                            fontSize: 12,
                            color: Colors.purple.shade700,
                          ),
                        ),
                        Text(
                          '$avgDaysSaved days per horizon',
                          style: fontProvider.getTextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple.shade900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            // Autopilot Preparedness Section
            if (provider.upcomingPayments.isNotEmpty) ...[
              const SizedBox(height: 32),
              Text(
                'Autopilot Status',
                style: fontProvider.getTextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              _buildAutopilotPreparednessCard(
                provider,
                theme,
                fontProvider,
                currency,
              ),
            ],

            const SizedBox(height: 32),

            // Top 3 horizons moved forward
            if (provider.topHorizons.isNotEmpty) ...[
              Text(
                'Top Horizon Impacts',
                style: fontProvider.getTextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              ...provider.topHorizons.asMap().entries.map((entry) {
                final index = entry.key;
                final impact = entry.value;
                return _buildHorizonImpactCard(
                  theme,
                  fontProvider,
                  currency,
                  impact,
                  rank: index + 1,
                );
              }),
            ],

            const SizedBox(height: 32),

            // Done button
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.secondary,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Return to Base',
                style: fontProvider.getTextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String emoji,
    String label,
    String value,
    MaterialColor color,
    ThemeData theme,
    FontProvider fontProvider, {
    VoidCallback? onTap,
  }) {
    final cardContent = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.shade50, color.shade100]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade300),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Text(
            label,
            style: fontProvider.getTextStyle(
              fontSize: 11,
              color: color.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: fontProvider.getTextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color.shade900,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: cardContent,
      );
    }

    return cardContent;
  }

  Widget _buildAutopilotPreparednessCard(
    PayDayCockpitProvider provider,
    ThemeData theme,
    FontProvider fontProvider,
    NumberFormat currency,
  ) {
    final preparedCount = provider.autopilotPreparedness.values
        .where((prepared) => prepared)
        .length;
    final totalCount = provider.upcomingPayments.length;
    final allPrepared = preparedCount == totalCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: allPrepared
              ? [Colors.green.shade50, Colors.green.shade100]
              : [Colors.orange.shade50, Colors.orange.shade100],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: allPrepared ? Colors.green.shade300 : Colors.orange.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                allPrepared ? '✅' : '⚠️',
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  allPrepared
                      ? 'All Envelopes Ready for Autopilot!'
                      : 'Some Envelopes Need Attention',
                  style: fontProvider.getTextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: allPrepared
                        ? Colors.green.shade900
                        : Colors.orange.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$preparedCount of $totalCount upcoming scheduled payments are fully funded',
            style: fontProvider.getTextStyle(
              fontSize: 14,
              color: allPrepared
                  ? Colors.green.shade700
                  : Colors.orange.shade700,
            ),
          ),
          const SizedBox(height: 16),
          ...provider.upcomingPayments.map<Widget>((payment) {
            final envelope = provider.allEnvelopes.firstWhere(
              (e) => e.id == payment.envelopeId,
              orElse: () => Envelope(
                id: payment.envelopeId ?? '',
                name: 'Unknown',
                userId: provider.userId,
                currentAmount: 0,
              ),
            );
            final isPrepared =
                provider.autopilotPreparedness[payment.envelopeId] ?? false;
            final shortage = isPrepared
                ? 0.0
                : (payment.amount - envelope.currentAmount);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text(
                    isPrepared ? '✓' : '✗',
                    style: TextStyle(
                      fontSize: 16,
                      color: isPrepared
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  envelope.getIconWidget(theme, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          envelope.name,
                          style: fontProvider.getTextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (!isPrepared)
                          Text(
                            'Short ${currency.format(shortage)}',
                            style: fontProvider.getTextStyle(
                              fontSize: 11,
                              color: Colors.red.shade700,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    currency.format(payment.amount),
                    style: fontProvider.getTextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isPrepared
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHorizonImpactCard(
    ThemeData theme,
    FontProvider fontProvider,
    NumberFormat currency,
    EnvelopeHorizonImpact impact, {
    int? rank,
  }) {
    // Medal colors based on rank
    Color? medalColor;
    String? medal;
    if (rank != null) {
      switch (rank) {
        case 1:
          medalColor = Colors.amber.shade700;
          medal = '🥇';
          break;
        case 2:
          medalColor = Colors.grey.shade600;
          medal = '🥈';
          break;
        case 3:
          medalColor = Colors.brown.shade600;
          medal = '🥉';
          break;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: rank != null && rank <= 3
            ? LinearGradient(
                colors: [
                  medalColor?.withValues(alpha: 0.1) ??
                      theme.colorScheme.surfaceContainerHighest,
                  theme.colorScheme.surfaceContainerHighest,
                ],
              )
            : null,
        color: rank == null ? theme.colorScheme.surfaceContainerHighest : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: medalColor ?? theme.colorScheme.primary.withValues(alpha: 0.3),
          width: rank != null && rank <= 3 ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          if (medal != null) ...[
            Text(medal, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 8),
          ],
          Text(
            impact.envelope.emoji ?? '📨',
            style: const TextStyle(fontSize: 32),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  impact.envelope.name,
                  style: fontProvider.getTextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '🔥 ${impact.daysSaved} days closer',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      currency.format(impact.stuffedAmount),
                      style: fontProvider.getTextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
