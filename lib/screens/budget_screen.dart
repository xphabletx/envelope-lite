// lib/screens/budget_screen.dart
// FONT PROVIDER INTEGRATED: All GoogleFonts.caveat() replaced with FontProvider
// All button text wrapped in FittedBox to prevent wrapping

import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // NEW IMPORT
// Kept as requested
import 'package:intl/intl.dart';
import '../models/envelope.dart';
import '../models/transaction.dart';
import '../services/envelope_repo.dart';
import '../services/localization_service.dart';
import '../providers/font_provider.dart'; // NEW IMPORT

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key, required this.repo});

  final EnvelopeRepo repo;

  Map<String, double> _calculateMonthlyStats(List<Transaction> transactions) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    double deposits = 0;
    double withdrawals = 0;
    double transfers = 0;

    for (final tx in transactions) {
      if (tx.date.isAfter(monthStart)) {
        if (tx.type == TransactionType.deposit) {
          deposits += tx.amount;
        } else if (tx.type == TransactionType.withdrawal) {
          withdrawals += tx.amount;
        } else if (tx.type == TransactionType.transfer) {
          transfers += tx.amount;
        }
      }
    }

    return {
      'deposits': deposits,
      'withdrawals': withdrawals,
      'transfers': transfers,
      'netChange': deposits - withdrawals,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormatter = NumberFormat.currency(symbol: '£');
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return StreamBuilder<List<Envelope>>(
      stream: repo.envelopesStream(),
      builder: (context, envSnapshot) {
        final envelopes = envSnapshot.data ?? [];

        return StreamBuilder<List<Transaction>>(
          stream: repo.transactionsStream,
          builder: (context, txSnapshot) {
            final transactions = txSnapshot.data ?? [];
            final monthlyStats = _calculateMonthlyStats(transactions);

            // Calculate totals
            final totalSaved = envelopes.fold<double>(
              0.0,
              (sum, e) => sum + e.currentAmount,
            );

            final totalTarget = envelopes.fold<double>(
              0.0,
              (sum, e) => sum + (e.targetAmount ?? 0.0),
            );

            final percentToTarget = totalTarget > 0
                ? (totalSaved / totalTarget * 100).clamp(0, 100)
                : 0.0;

            final envelopesWithTargets = envelopes
                .where((e) => e.targetAmount != null && e.targetAmount! > 0)
                .toList();

            final fullyFundedCount = envelopesWithTargets
                .where((e) => e.currentAmount >= e.targetAmount!)
                .length;

            return Scaffold(
              backgroundColor: theme.scaffoldBackgroundColor,
              appBar: AppBar(
                backgroundColor: theme.scaffoldBackgroundColor,
                elevation: 0,
                title: Text(
                  tr('budget_overview_title'),
                  // UPDATED: FontProvider
                  style: fontProvider.getTextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Total Saved Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.secondary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withAlpha(77),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('budget_total_saved'),
                            // UPDATED: FontProvider
                            style: fontProvider.getTextStyle(
                              fontSize: 24,
                              color: Colors.white.withAlpha(230),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            currencyFormatter.format(totalSaved),
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Text(
                                '${tr('budget_target')}: ${currencyFormatter.format(totalTarget)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white.withAlpha(204),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(51),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${percentToTarget.toInt()}%',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // This Month Stats
                    Text(
                      tr('budget_this_month'),
                      // UPDATED: FontProvider
                      style: fontProvider.getTextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: tr('budget_income'),
                            amount: monthlyStats['deposits']!,
                            color: Colors.green,
                            icon: Icons.arrow_downward,
                            formatter: currencyFormatter,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            title: tr('budget_spent'),
                            amount: monthlyStats['withdrawals']!,
                            color: Colors.red,
                            icon: Icons.arrow_upward,
                            formatter: currencyFormatter,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: monthlyStats['netChange']! >= 0
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: monthlyStats['netChange']! >= 0
                              ? Colors.green.shade300
                              : Colors.red.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            tr('budget_net_change'),
                            // UPDATED: FontProvider
                            style: fontProvider.getTextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: monthlyStats['netChange']! >= 0
                                  ? Colors.green.shade800
                                  : Colors.red.shade800,
                            ),
                          ),
                          Text(
                            currencyFormatter.format(
                              monthlyStats['netChange']!.abs(),
                            ),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: monthlyStats['netChange']! >= 0
                                  ? Colors.green.shade800
                                  : Colors.red.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Envelope Progress
                    Text(
                      tr('budget_envelope_progress'),
                      // UPDATED: FontProvider
                      style: fontProvider.getTextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _ProgressRow(
                            label: tr('budget_total_envelopes'),
                            value: '${envelopes.length}',
                            theme: theme,
                          ),
                          const Divider(height: 24),
                          _ProgressRow(
                            label: tr('budget_with_targets'),
                            value: '${envelopesWithTargets.length}',
                            theme: theme,
                          ),
                          const Divider(height: 24),
                          _ProgressRow(
                            label: tr('budget_fully_funded'),
                            value: '$fullyFundedCount',
                            theme: theme,
                            valueColor: Colors.green.shade700,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Top Envelopes by Balance
                    Text(
                      tr('budget_top_envelopes'),
                      // UPDATED: FontProvider
                      style: fontProvider.getTextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children:
                            (envelopes.toList()..sort(
                                  (a, b) => b.currentAmount.compareTo(
                                    a.currentAmount,
                                  ),
                                ))
                                .take(5)
                                .map((envelope) {
                                  return ListTile(
                                    leading: Text(
                                      envelope.emoji ?? '📨',
                                      style: const TextStyle(fontSize: 32),
                                    ),
                                    title: Text(
                                      envelope.name,
                                      // UPDATED: FontProvider
                                      style: fontProvider.getTextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    trailing: Text(
                                      currencyFormatter.format(
                                        envelope.currentAmount,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                })
                                .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.amount,
    required this.color,
    required this.icon,
    required this.formatter,
  });

  final String title;
  final double amount;
  final Color color;
  final IconData icon;
  final NumberFormat formatter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                // UPDATED: FontProvider
                style: fontProvider.getTextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            formatter.format(amount),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.value,
    required this.theme,
    this.valueColor,
  });

  final String label;
  final String value;
  final ThemeData theme;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 16)),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: valueColor ?? theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
