// lib/widgets/budget/overview_cards.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/account.dart';
import '../../models/envelope.dart';
import '../../models/transaction.dart';
import '../../models/scheduled_payment.dart';
import '../../services/account_repo.dart';
import '../../services/envelope_repo.dart';
import '../../services/group_repo.dart';
import '../../services/scheduled_payment_repo.dart';
import '../../providers/font_provider.dart';
import '../../screens/stats_history_screen.dart';

import '../../screens/accounts/account_list_screen.dart';
import 'scheduled_payments_list_screen.dart';
import 'auto_fill_list_screen.dart'; // NEW import

class BudgetOverviewCards extends StatefulWidget {
  const BudgetOverviewCards({
    super.key,
    required this.accountRepo,
    required this.envelopeRepo,
    required this.paymentRepo,
  });

  final AccountRepo accountRepo;
  final EnvelopeRepo envelopeRepo;
  final ScheduledPaymentRepo paymentRepo;

  @override
  State<BudgetOverviewCards> createState() => _BudgetOverviewCardsState();
}

class _BudgetOverviewCardsState extends State<BudgetOverviewCards> {
  // Historical range for Income/Spending only
  DateTime _historyStart = DateTime.now().subtract(const Duration(days: 30));
  DateTime _historyEnd = DateTime.now();

  final PageController _pageController = PageController(viewportFraction: 0.85);
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      final page = _pageController.page?.round() ?? 0;
      if (page != _currentPage) {
        setState(() => _currentPage = page);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _selectHistoryRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _historyStart, end: _historyEnd),
      helpText: 'Select History Range',
    );
    if (picked != null) {
      setState(() {
        _historyStart = picked.start;
        _historyEnd = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    // Hardcoded range for Scheduled Payments projection
    final futureStart = DateTime.now();
    final futureEnd = DateTime.now().add(const Duration(days: 30));

    return Column(
      children: [
        // Date range header (Explicitly labeled History)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.history, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'History: ${_formatDateRange()}',
                  style: fontProvider.getTextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _selectHistoryRange,
                icon: const Icon(Icons.edit_calendar, size: 16),
                label: Text(
                  'Change',
                  style: fontProvider.getTextStyle(fontSize: 14),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(60, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),

        // Cards PageView
        SizedBox(
          height: 200,
          child: StreamBuilder<List<Account>>(
            stream: widget.accountRepo.accountsStream(),
            builder: (context, accountSnapshot) {
              return StreamBuilder<List<Envelope>>(
                stream: widget.envelopeRepo.envelopesStream(),
                builder: (context, envelopeSnapshot) {
                  return StreamBuilder<List<Transaction>>(
                    stream: widget.envelopeRepo.transactionsStream,
                    builder: (context, txSnapshot) {
                      return StreamBuilder<List<ScheduledPayment>>(
                        stream: widget.paymentRepo.scheduledPaymentsStream,
                        builder: (context, paymentSnapshot) {
                          // Handle loading states gracefully
                          final accounts = accountSnapshot.data ?? [];
                          final envelopes = envelopeSnapshot.data ?? [];
                          final allTx = txSnapshot.data ?? [];
                          final scheduledPayments = paymentSnapshot.data ?? [];

                          // Filter transactions in HISTORY range
                          final txInRange = allTx.where((tx) {
                            return tx.date.isAfter(
                                  _historyStart.subtract(
                                    const Duration(seconds: 1),
                                  ),
                                ) &&
                                tx.date.isBefore(
                                  _historyEnd.add(const Duration(days: 1)),
                                );
                          }).toList();

                          return PageView(
                            controller: _pageController,
                            children: [
                              _buildAccountsCard(accounts),
                              _buildIncomeCard(txInRange),
                              _buildSpendingCard(txInRange),
                              // Use FUTURE range for Scheduled Payments
                              _buildScheduledPaymentsCard(
                                scheduledPayments,
                                futureStart,
                                futureEnd,
                              ),
                              _buildAutoFillCard(envelopes),
                              _buildTopEnvelopesCard(envelopes),
                            ],
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

        // Page indicator
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (index) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentPage == index
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            );
          }),
        ),
      ],
    );
  }

  String _formatDateRange() {
    final format = DateFormat('MMM d');
    if (_historyStart.year == _historyEnd.year &&
        _historyStart.month == _historyEnd.month &&
        _historyStart.day == _historyEnd.day) {
      return format.format(_historyStart);
    }
    return '${format.format(_historyStart)} - ${format.format(_historyEnd)}';
  }

  // 1. Total Balance -> Links to AccountListScreen
  Widget _buildAccountsCard(List<Account> accounts) {
    final theme = Theme.of(context);
    final currency = NumberFormat.currency(symbol: '£');

    final totalBalance = accounts.fold(
      0.0,
      (sum, acc) => sum + acc.currentBalance,
    );

    return _OverviewCard(
      icon: Icons.account_balance_wallet,
      title: 'Total Balance',
      value: currency.format(totalBalance),
      subtitle: '${accounts.length} account${accounts.length != 1 ? 's' : ''}',
      color: theme.colorScheme.primary,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                AccountListScreen(envelopeRepo: widget.envelopeRepo),
          ),
        );
      },
    );
  }

  // 2. Income -> Links to StatsHistoryScreen
  Widget _buildIncomeCard(List<Transaction> transactions) {
    final currency = NumberFormat.currency(symbol: '£');

    final income = transactions
        .where((tx) => tx.type == TransactionType.deposit)
        .fold(0.0, (sum, tx) => sum + tx.amount);

    return _OverviewCard(
      icon: Icons.arrow_downward,
      title: 'Income',
      value: currency.format(income),
      subtitle: 'In selected history range',
      color: Colors.green,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StatsHistoryScreen(
              repo: widget.envelopeRepo,
              title: 'Income & History',
              initialStart: _historyStart,
              initialEnd: _historyEnd,
            ),
          ),
        );
      },
    );
  }

  // 3. Spending -> Links to StatsHistoryScreen
  Widget _buildSpendingCard(List<Transaction> transactions) {
    final currency = NumberFormat.currency(symbol: '£');

    final spending = transactions
        .where((tx) => tx.type == TransactionType.withdrawal)
        .fold(0.0, (sum, tx) => sum + tx.amount);

    return _OverviewCard(
      icon: Icons.arrow_upward,
      title: 'Spending',
      value: currency.format(spending),
      subtitle: 'In selected history range',
      color: Colors.red,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StatsHistoryScreen(
              repo: widget.envelopeRepo,
              title: 'Spending & History',
              initialStart: _historyStart,
              initialEnd: _historyEnd,
            ),
          ),
        );
      },
    );
  }

  // 4. Scheduled -> Links to ScheduledPaymentsListScreen
  // Calculates total for NEXT 30 DAYS
  Widget _buildScheduledPaymentsCard(
    List<ScheduledPayment> payments,
    DateTime start,
    DateTime end,
  ) {
    final theme = Theme.of(context);
    final currency = NumberFormat.currency(symbol: '£');

    double total = 0.0;
    int occurrenceCount = 0;

    for (final payment in payments) {
      DateTime cursor = payment.nextDueDate;

      int safety = 0;
      while (cursor.isBefore(end.add(const Duration(days: 1))) &&
          safety < 100) {
        if (!cursor.isBefore(start)) {
          total += payment.amount;
          occurrenceCount++;
        }

        switch (payment.frequencyUnit) {
          case PaymentFrequencyUnit.days:
            cursor = cursor.add(Duration(days: payment.frequencyValue));
            break;
          case PaymentFrequencyUnit.weeks:
            cursor = cursor.add(Duration(days: payment.frequencyValue * 7));
            break;
          case PaymentFrequencyUnit.months:
            cursor = DateTime(
              cursor.year,
              cursor.month + payment.frequencyValue,
              cursor.day,
            );
            break;
          case PaymentFrequencyUnit.years:
            cursor = DateTime(
              cursor.year + payment.frequencyValue,
              cursor.month,
              cursor.day,
            );
            break;
        }
        safety++;
      }
    }

    return _OverviewCard(
      icon: Icons.calendar_month,
      title: 'Scheduled',
      value: currency.format(total),
      subtitle: 'Next 30 Days ($occurrenceCount payments)',
      color: theme.colorScheme.secondary,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ScheduledPaymentsListScreen(
              paymentRepo: widget.paymentRepo,
              envelopeRepo: widget.envelopeRepo,
            ),
          ),
        );
      },
    );
  }

  // 5. Auto-Fill -> Links to AutoFillListScreen
  Widget _buildAutoFillCard(List<Envelope> envelopes) {
    final currency = NumberFormat.currency(symbol: '£');

    final autoFillTotal = envelopes
        .where((e) => e.autoFillEnabled && e.autoFillAmount != null)
        .fold(0.0, (sum, e) => sum + e.autoFillAmount!);

    final count = envelopes.where((e) => e.autoFillEnabled).length;

    return _OverviewCard(
      icon: Icons.autorenew,
      title: 'Auto-Fill',
      value: currency.format(autoFillTotal),
      subtitle: '$count active envelopes',
      color: Colors.purple,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AutoFillListScreen(
              envelopeRepo: widget.envelopeRepo,
              // Instantiate required repos
              groupRepo: GroupRepo(widget.envelopeRepo.db, widget.envelopeRepo),
              accountRepo: AccountRepo(
                widget.envelopeRepo.db,
                widget.envelopeRepo,
              ),
            ),
          ),
        );
      },
    );
  }

  // 6. Top Envelopes -> No specific link
  Widget _buildTopEnvelopesCard(List<Envelope> envelopes) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    final sorted = [...envelopes]
      ..sort((a, b) => b.currentAmount.compareTo(a.currentAmount));
    final top3 = sorted.take(3).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 24),
              const SizedBox(width: 8),
              Text(
                'Top Envelopes',
                style: fontProvider.getTextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (top3.isEmpty)
            Text(
              'No envelopes yet',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            )
          else
            ...top3.map(
              (env) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text(
                      env.emoji ?? '📨',
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        env.name,
                        style: fontProvider.getTextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      NumberFormat.currency(
                        symbol: '£',
                      ).format(env.currentAmount),
                      style: fontProvider.getTextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Reusable card widget with interaction
class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      elevation: 0,
      color: color.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: color),
              const SizedBox(height: 12),
              Text(
                title,
                style: fontProvider.getTextStyle(
                  fontSize: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: fontProvider.getTextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward,
                      size: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
