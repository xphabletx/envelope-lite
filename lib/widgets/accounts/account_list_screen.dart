// lib/screens/accounts/account_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/account_repo.dart';
import '../../services/envelope_repo.dart';
import '../../models/account.dart';
import '../../providers/font_provider.dart';
import '../../widgets/accounts/account_editor_modal.dart';
import '../../screens/accounts/account_detail_screen.dart';

class AccountListScreen extends StatelessWidget {
  const AccountListScreen({super.key, required this.envelopeRepo});

  final EnvelopeRepo envelopeRepo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final accountRepo = AccountRepo(envelopeRepo.db, envelopeRepo);

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
          'Accounts',
          style: fontProvider.getTextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
      body: StreamBuilder<List<Account>>(
        stream: accountRepo.accountsStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final accounts = snapshot.data!;

          if (accounts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 80,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No accounts yet',
                    style: fontProvider.getTextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to create your first account',
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final account = accounts[index];
              return _AccountCard(
                account: account,
                accountRepo: accountRepo,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AccountDetailScreen(
                        accountId: account.id,
                        accountRepo: accountRepo,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAccountEditor(context, accountRepo),
        backgroundColor: theme.colorScheme.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAccountEditor(BuildContext context, AccountRepo accountRepo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AccountEditorModal(accountRepo: accountRepo),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.accountRepo,
    required this.onTap,
  });

  final Account account;
  final AccountRepo accountRepo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final currency = NumberFormat.currency(symbol: '£');

    return FutureBuilder<double>(
      future: accountRepo.getAssignedAmount(account.id),
      builder: (context, snapshot) {
        final assigned = snapshot.data ?? 0.0;
        final available = account.currentBalance - assigned;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Material(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            elevation: 2,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Emoji + Name + Default star
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer
                                .withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            account.emoji ?? '💳',
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            account.name,
                            style: fontProvider.getTextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (account.isDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Default',
                                  style: fontProvider.getTextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Balance
                    Text(
                      'Balance',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currency.format(account.currentBalance),
                      style: fontProvider.getTextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Assigned & Available
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Assigned',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currency.format(assigned),
                                style: fontProvider.getTextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.2,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Available ✨',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currency.format(available),
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
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
