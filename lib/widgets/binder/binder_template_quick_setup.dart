import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/binder_templates.dart';
import '../../models/scheduled_payment.dart';
import '../../services/envelope_repo.dart';
import '../../services/scheduled_payment_repo.dart';
import '../../services/group_repo.dart';
import '../../providers/font_provider.dart';
import '../../providers/locale_provider.dart';
import '../../utils/calculator_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BinderTemplateQuickSetup extends StatefulWidget {
  final BinderTemplate template;
  final String userId;
  final String? defaultAccountId; // For Account Mode linking
  final String? existingBinderId; // If adding to existing binder
  final Function(int)? onComplete; // Optional callback for onboarding flow
  final bool returnEnvelopeIds; // If true, pops with List<String> of created envelope IDs

  const BinderTemplateQuickSetup({
    super.key,
    required this.template,
    required this.userId,
    this.defaultAccountId,
    this.existingBinderId,
    this.onComplete,
    this.returnEnvelopeIds = false,
  });

  @override
  State<BinderTemplateQuickSetup> createState() => _BinderTemplateQuickSetupState();
}

class _BinderTemplateQuickSetupState extends State<BinderTemplateQuickSetup> {
  final Set<String> _selectedEnvelopeIds = {};
  bool _showQuickEntry = false;

  @override
  void initState() {
    super.initState();
    // Select all envelopes by default
    _selectedEnvelopeIds.addAll(
      widget.template.envelopes.map((e) => e.id),
    );
  }

  void _toggleAll(bool select) {
    setState(() {
      if (select) {
        _selectedEnvelopeIds.addAll(widget.template.envelopes.map((e) => e.id));
      } else {
        _selectedEnvelopeIds.clear();
      }
    });
  }

  void _startQuickEntry() {
    setState(() {
      _showQuickEntry = true;
    });
  }

  Future<void> _createEnvelopesEmpty() async {
    final envelopeRepo = EnvelopeRepo.firebase(
      FirebaseFirestore.instance,
      userId: widget.userId,
    );
    final groupRepo = GroupRepo(envelopeRepo);
    int createdCount = 0;
    final createdIds = <String>[];

    // Step 1: Determine the binder ID
    String? binderId = widget.existingBinderId;

    // Only create a new binder if we're NOT adding to an existing one
    if (binderId == null) {
      binderId = await groupRepo.createGroup(
        name: widget.template.name,
        emoji: widget.template.emoji,
      );
    }

    // Step 2: Create empty envelopes in the binder
    for (final templateEnvelope in widget.template.envelopes) {
      if (!_selectedEnvelopeIds.contains(templateEnvelope.id)) continue;

      final envelopeId = await envelopeRepo.createEnvelope(
        name: templateEnvelope.name,
        startingAmount: 0.0,
        emoji: templateEnvelope.emoji,
        autoFillEnabled: false,
        groupId: binderId, // Link to binder
      );
      createdIds.add(envelopeId);
      createdCount++;
    }

    if (mounted) {
      final message = widget.existingBinderId != null
          ? 'Created $createdCount envelopes'
          : 'Created ${widget.template.name} binder with $createdCount envelopes!';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );

      if (widget.returnEnvelopeIds) {
        Navigator.of(context).pop(createdIds);
      } else {
        widget.onComplete?.call(createdCount);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);

    if (_showQuickEntry) {
      return _QuickEntryFlow(
        template: widget.template,
        selectedEnvelopeIds: _selectedEnvelopeIds,
        userId: widget.userId,
        defaultAccountId: widget.defaultAccountId,
        existingBinderId: widget.existingBinderId,
        returnEnvelopeIds: widget.returnEnvelopeIds,
        onComplete: (count, createdIds) {
          if (widget.returnEnvelopeIds) {
            Navigator.of(context).pop(createdIds);
          } else {
            widget.onComplete?.call(count);
          }
        },
        onBack: () {
          setState(() => _showQuickEntry = false);
        },
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.template.name,
          style: fontProvider.getTextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              border: Border(
                bottom: BorderSide(color: theme.dividerColor),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select the envelopes you want:',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _toggleAll(true),
                        child: const Text('Select All'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _toggleAll(false),
                        child: const Text('Deselect All'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Envelope list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.template.envelopes.length,
              itemBuilder: (context, index) {
                final envelope = widget.template.envelopes[index];
                final isSelected = _selectedEnvelopeIds.contains(envelope.id);

                return CheckboxListTile(
                  value: isSelected,
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        _selectedEnvelopeIds.add(envelope.id);
                      } else {
                        _selectedEnvelopeIds.remove(envelope.id);
                      }
                    });
                  },
                  secondary: Text(envelope.emoji, style: const TextStyle(fontSize: 32)),
                  title: Text(
                    envelope.name,
                    style: fontProvider.getTextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: envelope.defaultAmount != null
                      ? Text('Suggested: £${envelope.defaultAmount!.toStringAsFixed(2)}')
                      : null,
                );
              },
            ),
          ),

          // Bottom actions
          Container(
            padding: const EdgeInsets.all(20),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_selectedEnvelopeIds.length} envelope(s) selected',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Want to add details now?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '(Current amounts, recurring bills, etc.)',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _selectedEnvelopeIds.isEmpty
                              ? null
                              : _createEnvelopesEmpty,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Create Empty'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _selectedEnvelopeIds.isEmpty
                              ? null
                              : _startQuickEntry,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Add Details Now'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// QUICK ENTRY FLOW - Swipeable cards
// ============================================================================

class _QuickEntryFlow extends StatefulWidget {
  final BinderTemplate template;
  final Set<String> selectedEnvelopeIds;
  final String userId;
  final String? defaultAccountId;
  final String? existingBinderId;
  final bool returnEnvelopeIds;
  final Function(int, List<String>) onComplete; // Returns count and envelope IDs
  final VoidCallback onBack;

  const _QuickEntryFlow({
    required this.template,
    required this.selectedEnvelopeIds,
    required this.userId,
    this.defaultAccountId,
    this.existingBinderId,
    this.returnEnvelopeIds = false,
    required this.onComplete,
    required this.onBack,
  });

  @override
  State<_QuickEntryFlow> createState() => _QuickEntryFlowState();
}

class _QuickEntryFlowState extends State<_QuickEntryFlow> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  late List<EnvelopeTemplate> _selectedEnvelopes;
  final List<EnvelopeData> _collectedData = [];

  @override
  void initState() {
    super.initState();
    _selectedEnvelopes = widget.template.envelopes
        .where((e) => widget.selectedEnvelopeIds.contains(e.id))
        .toList();

    // Initialize data list
    for (final envelope in _selectedEnvelopes) {
      _collectedData.add(EnvelopeData(template: envelope));
    }
  }

  void _nextCard() {
    if (_currentIndex < _selectedEnvelopes.length - 1) {
      setState(() => _currentIndex++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _saveAllEnvelopes();
    }
  }

  void _previousCard() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skipCard() {
    // Mark as skipped and move to next
    _collectedData[_currentIndex].skipped = true;
    _nextCard();
  }

  Future<void> _saveAllEnvelopes() async {
    final envelopeRepo = EnvelopeRepo.firebase(
      FirebaseFirestore.instance,
      userId: widget.userId,
    );
    final groupRepo = GroupRepo(envelopeRepo);
    final scheduledPaymentRepo = ScheduledPaymentRepo(widget.userId);
    int createdCount = 0;
    final createdIds = <String>[];

    // Step 1: Determine the binder ID
    String? binderId = widget.existingBinderId;

    // Only create a new binder if we're NOT adding to an existing one
    if (binderId == null) {
      binderId = await groupRepo.createGroup(
        name: widget.template.name,
        emoji: widget.template.emoji,
      );
    }

    // Step 2: Create all envelopes and assign them to the binder
    for (final data in _collectedData) {
      String? envelopeId;

      if (data.skipped) {
        // Create empty envelope
        envelopeId = await envelopeRepo.createEnvelope(
          name: data.template.name,
          startingAmount: 0.0,
          emoji: data.template.emoji,
          autoFillEnabled: false,
          groupId: binderId, // Assign to the binder
        );
        createdIds.add(envelopeId);
        createdCount++;
      } else {
        // Create envelope with full data
        envelopeId = await envelopeRepo.createEnvelope(
          name: data.template.name,
          startingAmount: data.currentAmount,
          targetAmount: data.targetAmount,
          emoji: data.template.emoji,
          autoFillEnabled: data.payDayDepositEnabled,
          autoFillAmount: data.payDayDepositEnabled ? data.payDayDepositAmount : null,
          linkedAccountId: data.payDayDepositEnabled && widget.defaultAccountId != null
              ? widget.defaultAccountId
              : null,
          groupId: binderId, // Assign to the binder
        );
        createdIds.add(envelopeId);
        createdCount++;

        // Create scheduled payment if enabled
        if (data.recurringBillEnabled && data.firstPaymentDate != null) {
          await scheduledPaymentRepo.createScheduledPayment(
            envelopeId: envelopeId,
            name: 'Recurring: ${data.template.name}',
            description: 'Auto-created from template',
            amount: data.recurringBillAmount,
            startDate: data.firstPaymentDate!,
            frequencyValue: 1,
            frequencyUnit: _convertFrequencyToUnit(data.recurringFrequency),
            colorName: 'Default',
            colorValue: 0xFF8B6F47,
            isAutomatic: data.autoExecute,
          );
        }
      }
    }

    if (mounted) {
      final message = widget.existingBinderId != null
          ? 'Added $createdCount envelopes to binder!'
          : 'Created ${widget.template.name} binder with $createdCount envelopes!';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
      widget.onComplete(createdCount, createdIds);
    }
  }

  PaymentFrequencyUnit _convertFrequencyToUnit(Frequency freq) {
    switch (freq) {
      case Frequency.weekly:
        return PaymentFrequencyUnit.weeks;
      case Frequency.monthly:
        return PaymentFrequencyUnit.months;
      case Frequency.yearly:
        return PaymentFrequencyUnit.years;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView.builder(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _selectedEnvelopes.length,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        itemBuilder: (context, index) {
          return _QuickEntryCard(
            template: _selectedEnvelopes[index],
            data: _collectedData[index],
            isAccountMode: widget.defaultAccountId != null,
            currentIndex: index + 1,
            totalCount: _selectedEnvelopes.length,
            onNext: _nextCard,
            onBack: _previousCard,
            onSkip: _skipCard,
            isFirst: index == 0,
            isLast: index == _selectedEnvelopes.length - 1,
          );
        },
      ),
    );
  }
}

// ============================================================================
// QUICK ENTRY CARD - Single envelope data entry
// ============================================================================

class _QuickEntryCard extends StatefulWidget {
  final EnvelopeTemplate template;
  final EnvelopeData data;
  final bool isAccountMode;
  final int currentIndex;
  final int totalCount;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final bool isFirst;
  final bool isLast;

  const _QuickEntryCard({
    required this.template,
    required this.data,
    required this.isAccountMode,
    required this.currentIndex,
    required this.totalCount,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
    required this.isFirst,
    required this.isLast,
  });

  @override
  State<_QuickEntryCard> createState() => _QuickEntryCardState();
}

class _QuickEntryCardState extends State<_QuickEntryCard> {
  late final TextEditingController _currentAmountController;
  late final TextEditingController _targetAmountController;
  late final TextEditingController _recurringAmountController;
  late final TextEditingController _payDayAmountController;

  @override
  void initState() {
    super.initState();

    _currentAmountController = TextEditingController(
      text: widget.data.currentAmount > 0 ? widget.data.currentAmount.toString() : '',
    );
    _targetAmountController = TextEditingController(
      text: widget.data.targetAmount != null ? widget.data.targetAmount.toString() : '',
    );
    _recurringAmountController = TextEditingController(
      text: widget.template.defaultAmount?.toString() ?? '',
    );
    _payDayAmountController = TextEditingController(
      text: widget.template.defaultAmount?.toString() ?? '',
    );
  }

  Future<void> _showDayPicker(BuildContext context) async {
    final now = DateTime.now();
    // Use existing date if set, otherwise use today
    final initialDate = widget.data.firstPaymentDate ?? now;

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: DateTime(now.year + 2, 12, 31),
      helpText: 'Select first payment date',
    );

    if (selectedDate != null && mounted) {
      setState(() {
        widget.data.recurringDay = selectedDate.day;
        widget.data.firstPaymentDate = selectedDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Header with progress
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(widget.template.emoji, style: const TextStyle(fontSize: 32)),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            widget.template.name,
                            style: fontProvider.getTextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: widget.onSkip,
                        child: const Text('Skip'),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${widget.currentIndex}/${widget.totalCount}',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Form fields
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Current Amount
                      TextField(
                        controller: _currentAmountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Current Amount (optional)',
                          prefixText: localeProvider.currencySymbol,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
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
                                    _currentAmountController.text = result;
                                    widget.data.currentAmount = double.tryParse(result) ?? 0.0;
                                  });
                                }
                              },
                              tooltip: 'Open Calculator',
                            ),
                          ),
                        ),
                        onChanged: (value) {
                          widget.data.currentAmount = double.tryParse(value) ?? 0.0;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Target Amount
                      TextField(
                        controller: _targetAmountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Target Amount (optional)',
                          prefixText: localeProvider.currencySymbol,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
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
                                    _targetAmountController.text = result;
                                    widget.data.targetAmount = double.tryParse(result);
                                  });
                                }
                              },
                              tooltip: 'Open Calculator',
                            ),
                          ),
                        ),
                        onChanged: (value) {
                          widget.data.targetAmount = double.tryParse(value);
                        },
                      ),

                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 24),

                      // Recurring Bill
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Recurring Bill?',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Switch(
                            value: widget.data.recurringBillEnabled,
                            onChanged: (enabled) {
                              setState(() {
                                widget.data.recurringBillEnabled = enabled;

                                // Auto-suggest for pay day deposit
                                if (enabled && widget.data.recurringBillAmount > 0) {
                                  widget.data.payDayDepositAmount = widget.data.recurringBillAmount;
                                  _payDayAmountController.text = widget.data.recurringBillAmount.toString();
                                }
                              });
                            },
                          ),
                        ],
                      ),

                      if (widget.data.recurringBillEnabled) ...[
                        const SizedBox(height: 16),

                        TextField(
                          controller: _recurringAmountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Amount',
                            prefixText: localeProvider.currencySymbol,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
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
                                      _recurringAmountController.text = result;
                                      final amount = double.tryParse(result) ?? 0.0;
                                      widget.data.recurringBillAmount = amount;

                                      // Auto-update pay day deposit
                                      widget.data.payDayDepositAmount = amount;
                                      _payDayAmountController.text = amount.toString();
                                    });
                                  }
                                },
                                tooltip: 'Open Calculator',
                              ),
                            ),
                          ),
                          onChanged: (value) {
                            final amount = double.tryParse(value) ?? 0.0;
                            widget.data.recurringBillAmount = amount;

                            // Auto-update pay day deposit
                            widget.data.payDayDepositAmount = amount;
                            _payDayAmountController.text = amount.toString();
                          },
                        ),

                        const SizedBox(height: 16),

                        DropdownButtonFormField<Frequency>(
                          value: widget.data.recurringFrequency,
                          decoration: InputDecoration(
                            labelText: 'Frequency',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: Frequency.values.map((freq) {
                            final name = freq.toString().split('.').last;
                            final capitalized = name[0].toUpperCase() + name.substring(1);
                            return DropdownMenuItem(
                              value: freq,
                              child: Text(capitalized),
                            );
                          }).toList(),
                          onChanged: (freq) {
                            if (freq != null) {
                              setState(() {
                                widget.data.recurringFrequency = freq;
                              });
                            }
                          },
                        ),

                        const SizedBox(height: 16),

                        GestureDetector(
                          onTap: () => _showDayPicker(context),
                          child: AbsorbPointer(
                            child: TextFormField(
                              decoration: InputDecoration(
                                labelText: 'First Payment Date',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                suffixIcon: const Icon(Icons.calendar_today),
                              ),
                              controller: TextEditingController(
                                text: widget.data.firstPaymentDate != null
                                    ? '${widget.data.firstPaymentDate!.day}/${widget.data.firstPaymentDate!.month}/${widget.data.firstPaymentDate!.year}'
                                    : 'Tap to select date',
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        SwitchListTile(
                          title: const Text('Auto-execute payment'),
                          value: widget.data.autoExecute,
                          onChanged: (enabled) {
                            setState(() {
                              widget.data.autoExecute = enabled;
                            });
                          },
                        ),
                      ],

                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 24),

                      // Pay Day Deposit
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Pay Day Deposit?',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Switch(
                            value: widget.data.payDayDepositEnabled,
                            onChanged: (enabled) {
                              setState(() {
                                widget.data.payDayDepositEnabled = enabled;
                              });
                            },
                          ),
                        ],
                      ),

                      if (widget.data.payDayDepositEnabled) ...[
                        const SizedBox(height: 16),

                        TextField(
                          controller: _payDayAmountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Amount',
                            prefixText: localeProvider.currencySymbol,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            helperText: widget.data.recurringBillEnabled
                                ? 'Auto-suggested from recurring bill'
                                : null,
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
                                      _payDayAmountController.text = result;
                                      widget.data.payDayDepositAmount = double.tryParse(result) ?? 0.0;
                                    });
                                  }
                                },
                                tooltip: 'Open Calculator',
                              ),
                            ),
                          ),
                          onChanged: (value) {
                            widget.data.payDayDepositAmount = double.tryParse(value) ?? 0.0;
                          },
                        ),

                        if (widget.isAccountMode) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.link,
                                  size: 20,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Will be linked to Main Account',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),

              // Navigation buttons
              const SizedBox(height: 24),
              Row(
                children: [
                  if (!widget.isFirst)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onBack,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('← Back'),
                      ),
                    ),
                  if (!widget.isFirst) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: widget.onNext,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(widget.isLast ? 'Finish' : 'Next →'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _currentAmountController.dispose();
    _targetAmountController.dispose();
    _recurringAmountController.dispose();
    _payDayAmountController.dispose();
    super.dispose();
  }
}

// ============================================================================
// DATA CLASSES
// ============================================================================

enum Frequency {
  weekly,
  monthly,
  yearly,
}

class EnvelopeData {
  final EnvelopeTemplate template;
  bool skipped = false;

  double currentAmount = 0.0;
  double? targetAmount;

  bool recurringBillEnabled = false;
  double recurringBillAmount = 0.0;
  Frequency recurringFrequency = Frequency.monthly;
  int recurringDay = 1;
  DateTime? firstPaymentDate;
  bool autoExecute = false;

  bool payDayDepositEnabled = false;
  double payDayDepositAmount = 0.0;

  EnvelopeData({required this.template});
}
