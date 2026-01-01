import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/account.dart';
import '../../services/account_repo.dart';
import '../../providers/font_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/time_machine_provider.dart';
import '../../widgets/envelope/omni_icon_picker_modal.dart';
import '../../utils/calculator_helper.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({
    super.key,
    required this.account,
    required this.accountRepo,
  });

  final Account account;
  final AccountRepo accountRepo;

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  final _autoFillAmountController = TextEditingController();
  final _nameFocus = FocusNode();
  final _balanceFocus = FocusNode();
  final _autoFillAmountFocus = FocusNode();

  String? _iconType;
  String? _iconValue;
  int? _iconColor;
  bool _isDefault = false;
  bool _saving = false;
  AccountType _accountType = AccountType.bankAccount;
  double? _creditLimit;
  bool _payDayAutoFillEnabled = false;

  @override
  void initState() {
    super.initState();

    // Populate fields from existing account
    _nameController.text = widget.account.name;
    _balanceController.text = widget.account.currentBalance.toStringAsFixed(2);
    _iconType = widget.account.iconType;
    _iconValue = widget.account.iconValue;
    _iconColor = widget.account.iconColor;
    _isDefault = widget.account.isDefault;
    _accountType = widget.account.accountType;
    _creditLimit = widget.account.creditLimit;
    _payDayAutoFillEnabled = widget.account.payDayAutoFillEnabled;

    // Debug: Log what we're loading from Hive
    debugPrint('[AccountSettings] 🔍 Loading account: ${widget.account.name}');
    debugPrint('[AccountSettings]    payDayAutoFillEnabled: ${widget.account.payDayAutoFillEnabled}');
    debugPrint('[AccountSettings]    payDayAutoFillAmount: ${widget.account.payDayAutoFillAmount}');

    // Populate auto-fill amount controller if it exists
    if (widget.account.payDayAutoFillAmount != null) {
      _autoFillAmountController.text = widget.account.payDayAutoFillAmount!.toStringAsFixed(2);
      debugPrint('[AccountSettings]    Controller populated with: ${_autoFillAmountController.text}');
    }

    // Select all text in balance when focused
    _balanceFocus.addListener(() {
      if (_balanceFocus.hasFocus) {
        _balanceController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _balanceController.text.length,
        );
      }
    });

    // Select all text in auto-fill amount when focused
    _autoFillAmountFocus.addListener(() {
      if (_autoFillAmountFocus.hasFocus) {
        _autoFillAmountController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _autoFillAmountController.text.length,
        );
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _autoFillAmountController.dispose();
    _nameFocus.dispose();
    _balanceFocus.dispose();
    _autoFillAmountFocus.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OmniIconPickerModal(
        initialQuery: _nameController.text.trim(),
      ),
    );

    if (result != null) {
      setState(() {
        _iconType = result['type'] as String;
        _iconValue = result['value'] as String;
        _iconColor = null;
      });
    }
  }

  Widget _buildIconPreview() {
    final theme = Theme.of(context);
    final account = Account(
      id: '',
      name: '',
      userId: '',
      currentBalance: 0,
      createdAt: DateTime.now(),
      lastUpdated: DateTime.now(),
      iconType: _iconType,
      iconValue: _iconValue,
      iconColor: _iconColor,
      emoji: widget.account.emoji,
    );

    return account.getIconWidget(theme, size: 32);
  }

  Future<void> _openCalculator() async {
    final result = await CalculatorHelper.showCalculator(context);
    if (result != null && mounted) {
      setState(() {
        _balanceController.text = result;
      });
    }
  }

  Future<void> _openAutoFillCalculator() async {
    final result = await CalculatorHelper.showCalculator(context);
    if (result != null && mounted) {
      setState(() {
        _autoFillAmountController.text = result;
      });
    }
  }

  Future<void> _handleSave() async {
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

    if (_saving) return;
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final name = _nameController.text.trim();
    final balanceText = _balanceController.text.trim();
    final balance = double.tryParse(balanceText);

    if (balance == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid balance')),
      );
      return;
    }

    // Parse auto-fill amount from controller - explicitly handle all cases
    double? autoFillAmount;
    if (_payDayAutoFillEnabled) {
      if (_autoFillAmountController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter an auto-fill amount')),
        );
        return;
      }
      autoFillAmount = double.tryParse(_autoFillAmountController.text.trim());
      if (autoFillAmount == null || autoFillAmount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid auto-fill amount')),
        );
        return;
      }
    } else {
      // Auto-fill is disabled - explicitly set to null
      autoFillAmount = null;
    }

    setState(() => _saving = true);

    // Debug: Log what we're about to save
    debugPrint('[AccountSettings] 💾 Saving account: $name');
    debugPrint('[AccountSettings]    payDayAutoFillEnabled: $_payDayAutoFillEnabled');
    debugPrint('[AccountSettings]    payDayAutoFillAmount: $autoFillAmount');

    try {
      await widget.accountRepo.updateAccount(
        accountId: widget.account.id,
        name: name,
        currentBalance: _accountType == AccountType.creditCard
            ? -balance.abs()
            : balance,
        isDefault: _isDefault,
        iconType: _iconType,
        iconValue: _iconValue,
        iconColor: _iconColor,
        // Always pass explicit values, never rely on null-coalescing in updateAccount
        payDayAutoFillEnabled: _payDayAutoFillEnabled,
        payDayAutoFillAmount: autoFillAmount,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _handleDelete() async {
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

    if (_saving) return;

    // Get linked envelopes count
    final linkedEnvelopes = await widget.accountRepo.getLinkedEnvelopes(widget.account.id);
    final linkedCount = linkedEnvelopes.length;

    if (!mounted) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final fontProvider = Provider.of<FontProvider>(context, listen: false);

        return AlertDialog(
          title: Text(
            'Delete Account?',
            style: fontProvider.getTextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete "${widget.account.name}"?',
                style: fontProvider.getTextStyle(fontSize: 16),
              ),
              if (linkedCount > 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '$linkedCount linked envelope${linkedCount == 1 ? '' : 's'} will be unlinked (not deleted)',
                          style: fontProvider.getTextStyle(
                            fontSize: 14,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'This action cannot be undone.',
                style: fontProvider.getTextStyle(
                  fontSize: 14,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: fontProvider.getTextStyle(fontSize: 16),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: Text(
                'Delete',
                style: fontProvider.getTextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _saving = true);

    try {
      await widget.accountRepo.deleteAccount(widget.account.id);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Icon(
              Icons.settings,
              size: 28,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Account Settings',
                style: fontProvider.getTextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          bottom: media.viewInsets.bottom + 24,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // Name field
              TextFormField(
                controller: _nameController,
                focusNode: _nameFocus,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                style: fontProvider.getTextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  labelText: 'Account Name',
                  labelStyle: fontProvider.getTextStyle(fontSize: 18),
                  hintText: 'e.g. Main Account',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.account_balance_wallet),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
                onTap: () {
                  _nameController.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: _nameController.text.length,
                  );
                },
                onEditingComplete: () => _balanceFocus.requestFocus(),
              ),
              const SizedBox(height: 16),

              // Account type dropdown (display only, cannot change)
              DropdownButtonFormField<AccountType>(
                initialValue: _accountType,
                decoration: InputDecoration(
                  labelText: 'Account Type',
                  labelStyle: fontProvider.getTextStyle(fontSize: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(
                    _accountType == AccountType.creditCard
                        ? Icons.credit_card
                        : Icons.account_balance,
                  ),
                ),
                items: [
                  DropdownMenuItem(
                    value: AccountType.bankAccount,
                    child: Text(
                      'Bank Account',
                      style: fontProvider.getTextStyle(fontSize: 18),
                    ),
                  ),
                  DropdownMenuItem(
                    value: AccountType.creditCard,
                    child: Text(
                      'Credit Card',
                      style: fontProvider.getTextStyle(fontSize: 18),
                    ),
                  ),
                ],
                onChanged: null, // Cannot change account type after creation
              ),
              const SizedBox(height: 16),

              // Icon picker
              InkWell(
                onTap: _pickIcon,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: theme.colorScheme.outline.withAlpha(128),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.emoji_emotions),
                      const SizedBox(width: 16),
                      Text(
                        'Icon',
                        style: fontProvider.getTextStyle(fontSize: 18),
                      ),
                      const Spacer(),
                      _buildIconPreview(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Balance field with calculator inside
              TextFormField(
                controller: _balanceController,
                focusNode: _balanceFocus,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                style: fontProvider.getTextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  labelText: _accountType == AccountType.creditCard
                      ? 'Current Balance Owed'
                      : 'Current Balance',
                  labelStyle: fontProvider.getTextStyle(fontSize: 18),
                  hintText: '0.00',
                  helperText: _accountType == AccountType.creditCard
                      ? 'Enter the amount you owe (will be stored as negative)'
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixText: _accountType == AccountType.creditCard
                      ? '-${localeProvider.currencySymbol} '
                      : '${localeProvider.currencySymbol} ',
                  prefixStyle: fontProvider.getTextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _accountType == AccountType.creditCard
                        ? Colors.red
                        : null,
                  ),
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
                      onPressed: _openCalculator,
                      tooltip: 'Open Calculator',
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                ),
                onTap: () {
                  _balanceController.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: _balanceController.text.length,
                  );
                },
              ),
              const SizedBox(height: 16),

              // Credit limit field (credit cards only)
              if (_accountType == AccountType.creditCard) ...[
                TextFormField(
                  initialValue: _creditLimit?.toStringAsFixed(2),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: fontProvider.getTextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Credit Limit (Optional)',
                    labelStyle: fontProvider.getTextStyle(fontSize: 18),
                    hintText: '0.00',
                    helperText: 'Total credit available on this card',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixText: '${localeProvider.currencySymbol} ',
                    prefixStyle: fontProvider.getTextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onChanged: (value) {
                    final limit = double.tryParse(value);
                    setState(() => _creditLimit = limit);
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Pay Day Auto-Fill section (only if NOT default account)
              if (!_isDefault) ...[
                SwitchListTile(
                  value: _payDayAutoFillEnabled,
                  onChanged: (value) {
                    setState(() {
                      _payDayAutoFillEnabled = value;
                      if (!value) {
                        _autoFillAmountController.clear();
                      }
                    });
                  },
                  title: Text(
                    'Pay Day Auto-Fill',
                    style: fontProvider.getTextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Automatically allocate money from pay day to this account',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withAlpha(153),
                    ),
                  ),
                ),
                if (_payDayAutoFillEnabled) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _autoFillAmountController,
                    focusNode: _autoFillAmountFocus,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: fontProvider.getTextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Pay Day Auto-Fill Amount',
                      labelStyle: fontProvider.getTextStyle(fontSize: 18),
                      hintText: '0.00',
                      helperText: _accountType == AccountType.creditCard
                          ? 'Amount to pay toward credit card each pay day'
                          : 'Amount to deposit to this account each pay day',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixText: '${localeProvider.currencySymbol} ',
                      prefixStyle: fontProvider.getTextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
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
                          onPressed: _openAutoFillCalculator,
                          tooltip: 'Open Calculator',
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 20,
                      ),
                    ),
                    onChanged: (value) {
                      // Value is already in the controller, no need to store separately
                    },
                    onTap: () {
                      _autoFillAmountController.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: _autoFillAmountController.text.length,
                      );
                    },
                  ),
                ],
                const SizedBox(height: 16),
              ],

              // Default toggle (only show for bank accounts, not credit cards)
              if (_accountType == AccountType.bankAccount) ...[
                SwitchListTile(
                  value: _isDefault,
                  onChanged: (value) {
                    setState(() {
                      _isDefault = value;
                      // If setting as default, disable auto-fill (can't fill itself!)
                      if (value) {
                        _payDayAutoFillEnabled = false;
                        _autoFillAmountController.clear();
                      }
                    });
                  },
                  title: Text(
                    'Set as default account',
                    style: fontProvider.getTextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Pay Day deposits will go to this account',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withAlpha(153),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ] else
                const SizedBox(height: 32),

              // Save button
              FilledButton(
                onPressed: _saving ? null : _handleSave,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Save Changes',
                        style: fontProvider.getTextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
              const SizedBox(height: 16),

              // Delete button
              OutlinedButton(
                onPressed: _saving ? null : _handleDelete,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: Colors.red.shade400, width: 2),
                ),
                child: Text(
                  'Delete Account',
                  style: fontProvider.getTextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade400,
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
