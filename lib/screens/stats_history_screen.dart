// lib/screens/stats_history_screen.dart
// COMPLETE REDESIGN - Modern UI with all original functionality

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/envelope.dart';
import '../models/envelope_group.dart';
import '../models/transaction.dart';
import '../models/analytics_data.dart';
import '../models/account.dart';
import '../services/envelope_repo.dart';
import '../services/account_repo.dart';
import '../providers/font_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/time_machine_provider.dart';
import '../widgets/time_machine_indicator.dart';
import '../widgets/analytics/analytics_section.dart';

enum StatsFilterType { envelopes, groups, accounts }

class StatsHistoryScreen extends StatefulWidget {
  const StatsHistoryScreen({
    super.key,
    required this.repo,
    this.initialEnvelopeIds,
    this.initialGroupIds,
    this.initialStart,
    this.initialEnd,
    this.myOnlyDefault = false,
    this.title,
    this.filterTransactionTypes,
  });

  final EnvelopeRepo repo;
  final Set<String>? initialEnvelopeIds;
  final Set<String>? initialGroupIds;
  final DateTime? initialStart;
  final DateTime? initialEnd;
  final bool myOnlyDefault;
  final String? title;
  final Set<TransactionType>? filterTransactionTypes;

  @override
  State<StatsHistoryScreen> createState() => _StatsHistoryScreenState();
}

class _StatsHistoryScreenState extends State<StatsHistoryScreen> {
  late NumberFormat currency;
  final selectedIds = <String>{};
  final activeFilters = <StatsFilterType>{}; // Track which filters are active
  late bool myOnly;
  late DateTime start;
  late DateTime end;
  bool _didApplyExplicitInitialSelection = false;

  @override
  void initState() {
    super.initState();
    myOnly = widget.myOnlyDefault;

    // Initialize dates immediately - check time machine state before first build
    final timeMachine = Provider.of<TimeMachineProvider>(context, listen: false);

    if (widget.initialStart != null && widget.initialEnd != null) {
      // Explicit dates provided (e.g., from Budget Screen cards)
      start = widget.initialStart!;
      final providedEnd = widget.initialEnd!;
      end = DateTime(
        providedEnd.year,
        providedEnd.month,
        providedEnd.day,
        23,
        59,
        59,
        999,
      );
      debugPrint('[TimeMachine::StatsHistoryScreen] Using explicit dates: $start to $end');
    } else if (timeMachine.isActive && timeMachine.entryDate != null && timeMachine.futureDate != null) {
      // Time machine active, no explicit dates - use entry date → target date
      start = timeMachine.entryDate!;
      final targetDate = timeMachine.futureDate!;
      end = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
        23,
        59,
        59,
        999,
      );
      debugPrint('[TimeMachine::StatsHistoryScreen] Time Machine active: using entry → target date $start to $end');
    } else {
      // Normal mode - last 30 days
      start = DateTime.now().subtract(const Duration(days: 30));
      final defaultEnd = DateTime.now();
      end = DateTime(
        defaultEnd.year,
        defaultEnd.month,
        defaultEnd.day,
        23,
        59,
        59,
        999,
      );
      debugPrint('[TimeMachine::StatsHistoryScreen] Normal mode: last 30 days');
    }

    // Initialize currency formatter after context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final locale = Provider.of<LocaleProvider>(context, listen: false);
      currency = NumberFormat.currency(symbol: locale.currencySymbol);
    });

    final hasExplicit =
        (widget.initialEnvelopeIds != null &&
            widget.initialEnvelopeIds!.isNotEmpty) ||
        (widget.initialGroupIds != null && widget.initialGroupIds!.isNotEmpty);

    if (hasExplicit) {
      selectedIds
        ..clear()
        ..addAll(widget.initialEnvelopeIds ?? const <String>{})
        ..addAll(widget.initialGroupIds ?? const <String>{});
      _didApplyExplicitInitialSelection = true;
    }
  }

  Future<void> _pickRange() async {
    // If time machine is active, cap lastDate at projection date
    final timeMachine = Provider.of<TimeMachineProvider>(context, listen: false);
    DateTime effectiveLastDate = DateTime.now().add(const Duration(days: 365));

    if (timeMachine.isActive && timeMachine.futureDate != null) {
      effectiveLastDate = timeMachine.futureDate!;
      debugPrint('[TimeMachine::StatsHistoryScreen] Date Range Picker:');
      debugPrint('[TimeMachine::StatsHistoryScreen]   Capped lastDate at ${timeMachine.futureDate}');
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

  AnalyticsFilter _getInitialAnalyticsFilter() {
    // Determine initial analytics filter based on filterTransactionTypes
    if (widget.filterTransactionTypes != null) {
      final hasDeposits = widget.filterTransactionTypes!.contains(TransactionType.deposit);
      final hasWithdrawals = widget.filterTransactionTypes!.contains(TransactionType.withdrawal);
      final hasScheduledPayments = widget.filterTransactionTypes!.contains(TransactionType.scheduledPayment);
      final hasTransfers = widget.filterTransactionTypes!.contains(TransactionType.transfer);

      // If filtering for account-level transactions (deposits, withdrawals, and transfers), show Net
      if (hasDeposits && hasWithdrawals && hasTransfers && !hasScheduledPayments) {
        return AnalyticsFilter.net;
      }
      // If filtering for deposits/income only, show Cash In
      if (hasDeposits && !hasWithdrawals && !hasScheduledPayments) {
        return AnalyticsFilter.cashIn;
      }
      // If filtering for withdrawals/scheduled payments, show Cash Out
      if ((hasWithdrawals || hasScheduledPayments) && !hasDeposits) {
        return AnalyticsFilter.cashOut;
      }
    }
    // Default to Cash Out for all other cases
    return AnalyticsFilter.cashOut;
  }

  void _showSelectionSheet<T>({
    required String title,
    required List<T> items,
    required String Function(T) getId,
    required Future<String> Function(T) getLabel,
  }) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              return Column(
                children: [
                  // Drag handle
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.3,
                        ),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: fontProvider.getTextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Select/Deselect buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: () {
                              setModalState(() {
                                setState(() {
                                  _didApplyExplicitInitialSelection = true;
                                  selectedIds.addAll(items.map(getId));
                                });
                              });
                            },
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              'Select All',
                              style: fontProvider.getTextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setModalState(() {
                                setState(() {
                                  _didApplyExplicitInitialSelection = true;
                                  for (var item in items) {
                                    selectedIds.remove(getId(item));
                                  }
                                });
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              'Deselect All',
                              style: fontProvider.getTextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // List
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final id = getId(item);
                        final isSelected = selectedIds.contains(id);

                        return FutureBuilder<String>(
                          future: getLabel(item),
                          builder: (context, snapshot) {
                            final label = snapshot.data ?? '...';
                            return _selectionTile(
                              label: label,
                              selected: isSelected,
                              onChanged: (v) {
                                setModalState(() {
                                  setState(() {
                                    _didApplyExplicitInitialSelection = true;
                                    if (v) {
                                      selectedIds.add(id);
                                    } else {
                                      selectedIds.remove(id);
                                    }
                                  });
                                });
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[TimeMachine::StatsHistoryScreen::build] ========================================');
    debugPrint('[TimeMachine::StatsHistoryScreen::build] Build called');
    debugPrint('[TimeMachine::StatsHistoryScreen::build] widget.initialStart = ${widget.initialStart}');
    debugPrint('[TimeMachine::StatsHistoryScreen::build] widget.initialEnd = ${widget.initialEnd}');
    debugPrint('[TimeMachine::StatsHistoryScreen::build] Current start = $start');
    debugPrint('[TimeMachine::StatsHistoryScreen::build] Current end = $end');
    debugPrint('[TimeMachine::StatsHistoryScreen::build] ========================================');

    final title = widget.title ?? 'Statistics & History';
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            style: fontProvider.getTextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Time Machine Indicator at the top
          const TimeMachineIndicator(),

          Expanded(
            child: StreamBuilder<List<Envelope>>(
              stream: widget.repo.envelopesStream(),
              builder: (_, sEnv) {
                final envelopes = sEnv.data ?? const <Envelope>[];

                return StreamBuilder<List<EnvelopeGroup>>(
            stream: widget.repo.groupsStream,
            builder: (_, sGrp) {
              final groups = sGrp.data ?? const <EnvelopeGroup>[];

              // Get AccountRepo from context
              final accountRepo = AccountRepo(widget.repo);

              return StreamBuilder<List<Account>>(
                stream: accountRepo.accountsStream(),
                builder: (_, sAcc) {
                  final accounts = sAcc.data ?? const <Account>[];

                  return Consumer<TimeMachineProvider>(
                    builder: (context, timeMachine, _) {
                      return StreamBuilder<List<Transaction>>(
                        stream: widget.repo.transactionsStream,
                        builder: (_, sTx) {
                          var txs = sTx.data ?? const <Transaction>[];

                      // If time machine is active, merge with projected transactions
                      if (timeMachine.isActive) {
                        final projectedTxs = timeMachine.getProjectedTransactionsForDateRange(
                          start,
                          end,
                          includeTransfers: true,
                        );

                        debugPrint('[TimeMachine::StatsHistoryScreen] Transaction Filtering:');
                        debugPrint('[TimeMachine::StatsHistoryScreen]   Real transactions: ${txs.length}');
                        debugPrint('[TimeMachine::StatsHistoryScreen]   Projected transactions: ${projectedTxs.length}');

                        txs = [...txs, ...projectedTxs];
                        debugPrint('[TimeMachine::StatsHistoryScreen]   Merged total: ${txs.length}');
                      }

                  // Auto-select all and set default filters if no explicit selection
                  if (!_didApplyExplicitInitialSelection &&
                      selectedIds.isEmpty &&
                      (envelopes.isNotEmpty || groups.isNotEmpty || accounts.isNotEmpty)) {
                    selectedIds
                      ..clear()
                      ..addAll(envelopes.map((e) => e.id))
                      ..addAll(groups.map((g) => g.id))
                      ..addAll(accounts.map((a) => a.id));

                    // Determine default active filters based on filterTransactionTypes
                    activeFilters.clear();

                    // Check if this is an account-level view
                    final isAccountView = widget.filterTransactionTypes != null &&
                        widget.filterTransactionTypes!.contains(TransactionType.deposit) &&
                        widget.filterTransactionTypes!.contains(TransactionType.withdrawal) &&
                        widget.filterTransactionTypes!.contains(TransactionType.transfer);

                    if (isAccountView) {
                      // Account view: activate accounts filter only
                      activeFilters.add(StatsFilterType.accounts);
                    } else {
                      // Default: activate envelopes and groups
                      activeFilters.add(StatsFilterType.envelopes);
                      activeFilters.add(StatsFilterType.groups);
                    }
                  }

                  final filteredEnvelopes = myOnly
                      ? envelopes
                            .where((e) => e.userId == widget.repo.currentUserId)
                            .toList()
                      : envelopes;

                  final filteredGroups = myOnly
                      ? groups
                            .where((g) => g.userId == widget.repo.currentUserId)
                            .toList()
                      : groups;

                  final filteredAccounts = accounts; // Accounts are always local-only

                  final selectedGroupIds = selectedIds
                      .where((id) => groups.any((g) => g.id == id))
                      .toSet();
                  final selectedEnvelopeIds = selectedIds
                      .where((id) => envelopes.any((e) => e.id == id))
                      .toSet();
                  // selectedAccountIds not needed since account filtering is based on empty envelopeId

                  // Calculate chosen envelopes based on active filters
                  List<Envelope> chosen = [];

                  if (activeFilters.contains(StatsFilterType.envelopes)) {
                    chosen.addAll(
                      filteredEnvelopes.where((e) => selectedEnvelopeIds.contains(e.id))
                    );
                  }

                  if (activeFilters.contains(StatsFilterType.groups)) {
                    chosen.addAll(
                      filteredEnvelopes.where(
                        (e) => e.groupId != null && selectedGroupIds.contains(e.groupId)
                      )
                    );
                  }

                  // Remove duplicates if any envelope is in both selected directly and via group
                  chosen = chosen.toSet().toList();

                  final envMap = {for (final e in envelopes) e.id: e.name};
                  final chosenIds = chosen.map((e) => e.id).toSet();

                  // Filter transactions based on active filters
                  final shownTxs = txs.where((t) {
                    bool inChosen = false;

                    // Check if transaction should be included based on active filters
                    if (activeFilters.contains(StatsFilterType.accounts)) {
                      // For account view: show account-level transactions (no envelopeId)
                      // This includes:
                      // - Pay day deposits (from Time Machine projections)
                      // - Account auto-fill transfers (from Time Machine projections)
                      // - Real account-level transactions with no envelopeId
                      if (t.envelopeId.isEmpty) {
                        inChosen = true;
                      }
                    }

                    if (activeFilters.contains(StatsFilterType.envelopes) ||
                        activeFilters.contains(StatsFilterType.groups)) {
                      // For envelope/group view: show transactions from chosen envelopes
                      if (chosenIds.contains(t.envelopeId)) {
                        inChosen = true;
                      }
                    }

                    final inRange =
                        !t.date.isBefore(start) && t.date.isBefore(end);
                    final typeMatch =
                        widget.filterTransactionTypes == null ||
                        widget.filterTransactionTypes!.contains(t.type);
                    return inChosen && inRange && typeMatch;
                  }).toList()..sort((a, b) => b.date.compareTo(a.date));

                  // Calculate stats - use projected data if time machine is active
                  double totalTarget;
                  double totalSaved;

                  if (timeMachine.isActive) {
                    // Use projected envelope data
                    final projectedChosen = chosen
                        .map((e) => timeMachine.getProjectedEnvelope(e))
                        .toList();

                    totalTarget = projectedChosen.fold(
                      0.0,
                      (s, e) => s + (e.targetAmount ?? 0),
                    );
                    totalSaved = projectedChosen.fold(
                      0.0,
                      (s, e) => s + e.currentAmount,
                    );

                    debugPrint('[TimeMachine::StatsHistoryScreen] Summary Statistics:');
                    debugPrint('[TimeMachine::StatsHistoryScreen]   Total Saved (projected): $totalSaved');
                    debugPrint('[TimeMachine::StatsHistoryScreen]   Total Target (projected): $totalTarget');
                  } else {
                    totalTarget = chosen.fold(
                      0.0,
                      (s, e) => s + (e.targetAmount ?? 0),
                    );
                    totalSaved = chosen.fold(
                      0.0,
                      (s, e) => s + e.currentAmount,
                    );
                  }
                  final double pct = totalTarget > 0
                      ? (totalSaved / totalTarget).clamp(0.0, 1.0) * 100
                      : 0.0;

                  // Calculate transaction stats (only for shown transaction types)
                  final showDeposits =
                      widget.filterTransactionTypes == null ||
                      widget.filterTransactionTypes!.contains(
                        TransactionType.deposit,
                      );
                  final showWithdrawals =
                      widget.filterTransactionTypes == null ||
                      widget.filterTransactionTypes!.contains(
                        TransactionType.withdrawal,
                      );
                  final showScheduledPayments =
                      widget.filterTransactionTypes == null ||
                      widget.filterTransactionTypes!.contains(
                        TransactionType.scheduledPayment,
                      );
                  final showTransfers =
                      widget.filterTransactionTypes == null ||
                      widget.filterTransactionTypes!.contains(
                        TransactionType.transfer,
                      );

                  final double totDep = showDeposits
                      ? shownTxs
                            .where((t) => t.type == TransactionType.deposit)
                            .fold(0.0, (s, t) => s + t.amount)
                      : 0.0;
                  final double totWdr = showWithdrawals
                      ? shownTxs
                            .where((t) => t.type == TransactionType.withdrawal)
                            .fold(0.0, (s, t) => s + t.amount)
                      : 0.0;
                  final double totSchPay = showScheduledPayments
                      ? shownTxs
                            .where((t) => t.type == TransactionType.scheduledPayment)
                            .fold(0.0, (s, t) => s + t.amount)
                      : 0.0;
                  final double totTrnOut = showTransfers
                      ? shownTxs
                            .where(
                              (t) =>
                                  t.type == TransactionType.transfer &&
                                  t.transferDirection == TransferDirection.out_,
                            )
                            .fold(0.0, (s, t) => s + t.amount)
                      : 0.0;

                  final envSelectedCount = filteredEnvelopes
                      .where((e) => selectedIds.contains(e.id))
                      .length;
                  final grpSelectedCount = filteredGroups
                      .where((g) => selectedIds.contains(g.id))
                      .length;
                  final accSelectedCount = filteredAccounts
                      .where((a) => selectedIds.contains(a.id))
                      .length;

                  return CustomScrollView(
                    slivers: [
                      // Date Range Card
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: _DateRangeCard(
                            start: start,
                            end: end,
                            myOnly: myOnly,
                            inWorkspace: widget.repo.inWorkspace,
                            onDateTap: _pickRange,
                            onToggleMyOnly: (v) => setState(() => myOnly = v),
                          ),
                        ),
                      ),

                      // Filter Toggle Buttons
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _ToggleFilterButton(
                                icon: Icons.mail_outline,
                                count: envSelectedCount,
                                isActive: activeFilters.contains(StatsFilterType.envelopes),
                                onTap: () {
                                  setState(() {
                                    if (activeFilters.contains(StatsFilterType.envelopes)) {
                                      activeFilters.remove(StatsFilterType.envelopes);
                                    } else {
                                      activeFilters.add(StatsFilterType.envelopes);
                                    }
                                  });
                                },
                                onLongPress: () => _showSelectionSheet<Envelope>(
                                  title: 'Select Envelopes',
                                  items: filteredEnvelopes,
                                  getId: (e) => e.id,
                                  getLabel: (e) async {
                                    final isMyEnvelope =
                                        e.userId == widget.repo.currentUserId;
                                    final owner = await widget.repo
                                        .getUserDisplayName(e.userId);
                                    return isMyEnvelope
                                        ? e.name
                                        : '$owner - ${e.name}';
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              _ToggleFilterButton(
                                icon: Icons.folder_open,
                                count: grpSelectedCount,
                                isActive: activeFilters.contains(StatsFilterType.groups),
                                onTap: () {
                                  setState(() {
                                    if (activeFilters.contains(StatsFilterType.groups)) {
                                      activeFilters.remove(StatsFilterType.groups);
                                    } else {
                                      activeFilters.add(StatsFilterType.groups);
                                    }
                                  });
                                },
                                onLongPress: () => _showSelectionSheet<EnvelopeGroup>(
                                  title: 'Select Binders',
                                  items: filteredGroups,
                                  getId: (g) => g.id,
                                  getLabel: (g) async => g.name,
                                ),
                              ),
                              const SizedBox(width: 12),
                              _ToggleFilterButton(
                                icon: Icons.account_balance_wallet,
                                count: accSelectedCount,
                                isActive: activeFilters.contains(StatsFilterType.accounts),
                                onTap: () {
                                  setState(() {
                                    if (activeFilters.contains(StatsFilterType.accounts)) {
                                      activeFilters.remove(StatsFilterType.accounts);
                                    } else {
                                      activeFilters.add(StatsFilterType.accounts);
                                    }
                                  });
                                },
                                onLongPress: () => _showSelectionSheet<Account>(
                                  title: 'Select Accounts',
                                  items: filteredAccounts,
                                  getId: (a) => a.id,
                                  getLabel: (a) async => a.name,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 8)),

                      // Analytics Section
                      SliverToBoxAdapter(
                        child: AnalyticsSection(
                          // Pass transactions filtered by envelope/group/account and date range
                          // but NOT by transaction type - this allows switching between Cash In/Out/Net
                          transactions: txs.where((t) {
                            bool inChosen = false;

                            // Check if transaction should be included based on active filters
                            if (activeFilters.contains(StatsFilterType.accounts)) {
                              if (t.envelopeId.isEmpty) {
                                inChosen = true;
                              }
                            }

                            if (activeFilters.contains(StatsFilterType.envelopes) ||
                                activeFilters.contains(StatsFilterType.groups)) {
                              if (chosenIds.contains(t.envelopeId)) {
                                inChosen = true;
                              }
                            }

                            final inRange = !t.date.isBefore(start) && t.date.isBefore(end);
                            return inChosen && inRange;
                          }).toList(),
                          envelopes: envelopes,
                          groups: groups,
                          dateRange: DateTimeRange(start: start, end: end),
                          initialFilter: _getInitialAnalyticsFilter(),
                          timeMachineDate: timeMachine.isActive ? timeMachine.futureDate : null,
                          onDateRangeChange: (range) {
                            setState(() {
                              start = DateTime(
                                range.start.year,
                                range.start.month,
                                range.start.day,
                              );
                              end = DateTime(
                                range.end.year,
                                range.end.month,
                                range.end.day,
                                23,
                                59,
                                59,
                                999,
                              );
                            });
                          },
                        ),
                      ),

                      // Summary Card
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _SummaryCard(
                            activeFilters: activeFilters,
                            count: chosen.length,
                            totalTarget: totalTarget,
                            totalSaved: totalSaved,
                            progress: pct,
                          ),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 16)),

                      // Transaction Stats Card
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _TransactionStatsCard(
                            start: start,
                            end: end,
                            deposited: totDep,
                            withdrawn: totWdr,
                            scheduledPayments: totSchPay,
                            transferred: totTrnOut,
                          ),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 24)),

                      // Ledger Header
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Icon(
                                Icons.receipt_long,
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
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
                                '${shownTxs.length}',
                                style: fontProvider.getTextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 12)),

                      // Transaction List
                      if (shownTxs.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 64,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No transactions found',
                                  style: fontProvider.getTextStyle(
                                    fontSize: 18,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Try adjusting your filters',
                                  style: fontProvider.getTextStyle(
                                    fontSize: 14,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.4),
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
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final t = shownTxs[index];
                              return FutureBuilder<Map<String, String>>(
                                future: _getUserNamesForTransaction(t),
                                builder: (context, snapshot) {
                                  final userNames = snapshot.data ?? {};
                                  return _TransactionTile(
                                    transaction: t,
                                    envMap: envMap,
                                    envelopes: envelopes,
                                    accounts: accounts,
                                    userNames: userNames,
                                    currentUserId: widget.repo.currentUserId,
                                  );
                                },
                              );
                            }, childCount: shownTxs.length),
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

  Widget _selectionTile({
    required String label,
    required bool selected,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!selected),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withValues(alpha: 0.2),
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  border: Border.all(
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                    width: 2,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: fontProvider.getTextStyle(
                    fontSize: 16,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Map<String, String>> _getUserNamesForTransaction(Transaction t) async {
    final Map<String, String> names = {};

    if (t.type == TransactionType.transfer) {
      if (t.sourceOwnerId != null) {
        names['source'] = await widget.repo.getUserDisplayName(
          t.sourceOwnerId!,
        );
      }
      if (t.targetOwnerId != null) {
        names['target'] = await widget.repo.getUserDisplayName(
          t.targetOwnerId!,
        );
      }
    } else {
      if (t.ownerId != null) {
        names['owner'] = await widget.repo.getUserDisplayName(t.ownerId!);
      }
    }

    return names;
  }
}

// EXTRACTED WIDGETS FOR BETTER ORGANIZATION

class _DateRangeCard extends StatelessWidget {
  const _DateRangeCard({
    required this.start,
    required this.end,
    required this.myOnly,
    required this.inWorkspace,
    required this.onDateTap,
    required this.onToggleMyOnly,
  });

  final DateTime start;
  final DateTime end;
  final bool myOnly;
  final bool inWorkspace;
  final VoidCallback onDateTap;
  final ValueChanged<bool> onToggleMyOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return Material(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onDateTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_today,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date Range',
                      style: fontProvider.getTextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${DateFormat('MMM d').format(start)} - ${DateFormat('MMM d, yyyy').format(end)}',
                      style: fontProvider.getTextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Only show "Mine only" toggle when in workspace mode
              if (inWorkspace)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Mine only',
                      style: fontProvider.getTextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    Switch(
                      value: myOnly,
                      activeTrackColor: theme.colorScheme.secondary,
                      onChanged: onToggleMyOnly,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleFilterButton extends StatelessWidget {
  const _ToggleFilterButton({
    required this.icon,
    required this.count,
    required this.isActive,
    required this.onTap,
    required this.onLongPress,
  });

  final IconData icon;
  final int count;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? theme.colorScheme.primary.withValues(alpha: 0.2)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 8),
            Text(
              '($count)',
              style: fontProvider.getTextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.activeFilters,
    required this.count,
    required this.totalTarget,
    required this.totalSaved,
    required this.progress,
  });

  final Set<StatsFilterType> activeFilters;
  final int count;
  final double totalTarget;
  final double totalSaved;
  final double progress;

  String get _title {
    final filters = <String>[];
    if (activeFilters.contains(StatsFilterType.envelopes)) filters.add('Envelopes');
    if (activeFilters.contains(StatsFilterType.groups)) filters.add('Binders');
    if (activeFilters.contains(StatsFilterType.accounts)) filters.add('Accounts');

    if (filters.isEmpty) return 'No Filters Selected';
    if (filters.length == 1) return '${filters[0]} Summary';
    return '${filters.join(' + ')} Summary';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final locale = Provider.of<LocaleProvider>(context, listen: false);
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.secondary.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.pie_chart,
                color: theme.colorScheme.secondary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _title,
                style: fontProvider.getTextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.secondary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count',
                  style: fontProvider.getTextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _StatRow(label: 'Target', value: currency.format(totalTarget)),
          _StatRow(
            label: 'Saved',
            value: currency.format(totalSaved),
            bold: true,
          ),
          _StatRow(
            label: 'Progress',
            value: '${progress.toStringAsFixed(1)}%',
            bold: true,
            color: progress >= 100 ? Colors.green : theme.colorScheme.secondary,
          ),
        ],
      ),
    );
  }
}

class _TransactionStatsCard extends StatelessWidget {
  const _TransactionStatsCard({
    required this.start,
    required this.end,
    required this.deposited,
    required this.withdrawn,
    required this.transferred,
    this.scheduledPayments = 0.0,
  });

  final DateTime start;
  final DateTime end;
  final double deposited;
  final double withdrawn;
  final double transferred;
  final double scheduledPayments;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final locale = Provider.of<LocaleProvider>(context, listen: false);
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Transaction Summary',
                style: fontProvider.getTextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${DateFormat('MMM d').format(start)} - ${DateFormat('MMM d').format(end)}',
            style: fontProvider.getTextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          _StatRow(
            label: 'Deposited',
            value: currency.format(deposited),
            bold: true,
            color: Colors.green.shade700,
            icon: Icons.arrow_downward,
          ),
          _StatRow(
            label: 'Withdrawn',
            value: currency.format(withdrawn),
            color: Colors.red.shade700,
            icon: Icons.arrow_upward,
          ),
          _StatRow(
            label: 'Scheduled Payments',
            value: currency.format(scheduledPayments),
            color: Colors.purple.shade700,
            icon: Icons.event_repeat,
          ),
          _StatRow(
            label: 'Transferred Out',
            value: currency.format(transferred),
            color: Colors.blue.shade700,
            icon: Icons.swap_horiz,
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.color,
    this.icon,
  });

  final String label;
  final String value;
  final bool bold;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: fontProvider.getTextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          Text(
            value,
            style: fontProvider.getTextStyle(
              fontSize: 16,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color ?? theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.envMap,
    required this.envelopes,
    required this.accounts,
    required this.userNames,
    required this.currentUserId,
  });

  final Transaction transaction;
  final Map<String, String> envMap;
  final List<Envelope> envelopes;
  final List<Account> accounts;
  final Map<String, String> userNames;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final locale = Provider.of<LocaleProvider>(context, listen: false);
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);

    final t = transaction;

    // Find related envelope if exists
    final envelope = envelopes.firstWhere(
      (e) => e.id == t.envelopeId,
      orElse: () => Envelope(id: '', name: '', userId: ''),
    );

    // Determine display properties based on transaction type
    String title;
    Widget leadingIcon;
    Color color;
    String amountStr;

    // Transaction type 1: Envelope Auto-Fill Deposits (from linked account)
    if (t.type == TransactionType.deposit && t.description.contains('Auto-fill deposit from')) {
      // Extract account name from description
      final match = RegExp(r'Auto-fill deposit from (.+)').firstMatch(t.description);
      final accountName = match?.group(1) ?? 'Unknown Account';

      title = '${envelope.name} - Auto-fill deposit from $accountName';
      leadingIcon = envelope.id.isNotEmpty
          ? envelope.getIconWidget(theme, size: 24)
          : Icon(Icons.mail_outline, size: 24, color: theme.colorScheme.primary);
      color = Colors.green.shade700;
      amountStr = '+${currency.format(t.amount)}';
    }
    // Transaction type 2: Scheduled Payments (from envelopes)
    else if (t.type == TransactionType.scheduledPayment) {
      title = '${envelope.name} - Scheduled payment';
      leadingIcon = envelope.id.isNotEmpty
          ? envelope.getIconWidget(theme, size: 24)
          : Icon(Icons.mail_outline, size: 24, color: theme.colorScheme.primary);
      color = Colors.purple.shade700;
      amountStr = '-${currency.format(t.amount)}';
    }
    // Transaction type 3: Pay Day (income to default account)
    else if (t.type == TransactionType.deposit && t.envelopeId.isEmpty && t.description == 'PAY DAY!') {
      // Find default account
      final defaultAccount = accounts.firstWhere(
        (a) => a.isDefault,
        orElse: () => accounts.isNotEmpty ? accounts.first : Account(
          id: '', name: 'Main', currentBalance: 0, userId: '',
          createdAt: DateTime.now(), lastUpdated: DateTime.now()
        ),
      );

      title = '${defaultAccount.name} - PAY DAY!';
      leadingIcon = defaultAccount.getIconWidget(theme, size: 24);
      color = Colors.green.shade700;
      amountStr = '+${currency.format(t.amount)}';
    }
    // Transaction type 4: Account Auto-Fill (other accounts/credit cards receiving from default)
    else if (t.type == TransactionType.deposit && t.description.contains('Auto-fill deposit from')) {
      // This is for account-level transactions (no envelope)
      final match = RegExp(r'Auto-fill deposit from (.+)').firstMatch(t.description);
      final sourceAccountName = match?.group(1) ?? 'Unknown Account';

      // The transaction's accountId should be set, but we need to find the target account
      // For account-level transactions, we need to infer from context
      // This is a deposit, so find the non-default account that matches
      final targetAccount = accounts.firstWhere(
        (a) => !a.isDefault,
        orElse: () => Account(
          id: '', name: 'Other Account', currentBalance: 0, userId: '',
          createdAt: DateTime.now(), lastUpdated: DateTime.now()
        ),
      );

      title = '${targetAccount.name} - Auto-fill deposit from $sourceAccountName';
      leadingIcon = targetAccount.getIconWidget(theme, size: 24);
      color = Colors.green.shade700;
      amountStr = '+${currency.format(t.amount)}';
    }
    // Transaction type 5: When viewing Default Account History (money leaving to envelopes)
    else if (t.type == TransactionType.withdrawal && t.description.contains('Withdrawal auto-fill') && !t.description.contains(' - ')) {
      // Old format without " - " separator, generic withdrawal
      title = t.description;
      leadingIcon = envelope.id.isNotEmpty
          ? envelope.getIconWidget(theme, size: 24)
          : Icon(Icons.mail_outline, size: 24, color: theme.colorScheme.primary);
      color = Colors.red.shade700;
      amountStr = '-${currency.format(t.amount)}';
    }
    // Transaction type 5 & 6: Withdrawal auto-fill (to envelope or account)
    else if (t.type == TransactionType.withdrawal && t.description.contains(' - Withdrawal auto-fill')) {
      // Extract entity name from description "[Entity Name] - Withdrawal auto-fill"
      final entityName = t.description.replaceAll(' - Withdrawal auto-fill', '');

      // Try to find envelope first
      final env = envelopes.firstWhere(
        (e) => e.name == entityName,
        orElse: () => Envelope(id: '', name: '', userId: ''),
      );

      if (env.id.isNotEmpty) {
        // Transaction type 5: Money leaving to envelope
        title = '$entityName - Withdrawal auto-fill';
        leadingIcon = env.getIconWidget(theme, size: 24);
      } else {
        // Transaction type 6: Money leaving to another account
        final account = accounts.firstWhere(
          (a) => a.name == entityName,
          orElse: () => Account(
            id: '', name: entityName, currentBalance: 0, userId: '',
            createdAt: DateTime.now(), lastUpdated: DateTime.now()
          ),
        );
        title = '$entityName - Withdrawal auto-fill';
        leadingIcon = account.getIconWidget(theme, size: 24);
      }

      color = Colors.red.shade700;
      amountStr = '-${currency.format(t.amount)}';
    }
    // Regular envelope transactions (deposit/withdrawal)
    else if (t.type == TransactionType.deposit || t.type == TransactionType.withdrawal) {
      final envName = envMap[t.envelopeId] ?? 'Unknown';
      title = envName;
      leadingIcon = envelope.id.isNotEmpty
          ? envelope.getIconWidget(theme, size: 24)
          : Icon(Icons.mail_outline, size: 24, color: theme.colorScheme.primary);

      if (t.type == TransactionType.deposit) {
        color = Colors.green.shade700;
        amountStr = '+${currency.format(t.amount)}';
      } else {
        color = Colors.red.shade700;
        amountStr = '-${currency.format(t.amount)}';
      }
    }
    // Transfer transactions
    else {
      final sourceOwner = userNames['source'] ?? 'Unknown';
      final targetOwner = userNames['target'] ?? 'Unknown';
      final sourceName = t.sourceEnvelopeName ?? 'Unknown';
      final targetName = t.targetEnvelopeName ?? 'Unknown';
      title = '$sourceOwner: $sourceName → $targetOwner: $targetName';
      leadingIcon = Icon(Icons.swap_horiz, size: 24, color: theme.colorScheme.primary);
      color = Colors.blue.shade700;
      amountStr = '→${currency.format(t.amount)}';
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
            child: SizedBox(width: 24, height: 24, child: leadingIcon),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: fontProvider.getTextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
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
                DateFormat('MMM dd').format(t.date),
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
