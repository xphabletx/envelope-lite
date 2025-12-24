import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
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
import '../../providers/time_machine_provider.dart';
import 'time_machine_transition.dart';

class TimeMachineScreen extends StatefulWidget {
  const TimeMachineScreen({
    super.key,
    required this.accountRepo,
    required this.envelopeRepo,
    required this.groupRepo,
    required this.paySettings,
  });

  final AccountRepo accountRepo;
  final EnvelopeRepo envelopeRepo;
  final GroupRepo groupRepo;
  final PayDaySettings paySettings;

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

  bool _calculating = false;
  bool _adjustmentsExpanded = false;
  ProjectionResult? _result;

  List<Envelope> _allEnvelopes = [];
  List<EnvelopeGroup> _allBinders = [];

  @override
  void initState() {
    super.initState();
    _targetDate = DateTime.now().add(const Duration(days: 30));
    _payAmountController = TextEditingController(
      text: widget.paySettings.lastPayAmount?.toStringAsFixed(2) ?? '0.00',
    );
    _payAmountFocusNode = FocusNode();
    _payFrequency = widget.paySettings.payFrequency;

    if (widget.paySettings.lastPayDate != null) {
      _nextPayDate = _calculateNextPayDateFromHistory(
        widget.paySettings.lastPayDate!,
        widget.paySettings.payFrequency,
      );
    } else {
      _nextPayDate = DateTime.now().add(const Duration(days: 1));
    }

    _loadData();
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
    super.dispose();
  }

  Future<void> _loadData() async {
    final envelopes = await widget.envelopeRepo.envelopesStream().first;
    final bindersSnapshot = await widget.groupRepo.groupsCol().get();

    if (!mounted) return;

    setState(() {
      _allEnvelopes = envelopes;
      _allBinders = bindersSnapshot.docs
          .map((doc) => EnvelopeGroup.fromFirestore(doc))
          .toList();

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
      _targetDate = DateTime.now().add(const Duration(days: 30));
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
    DateTime selectedDate = DateTime.now();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Temporary Expense'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '£ ',
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: const Text('Date'),
                  subtitle: Text(DateFormat('MMM d, yyyy').format(selectedDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: _targetDate,
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
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
                    'date': selectedDate,
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
            effectiveDate: result['date'],
            linkedAccountId: null,
          ),
        ),
      );
    }
  }

  void _removeTempEnvelope(String id) {
    setState(() => _tempEnvelopes.removeWhere((e) => e.id == id));
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

      final paymentsSnapshot = await widget.envelopeRepo.db
          .collection('users')
          .doc(widget.envelopeRepo.currentUserId)
          .collection('solo')
          .doc('data')
          .collection('scheduledPayments')
          .get();

      final scheduledPayments = paymentsSnapshot.docs
          .map((doc) => ScheduledPayment.fromFirestore(doc))
          .toList();

      final scenario = ProjectionScenario(
        startDate: DateTime.now(),
        endDate: _targetDate,
        customPayAmount: payAmount,
        customPayFrequency: _payFrequency,
        envelopeEnabled: _envelopeEnabled,
        envelopeOverrides: _envelopeOverrides,
        temporaryEnvelopes: _tempEnvelopes,
        binderEnabled: _binderEnabled,
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
    print('\n>>> _calculateAnchorDate DEBUG (Time Machine) <<<');
    print('Target (Next Pay Date): $target');
    print('Frequency: $frequency');

    DateTime anchor;
    switch (frequency) {
      case 'weekly':
        anchor = target.subtract(const Duration(days: 7));
        print('WEEKLY: Anchor = target - 7 days = $anchor');
        break;
      case 'biweekly':
        anchor = target.subtract(const Duration(days: 14));
        print('BIWEEKLY: Anchor = target - 14 days = $anchor');
        break;
      case 'monthly':
        anchor = DateTime(target.year, target.month - 1, target.day);
        print('MONTHLY: Anchor = previous month same day = $anchor');
        break;
      default:
        anchor = target.subtract(const Duration(days: 1));
        print('DEFAULT: Anchor = target - 1 day = $anchor');
        break;
    }
    print('>>> Anchor date will be used as lastPayDate in projection <<<\n');
    return anchor;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final currency = NumberFormat.currency(symbol: '£');

    final envelopesByBinder = <String, List<Envelope>>{};
    final individualEnvelopes = <Envelope>[];
    for (final env in _allEnvelopes) {
      if (env.groupId != null && env.groupId!.isNotEmpty) {
        envelopesByBinder.putIfAbsent(env.groupId!, () => []).add(env);
      } else {
        individualEnvelopes.add(env);
      }
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.access_time, size: 28),
            const SizedBox(width: 8),
            Text(
              'Time Machine',
              style: fontProvider.getTextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ========== SECTION 1: SETTINGS ==========
            Container(
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
                        lastDate: DateTime.now().add(const Duration(days: 730)),
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
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _nextPayDate,
                        firstDate: DateTime.now(),
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
                  TextField(
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
                      prefixText: '£ ',
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
                  'Scenario Adjustments (Optional)',
                  style: fontProvider.getTextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text('Toggle envelopes, add temp expenses'),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Toggle Envelopes/Binders:',
                          style: fontProvider.getTextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Individual envelopes
                        ...individualEnvelopes.map(
                          (env) => CheckboxListTile(
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
                                Text(
                                  currency.format(env.currentAmount),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
                                (env) => Padding(
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
                                        Text(
                                          currency.format(env.currentAmount),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),

                        const Divider(height: 32),

                        // Temporary Expenses
                        Text(
                          'Temporary Expenses:',
                          style: fontProvider.getTextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),

                        ..._tempEnvelopes.map(
                          (temp) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              dense: true,
                              leading: const Icon(Icons.schedule, size: 20),
                              title: Text(temp.name),
                              subtitle: Text(
                                '${currency.format(temp.amount)} on ${DateFormat('MMM d').format(temp.effectiveDate)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, size: 20),
                                color: Colors.red,
                                onPressed: () => _removeTempEnvelope(temp.id),
                              ),
                            ),
                          ),
                        ),

                        OutlinedButton.icon(
                          onPressed: _addTemporaryEnvelope,
                          icon: const Icon(Icons.add, size: 20),
                          label: const Text('Add Temporary Expense'),
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

                    const SizedBox(height: 24),

                    // Enter Time Machine Button
                    FilledButton.icon(
                      onPressed: () async {
                        if (_result == null) return;

                        // Show cool transition animation
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => TimeMachineTransition(
                            targetDate: _targetDate,
                          ),
                        );

                        // Wait for animation
                        await Future.delayed(const Duration(milliseconds: 1500));

                        // Activate Time Machine mode
                        if (!mounted) return;
                        final timeMachine = Provider.of<TimeMachineProvider>(
                          context,
                          listen: false,
                        );
                        timeMachine.enterTimeMachine(
                          targetDate: _targetDate,
                          projection: _result!,
                        );

                        // Close transition dialog
                        if (!mounted) return;
                        Navigator.pop(context); // Close transition

                        // Navigate to home screen (in future mode)
                        Navigator.popUntil(context, (route) => route.isFirst);
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        minimumSize: const Size(double.infinity, 60),
                        backgroundColor: theme.colorScheme.secondaryContainer,
                        foregroundColor:
                            theme.colorScheme.onSecondaryContainer,
                      ),
                      icon: const Icon(Icons.access_time, size: 28),
                      label: Text(
                        'Enter Time Machine',
                        style: fontProvider.getTextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 80),
          ],
        ),
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
