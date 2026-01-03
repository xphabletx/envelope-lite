// lib/screens/budget_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/account_repo.dart';
import '../services/envelope_repo.dart';
import '../services/group_repo.dart';
import '../services/scheduled_payment_repo.dart';
import '../services/pay_day_settings_service.dart';
import '../providers/font_provider.dart';
import '../widgets/budget/overview_cards.dart';
import '../models/pay_day_settings.dart';
import '../widgets/budget/time_machine_screen.dart';
import '../widgets/time_machine_indicator.dart';
import '../utils/responsive_helper.dart';
// Note: account_list_screen.dart import removed since it's no longer used here

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({
    super.key,
    required this.repo,
    this.initialProjectionDate,
  });

  final EnvelopeRepo repo;
  final DateTime? initialProjectionDate;

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  // Initialize repos once
  late final AccountRepo accountRepo;
  late final GroupRepo groupRepo;
  late final ScheduledPaymentRepo paymentRepo;

  @override
  void initState() {
    super.initState();
    accountRepo = AccountRepo(widget.repo);
    groupRepo = GroupRepo(widget.repo);
    paymentRepo = ScheduledPaymentRepo(widget.repo.currentUserId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final responsive = context.responsive;
    final isLandscape = responsive.isLandscape;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: isLandscape
          ? PreferredSize(
              preferredSize: const Size.fromHeight(0),
              child: AppBar(
                toolbarHeight: 0,
                backgroundColor: theme.scaffoldBackgroundColor,
                elevation: 0,
              ),
            )
          : AppBar(
              backgroundColor: theme.scaffoldBackgroundColor,
              elevation: 0,
              title: FittedBox(
                child: Text(
                  'Budget',
                  style: fontProvider.getTextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
      body: isLandscape
          ? _buildLandscapeLayout(theme, fontProvider)
          : _buildPortraitLayout(theme, fontProvider),
    );
  }

  Widget _buildPortraitLayout(ThemeData theme, FontProvider fontProvider) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TimeMachineIndicator(),
          const SizedBox(height: 16),
          BudgetOverviewCards(
            accountRepo: accountRepo,
            envelopeRepo: widget.repo,
            paymentRepo: paymentRepo,
          ),
          const SizedBox(height: 32),
          _buildDivider(theme),
          const SizedBox(height: 32),
          _buildTimeMachineButton(theme, fontProvider),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildLandscapeLayout(ThemeData theme, FontProvider fontProvider) {
    return Column(
      children: [
        const TimeMachineIndicator(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column: Time Machine
              Expanded(
                flex: 1,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildDivider(theme),
                      const SizedBox(height: 24),
                      _buildTimeMachineButton(theme, fontProvider),
                    ],
                  ),
                ),
              ),
              // Right column: Overview Cards
              Expanded(
                flex: 1,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: BudgetOverviewCards(
                    accountRepo: accountRepo,
                    envelopeRepo: widget.repo,
                    paymentRepo: paymentRepo,
                    useVerticalLayout: true, // Vertical scroll in landscape
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: theme.colorScheme.outline)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'FUTURE PROJECTION',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
          Expanded(child: Divider(color: theme.colorScheme.outline)),
        ],
      ),
    );
  }

  Widget _buildTimeMachineButton(ThemeData theme, FontProvider fontProvider) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.secondaryContainer,
              theme.colorScheme.secondaryContainer.withValues(alpha: 0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.secondary.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: 2,
            ),
            BoxShadow(
              color: theme.colorScheme.secondary.withValues(alpha: 0.1),
              blurRadius: 40,
              offset: const Offset(0, 12),
              spreadRadius: 4,
            ),
          ],
          border: Border.all(
            width: 3,
            color: theme.colorScheme.secondary.withValues(alpha: 0.5),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(21),
            border: Border.all(
              width: 2,
              color: theme.colorScheme.onSecondaryContainer.withValues(
                alpha: 0.2,
              ),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                final userId = widget.repo.currentUserId;
                final payDayService = PayDaySettingsService(widget.repo.db, userId);

                debugPrint('[BudgetScreen] Loading pay day settings for time machine...');
                final paySettings = await payDayService.getPayDaySettings();
                debugPrint('[BudgetScreen] Pay day settings loaded: ${paySettings?.nextPayDate}');

                if (!context.mounted) return;

                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TimeMachineScreen(
                      accountRepo: accountRepo,
                      envelopeRepo: widget.repo,
                      groupRepo: groupRepo,
                      paySettings: paySettings ?? PayDaySettings(userId: userId),
                      scrollToSettings: true,
                    ),
                    fullscreenDialog: true,
                  ),
                );
              },
              borderRadius: BorderRadius.circular(21),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 28,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.onSecondaryContainer
                            .withValues(alpha: 0.15),
                        border: Border.all(
                          color: theme.colorScheme.onSecondaryContainer
                              .withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.access_time,
                        size: 56,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Time Machine',
                      style: fontProvider.getTextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'View your future finances',
                      style: TextStyle(
                        fontSize: 16,
                        color: theme.colorScheme.onSecondaryContainer
                            .withValues(alpha: 0.8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
