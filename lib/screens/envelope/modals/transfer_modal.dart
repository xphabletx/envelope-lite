// lib/screens/envelope/modals/transfer_modal.dart
// Unified with quick_action_modal.dart style and layout

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../models/envelope.dart';
import '../../../models/account.dart';
import '../../../models/app_error.dart';
import '../../../services/envelope_repo.dart';
import '../../../services/account_repo.dart';
import '../../../services/error_handler_service.dart';
import '../../../services/workspace_helper.dart';
import '../../../providers/font_provider.dart';
import '../../../providers/locale_provider.dart';
import '../../../providers/time_machine_provider.dart';
import '../../../utils/calculator_helper.dart';
import '../../../widgets/partner_badge.dart';
import '../../../utils/responsive_helper.dart';
import '../../../widgets/common/smart_text_field.dart';

class TransferModal extends StatefulWidget {
  const TransferModal({
    super.key,
    required this.repo,
    required this.sourceEnvelopeId,
    required this.sourceEnvelopeName,
    required this.currentAmount,
  });

  final EnvelopeRepo repo;
  final String sourceEnvelopeId;
  final String sourceEnvelopeName;
  final double currentAmount;

  @override
  State<TransferModal> createState() => _TransferModalState();
}

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

class _TransferModalState extends State<TransferModal> {
  final _amountController = TextEditingController();
  final _amountFocus = FocusNode();
  final _descController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String? _selectedTargetId;
  bool _isLoading = false;
  List<Envelope> _availableEnvelopes = [];
  List<Account> _availableAccounts = [];
  late AccountRepo _accountRepo;

  @override
  void initState() {
    super.initState();
    _accountRepo = AccountRepo(widget.repo);
    _loadEnvelopesAndAccounts();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocus.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadEnvelopesAndAccounts() async {
    // Load envelopes
    final envelopeSubscription = widget.repo.envelopesStream().listen((envelopes) {
      if (mounted) {
        setState(() {
          _availableEnvelopes = envelopes
              .where((e) => e.id != widget.sourceEnvelopeId)
              .toList();
        });
      }
    });

    // Load accounts (include ALL accounts - default and non-default)
    final accountSubscription = _accountRepo.accountsStream().listen((accounts) {
      if (mounted) {
        setState(() {
          _availableAccounts = accounts;
        });
      }
    });

    // Clean up subscriptions when done
    Future.delayed(const Duration(seconds: 1), () {
      envelopeSubscription.cancel();
      accountSubscription.cancel();
    });
  }

  // Get combined list of transfer destinations (envelopes + accounts), alphabetized
  List<_TransferDestination> _getTransferDestinations(ThemeData theme) {
    final destinations = <_TransferDestination>[];

    // Add envelopes
    for (final envelope in _availableEnvelopes) {
      destinations.add(_TransferDestination(
        id: 'envelope_${envelope.id}',
        name: envelope.name,
        balance: envelope.currentAmount,
        isAccount: false,
        icon: envelope.getIconWidget(theme, size: 20),
        userId: envelope.userId,
      ));
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

  Future<void> _submit() async {
    // Check if time machine mode is active - block modifications
    final timeMachine = Provider.of<TimeMachineProvider>(context, listen: false);
    if (timeMachine.shouldBlockModifications()) {
      ErrorHandler.showWarning(
        context,
        timeMachine.getBlockedActionMessage(),
      );
      return;
    }

    // Validation: Destination selected
    if (_selectedTargetId == null) {
      await ErrorHandler.handle(
        context,
        AppError.medium(
          code: 'NO_DESTINATION',
          userMessage: 'Please select a destination',
          category: ErrorCategory.validation,
        ),
      );
      return;
    }

    // Validation: Valid amount
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      await ErrorHandler.handle(
        context,
        AppError.medium(
          code: 'INVALID_AMOUNT',
          userMessage: 'Please enter a valid amount',
          category: ErrorCategory.validation,
        ),
      );
      return;
    }

    // Validation: Sufficient funds
    if (amount > widget.currentAmount) {
      await ErrorHandler.handle(
        context,
        AppError.business(
          code: 'INSUFFICIENT_FUNDS',
          userMessage: 'Insufficient funds in ${widget.sourceEnvelopeName}',
          severity: ErrorSeverity.medium,
          metadata: {
            'availableBalance': widget.currentAmount,
            'requestedAmount': amount,
          },
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final description = _descController.text.trim();

      // Check if transferring to account or envelope
      if (_selectedTargetId!.startsWith('account_')) {
        // Transfer to account: withdraw from envelope, deposit to account
        final accountId = _selectedTargetId!.substring('account_'.length);

        // Withdraw from envelope
        await widget.repo.withdraw(
          envelopeId: widget.sourceEnvelopeId,
          amount: amount,
          description: description.isEmpty
              ? 'Transfer to account'
              : description,
          date: _selectedDate,
        );

        // Deposit to account
        await _accountRepo.adjustBalance(
          accountId: accountId,
          amount: amount, // Positive amount = deposit
        );

      } else {
        // Transfer to envelope
        final envelopeId = _selectedTargetId!.substring('envelope_'.length);
        await widget.repo.transfer(
          fromEnvelopeId: widget.sourceEnvelopeId,
          toEnvelopeId: envelopeId,
          amount: amount,
          description: description,
          date: _selectedDate,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ErrorHandler.showSuccess(context, 'Transfer successful');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        await ErrorHandler.handle(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final responsive = context.responsive;
    final isLandscape = responsive.isLandscape;

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
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.swap_horiz,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Move Money',
                    style: fontProvider.getTextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Consumer<LocaleProvider>(
                    builder: (context, locale, _) => Text(
                      'Balance: ${NumberFormat.currency(symbol: locale.currencySymbol).format(widget.currentAmount)}',
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
          Consumer<LocaleProvider>(
            builder: (context, locale, _) => SmartTextField(
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
          ),

          const SizedBox(height: 16),

          // Transfer Target Dropdown
          Consumer<LocaleProvider>(
            builder: (context, localeProvider, _) {
              final destinations = _getTransferDestinations(theme);

              return DropdownButtonFormField<String>(
                key: ValueKey(_selectedTargetId),
                decoration: InputDecoration(
                  labelText: 'To Envelope or Account',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  // Add clear button (X) as suffix
                  suffixIcon: _selectedTargetId != null
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () => setState(() => _selectedTargetId = null),
                        )
                      : null,
                ),
                initialValue: _selectedTargetId,
                items: destinations
                    .map(
                      (dest) {
                        final isPartner = dest.userId != null &&
                            dest.userId != widget.repo.currentUserId;

                        return DropdownMenuItem(
                          value: dest.id,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Icon
                              dest.icon,
                              const SizedBox(width: 8),
                              // Name
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
                                '${localeProvider.currencySymbol}${dest.balance.toStringAsFixed(2)}',
                                style: fontProvider.getTextStyle(
                                  fontSize: 14,
                                  color: theme.colorScheme.onSurface.withAlpha(153),
                                ),
                              ),
                              // Partner badge if applicable
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
                              // Account badge for accounts
                              if (dest.isAccount) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.account_balance_wallet,
                                  size: 16,
                                  color: theme.colorScheme.primary.withAlpha(153),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedTargetId = v),
              );
            },
          ),

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
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
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
                      color: theme.colorScheme.onPrimary,
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
