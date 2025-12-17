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

class ScenarioEditorModal extends StatefulWidget {
  const ScenarioEditorModal({
    super.key,
    required this.accountRepo,
    required this.envelopeRepo,
    required this.groupRepo,
    required this.initialStartDate,
    required this.initialEndDate,
    required this.paySettings,
  });

  final AccountRepo accountRepo;
  final EnvelopeRepo envelopeRepo;
  final GroupRepo groupRepo;
  final DateTime initialStartDate;
  final DateTime initialEndDate;
  final PayDaySettings paySettings;

  @override
  State<ScenarioEditorModal> createState() => _ScenarioEditorModalState();
}

class _ScenarioEditorModalState extends State<ScenarioEditorModal> {
  late DateTime _startDate;
  late DateTime _endDate;
  late DateTime _nextPayDate;
  late TextEditingController _payAmountController;
  late String _payFrequency;

  // Scenario state
  final Map<String, bool> _envelopeEnabled = {};
  final Map<String, double> _envelopeOverrides = {};
  final Map<String, bool> _binderEnabled = {};
  final List<TemporaryEnvelope> _tempEnvelopes = [];

  bool _calculating = false;
  ProjectionResult? _result;

  List<Envelope> _allEnvelopes = [];
  List<EnvelopeGroup> _allBinders = [];

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
    _payAmountController = TextEditingController(
      text: widget.paySettings.lastPayAmount?.toStringAsFixed(2) ?? '0.00',
    );
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

  /// Helper to guess the next pay date based on history
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
      _startDate = widget.initialStartDate;
      _endDate = widget.initialEndDate;
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

  Future<void> _editEnvelopeAmount(Envelope envelope) async {
    final controller = TextEditingController(
      text: (_envelopeOverrides[envelope.id] ?? envelope.currentAmount)
          .toStringAsFixed(2),
    );
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${envelope.name}'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Amount',
            prefixText: '£ ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              Navigator.pop(context, val);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) {
      setState(() => _envelopeOverrides[envelope.id] = result);
    }
  }

  Future<void> _addTemporaryEnvelope() async {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Temporary Envelope'),
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
                  decoration: const InputDecoration(labelText: 'Amount'),
                ),
                ListTile(
                  title: Text(DateFormat('MMM d').format(selectedDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: _startDate,
                      lastDate: _endDate,
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
                if (amt != null) {
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
        startDate: _startDate,
        endDate: _endDate,
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
        payDayOfMonth: widget.paySettings.payDayOfMonth ?? 1,
        lastPayDate: anchorDate,
        defaultAccountId: widget.paySettings.defaultAccountId,
      );

      final result = await ProjectionService.calculateProjection(
        targetDate: _endDate,
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
    switch (frequency) {
      case 'weekly':
        return target.subtract(const Duration(days: 7));
      case 'biweekly':
        return target.subtract(const Duration(days: 14));
      case 'monthly':
        return DateTime(target.year, target.month - 1, target.day);
      default:
        return target.subtract(const Duration(days: 1));
    }
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
        title: Text(
          'Scenario Editor',
          style: fontProvider.getTextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- SETTINGS SECTION ---
            Text(
              '⚙️ Scenario Settings',
              style: fontProvider.getTextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),

            // Row 1: Date Range
            Row(
              children: [
                Expanded(
                  child: _DatePickerTile(
                    label: 'From',
                    date: _startDate,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime.now(),
                        lastDate: _endDate,
                      );
                      if (picked != null) setState(() => _startDate = picked);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DatePickerTile(
                    label: 'To',
                    date: _endDate,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _endDate,
                        firstDate: _startDate,
                        lastDate: DateTime.now().add(
                          const Duration(days: 365 * 2),
                        ),
                      );
                      if (picked != null) setState(() => _endDate = picked);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Row 2: Pay Amount
            TextField(
              controller: _payAmountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Pay Amount',
                prefixText: '£ ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Row 3: Frequency & Next Pay Date
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Frequency',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _payFrequency,
                        isExpanded: true,
                        items: ['weekly', 'biweekly', 'monthly']
                            .map(
                              (f) => DropdownMenuItem(
                                value: f,
                                child: Text(
                                  f[0].toUpperCase() + f.substring(1),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _payFrequency = v);
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // NEW FIELD: Next Pay Day Picker
                Expanded(
                  flex: 3,
                  child: _DatePickerTile(
                    label: 'Next Pay Day',
                    date: _nextPayDate,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _nextPayDate,
                        firstDate: DateTime.now(),
                        lastDate: _endDate,
                        helpText: 'Select Next Pay Check Date',
                      );
                      if (picked != null) setState(() => _nextPayDate = picked);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _resetToDefaults,
              icon: const Icon(Icons.refresh),
              label: const Text('Reset to Defaults'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // --- ENVELOPES SECTION ---
            Text(
              '📨 Envelopes',
              style: fontProvider.getTextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),

            ...individualEnvelopes.map(
              (env) => _EnvelopeTile(
                envelope: env,
                isEnabled: _envelopeEnabled[env.id] ?? true,
                overrideAmount: _envelopeOverrides[env.id],
                onToggle: () => _toggleEnvelope(env.id),
                onEdit: () => _editEnvelopeAmount(env),
              ),
            ),

            ...envelopesByBinder.entries.map((entry) {
              final binder = _allBinders.firstWhere((b) => b.id == entry.key);
              final envelopes = entry.value;
              final isBinderEnabled = _binderEnabled[binder.id] ?? true;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  _BinderHeader(
                    binder: binder,
                    isEnabled: isBinderEnabled,
                    onToggle: () => _toggleBinder(binder.id),
                  ),
                  ...envelopes.map(
                    (env) => Padding(
                      padding: const EdgeInsets.only(left: 24),
                      child: _EnvelopeTile(
                        envelope: env,
                        isEnabled: _envelopeEnabled[env.id] ?? true,
                        overrideAmount: _envelopeOverrides[env.id],
                        onToggle: () => _toggleEnvelope(env.id),
                        onEdit: () => _editEnvelopeAmount(env),
                      ),
                    ),
                  ),
                ],
              );
            }),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // --- TEMPORARY ENVELOPES SECTION ---
            Text(
              '💭 Temporary Envelopes',
              style: fontProvider.getTextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: _addTemporaryEnvelope,
              icon: const Icon(Icons.add),
              label: const Text('Add Temporary Envelope'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),

            ..._tempEnvelopes.map(
              (temp) => Card(
                margin: const EdgeInsets.only(top: 8),
                child: ListTile(
                  leading: const Icon(Icons.schedule),
                  title: Text(temp.name),
                  subtitle: Text(
                    '${currency.format(temp.amount)} on ${DateFormat('MMM d').format(temp.effectiveDate)}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeTempEnvelope(temp.id),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // --- ACTION BUTTON ---
            FilledButton(
              onPressed: _calculating ? null : _calculate,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 56),
                backgroundColor: theme.colorScheme.secondary,
              ),
              child: _calculating
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Calculate Projection',
                          style: fontProvider.getTextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.rocket_launch, color: Colors.white),
                      ],
                    ),
            ),

            // --- RESULTS SECTION ---
            if (_result != null) ...[
              const SizedBox(height: 32),
              const Divider(thickness: 2),
              const SizedBox(height: 16),

              Text(
                '📊 Projected Balances',
                style: fontProvider.getTextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Snapshot on ${DateFormat('MMM d, yyyy').format(_result!.projectionDate)}',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),

              // Total Available
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Available (Unallocated)',
                      style: TextStyle(fontSize: 16),
                    ),
                    Text(
                      currency.format(_result!.totalAvailable),
                      style: fontProvider.getTextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

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
                    title: Text(
                      accountProj.accountName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Text(
                      'Bank Balance: ${currency.format(accountProj.projectedBalance)}',
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Envelope',
                                    style: TextStyle(
                                      color: theme.colorScheme.outline,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text(
                                  'Proj. Balance',
                                  style: TextStyle(
                                    color: theme.colorScheme.outline,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(),
                            if (accountProj.envelopeProjections.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  'No linked envelopes',
                                  style: TextStyle(fontStyle: FontStyle.italic),
                                ),
                              ),

                            ...accountProj.envelopeProjections.map((env) {
                              final change =
                                  env.projectedAmount - env.currentAmount;
                              final isPositive = change >= 0;
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Row(
                                  children: [
                                    if (env.emoji != null) ...[
                                      Text(env.emoji!),
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
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Unallocated in Account:',
                                  style: TextStyle(fontStyle: FontStyle.italic),
                                ),
                                Text(
                                  currency.format(accountProj.availableAmount),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.secondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

// --- HELPER WIDGETS ---

class _DatePickerTile extends StatelessWidget {
  const _DatePickerTile({
    required this.label,
    required this.date,
    required this.onTap,
  });
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('MMM d').format(date),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnvelopeTile extends StatelessWidget {
  const _EnvelopeTile({
    required this.envelope,
    required this.isEnabled,
    required this.onToggle,
    required this.onEdit,
    this.overrideAmount,
  });
  final Envelope envelope;
  final bool isEnabled;
  final double? overrideAmount;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '£');
    final displayAmount = overrideAmount ?? envelope.currentAmount;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Checkbox(value: isEnabled, onChanged: (_) => onToggle()),
        title: Row(
          children: [
            if (envelope.emoji != null)
              Text(envelope.emoji!, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                envelope.name,
                style: TextStyle(
                  decoration: isEnabled ? null : TextDecoration.lineThrough,
                ),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currency.format(displayAmount),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: overrideAmount != null ? Colors.orange : null,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: onEdit,
            ),
          ],
        ),
      ),
    );
  }
}

class _BinderHeader extends StatelessWidget {
  const _BinderHeader({
    required this.binder,
    required this.isEnabled,
    required this.onToggle,
  });
  final EnvelopeGroup binder;
  final bool isEnabled;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final binderColor = theme.colorScheme.secondary;
    return Card(
      color: binderColor.withValues(alpha: 0.1),
      child: ListTile(
        leading: Checkbox(
          value: isEnabled,
          onChanged: (_) => onToggle(),
          activeColor: binderColor,
        ),
        title: Row(
          children: [
            if (binder.emoji != null)
              Text(binder.emoji!, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              binder.name,
              style: TextStyle(fontWeight: FontWeight.bold, color: binderColor),
            ),
          ],
        ),
        subtitle: const Text('Toggle all envelopes'),
      ),
    );
  }
}
