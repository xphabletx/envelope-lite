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
// Note: account_list_screen.dart import removed since it's no longer used here

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({
    super.key,
    required this.repo,
    this.initialProjectionDate,
  });

  final EnvelopeRepo repo;
  final DateTime? initialProjectionDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    // Initialize repos
    final accountRepo = AccountRepo(repo.db, repo);
    final groupRepo = GroupRepo(repo.db, repo);
    final paymentRepo = ScheduledPaymentRepo(repo.db, repo.currentUserId);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
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
        // ACTIONS REMOVED: Wallet icon has been moved to HomeScreen
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // SECTION 1: Overview Cards
            BudgetOverviewCards(
              accountRepo: accountRepo,
              envelopeRepo: repo,
              paymentRepo: paymentRepo,
            ),

            const SizedBox(height: 32),

            // Divider with label
            Padding(
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
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: theme.colorScheme.outline)),
                ],
              ),
            ),

            const SizedBox(height: 16),

            const SizedBox(height: 16),

            // Time Machine Button - Centered Special Tile
            Center(
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
                        // Load pay settings using PayDaySettingsService
                        final userId = repo.currentUserId;
                        final payDayService = PayDaySettingsService(repo.db, userId);

                        debugPrint('[BudgetScreen] Loading pay day settings for time machine...');
                        final paySettings = await payDayService.getPayDaySettings();
                        debugPrint('[BudgetScreen] Pay day settings loaded: ${paySettings?.nextPayDate}');

                        if (!context.mounted) return;

                        // Open Time Machine screen
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TimeMachineScreen(
                              accountRepo: accountRepo,
                              envelopeRepo: repo,
                              groupRepo: groupRepo,
                              paySettings: paySettings ?? PayDaySettings(userId: userId),
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
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
