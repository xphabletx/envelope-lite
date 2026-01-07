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
import '../common/smart_text_field.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/insight_data.dart';
import '../insight_tile.dart';

class BinderTemplateQuickSetup extends StatefulWidget {
  final BinderTemplate template;
  final String userId;
  final String? defaultAccountId; // For Account Mode linking
  final String? existingBinderId; // If adding to existing binder
  final Function(int)? onComplete; // Optional callback for onboarding flow
  final bool
  returnEnvelopeIds; // If true, pops with List<String> of created envelope IDs

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
  State<BinderTemplateQuickSetup> createState() =>
      _BinderTemplateQuickSetupState();
}

class _BinderTemplateQuickSetupState extends State<BinderTemplateQuickSetup> {
  final Set<String> _selectedEnvelopeIds = {};
  bool _showQuickEntry = false;

  @override
  void initState() {
    super.initState();
    // Select all envelopes by default
    _selectedEnvelopeIds.addAll(widget.template.envelopes.map((e) => e.id));
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
    // Only create a new binder if we're NOT adding to an existing one
    String? binderId =
        widget.existingBinderId ??
        await groupRepo.createGroup(
          name: widget.template.name,
          iconType: 'emoji',
          iconValue: widget.template.emoji,
        );

    // Step 2: Create empty envelopes in the binder
    for (final templateEnvelope in widget.template.envelopes) {
      if (!_selectedEnvelopeIds.contains(templateEnvelope.id)) continue;

      final envelopeId = await envelopeRepo.createEnvelope(
        name: templateEnvelope.name,
        startingAmount: 0.0,
        iconType: 'emoji',
        iconValue: templateEnvelope.emoji,
        cashFlowEnabled: false,
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
        SnackBar(content: Text(message), backgroundColor: Colors.green),
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
        onComplete: (envelopeCount, createdIds) {
          if (widget.returnEnvelopeIds) {
            Navigator.of(context).pop(createdIds);
          } else {
            widget.onComplete?.call(envelopeCount);
          }
        },
        onBack: () {
          setState(() => _showQuickEntry = false);
        },
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Title Header with Close button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Cancel',
                  ),
                  Expanded(
                    child: Text(
                      widget.template.name,
                      style: fontProvider.getTextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48), // Balance the close button
                ],
              ),
            ),
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.3,
                ),
                border: Border(bottom: BorderSide(color: theme.dividerColor)),
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
                    secondary: Text(
                      envelope.emoji,
                      style: const TextStyle(fontSize: 32),
                    ),
                    title: Text(
                      envelope.name,
                      style: fontProvider.getTextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: envelope.defaultAmount != null
                        ? Text(
                            'Suggested: £${envelope.defaultAmount!.toStringAsFixed(2)}',
                          )
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
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
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
                      '(Current amounts, autopilot, etc.)',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
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
  final Function(int, List<String>)
  onComplete; // Returns count and envelope IDs
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
    // Only create a new binder if we're NOT adding to an existing one
    String? binderId =
        widget.existingBinderId ??
        await groupRepo.createGroup(
          name: widget.template.name,
          iconType: 'emoji',
          iconValue: widget.template.emoji,
        );

    // Step 2: Create all envelopes and assign them to the binder
    for (final data in _collectedData) {
      String? envelopeId;

      if (data.skipped) {
        // Create empty envelope
        envelopeId = await envelopeRepo.createEnvelope(
          name: data.template.name,
          startingAmount: 0.0,
          iconType: 'emoji',
          iconValue: data.template.emoji,
          cashFlowEnabled: false,
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
          iconType: 'emoji',
          iconValue: data.template.emoji,
          cashFlowEnabled: data.payDayDepositEnabled,
          cashFlowAmount: data.payDayDepositEnabled
              ? data.payDayDepositAmount
              : null,
          linkedAccountId:
              data.payDayDepositEnabled && widget.defaultAccountId != null
              ? widget.defaultAccountId
              : null,
          groupId: binderId, // Assign to the binder
        );
        createdIds.add(envelopeId);
        createdCount++;

        // AUTO-CREATE SCHEDULED PAYMENT if autopilot is enabled
        // Use InsightData if available for better integration
        if (data.recurringBillEnabled && data.insightData != null && data.insightData!.autopilotAmount != null) {
          // Use insight data for proper frequency mapping
          final insightData = data.insightData!;

          // Map frequency from insight format to scheduled payment format
          PaymentFrequencyUnit frequencyUnit;
          int frequencyValue;

          switch (insightData.autopilotFrequency) {
            case 'weekly':
              frequencyUnit = PaymentFrequencyUnit.weeks;
              frequencyValue = 1;
              break;
            case 'biweekly':
              frequencyUnit = PaymentFrequencyUnit.weeks;
              frequencyValue = 2;
              break;
            case 'fourweekly':
              frequencyUnit = PaymentFrequencyUnit.weeks;
              frequencyValue = 4;
              break;
            case 'monthly':
              frequencyUnit = PaymentFrequencyUnit.months;
              frequencyValue = 1;
              break;
            case 'yearly':
              frequencyUnit = PaymentFrequencyUnit.years;
              frequencyValue = 1;
              break;
            default:
              frequencyUnit = PaymentFrequencyUnit.months;
              frequencyValue = 1;
          }

          // Determine start date
          final startDate = insightData.autopilotFirstDate ??
            DateTime.now().add(Duration(days: frequencyValue * (frequencyUnit == PaymentFrequencyUnit.weeks ? 7 : 30)));

          await scheduledPaymentRepo.createScheduledPayment(
            envelopeId: envelopeId,
            name: data.template.name,
            description: 'Autopilot payment',
            amount: insightData.autopilotAmount!,
            startDate: startDate,
            frequencyValue: frequencyValue,
            frequencyUnit: frequencyUnit,
            colorName: 'Autopilot',
            colorValue: 0xFF9C27B0, // Purple color for autopilot
            isAutomatic: insightData.autopilotAutoExecute,
            paymentType: ScheduledPaymentType.fixedAmount,
          );
        } else if (data.recurringBillEnabled && data.firstPaymentDate != null) {
          // Fallback to old method if InsightData not available
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
        SnackBar(content: Text(message), backgroundColor: Colors.green),
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
      appBar: AppBar(
        automaticallyImplyLeading: false, // Disable automatic back button
        toolbarHeight: 0, // Hide the AppBar completely
      ),
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
            userId: widget.userId,
            isAccountMode: widget.defaultAccountId != null,
            currentIndex: index + 1,
            totalCount: _selectedEnvelopes.length,
            onNext: _nextCard,
            onBack: _previousCard,
            onSkip: _skipCard,
            isFirst: index == 0,
            isLast: index == _selectedEnvelopes.length - 1,
            onBackToSelection:
                widget.onBack, // Pass the callback to return to selection
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
  final String userId;
  final bool isAccountMode;
  final int currentIndex;
  final int totalCount;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final bool isFirst;
  final bool isLast;
  final VoidCallback?
  onBackToSelection; // Callback to return to envelope selection

  const _QuickEntryCard({
    required this.template,
    required this.data,
    required this.userId,
    required this.isAccountMode,
    required this.currentIndex,
    required this.totalCount,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
    required this.isFirst,
    required this.isLast,
    this.onBackToSelection,
  });

  @override
  State<_QuickEntryCard> createState() => _QuickEntryCardState();
}

class _QuickEntryCardState extends State<_QuickEntryCard> {
  late final TextEditingController _currentAmountController;
  late final TextEditingController _targetAmountController;
  late final TextEditingController _recurringAmountController;
  late final TextEditingController _payDayAmountController;
  final ScrollController _scrollController = ScrollController();

  final FocusNode _currentAmountFocus = FocusNode();
  final FocusNode _targetAmountFocus = FocusNode();
  final FocusNode _recurringAmountFocus = FocusNode();
  final FocusNode _payDayAmountFocus = FocusNode();

  bool _showCurrentAmountTip = false;
  bool _showTargetAmountTip = false;
  bool _showRecurringBillTip = false;
  bool _showPayDayTip = false;

  @override
  void initState() {
    super.initState();

    _currentAmountController = TextEditingController(
      text: widget.data.currentAmount > 0
          ? widget.data.currentAmount.toString()
          : '',
    );
    _targetAmountController = TextEditingController(
      text: widget.data.targetAmount != null
          ? widget.data.targetAmount.toString()
          : '',
    );
    _recurringAmountController = TextEditingController(
      text: widget.template.defaultAmount?.toString() ?? '',
    );
    _payDayAmountController = TextEditingController(
      text: widget.template.defaultAmount?.toString() ?? '',
    );

    // Add focus listeners to show pro tips when fields receive focus
    _currentAmountFocus.addListener(() {
      if (_currentAmountFocus.hasFocus && !_showCurrentAmountTip) {
        setState(() => _showCurrentAmountTip = true);
      }
    });
    _targetAmountFocus.addListener(() {
      if (_targetAmountFocus.hasFocus && !_showTargetAmountTip) {
        setState(() => _showTargetAmountTip = true);
      }
    });
    _recurringAmountFocus.addListener(() {
      if (_recurringAmountFocus.hasFocus &&
          !_showRecurringBillTip &&
          widget.data.recurringBillEnabled) {
        setState(() => _showRecurringBillTip = true);
      }
    });
    _payDayAmountFocus.addListener(() {
      if (_payDayAmountFocus.hasFocus &&
          !_showPayDayTip &&
          widget.data.payDayDepositEnabled) {
        setState(() => _showPayDayTip = true);
      }
    });
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

  Widget _buildProTip(String text) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.secondary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // If this is the first card, go back to selection
        if (widget.isFirst) {
          widget.onBackToSelection?.call();
        } else {
          // Otherwise, go to the previous envelope
          widget.onBack();
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Fixed Header with title centered, skip and progress on right
              Padding(
                padding: const EdgeInsets.fromLTRB(60, 16, 24, 0),
                child: Row(
                  children: [
                    // Title with emoji (centered)
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.template.emoji,
                            style: const TextStyle(fontSize: 32),
                          ),
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
                    // Skip button and progress
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
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Scrollable Form fields
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                          maxWidth: constraints.maxWidth,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Current Amount
                            SmartTextField(
                              controller: _currentAmountController,
                              focusNode: _currentAmountFocus,
                              nextFocusNode: _targetAmountFocus,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
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
                                      final result =
                                          await CalculatorHelper.showCalculator(
                                            context,
                                          );
                                      if (result != null && mounted) {
                                        setState(() {
                                          _currentAmountController.text = result;
                                          widget.data.currentAmount =
                                              double.tryParse(result) ?? 0.0;
                                        });
                                      }
                                    },
                                    tooltip: 'Open Calculator',
                                  ),
                                ),
                              ),
                              onTap: () {
                                if (!_showCurrentAmountTip) {
                                  setState(() => _showCurrentAmountTip = true);
                                }
                              },
                              onChanged: (value) {
                          widget.data.currentAmount =
                              double.tryParse(value) ?? 0.0;
                        },
                      ),

                      if (_showCurrentAmountTip)
                        _buildProTip(
                          'If you have cash in your account now that you\'ve already set aside for this envelope, add it here. This gives you an accurate starting point.',
                        ),

                      const SizedBox(height: 24),

                      // 👁️‍🗨️ INSIGHT TILE - Financial Planning
                      InsightTile(
                        userId: widget.userId,
                        startingAmount: widget.data.currentAmount, // Pass starting amount for gap calculation
                        initiallyExpanded: true, // Auto-expand for onboarding
                        onInsightChanged: (InsightData data) {
                          setState(() {
                            // Store full InsightData
                            widget.data.insightData = data;

                            // Update Horizon (target)
                            widget.data.targetAmount = data.horizonAmount;
                            if (data.horizonAmount != null) {
                              _targetAmountController.text = data.horizonAmount.toString();
                            }

                            // Update Cash Flow
                            widget.data.payDayDepositEnabled = data.cashFlowEnabled;
                            final cashFlow = data.effectiveCashFlow;
                            if (cashFlow != null && cashFlow > 0) {
                              widget.data.payDayDepositAmount = cashFlow;
                              _payDayAmountController.text = cashFlow.toString();
                            }

                            // Update Autopilot
                            widget.data.recurringBillEnabled = data.autopilotEnabled;
                            if (data.autopilotEnabled && data.autopilotAmount != null) {
                              widget.data.recurringBillAmount = data.autopilotAmount!;
                              _recurringAmountController.text = data.autopilotAmount.toString();

                              // Map frequency
                              widget.data.recurringFrequency = _mapAutopilotFrequency(data.autopilotFrequency);

                              // Set first payment date
                              if (data.autopilotFirstDate != null) {
                                widget.data.firstPaymentDate = data.autopilotFirstDate;
                                widget.data.recurringDay = data.autopilotFirstDate!.day;
                              }

                              // Set auto-execute
                              widget.data.autoExecute = data.autopilotAutoExecute;
                            }
                          });
                        },
                        initialData: InsightData(
                          horizonEnabled: widget.data.targetAmount != null,
                          horizonAmount: widget.data.targetAmount,
                          cashFlowEnabled: widget.data.payDayDepositEnabled,
                          calculatedCashFlow: widget.data.payDayDepositAmount,
                          autopilotEnabled: widget.data.recurringBillEnabled,
                          autopilotAmount: widget.data.recurringBillAmount,
                          autopilotFrequency: _mapFrequencyToString(widget.data.recurringFrequency),
                          autopilotFirstDate: widget.data.firstPaymentDate,
                          autopilotAutoExecute: widget.data.autoExecute,
                        ),
                      ),

                      if (widget.isAccountMode && widget.data.payDayDepositEnabled) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer
                                .withValues(alpha: 0.3),
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

                      // Navigation button (moved inside scroll view)
                      const SizedBox(height: 32),
                      FilledButton(
                        onPressed: widget.onNext,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          minimumSize: const Size.fromHeight(56),
                        ),
                        child: Text(widget.isLast ? 'Finish' : 'Next →'),
                      ),
                      const SizedBox(height: 24),
                    ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to map Insight autopilot frequency to local Frequency enum
  Frequency _mapAutopilotFrequency(String autopilotFreq) {
    switch (autopilotFreq) {
      case 'weekly':
        return Frequency.weekly;
      case 'monthly':
      case 'biweekly':
      case 'fourweekly':
        return Frequency.monthly; // Map all to monthly for simplicity
      case 'yearly':
        return Frequency.yearly;
      default:
        return Frequency.monthly;
    }
  }

  // Helper method to map local Frequency enum to Insight autopilot frequency string
  String _mapFrequencyToString(Frequency freq) {
    switch (freq) {
      case Frequency.weekly:
        return 'weekly';
      case Frequency.monthly:
        return 'monthly';
      case Frequency.yearly:
        return 'yearly';
    }
  }

  @override
  void dispose() {
    _currentAmountController.dispose();
    _targetAmountController.dispose();
    _recurringAmountController.dispose();
    _payDayAmountController.dispose();
    _scrollController.dispose();
    _currentAmountFocus.dispose();
    _targetAmountFocus.dispose();
    _recurringAmountFocus.dispose();
    _payDayAmountFocus.dispose();
    super.dispose();
  }
}

// ============================================================================
// DATA CLASSES
// ============================================================================

enum Frequency { weekly, monthly, yearly }

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

  // NEW: Store full InsightData for better autopilot integration
  InsightData? insightData;

  EnvelopeData({required this.template});
}
