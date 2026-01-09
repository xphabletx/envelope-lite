import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/account.dart';
import '../../services/account_repo.dart';
import '../../providers/font_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/time_machine_provider.dart';
import '../../widgets/envelope/omni_icon_picker_modal.dart';
import '../../utils/calculator_helper.dart';
import '../../widgets/common/smart_text_field.dart';

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
  final _nameFocus = FocusNode();
  final _balanceFocus = FocusNode();

  String? _iconType;
  String? _iconValue;
  int? _iconColor;
  bool _isDefault = false;
  bool _saving = false;
  AccountType _accountType = AccountType.bankAccount;
  double? _creditLimit;

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

    // SmartTextField now handles select-all-on-focus automatically
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

  Future<void> _openCalculator() async {
    final result = await CalculatorHelper.showCalculator(context);
    if (result != null && mounted) {
      setState(() {
        _balanceController.text = result;
      });
    }
  }


  Future<void> _handleSave() async {
    FocusScope.of(context).unfocus();

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

    final newBalance = _accountType == AccountType.creditCard
        ? -balance.abs()
        : balance;

    // Check if balance has changed - if so, show warning
    final balanceChanged = (newBalance - widget.account.currentBalance).abs() > 0.01;

    if (balanceChanged) {
      final confirmed = await _showBalanceEditWarning(newBalance);
      if (confirmed != true) {
        return; // User cancelled
      }
    }

    setState(() => _saving = true);

    try {
      await widget.accountRepo.updateAccount(
        accountId: widget.account.id,
        name: name,
        currentBalance: newBalance,
        isDefault: _isDefault,
        iconType: _iconType,
        iconValue: _iconValue,
        iconColor: _iconColor,
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

  Future<bool?> _showBalanceEditWarning(double newBalance) async {
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final locale = Provider.of<LocaleProvider>(context, listen: false);
    final oldBalance = widget.account.currentBalance;
    final difference = newBalance - oldBalance;

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Edit Account Balance?',
                style: fontProvider.getTextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '⚠️ Important:',
              style: fontProvider.getTextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Editing the balance directly is NOT the same as adding, taking, or transferring money.',
              style: fontProvider.getTextStyle(fontSize: 15),
            ),
            const SizedBox(height: 12),
            Text(
              'Use this only to correct mistakes or sync with your real bank balance.',
              style: fontProvider.getTextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Current:',
                        style: fontProvider.getTextStyle(fontSize: 14),
                      ),
                      Text(
                        '${locale.currencySymbol}${oldBalance.toStringAsFixed(2)}',
                        style: fontProvider.getTextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'New:',
                        style: fontProvider.getTextStyle(fontSize: 14),
                      ),
                      Text(
                        '${locale.currencySymbol}${newBalance.toStringAsFixed(2)}',
                        style: fontProvider.getTextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: difference >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Difference:',
                        style: fontProvider.getTextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${difference >= 0 ? '+' : ''}${locale.currencySymbol}${difference.toStringAsFixed(2)}',
                        style: fontProvider.getTextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: difference >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'A "Balance Adjustment" record will be created to track this change.',
              style: fontProvider.getTextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: fontProvider.getTextStyle(fontSize: 16)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade700),
            child: Text(
              'Continue',
              style: fontProvider.getTextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
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

    // Get all accounts and linked envelopes
    final allAccounts = await widget.accountRepo.accountsStream().first;
    final otherAccounts = allAccounts.where((a) => a.id != widget.account.id).toList();
    final linkedEnvelopes = await widget.accountRepo.getLinkedEnvelopes(widget.account.id);

    if (!mounted) return;

    // SCENARIO 1: Deleting DEFAULT account
    if (widget.account.isDefault) {
      if (otherAccounts.isNotEmpty) {
        // SCENARIO A: Other accounts exist - offer to move or switch to Budget Mode
        await _handleDeleteDefaultWithOtherAccounts(otherAccounts, linkedEnvelopes);
      } else {
        // SCENARIO B: This is the ONLY account - warn about Budget Mode switch
        await _handleDeleteOnlyAccount(linkedEnvelopes);
      }
    } else {
      // SCENARIO 2: Deleting non-default account - simple deletion
      await _handleDeleteNonDefaultAccount(linkedEnvelopes);
    }
  }

  Future<void> _handleDeleteDefaultWithOtherAccounts(
    List<Account> otherAccounts,
    List<dynamic> linkedEnvelopes,
  ) async {
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final firstOtherAccount = otherAccounts.first;

    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Default Account?',
          style: fontProvider.getTextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This is your default account with ${linkedEnvelopes.length} envelope${linkedEnvelopes.length == 1 ? '' : 's'} linked.\n\n'
          'Want to move ${linkedEnvelopes.length == 1 ? 'it' : 'them'} to ${firstOtherAccount.name}?',
          style: fontProvider.getTextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: Text('Cancel', style: fontProvider.getTextStyle(fontSize: 16)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'move'),
            child: Text(
              'Move to ${firstOtherAccount.name}',
              style: fontProvider.getTextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, 'budget_mode'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.orange),
            ),
            child: Text(
              'Switch to Budget Mode',
              style: fontProvider.getTextStyle(
                fontSize: 16,
                color: Colors.orange,
              ),
            ),
          ),
        ],
      ),
    );

    if (action == 'move') {
      await _moveEnvelopesAndDelete(firstOtherAccount, linkedEnvelopes);
    } else if (action == 'budget_mode') {
      await _showBudgetModeWarning(otherAccounts, linkedEnvelopes);
    }
  }

  Future<void> _showBudgetModeWarning(
    List<Account> otherAccounts,
    List<dynamic> linkedEnvelopes,
  ) async {
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final firstOtherAccount = otherAccounts.first;

    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Switch to Budget Mode?',
          style: fontProvider.getTextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '⚠️ Heads up! You\'re switching to a less accurate tracking mode.\n\n'
          'Your envelopes will use "magic money" instead of real account balances.\n\n'
          'Want to make ${firstOtherAccount.name} your default instead, or create a new one?',
          style: fontProvider.getTextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: Text('Cancel', style: fontProvider.getTextStyle(fontSize: 16)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'make_default'),
            child: Text(
              'Make ${firstOtherAccount.name} Default',
              style: fontProvider.getTextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, 'continue'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
            ),
            child: Text(
              'Continue Anyway',
              style: fontProvider.getTextStyle(
                fontSize: 16,
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (action == 'make_default') {
      await _moveEnvelopesAndDelete(firstOtherAccount, linkedEnvelopes);
    } else if (action == 'continue') {
      await _unlinkEnvelopesAndDelete(linkedEnvelopes);
    }
  }

  Future<void> _handleDeleteOnlyAccount(List<dynamic> linkedEnvelopes) async {
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Switch to Budget Mode?',
          style: fontProvider.getTextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '⚠️ You\'re deleting your only account.\n\n'
          'This will switch you to Budget Mode where envelopes use "magic money" '
          'instead of real account balances.\n\n'
          'Are you sure?',
          style: fontProvider.getTextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: fontProvider.getTextStyle(fontSize: 16)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: Text(
              'Switch to Budget Mode',
              style: fontProvider.getTextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _unlinkEnvelopesAndDelete(linkedEnvelopes);
    }
  }

  Future<void> _handleDeleteNonDefaultAccount(List<dynamic> linkedEnvelopes) async {
    if (linkedEnvelopes.isEmpty) {
      // No envelopes linked - simple delete with basic confirmation
      final confirmed = await _showSimpleDeleteConfirmation();
      if (confirmed == true) {
        await _performDelete();
      }
      return;
    }

    // Has linked envelopes - show warning
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Account?',
          style: fontProvider.getTextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This account has ${linkedEnvelopes.length} envelope${linkedEnvelopes.length == 1 ? '' : 's'} linked.\n\n'
          '${linkedEnvelopes.length == 1 ? 'It' : 'They'}\'ll be unlinked and won\'t receive Cash Flow anymore.',
          style: fontProvider.getTextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: fontProvider.getTextStyle(fontSize: 16)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
      ),
    );

    if (confirmed == true) {
      await _performDelete();
    }
  }

  Future<bool?> _showSimpleDeleteConfirmation() async {
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Account?',
          style: fontProvider.getTextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${widget.account.name}"?\n\n'
          'This action cannot be undone.',
          style: fontProvider.getTextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: fontProvider.getTextStyle(fontSize: 16)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
      ),
    );
  }

  Future<void> _moveEnvelopesAndDelete(
    Account targetAccount,
    List<dynamic> linkedEnvelopes,
  ) async {
    debugPrint('[AccountSettings] _moveEnvelopesAndDelete START');
    debugPrint('[AccountSettings] Deleting: ${widget.account.name} (${widget.account.id})');
    debugPrint('[AccountSettings] Target: ${targetAccount.name} (${targetAccount.id})');

    setState(() => _saving = true);

    try {
      debugPrint('[AccountSettings] Setting ${targetAccount.name} as default...');
      // Set target account as default first
      await widget.accountRepo.updateAccount(
        accountId: targetAccount.id,
        isDefault: true,
      );
      debugPrint('[AccountSettings] Default account updated');

      // Note: Moving envelopes to the target account would require EnvelopeRepo access
      // For now, deleteAccount will unlink them automatically
      // TODO: Pass EnvelopeRepo to this screen to enable bulk re-linking to target account

      debugPrint('[AccountSettings] Calling deleteAccount...');
      // Delete the account (this automatically unlinks all envelopes)
      await widget.accountRepo.deleteAccount(widget.account.id);
      debugPrint('[AccountSettings] deleteAccount completed');

      if (mounted) {
        debugPrint('[AccountSettings] Widget still mounted, navigating back...');
        // Pop twice: once for settings screen, once for detail screen
        Navigator.pop(context);
        debugPrint('[AccountSettings] First pop complete');
        Navigator.pop(context);
        debugPrint('[AccountSettings] Second pop complete');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Account deleted. ${targetAccount.name} is now your default account.\n'
              '${linkedEnvelopes.length} envelope${linkedEnvelopes.length == 1 ? ' was' : 's were'} unlinked.',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
        debugPrint('[AccountSettings] Success message shown');
      } else {
        debugPrint('[AccountSettings] WARNING: Widget not mounted after delete!');
      }
    } catch (e) {
      debugPrint('[AccountSettings] ERROR in _moveEnvelopesAndDelete: $e');
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
    debugPrint('[AccountSettings] _moveEnvelopesAndDelete END');
  }

  Future<void> _unlinkEnvelopesAndDelete(List<dynamic> linkedEnvelopes) async {
    debugPrint('[AccountSettings] _unlinkEnvelopesAndDelete START');
    debugPrint('[AccountSettings] Deleting: ${widget.account.name} (${widget.account.id})');
    debugPrint('[AccountSettings] Switching to Budget Mode');

    setState(() => _saving = true);

    try {
      debugPrint('[AccountSettings] Calling deleteAccount...');
      // Delete the account (this automatically unlinks all envelopes via AccountRepo.deleteAccount)
      await widget.accountRepo.deleteAccount(widget.account.id);
      debugPrint('[AccountSettings] deleteAccount completed');

      // Note: Pay day settings should be cleared by the account repo when last account deleted

      if (mounted) {
        debugPrint('[AccountSettings] Widget still mounted, navigating back...');
        // Pop twice: once for settings screen, once for detail screen
        Navigator.pop(context);
        debugPrint('[AccountSettings] First pop complete');
        Navigator.pop(context);
        debugPrint('[AccountSettings] Second pop complete');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Switched to Budget Mode. ${linkedEnvelopes.length} envelope${linkedEnvelopes.length == 1 ? ' was' : 's were'} unlinked.',
            ),
          ),
        );
        debugPrint('[AccountSettings] Success message shown');
      } else {
        debugPrint('[AccountSettings] WARNING: Widget not mounted after delete!');
      }
    } catch (e) {
      debugPrint('[AccountSettings] ERROR in _unlinkEnvelopesAndDelete: $e');
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
    debugPrint('[AccountSettings] _unlinkEnvelopesAndDelete END');
  }

  Future<void> _performDelete() async {
    debugPrint('[AccountSettings] _performDelete START');
    debugPrint('[AccountSettings] Deleting: ${widget.account.name} (${widget.account.id})');

    setState(() => _saving = true);

    try {
      debugPrint('[AccountSettings] Calling deleteAccount...');
      await widget.accountRepo.deleteAccount(widget.account.id);
      debugPrint('[AccountSettings] deleteAccount completed');

      if (mounted) {
        debugPrint('[AccountSettings] Widget still mounted, navigating back...');
        // Pop twice: once for settings screen, once for detail screen
        Navigator.pop(context);
        debugPrint('[AccountSettings] First pop complete');
        Navigator.pop(context);
        debugPrint('[AccountSettings] Second pop complete');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deleted successfully')),
        );
        debugPrint('[AccountSettings] Success message shown');
      } else {
        debugPrint('[AccountSettings] WARNING: Widget not mounted after delete!');
      }
    } catch (e) {
      debugPrint('[AccountSettings] ERROR in _performDelete: $e');
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
    debugPrint('[AccountSettings] _performDelete END');
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
              SmartTextFormField(
                controller: _nameController,
                focusNode: _nameFocus,
                nextFocusNode: _balanceFocus,
                textCapitalization: TextCapitalization.words,
                autocorrect: false,
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
                      Image.asset(
                        'assets/default/stufficon.png',
                        width: 24,
                        height: 24,
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Icon',
                        style: fontProvider.getTextStyle(fontSize: 18),
                      ),
                      const Spacer(),
                      const Icon(Icons.add_photo_alternate_outlined),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Balance field with calculator inside
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

              // Default toggle (only show for bank accounts, not credit cards)
              if (_accountType == AccountType.bankAccount) ...[
                SwitchListTile(
                  value: _isDefault,
                  onChanged: (value) {
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
