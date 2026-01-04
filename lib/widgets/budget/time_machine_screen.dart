import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:hive/hive.dart';
import '../../models/envelope.dart';
import '../../models/envelope_group.dart';
import '../../models/scheduled_payment.dart';
import '../../models/pay_day_settings.dart';
import '../../models/projection.dart';
import '../../services/account_repo.dart';
import '../../services/envelope_repo.dart';
import '../../services/group_repo.dart';
import '../../services/projection_service.dart';
import '../../providers/font_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/time_machine_provider.dart';
import 'time_machine_transition.dart';
import '../tutorial_wrapper.dart';
import '../../data/tutorial_sequences.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/common/smart_text_field.dart';

class TimeMachineScreen extends StatefulWidget {
  const TimeMachineScreen({
    super.key,
    required this.accountRepo,
    required this.envelopeRepo,
    required this.groupRepo,
    required this.paySettings,
    this.scrollToSettings = false,
  });

  final AccountRepo accountRepo;
  final EnvelopeRepo envelopeRepo;
  final GroupRepo groupRepo;
  final PayDaySettings paySettings;
  final bool scrollToSettings;

  @override
  State<TimeMachineScreen> createState() => _TimeMachineScreenState();
}

class _TimeMachineScreenState extends State<TimeMachineScreen> {
  late DateTime _targetDate;
  late DateTime _nextPayDate;
  late TextEditingController _payAmountController;
  late FocusNode _payAmountFocusNode;
  late String _payFrequency;

  // Scenario state
  final Map<String, bool> _envelopeEnabled = {};
  final Map<String, double> _envelopeOverrides = {};
  final Map<String, bool> _binderEnabled = {};
  final List<TemporaryEnvelope> _tempEnvelopes = [];
  final Map<String, EnvelopeSettingOverride> _envelopeSettings = {};
  final Map<String, DateTime> _scheduledPaymentDateOverrides = {};

  bool _calculating = false;
  bool _adjustmentsExpanded = false;
  ProjectionResult? _result;

  List<Envelope> _allEnvelopes = [];
  List<EnvelopeGroup> _allBinders = [];

  // Scroll controller and keys for navigation
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _settingsKey = GlobalKey();
  final GlobalKey _resultsKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    // Set target date to same day next month (or last day if that day doesn't exist)
    _targetDate = _getNextMonthSameDay(DateTime.now());

    // Use expectedPayAmount from PayDaySettings (not lastPayAmount)
    _payAmountController = TextEditingController(
      text: widget.paySettings.expectedPayAmount?.toStringAsFixed(2) ?? '0.00',
    );
    _payAmountFocusNode = FocusNode();

    // Use pay frequency from settings
    _payFrequency = widget.paySettings.payFrequency;

    // Use getNextPayDateAdjusted() to intelligently calculate next pay date
    final calculatedNextPayDate = widget.paySettings.adjustForWeekends
        ? widget.paySettings.getNextPayDateAdjusted()
        : widget.paySettings.getNextPayDate();

    if (calculatedNextPayDate != null) {
      // If the calculated date is in the past, advance it based on frequency
      final now = DateTime.now();
      _nextPayDate = calculatedNextPayDate;

      // Keep advancing until we get a future date
      while (_nextPayDate.isBefore(now)) {
        _nextPayDate = PayDaySettings.calculateNextPayDate(_nextPayDate, _payFrequency);
        if (widget.paySettings.adjustForWeekends) {
          _nextPayDate = widget.paySettings.adjustForWeekend(_nextPayDate);
        }
      }

      debugPrint('[TimeMachine] ✅ Initialized with next pay date: $_nextPayDate (adjustForWeekends: ${widget.paySettings.adjustForWeekends})');
    } else {
      _nextPayDate = DateTime.now().add(const Duration(days: 1));
      debugPrint('[TimeMachine] ⚠️ No pay date in settings, using tomorrow');
    }

    debugPrint('[TimeMachine] ✅ Initialized projection settings:');
    debugPrint('  - Target date: $_targetDate');
    debugPrint('  - Next pay date: $_nextPayDate');
    debugPrint('  - Pay amount: ${_payAmountController.text}');
    debugPrint('  - Pay frequency: $_payFrequency');

    _loadData();

    // Auto-scroll to settings after frame is rendered
    if (widget.scrollToSettings) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSettings();
      });
    }
  }

  void _scrollToSettings() {
    final context = _settingsKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _scrollToResults() {
    final context = _resultsKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
        alignment: 0.1, // Show near top of screen
      );
    }
  }

  /// Get the same day next month, or last day of next month if day doesn't exist
  DateTime _getNextMonthSameDay(DateTime date) {
    final nextMonth = DateTime(date.year, date.month + 1, 1);
    final lastDayOfNextMonth = DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
    final targetDay = date.day > lastDayOfNextMonth ? lastDayOfNextMonth : date.day;
    return DateTime(nextMonth.year, nextMonth.month, targetDay);
  }

  DateTime _calculateNextPayDateFromHistory(
    DateTime lastDate,
    String frequency,
  ) {
    DateTime calculated = lastDate;
    final now = DateTime.now();
    while (calculated.isBefore(now) || calculated.isAtSameMomentAs(now)) {
      switch (frequency) {
        case 'weekly':
          calculated = calculated.add(const Duration(days: 7));
          break;
        case 'biweekly':
          calculated = calculated.add(const Duration(days: 14));
          break;
        case 'monthly':
          calculated = DateTime(
            calculated.year,
            calculated.month + 1,
            calculated.day,
          );
          break;
        default:
          return now.add(const Duration(days: 1));
      }
    }
    return calculated;
  }

  @override
  void dispose() {
    _payAmountController.dispose();
    _payAmountFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final envelopes = await widget.envelopeRepo.envelopesStream().first;
    // Use getAllGroupsAsync to read from Hive (works in both solo and workspace mode)
    final allBinders = await widget.groupRepo.getAllGroupsAsync();

    if (!mounted) return;

    setState(() {
      _allEnvelopes = envelopes;
      _allBinders = allBinders;

      for (final env in envelopes) {
        _envelopeEnabled[env.id] = true;
      }
      for (final binder in _allBinders) {
        _binderEnabled[binder.id] = true;
      }
    });
  }

  void _resetToDefaults() {
    setState(() {
      _targetDate = _getNextMonthSameDay(DateTime.now());
      _payAmountController.text =
          widget.paySettings.lastPayAmount?.toStringAsFixed(2) ?? '0.00';
      _payFrequency = widget.paySettings.payFrequency;

      if (widget.paySettings.lastPayDate != null) {
        _nextPayDate = _calculateNextPayDateFromHistory(
          widget.paySettings.lastPayDate!,
          widget.paySettings.payFrequency,
        );
      } else {
        _nextPayDate = DateTime.now().add(const Duration(days: 1));
      }

      _envelopeOverrides.clear();
      _tempEnvelopes.clear();
      _envelopeSettings.clear();
      _scheduledPaymentDateOverrides.clear();
      _result = null;

      for (final env in _allEnvelopes) {
        _envelopeEnabled[env.id] = true;
      }
      for (final binder in _allBinders) {
        _binderEnabled[binder.id] = true;
      }
    });
  }

  void _toggleBinder(String binderId) {
    final newState = !(_binderEnabled[binderId] ?? true);
    setState(() {
      _binderEnabled[binderId] = newState;
      for (final env in _allEnvelopes) {
        if (env.groupId == binderId) _envelopeEnabled[env.id] = newState;
      }
    });
  }

  void _toggleEnvelope(String envelopeId) {
    setState(() {
      _envelopeEnabled[envelopeId] = !(_envelopeEnabled[envelopeId] ?? true);
    });
  }

  Future<void> _addTemporaryEnvelope() async {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    DateTime selectedStartDate = DateTime.now();
    DateTime? selectedEndDate;
    bool isIncome = false;
    String? frequency; // null = one-time

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Temporary Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Income/Expense Toggle
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('Expense'),
                      icon: Icon(Icons.arrow_downward, size: 16),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('Income'),
                      icon: Icon(Icons.arrow_upward, size: 16),
                    ),
                  ],
                  selected: {isIncome},
                  onSelectionChanged: (Set<bool> selected) {
                    setDialogState(() => isIncome = selected.first);
                  },
                ),
                const SizedBox(height: 16),
                SmartTextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Name'),
                  onTap: () => nameController.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: nameController.text.length,
                  ),
                ),
                SmartTextField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: '${Provider.of<LocaleProvider>(context, listen: false).currencySymbol} ',
                  ),
                  onTap: () => amountController.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: amountController.text.length,
                  ),
                ),
                const SizedBox(height: 16),

                // Frequency selector
                DropdownButtonFormField<String?>(
                  value: frequency,
                  decoration: const InputDecoration(labelText: 'Frequency'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('One-time')),
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    DropdownMenuItem(value: 'biweekly', child: Text('Biweekly')),
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  ],
                  onChanged: (val) => setDialogState(() => frequency = val),
                ),
                const SizedBox(height: 12),

                // Start Date
                ListTile(
                  title: Text(frequency == null ? 'Date' : 'Start Date'),
                  subtitle: Text(DateFormat('MMM d, yyyy').format(selectedStartDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedStartDate,
                      firstDate: DateTime.now(),
                      lastDate: _targetDate,
                    );
                    if (picked != null) {
                      setDialogState(() => selectedStartDate = picked);
                    }
                  },
                ),

                // End Date (only for recurring)
                if (frequency != null)
                  ListTile(
                    title: const Text('End Date (Optional)'),
                    subtitle: Text(selectedEndDate != null
                        ? DateFormat('MMM d, yyyy').format(selectedEndDate!)
                        : 'Ongoing'),
                    trailing: selectedEndDate != null
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setDialogState(() => selectedEndDate = null),
                          )
                        : const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedEndDate ?? selectedStartDate.add(const Duration(days: 30)),
                        firstDate: selectedStartDate,
                        lastDate: DateTime(2100, 12, 31), // Same as target date limit
                      );
                      if (picked != null) {
                        setDialogState(() => selectedEndDate = picked);
                      }
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final amt = double.tryParse(amountController.text);
                if (amt != null && nameController.text.isNotEmpty) {
                  Navigator.pop(context, {
                    'name': nameController.text,
                    'amount': amt,
                    'startDate': selectedStartDate,
                    'endDate': selectedEndDate,
                    'isIncome': isIncome,
                    'frequency': frequency,
                  });
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      setState(
        () => _tempEnvelopes.add(
          TemporaryEnvelope(
            id: const Uuid().v4(),
            name: result['name'],
            amount: result['amount'],
            startDate: result['startDate'],
            endDate: result['endDate'],
            isIncome: result['isIncome'],
            frequency: result['frequency'],
            linkedAccountId: null,
          ),
        ),
      );
    }
  }

  void _removeTempEnvelope(String id) {
    setState(() => _tempEnvelopes.removeWhere((e) => e.id == id));
  }

  double _calculateTotalAutoFill() {
    double total = 0;
    for (final env in _allEnvelopes) {
      final isEnabled = _envelopeEnabled[env.id] ?? true;
      if (!isEnabled) continue;

      final settingOverride = _envelopeSettings[env.id];
      final autoFillEnabled = settingOverride?.autoFillEnabled ?? env.autoFillEnabled;
      final autoFillAmount = settingOverride?.autoFillAmount ?? env.autoFillAmount ?? 0;

      if (autoFillEnabled && autoFillAmount > 0) {
        total += autoFillAmount;
      }
    }
    return total;
  }

  Future<void> _showEnvelopeSettings(Envelope envelope) async {
    final currentOverride = _envelopeSettings[envelope.id];
    final autoFillEnabled = currentOverride?.autoFillEnabled ?? envelope.autoFillEnabled;
    final autoFillAmount = currentOverride?.autoFillAmount ?? envelope.autoFillAmount ?? 0;

    bool enabledValue = autoFillEnabled;
    final amountController = TextEditingController(
      text: autoFillAmount.toStringAsFixed(2),
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              if (envelope.iconValue != null || envelope.emoji != null)
                envelope.getIconWidget(Theme.of(context), size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  envelope.name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Scenario Override Settings',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Auto-fill Enabled'),
                  value: enabledValue,
                  onChanged: (val) => setDialogState(() => enabledValue = val),
                ),
                const SizedBox(height: 8),
                if (enabledValue)
                  SmartTextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Auto-fill Amount',
                      prefixText: '${Provider.of<LocaleProvider>(context, listen: false).currencySymbol} ',
                    ),
                    onTap: () => amountController.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: amountController.text.length,
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Original: ${envelope.autoFillEnabled ? "${Provider.of<LocaleProvider>(context, listen: false).currencySymbol}${envelope.autoFillAmount?.toStringAsFixed(2) ?? '0.00'}" : "OFF"}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (currentOverride != null)
              TextButton(
                onPressed: () => Navigator.pop(context, {'remove': true}),
                child: const Text('Remove Override'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final amt = double.tryParse(amountController.text);
                if (amt != null) {
                  Navigator.pop(context, {
                    'autoFillEnabled': enabledValue,
                    'autoFillAmount': amt,
                  });
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      setState(() {
        if (result['remove'] == true) {
          _envelopeSettings.remove(envelope.id);
        } else {
          _envelopeSettings[envelope.id] = EnvelopeSettingOverride(
            autoFillEnabled: result['autoFillEnabled'],
            autoFillAmount: result['autoFillAmount'],
          );
        }
      });
    }
  }

  Future<void> _calculate() async {
    if (_calculating) return;

    final payAmount = double.tryParse(_payAmountController.text);
    if (payAmount == null || payAmount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid pay amount')),
      );
      return;
    }

    setState(() => _calculating = true);

    try {
      final accounts = await widget.accountRepo.accountsStream().first;
      final envelopes = _allEnvelopes;

      // Fetch scheduled payments from Hive
      final paymentBox = Hive.box<ScheduledPayment>('scheduledPayments');

      // Get valid envelope IDs to filter out orphaned scheduled payments
      final validEnvelopeIds = envelopes.map((e) => e.id).toSet();

      final scheduledPayments = paymentBox.values
          .where((p) => p.userId == widget.envelopeRepo.currentUserId)
          .where((p) {
            // Include payments without envelope ID (account-level payments)
            if (p.envelopeId == null) return true;

            // Only include payments linked to existing envelopes
            final isValid = validEnvelopeIds.contains(p.envelopeId);

            if (!isValid) {
              debugPrint('[TimeMachine] ⚠️ Filtering out orphaned scheduled payment: ${p.name} (envelope ${p.envelopeId} not found)');
            }

            return isValid;
          })
          .toList();

      debugPrint('[TimeMachine] Using ${scheduledPayments.length} valid scheduled payments for projection');

      final scenario = ProjectionScenario(
        startDate: DateTime.now(),
        endDate: _targetDate,
        customPayAmount: payAmount,
        customPayFrequency: _payFrequency,
        envelopeEnabled: _envelopeEnabled,
        envelopeOverrides: _envelopeOverrides,
        temporaryEnvelopes: _tempEnvelopes,
        binderEnabled: _binderEnabled,
        envelopeSettings: _envelopeSettings,
        scheduledPaymentDateOverrides: _scheduledPaymentDateOverrides,
      );

      final anchorDate = _calculateAnchorDate(_nextPayDate, _payFrequency);

      final customSettings = PayDaySettings(
        userId: widget.envelopeRepo.currentUserId,
        lastPayAmount: payAmount,
        payFrequency: _payFrequency,
        payDayOfMonth: _nextPayDate.day, // Extract day from date picker
        lastPayDate: anchorDate,
        defaultAccountId: widget.paySettings.defaultAccountId,
      );

      final result = await ProjectionService.calculateProjection(
        targetDate: _targetDate,
        accounts: accounts,
        envelopes: envelopes,
        scheduledPayments: scheduledPayments,
        paySettings: customSettings,
        scenario: scenario,
      );

      setState(() {
        _result = result;
        _calculating = false;
      });

      // Scroll to results after calculation
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToResults();
      });
    } catch (e) {
      setState(() => _calculating = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  DateTime _calculateAnchorDate(DateTime target, String frequency) {
    // print('\n>>> _calculateAnchorDate DEBUG (Time Machine) <<<');
    // print('Target (Next Pay Date): $target');
    // print('Frequency: $frequency');

    DateTime anchor;
    switch (frequency) {
      case 'weekly':
        anchor = target.subtract(const Duration(days: 7));
    // print('WEEKLY: Anchor = target - 7 days = $anchor');
        break;
      case 'biweekly':
        anchor = target.subtract(const Duration(days: 14));
    // print('BIWEEKLY: Anchor = target - 14 days = $anchor');
        break;
      case 'monthly':
        anchor = DateTime(target.year, target.month - 1, target.day);
    // print('MONTHLY: Anchor = previous month same day = $anchor');
        break;
      default:
        anchor = target.subtract(const Duration(days: 1));
    // print('DEFAULT: Anchor = target - 1 day = $anchor');
        break;
    }
    // print('>>> Anchor date will be used as lastPayDate in projection <<<\n');
    return anchor;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final locale = Provider.of<LocaleProvider>(context, listen: false);
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);
    final responsive = context.responsive;
    final isLandscape = responsive.isLandscape;

    final envelopesByBinder = <String, List<Envelope>>{};
    final individualEnvelopes = <Envelope>[];
    for (final env in _allEnvelopes) {
      if (env.groupId != null && env.groupId!.isNotEmpty) {
        envelopesByBinder.putIfAbsent(env.groupId!, () => []).add(env);
      } else {
        individualEnvelopes.add(env);
      }
    }

    return TutorialWrapper(
      tutorialSequence: timeMachineTutorial,
      spotlightKeys: const {},
      child: Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        toolbarHeight: isLandscape ? 48 : kToolbarHeight,
        leading: IconButton(
          icon: Icon(Icons.close, size: isLandscape ? 20 : 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.access_time, size: isLandscape ? 20 : 28),
            const SizedBox(width: 8),
            Text(
              'Time Machine',
              style: fontProvider.getTextStyle(
                fontSize: isLandscape ? 18 : 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.symmetric(
          horizontal: isLandscape ? 60 : 16,
          vertical: isLandscape ? 12 : 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ========== SECTION 1: SETTINGS ==========
            Container(
              key: _settingsKey,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
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
                      Icon(
                        Icons.settings,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Projection Settings',
                        style: fontProvider.getTextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Target Date
                  Text(
                    'Target Date',
                    style: fontProvider.getTextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _targetDate,
                        firstDate: DateTime.now().add(const Duration(days: 1)),
                        lastDate: DateTime(2100, 12, 31), // Plan into the next century!
                      );
                      if (picked != null) setState(() => _targetDate = picked);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.colorScheme.outline),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_month,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              DateFormat('MMMM d, yyyy').format(_targetDate),
                              style: fontProvider.getTextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Next Pay Date
                  Text(
                    'Next Pay Date',
                    style: fontProvider.getTextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final now = DateTime.now();
                      // Ensure initialDate is not before firstDate
                      final initialDate = _nextPayDate.isBefore(now) ? now : _nextPayDate;

                      final picked = await showDatePicker(
                        context: context,
                        initialDate: initialDate,
                        firstDate: now,
                        lastDate: _targetDate,
                        helpText: 'When is your next paycheck?',
                      );
                      if (picked != null) {
                        setState(() => _nextPayDate = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.colorScheme.outline),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.event_available,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              DateFormat('MMMM d, yyyy').format(_nextPayDate),
                              style: fontProvider.getTextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Pay Amount
                  Text(
                    'Pay Amount',
                    style: fontProvider.getTextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SmartTextField(
                    controller: _payAmountController,
                    focusNode: _payAmountFocusNode,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: fontProvider.getTextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () {
                      // Select all text when tapped
                      _payAmountController.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: _payAmountController.text.length,
                      );
                    },
                    decoration: InputDecoration(
                      prefixText: '${locale.currencySymbol} ',
                      prefixStyle: fontProvider.getTextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Pay Frequency
                  Text(
                    'Pay Frequency',
                    style: fontProvider.getTextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InputDecorator(
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _payFrequency,
                        isExpanded: true,
                        items: [
                          DropdownMenuItem(
                            value: 'weekly',
                            child: Text(
                              'Weekly',
                              style: fontProvider.getTextStyle(fontSize: 16),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'biweekly',
                            child: Text(
                              'Biweekly',
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
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Info Banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Projection based on current auto-fill & scheduled payments',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Calculate Button
                  FilledButton(
                    onPressed: _calculating ? null : _calculate,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 56),
                      backgroundColor: theme.colorScheme.secondary,
                    ),
                    child: _calculating
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.calculate, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                'Calculate Projection',
                                style: fontProvider.getTextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ========== SECTION 2: ADJUSTMENTS (COLLAPSIBLE) ==========
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ExpansionTile(
                initiallyExpanded: _adjustmentsExpanded,
                onExpansionChanged: (expanded) {
                  setState(() => _adjustmentsExpanded = expanded);
                },
                leading: Icon(
                  Icons.tune,
                  color: theme.colorScheme.secondary,
                ),
                title: Text(
                  'Scenario Adjuster',
                  style: fontProvider.getTextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text('Fine-tune envelopes, income, expenses & payments'),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Envelopes & Auto-fill:',
                              style: fontProvider.getTextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                'Total: ${currency.format(_calculateTotalAutoFill())}',
                                style: fontProvider.getTextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Individual envelopes
                        ...individualEnvelopes.map(
                          (env) {
                            final settingOverride = _envelopeSettings[env.id];
                            final autoFillEnabled = settingOverride?.autoFillEnabled ?? env.autoFillEnabled;
                            final autoFillAmount = settingOverride?.autoFillAmount ?? env.autoFillAmount ?? 0;
                            final hasOverride = _envelopeSettings.containsKey(env.id);

                            return CheckboxListTile(
                              dense: true,
                              value: _envelopeEnabled[env.id] ?? true,
                              onChanged: (val) => _toggleEnvelope(env.id),
                              title: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (env.iconValue != null || env.emoji != null)
                                    env.getIconWidget(theme, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(env.name)),
                                  IconButton(
                                    icon: Icon(
                                      Icons.settings,
                                      size: 18,
                                      color: hasOverride
                                          ? theme.colorScheme.secondary
                                          : Colors.grey,
                                    ),
                                    onPressed: () => _showEnvelopeSettings(env),
                                    tooltip: 'Override auto-fill settings',
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                '${currency.format(env.currentAmount)} • Auto-fill: ${autoFillEnabled && autoFillAmount > 0 ? currency.format(autoFillAmount) : "OFF"}${hasOverride ? " ⚙️" : ""}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: hasOverride
                                      ? theme.colorScheme.secondary
                                      : Colors.grey[600],
                                  fontWeight: hasOverride ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            );
                          },
                        ),

                        // Binders with envelopes
                        ...envelopesByBinder.entries.map((entry) {
                          final binder =
                              _allBinders.firstWhere((b) => b.id == entry.key);
                          final envelopes = entry.value;
                          final isBinderEnabled =
                              _binderEnabled[binder.id] ?? true;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CheckboxListTile(
                                dense: true,
                                value: isBinderEnabled,
                                onChanged: (val) => _toggleBinder(binder.id),
                                title: Row(
                                  children: [
                                    if (binder.emoji != null)
                                      Text(
                                        binder.emoji!,
                                        style: const TextStyle(fontSize: 18),
                                      ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        binder.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.secondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: const Text('Toggle all'),
                              ),
                              ...envelopes.map(
                                (env) {
                                  final settingOverride = _envelopeSettings[env.id];
                                  final autoFillEnabled = settingOverride?.autoFillEnabled ?? env.autoFillEnabled;
                                  final autoFillAmount = settingOverride?.autoFillAmount ?? env.autoFillAmount ?? 0;
                                  final hasOverride = _envelopeSettings.containsKey(env.id);

                                  return Padding(
                                    padding: const EdgeInsets.only(left: 32),
                                    child: CheckboxListTile(
                                      dense: true,
                                      value: _envelopeEnabled[env.id] ?? true,
                                      onChanged: (val) => _toggleEnvelope(env.id),
                                      title: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (env.iconValue != null ||
                                              env.emoji != null)
                                            env.getIconWidget(theme, size: 16),
                                          const SizedBox(width: 8),
                                          Expanded(child: Text(env.name)),
                                          IconButton(
                                            icon: Icon(
                                              Icons.settings,
                                              size: 16,
                                              color: hasOverride
                                                  ? theme.colorScheme.secondary
                                                  : Colors.grey,
                                            ),
                                            onPressed: () => _showEnvelopeSettings(env),
                                            tooltip: 'Override auto-fill settings',
                                          ),
                                        ],
                                      ),
                                      subtitle: Text(
                                        '${currency.format(env.currentAmount)} • Auto-fill: ${autoFillEnabled && autoFillAmount > 0 ? currency.format(autoFillAmount) : "OFF"}${hasOverride ? " ⚙️" : ""}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: hasOverride
                                              ? theme.colorScheme.secondary
                                              : Colors.grey[600],
                                          fontWeight: hasOverride ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          );
                        }),

                        const Divider(height: 32),

                        // Temporary Income/Expenses
                        Text(
                          'Temporary Income/Expenses:',
                          style: fontProvider.getTextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),

                        ..._tempEnvelopes.map(
                          (temp) {
                            String subtitle;
                            if (temp.isRecurring) {
                              final endInfo = temp.endDate != null
                                  ? ' until ${DateFormat('MMM d').format(temp.endDate!)}'
                                  : ' (ongoing)';
                              subtitle = '${currency.format(temp.amount)} ${temp.frequency} from ${DateFormat('MMM d').format(temp.startDate)}$endInfo';
                            } else {
                              subtitle = '${currency.format(temp.amount)} on ${DateFormat('MMM d').format(temp.startDate)}';
                            }

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              color: temp.isIncome
                                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                                  : null,
                              child: ListTile(
                                dense: true,
                                leading: Icon(
                                  temp.isIncome ? Icons.arrow_upward : Icons.arrow_downward,
                                  size: 20,
                                  color: temp.isIncome ? Colors.green : Colors.red,
                                ),
                                title: Text(temp.name),
                                subtitle: Text(
                                  subtitle,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, size: 20),
                                  color: Colors.red,
                                  onPressed: () => _removeTempEnvelope(temp.id),
                                ),
                              ),
                            );
                          },
                        ),

                        OutlinedButton.icon(
                          onPressed: _addTemporaryEnvelope,
                          icon: const Icon(Icons.add, size: 20),
                          label: const Text('Add Temporary Item'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 44),
                          ),
                        ),

                        const SizedBox(height: 12),

                        OutlinedButton.icon(
                          onPressed: _resetToDefaults,
                          icon: const Icon(Icons.refresh, size: 20),
                          label: const Text('Reset to Defaults'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 44),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ========== SECTION 3: RESULTS ==========
            if (_result != null) ...[
              Container(
                key: _resultsKey,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color:
                      theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.analytics,
                          color: theme.colorScheme.secondary,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Future Snapshot',
                                style: fontProvider.getTextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.secondary,
                                ),
                              ),
                              Text(
                                DateFormat('MMMM d, yyyy')
                                    .format(_result!.projectionDate),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Summary Cards
                    _SummaryCard(
                      icon: Icons.account_balance_wallet,
                      label: 'Total Balance',
                      amount: _result!.totalBalance,
                      color: theme.colorScheme.primary,
                      currency: currency,
                    ),
                    const SizedBox(height: 8),
                    _SummaryCard(
                      icon: Icons.mail,
                      label: 'In Envelopes',
                      amount: _result!.totalAssigned,
                      color: Colors.blue,
                      currency: currency,
                    ),
                    const SizedBox(height: 8),
                    _SummaryCard(
                      icon: Icons.auto_awesome,
                      label: 'Unallocated',
                      amount: _result!.totalAvailable,
                      color: Colors.green,
                      currency: currency,
                    ),
                    const SizedBox(height: 8),
                    _SummaryCard(
                      icon: Icons.payment,
                      label: 'Total Spent',
                      amount: _result!.totalSpent,
                      color: Colors.red,
                      currency: currency,
                      tooltip: 'Money paid to external bills/expenses',
                    ),

                    const SizedBox(height: 20),

                    // Income vs Expenses Breakdown
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.analytics_outlined,
                                size: 20,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Income & Expenses',
                                style: fontProvider.getTextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem(
                                context: context,
                                label: 'Income',
                                value: _calculateTotalIncome(_result!.timeline),
                                color: Colors.green,
                                currency: locale.currencySymbol,
                                fontProvider: fontProvider,
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: theme.colorScheme.outline.withValues(alpha: 0.2),
                              ),
                              _buildStatItem(
                                context: context,
                                label: 'Expenses',
                                value: _calculateTotalExpenses(_result!.timeline),
                                color: Colors.red,
                                currency: locale.currencySymbol,
                                fontProvider: fontProvider,
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: theme.colorScheme.outline.withValues(alpha: 0.2),
                              ),
                              _buildStatItem(
                                context: context,
                                label: 'Net Change',
                                value: _calculateNetChange(_result!.timeline),
                                color: _calculateNetChange(_result!.timeline) >= 0
                                    ? Colors.green
                                    : Colors.red,
                                currency: locale.currencySymbol,
                                fontProvider: fontProvider,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Projected Timeline
                    if (_result!.timeline.isNotEmpty)
                      Card(
                        margin: EdgeInsets.zero,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ExpansionTile(
                          title: Row(
                            children: [
                              Icon(
                                Icons.timeline,
                                size: 20,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Projected Transactions',
                                style: fontProvider.getTextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4, left: 32),
                            child: Text(
                              '${_result!.timeline.length} events',
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                          children: [
                            Container(
                              constraints: const BoxConstraints(maxHeight: 400),
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const ClampingScrollPhysics(),
                                padding: const EdgeInsets.all(16),
                                itemCount: _result!.timeline.length,
                                separatorBuilder: (context, index) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final event = _result!.timeline[index];
                                  final isIncome = event.isCredit;

                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isIncome
                                            ? Colors.green.shade50
                                            : Colors.red.shade50,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isIncome ? Icons.add : Icons.remove,
                                        color: isIncome ? Colors.green : Colors.red,
                                        size: 20,
                                      ),
                                    ),
                                    title: Text(
                                      event.description,
                                      style: fontProvider.getTextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          DateFormat('MMM d, yyyy').format(event.date),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.6),
                                          ),
                                        ),
                                        if (event.envelopeName != null)
                                          Text(
                                            'Envelope: ${event.envelopeName}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: theme.colorScheme.primary
                                                  .withValues(alpha: 0.7),
                                            ),
                                          ),
                                      ],
                                    ),
                                    trailing: Text(
                                      '${isIncome ? '+' : '-'}${locale.currencySymbol}${event.amount.toStringAsFixed(2)}',
                                      style: fontProvider.getTextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isIncome ? Colors.green : Colors.red,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 20),

                    // Enter Time Machine Button (with pulsing animation)
                    _PulsingEnterButton(
                      targetDate: _targetDate,
                      result: _result!,
                    ),

                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 20),

                    // Account Breakdowns
                    ..._result!.accountProjections.values.map((accountProj) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ExpansionTile(
                          initiallyExpanded: true,
                          leading: Icon(
                            Icons.account_balance,
                            color: theme.colorScheme.primary,
                          ),
                          title: Text(
                            accountProj.accountName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            currency.format(accountProj.projectedBalance),
                            style: TextStyle(
                              color: accountProj.projectedBalance < 0
                                  ? Colors.red
                                  : Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          children: [
                            Container(
                              color: theme.colorScheme.surfaceContainerLowest,
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  if (accountProj.envelopeProjections.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Text(
                                        'No linked envelopes',
                                        style: TextStyle(
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  ...accountProj.envelopeProjections.map((env) {
                                    final change =
                                        env.projectedAmount - env.currentAmount;
                                    final isPositive = change >= 0;
                                    final tempEnvelope = Envelope(
                                      id: env.envelopeId,
                                      name: env.envelopeName,
                                      userId: '',
                                      emoji: env.emoji,
                                      iconType: env.iconType,
                                      iconValue: env.iconValue,
                                    );
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 6,
                                      ),
                                      child: Row(
                                        children: [
                                          if (tempEnvelope.iconValue != null ||
                                              tempEnvelope.emoji != null) ...[
                                            tempEnvelope.getIconWidget(
                                              theme,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  env.envelopeName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                Text(
                                                  '${isPositive ? '+' : ''}${currency.format(change)}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isPositive
                                                        ? Colors.green
                                                        : Colors.red,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            currency.format(env.projectedAmount),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: env.projectedAmount < 0
                                                  ? Colors.red
                                                  : null,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                  const Divider(height: 24),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Available:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        currency.format(
                                          accountProj.availableAmount,
                                        ),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.secondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 80),
          ],
        ),
      ),
    ),
    );
  }

  // Helper methods for stats calculation
  double _calculateTotalIncome(List<ProjectionEvent> timeline) {
    return timeline
        .where((event) => event.isCredit)
        .fold(0.0, (sum, event) => sum + event.amount);
  }

  double _calculateTotalExpenses(List<ProjectionEvent> timeline) {
    return timeline
        .where((event) => !event.isCredit)
        .fold(0.0, (sum, event) => sum + event.amount);
  }

  double _calculateNetChange(List<ProjectionEvent> timeline) {
    return _calculateTotalIncome(timeline) - _calculateTotalExpenses(timeline);
  }

  Widget _buildStatItem({
    required BuildContext context,
    required String label,
    required double value,
    required Color color,
    required String currency,
    required FontProvider fontProvider,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$currency${value.toStringAsFixed(2)}',
              style: fontProvider.getTextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ========== HELPER WIDGET ==========

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.amount,
    required this.color,
    required this.currency,
    this.tooltip,
  });

  final IconData icon;
  final String label;
  final double amount;
  final Color color;
  final NumberFormat currency;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          Text(
            currency.format(amount),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (tooltip != null) ...[
            const SizedBox(width: 4),
            Tooltip(
              message: tooltip!,
              child: Icon(
                Icons.info_outline,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
      ),
    );

    return card;
  }
}

// Pulsing Enter Time Machine Button Widget
class _PulsingEnterButton extends StatefulWidget {
  const _PulsingEnterButton({
    required this.targetDate,
    required this.result,
  });

  final DateTime targetDate;
  final ProjectionResult result;

  @override
  State<_PulsingEnterButton> createState() => _PulsingEnterButtonState();
}

class _PulsingEnterButtonState extends State<_PulsingEnterButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
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
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.secondary.withValues(
                  alpha: _glowAnimation.value,
                ),
                blurRadius: 20 * _glowAnimation.value,
                spreadRadius: 5 * _glowAnimation.value,
              ),
            ],
          ),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: FilledButton.icon(
              onPressed: () async {
                // Show cool transition animation
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => TimeMachineTransition(
                    targetDate: widget.targetDate,
                  ),
                );

                // Wait for animation
                await Future.delayed(const Duration(milliseconds: 1500));

                // Activate Time Machine mode
                if (!context.mounted) return;
                final timeMachine = Provider.of<TimeMachineProvider>(
                  context,
                  listen: false,
                );
                timeMachine.enterTimeMachine(
                  targetDate: widget.targetDate,
                  projection: widget.result,
                );

                // Close transition dialog
                if (!context.mounted) return;
                Navigator.pop(context); // Close transition

                // Pop back to budget screen
                if (!context.mounted) return;
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
                minimumSize: const Size(double.infinity, 70),
                backgroundColor: theme.colorScheme.secondary,
                foregroundColor: theme.colorScheme.onSecondary,
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.access_time, size: 32),
              label: Text(
                'Enter Time Machine',
                style: fontProvider.getTextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSecondary,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
