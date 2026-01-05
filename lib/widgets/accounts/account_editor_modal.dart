import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/account.dart';
import '../../services/account_repo.dart';
import '../../services/envelope_repo.dart';
import '../../services/pay_day_settings_service.dart';
import '../../screens/pay_day_settings_screen.dart';
import '../../providers/font_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/time_machine_provider.dart';
import '../envelope/omni_icon_picker_modal.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/common/smart_text_field.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AccountEditorModal extends StatefulWidget {
  const AccountEditorModal({
    super.key,
    required this.accountRepo,
    required this.envelopeRepo,
    this.account, // null = create mode, not null = edit mode
  });

  final AccountRepo accountRepo;
  final EnvelopeRepo envelopeRepo;
  final Account? account;

  @override
  State<AccountEditorModal> createState() => _AccountEditorModalState();
}

class _AccountEditorModalState extends State<AccountEditorModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController(text: '0.00');
  final _nameFocus = FocusNode();
  final _balanceFocus = FocusNode();

  String? _iconType;
  String? _iconValue;
  int? _iconColor;

  String _selectedColor = 'Primary';
  bool _isDefault = false;
  bool _saving = false;
  AccountType _accountType = AccountType.bankAccount;
  double? _creditLimit;
  bool _isFirstAccount = false;

  bool get _isEditMode => widget.account != null;

  @override
  void initState() {
    super.initState();

    // Check if this is the first account
    _checkIfFirstAccount();

    // If editing, populate fields
    if (_isEditMode) {
      _nameController.text = widget.account!.name;
      _balanceController.text = widget.account!.currentBalance.toStringAsFixed(
        2,
      );
      _iconType = widget.account!.iconType;
      _iconValue = widget.account!.iconValue;
      _iconColor = widget.account!.iconColor;
      _selectedColor = widget.account!.colorName ?? 'Primary';
      _isDefault = widget.account!.isDefault;
      _accountType = widget.account!.accountType;
      _creditLimit = widget.account!.creditLimit;
    }

    // Auto-focus name field - DISABLED to prevent keyboard popup
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   if (mounted) {
    //     _nameFocus.requestFocus();
    //   }
    // });

    // Select all text in balance when focused
    _balanceFocus.addListener(() {
      if (_balanceFocus.hasFocus) {
        _balanceController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _balanceController.text.length,
        );
      }
    });
  }

  void _checkIfFirstAccount() {
    final accounts = widget.accountRepo.getAccountsSync();
    _isFirstAccount = accounts.isEmpty;

    // Auto-enable default for first account
    if (_isFirstAccount) {
      _isDefault = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _nameFocus.dispose();
    _balanceFocus.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OmniIconPickerModal(
        initialQuery: _nameController.text.trim(), // Pre-populate with account name
      ),
    );

    if (result != null) {
      setState(() {
        _iconType = result['type'] as String;
        _iconValue = result['value'] as String;
        // For now, let's keep color null, can be added later
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
      emoji: _isEditMode ? widget.account?.emoji : null,
    );

    return account.getIconWidget(theme, size: 32);
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

    if (balance == null || balance < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid balance')),
      );
      return;
    }

    // Check for duplicate account names (only when creating or if name changed)
    final allAccounts = await widget.accountRepo.accountsStream().first;
    final duplicateName = allAccounts.any((a) =>
      a.name.trim().toLowerCase() == name.toLowerCase() &&
      a.id != widget.account?.id // Exclude current account when editing
    );

    if (duplicateName) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An account named "$name" already exists. Please choose a different name.'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      String? newAccountId;

      if (_isEditMode) {
        // Update existing account
        await widget.accountRepo.updateAccount(
          accountId: widget.account!.id,
          name: name,
          currentBalance: balance,
          colorName: _selectedColor,
          isDefault: _isDefault,
          iconType: _iconType,
          iconValue: _iconValue,
          iconColor: _iconColor,
        );
      } else {
        // Create new account
        newAccountId = await widget.accountRepo.createAccount(
          name: name,
          startingBalance: _accountType == AccountType.creditCard
              ? -balance.abs()  // Credit cards are negative
              : balance,
          colorName: _selectedColor,
          isDefault: _isDefault,
          iconType: _iconType,
          iconValue: _iconValue,
          iconColor: _iconColor,
          accountType: _accountType,
          creditLimit: _creditLimit,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditMode ? 'Account updated!' : 'Account created!',
            ),
          ),
        );

        // If this is the first default account, check for bulk linking
        if (!_isEditMode && _isDefault && newAccountId != null) {
          await _checkBulkLinking(newAccountId);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _checkBulkLinking(String accountId) async {
    // Check for unlinked cash flow envelopes
    final unlinkedEnvelopes = await widget.envelopeRepo.getUnlinkedCashFlowEnvelopes();

    if (unlinkedEnvelopes.isEmpty) {
      // No unlinked envelopes, check pay day setup
      await _checkPayDaySetup(accountId);
      return;
    }

    // AUTOMATIC BULK LINKING - No choice, this just happens
    final envelopeIds = unlinkedEnvelopes.map((e) => e.id).toList();
    await widget.envelopeRepo.bulkLinkToAccount(envelopeIds, accountId);

    // Update pay day settings with default account
    final payDayService = PayDaySettingsService(
      FirebaseFirestore.instance,
      widget.envelopeRepo.currentUserId,
    );
    final settings = await payDayService.getSettings();
    if (settings != null) {
      await payDayService.updatePayDaySettings(
        settings.copyWith(defaultAccountId: accountId),
      );
    }

    // Get account name for display
    final accounts = await widget.accountRepo.accountsStream().first;
    final account = accounts.firstWhere((a) => a.id == accountId);
    final accountName = account.name;

    // Show NOTIFICATION dialog (not asking permission, just informing)
    if (!mounted) return;
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Linking Envelopes',
          style: fontProvider.getTextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'You have ${unlinkedEnvelopes.length} envelope${unlinkedEnvelopes.length == 1 ? '' : 's'} with Cash Flow enabled.\n\n'
          'We\'re linking ${unlinkedEnvelopes.length == 1 ? 'it' : 'them'} to $accountName (your new default account) '
          'so pay day deposits can flow into this account.\n\n'
          'Want to set up your pay day schedule now? It powers the Time Machine.',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Skip For Now', style: fontProvider.getTextStyle(fontSize: 16)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to pay day settings
              final payDayService = PayDaySettingsService(
                FirebaseFirestore.instance,
                widget.envelopeRepo.currentUserId,
              );
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PayDaySettingsScreen(service: payDayService),
                ),
              );
            },
            child: Text(
              'Set Up Pay Day',
              style: fontProvider.getTextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Linked ${envelopeIds.length} envelope${envelopeIds.length == 1 ? '' : 's'} to $accountName'),
        ),
      );
    }
  }

  Future<void> _checkPayDaySetup(String accountId) async {
    // Check if pay day is already configured
    final payDayService = PayDaySettingsService(
      FirebaseFirestore.instance,
      widget.envelopeRepo.currentUserId,
    );
    final settings = await payDayService.getSettings();

    // Only offer setup if not already configured
    if (settings == null || settings.nextPayDate == null) {
      if (!mounted) return;
      final fontProvider = Provider.of<FontProvider>(context, listen: false);

      final shouldSetup = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Set Up Pay Day?',
            style: fontProvider.getTextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Would you like to configure your pay day settings now? This will help automate your envelope stuffing.',
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Later', style: fontProvider.getTextStyle(fontSize: 16)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Set Up Pay Day',
                style: fontProvider.getTextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );

      if (shouldSetup == true && mounted) {
        // Navigate to pay day settings
        final payDayService = PayDaySettingsService(
          FirebaseFirestore.instance,
          widget.envelopeRepo.currentUserId,
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PayDaySettingsScreen(service: payDayService),
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
    final responsive = context.responsive;
    final isLandscape = responsive.isLandscape;

    // Use smaller percentage in landscape to avoid overflow
    final modalHeight = media.size.height * (isLandscape ? 0.75 : 0.9);

    return Container(
      height: modalHeight,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  size: 28,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _isEditMode ? 'Edit Account' : 'New Account',
                    style: fontProvider.getTextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Form content
          Flexible(
            child: SingleChildScrollView(
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
                    // Name field
                    SmartTextFormField(
                      controller: _nameController,
                      focusNode: _nameFocus,
                      nextFocusNode: _balanceFocus,
                      textCapitalization: TextCapitalization.words,
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
                      
                    ),
                    const SizedBox(height: 16),

                    // Account type dropdown
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
                      onChanged: _isEditMode ? null : (AccountType? newType) {
                        if (newType != null) {
                          setState(() => _accountType = newType);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Default toggle (ABOVE other options, only for bank accounts)
                    if (_accountType == AccountType.bankAccount) ...[
                      SwitchListTile(
                        value: _isDefault,
                        onChanged: (value) async {
                          // If trying to unset default on first/only account, show warning
                          if (!value && _isFirstAccount) {
                            await showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text(
                                  'Default Account Required',
                                  style: fontProvider.getTextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                content: const Text(
                                  'You need at least one default account for Pay Day deposits. Please create another account and set it as default before removing this one.',
                                  style: TextStyle(fontSize: 16),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text(
                                      'OK',
                                      style: fontProvider.getTextStyle(fontSize: 16),
                                    ),
                                  ),
                                ],
                              ),
                            );
                            return; // Don't change the value
                          }

                          setState(() {
                            _isDefault = value;
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
                      const SizedBox(height: 16),
                    ],

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

                    // Balance field
                    SmartTextFormField(
                      controller: _balanceController,
                      focusNode: _balanceFocus,
                      isLastField: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: fontProvider.getTextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        labelText: _accountType == AccountType.creditCard
                            ? (_isEditMode ? 'Current Balance Owed' : 'Starting Balance Owed')
                            : (_isEditMode ? 'Current Balance' : 'Starting Balance'),
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
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 20,
                          ),
                        ),
                        onChanged: (value) {
                          final limit = double.tryParse(value);
                          setState(() => _creditLimit = limit);
                        },
                        onTap: () {
                          // This will be handled by initialValue
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Color picker
                    DropdownButtonFormField<String>(
                      initialValue: _selectedColor,
                      decoration: InputDecoration(
                        labelText: 'Color Theme',
                        labelStyle: fontProvider.getTextStyle(fontSize: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.palette),
                      ),
                      items:
                          [
                            'Primary',
                            'Secondary',
                            'Tertiary',
                            'Red',
                            'Orange',
                            'Yellow',
                            'Green',
                            'Blue',
                            'Purple',
                            'Pink',
                          ].map((color) {
                            return DropdownMenuItem(
                              value: color,
                              child: Text(
                                color,
                                style: fontProvider.getTextStyle(fontSize: 18),
                              ),
                            );
                          }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedColor = value);
                        }
                      },
                    ),
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
                              _isEditMode ? 'Save Changes' : 'Create Account',
                              style: fontProvider.getTextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
