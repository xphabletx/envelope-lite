// lib/screens/stats_history_screen.dart
// REFACTORED with "Virtual Ledger" philosophy: External vs Internal transactions
// UI redesign: Data first, filters collapsible
// FULL CONTEXT AWARENESS: Envelopes, Groups, Accounts, Time Machine, filterTransactionTypes

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/envelope.dart';
import '../models/envelope_group.dart';
import '../models/transaction.dart';
import '../models/account.dart';
import '../models/analytics_data.dart';
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
  late DateTime start;
  late DateTime end;
  bool _filtersExpanded = false;

  // Context-aware filtering
  final selectedIds = <String>{};
  final activeFilters = <StatsFilterType>{};
  late bool myOnly;
  bool _didApplyExplicitInitialSelection = false;

  @override
  void initState() {
    super.initState();
    myOnly = widget.myOnlyDefault;

    final timeMachine = Provider.of<TimeMachineProvider>(context, listen: false);

    // Initialize dates with full context awareness
    if (widget.initialStart != null && widget.initialEnd != null) {
      // Explicit dates provided (e.g., from Budget Screen cards)
      start = widget.initialStart!;
      final providedEnd = widget.initialEnd!;
      end = DateTime(
        providedEnd.year,
        providedEnd.month,
        providedEnd.day,
        23, 59, 59, 999,
      );
      debugPrint('[StatsV2] Using explicit dates: $start to $end');
    } else if (timeMachine.isActive && timeMachine.entryDate != null && timeMachine.futureDate != null) {
      // Time machine active, no explicit dates - use entry date → target date
      start = timeMachine.entryDate!;
      final targetDate = timeMachine.futureDate!;
      end = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59, 999);
      debugPrint('[StatsV2] Time Machine active: $start to $end');
    } else {
      // Normal mode - last 30 days
      start = DateTime.now().subtract(const Duration(days: 30));
      final defaultEnd = DateTime.now();
      end = DateTime(defaultEnd.year, defaultEnd.month, defaultEnd.day, 23, 59, 59, 999);
    }

    // Initialize context-aware filters
    final hasExplicit =
        (widget.initialEnvelopeIds != null && widget.initialEnvelopeIds!.isNotEmpty) ||
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

  AnalyticsFilter _getInitialAnalyticsFilter() {
    if (widget.filterTransactionTypes != null) {
      final hasDeposits = widget.filterTransactionTypes!.contains(TransactionType.deposit);
      final hasWithdrawals = widget.filterTransactionTypes!.contains(TransactionType.withdrawal);
      final hasScheduledPayments = widget.filterTransactionTypes!.contains(TransactionType.scheduledPayment);
      final hasTransfers = widget.filterTransactionTypes!.contains(TransactionType.transfer);

      if (hasDeposits && hasWithdrawals && hasTransfers && !hasScheduledPayments) {
        return AnalyticsFilter.net;
      }
      if (hasDeposits && !hasWithdrawals && !hasScheduledPayments) {
        return AnalyticsFilter.cashIn;
      }
      if ((hasWithdrawals || hasScheduledPayments) && !hasDeposits) {
        return AnalyticsFilter.cashOut;
      }
    }
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
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
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
                  color: selected ? theme.colorScheme.primary : Colors.transparent,
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

                                // Auto-select all if no explicit selection
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
                                  final isAccountView = widget.filterTransactionTypes != null &&
                                      widget.filterTransactionTypes!.contains(TransactionType.deposit) &&
                                      widget.filterTransactionTypes!.contains(TransactionType.withdrawal) &&
                                      widget.filterTransactionTypes!.contains(TransactionType.transfer);

                                  if (isAccountView) {
                                    activeFilters.add(StatsFilterType.accounts);
                                  } else {
                                    activeFilters.add(StatsFilterType.envelopes);
                                    activeFilters.add(StatsFilterType.groups);
                                  }
                                }

                                // Apply myOnly filter
                                final filteredEnvelopes = myOnly
                                    ? envelopes.where((e) => e.userId == widget.repo.currentUserId).toList()
                                    : envelopes;

                                final filteredGroups = myOnly
                                    ? groups.where((g) => g.userId == widget.repo.currentUserId).toList()
                                    : groups;

                                final filteredAccounts = accounts; // Always local-only

                                // Calculate chosen entities based on active filters
                                final selectedGroupIds = selectedIds
                                    .where((id) => groups.any((g) => g.id == id))
                                    .toSet();
                                final selectedEnvelopeIds = selectedIds
                                    .where((id) => envelopes.any((e) => e.id == id))
                                    .toSet();

                                List<Envelope> chosenEnvelopes = [];
                                if (activeFilters.contains(StatsFilterType.envelopes)) {
                                  chosenEnvelopes.addAll(
                                    filteredEnvelopes.where((e) => selectedEnvelopeIds.contains(e.id))
                                  );
                                }
                                if (activeFilters.contains(StatsFilterType.groups)) {
                                  chosenEnvelopes.addAll(
                                    filteredEnvelopes.where(
                                      (e) => e.groupId != null && selectedGroupIds.contains(e.groupId)
                                    )
                                  );
                                }
                                chosenEnvelopes = chosenEnvelopes.toSet().toList();

                                final chosenEnvelopeIds = chosenEnvelopes.map((e) => e.id).toSet();

                                // Filter transactions by context
                                var contextFilteredTxs = txs.where((t) {
                                  bool inChosen = false;

                                  if (activeFilters.contains(StatsFilterType.accounts)) {
                                    if (t.envelopeId.isEmpty) {
                                      inChosen = true;
                                    }
                                  }

                                  if (activeFilters.contains(StatsFilterType.envelopes) ||
                                      activeFilters.contains(StatsFilterType.groups)) {
                                    if (chosenEnvelopeIds.contains(t.envelopeId)) {
                                      inChosen = true;
                                    }
                                  }

                                  final inRange = !t.date.isBefore(start) && t.date.isBefore(end);
                                  final typeMatch = widget.filterTransactionTypes == null ||
                                      widget.filterTransactionTypes!.contains(t.type);

                                  return inChosen && inRange && typeMatch;
                                }).toList();

                                // Deduplicate transfer transactions
                                final seenTransferLinks = <String>{};
                                contextFilteredTxs = contextFilteredTxs.where((t) {
                                  if (t.type == TransactionType.transfer && t.transferLinkId != null) {
                                    if (seenTransferLinks.contains(t.transferLinkId)) {
                                      return false;
                                    }
                                    seenTransferLinks.add(t.transferLinkId!);
                                  }
                                  return true;
                                }).toList();

                                // Sort by date descending
                                contextFilteredTxs.sort((a, b) => b.date.compareTo(a.date));

                                // Categorize transactions for Net Impact
                                double totalIncome = 0;
                                double totalSpending = 0;
                                double totalAllocations = 0;

                                for (final t in contextFilteredTxs) {
                                  final category = _categorizeTransaction(t, accounts);

                                  switch (category) {
                                    case TransactionCategory.externalIncome:
                                      totalIncome += t.amount;
                                      break;
                                    case TransactionCategory.externalSpending:
                                      totalSpending += t.amount;
                                      break;
                                    case TransactionCategory.internalAllocation:
                                      totalAllocations += t.amount.abs();
                                      break;
                                  }
                                }

                                final netSavings = totalIncome - totalSpending;

                                // Calculate counts for filter chips
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
                                    // FILTERS SECTION (Collapsible)
                                    if (_filtersExpanded)
                                      SliverToBoxAdapter(
                                        child: _FiltersSection(
                                          start: start,
                                          end: end,
                                          myOnly: myOnly,
                                          inWorkspace: widget.repo.inWorkspace,
                                          onDateTap: _pickRange,
                                          onToggleMyOnly: (v) => setState(() => myOnly = v),
                                          onClose: () => setState(() => _filtersExpanded = false),
                                          // Entity filters
                                          envSelectedCount: envSelectedCount,
                                          grpSelectedCount: grpSelectedCount,
                                          accSelectedCount: accSelectedCount,
                                          activeFilters: activeFilters,
                                          onToggleEnvelopes: () {
                                            setState(() {
                                              if (activeFilters.contains(StatsFilterType.envelopes)) {
                                                activeFilters.remove(StatsFilterType.envelopes);
                                              } else {
                                                activeFilters.add(StatsFilterType.envelopes);
                                              }
                                            });
                                          },
                                          onToggleGroups: () {
                                            setState(() {
                                              if (activeFilters.contains(StatsFilterType.groups)) {
                                                activeFilters.remove(StatsFilterType.groups);
                                              } else {
                                                activeFilters.add(StatsFilterType.groups);
                                              }
                                            });
                                          },
                                          onToggleAccounts: () {
                                            setState(() {
                                              if (activeFilters.contains(StatsFilterType.accounts)) {
                                                activeFilters.remove(StatsFilterType.accounts);
                                              } else {
                                                activeFilters.add(StatsFilterType.accounts);
                                              }
                                            });
                                          },
                                          onSelectEnvelopes: () => _showSelectionSheet<Envelope>(
                                            title: 'Select Envelopes',
                                            items: filteredEnvelopes,
                                            getId: (e) => e.id,
                                            getLabel: (e) async {
                                              final isMyEnvelope = e.userId == widget.repo.currentUserId;
                                              final owner = await widget.repo.getUserDisplayName(e.userId);
                                              return isMyEnvelope ? e.name : '$owner - ${e.name}';
                                            },
                                          ),
                                          onSelectGroups: () => _showSelectionSheet<EnvelopeGroup>(
                                            title: 'Select Binders',
                                            items: filteredGroups,
                                            getId: (g) => g.id,
                                            getLabel: (g) async => g.name,
                                          ),
                                          onSelectAccounts: () => _showSelectionSheet<Account>(
                                            title: 'Select Accounts',
                                            items: filteredAccounts,
                                            getId: (a) => a.id,
                                            getLabel: (a) async => a.name,
                                          ),
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

                                    // ANALYTICS/DONUT CHART (with context filtering)
                                    SliverToBoxAdapter(
                                      child: AnalyticsSection(
                                        transactions: txs.where((t) {
                                          bool inChosen = false;

                                          if (activeFilters.contains(StatsFilterType.accounts)) {
                                            if (t.envelopeId.isEmpty) {
                                              inChosen = true;
                                            }
                                          }

                                          if (activeFilters.contains(StatsFilterType.envelopes) ||
                                              activeFilters.contains(StatsFilterType.groups)) {
                                            if (chosenEnvelopeIds.contains(t.envelopeId)) {
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
                                              '${contextFilteredTxs.length}',
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
                                    if (contextFilteredTxs.isEmpty)
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
                                              final t = contextFilteredTxs[index];
                                              final category = _categorizeTransaction(t, accounts);

                                              return _TransactionTile(
                                                transaction: t,
                                                category: category,
                                                envelopes: envelopes,
                                                accounts: accounts,
                                              );
                                            },
                                            childCount: contextFilteredTxs.length,
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

// FILTERS SECTION (Collapsible with full context controls)
class _FiltersSection extends StatelessWidget {
  const _FiltersSection({
    required this.start,
    required this.end,
    required this.myOnly,
    required this.inWorkspace,
    required this.onDateTap,
    required this.onToggleMyOnly,
    required this.onClose,
    required this.envSelectedCount,
    required this.grpSelectedCount,
    required this.accSelectedCount,
    required this.activeFilters,
    required this.onToggleEnvelopes,
    required this.onToggleGroups,
    required this.onToggleAccounts,
    required this.onSelectEnvelopes,
    required this.onSelectGroups,
    required this.onSelectAccounts,
  });

  final DateTime start;
  final DateTime end;
  final bool myOnly;
  final bool inWorkspace;
  final VoidCallback onDateTap;
  final ValueChanged<bool> onToggleMyOnly;
  final VoidCallback onClose;
  final int envSelectedCount;
  final int grpSelectedCount;
  final int accSelectedCount;
  final Set<StatsFilterType> activeFilters;
  final VoidCallback onToggleEnvelopes;
  final VoidCallback onToggleGroups;
  final VoidCallback onToggleAccounts;
  final VoidCallback onSelectEnvelopes;
  final VoidCallback onSelectGroups;
  final VoidCallback onSelectAccounts;

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

          // Date Range
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
                    if (inWorkspace) ...[
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Mine only',
                            style: fontProvider.getTextStyle(
                              fontSize: 11,
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
                    Icon(Icons.arrow_forward_ios, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Entity filters
          Text(
            'Show transactions from:',
            style: fontProvider.getTextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip(
                icon: Icons.mail_outline,
                label: 'Envelopes ($envSelectedCount)',
                isActive: activeFilters.contains(StatsFilterType.envelopes),
                onTap: onToggleEnvelopes,
                onLongPress: onSelectEnvelopes,
              ),
              _FilterChip(
                icon: Icons.folder_open,
                label: 'Binders ($grpSelectedCount)',
                isActive: activeFilters.contains(StatsFilterType.groups),
                onTap: onToggleGroups,
                onLongPress: onSelectGroups,
              ),
              _FilterChip(
                icon: Icons.account_balance_wallet,
                label: 'Accounts ($accSelectedCount)',
                isActive: activeFilters.contains(StatsFilterType.accounts),
                onTap: onToggleAccounts,
                onLongPress: onSelectAccounts,
              ),
            ],
          ),

          const SizedBox(height: 8),
          Text(
            'Tap to toggle, long-press to select specific items',
            style: fontProvider.getTextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.onLongPress,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? theme.colorScheme.primary.withValues(alpha: 0.2)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
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
              size: 18,
              color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: fontProvider.getTextStyle(
                fontSize: 13,
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
