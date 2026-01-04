// lib/screens/stats_history_screen_v2.dart
// REFACTORED with "Virtual Ledger" philosophy: External vs Internal transactions
// UI redesign: Data first, filters collapsible

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/envelope.dart';
import '../models/envelope_group.dart';
import '../models/transaction.dart';
import '../models/account.dart';
import '../services/envelope_repo.dart';
import '../services/account_repo.dart';
import '../providers/font_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/time_machine_provider.dart';
import '../widgets/time_machine_indicator.dart';
import '../widgets/analytics/analytics_section.dart';

/// Categories for the new "Virtual Ledger" philosophy
enum TransactionCategory {
  externalIncome,    // Money entering the system (affects net worth)
  externalSpending,  // Money leaving the system (affects net worth)
  internalAllocation // Money moving between accounts/envelopes (net zero)
}

class StatsHistoryScreenV2 extends StatefulWidget {
  const StatsHistoryScreenV2({
    super.key,
    required this.repo,
    this.initialEnvelopeIds,
    this.initialGroupIds,
    this.initialStart,
    this.initialEnd,
    this.title,
  });

  final EnvelopeRepo repo;
  final Set<String>? initialEnvelopeIds;
  final Set<String>? initialGroupIds;
  final DateTime? initialStart;
  final DateTime? initialEnd;
  final String? title;

  @override
  State<StatsHistoryScreenV2> createState() => _StatsHistoryScreenV2State();
}

class _StatsHistoryScreenV2State extends State<StatsHistoryScreenV2> {
  late DateTime start;
  late DateTime end;
  bool _filtersExpanded = false;

  @override
  void initState() {
    super.initState();

    final timeMachine = Provider.of<TimeMachineProvider>(context, listen: false);

    if (widget.initialStart != null && widget.initialEnd != null) {
      start = widget.initialStart!;
      end = DateTime(
        widget.initialEnd!.year,
        widget.initialEnd!.month,
        widget.initialEnd!.day,
        23, 59, 59, 999,
      );
    } else if (timeMachine.isActive && timeMachine.entryDate != null && timeMachine.futureDate != null) {
      start = timeMachine.entryDate!;
      final targetDate = timeMachine.futureDate!;
      end = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59, 999);
    } else {
      start = DateTime.now().subtract(const Duration(days: 30));
      final defaultEnd = DateTime.now();
      end = DateTime(defaultEnd.year, defaultEnd.month, defaultEnd.day, 23, 59, 59, 999);
    }
  }

  Future<void> _pickRange() async {
    final timeMachine = Provider.of<TimeMachineProvider>(context, listen: false);
    DateTime effectiveLastDate = DateTime.now().add(const Duration(days: 365));

    if (timeMachine.isActive && timeMachine.futureDate != null) {
      effectiveLastDate = timeMachine.futureDate!;
    }

    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: effectiveLastDate,
      initialDateRange: DateTimeRange(start: start, end: end),
    );

    if (r != null) {
      setState(() {
        start = DateTime(r.start.year, r.start.month, r.start.day);
        end = DateTime(r.end.year, r.end.month, r.end.day, 23, 59, 59, 999);
      });
    }
  }

  /// Categorize a transaction based on Virtual Ledger philosophy
  TransactionCategory _categorizeTransaction(Transaction t, List<Account> accounts) {
    // External Income: Deposits to Default Account with "PAY DAY!" description
    if (t.type == TransactionType.deposit &&
        t.envelopeId.isEmpty &&
        t.description == 'PAY DAY!') {
      return TransactionCategory.externalIncome;
    }

    // External Spending: Withdrawals and Scheduled Payments from Envelopes
    if ((t.type == TransactionType.withdrawal || t.type == TransactionType.scheduledPayment) &&
        t.envelopeId.isNotEmpty) {
      return TransactionCategory.externalSpending;
    }

    // Everything else is Internal Allocation:
    // - Auto-fills (deposits to envelopes, withdrawals from default account)
    // - Transfers (envelope-to-envelope, account-to-account)
    return TransactionCategory.internalAllocation;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);
    final title = widget.title ?? 'Statistics & History';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: fontProvider.getTextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        actions: [
          // Settings/Filter button
          IconButton(
            icon: Icon(
              _filtersExpanded ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: theme.colorScheme.primary,
            ),
            onPressed: () => setState(() => _filtersExpanded = !_filtersExpanded),
            tooltip: 'Filters',
          ),
        ],
      ),
      body: Column(
        children: [
          const TimeMachineIndicator(),

          Expanded(
            child: StreamBuilder<List<Envelope>>(
              initialData: widget.repo.getEnvelopesSync(),
              stream: widget.repo.envelopesStream(),
              builder: (_, sEnv) {
                final envelopes = sEnv.data ?? [];

                return StreamBuilder<List<EnvelopeGroup>>(
                  initialData: widget.repo.getGroupsSync(),
                  stream: widget.repo.groupsStream,
                  builder: (_, sGrp) {
                    final groups = sGrp.data ?? [];
                    final accountRepo = AccountRepo(widget.repo);

                    return StreamBuilder<List<Account>>(
                      initialData: accountRepo.getAccountsSync(),
                      stream: accountRepo.accountsStream(),
                      builder: (_, sAcc) {
                        final accounts = sAcc.data ?? [];

                        return Consumer<TimeMachineProvider>(
                          builder: (context, timeMachine, _) {
                            return StreamBuilder<List<Transaction>>(
                              initialData: widget.repo.getTransactionsSync(),
                              stream: widget.repo.transactionsStream,
                              builder: (_, sTx) {
                                var txs = sTx.data ?? [];

                                // Merge with projected transactions if time machine active
                                if (timeMachine.isActive) {
                                  final projectedTxs = timeMachine.getProjectedTransactionsForDateRange(
                                    start, end, includeTransfers: true,
                                  );
                                  txs = [...txs, ...projectedTxs];
                                }

                                // Filter by date range
                                final filteredTxs = txs.where((t) =>
                                  !t.date.isBefore(start) && t.date.isBefore(end)
                                ).toList();

                                // Categorize transactions
                                double totalIncome = 0;
                                double totalSpending = 0;
                                double totalAllocations = 0;

                                final incomeTxs = <Transaction>[];
                                final spendingTxs = <Transaction>[];
                                final allocationTxs = <Transaction>[];

                                for (final t in filteredTxs) {
                                  final category = _categorizeTransaction(t, accounts);

                                  switch (category) {
                                    case TransactionCategory.externalIncome:
                                      totalIncome += t.amount;
                                      incomeTxs.add(t);
                                      break;
                                    case TransactionCategory.externalSpending:
                                      totalSpending += t.amount;
                                      spendingTxs.add(t);
                                      break;
                                    case TransactionCategory.internalAllocation:
                                      totalAllocations += t.amount.abs();
                                      allocationTxs.add(t);
                                      break;
                                  }
                                }

                                final netSavings = totalIncome - totalSpending;

                                return CustomScrollView(
                                  slivers: [
                                    // FILTERS SECTION (Collapsible)
                                    if (_filtersExpanded)
                                      SliverToBoxAdapter(
                                        child: _FiltersSection(
                                          start: start,
                                          end: end,
                                          onDateTap: _pickRange,
                                          onClose: () => setState(() => _filtersExpanded = false),
                                        ),
                                      ),

                                    const SliverToBoxAdapter(child: SizedBox(height: 16)),

                                    // NET IMPACT CARD (Data First!)
                                    SliverToBoxAdapter(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        child: _NetImpactCard(
                                          income: totalIncome,
                                          spending: totalSpending,
                                          netSavings: netSavings,
                                          allocations: totalAllocations,
                                          start: start,
                                          end: end,
                                        ),
                                      ),
                                    ),

                                    const SliverToBoxAdapter(child: SizedBox(height: 16)),

                                    // ANALYTICS/DONUT CHART
                                    SliverToBoxAdapter(
                                      child: AnalyticsSection(
                                        transactions: filteredTxs,
                                        envelopes: envelopes,
                                        groups: groups,
                                        dateRange: DateTimeRange(start: start, end: end),
                                        timeMachineDate: timeMachine.isActive ? timeMachine.futureDate : null,
                                        onDateRangeChange: (range) {
                                          setState(() {
                                            start = DateTime(range.start.year, range.start.month, range.start.day);
                                            end = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59, 999);
                                          });
                                        },
                                      ),
                                    ),

                                    const SliverToBoxAdapter(child: SizedBox(height: 24)),

                                    // TRANSACTION HISTORY HEADER
                                    SliverToBoxAdapter(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 20),
                                        child: Row(
                                          children: [
                                            Icon(Icons.receipt_long, color: theme.colorScheme.primary, size: 20),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Transaction History',
                                              style: fontProvider.getTextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: theme.colorScheme.primary,
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              '${filteredTxs.length}',
                                              style: fontProvider.getTextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    const SliverToBoxAdapter(child: SizedBox(height: 12)),

                                    // TRANSACTION LIST
                                    if (filteredTxs.isEmpty)
                                      SliverFillRemaining(
                                        hasScrollBody: false,
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.receipt_long_outlined,
                                                size: 64,
                                                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                                              ),
                                              const SizedBox(height: 16),
                                              Text(
                                                'No transactions found',
                                                style: fontProvider.getTextStyle(
                                                  fontSize: 18,
                                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                    else
                                      SliverPadding(
                                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                                        sliver: SliverList(
                                          delegate: SliverChildBuilderDelegate(
                                            (context, index) {
                                              final t = filteredTxs[index];
                                              final category = _categorizeTransaction(t, accounts);

                                              return _TransactionTile(
                                                transaction: t,
                                                category: category,
                                                envelopes: envelopes,
                                                accounts: accounts,
                                              );
                                            },
                                            childCount: filteredTxs.length,
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// FILTERS SECTION (Collapsible)
class _FiltersSection extends StatelessWidget {
  const _FiltersSection({
    required this.start,
    required this.end,
    required this.onDateTap,
    required this.onClose,
  });

  final DateTime start;
  final DateTime end;
  final VoidCallback onDateTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filters',
                style: fontProvider.getTextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Material(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onDateTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: theme.colorScheme.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Date Range',
                            style: fontProvider.getTextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${DateFormat('MMM d').format(start)} - ${DateFormat('MMM d, yyyy').format(end)}',
                            style: fontProvider.getTextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// NET IMPACT CARD (Big, Prominent, Data First!)
class _NetImpactCard extends StatelessWidget {
  const _NetImpactCard({
    required this.income,
    required this.spending,
    required this.netSavings,
    required this.allocations,
    required this.start,
    required this.end,
  });

  final double income;
  final double spending;
  final double netSavings;
  final double allocations;
  final DateTime start;
  final DateTime end;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);
    final locale = Provider.of<LocaleProvider>(context);
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
            theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet, color: theme.colorScheme.primary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Net Impact',
                  style: fontProvider.getTextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${DateFormat('MMM d').format(start)} - ${DateFormat('MMM d, yyyy').format(end)}',
            style: fontProvider.getTextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),

          // Income
          _StatRow(
            icon: Icons.arrow_downward,
            label: 'Income',
            value: currency.format(income),
            color: Colors.green.shade700,
            isLarge: true,
          ),

          const SizedBox(height: 12),

          // Spending
          _StatRow(
            icon: Icons.arrow_upward,
            label: 'Spending',
            value: currency.format(spending),
            color: Colors.red.shade700,
            isLarge: true,
          ),

          const SizedBox(height: 16),
          Divider(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
          const SizedBox(height: 16),

          // Net Savings
          _StatRow(
            icon: netSavings >= 0 ? Icons.trending_up : Icons.trending_down,
            label: 'Net Savings',
            value: currency.format(netSavings),
            color: netSavings >= 0 ? Colors.green.shade900 : Colors.red.shade900,
            isLarge: true,
            isBold: true,
          ),

          const SizedBox(height: 16),
          Divider(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
          const SizedBox(height: 16),

          // Allocations (Internal Moves)
          _StatRow(
            icon: Icons.swap_horiz,
            label: 'Internal Allocations',
            value: currency.format(allocations),
            color: Colors.blue.shade700,
            subtitle: 'Transfers & auto-fills (net zero)',
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.isLarge = false,
    this.isBold = false,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isLarge;
  final bool isBold;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: isLarge ? 24 : 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: fontProvider.getTextStyle(
                  fontSize: isLarge ? 16 : 14,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: fontProvider.getTextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ],
          ),
        ),
        Text(
          value,
          style: fontProvider.getTextStyle(
            fontSize: isLarge ? 20 : 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

// TRANSACTION TILE with clearer descriptions
class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.category,
    required this.envelopes,
    required this.accounts,
  });

  final Transaction transaction;
  final TransactionCategory category;
  final List<Envelope> envelopes;
  final List<Account> accounts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);
    final locale = Provider.of<LocaleProvider>(context);
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);
    final t = transaction;

    // Determine display based on category
    String title;
    String subtitle;
    IconData iconData;
    Color color;
    String amountStr;

    switch (category) {
      case TransactionCategory.externalIncome:
        final defaultAccount = accounts.firstWhere(
          (a) => a.isDefault,
          orElse: () => Account(
            id: '', name: 'Main', currentBalance: 0, userId: '',
            createdAt: DateTime.now(), lastUpdated: DateTime.now(),
          ),
        );
        title = 'Income: Pay Day';
        subtitle = 'Deposited to ${defaultAccount.name}';
        iconData = Icons.arrow_downward;
        color = Colors.green.shade700;
        amountStr = '+${currency.format(t.amount)}';
        break;

      case TransactionCategory.externalSpending:
        final envelope = envelopes.firstWhere(
          (e) => e.id == t.envelopeId,
          orElse: () => Envelope(id: '', name: 'Unknown', userId: ''),
        );

        if (t.type == TransactionType.scheduledPayment) {
          title = 'Spending: ${envelope.name}';
          subtitle = 'Scheduled payment';
        } else {
          title = 'Spending: ${envelope.name}';
          subtitle = 'Manual withdrawal';
        }
        iconData = Icons.arrow_upward;
        color = Colors.red.shade700;
        amountStr = '-${currency.format(t.amount)}';
        break;

      case TransactionCategory.internalAllocation:
        // Parse allocations more intelligently
        if (t.description.contains('Auto-fill deposit from')) {
          final envelope = envelopes.firstWhere(
            (e) => e.id == t.envelopeId,
            orElse: () => Envelope(id: '', name: 'Unknown', userId: ''),
          );
          title = 'Allocation: ${envelope.name}';
          subtitle = 'Auto-filled from default account';
        } else if (t.description.contains('Withdrawal auto-fill')) {
          title = 'Allocation: From Default Account';
          subtitle = t.description;
        } else if (t.type == TransactionType.transfer) {
          title = 'Transfer: ${t.sourceEnvelopeName ?? 'Unknown'} → ${t.targetEnvelopeName ?? 'Unknown'}';
          subtitle = 'Internal move';
        } else {
          title = 'Allocation';
          subtitle = t.description;
        }
        iconData = Icons.swap_horiz;
        color = Colors.blue.shade700;
        amountStr = currency.format(t.amount);
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: fontProvider.getTextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: fontProvider.getTextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amountStr,
                style: fontProvider.getTextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('MMM dd, h:mm a').format(t.date),
                style: fontProvider.getTextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
