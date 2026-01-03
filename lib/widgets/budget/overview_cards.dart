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
import '../../providers/locale_provider.dart';
import '../../providers/time_machine_provider.dart';
import '../../screens/stats_history_screen.dart';
import 'scheduled_payments_list_screen.dart';
import 'auto_fill_list_screen.dart';
import '../../screens/envelope/multi_target_screen.dart';
import '../../utils/responsive_helper.dart';

class BudgetOverviewCards extends StatefulWidget {
  const BudgetOverviewCards({
    super.key,
    required this.accountRepo,
    required this.envelopeRepo,
    required this.paymentRepo,
    this.useVerticalLayout = false,
  });

  final AccountRepo accountRepo;
  final EnvelopeRepo envelopeRepo;
  final ScheduledPaymentRepo paymentRepo;
  final bool useVerticalLayout; // If true, displays cards vertically instead of horizontal PageView

  @override
  State<BudgetOverviewCards> createState() => _BudgetOverviewCardsState();
}

class _BudgetOverviewCardsState extends State<BudgetOverviewCards> {
  // User-selected custom range (if any)
  DateTime? _userSelectedStart;
  DateTime? _userSelectedEnd;

  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
    _pageController.addListener(() {
      final page = _pageController.page?.round() ?? 0;
      if (page != _currentPage) {
        setState(() => _currentPage = page);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Update viewport fraction based on screen size
    final responsive = context.responsive;
    final isLandscape = responsive.isLandscape;
    final isTablet = responsive.isTablet;

    // Calculate optimal viewport fraction
    final newViewportFraction = (isTablet && isLandscape) ? 0.4
        : (isLandscape || isTablet) ? 0.6
        : 0.85;

    // Recreate controller if viewport fraction changed significantly
    if ((_pageController.viewportFraction - newViewportFraction).abs() > 0.1) {
      final currentPage = _pageController.hasClients ? (_pageController.page ?? 0) : 0;
      _pageController.dispose();
      _pageController = PageController(
        viewportFraction: newViewportFraction,
        initialPage: currentPage.round(),
      );
      _pageController.addListener(() {
        final page = _pageController.page?.round() ?? 0;
        if (page != _currentPage) {
          setState(() => _currentPage = page);
        }
      });
    }
  }

  // Calculate history range based on time machine state
  DateTimeRange _getHistoryRange(TimeMachineProvider timeMachine) {
    // If user selected a custom range, use it
    if (_userSelectedStart != null && _userSelectedEnd != null) {
      return DateTimeRange(start: _userSelectedStart!, end: _userSelectedEnd!);
    }

    // Otherwise, calculate based on time machine state
    if (timeMachine.isActive && timeMachine.futureDate != null) {
      // Time Machine: 30 days before target date
      final targetDate = timeMachine.futureDate!;
      return DateTimeRange(
        start: targetDate.subtract(const Duration(days: 30)),
        end: targetDate,
      );
    } else {
      // Normal: last 30 days from now
      final now = DateTime.now();
      return DateTimeRange(
        start: now.subtract(const Duration(days: 30)),
        end: now,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _selectHistoryRange(TimeMachineProvider timeMachine) async {
    final currentRange = _getHistoryRange(timeMachine);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: currentRange,
      helpText: 'Select History Range',
    );
    if (picked != null) {
      setState(() {
        _userSelectedStart = picked.start;
        _userSelectedEnd = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return Consumer<TimeMachineProvider>(
      builder: (context, timeMachine, _) {
        // Get dynamic history range based on time machine state
        final historyRange = _getHistoryRange(timeMachine);
        final historyStart = historyRange.start;
        final historyEnd = historyRange.end;

        // Calculate future range for Scheduled Payments
        // In time machine: show 30 days INTO THE FUTURE from target date
        // Outside time machine: show next 30 days from now
        final futureStart = timeMachine.isActive && timeMachine.futureDate != null
            ? timeMachine.futureDate!
            : DateTime.now();
        final futureEnd = timeMachine.isActive && timeMachine.futureDate != null
            ? timeMachine.futureDate!.add(const Duration(days: 30))
            : DateTime.now().add(const Duration(days: 30));

        return Column(
          children: [
            // Date range header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.history, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'History: ${_formatDateRange(historyStart, historyEnd)}',
                      style: fontProvider.getTextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _selectHistoryRange(timeMachine),
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

            // Cards PageView or Column
            widget.useVerticalLayout
                ? StreamBuilder<List<Account>>(
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
                                  var accounts = accountSnapshot.data ?? [];
                                  final envelopes = envelopeSnapshot.data ?? [];
                                  var allTx = txSnapshot.data ?? [];
                                  final scheduledPayments = paymentSnapshot.data ?? [];

                                  // Merge with projected data if time machine is active
                                  if (timeMachine.isActive) {
                                    // Get projected transactions
                                    final projectedTx = timeMachine.getProjectedTransactionsForDateRange(
                                      historyStart,
                                      historyEnd,
                                      includeTransfers: true,
                                    );
                                    allTx = [...allTx, ...projectedTx];

                                    // Transform accounts to use projected balances
                                    accounts = accounts.map((account) {
                                      return timeMachine.getProjectedAccount(account);
                                    }).toList();
                                  }

                                  // Filter transactions in HISTORY range
                                  final txInRange = allTx.where((tx) {
                                    return tx.date.isAfter(
                                          historyStart.subtract(
                                            const Duration(seconds: 1),
                                          ),
                                        ) &&
                                        tx.date.isBefore(
                                          historyEnd.add(const Duration(days: 1)),
                                        );
                                  }).toList();

                                  // Vertical layout - all cards stacked
                                  return Column(
                                    children: [
                                      _buildTargetCard(envelopes),
                                      const SizedBox(height: 12),
                                      _buildAccountsCard(accounts),
                                      const SizedBox(height: 12),
                                      _buildIncomeCard(txInRange, historyStart, historyEnd),
                                      const SizedBox(height: 12),
                                      _buildSpendingCard(txInRange, historyStart, historyEnd),
                                      const SizedBox(height: 12),
                                      // Use FUTURE range for Scheduled Payments
                                      _buildScheduledPaymentsCard(
                                        scheduledPayments,
                                        futureStart,
                                        futureEnd,
                                      ),
                                      const SizedBox(height: 12),
                                      _buildAutoFillCard(envelopes),
                                      const SizedBox(height: 12),
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
                  )
                : SizedBox(
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
                                    var accounts = accountSnapshot.data ?? [];
                                    final envelopes = envelopeSnapshot.data ?? [];
                                    var allTx = txSnapshot.data ?? [];
                                    final scheduledPayments = paymentSnapshot.data ?? [];

                                    // Merge with projected data if time machine is active
                                    if (timeMachine.isActive) {
                                      // Get projected transactions
                                      final projectedTx = timeMachine.getProjectedTransactionsForDateRange(
                                        historyStart,
                                        historyEnd,
                                        includeTransfers: true,
                                      );
                                      allTx = [...allTx, ...projectedTx];

                                      // Transform accounts to use projected balances
                                      accounts = accounts.map((account) {
                                        return timeMachine.getProjectedAccount(account);
                                      }).toList();
                                    }

                                    // Filter transactions in HISTORY range
                                    final txInRange = allTx.where((tx) {
                                      return tx.date.isAfter(
                                            historyStart.subtract(
                                              const Duration(seconds: 1),
                                            ),
                                          ) &&
                                          tx.date.isBefore(
                                            historyEnd.add(const Duration(days: 1)),
                                          );
                                    }).toList();

                                    return PageView(
                                      controller: _pageController,
                                      children: [
                                        _buildTargetCard(envelopes),
                                        _buildAccountsCard(accounts),
                                        _buildIncomeCard(txInRange, historyStart, historyEnd),
                                        _buildSpendingCard(txInRange, historyStart, historyEnd),
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

            // Page indicator (only for horizontal PageView)
            if (!widget.useVerticalLayout) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(7, (index) {
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
          ],
        );
      },
    );
  }

  String _formatDateRange(DateTime start, DateTime end) {
    final format = DateFormat('MMM d');
    if (start.year == end.year &&
        start.month == end.month &&
        start.day == end.day) {
      return format.format(start);
    }
    return '${format.format(start)} - ${format.format(end)}';
  }

  // 0. Target Data Card -> Links to MultiTargetScreen
  Widget _buildTargetCard(List<Envelope> envelopes) {
    final theme = Theme.of(context);

    final targetEnvelopes = envelopes.where((e) => e.targetAmount != null && e.targetAmount! > 0).toList();
    final targetCount = targetEnvelopes.length;

    return _OverviewCard(
      icon: Icons.track_changes,
      title: 'Total Target Data',
      value: targetCount.toString(),
      subtitle: targetCount == 1 ? 'Target' : 'Targets',
      color: theme.colorScheme.tertiary,
      onTap: targetCount > 0
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MultiTargetScreen(
                    envelopeRepo: widget.envelopeRepo,
                    groupRepo: GroupRepo(widget.envelopeRepo),
                    accountRepo: widget.accountRepo,
                    mode: TargetScreenMode.multiEnvelope,
                  ),
                ),
              );
            }
          : null,
    );
  }

  // 1. Total Balance -> Links to StatsHistoryScreen showing account-level transactions
  Widget _buildAccountsCard(List<Account> accounts) {
    final theme = Theme.of(context);
    final locale = Provider.of<LocaleProvider>(context, listen: false);
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);
    final timeMachine = Provider.of<TimeMachineProvider>(context, listen: false);

    final totalBalance = accounts.fold(
      0.0,
      (sum, acc) => sum + acc.currentBalance,
    );

    return _OverviewCard(
      icon: Icons.account_balance_wallet,
      title: 'Total Accounts Balance',
      value: currency.format(totalBalance),
      subtitle: '${accounts.length} account${accounts.length != 1 ? 's' : ''}',
      color: theme.colorScheme.primary,
      onTap: () {
        // Navigate to stats with entry → target date range
        // Show account-level transactions: pay day deposits, auto-fills (withdrawals), and transfers
        DateTime? initialStart;
        DateTime? initialEnd;

        if (timeMachine.isActive && timeMachine.entryDate != null && timeMachine.futureDate != null) {
          initialStart = timeMachine.entryDate!;
          initialEnd = timeMachine.futureDate!;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StatsHistoryScreen(
              repo: widget.envelopeRepo,
              title: 'Accounts Balance & History',
              initialStart: initialStart,
              initialEnd: initialEnd,
              // Filter to show account-level transactions only:
              // - Deposits with no envelope (pay day to account)
              // - Withdrawals with no envelope (auto-fills from account)
              // - Transfers (account-to-account)
              filterTransactionTypes: {
                TransactionType.deposit,
                TransactionType.withdrawal,
                TransactionType.transfer,
              },
            ),
          ),
        );
      },
    );
  }

  // 2. Income -> Links to StatsHistoryScreen
  Widget _buildIncomeCard(List<Transaction> transactions, DateTime historyStart, DateTime historyEnd) {
    final locale = Provider.of<LocaleProvider>(context, listen: false);
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);

    final income = transactions
        .where((tx) => tx.type == TransactionType.deposit)
        .fold(0.0, (sum, tx) => sum + tx.amount);

    return _OverviewCard(
      icon: Icons.arrow_downward,
      title: 'Total Envelope Income',
      value: currency.format(income),
      subtitle: 'In selected history range',
      color: Colors.green,
      onTap: () {
        debugPrint('[TimeMachine::OverviewCards] ========================================');
        debugPrint('[TimeMachine::OverviewCards] Income card tapped!');
        debugPrint('[TimeMachine::OverviewCards] Navigating to Stats & History');
        debugPrint('[TimeMachine::OverviewCards] Will use entry → target date in time machine mode');
        debugPrint('[TimeMachine::OverviewCards] ========================================');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StatsHistoryScreen(
              repo: widget.envelopeRepo,
              title: 'Envelope Income & History',
              // Don't pass explicit dates - let screen use entry → target date in time machine
              filterTransactionTypes: {TransactionType.deposit},
            ),
          ),
        );
      },
    );
  }

  // 3. Spending -> Links to StatsHistoryScreen
  Widget _buildSpendingCard(List<Transaction> transactions, DateTime historyStart, DateTime historyEnd) {
    final locale = Provider.of<LocaleProvider>(context, listen: false);
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);

    // Include both withdrawals and scheduled payments
    final spending = transactions
        .where((tx) => tx.type == TransactionType.withdrawal || tx.type == TransactionType.scheduledPayment)
        .fold(0.0, (sum, tx) => sum + tx.amount);

    return _OverviewCard(
      icon: Icons.arrow_upward,
      title: 'Total Envelope Spending',
      value: currency.format(spending),
      subtitle: 'In selected history range',
      color: Colors.red,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StatsHistoryScreen(
              repo: widget.envelopeRepo,
              title: 'Envelope Spending & History',
              // Don't pass explicit dates - let screen use entry → target date in time machine
              filterTransactionTypes: {TransactionType.withdrawal, TransactionType.scheduledPayment},
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
    final locale = Provider.of<LocaleProvider>(context, listen: false);
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);

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
              futureStart: start,
              futureEnd: end,
            ),
          ),
        );
      },
    );
  }

  // 5. Auto-Fill -> Links to AutoFillListScreen
  Widget _buildAutoFillCard(List<Envelope> envelopes) {
    final locale = Provider.of<LocaleProvider>(context, listen: false);
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);

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
              groupRepo: GroupRepo(widget.envelopeRepo),
              accountRepo: AccountRepo(widget.envelopeRepo),
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
                    Consumer<LocaleProvider>(
                      builder: (context, locale, _) => Text(
                        NumberFormat.currency(
                          symbol: locale.currencySymbol,
                        ).format(env.currentAmount),
                        style: fontProvider.getTextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 36, color: color),
              const SizedBox(height: 12),
              Text(
                title,
                style: fontProvider.getTextStyle(
                  fontSize: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: fontProvider.getTextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
