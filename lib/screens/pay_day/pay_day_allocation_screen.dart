// lib/screens/pay_day/pay_day_allocation_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';
import '../../models/envelope.dart';
import '../../models/envelope_group.dart';
import '../../models/account.dart';
import '../../services/envelope_repo.dart';
import '../../services/group_repo.dart';
import '../../services/account_repo.dart';
import '../../providers/font_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_themes.dart';
import 'pay_day_stuffing_screen.dart';
import '../../utils/calculator_helper.dart';
import '../../utils/dialog_helpers.dart';

class PayDayAllocationScreen extends StatefulWidget {
  const PayDayAllocationScreen({
    super.key,
    required this.repo,
    required this.groupRepo,
    required this.accountRepo,
    required this.totalAmount,
    required this.accountId,
  });

  final EnvelopeRepo repo;
  final GroupRepo groupRepo;
  final AccountRepo accountRepo;
  final double totalAmount;
  final String accountId;

  @override
  State<PayDayAllocationScreen> createState() => _PayDayAllocationScreenState();
}

class _PayDayAllocationScreenState extends State<PayDayAllocationScreen> {
  // Track which envelopes are selected and their amounts
  Map<String, double> allocations = {};

  // Track which accounts are selected (separate from envelope allocations)
  Map<String, double> accountAllocations = {};

  // Track which binders are expanded
  Set<String> expandedBinderIds = {};

  // Track binders temporarily added for this pay day session
  Set<String> temporarilyAddedBinderIds = {};

  // All data
  List<Envelope> allEnvelopes = [];
  List<EnvelopeGroup> allBinders = [];
  List<Account> allBankAccounts = [];
  List<Account> allCreditCards = [];

  bool _loading = true;
  bool _hasShownTemporaryWarning = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final envelopeBox = Hive.box<Envelope>('envelopes');
      final groupBox = Hive.box<EnvelopeGroup>('groups');
      final accountBox = Hive.box<Account>('accounts');

      // Load all envelopes for current user (filter out virtual account envelopes)
      final envelopes = envelopeBox.values
          .where((e) =>
              e.userId == widget.repo.currentUserId &&
              !e.id.startsWith('_account_available_'))
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      // Load all groups for current user
      final binders = groupBox.values
          .where((g) => g.userId == widget.repo.currentUserId)
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      // Load all accounts for current user (exclude the default/source account)
      final accounts = accountBox.values
          .where((a) =>
              a.userId == widget.repo.currentUserId &&
              a.id != widget.accountId)
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      // Separate bank accounts and credit cards with auto-fill
      final bankAccounts = accounts
          .where((a) =>
              a.accountType == AccountType.bankAccount &&
              a.payDayAutoFillEnabled &&
              a.payDayAutoFillAmount != null &&
              a.payDayAutoFillAmount! > 0)
          .toList();

      final creditCards = accounts
          .where((a) =>
              a.accountType == AccountType.creditCard &&
              a.payDayAutoFillEnabled &&
              a.payDayAutoFillAmount != null &&
              a.payDayAutoFillAmount! > 0)
          .toList();

      // Initialize allocations with auto-fill envelopes
      final Map<String, double> initialAllocations = {};
      for (final env in envelopes) {
        if (env.autoFillEnabled && env.autoFillAmount != null && env.autoFillAmount! > 0) {
          initialAllocations[env.id] = env.autoFillAmount!;
        }
      }

      // Initialize account allocations with auto-fill accounts
      final Map<String, double> initialAccountAllocations = {};
      for (final account in [...bankAccounts, ...creditCards]) {
        initialAccountAllocations[account.id] = account.payDayAutoFillAmount!;
      }

      // Auto-expand pay day binders
      final autoExpandBinders = binders
          .where((b) => b.payDayEnabled)
          .map((b) => b.id)
          .toSet();

      if (mounted) {
        setState(() {
          allEnvelopes = envelopes;
          allBinders = binders;
          allBankAccounts = bankAccounts;
          allCreditCards = creditCards;
          allocations = initialAllocations;
          accountAllocations = initialAccountAllocations;
          expandedBinderIds = autoExpandBinders;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading allocation data: $e');
      if (mounted) {
        setState(() => _loading = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error loading data: $e')),
            );
          }
        });
      }
    }
  }

  double get totalAllocated {
    final envelopeAllocated = allocations.values.fold(0.0, (sum, amount) => sum + amount);
    final accountAllocated = accountAllocations.values.fold(0.0, (sum, amount) => sum + amount);
    return envelopeAllocated + accountAllocated;
  }

  double get remainingAmount => widget.totalAmount - totalAllocated;

  bool get canProcessPayDay => remainingAmount >= 0;

  Future<void> _showTemporaryChangeWarning() async {
    if (_hasShownTemporaryWarning) return;

    await DialogHelpers.showInfoDialog(
      context: context,
      title: 'Temporary Changes',
      message: 'Changes you make on this screen are temporary and only apply to this pay day session.\n\n'
          'To permanently change auto-fill settings, edit them in the envelope, binder, or account settings.',
      icon: Icons.info_outline,
    );

    setState(() {
      _hasShownTemporaryWarning = true;
    });
  }

  void _toggleEnvelope(String envelopeId, double? autoFillAmount) async {
    await _showTemporaryChangeWarning();

    setState(() {
      if (allocations.containsKey(envelopeId)) {
        allocations.remove(envelopeId);
      } else {
        allocations[envelopeId] = autoFillAmount ?? 0.0;
      }
    });
  }

  void _toggleAccount(String accountId, double? autoFillAmount) async {
    await _showTemporaryChangeWarning();

    setState(() {
      if (accountAllocations.containsKey(accountId)) {
        accountAllocations.remove(accountId);
      } else {
        accountAllocations[accountId] = autoFillAmount ?? 0.0;
      }
    });
  }

  Future<void> _editEnvelopeAmount(Envelope envelope) async {
    await _showTemporaryChangeWarning();

    if (!mounted) return;
    final result = await CalculatorHelper.showCalculator(context);

    if (result != null && mounted) {
      final amount = double.tryParse(result);
      if (amount != null && amount >= 0) {
        setState(() {
          if (amount > 0) {
            allocations[envelope.id] = amount;
          } else {
            allocations.remove(envelope.id);
          }
        });
      }
    }
  }

  Future<void> _editAccountAmount(Account account) async {
    await _showTemporaryChangeWarning();

    if (!mounted) return;
    final result = await CalculatorHelper.showCalculator(context);

    if (result != null && mounted) {
      final amount = double.tryParse(result);
      if (amount != null && amount >= 0) {
        setState(() {
          if (amount > 0) {
            accountAllocations[account.id] = amount;
          } else {
            accountAllocations.remove(account.id);
          }
        });
      }
    }
  }

  void _toggleBinder(String binderId) {
    setState(() {
      if (expandedBinderIds.contains(binderId)) {
        expandedBinderIds.remove(binderId);
      } else {
        expandedBinderIds.add(binderId);
      }
    });
  }

  Future<void> _addMoreItems() async {
    // Show info about temporary changes (only once per session)
    if (!_hasShownTemporaryWarning) {
      await DialogHelpers.showInfoDialog(
        context: context,
        title: 'Add Items Temporarily',
        message: 'Items you add here will only be included in this pay day session.\n\n'
            'To permanently enable auto-fill for an item, edit its settings from the main screen.',
        icon: Icons.info_outline,
      );

      setState(() {
        _hasShownTemporaryWarning = true;
      });
    }

    if (!mounted) return;

    // Get IDs that are already showing (including temporarily added binders)
    final payDayBinderIds = allBinders
        .where((b) => b.payDayEnabled || temporarilyAddedBinderIds.contains(b.id))
        .map((b) => b.id)
        .toSet();

    // Get envelopes already showing
    final alreadyShowingEnvelopes = allEnvelopes.where((env) {
      // In a pay day binder (including temporarily added)
      if (env.groupId != null && payDayBinderIds.contains(env.groupId)) {
        return true;
      }
      // Has auto-fill but not in a pay day binder
      if (env.autoFillEnabled &&
          env.autoFillAmount != null &&
          env.autoFillAmount! > 0 &&
          (env.groupId == null || !payDayBinderIds.contains(env.groupId))) {
        return true;
      }
      // Already in allocations (manually added)
      if (allocations.containsKey(env.id)) {
        return true;
      }
      return false;
    }).map((e) => e.id).toSet();

    // Available envelopes
    final availableEnvelopes = allEnvelopes
        .where((env) => !alreadyShowingEnvelopes.contains(env.id))
        .toList();

    // Available binders (those without pay day enabled and not temporarily added)
    final availableBinders = allBinders
        .where((b) => !b.payDayEnabled && !temporarilyAddedBinderIds.contains(b.id))
        .toList();

    // Available accounts (those without auto-fill and not already in allocations)
    final availableBankAccounts = Hive.box<Account>('accounts').values
        .where((a) =>
            a.userId == widget.repo.currentUserId &&
            a.id != widget.accountId &&
            a.accountType == AccountType.bankAccount &&
            !accountAllocations.containsKey(a.id) &&
            (!a.payDayAutoFillEnabled ||
                a.payDayAutoFillAmount == null ||
                a.payDayAutoFillAmount! <= 0))
        .toList();

    final availableCreditCards = Hive.box<Account>('accounts').values
        .where((a) =>
            a.userId == widget.repo.currentUserId &&
            a.id != widget.accountId &&
            a.accountType == AccountType.creditCard &&
            !accountAllocations.containsKey(a.id) &&
            (!a.payDayAutoFillEnabled ||
                a.payDayAutoFillAmount == null ||
                a.payDayAutoFillAmount! <= 0))
        .toList();

    if (availableEnvelopes.isEmpty && availableBinders.isEmpty &&
        availableBankAccounts.isEmpty && availableCreditCards.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All items are already visible')),
      );
      return;
    }

    // Show selection dialog
    if (!mounted) return;
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddItemSheet(
        envelopes: availableEnvelopes,
        binders: availableBinders,
        bankAccounts: availableBankAccounts,
        creditCards: availableCreditCards,
        allEnvelopes: allEnvelopes,
      ),
    );

    if (result != null && mounted) {
      final type = result['type'] as String;
      final item = result['item'];

      setState(() {
        if (type == 'envelope') {
          final envelope = item as Envelope;
          // Add with auto-fill amount or 0
          allocations[envelope.id] = envelope.autoFillAmount ?? 0.0;
        } else if (type == 'binder') {
          // Add binder temporarily (without permanently updating the database)
          final binder = item as EnvelopeGroup;
          temporarilyAddedBinderIds.add(binder.id);
          expandedBinderIds.add(binder.id);

          // Add all envelopes in this binder with their auto-fill amounts
          final binderEnvelopes = allEnvelopes.where((e) => e.groupId == binder.id);
          for (final env in binderEnvelopes) {
            if (env.autoFillEnabled && env.autoFillAmount != null && env.autoFillAmount! > 0) {
              allocations[env.id] = env.autoFillAmount!;
            }
          }
        } else if (type == 'account') {
          final account = item as Account;
          // Add with auto-fill amount or 0
          accountAllocations[account.id] = account.payDayAutoFillAmount ?? 0.0;
        }
      });
    }
  }

  void _continueToStuffing() {
    if (!canProcessPayDay) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Total allocation exceeds pay day amount by ${NumberFormat.currency(symbol: Provider.of<LocaleProvider>(context, listen: false).currencySymbol).format(remainingAmount.abs())}',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (allocations.isEmpty && accountAllocations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one item to allocate')),
      );
      return;
    }

    // Filter out any with 0 amount
    final validAllocations = Map<String, double>.fromEntries(
      allocations.entries.where((e) => e.value > 0),
    );

    final validAccountAllocations = Map<String, double>.fromEntries(
      accountAllocations.entries.where((e) => e.value > 0),
    );

    if (validAllocations.isEmpty && validAccountAllocations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please ensure selected items have amounts greater than 0')),
      );
      return;
    }

    // Get the envelope objects for stuffing
    final envelopesToStuff = allEnvelopes
        .where((env) => validAllocations.containsKey(env.id))
        .toList();

    // Get the account objects for stuffing
    final accountsToStuff = [...allBankAccounts, ...allCreditCards]
        .where((acc) => validAccountAllocations.containsKey(acc.id))
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PayDayStuffingScreen(
          repo: widget.repo,
          accountRepo: widget.accountRepo,
          allocations: validAllocations,
          envelopes: envelopesToStuff,
          accountAllocations: validAccountAllocations,
          accounts: accountsToStuff,
          totalAmount: widget.totalAmount,
          accountId: widget.accountId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final locale = Provider.of<LocaleProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);

    // Section 1: Pay day binders (including temporarily added ones)
    final payDayBinders = allBinders
        .where((b) => b.payDayEnabled || temporarilyAddedBinderIds.contains(b.id))
        .toList();

    // Section 2: Individual auto-fill envelopes not in pay day binders
    final payDayBinderIds = payDayBinders.map((b) => b.id).toSet();
    final individualAutoFillEnvelopes = allEnvelopes.where((env) {
      // Must have auto-fill enabled
      if (!env.autoFillEnabled || env.autoFillAmount == null || env.autoFillAmount! <= 0) {
        return false;
      }
      // Must not be in a pay day binder
      return env.groupId == null || !payDayBinderIds.contains(env.groupId);
    }).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'Pay Day Allocation',
                style: fontProvider.getTextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            Text(
              currency.format(widget.totalAmount),
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // SECTION 1: Pay Day Binders
                if (payDayBinders.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Binders',
                    Icons.folder_special,
                    theme,
                    fontProvider,
                    payDayBinders,
                    currency,
                  ),
                  const SizedBox(height: 16),
                  ...payDayBinders.map((binder) => _buildBinderSection(
                        binder,
                        theme,
                        fontProvider,
                        themeProvider,
                        currency,
                      )),
                  const SizedBox(height: 24),
                ],

                // SECTION 2: Individual Auto-Fill Envelopes
                if (individualAutoFillEnvelopes.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Envelopes',
                    Icons.mail,
                    theme,
                    fontProvider,
                    individualAutoFillEnvelopes,
                    currency,
                  ),
                  const SizedBox(height: 16),
                  ...individualAutoFillEnvelopes.map(
                    (env) => _buildEnvelopeTile(env, theme, fontProvider, currency),
                  ),
                  const SizedBox(height: 24),
                ],

                // SECTION 3: Bank Accounts
                if (allBankAccounts.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Accounts',
                    Icons.account_balance,
                    theme,
                    fontProvider,
                    allBankAccounts,
                    currency,
                    isAccount: true,
                  ),
                  const SizedBox(height: 16),
                  ...allBankAccounts.map(
                    (account) => _buildAccountTile(account, theme, fontProvider, currency),
                  ),
                  const SizedBox(height: 24),
                ],

                // SECTION 4: Credit Cards
                if (allCreditCards.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Credit Cards',
                    Icons.credit_card,
                    theme,
                    fontProvider,
                    allCreditCards,
                    currency,
                    isAccount: true,
                  ),
                  const SizedBox(height: 16),
                  ...allCreditCards.map(
                    (account) => _buildAccountTile(account, theme, fontProvider, currency),
                  ),
                  const SizedBox(height: 24),
                ],

                // Empty state
                if (payDayBinders.isEmpty &&
                    individualAutoFillEnvelopes.isEmpty &&
                    allBankAccounts.isEmpty &&
                    allCreditCards.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 48,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No Auto-Fill Setup',
                          style: fontProvider.getTextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enable auto-fill on binders, envelopes, or accounts to see them here!',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.orange.shade700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // Add More Button
                OutlinedButton.icon(
                  onPressed: _addMoreItems,
                  icon: const Icon(Icons.add_circle_outline),
                  label: Text(
                    'Add More Items',
                    style: fontProvider.getTextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Allocation Breakdown
                if (totalAllocated > 0) ...[
                  _buildAllocationBreakdown(theme, fontProvider, currency),
                  const SizedBox(height: 24),
                ],

                // Remaining Amount
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: canProcessPayDay
                          ? [
                              theme.colorScheme.secondaryContainer,
                              theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
                            ]
                          : [
                              Colors.red.shade100,
                              Colors.red.shade50,
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: canProcessPayDay
                          ? theme.colorScheme.secondary
                          : Colors.red.shade700,
                      width: 3,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        canProcessPayDay ? 'Remaining' : 'Over Budget!',
                        style: fontProvider.getTextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: canProcessPayDay ? null : Colors.red.shade900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currency.format(remainingAmount.abs()),
                        style: fontProvider.getTextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: canProcessPayDay
                              ? theme.colorScheme.secondary
                              : Colors.red.shade700,
                        ),
                      ),
                      if (!canProcessPayDay)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Remove some allocations to continue',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
      bottomNavigationBar: _loading
          ? null
          : _buildStartStuffingButton(theme, fontProvider),
    );
  }

  Widget _buildStartStuffingButton(ThemeData theme, FontProvider fontProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: canProcessPayDay
            ? _PulsingButton(
                onPressed: _continueToStuffing,
                color: theme.colorScheme.secondary,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.celebration, size: 28, color: Colors.white),
                    const SizedBox(width: 12),
                    Text(
                      'Start Stuffing!',
                      style: fontProvider.getTextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
            : Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.block, size: 28, color: Colors.white),
                    const SizedBox(width: 12),
                    Text(
                      'Over Budget',
                      style: fontProvider.getTextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    IconData icon,
    ThemeData theme,
    FontProvider fontProvider,
    List<dynamic> items,
    NumberFormat currency, {
    bool isAccount = false,
  }) {
    double totalBalance = 0;
    double totalAutoFill = 0;
    int itemCount = 0;

    if (isAccount) {
      final accounts = items.cast<Account>();
      for (final account in accounts) {
        totalBalance += account.currentBalance;
        if (accountAllocations.containsKey(account.id)) {
          totalAutoFill += accountAllocations[account.id]!;
          itemCount++;
        }
      }
    } else if (items.first is EnvelopeGroup) {
      final binders = items.cast<EnvelopeGroup>();
      for (final binder in binders) {
        final binderEnvelopes = allEnvelopes.where((e) => e.groupId == binder.id).toList();
        for (final env in binderEnvelopes) {
          totalBalance += env.currentAmount;
          if (allocations.containsKey(env.id)) {
            totalAutoFill += allocations[env.id]!;
          }
        }
        itemCount += binderEnvelopes.length;
      }
    } else {
      final envelopes = items.cast<Envelope>();
      for (final env in envelopes) {
        totalBalance += env.currentAmount;
        if (allocations.containsKey(env.id)) {
          totalAutoFill += allocations[env.id]!;
          itemCount++;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: fontProvider.getTextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Balance',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  Text(
                    currency.format(totalBalance),
                    style: fontProvider.getTextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Auto-fill Amount',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  Text(
                    currency.format(totalAutoFill),
                    style: fontProvider.getTextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (items.first is EnvelopeGroup)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '(out of $itemCount envelopes)',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAllocationBreakdown(
    ThemeData theme,
    FontProvider fontProvider,
    NumberFormat currency,
  ) {
    final payDayBinders = allBinders.where((b) => b.payDayEnabled).toList();
    final payDayBinderIds = payDayBinders.map((b) => b.id).toSet();
    final individualAutoFillEnvelopes = allEnvelopes.where((env) {
      if (!env.autoFillEnabled || env.autoFillAmount == null || env.autoFillAmount! <= 0) {
        return false;
      }
      return env.groupId == null || !payDayBinderIds.contains(env.groupId);
    }).toList();

    // Calculate totals for each section
    double bindersTotal = 0;
    for (final binder in payDayBinders) {
      final binderEnvelopes = allEnvelopes.where((e) => e.groupId == binder.id);
      for (final env in binderEnvelopes) {
        if (allocations.containsKey(env.id)) {
          bindersTotal += allocations[env.id]!;
        }
      }
    }

    double envelopesTotal = 0;
    for (final env in individualAutoFillEnvelopes) {
      if (allocations.containsKey(env.id)) {
        envelopesTotal += allocations[env.id]!;
      }
    }

    double accountsTotal = 0;
    for (final account in allBankAccounts) {
      if (accountAllocations.containsKey(account.id)) {
        accountsTotal += accountAllocations[account.id]!;
      }
    }

    double creditCardsTotal = 0;
    for (final account in allCreditCards) {
      if (accountAllocations.containsKey(account.id)) {
        creditCardsTotal += accountAllocations[account.id]!;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.tertiary.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Allocation Breakdown',
            style: fontProvider.getTextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.tertiary,
            ),
          ),
          const SizedBox(height: 16),
          if (bindersTotal > 0)
            _buildBreakdownRow(
              'Binders',
              bindersTotal,
              bindersTotal / widget.totalAmount * 100,
              theme,
              fontProvider,
              currency,
            ),
          if (envelopesTotal > 0)
            _buildBreakdownRow(
              'Envelopes',
              envelopesTotal,
              envelopesTotal / widget.totalAmount * 100,
              theme,
              fontProvider,
              currency,
            ),
          if (accountsTotal > 0)
            _buildBreakdownRow(
              'Accounts',
              accountsTotal,
              accountsTotal / widget.totalAmount * 100,
              theme,
              fontProvider,
              currency,
            ),
          if (creditCardsTotal > 0)
            _buildBreakdownRow(
              'Credit Cards',
              creditCardsTotal,
              creditCardsTotal / widget.totalAmount * 100,
              theme,
              fontProvider,
              currency,
            ),
          if (remainingAmount > 0) ...[
            const Divider(height: 24),
            _buildBreakdownRow(
              'Remaining',
              remainingAmount,
              remainingAmount / widget.totalAmount * 100,
              theme,
              fontProvider,
              currency,
              isRemaining: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(
    String label,
    double amount,
    double percentage,
    ThemeData theme,
    FontProvider fontProvider,
    NumberFormat currency, {
    bool isRemaining = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: fontProvider.getTextStyle(
                fontSize: 16,
                fontWeight: isRemaining ? FontWeight.bold : FontWeight.w600,
                color: isRemaining
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: fontProvider.getTextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.tertiary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            currency.format(amount),
            style: fontProvider.getTextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isRemaining
                  ? theme.colorScheme.secondary
                  : theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  void _toggleAllEnvelopesInBinder(String binderId) async {
    await _showTemporaryChangeWarning();

    final binderEnvelopes = allEnvelopes
        .where((env) => env.groupId == binderId)
        .toList();

    // Check if all envelopes are selected
    final allSelected = binderEnvelopes.every((env) => allocations.containsKey(env.id));

    setState(() {
      if (allSelected) {
        // Deselect all
        for (final env in binderEnvelopes) {
          allocations.remove(env.id);
        }
      } else {
        // Select all with their auto-fill amounts
        for (final env in binderEnvelopes) {
          allocations[env.id] = env.autoFillAmount ?? 0.0;
        }
      }
    });
  }

  Widget _buildBinderSection(
    EnvelopeGroup binder,
    ThemeData theme,
    FontProvider fontProvider,
    ThemeProvider themeProvider,
    NumberFormat currency,
  ) {
    final isExpanded = expandedBinderIds.contains(binder.id);
    final binderEnvelopes = allEnvelopes
        .where((env) => env.groupId == binder.id)
        .toList();

    final binderColorOption = ThemeBinderColors.getColorsForTheme(
      themeProvider.currentThemeId,
    )[binder.colorIndex];

    // Calculate binder totals and selection state
    double binderBalance = 0;
    double binderAutoFill = 0;
    int selectedCount = 0;
    for (final env in binderEnvelopes) {
      binderBalance += env.currentAmount;
      if (allocations.containsKey(env.id)) {
        binderAutoFill += allocations[env.id]!;
        selectedCount++;
      }
    }
    final allSelected = selectedCount == binderEnvelopes.length && binderEnvelopes.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: binderColorOption.paperColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: binderColorOption.envelopeBorderColor,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // Binder header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: allSelected,
                      tristate: true,
                      onChanged: (value) => _toggleAllEnvelopesInBinder(binder.id),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _toggleBinder(binder.id),
                      child: Row(
                        children: [
                          binder.getIconWidget(theme, size: 32),
                          const SizedBox(width: 12),
                        ],
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => _toggleBinder(binder.id),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              binder.name,
                              style: fontProvider.getTextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: binderColorOption.envelopeTextColor,
                              ),
                            ),
                            Text(
                              '(${binderEnvelopes.length} envelopes)',
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: binderColorOption.envelopeTextColor.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => _toggleBinder(binder.id),
                      child: Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: binderColorOption.envelopeTextColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Balance',
                            style: TextStyle(
                              fontSize: 11,
                              color: binderColorOption.envelopeTextColor.withValues(alpha: 0.6),
                            ),
                          ),
                          Text(
                            currency.format(binderBalance),
                            style: fontProvider.getTextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: binderColorOption.envelopeTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Auto-fill',
                            style: TextStyle(
                              fontSize: 11,
                              color: binderColorOption.envelopeTextColor.withValues(alpha: 0.6),
                            ),
                          ),
                          Text(
                            currency.format(binderAutoFill),
                            style: fontProvider.getTextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: binderColorOption.envelopeTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Envelopes in binder
          if (isExpanded) ...[
            const Divider(height: 1),
            ...binderEnvelopes.map((env) => _buildEnvelopeTile(
                  env,
                  theme,
                  fontProvider,
                  currency,
                  inBinder: true,
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildEnvelopeTile(
    Envelope envelope,
    ThemeData theme,
    FontProvider fontProvider,
    NumberFormat currency, {
    bool inBinder = false,
  }) {
    final isSelected = allocations.containsKey(envelope.id);
    final amount = allocations[envelope.id] ?? 0.0;

    // Get binder name if envelope is in a binder without pay day enabled
    String? binderLabel;
    if (envelope.groupId != null) {
      final binder = allBinders.firstWhere(
        (b) => b.id == envelope.groupId,
        orElse: () => allBinders.first,
      );
      if (!binder.payDayEnabled) {
        binderLabel = 'in ${binder.name}';
      }
    }

    return Container(
      margin: EdgeInsets.only(
        bottom: 8,
        left: inBinder ? 16 : 0,
        right: inBinder ? 16 : 0,
        top: inBinder ? 8 : 0,
      ),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.outline.withValues(alpha: 0.3),
          width: isSelected ? 3 : 2,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (value) => _toggleEnvelope(envelope.id, envelope.autoFillAmount),
            ),
            const SizedBox(width: 8),
            Text(
              envelope.emoji ?? '📨',
              style: TextStyle(
                fontSize: 32,
                color: isSelected ? null : Colors.grey,
              ),
            ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                envelope.name,
                style: fontProvider.getTextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
            if (isSelected)
              IconButton(
                icon: Icon(
                  Icons.settings,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                onPressed: () => _editEnvelopeAmount(envelope),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (binderLabel != null)
              Text(
                binderLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  fontStyle: FontStyle.italic,
                ),
              ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  'Balance: ${currency.format(envelope.currentAmount)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: isSelected
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.8)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                Text(
                  'Auto-fill: ${currency.format(amount)}',
                  style: fontProvider.getTextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountTile(
    Account account,
    ThemeData theme,
    FontProvider fontProvider,
    NumberFormat currency,
  ) {
    final isSelected = accountAllocations.containsKey(account.id);
    final amount = accountAllocations[account.id] ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.outline.withValues(alpha: 0.3),
          width: isSelected ? 3 : 2,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (value) => _toggleAccount(account.id, account.payDayAutoFillAmount),
            ),
            const SizedBox(width: 8),
            account.getIconWidget(theme, size: 32),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                account.name,
                style: fontProvider.getTextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
            if (isSelected)
              IconButton(
                icon: Icon(
                  Icons.settings,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                onPressed: () => _editAccountAmount(account),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
        subtitle: Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            Text(
              'Balance: ${currency.format(account.currentBalance)}',
              style: TextStyle(
                fontSize: 14,
                color: isSelected
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.8)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            Text(
              'Auto-fill: ${currency.format(amount)}',
              style: fontProvider.getTextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Add item selection sheet
class _AddItemSheet extends StatefulWidget {
  final List<Envelope> envelopes;
  final List<EnvelopeGroup> binders;
  final List<Account> bankAccounts;
  final List<Account> creditCards;
  final List<Envelope> allEnvelopes;

  const _AddItemSheet({
    required this.envelopes,
    required this.binders,
    required this.bankAccounts,
    required this.creditCards,
    required this.allEnvelopes,
  });

  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final locale = Provider.of<LocaleProvider>(context, listen: false);
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);

    final tabs = <String>[];
    if (widget.binders.isNotEmpty) tabs.add('Binders');
    if (widget.envelopes.isNotEmpty) tabs.add('Envelopes');
    if (widget.bankAccounts.isNotEmpty) tabs.add('Accounts');
    if (widget.creditCards.isNotEmpty) tabs.add('Credit Cards');

    if (tabs.isEmpty) {
      return Container(
        height: 200,
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'No items available to add',
            style: fontProvider.getTextStyle(fontSize: 18),
          ),
        ),
      );
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Icon(
                  Icons.add_circle,
                  size: 28,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Add Items',
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
          if (tabs.length > 1)
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: tabs.length,
                itemBuilder: (context, index) {
                  final isSelected = _selectedTab == index;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(tabs[index]),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedTab = index);
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
          Expanded(
            child: _buildTabContent(tabs[_selectedTab], theme, fontProvider, currency),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(
    String tab,
    ThemeData theme,
    FontProvider fontProvider,
    NumberFormat currency,
  ) {
    Widget content;

    switch (tab) {
      case 'Binders':
        content = ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: widget.binders.length,
          itemBuilder: (context, index) {
            final binder = widget.binders[index];
            final binderEnvelopes = widget.allEnvelopes
                .where((e) => e.groupId == binder.id)
                .toList();
            final totalBalance = binderEnvelopes.fold<double>(
              0,
              (sum, env) => sum + env.currentAmount,
            );

            return ListTile(
              leading: binder.getIconWidget(theme, size: 32),
              title: Text(
                binder.name,
                style: fontProvider.getTextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'Balance: ${currency.format(totalBalance)} (${binderEnvelopes.length} envelopes)',
                style: const TextStyle(fontSize: 14),
              ),
              onTap: () => Navigator.pop(context, {
                'type': 'binder',
                'item': binder,
              }),
            );
          },
        );
        break;

      case 'Envelopes':
        content = ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: widget.envelopes.length,
          itemBuilder: (context, index) {
            final envelope = widget.envelopes[index];
            return ListTile(
              leading: Text(
                envelope.emoji ?? '📨',
                style: const TextStyle(fontSize: 32),
              ),
              title: Text(
                envelope.name,
                style: fontProvider.getTextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'Balance: ${currency.format(envelope.currentAmount)}',
                style: const TextStyle(fontSize: 14),
              ),
              onTap: () => Navigator.pop(context, {
                'type': 'envelope',
                'item': envelope,
              }),
            );
          },
        );
        break;

      case 'Accounts':
        content = ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: widget.bankAccounts.length,
          itemBuilder: (context, index) {
            final account = widget.bankAccounts[index];
            return ListTile(
              leading: account.getIconWidget(theme, size: 32),
              title: Text(
                account.name,
                style: fontProvider.getTextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'Balance: ${currency.format(account.currentBalance)}',
                style: const TextStyle(fontSize: 14),
              ),
              onTap: () => Navigator.pop(context, {
                'type': 'account',
                'item': account,
              }),
            );
          },
        );
        break;

      case 'Credit Cards':
        content = ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: widget.creditCards.length,
          itemBuilder: (context, index) {
            final account = widget.creditCards[index];
            return ListTile(
              leading: account.getIconWidget(theme, size: 32),
              title: Text(
                account.name,
                style: fontProvider.getTextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'Balance: ${currency.format(account.currentBalance)}',
                style: const TextStyle(fontSize: 14),
              ),
              onTap: () => Navigator.pop(context, {
                'type': 'account',
                'item': account,
              }),
            );
          },
        );
        break;

      default:
        content = const SizedBox.shrink();
    }

    return content;
  }
}

// Pulsing button with glow effect
class _PulsingButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Color color;
  final Widget child;

  const _PulsingButton({
    required this.onPressed,
    required this.color,
    required this.child,
  });

  @override
  State<_PulsingButton> createState() => _PulsingButtonState();
}

class _PulsingButtonState extends State<_PulsingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: _glowAnimation.value),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Material(
              color: widget.color,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: widget.onPressed,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: widget.child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
