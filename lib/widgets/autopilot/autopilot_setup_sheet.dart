// lib/widgets/autopilot/autopilot_setup_sheet.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/scheduled_payment.dart';
import '../../models/envelope.dart';
import '../../models/account.dart';
import '../../services/envelope_repo.dart';
import '../../services/account_repo.dart';
import '../../services/scheduled_payment_repo.dart';
import '../../providers/locale_provider.dart';

enum SourceType { envelope, account }

class AutopilotSetupSheet extends StatefulWidget {
  final String sourceId;
  final SourceType sourceType;
  final Function(ScheduledPayment) onComplete;
  final ScheduledPayment? existingAutopilot; // For editing

  const AutopilotSetupSheet({
    super.key,
    required this.sourceId,
    required this.sourceType,
    required this.onComplete,
    this.existingAutopilot,
  });

  @override
  State<AutopilotSetupSheet> createState() => _AutopilotSetupSheetState();
}

class _AutopilotSetupSheetState extends State<AutopilotSetupSheet> {
  late AutopilotType _selectedType;
  String? _destinationId;
  final _amountController = TextEditingController();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  PaymentFrequencyUnit _frequencyUnit = PaymentFrequencyUnit.months;
  int _frequencyValue = 1;
  int _dayOfMonth = 1;
  bool _autoExecute = false;

  String _selectedColorName = 'Blusher';
  int _selectedColorValue = 0xFFF8BBD0;

  List<Envelope> _availableEnvelopes = [];
  List<Account> _availableAccounts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.sourceType == SourceType.envelope
        ? AutopilotType.spend
        : AutopilotType.accountToEnvelope;

    // Pre-fill for editing
    if (widget.existingAutopilot != null) {
      final ap = widget.existingAutopilot!;
      _selectedType = ap.autopilotType ?? AutopilotType.spend;
      _destinationId = ap.destinationId;
      _amountController.text = ap.amount.toString();
      _nameController.text = ap.name;
      _descriptionController.text = ap.description ?? '';
      _frequencyUnit = ap.frequencyUnit;
      _frequencyValue = ap.frequencyValue;
      _autoExecute = ap.isAutomatic;
      _selectedColorName = ap.colorName;
      _selectedColorValue = ap.colorValue;
    }

    _loadData();
  }

  Future<void> _loadData() async {
    final envelopeRepo = context.read<EnvelopeRepo>();
    final accountRepo = context.read<AccountRepo>();

    // Only show current user's envelopes for autopilot configuration
    final allEnvelopes = await envelopeRepo.envelopesStream(showPartnerEnvelopes: false).first;
    final envelopes = allEnvelopes
        .where((e) => e.userId == envelopeRepo.currentUserId)
        .toList();
    final accounts = await accountRepo.getAllAccounts();

    setState(() {
      // For spend mode, include the current envelope itself
      // For transfer modes, exclude it
      _availableEnvelopes = envelopes;
      _availableAccounts = accounts.where((a) => a.id != widget.sourceId).toList();
      _loading = false;

      // Pre-select the current envelope for spend mode
      if (_selectedType == AutopilotType.spend && widget.sourceType == SourceType.envelope) {
        _destinationId = widget.sourceId;
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<LocaleProvider>();

    if (_loading) {
      return Container(
        padding: const EdgeInsets.all(24),
        height: 200,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.autorenew, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  widget.existingAutopilot == null ? 'Set Up Autopilot' : 'Edit Autopilot',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
                hintText: 'e.g., Monthly Savings Transfer',
              ),
            ),

            const SizedBox(height: 16),

            // Type selection
            DropdownButtonFormField<AutopilotType>(
              initialValue: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Autopilot Type',
                border: OutlineInputBorder(),
              ),
              items: _buildTypeOptions(),
              onChanged: (type) {
                setState(() {
                  _selectedType = type!;
                  // Pre-select current envelope for spend mode
                  if (type == AutopilotType.spend && widget.sourceType == SourceType.envelope) {
                    _destinationId = widget.sourceId;
                  } else {
                    _destinationId = null; // Reset destination for transfer modes
                  }
                });
              },
            ),

            const SizedBox(height: 16),

            // Destination selector - always shown
            _buildDestinationPicker(locale),
            const SizedBox(height: 16),

            // Amount
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: locale.currencySymbol,
                border: const OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // Frequency
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _frequencyValue,
                    decoration: const InputDecoration(
                      labelText: 'Every',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(12, (i) => i + 1).map((value) {
                      return DropdownMenuItem(
                        value: value,
                        child: Text('$value'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _frequencyValue = value!);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<PaymentFrequencyUnit>(
                    initialValue: _frequencyUnit,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: PaymentFrequencyUnit.values.map((unit) {
                      return DropdownMenuItem(
                        value: unit,
                        child: Text(_formatFrequencyUnit(unit)),
                      );
                    }).toList(),
                    onChanged: (unit) {
                      setState(() => _frequencyUnit = unit!);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Day of month (for monthly frequency)
            if (_frequencyUnit == PaymentFrequencyUnit.months) ...[
              DropdownButtonFormField<int>(
                initialValue: _dayOfMonth,
                decoration: const InputDecoration(
                  labelText: 'Day of Month',
                  border: OutlineInputBorder(),
                ),
                items: List.generate(28, (i) => i + 1).map((day) {
                  return DropdownMenuItem(
                    value: day,
                    child: Text('$day${_getDaySuffix(day)}'),
                  );
                }).toList(),
                onChanged: (day) {
                  setState(() => _dayOfMonth = day!);
                },
              ),
              const SizedBox(height: 16),
            ],

            // Description (optional)
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),

            const SizedBox(height: 16),

            // Auto-execute toggle
            SwitchListTile(
              title: const Text('Auto-execute'),
              subtitle: const Text('Automatically process on due date'),
              value: _autoExecute,
              onChanged: (enabled) {
                setState(() => _autoExecute = enabled);
              },
              contentPadding: EdgeInsets.zero,
            ),

            const SizedBox(height: 16),

            // Color picker
            _buildColorPicker(theme),

            const SizedBox(height: 24),

            // Save button
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
              ),
              child: const Text('Save Autopilot'),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  List<DropdownMenuItem<AutopilotType>> _buildTypeOptions() {
    final options = <DropdownMenuItem<AutopilotType>>[];

    if (widget.sourceType == SourceType.envelope) {
      options.addAll([
        const DropdownMenuItem(
          value: AutopilotType.spend,
          child: Text('Spend'),
        ),
        const DropdownMenuItem(
          value: AutopilotType.envelopeToAccount,
          child: Text('Transfer'),
        ),
        const DropdownMenuItem(
          value: AutopilotType.envelopeToEnvelope,
          child: Text('Transfer'),
        ),
      ]);
    } else if (widget.sourceType == SourceType.account) {
      options.addAll([
        const DropdownMenuItem(
          value: AutopilotType.accountToAccount,
          child: Text('Transfer'),
        ),
        const DropdownMenuItem(
          value: AutopilotType.accountToEnvelope,
          child: Text('Transfer'),
        ),
      ]);
    }

    return options;
  }

  Widget _buildDestinationPicker(LocaleProvider locale) {
    // Determine what to show based on autopilot type
    final isSpendMode = _selectedType == AutopilotType.spend;
    final needsEnvelope = _selectedType == AutopilotType.spend ||
                          _selectedType == AutopilotType.envelopeToEnvelope ||
                          _selectedType == AutopilotType.accountToEnvelope;
    final needsAccount = _selectedType == AutopilotType.envelopeToAccount ||
                         _selectedType == AutopilotType.accountToAccount;

    if (needsEnvelope) {
      // For spend mode, only show the current envelope (locked)
      // For transfer mode, show all envelopes except the current one
      final filteredEnvelopes = isSpendMode
          ? _availableEnvelopes.where((e) => e.id == widget.sourceId).toList()
          : _availableEnvelopes.where((e) => e.id != widget.sourceId).toList();

      return DropdownButtonFormField<String>(
        initialValue: _destinationId,
        decoration: const InputDecoration(
          labelText: 'Destination',
          border: OutlineInputBorder(),
        ),
        items: filteredEnvelopes.map((env) {
          return DropdownMenuItem(
            value: env.id,
            child: Row(
              children: [
                env.getIconWidget(Theme.of(context), size: 24),
                const SizedBox(width: 12),
                Expanded(child: Text(env.name)),
                Text(
                  locale.formatCurrency(env.currentAmount),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: isSpendMode ? null : (id) {
          setState(() => _destinationId = id);
        },
      );
    } else if (needsAccount) {
      return DropdownButtonFormField<String>(
        initialValue: _destinationId,
        decoration: const InputDecoration(
          labelText: 'Destination',
          border: OutlineInputBorder(),
        ),
        items: _availableAccounts.map((acc) {
          return DropdownMenuItem(
            value: acc.id,
            child: Row(
              children: [
                acc.getIconWidget(Theme.of(context), size: 24),
                const SizedBox(width: 12),
                Expanded(child: Text(acc.name)),
                Text(
                  locale.formatCurrency(acc.currentBalance),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: (id) {
          setState(() => _destinationId = id);
        },
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildColorPicker(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Color',
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: CalendarColors.colors.entries.map((entry) {
            final isSelected = entry.key == _selectedColorName;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedColorName = entry.key;
                  _selectedColorValue = entry.value;
                });
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Color(entry.value),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    width: 3,
                  ),
                ),
                child: isSelected
                    ? Icon(Icons.check, color: theme.colorScheme.onPrimary)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _formatFrequencyUnit(PaymentFrequencyUnit unit) {
    switch (unit) {
      case PaymentFrequencyUnit.days:
        return _frequencyValue == 1 ? 'day' : 'days';
      case PaymentFrequencyUnit.weeks:
        return _frequencyValue == 1 ? 'week' : 'weeks';
      case PaymentFrequencyUnit.months:
        return _frequencyValue == 1 ? 'month' : 'months';
      case PaymentFrequencyUnit.years:
        return _frequencyValue == 1 ? 'year' : 'years';
    }
  }

  String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  DateTime _calculateNextDueDate() {
    final now = DateTime.now();

    if (_frequencyUnit == PaymentFrequencyUnit.months) {
      var next = DateTime(now.year, now.month, _dayOfMonth);
      if (next.isBefore(now)) {
        next = DateTime(now.year, now.month + 1, _dayOfMonth);
      }
      return next;
    } else {
      // For other frequencies, start tomorrow
      return now.add(const Duration(days: 1));
    }
  }

  void _save() async {
    // Validation
    if (_nameController.text.trim().isEmpty) {
      _showError('Please enter a name');
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showError('Please enter a valid amount');
      return;
    }

    if (_destinationId == null) {
      _showError('Please select a destination');
      return;
    }

    final autopilot = ScheduledPayment(
      id: widget.existingAutopilot?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      userId: context.read<EnvelopeRepo>().currentUserId,
      sourceId: widget.sourceId,
      destinationId: _destinationId,
      autopilotType: _selectedType,
      envelopeId: null, // Legacy field, not used for autopilot
      groupId: null,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      amount: amount,
      startDate: _calculateNextDueDate(),
      frequencyValue: _frequencyValue,
      frequencyUnit: _frequencyUnit,
      colorName: _selectedColorName,
      colorValue: _selectedColorValue,
      isAutomatic: _autoExecute,
      createdAt: widget.existingAutopilot?.createdAt ?? DateTime.now(),
    );

    // Save to database
    final scheduledPaymentRepo = context.read<ScheduledPaymentRepo>();
    if (widget.existingAutopilot == null) {
      await scheduledPaymentRepo.createScheduledPayment(
        envelopeId: null,
        groupId: null,
        name: autopilot.name,
        description: autopilot.description,
        amount: autopilot.amount,
        startDate: autopilot.startDate,
        frequencyValue: autopilot.frequencyValue,
        frequencyUnit: autopilot.frequencyUnit,
        colorName: autopilot.colorName,
        colorValue: autopilot.colorValue,
        isAutomatic: autopilot.isAutomatic,
        paymentType: autopilot.paymentType,
        paymentEnvelopeId: autopilot.paymentEnvelopeId,
        autopilotType: autopilot.autopilotType,
        sourceId: autopilot.sourceId,
        destinationId: autopilot.destinationId,
      );
    } else {
      await scheduledPaymentRepo.updateScheduledPayment(
        id: autopilot.id,
        name: autopilot.name,
        description: autopilot.description,
        amount: autopilot.amount,
        startDate: autopilot.startDate,
        frequencyValue: autopilot.frequencyValue,
        frequencyUnit: autopilot.frequencyUnit,
        colorName: autopilot.colorName,
        colorValue: autopilot.colorValue,
        isAutomatic: autopilot.isAutomatic,
      );
    }

    widget.onComplete(autopilot);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }
}
