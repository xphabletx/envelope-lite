import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import '../../models/account.dart';
import '../../models/envelope.dart';
import '../../models/transaction.dart';
import '../../services/account_repo.dart';
import '../../services/envelope_repo.dart';
import '../../providers/font_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/time_machine_provider.dart';
import '../../widgets/time_machine_indicator.dart';
import '../../widgets/accounts/account_quick_action_modal.dart';
import '../../utils/calculator_helper.dart';
import '../../services/localization_service.dart';
import '../envelope/envelopes_detail_screen.dart';
import '../stats_history_screen.dart';
import 'account_settings_screen.dart';
import '../../../widgets/common/smart_text_field.dart';

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

  void _showQuickAction(TransactionType type, Account account) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AccountQuickActionModal(
        account: account,
        allAccounts: widget.accountRepo.getAccountsSync(),
        repo: widget.accountRepo,
        type: type,
        envelopeRepo: widget.envelopeRepo,
      ),
    );
  }

  void _showCalculator(BuildContext context) async {
    await CalculatorHelper.showCalculator(context);
  }

  Widget _buildThemedFAB(
    BuildContext context,
    Account account,
    ThemeData theme,
  ) {
    final iconColor = theme.colorScheme.onPrimaryContainer;
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    final children = <SpeedDialChild>[
      SpeedDialChild(
        child: Icon(Icons.add_circle, color: iconColor),
        backgroundColor: theme.colorScheme.primaryContainer,
        label: tr('action_add_money'),
        labelStyle: fontProvider.getTextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        labelBackgroundColor: theme.colorScheme.surface,
        onTap: () => _showQuickAction(TransactionType.deposit, account),
      ),
      SpeedDialChild(
        child: Icon(Icons.remove_circle, color: iconColor),
        backgroundColor: theme.colorScheme.primaryContainer,
        label: 'Take Money',
        labelStyle: fontProvider.getTextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        labelBackgroundColor: theme.colorScheme.surface,
        onTap: () => _showQuickAction(TransactionType.withdrawal, account),
      ),
      SpeedDialChild(
        child: Icon(Icons.swap_horiz, color: iconColor),
        backgroundColor: theme.colorScheme.primaryContainer,
        label: tr('action_move_money'),
        labelStyle: fontProvider.getTextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        labelBackgroundColor: theme.colorScheme.surface,
        onTap: () => _showQuickAction(TransactionType.transfer, account),
      ),
      SpeedDialChild(
        child: Icon(Icons.calculate, color: iconColor),
        backgroundColor: theme.colorScheme.primaryContainer,
        label: tr('calculator'),
        labelStyle: fontProvider.getTextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        labelBackgroundColor: theme.colorScheme.surface,
        onTap: () => _showCalculator(context),
      ),
    ];

    return SpeedDial(
      icon: Icons.add,
      activeIcon: Icons.close,
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: theme.colorScheme.onPrimary,
      overlayColor: Colors.black,
      overlayOpacity: 0.5,
      spacing: 12,
      spaceBetweenChildren: 8,
      buttonSize: const Size(56, 56),
      childrenButtonSize: const Size(56, 56),
      renderOverlay: true,
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final locale = Provider.of<LocaleProvider>(context, listen: false);
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);

    return StreamBuilder<Account>(
      stream: widget.accountRepo.accountStream(widget.account.id),
      initialData: widget.account,
      builder: (context, accountSnapshot) {
        debugPrint('[AccountDetail] Stream update - hasData: ${accountSnapshot.hasData}, hasError: ${accountSnapshot.hasError}');

        if (accountSnapshot.hasError) {
          debugPrint('[AccountDetail] Stream error: ${accountSnapshot.error}');
          // Account was deleted - navigate back
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              debugPrint('[AccountDetail] Account deleted, navigating back');
              Navigator.pop(context);
            }
          });
          return Scaffold(
            appBar: AppBar(
              title: FittedBox(child: Text(widget.account.name)),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (!accountSnapshot.hasData) {
          debugPrint('[AccountDetail] No data in stream - showing spinner');
          return Scaffold(
            appBar: AppBar(
              title: FittedBox(child: Text(widget.account.name)),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final account = accountSnapshot.data!;
        debugPrint('[AccountDetail] Displaying account: ${account.name}');

        return Consumer<TimeMachineProvider>(
          builder: (context, timeMachine, _) {
            // Use projected account if time machine is active
            final displayAccount = timeMachine.isActive
                ? timeMachine.getProjectedAccount(account)
                : account;

            return Scaffold(
              appBar: AppBar(
                title: FittedBox(child: Text(displayAccount.name)),
              ),
              floatingActionButton: timeMachine.isActive
                  ? null
                  : _buildThemedFAB(context, account, theme),
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.endFloat,
              body: Column(
                children: [
                  // Time Machine Indicator at the top
                  const TimeMachineIndicator(),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              displayAccount.getIconWidget(theme, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            displayAccount.name,
                            style: fontProvider.getTextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (displayAccount.isDefault)
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
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        currency.format(displayAccount.currentBalance),
                        style: fontProvider.getTextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Action chips
                    StreamBuilder<List<Envelope>>(
                      initialData: widget.envelopeRepo.getEnvelopesSync(), // ✅ Instant data!
                      stream: widget.envelopeRepo.envelopesStream(),
                      builder: (context, envSnapshot) {
                        final envelopes = envSnapshot.data ?? [];
                        final linkedEnvelopeIds = envelopes
                            .where((e) => e.linkedAccountId == widget.account.id)
                            .map((e) => e.id)
                            .toSet();

                        return Row(
                          children: [
                            Expanded(
                              child: _AccountActionChip(
                                icon: Icons.link,
                                label: 'Link',
                                subLabel: linkedEnvelopeIds.isEmpty
                                    ? 'No envelopes'
                                    : '${linkedEnvelopeIds.length} linked',
                                color: theme.colorScheme.primaryContainer,
                                textColor: theme.colorScheme.onPrimaryContainer,
                                onTap: () => _showLinkEnvelopesDialog(context),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _AccountActionChip(
                                icon: Icons.bar_chart,
                                label: 'Stats',
                                subLabel: 'View history',
                                color: theme.colorScheme.secondaryContainer,
                                textColor: theme.colorScheme.onSecondaryContainer,
                                onTap: () {
                                  // DEBUG: Log navigation to stats
                                  debugPrint('[AccountDetail] Opening Stats for account: ${displayAccount.name} (${displayAccount.id})');
                                  debugPrint('[AccountDetail] Linked envelope IDs: $linkedEnvelopeIds');

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => StatsHistoryScreen(
                                        repo: widget.envelopeRepo,
                                        title: '${displayAccount.name} - History',
                                        initialAccountIds: {displayAccount.id},
                                        // Don't filter by envelopes - show ALL account transactions
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _AccountActionChip(
                                icon: Icons.settings,
                                label: 'Settings',
                                subLabel: 'Configure',
                                color: theme.colorScheme.tertiaryContainer,
                                textColor: theme.colorScheme.onTertiaryContainer,
                                onTap: () {
                                  if (timeMachine.shouldBlockModifications()) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(timeMachine.getBlockedActionMessage()),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                    return;
                                  }

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AccountSettingsScreen(
                                        account: account,
                                        accountRepo: widget.accountRepo,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<double>(
                      stream: widget.accountRepo.assignedAmountStream(widget.account.id),
                      builder: (context, assignedSnapshot) {
                        if (assignedSnapshot.connectionState == ConnectionState.waiting) {
                          return const LinearProgressIndicator();
                        }

                        final assigned = assignedSnapshot.data ?? 0.0;
                        final available = displayAccount.currentBalance - assigned;

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
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      currency.format(assigned),
                                      style: fontProvider.getTextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                      maxLines: 1,
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
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      currency.format(available),
                                      style: fontProvider.getTextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.secondary,
                                      ),
                                      maxLines: 1,
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
                      initialData: widget.envelopeRepo.getEnvelopesSync(), // ✅ Instant data!
                      stream: widget.envelopeRepo.envelopesStream(),
                      builder: (context, envelopeSnapshot) {
                        final allEnvelopes = envelopeSnapshot.data ?? [];
                        final linkedEnvelopes = allEnvelopes
                            .where((e) => e.linkedAccountId == widget.account.id)
                            .toList();

                        if (linkedEnvelopes.isEmpty) {
                          return const Text('No envelopes linked to this account.');
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
                                // Use projected envelope if time machine is active
                                final displayEnvelope = timeMachine.isActive
                                    ? timeMachine.getProjectedEnvelope(envelope)
                                    : envelope;

                                return ListTile(
                                  leading: displayEnvelope.getIconWidget(theme),
                                  title: Text(displayEnvelope.name),
                                  subtitle: displayEnvelope.cashFlowEnabled &&
                                          displayEnvelope.cashFlowAmount != null
                                      ? Text(
                                          'Cash Flow: ${currency.format(displayEnvelope.cashFlowAmount)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: theme.colorScheme.primary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        )
                                      : null,
                                  trailing: Text(
                                    currency.format(displayEnvelope.currentAmount),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
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
                          ],
                        );
                      },
                    ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
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
        initialData: widget.envelopeRepo.getEnvelopesSync().where((e) => e.linkedAccountId == null).toList(), // ✅ Instant data!
        stream: widget.envelopeRepo.unlinkedEnvelopesStream(),
        builder: (context, snapshot) {
          final unlinkedEnvelopes = snapshot.data ?? [];

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

/// Compact action chip matching the design from ModernEnvelopeHeaderCard
class _AccountActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subLabel;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _AccountActionChip({
    required this.icon,
    required this.label,
    required this.subLabel,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: textColor, size: 20),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subLabel,
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.7),
                  fontSize: 10,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
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
            SmartTextFormField(
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
            Consumer<LocaleProvider>(
              builder: (context, locale, _) => SmartTextFormField(
                controller: _balanceController,
                decoration: InputDecoration(
                  labelText: tr('account_balance'),
                  border: const OutlineInputBorder(),
                  prefixText: locale.currencySymbol,
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