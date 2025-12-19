// lib/screens/accounts/account_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/account_repo.dart';
import '../../services/envelope_repo.dart';
import '../../models/account.dart';
import '../../providers/font_provider.dart';
import '../../widgets/accounts/account_editor_modal.dart';
import './account_detail_screen.dart';
import '../../widgets/accounts/account_card.dart';

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
                    color: theme.colorScheme.onSurface.withAlpha(77),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No accounts yet',
                    style: fontProvider.getTextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface.withAlpha(153),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to create your first account',
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.onSurface.withAlpha(128),
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
              return AccountCard(
                account: account,
                accountRepo: accountRepo,
                envelopeRepo: envelopeRepo,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AccountDetailScreen(
                        account: account,
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
