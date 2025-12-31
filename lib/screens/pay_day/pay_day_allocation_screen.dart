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
  // Track which envelopes/accounts are selected and their amounts
  Map<String, double> allocations = {};

  // Track which accounts are selected (separate from envelope allocations)
  Map<String, double> accountAllocations = {};

  // Track which binders are expanded
  Set<String> expandedBinderIds = {};

  // All data
  List<Envelope> allEnvelopes = [];
  List<EnvelopeGroup> allBinders = [];
  List<Account> allAccounts = [];

  bool _loading = true;

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
              !e.id.startsWith('_account_available_')) // Filter virtual envelopes
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
              a.id != widget.accountId && // Don't auto-fill to source account
              a.payDayAutoFillEnabled &&
              a.payDayAutoFillAmount != null &&
              a.payDayAutoFillAmount! > 0)
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      // Initialize allocations with auto-fill envelopes
      final Map<String, double> initialAllocations = {};
      for (final env in envelopes) {
        debugPrint('[PayDay] Envelope: ${env.name}, autoFillEnabled: ${env.autoFillEnabled}, autoFillAmount: ${env.autoFillAmount}');
        if (env.autoFillEnabled && env.autoFillAmount != null && env.autoFillAmount! > 0) {
          initialAllocations[env.id] = env.autoFillAmount!;
          debugPrint('[PayDay] ✅ Added to initial allocations: ${env.name} = ${env.autoFillAmount}');
        }
      }

      // Initialize account allocations with auto-fill accounts
      final Map<String, double> initialAccountAllocations = {};
      for (final account in accounts) {
        initialAccountAllocations[account.id] = account.payDayAutoFillAmount!;
        debugPrint('[PayDay] ✅ Added account to allocations: ${account.name} = ${account.payDayAutoFillAmount}');
      }

      debugPrint('[PayDay] Total envelopes: ${envelopes.length}, Initial allocations: ${initialAllocations.length}');
      debugPrint('[PayDay] Total accounts: ${accounts.length}, Initial account allocations: ${initialAccountAllocations.length}');

      // Auto-expand pay day binders
      final autoExpandBinders = binders
          .where((b) => b.payDayEnabled)
          .map((b) => b.id)
          .toSet();

      debugPrint('[PayDay] Pay day binders: ${autoExpandBinders.length}');

      if (mounted) {
        setState(() {
          allEnvelopes = envelopes;
          allBinders = binders;
          allAccounts = accounts;
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
        // Show error after build completes
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

  double get remainingAmount {
    final envelopeAllocated = allocations.values.fold(0.0, (sum, amount) => sum + amount);
    final accountAllocated = accountAllocations.values.fold(0.0, (sum, amount) => sum + amount);
    return widget.totalAmount - envelopeAllocated - accountAllocated;
  }

  void _toggleEnvelope(String envelopeId, double? autoFillAmount) {
    setState(() {
      if (allocations.containsKey(envelopeId)) {
        // Remove it
        allocations.remove(envelopeId);
      } else {
        // Add it with auto-fill amount or 0
        allocations[envelopeId] = autoFillAmount ?? 0.0;
      }
    });
  }

  Future<void> _editAmount(Envelope envelope) async {
    final result = await CalculatorHelper.showCalculator(context);

    if (result != null && mounted) {
      final amount = double.tryParse(result);
      if (amount != null && amount > 0) {
        setState(() {
          allocations[envelope.id] = amount;
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

  Future<void> _addEnvelope() async {
    // Get IDs that are already showing in sections 1 & 2
    final payDayBinderIds = allBinders
        .where((b) => b.payDayEnabled)
        .map((b) => b.id)
        .toSet();

    final alreadyShowing = allEnvelopes.where((env) {
      // In a pay day binder (section 1)
      if (env.groupId != null && payDayBinderIds.contains(env.groupId)) {
        return true;
      }
      // Has auto-fill but not in a pay day binder (section 2)
      if (env.autoFillEnabled &&
          env.autoFillAmount != null &&
          env.autoFillAmount! > 0 &&
          (env.groupId == null || !payDayBinderIds.contains(env.groupId))) {
        return true;
      }
      return false;
    }).map((e) => e.id).toSet();

    // Available envelopes are those not already showing
    final availableEnvelopes = allEnvelopes
        .where((env) => !alreadyShowing.contains(env.id))
        .toList();

    if (availableEnvelopes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All envelopes are already visible')),
      );
      return;
    }

    // Show selection dialog
    final selected = await showModalBottomSheet<Envelope>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddEnvelopeSheet(envelopes: availableEnvelopes),
    );

    if (selected != null && mounted) {
      // Prompt for amount
      final result = await CalculatorHelper.showCalculator(context);
      if (result != null && mounted) {
        final amount = double.tryParse(result);
        if (amount != null && amount > 0) {
          setState(() {
            allocations[selected.id] = amount;
          });
        }
      }
    }
  }

  void _continueToStuffing() {
    if (allocations.isEmpty && accountAllocations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one envelope or account')),
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
    final accountsToStuff = allAccounts
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

    // Section 1: Pay day binders
    final payDayBinders = allBinders.where((b) => b.payDayEnabled).toList();

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
                'Pay Day',
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
                  Row(
                    children: [
                      Icon(
                        Icons.folder_special,
                        color: theme.colorScheme.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Pay Day Binders',
                          style: fontProvider.getTextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
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
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: theme.colorScheme.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Auto-Fill Envelopes',
                          style: fontProvider.getTextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...individualAutoFillEnvelopes.map(
                    (env) => _buildEnvelopeTile(env, theme, fontProvider, currency),
                  ),
                  const SizedBox(height: 24),
                ],

                // SECTION 3: Auto-Fill Accounts
                if (allAccounts.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance,
                        color: theme.colorScheme.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Auto-Fill Accounts',
                          style: fontProvider.getTextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...allAccounts.map(
                    (account) => _buildAccountTile(account, theme, fontProvider, currency),
                  ),
                  const SizedBox(height: 24),
                ],

                // Empty state
                if (payDayBinders.isEmpty && individualAutoFillEnvelopes.isEmpty && allAccounts.isEmpty)
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
                          'Enable auto-fill on envelopes or binders to see them here!',
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
                  onPressed: _addEnvelope,
                  icon: const Icon(Icons.add_circle_outline),
                  label: Text(
                    'Add More Envelopes',
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

                // Remaining Amount
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.secondaryContainer,
                        theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.secondary,
                      width: 3,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '💵 Remaining',
                        style: fontProvider.getTextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currency.format(remainingAmount),
                        style: fontProvider.getTextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                      if (remainingAmount < 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '⚠️ You\'re over budget!',
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

                const SizedBox(height: 80),
              ],
            ),
      floatingActionButton: _loading
          ? null
          : FloatingActionButton.extended(
              onPressed: _continueToStuffing,
              backgroundColor: theme.colorScheme.secondary,
              icon: const Icon(Icons.celebration, size: 28),
              label: Text(
                'Start Stuffing! 🎉',
                style: fontProvider.getTextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
    );
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
          InkWell(
            onTap: () => _toggleBinder(binder.id),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  binder.getIconWidget(theme, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      binder.name,
                      style: fontProvider.getTextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: binderColorOption.envelopeTextColor,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: binderColorOption.envelopeTextColor,
                  ),
                ],
              ),
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
    final hasAutoFill = envelope.autoFillEnabled &&
                        envelope.autoFillAmount != null &&
                        envelope.autoFillAmount! > 0;

    return Container(
      margin: EdgeInsets.only(
        bottom: 8,
        left: inBinder ? 16 : 0,
        right: inBinder ? 16 : 0,
        top: inBinder ? 8 : 0,
      ),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.3)
              : theme.colorScheme.outline.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (value) => _toggleEnvelope(envelope.id, envelope.autoFillAmount),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        secondary: Text(
          envelope.emoji ?? '📨',
          style: TextStyle(
            fontSize: 32,
            color: isSelected ? null : Colors.grey,
          ),
        ),
        title: Text(
          envelope.name,
          style: fontProvider.getTextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isSelected
                ? theme.colorScheme.secondary
                : theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (envelope.subtitle != null && envelope.subtitle!.isNotEmpty)
              Text(
                envelope.subtitle!,
                style: TextStyle(
                  fontSize: 14,
                  color: isSelected
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  fontStyle: FontStyle.italic,
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  currency.format(amount),
                  style: fontProvider.getTextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _editAmount(envelope),
                    child: Icon(
                      Icons.edit,
                      size: 16,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                ],
                if (hasAutoFill && !isSelected)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      '(Auto: ${currency.format(envelope.autoFillAmount)})',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
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
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.3)
              : theme.colorScheme.outline.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (value) {
          setState(() {
            if (accountAllocations.containsKey(account.id)) {
              accountAllocations.remove(account.id);
            } else {
              accountAllocations[account.id] = account.payDayAutoFillAmount ?? 0.0;
            }
          });
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        secondary: account.getIconWidget(theme, size: 32),
        title: Text(
          account.name,
          style: fontProvider.getTextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isSelected
                ? theme.colorScheme.secondary
                : theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                currency.format(amount),
                style: fontProvider.getTextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
            if (isSelected)
              IconButton(
                icon: Icon(
                  Icons.edit,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                onPressed: () => _editAccountAmount(account),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _editAccountAmount(Account account) async {
    final result = await CalculatorHelper.showCalculator(context);

    if (result != null && mounted) {
      final amount = double.tryParse(result);
      if (amount != null && amount > 0) {
        setState(() {
          accountAllocations[account.id] = amount;
        });
      }
    }
  }
}

// Add envelope selection sheet
class _AddEnvelopeSheet extends StatelessWidget {
  final List<Envelope> envelopes;

  const _AddEnvelopeSheet({required this.envelopes});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

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
                    'Add Envelope',
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
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: envelopes.length,
              itemBuilder: (context, index) {
                final envelope = envelopes[index];
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
                  subtitle: envelope.subtitle != null && envelope.subtitle!.isNotEmpty
                      ? Text(
                          envelope.subtitle!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      : null,
                  onTap: () => Navigator.pop(context, envelope),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
