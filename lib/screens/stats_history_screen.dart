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
import '../widgets/analytics/cash_flow_mix_chart.dart';
import '../widgets/transactions/transaction_list_item.dart';

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
    this.initialAccountIds,
    this.initialStart,
    this.initialEnd,
    this.myOnlyDefault = false,
    this.title,
    this.filterTransactionTypes,
  });

  final EnvelopeRepo repo;
  final Set<String>? initialEnvelopeIds;
  final Set<String>? initialGroupIds;
  final Set<String>? initialAccountIds;
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
        (widget.initialGroupIds != null && widget.initialGroupIds!.isNotEmpty) ||
        (widget.initialAccountIds != null && widget.initialAccountIds!.isNotEmpty);

    if (hasExplicit) {
      selectedIds
        ..clear()
        ..addAll(widget.initialEnvelopeIds ?? const <String>{})
        ..addAll(widget.initialAccountIds ?? const <String>{})
        ..addAll(widget.initialGroupIds ?? const <String>{});
      _didApplyExplicitInitialSelection = true;

      // Set active filters based on what was explicitly provided
      if (widget.initialEnvelopeIds != null && widget.initialEnvelopeIds!.isNotEmpty) {
        activeFilters.add(StatsFilterType.envelopes);
      }
      if (widget.initialGroupIds != null && widget.initialGroupIds!.isNotEmpty) {
        activeFilters.add(StatsFilterType.groups);
      }
      if (widget.initialAccountIds != null && widget.initialAccountIds!.isNotEmpty) {
        activeFilters.add(StatsFilterType.accounts);
      }

      // DEBUG: Log initial context
      debugPrint('[StatsHistoryScreen] ===== CONTEXT INITIALIZATION =====');
      debugPrint('[StatsHistoryScreen] Title: ${widget.title}');
      debugPrint('[StatsHistoryScreen] Initial Envelope IDs: ${widget.initialEnvelopeIds}');
      debugPrint('[StatsHistoryScreen] Initial Group IDs: ${widget.initialGroupIds}');
      debugPrint('[StatsHistoryScreen] Initial Account IDs: ${widget.initialAccountIds}');
      debugPrint('[StatsHistoryScreen] Active Filters: $activeFilters');
      debugPrint('[StatsHistoryScreen] Selected IDs: $selectedIds');
      debugPrint('[StatsHistoryScreen] ====================================');
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


  /// Calculate Horizon Strategy Stats - The "Wall" Philosophy Analytics
  HorizonStrategyStats _calculateHorizonStats(
    List<Transaction> transactions,
    List<Envelope> envelopes,
  ) {
    // Identify Horizon envelopes (targetAmount != null && targetAmount > 0)
    final horizonEnvelopes = envelopes
        .where((e) => e.targetAmount != null && e.targetAmount! > 0)
        .toList();
    final horizonEnvelopeIds = horizonEnvelopes.map((e) => e.id).toSet();

    // Calculate total remaining gap for all Horizons
    double totalHorizonGap = 0;
    for (final env in horizonEnvelopes) {
      final gap = env.targetAmount! - env.currentAmount;
      if (gap > 0) {
        totalHorizonGap += gap;
      }
    }

    // Analyze transactions
    double externalInflow = 0;
    double externalOutflow = 0;
    double horizonVelocity = 0;
    double liquidCash = 0;
    double fixedBills = 0;
    double discretionary = 0;

    for (final t in transactions) {
      // Use new philosophy fields if available, fallback to legacy categorization
      final isExternal = t.impact == TransactionImpact.external;
      final isInternal = t.impact == TransactionImpact.internal;
      final isInflow = t.direction == TransactionDirection.inflow;
      final isOutflow = t.direction == TransactionDirection.outflow;
      final isMove = t.direction == TransactionDirection.move;

      // EXTERNAL INFLOW (Income)
      if (isExternal && isInflow) {
        externalInflow += t.amount;
      }

      // EXTERNAL OUTFLOW (Spending)
      else if (isExternal && isOutflow) {
        externalOutflow += t.amount;

        // Categorize spending: Fixed Bills vs Discretionary
        final isDebtTransaction = t.envelopeId.isNotEmpty &&
            envelopes.any((e) => e.id == t.envelopeId && e.isDebtEnvelope);
        final isAutopilot = t.description.toLowerCase().contains('autopilot');

        if (isDebtTransaction || isAutopilot) {
          fixedBills += t.amount;
        } else {
          discretionary += t.amount;
        }
      }

      // INTERNAL MOVES
      else if (isInternal && isMove) {
        // Check if destination is a Horizon envelope
        if (t.destinationId != null && horizonEnvelopeIds.contains(t.destinationId)) {
          horizonVelocity += t.amount;
        } else {
          liquidCash += t.amount;
        }
      }
    }

    // Calculate derived metrics
    final netImpact = externalInflow - externalOutflow;
    final efficiency = externalInflow > 0 ? netImpact / externalInflow : 0.0;
    final horizonImpact = totalHorizonGap > 0
        ? (horizonVelocity / totalHorizonGap) * 100
        : (horizonVelocity > 0 ? 100.0 : 0.0);

    return HorizonStrategyStats(
      externalInflow: externalInflow,
      externalOutflow: externalOutflow,
      netImpact: netImpact,
      efficiency: efficiency,
      horizonVelocity: horizonVelocity,
      totalHorizonGap: totalHorizonGap,
      horizonImpact: horizonImpact,
      fixedBills: fixedBills,
      discretionary: discretionary,
      liquidCash: liquidCash,
    );
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
                                // DEBUG: Log filtering context
                                debugPrint('[StatsHistoryScreen] ===== TRANSACTION FILTERING =====');
                                debugPrint('[StatsHistoryScreen] Total transactions: ${txs.length}');
                                debugPrint('[StatsHistoryScreen] Active filters: $activeFilters');
                                debugPrint('[StatsHistoryScreen] Selected IDs: $selectedIds');
                                debugPrint('[StatsHistoryScreen] Chosen Envelope IDs: ${chosenEnvelopeIds.length}');

                                // Extract account IDs from selectedIds for efficient lookup
                                final selectedAccountIds = selectedIds
                                    .where((id) => accounts.any((a) => a.id == id))
                                    .toSet();

                                var contextFilteredTxs = txs.where((t) {
                                  bool accountMatch = true;
                                  bool envelopeMatch = true;

                                  // Account filter: if active, transaction MUST be from selected account(s)
                                  if (activeFilters.contains(StatsFilterType.accounts)) {
                                    accountMatch = false;
                                    if (t.accountId != null && t.accountId!.isNotEmpty) {
                                      if (selectedAccountIds.isEmpty || selectedAccountIds.contains(t.accountId)) {
                                        accountMatch = true;
                                      }
                                    }
                                  }

                                  // Envelope/Group filter: if active, transaction MUST be from selected envelope(s)
                                  if (activeFilters.contains(StatsFilterType.envelopes) ||
                                      activeFilters.contains(StatsFilterType.groups)) {
                                    envelopeMatch = false;
                                    if (chosenEnvelopeIds.contains(t.envelopeId)) {
                                      envelopeMatch = true;
                                    }
                                  }

                                  final inRange = !t.date.isBefore(start) && t.date.isBefore(end);
                                  final typeMatch = widget.filterTransactionTypes == null ||
                                      widget.filterTransactionTypes!.contains(t.type);

                                  // Transaction must match ALL active filter types (AND logic)
                                  return accountMatch && envelopeMatch && inRange && typeMatch;
                                }).toList();

                                // DEBUG: Log sample transaction details when filtering returns 0 results
                                if (contextFilteredTxs.isEmpty && txs.isNotEmpty) {
                                  debugPrint('[StatsHistoryScreen] ⚠️ No transactions matched filters!');
                                  debugPrint('[StatsHistoryScreen] Selected Account IDs: $selectedAccountIds');
                                  debugPrint('[StatsHistoryScreen] Chosen Envelope IDs: $chosenEnvelopeIds');
                                  debugPrint('[StatsHistoryScreen] Sample transactions (first 3):');
                                  for (var i = 0; i < (txs.length > 3 ? 3 : txs.length); i++) {
                                    final t = txs[i];
                                    debugPrint('[StatsHistoryScreen]   - Tx ${i+1}: accountId=${t.accountId}, envelopeId=${t.envelopeId}, type=${t.type}, amount=${t.amount}');
                                  }
                                }

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

                                // DEBUG: Log filtered results with useful information
                                debugPrint('[StatsHistoryScreen] Filtered transactions: ${contextFilteredTxs.length}');
                                if (contextFilteredTxs.isNotEmpty) {
                                  debugPrint('[StatsHistoryScreen] ');
                                  debugPrint('[StatsHistoryScreen] TRANSACTION LIST:');
                                  debugPrint('[StatsHistoryScreen] ');
                                  for (var i = 0; i < (contextFilteredTxs.length > 10 ? 10 : contextFilteredTxs.length); i++) {
                                    final t = contextFilteredTxs[i];
                                    final txDate = DateFormat('MMM d, yyyy').format(t.date);
                                    final txTime = DateFormat('h:mm a').format(t.date);

                                    // Find account and envelope names
                                    String accName = 'None';
                                    if (t.accountId != null && t.accountId!.isNotEmpty) {
                                      final acc = accounts.firstWhere(
                                        (a) => a.id == t.accountId,
                                        orElse: () => Account(id: '', name: 'Unknown', currentBalance: 0, userId: '', createdAt: DateTime.now(), lastUpdated: DateTime.now()),
                                      );
                                      accName = acc.name;
                                    }

                                    String envName = 'None';
                                    if (t.envelopeId.isNotEmpty) {
                                      final env = envelopes.firstWhere(
                                        (e) => e.id == t.envelopeId,
                                        orElse: () => Envelope(id: '', name: 'Unknown', userId: ''),
                                      );
                                      envName = env.name;
                                    }

                                    String typeStr = t.type.name.toUpperCase();
                                    String fromTo = '';

                                    if (t.type == TransactionType.transfer) {
                                      fromTo = 'From: ${t.sourceEnvelopeName ?? 'Unknown'} → To: ${t.targetEnvelopeName ?? 'Unknown'}';
                                    } else if (t.type == TransactionType.deposit) {
                                      fromTo = accName != 'None' ? 'To Account: $accName' : 'To Envelope: $envName';
                                    } else if (t.type == TransactionType.withdrawal) {
                                      fromTo = accName != 'None' ? 'From Account: $accName' : 'From Envelope: $envName';
                                    }

                                    debugPrint('[StatsHistoryScreen] ${i + 1}. ${t.description}');
                                    debugPrint('[StatsHistoryScreen]    Type: $typeStr | Amount: £${t.amount.toStringAsFixed(2)}');
                                    debugPrint('[StatsHistoryScreen]    $fromTo');
                                    debugPrint('[StatsHistoryScreen]    Date: $txDate at $txTime');
                                    debugPrint('[StatsHistoryScreen] ');
                                  }
                                }
                                debugPrint('[StatsHistoryScreen] ====================================');

                                // Calculate Horizon Strategy Stats
                                final horizonStats = _calculateHorizonStats(
                                  contextFilteredTxs,
                                  envelopes,
                                );

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

                                    // HORIZON STRATEGY CARD (Replaces Net Impact Card)
                                    SliverToBoxAdapter(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        child: _StrategyCard(
                                          stats: horizonStats,
                                          start: start,
                                          end: end,
                                        ),
                                      ),
                                    ),

                                    const SliverToBoxAdapter(child: SizedBox(height: 16)),

                                    // CASH FLOW MIX CHART (Simplified 3-segment donut)
                                    SliverToBoxAdapter(
                                      child: CashFlowMixChart(
                                        stats: horizonStats,
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
                                      SliverPadding(
                                        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 100),
                                        sliver: SliverFillRemaining(
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
                                        ),
                                      )
                                    else
                                      SliverPadding(
                                        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).padding.bottom + 80),
                                        sliver: SliverList(
                                          delegate: SliverChildBuilderDelegate(
                                            (context, index) {
                                              final t = contextFilteredTxs[index];

                                              return TransactionListItem(
                                                transaction: t,
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
                    // Only show "Mine only" toggle when viewing envelopes/groups
                    // (accounts are never shared in workspaces)
                    if (inWorkspace && (activeFilters.contains(StatsFilterType.envelopes) ||
                                        activeFilters.contains(StatsFilterType.groups))) ...[
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

// HORIZON STRATEGY CARD - The "Wall" Philosophy Dashboard
class _StrategyCard extends StatelessWidget {
  const _StrategyCard({
    required this.stats,
    required this.start,
    required this.end,
  });

  final HorizonStrategyStats stats;
  final DateTime start;
  final DateTime end;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);
    final locale = Provider.of<LocaleProvider>(context);
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);

    // Color palette for feedback
    final greenColor = Colors.green.shade700;
    final goldColor = theme.colorScheme.secondary;
    final redColor = Colors.red.shade700;

    final feedbackColor = stats.getFeedbackColor(greenColor, goldColor, redColor);

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
          // Header
          Row(
            children: [
              Icon(Icons.analytics, color: theme.colorScheme.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Horizon Strategy',
                      style: fontProvider.getTextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Text(
                      '${DateFormat('MMM d').format(start)} - ${DateFormat('MMM d, yyyy').format(end)}',
                      style: fontProvider.getTextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Net Impact (Big Number)
          Center(
            child: Column(
              children: [
                Text(
                  'Net Impact',
                  style: fontProvider.getTextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  currency.format(stats.netImpact),
                  style: fontProvider.getTextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: stats.netImpact >= 0 ? greenColor : redColor,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Strategy Feedback Message
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: feedbackColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: feedbackColor.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  stats.efficiency > 0.2
                      ? Icons.rocket_launch
                      : stats.efficiency > 0
                          ? Icons.check_circle
                          : Icons.warning,
                  color: feedbackColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    stats.strategyFeedback,
                    style: fontProvider.getTextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: feedbackColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Key Metrics Row
          Row(
            children: [
              Expanded(
                child: _MetricBox(
                  icon: Icons.speed,
                  label: 'Efficiency',
                  value: '${(stats.efficiency * 100).toStringAsFixed(1)}%',
                  color: feedbackColor,
                  helpText: "The percentage of your income that stays inside 'The Wall' after bills and spending.",
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricBox(
                  icon: Icons.trending_up,
                  label: 'Horizon Fuel',
                  value: currency.format(stats.horizonVelocity),
                  color: goldColor,
                  helpText: "The speed at which you are moving money into your Horizon goals.",
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Horizon Impact Message
          GestureDetector(
            onTap: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (ctx) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.flag, color: theme.colorScheme.primary, size: 28),
                            const SizedBox(width: 12),
                            Text(
                              'Horizon Impact',
                              style: fontProvider.getTextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "How much of your total savings gap you closed during this period.",
                          style: fontProvider.getTextStyle(
                            fontSize: 16,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              'Got it',
                              style: fontProvider.getTextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.flag,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      stats.getHorizonImpactMessage(),
                      style: fontProvider.getTextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: theme.colorScheme.primary.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Income Allocation Progress Bar
          _IncomeAllocationBar(stats: stats),

          // Deficit Warning (if applicable)
          if (stats.isDeficit) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: redColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: redColor.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: redColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '⚠️ Deficit Strategy: Spending exceeded income',
                      style: fontProvider.getTextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: redColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Metric Box for Efficiency and Horizon Fuel
class _MetricBox extends StatelessWidget {
  const _MetricBox({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.helpText,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? helpText;

  void _showHelpDialog(BuildContext context) {
    if (helpText == null) return;

    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: fontProvider.getTextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                helpText!,
                style: fontProvider.getTextStyle(
                  fontSize: 16,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Got it',
                    style: fontProvider.getTextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: fontProvider.getTextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              if (helpText != null) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _showHelpDialog(context),
                  child: Icon(
                    Icons.info_outline,
                    size: 14,
                    color: theme.colorScheme.primary.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: fontProvider.getTextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// Income Allocation Progress Bar - Multi-Segment
class _IncomeAllocationBar extends StatelessWidget {
  const _IncomeAllocationBar({required this.stats});

  final HorizonStrategyStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);
    final allocation = stats.getIncomeAllocation();

    final spentPercent = allocation['spent']!;
    final horizonsPercent = allocation['horizons']!;
    final liquidPercent = allocation['liquid']!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Income Allocation',
          style: fontProvider.getTextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),

        // Multi-segment bar
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 24,
            child: Row(
              children: [
                // Spent segment (Red)
                if (spentPercent > 0)
                  Flexible(
                    flex: (spentPercent * 100).round(),
                    child: Container(
                      color: Colors.red.shade700,
                      alignment: Alignment.center,
                      child: spentPercent > 0.15
                          ? Text(
                              '${(spentPercent * 100).toStringAsFixed(0)}%',
                              style: fontProvider.getTextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                  ),

                // Horizons segment (Gold)
                if (horizonsPercent > 0)
                  Flexible(
                    flex: (horizonsPercent * 100).round(),
                    child: Container(
                      color: theme.colorScheme.secondary,
                      alignment: Alignment.center,
                      child: horizonsPercent > 0.15
                          ? Text(
                              '${(horizonsPercent * 100).toStringAsFixed(0)}%',
                              style: fontProvider.getTextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                  ),

                // Liquid segment (Grey)
                if (liquidPercent > 0)
                  Flexible(
                    flex: (liquidPercent * 100).round(),
                    child: Container(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                      alignment: Alignment.center,
                      child: liquidPercent > 0.15
                          ? Text(
                              '${(liquidPercent * 100).toStringAsFixed(0)}%',
                              style: fontProvider.getTextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Legend
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            _LegendItem(
              color: Colors.red.shade700,
              label: 'Spent',
              percent: spentPercent * 100,
            ),
            _LegendItem(
              color: theme.colorScheme.secondary,
              label: 'Horizons',
              percent: horizonsPercent * 100,
            ),
            _LegendItem(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              label: 'Liquid',
              percent: liquidPercent * 100,
            ),
          ],
        ),
      ],
    );
  }
}

// Legend Item for Progress Bar
class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.percent,
  });

  final Color color;
  final String label;
  final double percent;

  @override
  Widget build(BuildContext context) {
    final fontProvider = Provider.of<FontProvider>(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label (${percent.toStringAsFixed(0)}%)',
          style: fontProvider.getTextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}


