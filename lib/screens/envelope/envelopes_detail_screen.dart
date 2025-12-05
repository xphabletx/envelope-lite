// lib/screens/envelope/envelopes_detail_screen.dart
// FONT PROVIDER INTEGRATED: All GoogleFonts.caveat() replaced with FontProvider
// All button text wrapped in FittedBox to prevent wrapping
// DEPRECATION FIX: .withOpacity -> .withValues(alpha: )

import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // NEW IMPORT
import 'package:intl/intl.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import '../../../models/envelope.dart';
import '../../../models/envelope_group.dart';
import '../../../models/transaction.dart';
import '../../../services/envelope_repo.dart';
import '../../../services/group_repo.dart';
import '../../../widgets/calculator_widget.dart';
import '../stats_history_screen.dart';
import 'envelope_header_card.dart';
import 'envelope_transaction_list.dart';
import 'envelope_settings_sheet.dart';
import '../group_detail_screen.dart';
import 'modals/deposit_modal.dart';
import 'modals/withdraw_modal.dart';
import 'modals/transfer_modal.dart';
import '../../../services/localization_service.dart';
import '../../../providers/font_provider.dart'; // NEW IMPORT

class EnvelopeDetailScreen extends StatefulWidget {
  const EnvelopeDetailScreen({
    super.key,
    required this.envelopeId,
    required this.repo,
  });

  final String envelopeId;
  final EnvelopeRepo repo;

  @override
  State<EnvelopeDetailScreen> createState() => _EnvelopeDetailScreenState();
}

class _EnvelopeDetailScreenState extends State<EnvelopeDetailScreen> {
  // Current month being viewed (defaults to now)
  late DateTime _viewingMonth;
  final _scrollController = ScrollController();
  double _savedScrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _viewingMonth = DateTime.now();
    _scrollController.addListener(_saveScrollOffset);
  }

  void _saveScrollOffset() {
    if (_scrollController.hasClients) {
      _savedScrollOffset = _scrollController.offset;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_saveScrollOffset);
    _scrollController.dispose();
    super.dispose();
  }

  void _previousMonth() {
    setState(() {
      _viewingMonth = DateTime(_viewingMonth.year, _viewingMonth.month - 1);
    });
    _restoreScroll();
  }

  void _nextMonth() {
    setState(() {
      _viewingMonth = DateTime(_viewingMonth.year, _viewingMonth.month + 1);
    });
    _restoreScroll();
  }

  void _restoreScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && _savedScrollOffset > 0) {
        _scrollController.jumpTo(
          _savedScrollOffset.clamp(
            0.0,
            _scrollController.position.maxScrollExtent,
          ),
        );
      }
    });
  }

  void _goToCurrentMonth() {
    setState(() {
      _viewingMonth = DateTime.now();
    });
  }

  bool _isCurrentMonth() {
    final now = DateTime.now();
    return _viewingMonth.year == now.year && _viewingMonth.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return StreamBuilder<Envelope>(
      stream: widget.repo.envelopeStream(widget.envelopeId),
      builder: (context, envelopeSnapshot) {
        if (envelopeSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (!envelopeSnapshot.hasData) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(tr('error_envelope_not_found'))),
          );
        }

        final envelope = envelopeSnapshot.data!;

        return StreamBuilder<List<Transaction>>(
          stream: widget.repo.transactionsForEnvelope(widget.envelopeId),
          builder: (context, txSnapshot) {
            final allTransactions = txSnapshot.data ?? [];

            // Filter transactions for the viewing month
            final monthStart = DateTime(
              _viewingMonth.year,
              _viewingMonth.month,
              1,
            );
            final monthEnd = DateTime(
              _viewingMonth.year,
              _viewingMonth.month + 1,
              0,
              23,
              59,
              59,
            );

            final monthTransactions = allTransactions.where((tx) {
              return tx.date.isAfter(
                    monthStart.subtract(const Duration(seconds: 1)),
                  ) &&
                  tx.date.isBefore(monthEnd.add(const Duration(seconds: 1)));
            }).toList();

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
                  envelope.name,
                  // UPDATED: FontProvider
                  style: fontProvider.getTextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                actions: [
                  // Stats/History button
                  IconButton(
                    icon: const Icon(Icons.bar_chart),
                    tooltip: tr('envelope_view_history_tooltip'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StatsHistoryScreen(
                            repo: widget.repo,
                            initialEnvelopeIds: {envelope.id},
                            title: '${envelope.name} - ${tr('history')}',
                          ),
                        ),
                      );
                    },
                  ),

                  // Settings button
                  IconButton(
                    icon: const Icon(Icons.settings),
                    tooltip: tr('settings'),
                    onPressed: () => _showSettings(context, envelope),
                  ),
                ],
              ),
              body: SingleChildScrollView(
                key: const PageStorageKey<String>('envelope_detail_scroll'),
                controller: _scrollController,
                child: Column(
                  children: [
                    // Envelope header card (original design)
                    EnvelopeHeaderCard(envelope: envelope),

                    const SizedBox(height: 16),

                    // "In Binder" info row (if applicable)
                    if (envelope.groupId != null)
                      _BinderInfoRow(
                        binderId: envelope.groupId!,
                        repo: widget.repo,
                      ),

                    if (envelope.groupId != null) const SizedBox(height: 16),

                    // Month navigation bar
                    _buildMonthNavigationBar(theme),

                    const SizedBox(height: 8),

                    // Transaction list for the month
                    EnvelopeTransactionList(
                      key: ValueKey(
                        'transactions_${_viewingMonth.month}_${_viewingMonth.year}',
                      ),
                      transactions: monthTransactions,
                      onTransactionTap: (tx) {
                        // Optional: Show transaction details
                      },
                    ),

                    const SizedBox(height: 140), // Space for FAB + bottom nav
                  ],
                ),
              ),
              bottomNavigationBar: BottomNavigationBar(
                backgroundColor: theme.scaffoldBackgroundColor,
                selectedItemColor: theme.colorScheme.primary,
                unselectedItemColor: Colors.grey.shade600,
                elevation: 8,
                type: BottomNavigationBarType.fixed,
                // UPDATED: FontProvider
                selectedLabelStyle: fontProvider.getTextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                // UPDATED: FontProvider
                unselectedLabelStyle: fontProvider.getTextStyle(fontSize: 14),
                items: [
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.mail_outline),
                    activeIcon: const Icon(Icons.mail),
                    label: tr('home_envelopes_tab'),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.folder_open_outlined),
                    activeIcon: const Icon(Icons.folder_copy),
                    label: tr('home_groups_tab'),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.account_balance_wallet_outlined),
                    activeIcon: const Icon(Icons.account_balance_wallet),
                    label: tr('home_budget_tab'),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.calendar_today_outlined),
                    activeIcon: const Icon(Icons.calendar_today),
                    label: tr('home_calendar_tab'),
                  ),
                ],
                currentIndex: 0,
                onTap: (index) {
                  // Navigate back to home with selected index
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
              floatingActionButton: _buildThemedFAB(context, envelope, theme),
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.endFloat,
            );
          },
        );
      },
    );
  }

  // Month navigation bar with arrows
  Widget _buildMonthNavigationBar(ThemeData theme) {
    final monthName = DateFormat('MMMM yyyy').format(_viewingMonth);
    final isCurrentMonth = _isCurrentMonth();
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        // FIX: withOpacity -> withValues
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          // Previous month button
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _previousMonth,
            color: theme.colorScheme.primary,
          ),

          // Current month label (tappable to return to current month)
          Expanded(
            child: InkWell(
              onTap: isCurrentMonth ? null : _goToCurrentMonth,
              child: Column(
                children: [
                  Text(
                    monthName,
                    // UPDATED: FontProvider
                    style: fontProvider.getTextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (!isCurrentMonth)
                    Text(
                      tr('envelope_return_current_month'),
                      style: TextStyle(
                        fontSize: 11,
                        // FIX: withOpacity -> withValues
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
          ),

          // Next month button (disabled if current or future)
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: isCurrentMonth ? null : _nextMonth,
            color: isCurrentMonth
                // FIX: withOpacity -> withValues
                ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
                : theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }

  // Themed FAB with SpeedDial
  Widget _buildThemedFAB(
    BuildContext context,
    Envelope envelope,
    ThemeData theme,
  ) {
    // Use consistent icon color across all buttons
    final iconColor = theme.colorScheme.onPrimaryContainer;
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return SpeedDial(
      icon: Icons.add,
      activeIcon: Icons.close,
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: theme.colorScheme.onPrimary,
      overlayColor: Colors.black,
      overlayOpacity: 0.5,
      spacing: 12,
      spaceBetweenChildren: 8,
      buttonSize: const Size(56, 56),
      childrenButtonSize: const Size(56, 56),
      renderOverlay: true,
      children: [
        SpeedDialChild(
          child: Icon(Icons.add_circle, color: iconColor),
          backgroundColor: theme.colorScheme.primaryContainer,
          label: tr('action_add_money'),
          // UPDATED: FontProvider
          labelStyle: fontProvider.getTextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          labelBackgroundColor: theme.colorScheme.surface,
          onTap: () => _showDepositModal(context, envelope),
        ),
        SpeedDialChild(
          child: Icon(Icons.remove_circle, color: iconColor),
          backgroundColor: theme.colorScheme.primaryContainer,
          label: tr('action_take_money'),
          // UPDATED: FontProvider
          labelStyle: fontProvider.getTextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          labelBackgroundColor: theme.colorScheme.surface,
          onTap: () => _showWithdrawModal(context, envelope),
        ),
        SpeedDialChild(
          child: Icon(Icons.swap_horiz, color: iconColor),
          backgroundColor: theme.colorScheme.primaryContainer,
          label: tr('action_move_money'),
          // UPDATED: FontProvider
          labelStyle: fontProvider.getTextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          labelBackgroundColor: theme.colorScheme.surface,
          onTap: () => _showTransferModal(context, envelope),
        ),
        SpeedDialChild(
          child: Icon(Icons.calculate, color: iconColor),
          backgroundColor: theme.colorScheme.primaryContainer,
          label: tr('calculator'),
          // UPDATED: FontProvider
          labelStyle: fontProvider.getTextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          labelBackgroundColor: theme.colorScheme.surface,
          onTap: () => _showCalculator(context),
        ),
      ],
    );
  }

  void _showSettings(BuildContext context, Envelope envelope) {
    final groupRepo = GroupRepo(widget.repo.db, widget.repo);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: EnvelopeSettingsSheet(
          envelopeId: envelope.id,
          repo: widget.repo,
          groupRepo: groupRepo,
        ),
      ),
    );
  }

  void _showDepositModal(BuildContext context, Envelope envelope) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: DepositModal(
          repo: widget.repo,
          envelopeId: envelope.id,
          envelopeName: envelope.name,
        ),
      ),
    );
  }

  void _showWithdrawModal(BuildContext context, Envelope envelope) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: WithdrawModal(
          repo: widget.repo,
          envelopeId: envelope.id,
          envelopeName: envelope.name,
          currentAmount: envelope.currentAmount,
        ),
      ),
    );
  }

  void _showTransferModal(BuildContext context, Envelope envelope) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: TransferModal(
          repo: widget.repo,
          sourceEnvelopeId: envelope.id,
          sourceEnvelopeName: envelope.name,
          currentAmount: envelope.currentAmount,
        ),
      ),
    );
  }

  void _showCalculator(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const Dialog(child: CalculatorWidget()),
    );
  }
}

// Binder info row (shown below header if envelope is in a binder)
class _BinderInfoRow extends StatelessWidget {
  const _BinderInfoRow({required this.binderId, required this.repo});

  final String binderId;
  final EnvelopeRepo repo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupRepo = GroupRepo(repo.db, repo);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return FutureBuilder<EnvelopeGroup?>(
      future: _getBinder(groupRepo),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final binder = snapshot.data!;
        final binderColor = GroupColors.getThemedColor(
          binder.colorName,
          theme.colorScheme,
        );

        return InkWell(
          onTap: () async {
            final binderData = await _getBinder(groupRepo);
            if (binderData != null && context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GroupDetailScreen(
                    group: binderData,
                    groupRepo: groupRepo,
                    envelopeRepo: repo,
                  ),
                ),
              );
            }
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              // FIX: withOpacity -> withValues
              color: binderColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              // FIX: withOpacity -> withValues
              border: Border.all(color: binderColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    // FIX: withOpacity -> withValues
                    color: binderColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.folder, size: 20, color: binderColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('envelope_in_binder'),
                        style: TextStyle(
                          fontSize: 12,
                          // FIX: withOpacity -> withValues
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (binder.emoji != null) ...[
                            Text(
                              binder.emoji!,
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              binder.name,
                              // UPDATED: FontProvider
                              style: fontProvider.getTextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: binderColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 16, color: binderColor),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<EnvelopeGroup?> _getBinder(GroupRepo groupRepo) async {
    final snapshot = await groupRepo.groupsCol().doc(binderId).get();
    if (!snapshot.exists) return null;
    return EnvelopeGroup.fromFirestore(snapshot);
  }
}
