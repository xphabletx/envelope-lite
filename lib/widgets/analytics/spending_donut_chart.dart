import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../models/analytics_data.dart';
import '../../providers/font_provider.dart';
import '../../providers/locale_provider.dart';

class SpendingDonutChart extends StatefulWidget {
  const SpendingDonutChart({
    super.key,
    required this.segments,
    required this.total,
    required this.isDrilledDown,
    required this.onSegmentTap,
    required this.onBackTap,
  });

  final List<ChartSegment> segments;
  final double total;
  final bool isDrilledDown;
  final Function(ChartSegment) onSegmentTap;
  final VoidCallback? onBackTap;

  @override
  State<SpendingDonutChart> createState() => _SpendingDonutChartState();
}

class _SpendingDonutChartState extends State<SpendingDonutChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final locale = Provider.of<LocaleProvider>(context, listen: false);
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);

    if (widget.segments.isEmpty) {
      return Container(
        height: 300,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pie_chart_outline,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No data for this period',
              style: fontProvider.getTextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Back button if drilled down
        if (widget.isDrilledDown && widget.onBackTap != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FilledButton.tonalIcon(
              onPressed: widget.onBackTap,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: Text(
                'Back to Binders',
                style: fontProvider.getTextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),

        // Chart
        SizedBox(
          height: 280,
          child: Stack(
            children: [
              PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          touchedIndex = -1;
                          return;
                        }
                        touchedIndex =
                            pieTouchResponse.touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 2,
                  centerSpaceRadius: 80,
                  sections: _buildSections(),
                ),
              ),

              // Center text
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Total',
                      style: fontProvider.getTextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currency.format(widget.total),
                      style: fontProvider.getTextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Legend
        Wrap(
          spacing: 16,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: widget.segments.map((segment) {
            final index = widget.segments.indexOf(segment);
            final isTouched = index == touchedIndex;

            return InkWell(
              onTap: () => widget.onSegmentTap(segment),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isTouched
                      ? segment.color.withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isTouched
                        ? segment.color
                        : theme.colorScheme.outline.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: segment.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (segment.emoji != null) ...[
                      Text(segment.emoji!, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 4),
                    ],
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Text(
                        segment.name,
                        style: fontProvider.getTextStyle(
                          fontSize: 14,
                          fontWeight: isTouched
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${segment.getPercentage(widget.total).toStringAsFixed(0)}%',
                      style: fontProvider.getTextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: segment.color,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  List<PieChartSectionData> _buildSections() {
    return widget.segments.asMap().entries.map((entry) {
      final index = entry.key;
      final segment = entry.value;
      final isTouched = index == touchedIndex;

      final fontSize = isTouched ? 16.0 : 14.0;
      final radius = isTouched ? 70.0 : 60.0;

      return PieChartSectionData(
        color: segment.color,
        value: segment.amount,
        title: '${segment.getPercentage(widget.total).toStringAsFixed(0)}%',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 2,
            ),
          ],
        ),
      );
    }).toList();
  }
}
