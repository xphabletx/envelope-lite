import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/account.dart';
import '../../models/envelope.dart';
import '../../services/account_repo.dart';
import '../../providers/font_provider.dart';
import '../../widgets/accounts/account_editor_modal.dart';

class AccountDetailScreen extends StatelessWidget {
  const AccountDetailScreen({
    super.key,
    required this.accountId,
    required this.accountRepo,
  });

  final String accountId;
  final AccountRepo accountRepo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return StreamBuilder<Account>(
      stream: accountRepo.accountStream(accountId),
      builder: (context, accountSnapshot) {
        if (!accountSnapshot.hasData) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final account = accountSnapshot.data!;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: theme.scaffoldBackgroundColor,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              account.name,
              style: fontProvider.getTextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            actions: [
              // Edit button
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Edit Account',
                color: theme.colorScheme.onSurface,
                onPressed: () => _showEditModal(context, account),
              ),
              // Delete button
              IconButton(
                icon: const Icon(Icons.delete),
                tooltip: 'Delete Account',
                color: theme.colorScheme.error,
                onPressed: () => _confirmDelete(context, account),
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Account summary card
                _AccountSummaryCard(account: account, accountRepo: accountRepo),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),

                // Linked envelopes section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Linked Envelopes',
                    style: fontProvider.getTextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Envelope list
                FutureBuilder<List<Envelope>>(
                  future: accountRepo.getLinkedEnvelopes(accountId),
                  builder: (context, envelopeSnapshot) {
                    if (!envelopeSnapshot.hasData) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final envelopes = envelopeSnapshot.data!;

                    if (envelopes.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Icon(
                                Icons.mail_outline,
                                size: 64,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No envelopes linked yet',
                                style: fontProvider.getTextStyle(
                                  fontSize: 18,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Link envelopes to this account in envelope settings',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: envelopes.length,
                      itemBuilder: (context, index) {
                        return _EnvelopeTile(envelope: envelopes[index]);
                      },
                    );
                  },
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditModal(BuildContext context, Account account) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          AccountEditorModal(accountRepo: accountRepo, account: account),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Account account) async {
    // Check if any envelopes are linked
    final linkedEnvelopes = await accountRepo.getLinkedEnvelopes(account.id);

    if (!context.mounted) return;

    if (linkedEnvelopes.isNotEmpty) {
      // Show warning - cannot delete
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot Delete Account'),
          content: Text(
            'This account has ${linkedEnvelopes.length} linked envelope(s). '
            'Please unlink or delete them first.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account?'),
        content: Text(
          'Are you sure you want to delete "${account.name}"? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await accountRepo.deleteAccount(account.id);
      if (context.mounted) {
        Navigator.pop(context); // Go back to account list
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Account deleted')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

// Account summary card widget
class _AccountSummaryCard extends StatelessWidget {
  const _AccountSummaryCard({required this.account, required this.accountRepo});

  final Account account;
  final AccountRepo accountRepo;

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
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              // Emoji + Name + Default badge
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    account.emoji ?? '💳',
                    style: const TextStyle(fontSize: 48),
                  ),
                  const SizedBox(height: 8),
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
                          const Icon(Icons.star, size: 16, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            'Default',
                            style: fontProvider.getTextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // Balance
              Text(
                'Balance',
                style: TextStyle(
                  fontSize: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                currency.format(account.currentBalance),
                style: fontProvider.getTextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),

              // Assigned & Available
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Assigned',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currency.format(assigned),
                          style: fontProvider.getTextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Available ✨',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currency.format(available),
                          style: fontProvider.getTextStyle(
                            fontSize: 24,
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
        );
      },
    );
  }
}

// Envelope tile widget
class _EnvelopeTile extends StatelessWidget {
  const _EnvelopeTile({required this.envelope});

  final Envelope envelope;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final currency = NumberFormat.currency(symbol: '£');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            // TODO: Navigate to envelope detail screen
            // Navigator.push(context, MaterialPageRoute(...));
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(
                  envelope.emoji ?? '📨',
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        envelope.name,
                        style: fontProvider.getTextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (envelope.subtitle != null &&
                          envelope.subtitle!.isNotEmpty)
                        Text(
                          envelope.subtitle!,
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  currency.format(envelope.currentAmount),
                  style: fontProvider.getTextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
