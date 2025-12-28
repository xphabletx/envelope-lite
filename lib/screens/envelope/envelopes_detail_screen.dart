// lib/screens/envelope/envelopes_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import '../../../models/envelope.dart';
import '../../../models/envelope_group.dart';
import '../../../models/transaction.dart';
import '../../../services/envelope_repo.dart';
import '../../../services/group_repo.dart';
import '../../../services/account_repo.dart';
import '../../../services/scheduled_payment_repo.dart'; // NEW IMPORT
import '../../../utils/target_helper.dart';
import 'envelope_transaction_list.dart';
import '../group_detail_screen.dart';
import 'modals/deposit_modal.dart';
import 'modals/withdraw_modal.dart';
import 'modals/transfer_modal.dart';
import '../../../services/localization_service.dart';
import '../../../providers/font_provider.dart';
import '../../../providers/locale_provider.dart';
import '../../../providers/time_machine_provider.dart';
import '../../utils/calculator_helper.dart';
import 'modern_envelope_header_card.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_themes.dart';
import '../../widgets/time_machine_indicator.dart';

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
  late DateTime _viewingMonth;
  final _scrollController = ScrollController();
  double _savedScrollOffset = 0.0;

  // TUTORIAL KEYS
  final GlobalKey _envelopeCardKey = GlobalKey();
  final GlobalKey _transactionListKey = GlobalKey();
  final GlobalKey _fabKey = GlobalKey();

  // Initialize repos once
  late final GroupRepo _groupRepo;
  late final AccountRepo _accountRepo;
  late final ScheduledPaymentRepo _scheduledPaymentRepo;

  @override
  void initState() {
    super.initState();
    _viewingMonth = DateTime.now();
    _scrollController.addListener(_saveScrollOffset);

    // Initialize repos once
    _groupRepo = GroupRepo(widget.repo);
    _accountRepo = AccountRepo(widget.repo);
    _scheduledPaymentRepo = ScheduledPaymentRepo(widget.repo.currentUserId);

    _checkTutorial();
    _checkPartnerEnvelope();
  }

  Future<void> _checkTutorial() async {
    // Tutorial logic placeholder
  }

  Future<void> _checkPartnerEnvelope() async {
    final envelopeStream = widget.repo.envelopeStream(widget.envelopeId);
    final envelope = await envelopeStream.first;

    if (envelope.userId != widget.repo.currentUserId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You can only view or transfer funds to other users\' envelopes.'),
              duration: Duration(seconds: 4),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });
    }
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
    setState(() => _viewingMonth = DateTime.now());
  }

  bool _isCurrentMonth() {
    final now = DateTime.now();
    return _viewingMonth.year == now.year && _viewingMonth.month == now.month;
  }

  void _onBottomNavTap(int index) {
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil('/home', (route) => false, arguments: index);
  }

  Future<void> _navigateToEnvelope(String envelopeId) async {
    // Replace current route with new envelope detail
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => EnvelopeDetailScreen(
          envelopeId: envelopeId,
          repo: widget.repo,
        ),
      ),
    );
  }

  void _handleHorizontalDragEnd(
    DragEndDetails details,
    List<Envelope> sortedEnvelopes,
  ) {
    // Find current envelope index
    final currentIndex = sortedEnvelopes.indexWhere((e) => e.id == widget.envelopeId);
    if (currentIndex == -1) return;

    // Check swipe velocity
    const swipeThreshold = 500.0; // pixels per second

    if (details.primaryVelocity != null) {
      if (details.primaryVelocity! > swipeThreshold) {
        // Swipe right - go to previous envelope
        if (currentIndex > 0) {
          _navigateToEnvelope(sortedEnvelopes[currentIndex - 1].id);
        }
      } else if (details.primaryVelocity! < -swipeThreshold) {
        // Swipe left - go to next envelope
        if (currentIndex < sortedEnvelopes.length - 1) {
          _navigateToEnvelope(sortedEnvelopes[currentIndex + 1].id);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final timeMachine = Provider.of<TimeMachineProvider>(context);

    return StreamBuilder<Envelope>(
      stream: widget.repo.envelopeStream(widget.envelopeId),
      builder: (context, envelopeSnapshot) {
        if (envelopeSnapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading envelope',
                    style: fontProvider.getTextStyle(fontSize: 20),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    envelopeSnapshot.error.toString(),
                    style: const TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        if (!envelopeSnapshot.hasData) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final realEnvelope = envelopeSnapshot.data!;

        // Apply Time Machine projection if active
        final envelope = timeMachine.isActive
            ? timeMachine.getProjectedEnvelope(realEnvelope)
            : realEnvelope;

        return StreamBuilder<List<Envelope>>(
          stream: widget.repo.envelopesStream(),
          builder: (context, envelopesSnapshot) {
            final allEnvelopes = envelopesSnapshot.data ?? [];
            // Sort by name (same as home screen default)
            final sortedEnvelopes = allEnvelopes.toList()
              ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

            return StreamBuilder<List<Transaction>>(
              stream: widget.repo.transactionsForEnvelope(widget.envelopeId),
              builder: (context, txSnapshot) {
                final realTransactions = txSnapshot.data ?? [];

                // If in Time Machine mode, add future transactions
                final allTransactions = timeMachine.isActive
                    ? [
                        ...realTransactions,
                        ...timeMachine.getFutureTransactions(widget.envelopeId),
                      ]
                    : realTransactions;

                // Filter transactions logic
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

                return PopScope(
                  canPop: true,
                  child: GestureDetector(
                    onHorizontalDragEnd: (details) => _handleHorizontalDragEnd(details, sortedEnvelopes),
                    child: Scaffold(
                backgroundColor: theme.scaffoldBackgroundColor,
                appBar: AppBar(
                  backgroundColor: theme.scaffoldBackgroundColor,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                title: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    envelope.name,
                    style: fontProvider.getTextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              body: SingleChildScrollView(
                key: const PageStorageKey<String>('envelope_detail_scroll'),
                controller: _scrollController,
                child: Column(
                  children: [
                    // Time Machine Indicator
                    const TimeMachineIndicator(),

                    // ---------------------------------------------------
                    // 1. THE VECTOR ENVELOPE (CustomPaint)
                    // ---------------------------------------------------
                    ModernEnvelopeHeaderCard(
                      key: _envelopeCardKey,
                      envelope: envelope,
                      repo: widget.repo,
                      groupRepo: _groupRepo,
                      accountRepo: _accountRepo,
                      scheduledPaymentRepo: _scheduledPaymentRepo,
                    ),

                    // ---------------------------------------------------
                    // 2. TARGET STATUS CARD
                    // ---------------------------------------------------
                    if (envelope.targetDate != null &&
                        (envelope.targetAmount ?? 0) > envelope.currentAmount)
                      _TargetStatusCard(envelope: envelope),

                    // ---------------------------------------------------
                    // 3. BINDER / GROUP INFO
                    // ---------------------------------------------------
                    const SizedBox(height: 16),
                    if (envelope.groupId != null)
                      _BinderInfoRow(
                        binderId: envelope.groupId!,
                        repo: widget.repo,
                      ),

                    // ---------------------------------------------------
                    // 4. MONTH NAVIGATION & LIST
                    // ---------------------------------------------------
                    if (envelope.groupId != null) const SizedBox(height: 16),
                    _buildMonthNavigationBar(theme),
                    const SizedBox(height: 8),
                    EnvelopeTransactionList(
                      key: _transactionListKey, // TUTORIAL KEY
                      transactions: monthTransactions,
                      onTransactionTap: (tx) {},
                    ),
                    const SizedBox(height: 140),
                  ],
                ),
              ),

              bottomNavigationBar: BottomNavigationBar(
                backgroundColor: theme.scaffoldBackgroundColor,
                selectedItemColor: theme.colorScheme.primary,
                unselectedItemColor: Colors.grey.shade600,
                elevation: 8,
                type: BottomNavigationBarType.fixed,
                selectedLabelStyle: fontProvider.getTextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: fontProvider.getTextStyle(fontSize: 14),
                currentIndex: 0,
                onTap: _onBottomNavTap,
                items: [
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.mail_outline),
                    activeIcon: const Icon(Icons.mail),
                    label: tr('home_envelopes_tab'),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.folder_open_outlined),
                    activeIcon: const Icon(Icons.folder_copy),
                    label: tr('home_binders_tab'),
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
              ),
              floatingActionButton: timeMachine.isActive
                  ? null
                  : _buildThemedFAB(context, envelope, theme),
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.endFloat,
            ),
          ),
        );
      },
    );
          },
        );
      },
    );
  }

  void _showCalculator(BuildContext context) async {
    await CalculatorHelper.showCalculator(context);
  }

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
        border: Border.all(
          color: theme.colorScheme.outline.withAlpha(51),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _previousMonth,
            color: theme.colorScheme.primary,
          ),
          Expanded(
            child: InkWell(
              onTap: isCurrentMonth ? null : _goToCurrentMonth,
              child: Column(
                children: [
                  Text(
                    monthName,
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
                        color: theme.colorScheme.onSurface.withAlpha(128),
                      ),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: isCurrentMonth ? null : _nextMonth,
            color: isCurrentMonth
                ? theme.colorScheme.onSurface.withAlpha(77)
                : theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildThemedFAB(
    BuildContext context,
    Envelope envelope,
    ThemeData theme,
  ) {
    final iconColor = theme.colorScheme.onPrimaryContainer;
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final isOwner = envelope.userId == widget.repo.currentUserId;

    // Build children list conditionally
    final children = <SpeedDialChild>[
      if (isOwner) ...[
        SpeedDialChild(
          child: Icon(Icons.add_circle, color: iconColor),
          backgroundColor: theme.colorScheme.primaryContainer,
          label: tr('action_add_money'),
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
          labelStyle: fontProvider.getTextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          labelBackgroundColor: theme.colorScheme.surface,
          onTap: () => _showWithdrawModal(context, envelope),
        ),
      ],
      SpeedDialChild(
        child: Icon(Icons.swap_horiz, color: iconColor),
        backgroundColor: theme.colorScheme.primaryContainer,
        label: tr('action_move_money'),
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
        labelStyle: fontProvider.getTextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        labelBackgroundColor: theme.colorScheme.surface,
        onTap: () => _showCalculator(context),
      ),
    ];

    return SpeedDial(
      key: _fabKey, // TUTORIAL KEY
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
      children: children,
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
}

class _TargetStatusCard extends StatelessWidget {
  const _TargetStatusCard({required this.envelope});
  final Envelope envelope;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Provider.of<LocaleProvider>(context, listen: false);
    final suggestion = TargetHelper.getSuggestionText(envelope, locale.currencySymbol);
    final daysLeft = TargetHelper.getDaysRemaining(envelope);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withAlpha(128),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.secondary.withAlpha(77),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.track_changes, color: theme.colorScheme.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  suggestion,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
                Text(
                  daysLeft > 0 ? '$daysLeft days remaining' : 'Target due',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSecondaryContainer.withAlpha(204),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BinderInfoRow extends StatefulWidget {
  const _BinderInfoRow({required this.binderId, required this.repo});

  final String binderId;
  final EnvelopeRepo repo;

  @override
  State<_BinderInfoRow> createState() => _BinderInfoRowState();
}

class _BinderInfoRowState extends State<_BinderInfoRow> {
  late final GroupRepo _groupRepo;

  @override
  void initState() {
    super.initState();
    _groupRepo = GroupRepo(widget.repo);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return FutureBuilder<EnvelopeGroup?>(
      future: _getBinder(_groupRepo),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final binder = snapshot.data!;
        final binderColorOption =
            ThemeBinderColors.getColorsForTheme(themeProvider.currentThemeId)[binder.colorIndex];
        final binderColor = binderColorOption.binderColor;

        return InkWell(
          onTap: () async {
            final binderData = await _getBinder(_groupRepo);
            if (binderData != null && context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GroupDetailScreen(
                    group: binderData,
                    groupRepo: _groupRepo,
                    envelopeRepo: widget.repo,
                  ),
                ),
              );
            }
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: binderColor.withAlpha(38),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: binderColor.withAlpha(102)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: binderColor.withAlpha(77),
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
                          color: theme.colorScheme.onSurface.withAlpha(153),
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
    // Use getGroupAsync to read from Hive (works in both solo and workspace mode)
    return await groupRepo.getGroupAsync(widget.binderId);
  }
}