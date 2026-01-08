// lib/widgets/quick_action_modal.dart
// DEPRECATION FIX: .withOpacity -> .withValues(alpha: )

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart'; // NEW IMPORT
import '../models/envelope.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import '../services/envelope_repo.dart';
import '../services/account_repo.dart';
import '../services/workspace_helper.dart';
import '../providers/font_provider.dart'; // NEW IMPORT
import '../providers/locale_provider.dart';
import '../providers/time_machine_provider.dart';
import '../utils/calculator_helper.dart';
import '../widgets/partner_badge.dart';
import '../utils/responsive_helper.dart';
import '../widgets/common/smart_text_field.dart';

// Helper class to represent transfer destinations (envelope or account)
class _TransferDestination {
  final String id;
  final String name;
  final double balance;
  final bool isAccount;
  final Widget icon;
  final String? userId; // For partner badges

  _TransferDestination({
    required this.id,
    required this.name,
    required this.balance,
    required this.isAccount,
    required this.icon,
    this.userId,
  });
}

class QuickActionModal extends StatefulWidget {
  const QuickActionModal({
    super.key,
    required this.envelope,
    required this.allEnvelopes,
    required this.repo,
    required this.type,
  });

  final Envelope envelope;
  final List<Envelope> allEnvelopes;
  final EnvelopeRepo repo;
  final TransactionType type;

  @override
  State<QuickActionModal> createState() => _QuickActionModalState();
}

class _QuickActionModalState extends State<QuickActionModal> {
  final _amountController = TextEditingController();
  final _descController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String? _selectedTargetId; // For transfers only
  bool _isLoading = false;
  List<Account> _availableAccounts = [];
  late AccountRepo _accountRepo;

  @override
  void initState() {
    super.initState();
    _accountRepo = AccountRepo(widget.repo);
    _loadAccounts();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    // Load accounts for transfer destinations
    final accountSubscription = _accountRepo.accountsStream().listen((accounts) {
      if (mounted) {
        setState(() {
          _availableAccounts = accounts;
        });
      }
    });

    // Clean up subscription
    Future.delayed(const Duration(seconds: 1), () {
      accountSubscription.cancel();
    });
  }

  // Get combined list of transfer destinations (envelopes + accounts), alphabetized
  List<_TransferDestination> _getTransferDestinations(ThemeData theme) {
    final destinations = <_TransferDestination>[];

    // Add envelopes (excluding source envelope)
    for (final envelope in widget.allEnvelopes) {
      if (envelope.id != widget.envelope.id) {
        destinations.add(_TransferDestination(
          id: 'envelope_${envelope.id}',
          name: envelope.name,
          balance: envelope.currentAmount,
          isAccount: false,
          icon: envelope.getIconWidget(theme, size: 20),
          userId: envelope.userId,
        ));
      }
    }

    // Add accounts
    for (final account in _availableAccounts) {
      destinations.add(_TransferDestination(
        id: 'account_${account.id}',
        name: account.name,
        balance: account.currentBalance,
        isAccount: true,
        icon: account.getIconWidget(theme, size: 20),
        userId: account.userId,
      ));
    }

    // Sort alphabetically by name
    destinations.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return destinations;
  }

  void _showCalculator() async {
    final result = await CalculatorHelper.showCalculator(context);

    if (result != null && mounted) {
      setState(() {
        _amountController.text = result;
      });
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    // Check if time machine mode is active - block modifications
    final timeMachine = Provider.of<TimeMachineProvider>(context, listen: false);
    if (timeMachine.shouldBlockModifications()) {
      _showErrorDialog(
        'Time Machine Active',
        timeMachine.getBlockedActionMessage(),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showErrorDialog(
        'Invalid Amount',
        'Please enter a valid amount greater than zero.',
      );
      return;
    }

    if ((widget.type == TransactionType.withdrawal ||
            widget.type == TransactionType.transfer) &&
        amount > widget.envelope.currentAmount) {
      _showErrorDialog(
        'Insufficient Funds',
        'The envelope does not have enough funds for this transaction.',
      );
      return;
    }

    if (widget.type == TransactionType.transfer && _selectedTargetId == null) {
      _showErrorDialog(
        'No Destination Selected',
        'Please select a destination for the transfer.',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.type == TransactionType.deposit) {
        await widget.repo.deposit(
          envelopeId: widget.envelope.id,
          amount: amount,
          description: _descController.text.trim(),
          date: _selectedDate,
        );
      } else if (widget.type == TransactionType.withdrawal) {
        await widget.repo.withdraw(
          envelopeId: widget.envelope.id,
          amount: amount,
          description: _descController.text.trim(),
          date: _selectedDate,
        );
      } else if (widget.type == TransactionType.transfer) {
        // Determine if transferring to envelope or account
        if (_selectedTargetId!.startsWith('envelope_')) {
          // Envelope-to-envelope transfer
          final targetEnvelopeId = _selectedTargetId!.substring('envelope_'.length);
          await widget.repo.transfer(
            fromEnvelopeId: widget.envelope.id,
            toEnvelopeId: targetEnvelopeId,
            amount: amount,
            description: _descController.text.trim(),
            date: _selectedDate,
          );
        } else if (_selectedTargetId!.startsWith('account_')) {
          // Envelope-to-account transfer
          final targetAccountId = _selectedTargetId!.substring('account_'.length);

          // Withdraw from envelope
          await widget.repo.withdraw(
            envelopeId: widget.envelope.id,
            amount: amount,
            description: _descController.text.trim(),
            date: _selectedDate,
          );

          // Deposit to account
          await _accountRepo.deposit(
            targetAccountId,
            amount,
            description: _descController.text.trim(),
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
        _showErrorDialog(
          'Transaction Failed',
          'An error occurred: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTransfer = widget.type == TransactionType.transfer;
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final locale = Provider.of<LocaleProvider>(context, listen: false);
    final responsive = context.responsive;
    final isLandscape = responsive.isLandscape;

    String title;
    IconData icon;
    Color color;

    switch (widget.type) {
      case TransactionType.deposit:
        title = 'Add Income';
        icon = Icons.arrow_upward;
        color = Colors.green.shade600;
        break;
      case TransactionType.withdrawal:
        title = 'Spend';
        icon = Icons.arrow_downward;
        color = Colors.red.shade600;
        break;
      case TransactionType.scheduledPayment:
        // This shouldn't be used in quick actions, but include for completeness
        title = 'Autopilot';
        icon = Icons.event_repeat;
        color = Colors.purple.shade700;
        break;
      case TransactionType.transfer:
        title = 'Transfer';
        icon = Icons.swap_horiz;
        color = Colors.blue.shade600;
        break;
    }

    return SafeArea(
      child: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + (isLandscape ? 12 : 16),
            top: isLandscape ? 12 : 16,
            left: isLandscape ? 12 : 16,
            right: isLandscape ? 12 : 16,
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
                    // UPDATED: FontProvider
                    style: fontProvider.getTextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Consumer<LocaleProvider>(
                    builder: (context, locale, _) => Text(
                      'Balance: ${NumberFormat.currency(symbol: locale.currencySymbol).format(widget.envelope.currentAmount)}',
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
            // UPDATED: FontProvider
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
                labelText: 'Transfer To',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: _getTransferDestinations(theme).map((dest) {
                final isPartner = dest.userId != null && dest.userId != widget.repo.currentUserId;
                return DropdownMenuItem(
                  value: dest.id,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: dest.icon,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        flex: 2,
                        child: Text(
                          dest.name,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: fontProvider.getTextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Balance
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${locale.currencySymbol}${dest.balance.toStringAsFixed(2)}',
                            style: fontProvider.getTextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onSurface.withAlpha(153),
                            ),
                          ),
                        ),
                      ),
                      if (dest.isAccount) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Account',
                            style: fontProvider.getTextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      if (isPartner) ...[
                        const SizedBox(width: 8),
                        FutureBuilder<String>(
                          future: WorkspaceHelper.getUserDisplayName(
                            dest.userId!,
                            widget.repo.currentUserId,
                          ),
                          builder: (context, snapshot) {
                            return PartnerBadge(
                              partnerName: snapshot.data ?? 'Partner',
                              size: PartnerBadgeSize.small,
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
              onChanged: (v) => setState(() => _selectedTargetId = v),
            ),
          ],

          const SizedBox(height: 16),

          // Description
          SmartTextField(
            controller: _descController,
            textCapitalization: TextCapitalization.words,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'Description (Optional)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            // UPDATED: FontProvider
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
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'Confirm',
                    // UPDATED: FontProvider
                    style: fontProvider.getTextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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
