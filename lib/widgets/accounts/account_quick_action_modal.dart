// lib/widgets/accounts/account_quick_action_modal.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/account.dart';
import '../../models/envelope.dart';
import '../../models/transaction.dart';
import '../../services/account_repo.dart';
import '../../services/envelope_repo.dart';
import '../../providers/font_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/time_machine_provider.dart';
import '../../utils/calculator_helper.dart';
import '../common/smart_text_field.dart';

// Helper class to represent transfer destinations (account or envelope)
class _TransferDestination {
  final String id;
  final String name;
  final double balance;
  final bool isAccount;
  final Widget icon;

  _TransferDestination({
    required this.id,
    required this.name,
    required this.balance,
    required this.isAccount,
    required this.icon,
  });
}

class AccountQuickActionModal extends StatefulWidget {
  const AccountQuickActionModal({
    super.key,
    required this.account,
    required this.allAccounts,
    required this.repo,
    required this.type,
    this.envelopeRepo,
  });

  final Account account;
  final List<Account> allAccounts;
  final AccountRepo repo;
  final TransactionType type;
  final EnvelopeRepo? envelopeRepo;

  @override
  State<AccountQuickActionModal> createState() => _AccountQuickActionModalState();
}

class _AccountQuickActionModalState extends State<AccountQuickActionModal> {
  final _amountController = TextEditingController();
  final _descController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String? _selectedTargetId; // For transfers only
  bool _isLoading = false;
  List<Envelope> _availableEnvelopes = [];

  @override
  void initState() {
    super.initState();
    if (widget.type == TransactionType.transfer && widget.envelopeRepo != null) {
      _loadEnvelopes();
    }
  }

  Future<void> _loadEnvelopes() async {
    final envelopeSubscription = widget.envelopeRepo!.envelopesStream().listen((envelopes) {
      if (mounted) {
        setState(() {
          _availableEnvelopes = envelopes;
        });
      }
    });

    // Clean up subscription after 1 second
    Future.delayed(const Duration(seconds: 1), () {
      envelopeSubscription.cancel();
    });
  }

  // Get combined list of transfer destinations (accounts + envelopes)
  List<_TransferDestination> _getTransferDestinations(ThemeData theme) {
    final destinations = <_TransferDestination>[];

    // Add other accounts
    for (final account in widget.allAccounts) {
      if (account.id != widget.account.id) {
        destinations.add(_TransferDestination(
          id: 'account_${account.id}',
          name: account.name,
          balance: account.currentBalance,
          isAccount: true,
          icon: account.getIconWidget(theme, size: 20),
        ));
      }
    }

    // Add envelopes
    for (final envelope in _availableEnvelopes) {
      destinations.add(_TransferDestination(
        id: 'envelope_${envelope.id}',
        name: envelope.name,
        balance: envelope.currentAmount,
        isAccount: false,
        icon: envelope.getIconWidget(theme, size: 20),
      ));
    }

    // Sort alphabetically by name
    destinations.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return destinations;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _showCalculator() async {
    final result = await CalculatorHelper.showCalculator(context);

    if (result != null && mounted) {
      setState(() {
        _amountController.text = result;
      });
    }
  }

  Future<void> _submit() async {
    // Check if time machine mode is active - block modifications
    final timeMachine = Provider.of<TimeMachineProvider>(context, listen: false);
    if (timeMachine.shouldBlockModifications()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(timeMachine.getBlockedActionMessage()),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    if ((widget.type == TransactionType.withdrawal ||
            widget.type == TransactionType.transfer) &&
        amount > widget.account.currentBalance) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Insufficient funds')));
      return;
    }

    if (widget.type == TransactionType.transfer && _selectedTargetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a destination')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.type == TransactionType.deposit) {
        await widget.repo.deposit(
          widget.account.id,
          amount,
          description: _descController.text.trim(),
        );
      } else if (widget.type == TransactionType.withdrawal) {
        await widget.repo.withdraw(
          widget.account.id,
          amount,
          description: _descController.text.trim(),
        );
      } else if (widget.type == TransactionType.transfer) {
        final description = _descController.text.trim();

        // Check if transferring to account or envelope
        if (_selectedTargetId!.startsWith('account_')) {
          // Transfer to another account
          final accountId = _selectedTargetId!.substring('account_'.length);
          await widget.repo.transfer(
            widget.account.id,
            accountId,
            amount,
            description: description,
          );
        } else if (_selectedTargetId!.startsWith('envelope_')) {
          // Transfer to envelope: create linked transfer transactions
          final envelopeId = _selectedTargetId!.substring('envelope_'.length);

          // Transfer from account to envelope
          await widget.repo.transferToEnvelope(
            accountId: widget.account.id,
            envelopeId: envelopeId,
            amount: amount,
            description: description.isEmpty ? 'Transfer' : description,
            date: _selectedDate,
            envelopeRepo: widget.envelopeRepo!,
          );
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Transaction successful')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTransfer = widget.type == TransactionType.transfer;
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final locale = Provider.of<LocaleProvider>(context, listen: false);

    String title;
    IconData icon;
    Color color;

    switch (widget.type) {
      case TransactionType.deposit:
        title = 'Add Money';
        icon = Icons.add_circle;
        color = theme.colorScheme.primary;
        break;
      case TransactionType.withdrawal:
        title = 'Take Money';
        icon = Icons.remove_circle;
        color = theme.colorScheme.error;
        break;
      case TransactionType.scheduledPayment:
        // This shouldn't be used in quick actions, but include for completeness
        title = 'Autopilot';
        icon = Icons.event_repeat;
        color = Colors.purple.shade700;
        break;
      case TransactionType.transfer:
        title = 'Move Money';
        icon = Icons.swap_horiz;
        color = theme.colorScheme.primary;
        break;
    }

    return SafeArea(
      child: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            top: 16,
            left: 16,
            right: 16,
          ),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: fontProvider.getTextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Consumer<LocaleProvider>(
                    builder: (context, locale, _) => Text(
                      'Balance: ${NumberFormat.currency(symbol: locale.currencySymbol).format(widget.account.currentBalance)}',
                      style: fontProvider.getTextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withAlpha(179),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Amount
          SmartTextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: fontProvider.getTextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: locale.currencySymbol,
              suffixIcon: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.calculate,
                    color: theme.colorScheme.onPrimary,
                  ),
                  onPressed: _showCalculator,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onTap: () => _amountController.selection = TextSelection(
              baseOffset: 0,
              extentOffset: _amountController.text.length,
            ),
          ),

          if (isTransfer) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey(_selectedTargetId),
              initialValue: _selectedTargetId,
              decoration: InputDecoration(
                labelText: 'To Account or Envelope',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: _getTransferDestinations(theme)
                  .map(
                    (dest) {
                      return DropdownMenuItem(
                        value: dest.id,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            dest.icon,
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                dest.name,
                                overflow: TextOverflow.ellipsis,
                                style: fontProvider.getTextStyle(fontSize: 16),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Balance
                            Text(
                              '${locale.currencySymbol}${dest.balance.toStringAsFixed(2)}',
                              style: fontProvider.getTextStyle(
                                fontSize: 14,
                                color: theme.colorScheme.onSurface.withAlpha(153),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selectedTargetId = v),
            ),
          ],

          const SizedBox(height: 16),

          // Description
          SmartTextField(
            controller: _descController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Description (Optional)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            style: fontProvider.getTextStyle(fontSize: 16),
            onTap: () => _descController.selection = TextSelection(
              baseOffset: 0,
              extentOffset: _descController.text.length,
            ),
          ),

          const SizedBox(height: 16),

          // Date Picker
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    DateFormat('MMM dd, yyyy').format(_selectedDate),
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Submit Button
          ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: widget.type == TransactionType.withdrawal
                  ? theme.colorScheme.onError
                  : theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: widget.type == TransactionType.withdrawal
                          ? theme.colorScheme.onError
                          : theme.colorScheme.onPrimary,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'Confirm',
                    style: fontProvider.getTextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
            ],
          ),
        ),
      ),
    );
  }
}
