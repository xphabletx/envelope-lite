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
import '../../widgets/partner_badge.dart';
import '../../services/workspace_helper.dart';

class AccountListScreen extends StatefulWidget {
  const AccountListScreen({super.key, required this.envelopeRepo});

  final EnvelopeRepo envelopeRepo;

  @override
  State<AccountListScreen> createState() => _AccountListScreenState();
}

class _AccountListScreenState extends State<AccountListScreen> {
  bool _mineOnly = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final accountRepo = AccountRepo(widget.envelopeRepo.db, widget.envelopeRepo);
    final isWorkspace = widget.envelopeRepo.inWorkspace;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: FittedBox(
          child: Text(
            'Accounts',
            style: fontProvider.getTextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        actions: [
          if (isWorkspace)
            Row(
              children: [
                Text(
                  'Mine Only',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Switch(
                  value: _mineOnly,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (val) => setState(() => _mineOnly = val),
                ),
                const SizedBox(width: 16),
              ],
            ),
        ],
      ),
      body: StreamBuilder<List<Account>>(
        stream: accountRepo.accountsStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var accounts = snapshot.data!;

          // Filter accounts based on Mine Only toggle
          if (_mineOnly) {
            accounts = accounts.where((a) => a.userId == widget.envelopeRepo.currentUserId).toList();
          }

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
              final isPartner = account.userId != widget.envelopeRepo.currentUserId;

              return Stack(
                children: [
                  AccountCard(
                    account: account,
                    accountRepo: accountRepo,
                    envelopeRepo: widget.envelopeRepo,
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
                  ),
                  if (isPartner && !_mineOnly)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: FutureBuilder<String>(
                        future: WorkspaceHelper.getUserDisplayName(
                          account.userId,
                          widget.envelopeRepo.currentUserId,
                        ),
                        builder: (context, snapshot) {
                          return PartnerBadge(
                            partnerName: snapshot.data ?? 'Partner',
                            size: PartnerBadgeSize.normal,
                          );
                        },
                      ),
                    ),
                ],
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
