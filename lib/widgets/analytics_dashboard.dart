import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/envelope.dart'; // Adjust import path if needed
import '../../providers/theme_provider.dart'; // Adjust import path
import 'package:provider/provider.dart';

class AnalyticsDashboard extends StatelessWidget {
  final List<Envelope> envelopes;
  final double totalSaved;
  final String currencySymbol;

  const AnalyticsDashboard({
    Key? key,
    required this.envelopes,
    required this.totalSaved,
    required this.currencySymbol,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Access current theme colors
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final onSurface = theme.colorScheme.onSurface;

    // Sort envelopes by amount (High to Low) for the chart
    final sortedEnvelopes = List<Envelope>.from(envelopes)
      ..sort((a, b) => b.currentAmount.compareTo(a.currentAmount));
    final topEnvelopes = sortedEnvelopes.take(5).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Net Worth Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, primaryColor.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Total Saved",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "$currencySymbol${NumberFormat('#,##0.00').format(totalSaved)}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Caveat', // Respecting font constraint
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Text(
            "Top Envelopes",
            style: theme.textTheme.headlineSmall?.copyWith(
              fontFamily: 'Caveat',
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),

          // 2. Bar Chart
          if (totalSaved > 0)
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: topEnvelopes.first.currentAmount * 1.2,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      tooltipBgColor: Colors.blueGrey,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          topEnvelopes[group.x.toInt()].name,
                          const TextStyle(color: Colors.white),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          if (value.toInt() >= topEnvelopes.length)
                            return const SizedBox.shrink();
                          // Show first 2 chars of envelope name
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              topEnvelopes[value.toInt()].name
                                  .substring(0, 2)
                                  .toUpperCase(),
                              style: TextStyle(
                                color: onSurface.withOpacity(0.6),
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: topEnvelopes.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.currentAmount,
                          color: primaryColor,
                          width: 16,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: topEnvelopes.first.currentAmount * 1.2,
                            color: onSurface.withOpacity(0.05),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            )
          else
            const Center(child: Text("Start saving to see analytics!")),

          const SizedBox(height: 24),

          // 3. Targets At A Glance
          Text(
            "Target Progress",
            style: theme.textTheme.headlineSmall?.copyWith(
              fontFamily: 'Caveat',
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          ...envelopes.where((e) => (e.targetAmount ?? 0) > 0).map((e) {
            final progress = (e.currentAmount / e.targetAmount!).clamp(
              0.0,
              1.0,
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        e.name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text("${(progress * 100).toInt()}%"),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: onSurface.withOpacity(0.1),
                    color: progress >= 1.0 ? Colors.green : primaryColor,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
