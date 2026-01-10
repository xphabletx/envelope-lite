// lib/screens/pay_day/pay_day_cockpit.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../providers/pay_day_cockpit_provider.dart';
import '../../providers/font_provider.dart';
import '../../services/envelope_repo.dart';
import '../../services/group_repo.dart';
import '../../services/account_repo.dart';
import '../../services/scheduled_payment_repo.dart';
import 'phases/amount_entry_view.dart';
import 'phases/strategy_review_view.dart';
import 'phases/stuffing_execution_view.dart';
import 'phases/success_view.dart';

class PayDayCockpit extends StatefulWidget {
  const PayDayCockpit({
    super.key,
    required this.repo,
    required this.groupRepo,
    required this.accountRepo,
    required this.scheduledPaymentRepo,
  });

  final EnvelopeRepo repo;
  final GroupRepo groupRepo;
  final AccountRepo accountRepo;
  final ScheduledPaymentRepo scheduledPaymentRepo;

  @override
  State<PayDayCockpit> createState() => _PayDayCockpitState();
}

class _PayDayCockpitState extends State<PayDayCockpit> {
  late PayDayCockpitProvider _provider;
  final TextEditingController _amountController = TextEditingController(
    text: '0.00',
  );
  final FocusNode _amountFocus = FocusNode();
  Timer? _debounceTimer;

  // Horizon boost tracking
  final Map<String, double> _horizonBoosts =
      {}; // envelopeId -> percentage (0.0-1.0)

  // Temporary allocations (edits for this pay day only)
  final Map<String, double> _tempAllocations = {}; // envelopeId -> amount

  // Calculated boosts to pass to Phase 3 (both implicit and explicit)
  final Map<String, double> _calculatedBoosts =
      {}; // envelopeId -> absolute boost amount

  // Collapsible binders
  final Set<String> _expandedBinderIds = {};

  // Collapsible envelopes within binders (envelopeId -> isExpanded)
  final Map<String, bool> _expandedEnvelopeIds = {};

  // Animation state for waterfall (Phase 3)
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _envelopeKeys =
      {}; // index -> GlobalKey for auto-scroll
  double _initialAccountBalance =
      0.0; // Store the account balance before Phase 3 starts

  @override
  void initState() {
    super.initState();
    _provider = PayDayCockpitProvider(
      envelopeRepo: widget.repo,
      groupRepo: widget.groupRepo,
      accountRepo: widget.accountRepo,
      scheduledPaymentRepo: widget.scheduledPaymentRepo,
      userId: widget.repo.currentUserId,
    );
    _provider.initialize().then((_) {
      if (_provider.externalInflow > 0) {
        setState(() {
          _amountController.text = _provider.externalInflow.toStringAsFixed(2);
        });
      }
      // Initialize temp allocations when entering Phase 2
      _syncTempAllocations();
    });

    // Listen for phase changes to sync temp allocations
    _provider.addListener(_onProviderUpdate);
  }

  void _onProviderUpdate() {
    if (_provider.currentPhase == CockpitPhase.strategyReview) {
      _syncTempAllocations();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocus.dispose();
    _debounceTimer?.cancel();
    _scrollController.dispose();
    _envelopeKeys.clear();
    _provider.removeListener(_onProviderUpdate);
    _provider.dispose();
    super.dispose();
  }

  void _syncTempAllocations() {
    if (!mounted) return;

    setState(() {
      // Copy provider allocations to temp allocations
      _tempAllocations.clear();
      _tempAllocations.addAll(_provider.allocations);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);

    return ChangeNotifierProvider<PayDayCockpitProvider>.value(
      value: _provider,
      child: Consumer<PayDayCockpitProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return Scaffold(
              backgroundColor: theme.scaffoldBackgroundColor,
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          return Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            appBar: _buildAppBar(theme, fontProvider, provider),
            body: _buildPhaseContent(),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    ThemeData theme,
    FontProvider fontProvider,
    PayDayCockpitProvider provider,
  ) {
    String title = 'Pay Day Cockpit';
    switch (provider.currentPhase) {
      case CockpitPhase.amountEntry:
        title = 'External Inflow';
        break;
      case CockpitPhase.strategyReview:
        title = 'Strategy Review';
        break;
      case CockpitPhase.stuffingExecution:
        title = 'Fueling Horizons';
        break;
      case CockpitPhase.success:
        title = 'Future Recalibrated';
        break;
    }

    return AppBar(
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.pop(context),
        tooltip: 'Close',
      ),
      title: Text(
        title,
        style: fontProvider.getTextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildPhaseContent() {
    switch (_provider.currentPhase) {
      case CockpitPhase.amountEntry:
        return const AmountEntryView();

      case CockpitPhase.strategyReview:
        return StrategyReviewView(
          tempAllocations: _tempAllocations,
          horizonBoosts: _horizonBoosts,
          calculatedBoosts: _calculatedBoosts,
          expandedBinderIds: _expandedBinderIds,
          expandedEnvelopeIds: _expandedEnvelopeIds,
          onFuelHorizons: (baseAllocations, boosts) {
            // Callback is handled inside StrategyReviewView
          },
        );

      case CockpitPhase.stuffingExecution:
        return StuffingExecutionView(
          calculatedBoosts: _calculatedBoosts,
          initialAccountBalance: _initialAccountBalance,
          onInitialAccountBalanceSet: (balance) {
            setState(() {
              _initialAccountBalance = balance;
            });
          },
        );

      case CockpitPhase.success:
        return SuccessView(
          calculatedBoosts: _calculatedBoosts,
        );
    }
  }
}
