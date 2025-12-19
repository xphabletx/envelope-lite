import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/account.dart';
import '../../models/envelope.dart';
import '../../services/account_repo.dart';
import '../../services/envelope_repo.dart';
import '../../providers/font_provider.dart';

class AccountDetailScreen extends StatelessWidget {
  const AccountDetailScreen({
    super.key,
    required this.account,
    required this.accountRepo,
    required this.envelopeRepo,
  });

  final Account account;
  final AccountRepo accountRepo;
  final EnvelopeRepo envelopeRepo;

  void _showLinkEnvelopesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _LinkEnvelopesDialog(
        envelopeRepo: envelopeRepo,
        account: account,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final currency = NumberFormat.currency(symbol: '£');

    return Scaffold(
      appBar: AppBar(
        title: FittedBox(child: Text(account.name)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                account.getIconWidget(theme, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    account.name,
                    style: fontProvider.getTextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                if (account.isDefault)
                  const Icon(Icons.star, color: Colors.amber, size: 24),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Balance',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withAlpha(153),
              ),
            ),
            Text(
              currency.format(account.currentBalance),
              style: fontProvider.getTextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<double>(
              future: accountRepo.getAssignedAmount(account.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }
                final assigned = snapshot.data ?? 0.0;
                final available = account.currentBalance - assigned;
                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Assigned',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withAlpha(153),
                            ),
                          ),
                          Text(
                            currency.format(assigned),
                            style: fontProvider.getTextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Available ✨',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withAlpha(153),
                            ),
                          ),
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
                );
              },
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            StreamBuilder<List<Envelope>>(
              stream: envelopeRepo.envelopesStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final linkedEnvelopes = snapshot.data!
                    .where((e) => e.linkedAccountId == account.id)
                    .toList();

                if (linkedEnvelopes.isEmpty) {
                  return Column(
                    children: [
                      const Text('No envelopes linked to this account.'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => _showLinkEnvelopesDialog(context),
                        child: const Text('Link Envelopes'),
                      ),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Linked Envelopes',
                      style: fontProvider.getTextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: linkedEnvelopes.length,
                      itemBuilder: (context, index) {
                        final envelope = linkedEnvelopes[index];
                        return ListTile(
                          leading: envelope.getIconWidget(theme),
                          title: Text(envelope.name),
                          trailing: Text(
                            currency.format(envelope.currentAmount),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => _showLinkEnvelopesDialog(context),
                      child: const Text('Link More Envelopes'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkEnvelopesDialog extends StatefulWidget {
  const _LinkEnvelopesDialog({
    required this.envelopeRepo,
    required this.account,
  });

  final EnvelopeRepo envelopeRepo;
  final Account account;

  @override
  State<_LinkEnvelopesDialog> createState() => _LinkEnvelopesDialogState();
}

class _LinkEnvelopesDialogState extends State<_LinkEnvelopesDialog> {
  final Set<String> _selectedEnvelopeIds = {};
  bool _isLinking = false;

  void _toggleEnvelopeSelection(String envelopeId) {
    setState(() {
      if (_selectedEnvelopeIds.contains(envelopeId)) {
        _selectedEnvelopeIds.remove(envelopeId);
      } else {
        _selectedEnvelopeIds.add(envelopeId);
      }
    });
  }

  Future<void> _handleLinkEnvelopes() async {
    if (_isLinking || _selectedEnvelopeIds.isEmpty) return;

    setState(() => _isLinking = true);

    try {
      await widget.envelopeRepo.linkEnvelopesToAccount(
        _selectedEnvelopeIds.toList(),
        widget.account.id,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_selectedEnvelopeIds.length} envelope(s) linked to ${widget.account.name}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLinking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error linking envelopes: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Link Envelopes to ${widget.account.name}'),
      content: StreamBuilder<List<Envelope>>(
        stream: widget.envelopeRepo.unlinkedEnvelopesStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final unlinkedEnvelopes = snapshot.data!;

          if (unlinkedEnvelopes.isEmpty) {
            return const Text('No unlinked envelopes available.');
          }

          return SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: unlinkedEnvelopes.length,
              itemBuilder: (context, index) {
                final envelope = unlinkedEnvelopes[index];
                final isSelected = _selectedEnvelopeIds.contains(envelope.id);
                return CheckboxListTile(
                  title: Text(envelope.name),
                  value: isSelected,
                  onChanged: (_) => _toggleEnvelopeSelection(envelope.id),
                );
              },
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _handleLinkEnvelopes,
          child: _isLinking
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Link Selected'),
        ),
      ],
    );
  }
}