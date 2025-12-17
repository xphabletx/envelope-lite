// lib/screens/budget_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/account_repo.dart';
import '../services/envelope_repo.dart';
import '../services/group_repo.dart';
import '../services/scheduled_payment_repo.dart';
import '../providers/font_provider.dart';
import '../widgets/budget/overview_cards.dart';
import '../widgets/budget/projection_tool.dart';
import '../models/pay_day_settings.dart';
import '../widgets/budget/scenario_editor_modal.dart';
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
        title: Text(
          'Budget',
          style: fontProvider.getTextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
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

            const SizedBox(height: 24),

            // Scenario Planner Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton.icon(
                onPressed: () async {
                  // Load pay settings
                  final userId = repo.currentUserId;
                  final settingsDoc = await repo.db
                      .collection('users')
                      .doc(userId)
                      .collection('payDaySettings')
                      .doc('settings')
                      .get();

                  PayDaySettings paySettings;
                  if (settingsDoc.exists) {
                    paySettings = PayDaySettings.fromFirestore(settingsDoc);
                  } else {
                    paySettings = PayDaySettings(userId: userId);
                  }

                  if (!context.mounted) return;

                  // Open scenario editor
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ScenarioEditorModal(
                        accountRepo: accountRepo,
                        envelopeRepo: repo,
                        groupRepo: groupRepo,
                        initialStartDate: DateTime.now(),
                        initialEndDate: DateTime.now().add(
                          const Duration(days: 90),
                        ),
                        paySettings: paySettings,
                      ),
                      fullscreenDialog: true,
                    ),
                  );
                },
                icon: const Icon(Icons.science, size: 24),
                label: Text(
                  'What-If Scenario Planner',
                  style: fontProvider.getTextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 20,
                  ),
                  backgroundColor: theme.colorScheme.secondary,
                  minimumSize: const Size(double.infinity, 56),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // SECTION 2: Projection Tool
            // NEW: Pass the initialProjectionDate down
            ProjectionTool(
              accountRepo: accountRepo,
              envelopeRepo: repo,
              initialDate: initialProjectionDate, // NEW
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
