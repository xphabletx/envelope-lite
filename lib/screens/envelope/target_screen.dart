// lib/screens/envelope/target_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/envelope.dart';
import '../../models/transaction.dart';
import '../../services/envelope_repo.dart';
import '../../services/group_repo.dart';
import '../../services/account_repo.dart';
import '../../providers/font_provider.dart';
import '../../providers/locale_provider.dart';
import '../../utils/calculator_helper.dart';
import 'envelope_settings_sheet.dart';
import 'modals/deposit_modal.dart';

class TargetScreen extends StatefulWidget {
  const TargetScreen({
    super.key,
    required this.envelope,
    required this.envelopeRepo,
    required this.groupRepo,
    required this.accountRepo,
  });

  final Envelope envelope;
  final EnvelopeRepo envelopeRepo;
  final GroupRepo groupRepo;
  final AccountRepo accountRepo;

  @override
  State<TargetScreen> createState() => _TargetScreenState();
}

class _TargetScreenState extends State<TargetScreen> {
  final _contributionAmountController = TextEditingController();
  String _selectedFrequency = 'monthly';
  bool _showCalculator = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with auto-fill amount if available
    if (widget.envelope.autoFillAmount != null) {
      _contributionAmountController.text =
          widget.envelope.autoFillAmount!.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _contributionAmountController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final locale = Provider.of<LocaleProvider>(context, listen: false);

    return StreamBuilder<Envelope>(
      stream: widget.envelopeRepo.envelopeStream(widget.envelope.id),
      builder: (context, envelopeSnapshot) {
        final envelope = envelopeSnapshot.data ?? widget.envelope;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Target Progress',
              style: fontProvider.getTextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => Container(
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: EnvelopeSettingsSheet(
                        envelopeId: envelope.id,
                        repo: widget.envelopeRepo,
                        groupRepo: widget.groupRepo,
                        accountRepo: widget.accountRepo,
                      ),
                    ),
                  );
                },
                tooltip: 'Edit Target',
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Section 1: Current Progress
              _buildCurrentProgress(envelope, theme, fontProvider, locale),
              const SizedBox(height: 24),

              // Section 2: Calculation Helper
              _buildCalculationHelper(envelope, theme, fontProvider, locale),
              const SizedBox(height: 24),

              // Section 3: Historical Progress Graph
              StreamBuilder<List<Transaction>>(
                stream: widget.envelopeRepo
                    .transactionsForEnvelope(envelope.id),
                builder: (context, txSnapshot) {
                  if (!txSnapshot.hasData) {
                    return const SizedBox.shrink();
                  }
                  return _buildHistoricalGraph(
                    envelope,
                    txSnapshot.data!,
                    theme,
                    fontProvider,
                    locale,
                  );
                },
              ),
              const SizedBox(height: 24),

              // Section 4: Quick Actions
              _buildQuickActions(envelope, theme, fontProvider),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCurrentProgress(
    Envelope envelope,
    ThemeData theme,
    FontProvider fontProvider,
    LocaleProvider locale,
  ) {
    final hasAmountTarget = envelope.targetAmount != null;
    final hasTimeTarget = envelope.targetDate != null;

    // Calculate progress values
    double amountProgress = 0;
    double timeProgress = 0;
    int daysRemaining = 0;
    DateTime startDate = DateTime.now().subtract(const Duration(days: 30));

    if (hasAmountTarget) {
      amountProgress = envelope.targetAmount! > 0
          ? (envelope.currentAmount / envelope.targetAmount!).clamp(0.0, 1.0)
          : 0.0;
    }

    if (hasTimeTarget) {
      final now = DateTime.now();
      // Use term start date if available, otherwise estimate 30 days ago
      startDate = envelope.termStartDate ??
                  now.subtract(const Duration(days: 30));
      final totalDays = envelope.targetDate!.difference(startDate).inDays;
      final elapsedDays = now.difference(startDate).inDays;
      timeProgress = totalDays > 0 ? (elapsedDays / totalDays).clamp(0.0, 1.0) : 0.0;
      daysRemaining = envelope.targetDate!.difference(now).inDays;
    }

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
          // Icon/Emoji
          envelope.getIconWidget(theme, size: 48),
          const SizedBox(height: 16),

          // Envelope name
          Text(
            envelope.name,
            style: fontProvider.getTextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onPrimaryContainer,
            ),
            textAlign: TextAlign.center,
          ),

          // Amount Progress
          if (hasAmountTarget) ...[
            const SizedBox(height: 24),
            Text(
              locale.formatCurrency(envelope.currentAmount),
              style: fontProvider.getTextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.primary,
              ),
            ),
            Text(
              'of ${locale.formatCurrency(envelope.targetAmount!)}',
              style: fontProvider.getTextStyle(
                fontSize: 18,
                color: theme.colorScheme.onPrimaryContainer.withAlpha(204),
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: amountProgress,
                minHeight: 12,
                backgroundColor:
                    theme.colorScheme.onPrimaryContainer.withAlpha(51),
                valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(amountProgress * 100).toStringAsFixed(1)}% complete',
              style: fontProvider.getTextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            Text(
              '${locale.formatCurrency(envelope.targetAmount! - envelope.currentAmount)} remaining',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onPrimaryContainer.withAlpha(179),
              ),
            ),
          ],

          // Time Progress
          if (hasTimeTarget) ...[
            if (hasAmountTarget) const SizedBox(height: 24),
            if (hasAmountTarget)
              Divider(
                color: theme.colorScheme.onPrimaryContainer.withAlpha(77),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_today,
                  color: theme.colorScheme.onPrimaryContainer,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Target Date: ${DateFormat('MMM dd, yyyy').format(envelope.targetDate!)}',
                  style: fontProvider.getTextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: timeProgress,
                minHeight: 12,
                backgroundColor:
                    theme.colorScheme.onPrimaryContainer.withAlpha(51),
                valueColor: AlwaysStoppedAnimation(
                  theme.brightness == Brightness.dark
                      ? Colors.blue.shade400
                      : Colors.blue.shade600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(timeProgress * 100).toStringAsFixed(1)}% of time elapsed',
              style: fontProvider.getTextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            Text(
              daysRemaining > 0
                  ? '$daysRemaining days remaining'
                  : 'Target date passed!',
              style: TextStyle(
                fontSize: 14,
                color: daysRemaining > 0
                    ? theme.colorScheme.onPrimaryContainer.withAlpha(179)
                    : (theme.brightness == Brightness.dark
                        ? Colors.red.shade400
                        : Colors.red.shade700),
                fontWeight:
                    daysRemaining > 0 ? FontWeight.normal : FontWeight.bold,
              ),
            ),
          ],

          // On Track Status (if both targets)
          if (hasAmountTarget && hasTimeTarget) ...[
            const SizedBox(height: 24),
            Divider(
              color: theme.colorScheme.onPrimaryContainer.withAlpha(77),
            ),
            const SizedBox(height: 16),
            _buildOnTrackStatus(
              amountProgress,
              timeProgress,
              theme,
              fontProvider,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOnTrackStatus(
    double amountProgress,
    double timeProgress,
    ThemeData theme,
    FontProvider fontProvider,
  ) {
    final onTrack = amountProgress >= timeProgress;

    // Theme-aware colors
    final statusColor = onTrack
        ? (theme.brightness == Brightness.dark ? Colors.green.shade400 : Colors.green.shade700)
        : (theme.brightness == Brightness.dark ? Colors.orange.shade400 : Colors.orange.shade700);

    final bgColor = onTrack
        ? (theme.brightness == Brightness.dark
            ? theme.colorScheme.primaryContainer.withAlpha(128)
            : Colors.green.shade100)
        : (theme.brightness == Brightness.dark
            ? theme.colorScheme.errorContainer.withAlpha(128)
            : Colors.orange.shade100);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            onTrack ? Icons.check_circle : Icons.warning,
            color: statusColor,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              onTrack
                  ? '✅ On track to reach target!'
                  : '⚠️ Behind schedule',
              style: fontProvider.getTextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalculationHelper(
    Envelope envelope,
    ThemeData theme,
    FontProvider fontProvider,
    LocaleProvider locale,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        initiallyExpanded: _showCalculator,
        onExpansionChanged: (expanded) {
          setState(() => _showCalculator = expanded);
        },
        leading: Icon(
          Icons.calculate,
          color: theme.colorScheme.primary,
        ),
        title: Text(
          'Contribution Calculator',
          style: fontProvider.getTextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: const Text('Plan how to reach your target'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Contribution Amount Input
                TextField(
                  controller: _contributionAmountController,
                  decoration: InputDecoration(
                    labelText: 'Contribution Amount',
                    labelStyle: fontProvider.getTextStyle(fontSize: 16),
                    prefixText: '${locale.currencySymbol} ',
                    hintText: '100.00',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calculate_outlined),
                      onPressed: () async {
                        final result =
                            await CalculatorHelper.showCalculator(context);
                        if (result != null) {
                          _contributionAmountController.text = result;
                          setState(() {});
                        }
                      },
                      tooltip: 'Calculator',
                    ),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),

                // Frequency Selector
                DropdownButtonFormField<String>(
                  initialValue: _selectedFrequency,
                  decoration: InputDecoration(
                    labelText: 'Contribution Frequency',
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
                    setState(() => _selectedFrequency = value!);
                  },
                ),
                const SizedBox(height: 24),

                // Projection Results
                _buildProjectionResults(envelope, theme, fontProvider, locale),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectionResults(
    Envelope envelope,
    ThemeData theme,
    FontProvider fontProvider,
    LocaleProvider locale,
  ) {
    final contributionAmount =
        double.tryParse(_contributionAmountController.text) ?? 0;

    if (contributionAmount <= 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Enter a contribution amount to see projection',
          style: TextStyle(
            color: theme.colorScheme.onSurface.withAlpha(179),
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    final hasAmountTarget = envelope.targetAmount != null;
    final hasTimeTarget = envelope.targetDate != null;

    Container buildResultContainer(List<Widget> children, {Color? bgColor}) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor ??
              theme.colorScheme.primaryContainer.withAlpha(77),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.insights,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Projection',
                  style: fontProvider.getTextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      );
    }

    // Amount Only Target
    if (hasAmountTarget && !hasTimeTarget) {
      final remaining = envelope.targetAmount! - envelope.currentAmount;
      final contributionsNeeded = (remaining / contributionAmount).ceil();
      final daysPerContribution = _getDaysPerFrequency(_selectedFrequency);
      final daysToTarget = contributionsNeeded * daysPerContribution;
      final targetDate = DateTime.now().add(Duration(days: daysToTarget));

      return buildResultContainer([
        _buildProjectionRow(
          '💰 Remaining',
          locale.formatCurrency(remaining),
          fontProvider,
        ),
        const SizedBox(height: 8),
        _buildProjectionRow(
          '📊 Contributions needed',
          '$contributionsNeeded',
          fontProvider,
        ),
        const SizedBox(height: 8),
        _buildProjectionRow(
          '🎯 Reach target by',
          DateFormat('MMM dd, yyyy').format(targetDate),
          fontProvider,
        ),
      ]);
    }

    // Time Only Target
    if (hasTimeTarget && !hasAmountTarget) {
      final daysRemaining =
          envelope.targetDate!.difference(DateTime.now()).inDays;
      final daysPerContribution = _getDaysPerFrequency(_selectedFrequency);
      final contributionsRemaining =
          daysRemaining > 0 ? (daysRemaining / daysPerContribution).floor() : 0;
      final totalSaved =
          (contributionAmount * contributionsRemaining) + envelope.currentAmount;

      return buildResultContainer([
        _buildProjectionRow(
          '📅 Days until target',
          '$daysRemaining days',
          fontProvider,
        ),
        const SizedBox(height: 8),
        _buildProjectionRow(
          '📊 Contributions remaining',
          '$contributionsRemaining',
          fontProvider,
        ),
        const SizedBox(height: 8),
        _buildProjectionRow(
          '💰 Total saved by target',
          locale.formatCurrency(totalSaved),
          fontProvider,
        ),
      ]);
    }

    // Both Amount and Time Targets
    if (hasAmountTarget && hasTimeTarget) {
      final remaining = envelope.targetAmount! - envelope.currentAmount;
      final daysRemaining =
          envelope.targetDate!.difference(DateTime.now()).inDays;
      final daysPerContribution = _getDaysPerFrequency(_selectedFrequency);
      final contributionsRemaining =
          daysRemaining > 0 ? (daysRemaining / daysPerContribution).floor() : 0;

      final totalWithCurrentPace =
          envelope.currentAmount + (contributionAmount * contributionsRemaining);
      final willReachTarget = totalWithCurrentPace >= envelope.targetAmount!;

      if (willReachTarget) {
        // Will reach target on time
        final contributionsNeeded = (remaining / contributionAmount).ceil();
        final daysToTarget = contributionsNeeded * daysPerContribution;
        final reachDate = DateTime.now().add(Duration(days: daysToTarget));
        final daysEarly = envelope.targetDate!.difference(reachDate).inDays;

        final successColor = theme.brightness == Brightness.dark
            ? Colors.green.shade400
            : Colors.green.shade700;
        final successBgColor = theme.brightness == Brightness.dark
            ? theme.colorScheme.primaryContainer.withAlpha(102)
            : Colors.green.shade50;

        return buildResultContainer(
          [
            Row(
              children: [
                Icon(Icons.check_circle, color: successColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You\'ll reach your target!',
                    style: fontProvider.getTextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: successColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildProjectionRow(
              '🎯 Target reached',
              DateFormat('MMM dd, yyyy').format(reachDate),
              fontProvider,
            ),
            const SizedBox(height: 8),
            _buildProjectionRow(
              '⏰ Days before deadline',
              '$daysEarly days early',
              fontProvider,
              valueColor: successColor,
            ),
          ],
          bgColor: successBgColor,
        );
      } else {
        // Won't reach target at current pace
        final requiredPerContribution = contributionsRemaining > 0
            ? remaining / contributionsRemaining
            : remaining;

        final warningColor = theme.brightness == Brightness.dark
            ? Colors.orange.shade400
            : Colors.orange.shade700;
        final errorColor = theme.brightness == Brightness.dark
            ? Colors.red.shade400
            : Colors.red.shade700;
        final infoColor = theme.brightness == Brightness.dark
            ? Colors.blue.shade400
            : Colors.blue.shade700;
        final warningBgColor = theme.brightness == Brightness.dark
            ? theme.colorScheme.errorContainer.withAlpha(102)
            : Colors.orange.shade50;

        return buildResultContainer(
          [
            Row(
              children: [
                Icon(Icons.warning, color: warningColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Current pace won\'t reach target',
                    style: fontProvider.getTextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: warningColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildProjectionRow(
              '💰 At current pace',
              locale.formatCurrency(totalWithCurrentPace),
              fontProvider,
            ),
            const SizedBox(height: 8),
            _buildProjectionRow(
              '❌ Shortfall',
              locale.formatCurrency(envelope.targetAmount! - totalWithCurrentPace),
              fontProvider,
              valueColor: errorColor,
            ),
            const SizedBox(height: 12),
            Divider(color: theme.colorScheme.outline.withAlpha(128)),
            const SizedBox(height: 12),
            Text(
              'To reach target on time:',
              style: fontProvider.getTextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildProjectionRow(
              '✅ Need per contribution',
              locale.formatCurrency(requiredPerContribution),
              fontProvider,
              valueColor: infoColor,
            ),
          ],
          bgColor: warningBgColor,
        );
      }
    }

    return const SizedBox.shrink();
  }

  Widget _buildProjectionRow(
    String label,
    String value,
    FontProvider fontProvider, {
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: fontProvider.getTextStyle(fontSize: 14),
        ),
        Text(
          value,
          style: fontProvider.getTextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoricalGraph(
    Envelope envelope,
    List<Transaction> transactions,
    ThemeData theme,
    FontProvider fontProvider,
    LocaleProvider locale,
  ) {
    // Filter out future transactions and sort by date
    final realTransactions = transactions
        .where((tx) => !tx.isFuture)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (realTransactions.isEmpty) {
      return const SizedBox.shrink();
    }

    // Calculate balance over time
    final spots = <FlSpot>[];
    double runningBalance = 0;

    for (var i = 0; i < realTransactions.length; i++) {
      final tx = realTransactions[i];

      // Calculate balance change
      if (tx.type == TransactionType.deposit) {
        runningBalance += tx.amount;
      } else if (tx.type == TransactionType.withdrawal) {
        runningBalance -= tx.amount;
      } else if (tx.type == TransactionType.transfer) {
        if (tx.transferDirection == TransferDirection.in_) {
          runningBalance += tx.amount;
        } else {
          runningBalance -= tx.amount;
        }
      }

      // Convert date to x-axis value (days since first transaction)
      final daysSinceStart =
          tx.date.difference(realTransactions.first.date).inDays.toDouble();
      spots.add(FlSpot(daysSinceStart, runningBalance));
    }

    // Add current balance as final point if needed
    if (spots.isNotEmpty && spots.last.y != envelope.currentAmount) {
      final daysSinceStart = DateTime.now()
          .difference(realTransactions.first.date)
          .inDays
          .toDouble();
      spots.add(FlSpot(daysSinceStart, envelope.currentAmount));
    }

    // Create target line if amount target exists
    List<FlSpot>? targetSpots;
    if (envelope.targetAmount != null && spots.isNotEmpty) {
      targetSpots = [
        FlSpot(spots.first.x, envelope.targetAmount!),
        FlSpot(spots.last.x, envelope.targetAmount!),
      ];
    }

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
                  Icons.show_chart,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Progress Over Time',
                  style: fontProvider.getTextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: envelope.targetAmount != null
                        ? envelope.targetAmount! / 4
                        : null,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: theme.colorScheme.outline.withAlpha(51),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 60,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            locale.formatCurrency(value),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final date = realTransactions.first.date
                              .add(Duration(days: value.toInt()));
                          return Text(
                            DateFormat('MMM dd').format(date),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    // Main balance line
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: theme.colorScheme.primary,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: theme.colorScheme.primary.withAlpha(51),
                      ),
                    ),
                    // Target line
                    if (targetSpots != null)
                      LineChartBarData(
                        spots: targetSpots,
                        isCurved: false,
                        color: theme.brightness == Brightness.dark
                            ? Colors.green.shade400
                            : Colors.green.shade600,
                        barWidth: 2,
                        dashArray: [5, 5],
                        dotData: const FlDotData(show: false),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Balance', theme.colorScheme.primary),
                if (envelope.targetAmount != null) ...[
                  const SizedBox(width: 24),
                  _buildLegendItem(
                    'Target',
                    theme.brightness == Brightness.dark
                        ? Colors.green.shade400
                        : Colors.green.shade600,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 3,
          color: color,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildQuickActions(
    Envelope envelope,
    ThemeData theme,
    FontProvider fontProvider,
  ) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            icon: const Icon(Icons.add),
            label: Text(
              'Add Money',
              style: fontProvider.getTextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => Container(
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: DepositModal(
                    repo: widget.envelopeRepo,
                    envelopeId: envelope.id,
                    envelopeName: envelope.name,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
