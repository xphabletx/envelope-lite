// lib/screens/onboarding/onboarding_account_setup.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/account_repo.dart';
import '../../services/envelope_repo.dart';
import '../../providers/font_provider.dart';
import '../../providers/locale_provider.dart';
import '../../models/account.dart';
import '../../models/pay_day_settings.dart';

class OnboardingAccountSetup extends StatefulWidget {
  const OnboardingAccountSetup({
    super.key,
    required this.envelopeRepo,
    this.onBack,
    this.onComplete,
  });

  final EnvelopeRepo envelopeRepo;
  final VoidCallback? onBack;
  final VoidCallback? onComplete;

  @override
  State<OnboardingAccountSetup> createState() => _OnboardingAccountSetupState();
}

class _OnboardingAccountSetupState extends State<OnboardingAccountSetup> {
  final List<_AccountEntry> _accounts = [];
  bool _saving = false;

  // Pay day settings
  final _payAmountController = TextEditingController(text: '0.00');
  String _payFrequency = 'monthly';
  DateTime? _nextPayDate;

  @override
  void initState() {
    super.initState();
    // Start with one default account
    _addAccount(isDefault: true);
  }

  @override
  void dispose() {
    _payAmountController.dispose();
    for (final account in _accounts) {
      account.nameController.dispose();
      account.balanceController.dispose();
    }
    super.dispose();
  }

  void _addAccount({bool isDefault = false}) {
    setState(() {
      _accounts.add(_AccountEntry(
        nameController: TextEditingController(
          text: isDefault ? 'Main Account' : '',
        ),
        balanceController: TextEditingController(text: '0.00'),
        accountType: AccountType.bankAccount,
        isDefault: isDefault,
      ));
    });
  }

  void _removeAccount(int index) {
    if (_accounts.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need at least one account')),
      );
      return;
    }

    setState(() {
      _accounts[index].nameController.dispose();
      _accounts[index].balanceController.dispose();
      _accounts.removeAt(index);
    });
  }

  Future<void> _complete() async {
    if (_saving) return;

    // Validate at least one account
    if (_accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one account')),
      );
      return;
    }

    // Validate account names and balances
    for (final account in _accounts) {
      if (account.nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a name for all accounts')),
        );
        return;
      }

      final balance = double.tryParse(account.balanceController.text);
      if (balance == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please enter a valid balance for ${account.nameController.text}',
            ),
          ),
        );
        return;
      }
    }

    setState(() => _saving = true);

    try {
      final accountRepo = AccountRepo(
        widget.envelopeRepo.db,
        widget.envelopeRepo,
      );

      // Create all accounts
      for (final account in _accounts) {
        final balance = double.parse(account.balanceController.text);

        await accountRepo.createAccount(
          name: account.nameController.text.trim(),
          startingBalance: account.accountType == AccountType.creditCard
              ? -balance.abs()  // Credit cards are negative
              : balance,
          emoji: account.accountType == AccountType.creditCard ? '💳' : '💰',
          isDefault: account.isDefault,
          accountType: account.accountType,
          creditLimit: account.creditLimit,
        );
      }

      // Save pay day settings if provided
      final payAmount = double.tryParse(_payAmountController.text);
      debugPrint('[Onboarding] 💰 Pay day settings check:');
      debugPrint('[Onboarding]    Pay amount: $payAmount');
      debugPrint('[Onboarding]    Next pay date: $_nextPayDate');

      if (payAmount != null && payAmount > 0 && _nextPayDate != null) {
        debugPrint('[Onboarding] ✅ Saving pay day settings...');
        final userId = widget.envelopeRepo.currentUserId;

        // Create PayDaySettings object
        final payDaySettings = PayDaySettings(
          userId: userId,
          expectedPayAmount: payAmount,
          payFrequency: _payFrequency,
          nextPayDate: _nextPayDate,
          payDayOfMonth: _nextPayDate!.day,
          payDayOfWeek: _nextPayDate!.weekday,
        );

        // Save to Firestore
        await widget.envelopeRepo.db
            .collection('users')
            .doc(userId)
            .collection('payDaySettings')
            .doc('settings')
            .set(payDaySettings.toFirestore());

        debugPrint('[Onboarding] ✅ Pay day settings saved to Firestore');
        debugPrint('[Onboarding] ℹ️ Pay day will appear in Time Machine (not as a scheduled payment)');
      } else {
        debugPrint('[Onboarding] ⏭️ Skipping pay day settings - incomplete data');
      }

      if (mounted) {
        // Complete onboarding
        widget.onComplete?.call();
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final currencySymbol = localeProvider.currencySymbol;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  const Text('💰', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 16),
                  Text(
                    'Set up your accounts',
                    style: fontProvider.getTextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Track your money manually - no bank linking required',
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'We don\'t connect to your bank. You\'ll update balances manually.',
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Accounts list
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: _accounts.length,
              itemBuilder: (context, index) {
                  return _AccountEntryCard(
                    entry: _accounts[index],
                    index: index,
                    currencySymbol: currencySymbol,
                    fontProvider: fontProvider,
                    theme: theme,
                    onRemove: () => _removeAccount(index),
                    onTypeChanged: (type) {
                      setState(() {
                        _accounts[index].accountType = type;
                      });
                    },
                    onCreditLimitChanged: (limit) {
                      setState(() {
                        _accounts[index].creditLimit = limit;
                      });
                    },
                  );
                },
              ),

            // Add another account button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: OutlinedButton.icon(
                onPressed: () => _addAccount(),
                icon: const Icon(Icons.add),
                label: const Text('Add Another Account'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 56),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Divider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Divider(color: theme.colorScheme.outline),
            ),

            // Pay day settings (collapsed section)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pay Day Info (Optional)',
                    style: fontProvider.getTextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Set up your regular pay schedule. This will be added to your calendar and used for budget projections.',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Pay amount
                  TextField(
                    controller: _payAmountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: fontProvider.getTextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Take-home pay amount',
                      hintText: '0.00',
                      helperText: 'Your regular pay after taxes',
                      prefixText: '$currencySymbol ',
                      prefixStyle: fontProvider.getTextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onTap: () {
                      // Select all text when tapped
                      _payAmountController.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: _payAmountController.text.length,
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // Pay frequency
                  DropdownButtonFormField<String>(
                    initialValue: _payFrequency,
                    decoration: InputDecoration(
                      labelText: 'Pay frequency',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'weekly',
                        child: Text(
                          'Weekly (every 7 days)',
                          style: fontProvider.getTextStyle(fontSize: 16),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'biweekly',
                        child: Text(
                          'Bi-weekly (every 14 days)',
                          style: fontProvider.getTextStyle(fontSize: 16),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'fourweekly',
                        child: Text(
                          'Four-weekly (every 28 days)',
                          style: fontProvider.getTextStyle(fontSize: 16),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'monthly',
                        child: Text(
                          'Monthly',
                          style: fontProvider.getTextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _payFrequency = value);
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  // Next pay date
                  OutlinedButton.icon(
                    onPressed: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _nextPayDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        helpText: 'Select your next pay date',
                      );
                      if (pickedDate != null) {
                        setState(() => _nextPayDate = pickedDate);
                      }
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _nextPayDate == null
                          ? 'Select next pay date'
                          : 'Next pay: ${_nextPayDate!.month}/${_nextPayDate!.day}/${_nextPayDate!.year}',
                      style: fontProvider.getTextStyle(fontSize: 16),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      minimumSize: const Size(double.infinity, 56),
                    ),
                  ),

                  if (_nextPayDate != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This will be added to your calendar as a recurring event',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Bottom buttons
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Complete button
                  FilledButton(
                    onPressed: _saving ? null : _complete,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 56),
                    ),
                    child: _saving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'Get Started 🎉',
                            style: fontProvider.getTextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),

                  const SizedBox(height: 8),

                  // Skip button
                  TextButton(
                    onPressed: () {
                      widget.onComplete?.call();
                    },
                    child: Text(
                      'Skip for now',
                      style: fontProvider.getTextStyle(fontSize: 16),
                    ),
                  ),

                  if (widget.onBack != null) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: widget.onBack,
                      child: Text(
                        'Back',
                        style: fontProvider.getTextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

// Account entry data model
class _AccountEntry {
  final TextEditingController nameController;
  final TextEditingController balanceController;
  AccountType accountType;
  double? creditLimit;
  final bool isDefault;

  _AccountEntry({
    required this.nameController,
    required this.balanceController,
    required this.accountType,
    this.creditLimit,
    this.isDefault = false,
  });
}

// Account entry card widget
class _AccountEntryCard extends StatelessWidget {
  const _AccountEntryCard({
    required this.entry,
    required this.index,
    required this.currencySymbol,
    required this.fontProvider,
    required this.theme,
    required this.onRemove,
    required this.onTypeChanged,
    required this.onCreditLimitChanged,
  });

  final _AccountEntry entry;
  final int index;
  final String currencySymbol;
  final FontProvider fontProvider;
  final ThemeData theme;
  final VoidCallback onRemove;
  final Function(AccountType) onTypeChanged;
  final Function(double?) onCreditLimitChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with remove button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Account ${index + 1}',
                  style: fontProvider.getTextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                if (!entry.isDefault)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onRemove,
                    color: theme.colorScheme.error,
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Account type dropdown
            DropdownButtonFormField<AccountType>(
              value: entry.accountType,
              decoration: InputDecoration(
                labelText: 'Account Type',
                labelStyle: fontProvider.getTextStyle(fontSize: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(
                  entry.accountType == AccountType.creditCard
                      ? Icons.credit_card
                      : Icons.account_balance,
                ),
              ),
              items: [
                DropdownMenuItem(
                  value: AccountType.bankAccount,
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'Bank Account',
                        style: fontProvider.getTextStyle(fontSize: 18),
                      ),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: AccountType.creditCard,
                  child: Row(
                    children: [
                      const Icon(Icons.credit_card, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'Credit Card',
                        style: fontProvider.getTextStyle(fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ],
              onChanged: (AccountType? newType) {
                if (newType != null) {
                  onTypeChanged(newType);
                }
              },
            ),

            const SizedBox(height: 16),

            // Account name
            TextField(
              controller: entry.nameController,
              style: fontProvider.getTextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                labelText: 'Account Name',
                hintText: entry.accountType == AccountType.creditCard
                    ? 'e.g. Visa, Mastercard'
                    : 'e.g. Main Account, Savings',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onTap: () {
                // Select all text when tapped
                entry.nameController.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: entry.nameController.text.length,
                );
              },
            ),

            const SizedBox(height: 16),

            // Balance / Debt
            TextField(
              controller: entry.balanceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: fontProvider.getTextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                labelText: entry.accountType == AccountType.creditCard
                    ? 'Current Balance Owed'
                    : 'Current Balance',
                hintText: '0.00',
                helperText: entry.accountType == AccountType.creditCard
                    ? 'Enter the amount you owe (will be stored as negative)'
                    : null,
                prefixText: entry.accountType == AccountType.creditCard
                    ? '-$currencySymbol '
                    : '$currencySymbol ',
                prefixStyle: fontProvider.getTextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: entry.accountType == AccountType.creditCard
                      ? Colors.red
                      : null,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onTap: () {
                entry.balanceController.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: entry.balanceController.text.length,
                );
              },
            ),

            // Credit limit (credit cards only)
            if (entry.accountType == AccountType.creditCard) ...[
              const SizedBox(height: 16),
              TextField(
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: fontProvider.getTextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  labelText: 'Credit Limit (Optional)',
                  hintText: '0.00',
                  helperText: 'Total credit available on this card',
                  prefixText: '$currencySymbol ',
                  prefixStyle: fontProvider.getTextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) {
                  final limit = double.tryParse(value);
                  onCreditLimitChanged(limit);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
