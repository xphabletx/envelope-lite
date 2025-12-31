// lib/screens/pay_day/pay_day_amount_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/envelope_repo.dart';
import '../../services/group_repo.dart';
import '../../services/account_repo.dart';
import '../../services/pay_day_settings_service.dart';
import '../../models/account.dart';
import '../../providers/font_provider.dart';
import '../../providers/locale_provider.dart';
import 'pay_day_allocation_screen.dart';
import '../../utils/calculator_helper.dart';
import '../../widgets/tutorial_wrapper.dart';
import '../../data/tutorial_sequences.dart';

class PayDayAmountScreen extends StatefulWidget {
  const PayDayAmountScreen({
    super.key,
    required this.repo,
    required this.groupRepo,
    required this.accountRepo,
  });

  final EnvelopeRepo repo;
  final GroupRepo groupRepo;
  final AccountRepo accountRepo;

  @override
  State<PayDayAmountScreen> createState() => _PayDayAmountScreenState();
}

class _PayDayAmountScreenState extends State<PayDayAmountScreen> {
  final _amountController = TextEditingController(text: '0.00');
  final _amountFocus = FocusNode();
  String? _selectedAccountId;
  late final Stream<List<Account>> _accountsStream;
  bool _hasUserModifiedAmount = false; // Track if user has manually changed amount

  @override
  void initState() {
    super.initState();
    // Initialize the stream once to prevent multiple subscriptions
    _accountsStream = widget.accountRepo.accountsStream();
    _loadSavedPayAmount();
  }

  /// Load saved pay amount from settings
  Future<void> _loadSavedPayAmount() async {
    final payDayService = PayDaySettingsService(
      widget.repo.db,
      widget.repo.currentUserId,
    );
    final settings = await payDayService.getPayDaySettings();

    // Only load saved amount if user hasn't manually changed it
    if (settings != null &&
        settings.expectedPayAmount != null &&
        mounted &&
        !_hasUserModifiedAmount) {
      setState(() {
        _amountController.text = settings.expectedPayAmount!.toStringAsFixed(2);
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  void _continue() {
    final rawAmount = _amountController.text.replaceAll(',', '').trim();
    final amount = double.tryParse(rawAmount);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an account to deposit into'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PayDayAllocationScreen(
          repo: widget.repo,
          groupRepo: widget.groupRepo,
          accountRepo: widget.accountRepo,
          totalAmount: amount,
          accountId: _selectedAccountId!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final locale = Provider.of<LocaleProvider>(context, listen: false);
    final media = MediaQuery.of(context);

    return TutorialWrapper(
      tutorialSequence: payDayTutorial,
      spotlightKeys: const {},
      child: Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Close',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: media.size.height * 0.05),

              // Money emoji
              const Text(
                '💰',
                style: TextStyle(fontSize: 100),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                'Pay Day!',
                style: fontProvider.getTextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Subtitle
              Text(
                'How much did you get paid?',
                style: fontProvider.getTextStyle(
                  fontSize: 24,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Amount input
              TextField(
                controller: _amountController,
                focusNode: _amountFocus,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textAlign: TextAlign.center,
                style: fontProvider.getTextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.secondary,
                ),
                onChanged: (value) {
                  // Mark as modified when user types
                  _hasUserModifiedAmount = true;
                },
                decoration: InputDecoration(
                  prefixText: '${locale.currencySymbol} ',
                  prefixStyle: fontProvider.getTextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.secondary,
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
                      onPressed: () async {
                        final result = await CalculatorHelper.showCalculator(context);
                        if (result != null && mounted) {
                          setState(() {
                            _amountController.text = result;
                            _hasUserModifiedAmount = true; // Mark as modified
                          });
                        }
                      },
                      tooltip: 'Open Calculator',
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 3,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                ),
                onTap: () {
                  _amountController.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: _amountController.text.length,
                  );
                },
              ),
              const SizedBox(height: 32),

              // Account Selector
              Text(
                'Deposit To',
                style: fontProvider.getTextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              StreamBuilder<List<Account>>(
                stream: _accountsStream,
                builder: (context, snapshot) {
                  // FIX: Handle waiting state to prevent the "red flash"
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      height: 60, // Approximate height to prevent layout jump
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                      child: const Center(
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Please create an account first',
                        style: fontProvider.getTextStyle(
                          fontSize: 16,
                          color: theme.colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final accounts = snapshot.data!;
                  // Default to the first account if none selected
                  if (_selectedAccountId == null) {
                    final defaultAcc = accounts.firstWhere(
                      (a) => a.isDefault,
                      orElse: () => accounts.first,
                    );
                    _selectedAccountId = defaultAcc.id;
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: 0.2,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.5),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedAccountId,
                        isExpanded: true,
                        items: accounts.map((account) {
                          return DropdownMenuItem(
                            value: account.id,
                            child: Row(
                              children: [
                                Text(
                                  account.emoji ?? '💳',
                                  style: const TextStyle(fontSize: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    account.name,
                                    style: fontProvider.getTextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() => _selectedAccountId = val);
                        },
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 48),

              // Continue button
              FilledButton(
                onPressed: _continue,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  backgroundColor: theme.colorScheme.secondary,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Continue',
                      style: fontProvider.getTextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.arrow_forward,
                      size: 28,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
