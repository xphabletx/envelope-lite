// lib/screens/pay_day/pay_day_cockpit.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/pay_day_cockpit_provider.dart';
import '../../providers/font_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/envelope_repo.dart';
import '../../services/group_repo.dart';
import '../../services/account_repo.dart';
import '../../widgets/common/smart_text_field.dart';
import '../../utils/calculator_helper.dart';
import 'dart:async';

class PayDayCockpit extends StatefulWidget {
  const PayDayCockpit({
    super.key,
    required this.repo,
    required this.groupRepo,
    required this.accountRepo,
  });

  final EnvelopeRepo repo;
  final GroupRepo groupRepo;
  final AccountRepo accountRepo;

  @override
  State<PayDayCockpit> createState() => _PayDayCockpitState();
}

class _PayDayCockpitState extends State<PayDayCockpit> {
  late PayDayCockpitProvider _provider;
  final TextEditingController _amountController = TextEditingController(text: '0.00');
  final FocusNode _amountFocus = FocusNode();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _provider = PayDayCockpitProvider(
      envelopeRepo: widget.repo,
      groupRepo: widget.groupRepo,
      accountRepo: widget.accountRepo,
      userId: widget.repo.currentUserId,
    );
    _provider.initialize().then((_) {
      if (_provider.externalInflow > 0) {
        setState(() {
          _amountController.text = _provider.externalInflow.toStringAsFixed(2);
        });
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocus.dispose();
    _debounceTimer?.cancel();
    _provider.dispose();
    super.dispose();
  }

  void _onAmountChanged(String value) {
    // Debounce the updates (50ms as specified)
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 50), () {
      final amount = double.tryParse(value.replaceAll(',', '')) ?? 0.0;
      _provider.updateExternalInflow(amount);
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
            body: _buildPhaseContent(theme, fontProvider, provider),
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

  Widget _buildPhaseContent(
    ThemeData theme,
    FontProvider fontProvider,
    PayDayCockpitProvider provider,
  ) {
    switch (provider.currentPhase) {
      case CockpitPhase.amountEntry:
        return _buildPhase1AmountEntry(theme, fontProvider, provider);
      case CockpitPhase.strategyReview:
        return _buildPhase2StrategyReview(theme, fontProvider, provider);
      case CockpitPhase.stuffingExecution:
        return _buildPhase3StuffingExecution(theme, fontProvider, provider);
      case CockpitPhase.success:
        return _buildPhase4Success(theme, fontProvider, provider);
    }
  }

  // ==========================================================================
  // PHASE 1: AMOUNT ENTRY (The Source)
  // ==========================================================================

  Widget _buildPhase1AmountEntry(
    ThemeData theme,
    FontProvider fontProvider,
    PayDayCockpitProvider provider,
  ) {
    final locale = Provider.of<LocaleProvider>(context);
    final media = MediaQuery.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: media.size.height * 0.05),

            // Money icon "Outside the Wall"
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.green.shade300,
                  width: 3,
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    '💰',
                    style: TextStyle(fontSize: 100),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'OUTSIDE THE WALL',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Title
            Text(
              'External Inflow',
              style: fontProvider.getTextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Subtitle
            Text(
              provider.isAccountMode
                  ? 'Money arriving to ${provider.defaultAccount?.name ?? 'your account'}'
                  : 'Money arriving to the Horizon Pool',
              style: fontProvider.getTextStyle(
                fontSize: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 48),

            // Amount input with FittedBox
            SizedBox(
              height: 120,
              child: FittedBox(
                fit: BoxFit.contain,
                child: SmartTextField(
                  controller: _amountController,
                  focusNode: _amountFocus,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: fontProvider.getTextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.secondary,
                  ),
                  onChanged: _onAmountChanged,
                  decoration: InputDecoration(
                    prefixText: '${locale.currencySymbol} ',
                    prefixStyle: fontProvider.getTextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.secondary,
                    ),
                    suffixIcon: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.calculate,
                          color: theme.colorScheme.onPrimary,
                        ),
                        onPressed: () async {
                          final result = await CalculatorHelper.showCalculator(context);
                          if (result != null && mounted) {
                            setState(() {
                              _amountController.text = result;
                              _onAmountChanged(result);
                            });
                          }
                        },
                        tooltip: 'Open Calculator',
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 3,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                  ),
                  onTap: () {
                    _amountController.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: _amountController.text.length,
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 48),

            // Mode indicator
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    provider.isAccountMode ? Icons.account_balance : Icons.wallet,
                    color: theme.colorScheme.primary,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      provider.isAccountMode
                          ? 'Account Mode: Money flows to ${provider.defaultAccount?.name ?? 'account'}, then to envelopes'
                          : 'Simple Mode: Money flows directly to Horizon Pool',
                      style: fontProvider.getTextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),

            // Continue button
            FilledButton(
              onPressed: () => provider.proceedToStrategyReview(),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                backgroundColor: theme.colorScheme.secondary,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Review Strategy',
                    style: fontProvider.getTextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.arrow_forward,
                    size: 28,
                    color: Colors.white,
                  ),
                ],
              ),
            ),

            if (provider.error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Text(
                  provider.error!,
                  style: TextStyle(
                    color: Colors.red.shade900,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // PHASE 2: STRATEGY REVIEW (The Filter)
  // ==========================================================================

  Widget _buildPhase2StrategyReview(
    ThemeData theme,
    FontProvider fontProvider,
    PayDayCockpitProvider provider,
  ) {
    final locale = Provider.of<LocaleProvider>(context);
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);

    return Column(
      children: [
        // Waterfall Header (Sticky)
        _buildWaterfallHeader(theme, fontProvider, provider, currency),

        // Scrollable content
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Summary
              Text(
                'Review your cash flow strategy for this pay day. These are your automatic allocations.',
                style: fontProvider.getTextStyle(
                  fontSize: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),

              const SizedBox(height: 24),

              // Autopilot allocations summary
              Text(
                '${provider.allocations.length} envelopes ready for fueling',
                style: fontProvider.getTextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),

              const SizedBox(height: 16),

              // Add Horizon Boosts button
              OutlinedButton.icon(
                onPressed: () {
                  // TODO: Show modal to add temporary binders/envelopes
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Add Horizon Boosts - Coming in next iteration')),
                  );
                },
                icon: const Icon(Icons.add_circle_outline),
                label: Text(
                  'Add Horizon Boosts',
                  style: fontProvider.getTextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 48),
            ],
          ),
        ),

        // Bottom button
        _buildStrategyReviewButton(theme, fontProvider, provider),
      ],
    );
  }

  Widget _buildWaterfallHeader(
    ThemeData theme,
    FontProvider fontProvider,
    PayDayCockpitProvider provider,
    NumberFormat currency,
  ) {
    final isWarning = provider.isDippingIntoReserves;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isWarning
              ? [Colors.red.shade100, Colors.red.shade50]
              : [
                  theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
                ],
        ),
        border: Border(
          bottom: BorderSide(
            color: isWarning ? Colors.red.shade700 : theme.colorScheme.primary,
            width: 3,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Inflow',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      currency.format(provider.externalInflow),
                      style: fontProvider.getTextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Reserved for Autopilot',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      currency.format(provider.autopilotReserve),
                      style: fontProvider.getTextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Available Fuel',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    Text(
                      currency.format(provider.availableFuel),
                      style: fontProvider.getTextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (isWarning) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '⚠️ Using Reserved Funds / Buffer',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
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

  Widget _buildStrategyReviewButton(
    ThemeData theme,
    FontProvider fontProvider,
    PayDayCockpitProvider provider,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: FilledButton(
          onPressed: provider.canProceedToStuffing()
              ? () => provider.proceedToStuffing()
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.secondary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.rocket_launch, size: 28, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                'Fuel the Horizons!',
                style: fontProvider.getTextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // PHASE 3: STUFFING EXECUTION (The Waterfall)
  // ==========================================================================

  Widget _buildPhase3StuffingExecution(
    ThemeData theme,
    FontProvider fontProvider,
    PayDayCockpitProvider provider,
  ) {
    // Start the execution immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (provider.currentPhase == CockpitPhase.stuffingExecution) {
        provider.executeStuffing();
      }
    });

    final locale = Provider.of<LocaleProvider>(context);
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);

    // Calculate total stuffed so far
    double totalStuffed = 0;
    for (final entry in provider.allocations.entries) {
      totalStuffed += entry.value;
    }

    final remaining = provider.externalInflow - totalStuffed;
    final isOverBudget = remaining < 0;

    return Column(
      children: [
        // Waterfall Drainage Header (Sticky)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isOverBudget
                  ? [Colors.red.shade100, Colors.red.shade50]
                  : [
                      Colors.blue.shade50,
                      Colors.green.shade50,
                    ],
            ),
            border: Border(
              bottom: BorderSide(
                color: isOverBudget ? Colors.red.shade700 : Colors.blue.shade600,
                width: 3,
              ),
            ),
          ),
          child: Column(
            children: [
              // Animated draining fuel
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.water_drop,
                    color: isOverBudget ? Colors.red.shade700 : Colors.blue.shade600,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unallocated Fuel',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 600),
                        tween: Tween(begin: provider.externalInflow, end: remaining),
                        builder: (context, value, child) {
                          return Text(
                            currency.format(value),
                            style: fontProvider.getTextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: value < 0 ? Colors.red.shade700 : Colors.green.shade700,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),

              // Progress bar
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (totalStuffed / provider.externalInflow).clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation(
                    isOverBudget ? Colors.red.shade600 : Colors.blue.shade600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Stuffing progress message
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Fueling your horizons...',
            style: fontProvider.getTextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),

        // Progress indicator
        const Expanded(
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // PHASE 4: SUCCESS (Future Recalibrated)
  // ==========================================================================

  Widget _buildPhase4Success(
    ThemeData theme,
    FontProvider fontProvider,
    PayDayCockpitProvider provider,
  ) {
    final locale = Provider.of<LocaleProvider>(context);
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Time Machine Icon
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.2),
                    theme.colorScheme.secondary.withValues(alpha: 0.2),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Text(
                '⏰',
                style: TextStyle(fontSize: 80),
              ),
            ),

            const SizedBox(height: 32),

            // Success message
            Text(
              'Future Recalibrated',
              style: fontProvider.getTextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            Text(
              'Your Horizons are now closer',
              style: fontProvider.getTextStyle(
                fontSize: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

            // Top 3 horizons moved forward
            if (provider.topHorizons.isNotEmpty) ...[
              Text(
                'Top Horizons Advanced',
                style: fontProvider.getTextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              ...provider.topHorizons.map((impact) => _buildHorizonImpactCard(
                theme,
                fontProvider,
                currency,
                impact,
              )),
            ],

            const Spacer(),

            // Done button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.secondary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Done!',
                  style: fontProvider.getTextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizonImpactCard(
    ThemeData theme,
    FontProvider fontProvider,
    NumberFormat currency,
    EnvelopeHorizonImpact impact,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Text(
            impact.envelope.emoji ?? '📨',
            style: const TextStyle(fontSize: 32),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  impact.envelope.name,
                  style: fontProvider.getTextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '🔥 ${impact.daysSaved} days closer',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Text(
            currency.format(impact.stuffedAmount),
            style: fontProvider.getTextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
