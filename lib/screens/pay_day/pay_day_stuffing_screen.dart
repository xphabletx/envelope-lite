// lib/screens/pay_day/pay_day_stuffing_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';
import '../../models/envelope.dart';
import '../../models/envelope_group.dart';
import '../../models/account.dart';
import '../../models/pay_day_settings.dart';
import '../../services/envelope_repo.dart';
import '../../services/account_repo.dart';
import '../../services/group_repo.dart';
import '../../providers/font_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_themes.dart';
import '../../widgets/binder/stuffing_binder_card.dart';

class PayDayStuffingScreen extends StatefulWidget {
  const PayDayStuffingScreen({
    super.key,
    required this.repo,
    required this.accountRepo,
    required this.allocations,
    required this.envelopes,
    this.accountAllocations = const {},
    this.accounts = const [],
    required this.totalAmount,
    this.accountId,
  });

  final EnvelopeRepo repo;
  final AccountRepo accountRepo;
  final Map<String, double> allocations;
  final List<Envelope> envelopes;
  final Map<String, double> accountAllocations;
  final List<Account> accounts;
  final double totalAmount;
  final String? accountId;

  @override
  State<PayDayStuffingScreen> createState() => _PayDayStuffingScreenState();
}

class _PayDayStuffingScreenState extends State<PayDayStuffingScreen>
    with SingleTickerProviderStateMixin {

  // Binder groups
  final List<_BinderGroup> _binderGroups = [];
  final List<Envelope> _ungroupedEnvelopes = [];

  // Stuffing state
  int _currentBinderIndex = -1;
  int _currentEnvelopeIndex = -1;

  // Account balance animation
  double _accountBalance = 0.0;
  double _accountStartBalance = 0.0;
  double _accountEndBalance = 0.0;
  bool _showingDeposit = false;

  // Completion state
  bool _isComplete = false;
  double _totalEnvelopeStuffed = 0.0;
  double _totalAccountStuffed = 0.0;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _loadData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    // Get default account if specified
    if (widget.accountId != null) {
      final account = await widget.accountRepo.getAccount(widget.accountId!);
      if (account != null) {
        setState(() {
          _accountStartBalance = account.currentBalance;
          _accountBalance = account.currentBalance;
        });
      }
    }

    // Get all groups
    final groupRepo = GroupRepo(widget.repo);
    final allGroups = groupRepo.getAllGroups();

    // Group envelopes by binder
    if (!mounted) return;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    for (final group in allGroups) {
      final binderEnvelopes = widget.envelopes
          .where((e) => e.groupId == group.id)
          .toList();

      if (binderEnvelopes.isNotEmpty) {
        // Get binder colors
        final binderColors = ThemeBinderColors.getColorsForTheme(
          themeProvider.currentThemeId,
        )[group.colorIndex.clamp(0, ThemeBinderColors.getColorsForTheme(themeProvider.currentThemeId).length - 1)];

        _binderGroups.add(_BinderGroup(
          group: group,
          envelopes: binderEnvelopes,
          binderColors: binderColors,
        ));
      }
    }

    // Get ungrouped envelopes
    _ungroupedEnvelopes.addAll(
      widget.envelopes.where((e) => e.groupId == null).toList()
    );

    // Calculate totals
    _totalEnvelopeStuffed = widget.allocations.values.fold(0.0, (a, b) => a + b);
    _totalAccountStuffed = widget.accountAllocations.values.fold(0.0, (a, b) => a + b);

    _accountEndBalance = _accountStartBalance + widget.totalAmount - _totalEnvelopeStuffed - _totalAccountStuffed;

    setState(() {});

    // Start stuffing animation after a brief delay
    await Future.delayed(const Duration(milliseconds: 800));
    _startStuffing();
  }

  Future<void> _startStuffing() async {
    // STEP 1: Show the Pay Day Source (EXTERNAL → INTERNAL boundary)
    if (widget.accountId != null) {
      // WITH ACCOUNT: Show deposit animation
      setState(() => _showingDeposit = true);

      // Animate deposit into account
      await Future.delayed(const Duration(milliseconds: 600));
      setState(() {
        _accountBalance = _accountStartBalance + widget.totalAmount;
      });

      HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 1200));
      setState(() => _showingDeposit = false);
      await Future.delayed(const Duration(milliseconds: 400));
    } else {
      // WITHOUT ACCOUNT: Show Cash Rack animation
      setState(() => _showingDeposit = true);
      await Future.delayed(const Duration(milliseconds: 1200));
      setState(() => _showingDeposit = false);
      await Future.delayed(const Duration(milliseconds: 400));
    }

    // STEP 2: Process each binder
    for (int i = 0; i < _binderGroups.length; i++) {
      setState(() {
        _currentBinderIndex = i;
        _currentEnvelopeIndex = -1;
      });

      // Open binder (animation handled by widget)
      await Future.delayed(const Duration(milliseconds: 500));

      // Stuff each envelope in this binder
      for (int j = 0; j < _binderGroups[i].envelopes.length; j++) {
        setState(() {
          _currentEnvelopeIndex = j;
        });

        await _stuffEnvelope(_binderGroups[i].envelopes[j]);

        // Play haptic feedback
        HapticFeedback.mediumImpact();

        // Pause between envelopes (longer for satisfying effect)
        await Future.delayed(const Duration(milliseconds: 700));
      }

      // Close binder
      setState(() {
        _currentBinderIndex = -1;
      });

      await Future.delayed(const Duration(milliseconds: 400));
    }

    // Process ungrouped envelopes
    if (_ungroupedEnvelopes.isNotEmpty) {
      setState(() {
        _currentBinderIndex = -2; // Special index for "Other Envelopes"
        _currentEnvelopeIndex = -1;
      });

      await Future.delayed(const Duration(milliseconds: 500));

      for (int i = 0; i < _ungroupedEnvelopes.length; i++) {
        setState(() {
          _currentEnvelopeIndex = i;
        });

        await _stuffEnvelope(_ungroupedEnvelopes[i]);

        HapticFeedback.mediumImpact();
        await Future.delayed(const Duration(milliseconds: 700));
      }
    }

    // Process account auto-fills (transfers to other accounts)
    for (int i = 0; i < widget.accounts.length; i++) {
      final targetAccount = widget.accounts[i];
      final amount = widget.accountAllocations[targetAccount.id] ?? 0.0;

      try {
        // Update target account balance (transfer from default account)
        await widget.accountRepo.adjustBalance(
          accountId: targetAccount.id,
          amount: amount,
        );

        debugPrint('[PayDay] ✅ Cash Flow to account: ${targetAccount.name} = $amount');

        // Update animated balance
        setState(() {
          _accountBalance -= amount;
        });

        await Future.delayed(const Duration(milliseconds: 300));
      } catch (e) {
        debugPrint('Error auto-filling account ${targetAccount.name}: $e');
      }
    }

    // Update Default Account Balance (if account is specified)
    if (widget.accountId != null) {
      try {
        // Step 1: Deposit pay amount to account (EXTERNAL income)
        await widget.accountRepo.deposit(
          widget.accountId!,
          widget.totalAmount,
          description: 'Pay Day Deposit',
        );

        debugPrint('[PayDay] ✅ Deposited pay amount: ${widget.totalAmount}');

        // Note: Envelope cash flows are handled by transferToEnvelope() in _stuffEnvelope()
        // which creates paired transactions on both account and envelope sides.
        // No need for separate withdrawals here.

        // Step 2: Withdraw account cash flows from account (account-to-account transfers)
        if (_totalAccountStuffed > 0) {
          await widget.accountRepo.withdraw(
            widget.accountId!,
            _totalAccountStuffed,
            description: 'Cash Flow to Accounts',
          );

          debugPrint('[PayDay] ✅ Withdrew account cash flows: $_totalAccountStuffed');
        }
      } catch (e) {
        debugPrint('Error updating account balance: $e');
      }
    }

    // Update Settings History in Hive
    try {
      final userId = widget.repo.currentUserId;
      final payDayBox = Hive.box<PayDaySettings>('payDaySettings');

      PayDaySettings? existingSettings;
      String? settingsKey;
      for (var key in payDayBox.keys) {
        final settings = payDayBox.get(key);
        if (settings?.userId == userId) {
          existingSettings = settings;
          settingsKey = key.toString();
          break;
        }
      }

      final updatedSettings = existingSettings?.copyWith(
        lastPayAmount: widget.totalAmount,
        lastPayDate: DateTime.now(),
        defaultAccountId: widget.accountId,
      ) ?? PayDaySettings(
        userId: userId,
        lastPayAmount: widget.totalAmount,
        lastPayDate: DateTime.now(),
        defaultAccountId: widget.accountId,
        payFrequency: 'monthly',
      );

      final key = settingsKey ?? 'settings_$userId';
      await payDayBox.put(key, updatedSettings);
    } catch (e) {
      debugPrint('Error updating settings: $e');
    }

    // Show completion
    setState(() {
      _isComplete = true;
    });
  }

  Future<void> _stuffEnvelope(Envelope envelope) async {
    final amount = widget.allocations[envelope.id] ?? 0.0;

    try {
      if (widget.accountId != null) {
        // WITH ACCOUNT: Use INTERNAL transfer
        final account = await widget.accountRepo.getAccount(widget.accountId!);
        final accountName = account?.name ?? 'Account';

        await widget.accountRepo.transferToEnvelope(
          accountId: widget.accountId!,
          envelopeId: envelope.id,
          amount: amount,
          description: 'Cash Flow',
          date: DateTime.now(),
          envelopeRepo: widget.repo,
        );

        debugPrint('[PayDay] ✅ Cash Flow (INTERNAL): $accountName → ${envelope.name} = $amount');
      } else {
        // WITHOUT ACCOUNT: Use EXTERNAL deposit (virtual income)
        await widget.repo.deposit(
          envelopeId: envelope.id,
          amount: amount,
          description: 'Cash Flow',
          date: DateTime.now(),
        );

        debugPrint('[PayDay] ✅ Cash Flow (EXTERNAL): Virtual → ${envelope.name} = $amount');
      }

      // Update account balance animation
      setState(() {
        _accountBalance -= amount;
      });
    } catch (e) {
      debugPrint('Error with cash flow to ${envelope.name}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);
    final locale = Provider.of<LocaleProvider>(context);

    if (_isComplete) {
      return _buildCompletionScreen(theme, fontProvider, locale);
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(
            'Pay Day Stuffing',
            style: fontProvider.getTextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: theme.scaffoldBackgroundColor,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              // Pay Day Source (top of waterfall)
              if (widget.accountId != null)
                // WITH ACCOUNT: Show account balance
                _buildAccountBalance(theme, fontProvider, locale)
              else
                // WITHOUT ACCOUNT: Show Cash Rack
                _buildCashRack(theme, fontProvider, locale),

              const SizedBox(height: 24),

              // Money flowing animation (arrow + label)
              Center(
                child: Column(
                  children: [
                    // Animated money icon
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 800),
                      tween: Tween(begin: 0.0, end: 1.0),
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, -20 + (20 * value)),
                          child: Opacity(
                            opacity: value,
                            child: Text(
                              '💸',
                              style: TextStyle(fontSize: 32),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Icon(
                      Icons.arrow_downward,
                      size: 32,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cash Flow',
                      style: TextStyle(
                        fontSize: 16,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Binder groups
              ...List.generate(_binderGroups.length, (index) {
                return StuffingBinderCard(
                  binder: _binderGroups[index].group,
                  envelopes: _binderGroups[index].envelopes,
                  binderColors: _binderGroups[index].binderColors,
                  isOpen: _currentBinderIndex == index,
                  currentStuffingIndex: _currentBinderIndex == index ? _currentEnvelopeIndex : null,
                );
              }),

              // Ungrouped envelopes section
              if (_ungroupedEnvelopes.isNotEmpty)
                _buildUngroupedSection(theme, fontProvider),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountBalance(
    ThemeData theme,
    FontProvider fontProvider,
    LocaleProvider locale,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('💳', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  Text(
                    'Main Account',
                    style: fontProvider.getTextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _showingDeposit ? 'Receiving Pay Day...' : 'Balance',
                style: TextStyle(
                  fontSize: 14,
                  color: _showingDeposit
                      ? Colors.green.shade600
                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: _showingDeposit ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 800),
            tween: Tween(begin: _accountStartBalance, end: _accountBalance),
            builder: (context, value, child) {
              return Text(
                locale.formatCurrency(value),
                style: fontProvider.getTextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCashRack(
    ThemeData theme,
    FontProvider fontProvider,
    LocaleProvider locale,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.green.shade50,
            Colors.amber.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.green.shade300,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade200.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Cloud/Atmosphere header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '☁️',
                style: TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pay Day',
                    style: fontProvider.getTextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                  Text(
                    _showingDeposit ? 'Money arriving...' : 'Ready to stuff!',
                    style: TextStyle(
                      fontSize: 14,
                      color: _showingDeposit
                          ? Colors.green.shade600
                          : Colors.green.shade700,
                      fontWeight: _showingDeposit ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Cash Rack visualization
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.green.shade400,
                width: 2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Stack of bills emoji
                Text('💵', style: TextStyle(fontSize: 40)),
                const SizedBox(width: 8),
                Text('💵', style: TextStyle(fontSize: 40)),
                const SizedBox(width: 8),
                Text('💵', style: TextStyle(fontSize: 40)),
                const SizedBox(width: 16),

                // Amount
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 1200),
                  tween: Tween(begin: 0, end: widget.totalAmount),
                  builder: (context, value, child) {
                    return Text(
                      locale.formatCurrency(value),
                      style: fontProvider.getTextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade600,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'EXTERNAL INCOME',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUngroupedSection(ThemeData theme, FontProvider fontProvider) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final defaultColors = ThemeBinderColors.getColorsForTheme(
      themeProvider.currentThemeId,
    ).first;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📧', style: TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Text(
                'Individual Envelopes',
                style: fontProvider.getTextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          if (_currentBinderIndex == -2) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            ...List.generate(_ungroupedEnvelopes.length, (index) {
              final envelope = _ungroupedEnvelopes[index];
              final isCurrent = _currentEnvelopeIndex == index;
              return StuffingEnvelopeRow(
                envelope: envelope,
                binderColors: defaultColors,
                isCurrent: isCurrent,
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildCompletionScreen(
    ThemeData theme,
    FontProvider fontProvider,
    LocaleProvider locale,
  ) {
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Celebration
              ScaleTransition(
                scale: _pulseController.drive(Tween(begin: 1.0, end: 1.2)),
                child: const Text('🎉', style: TextStyle(fontSize: 80)),
              ),

              const SizedBox(height: 24),

              Text(
                'BINDERS STUFFED!',
                style: fontProvider.getTextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // Philosophy summary
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.green.shade50,
                      Colors.blue.shade50,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // EXTERNAL: Pay Day arrives
                    _buildSummaryRow(
                      icon: widget.accountId != null
                          ? Icons.arrow_downward
                          : Icons.cloud_download,
                      color: Colors.green.shade600,
                      label: widget.accountId != null
                          ? 'Pay Day Deposit'
                          : 'Pay Day from Cash Rack',
                      sublabel: 'EXTERNAL',
                      amount: widget.totalAmount,
                      locale: locale,
                      fontProvider: fontProvider,
                    ),

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),

                    // INTERNAL: Cash flow to envelopes
                    _buildSummaryRow(
                      icon: Icons.swap_horiz,
                      color: Colors.blue.shade600,
                      label: 'Cash Flow to Envelopes',
                      sublabel: 'INTERNAL',
                      amount: _totalEnvelopeStuffed,
                      locale: locale,
                      fontProvider: fontProvider,
                    ),

                    if (_totalAccountStuffed > 0) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      _buildSummaryRow(
                        icon: Icons.swap_horiz,
                        color: Colors.blue.shade600,
                        label: 'Cash Flow to Accounts',
                        sublabel: 'INTERNAL',
                        amount: _totalAccountStuffed,
                        locale: locale,
                        fontProvider: fontProvider,
                      ),
                    ],

                    if (widget.accountId != null) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      _buildSummaryRow(
                        icon: Icons.account_balance,
                        color: theme.colorScheme.primary,
                        label: 'Remaining in Account',
                        sublabel: 'Ready to use',
                        amount: _accountEndBalance,
                        locale: locale,
                        fontProvider: fontProvider,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Stats
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    if (_binderGroups.isNotEmpty)
                      Text(
                        '✅ ${_binderGroups.length} ${_binderGroups.length == 1 ? 'binder' : 'binders'} stuffed',
                        style: fontProvider.getTextStyle(fontSize: 16),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      '✅ ${widget.envelopes.length} ${widget.envelopes.length == 1 ? 'envelope' : 'envelopes'} filled',
                      style: fontProvider.getTextStyle(fontSize: 16),
                    ),
                    if (widget.accounts.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '✅ ${widget.accounts.length} ${widget.accounts.length == 1 ? 'account' : 'accounts'} auto-filled',
                        style: fontProvider.getTextStyle(fontSize: 16),
                      ),
                    ],
                  ],
                ),
              ),

              const Spacer(),

              // Done button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context); // Close stuffing screen
                    Navigator.pop(context); // Close allocation screen
                    Navigator.pop(context); // Close amount screen
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.secondary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    'Done!',
                    style: fontProvider.getTextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required Color color,
    required String label,
    required String sublabel,
    required double amount,
    required LocaleProvider locale,
    required FontProvider fontProvider,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: fontProvider.getTextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                sublabel,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Text(
          locale.formatCurrency(amount),
          style: fontProvider.getTextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _BinderGroup {
  final EnvelopeGroup group;
  final List<Envelope> envelopes;
  final BinderColorOption binderColors;

  _BinderGroup({
    required this.group,
    required this.envelopes,
    required this.binderColors,
  });
}
