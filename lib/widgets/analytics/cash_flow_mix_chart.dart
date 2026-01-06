import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/analytics_data.dart';
import '../../providers/font_provider.dart';
import '../../providers/locale_provider.dart';
import 'package:intl/intl.dart';
import './spending_donut_chart.dart';

/// Simplified Cash Flow Mix Chart - Shows 3 segments:
/// 1. Fixed Bills (Red) - Debt envelopes + Autopilot payments
/// 2. Discretionary (Orange) - Other external spending
/// 3. Horizon Savings (Gold/Green) - Internal moves to target envelopes
class CashFlowMixChart extends StatelessWidget {
  const CashFlowMixChart({
    super.key,
    required this.stats,
  });

  final HorizonStrategyStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final locale = Provider.of<LocaleProvider>(context);
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);

    // Create 3 segments for the donut chart
    final segments = <ChartSegment>[];

    // Segment 1: Fixed Bills (Red)
    if (stats.fixedBills > 0) {
      segments.add(ChartSegment(
        id: 'fixed_bills',
        name: 'Fixed Bills',
        amount: stats.fixedBills,
        color: Colors.red.shade700,
        emoji: '📋',
        isBinder: false,
      ));
    }

    // Segment 2: Discretionary (Orange)
    if (stats.discretionary > 0) {
      segments.add(ChartSegment(
        id: 'discretionary',
        name: 'Discretionary',
        amount: stats.discretionary,
        color: Colors.orange.shade700,
        emoji: '💳',
        isBinder: false,
      ));
    }

    // Segment 3: Horizon Savings (Gold/Green)
    if (stats.horizonVelocity > 0) {
      segments.add(ChartSegment(
        id: 'horizon_savings',
        name: 'Horizon Savings',
        amount: stats.horizonVelocity,
        color: theme.colorScheme.secondary,
        emoji: '🎯',
        isBinder: false,
      ));
    }

    final total = segments.fold(0.0, (sum, s) => sum + s.amount);

    // If no data, show placeholder with empty donut
    if (total == 0 || segments.isEmpty) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.pie_chart,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Cash Flow Mix',
                  style: fontProvider.getTextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            // Empty donut circle
            Center(
              child: Column(
                children: [
                  Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                        width: 32,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.hourglass_empty,
                        size: 48,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No spending data for this period',
                    style: fontProvider.getTextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.pie_chart,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Cash Flow Mix',
                style: fontProvider.getTextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Donut Chart
          SpendingDonutChart(
            segments: segments,
            total: total,
            isDrilledDown: false,
            onSegmentTap: (_) {}, // No drill-down functionality
            onBackTap: null,
          ),

          const SizedBox(height: 24),

          // Legend with amounts
          ...segments.map((segment) {
            final percent = (segment.amount / total) * 100;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: segment.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    segment.emoji ?? '',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      segment.name,
                      style: fontProvider.getTextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        currency.format(segment.amount),
                        style: fontProvider.getTextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: segment.color,
                        ),
                      ),
                      Text(
                        '${percent.toStringAsFixed(1)}%',
                        style: fontProvider.getTextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
