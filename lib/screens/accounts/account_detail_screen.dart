import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/account.dart';
import '../../models/envelope.dart';
import '../../services/account_repo.dart';
import '../../services/envelope_repo.dart';
import '../../providers/font_provider.dart';
import '../../services/localization_service.dart';
import '../envelope/envelopes_detail_screen.dart';

class AccountDetailScreen extends StatefulWidget {
  const AccountDetailScreen({
    super.key,
    required this.account,
    required this.accountRepo,
    required this.envelopeRepo,
  });

  final Account account;
  final AccountRepo accountRepo;
  final EnvelopeRepo envelopeRepo;

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen> {
  void _showLinkEnvelopesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _LinkEnvelopesDialog(
        envelopeRepo: widget.envelopeRepo,
        account: widget.account,
      ),
    );
  }

  void _showEditAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _EditAccountDialog(
        accountRepo: widget.accountRepo,
        account: widget.account,
      ),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final theme = Theme.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('delete_account_title')),
        content: Text(tr('delete_account_confirm_msg')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('delete')),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await widget.accountRepo.deleteAccount(widget.account.id);
        if (mounted) {
          Navigator.pop(context); // Go back to account list
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('success_account_deleted'))),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${tr('error_generic')}: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final currency = NumberFormat.currency(symbol: '£');

    return StreamBuilder<Account>(
      stream: widget.accountRepo.accountStream(widget.account.id),
      initialData: widget.account,
      builder: (context, accountSnapshot) {
        if (!accountSnapshot.hasData) {
          return Scaffold(
            appBar: AppBar(
              title: FittedBox(child: Text(widget.account.name)),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final account = accountSnapshot.data!;

        return Scaffold(
          appBar: AppBar(
            title: FittedBox(child: Text(account.name)),
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _showEditAccountDialog(context);
                  } else if (value == 'delete') {
                    _confirmDeleteAccount(context);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(Icons.edit),
                        const SizedBox(width: 12),
                        Text(tr('edit_account')),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete, color: Colors.red),
                        const SizedBox(width: 12),
                        Text(
                          tr('delete_account'),
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
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
                  future: widget.accountRepo.getAssignedAmount(account.id),
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
              stream: widget.envelopeRepo.envelopesStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final linkedEnvelopes = snapshot.data!
                    .where((e) => e.linkedAccountId == widget.account.id)
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
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EnvelopeDetailScreen(
                                  envelopeId: envelope.id,
                                  repo: widget.envelopeRepo,
                                ),
                              ),
                            );
                          },
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
      },
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

class _EditAccountDialog extends StatefulWidget {
  const _EditAccountDialog({
    required this.accountRepo,
    required this.account,
  });

  final AccountRepo accountRepo;
  final Account account;

  @override
  State<_EditAccountDialog> createState() => _EditAccountDialogState();
}

class _EditAccountDialogState extends State<_EditAccountDialog> {
  late TextEditingController _nameController;
  late TextEditingController _balanceController;
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.account.name);
    _balanceController = TextEditingController(
      text: widget.account.currentBalance.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      final newBalance = double.parse(_balanceController.text);
      await widget.accountRepo.updateAccount(
        accountId: widget.account.id,
        name: _nameController.text.trim(),
        currentBalance: newBalance,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('success_account_updated'))),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tr('error_generic')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('edit_account')),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: tr('account_name'),
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return tr('error_enter_name');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _balanceController,
              decoration: InputDecoration(
                labelText: tr('account_balance'),
                border: const OutlineInputBorder(),
                prefixText: '£',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return tr('error_invalid_amount');
                }
                if (double.tryParse(value) == null) {
                  return tr('error_invalid_amount');
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: Text(tr('cancel')),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _handleSave,
          child: _isSaving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(tr('save')),
        ),
      ],
    );
  }
}