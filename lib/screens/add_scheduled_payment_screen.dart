// lib/screens/calendar/add_scheduled_payment_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/envelope.dart';
import '../../models/envelope_group.dart';
import '../../models/scheduled_payment.dart';
import '../../services/envelope_repo.dart';
import '../../services/scheduled_payment_repo.dart';
import '../../providers/font_provider.dart';
import '../../providers/locale_provider.dart';
import '../../data/material_icons_database.dart';
import '../../widgets/calculator_widget.dart';

class AddScheduledPaymentScreen extends StatefulWidget {
  const AddScheduledPaymentScreen({
    super.key,
    required this.repo,
    this.preselectedEnvelopeId,
    this.paymentToEdit, // NEW: Optional payment to edit
  });

  final EnvelopeRepo repo;
  final String? preselectedEnvelopeId;
  final ScheduledPayment? paymentToEdit; // NEW

  @override
  State<AddScheduledPaymentScreen> createState() =>
      _AddScheduledPaymentScreenState();
}

class _AddScheduledPaymentScreenState extends State<AddScheduledPaymentScreen> {
  late final ScheduledPaymentRepo _paymentRepo;

  String? _selectedEnvelopeId;
  String? _selectedGroupId;
  final _descriptionCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  DateTime? _selectedDate;
  int _frequencyValue = 1;
  PaymentFrequencyUnit _frequencyUnit = PaymentFrequencyUnit.months;
  String _selectedColorName = 'Blusher';
  bool _isAutomatic = false;
  bool _saving = false;
  bool _isEditing = false;
  ScheduledPaymentType _paymentType = ScheduledPaymentType.fixedAmount;

  DateTime _focusedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _paymentRepo = ScheduledPaymentRepo(widget.repo.currentUserId);

    // Initialize logic
    if (widget.paymentToEdit != null) {
      _isEditing = true;
      final p = widget.paymentToEdit!;
      _selectedEnvelopeId = p.envelopeId;
      _selectedGroupId = p.groupId;
      _descriptionCtrl.text = p.description ?? '';
      _amountCtrl.text = p.amount
          .toString(); // Removed toStringAsFixed to prevent trailing zeros if int
      _selectedDate = p.nextDueDate; // Use next due date or startDate
      _focusedDay = p.nextDueDate;
      _frequencyValue = p.frequencyValue;
      _frequencyUnit = p.frequencyUnit;
      _selectedColorName = p.colorName;
      _isAutomatic = p.isAutomatic;
      _paymentType = p.paymentType;
    } else if (widget.preselectedEnvelopeId != null) {
      _selectedEnvelopeId = widget.preselectedEnvelopeId;
    }
  }

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Schedule?'),
        content: const Text(
          'Are you sure you want to delete this scheduled payment?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _saving = true);
      try {
        await _paymentRepo.deleteScheduledPayment(widget.paymentToEdit!.id);
        if (!mounted) return;
        Navigator.pop(context); // Close screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scheduled payment deleted')),
        );
      } catch (e) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _save() async {
    if (_selectedEnvelopeId == null && _selectedGroupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an envelope or group')),
      );
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a date')));
      return;
    }

    // Validate amount (only for fixed amount type)
    double amount = 0.0;
    if (_paymentType == ScheduledPaymentType.fixedAmount) {
      final amountText = _amountCtrl.text.trim();
      if (amountText.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please enter an amount')));
        return;
      }

      final parsedAmount = double.tryParse(amountText);
      if (parsedAmount == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invalid amount')));
        return;
      }
      amount = parsedAmount;
    }

    setState(() => _saving = true);

    try {
      // Determine display name (Envelope name or Group name)
      String name = 'Payment';
      if (_selectedEnvelopeId != null) {
        // We need to fetch the name. Since this is async inside sync flow,
        // ideally we grab it from snapshot or cache.
        // For editing, we might keep old name or refresh it.
        // Quick fetch:
        final envelopes = await widget.repo.envelopesStream().first;
        final envelope = envelopes.firstWhere(
          (e) => e.id == _selectedEnvelopeId,
          orElse: () => envelopes.first, // Fallback
        );
        name = envelope.name;
      } else if (_selectedGroupId != null) {
        final groups = await widget.repo.groupsStream.first;
        final group = groups.firstWhere(
          (g) => g.id == _selectedGroupId,
          orElse: () => groups.first,
        );
        name = group.name;
      }

      if (_isEditing) {
        // UPDATE EXISTING
        await _paymentRepo.updateScheduledPayment(
          id: widget.paymentToEdit!.id,
          name: name,
          description: _descriptionCtrl.text.trim().isEmpty
              ? null
              : _descriptionCtrl.text.trim(),
          amount: amount,
          startDate: _selectedDate, // Update the date
          frequencyValue: _frequencyValue,
          frequencyUnit: _frequencyUnit,
          colorName: _selectedColorName,
          colorValue: CalendarColors.getColorValue(_selectedColorName),
          isAutomatic: _isAutomatic,
          paymentType: _paymentType,
        );
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Payment updated!')));
      } else {
        // CREATE NEW
        await _paymentRepo.createScheduledPayment(
          envelopeId: _selectedEnvelopeId,
          groupId: _selectedGroupId,
          name: name,
          description: _descriptionCtrl.text.trim().isEmpty
              ? null
              : _descriptionCtrl.text.trim(),
          amount: amount,
          startDate: _selectedDate!,
          frequencyValue: _frequencyValue,
          frequencyUnit: _frequencyUnit,
          colorName: _selectedColorName,
          colorValue: CalendarColors.getColorValue(_selectedColorName),
          isAutomatic: _isAutomatic,
          paymentType: _paymentType,
        );
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scheduled payment created!')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  String get _frequencyString {
    final unit = _frequencyValue == 1
        ? _frequencyUnit.name.substring(0, _frequencyUnit.name.length - 1)
        : _frequencyUnit.name;
    return _frequencyValue == 1
        ? 'Every $unit'
        : 'Every $_frequencyValue $unit';
  }

  Widget _buildGroupIcon(EnvelopeGroup group, ThemeData theme) {
    // Use new icon system if available
    if (group.iconType != null && group.iconValue != null) {
      switch (group.iconType) {
        case 'emoji':
          return Text(
            group.iconValue!,
            style: const TextStyle(fontSize: 20),
          );

        case 'materialIcon':
          final iconData = materialIconsDatabase[group.iconValue!]?['icon'] as IconData? ?? Icons.folder;
          return Icon(
            iconData,
            size: 20,
            color: group.iconColor != null
                ? Color(group.iconColor!)
                : theme.colorScheme.primary,
          );

        case 'companyLogo':
          final logoUrl =
              'https://www.google.com/s2/favicons?sz=128&domain=${group.iconValue}';
          return ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CachedNetworkImage(
              imageUrl: logoUrl,
              width: 20,
              height: 20,
              fit: BoxFit.contain,
              placeholder: (context, url) => const SizedBox(
                width: 20,
                height: 20,
                child: Center(
                  child: SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(strokeWidth: 1),
                  ),
                ),
              ),
              errorWidget: (context, url, error) {
                return group.getIconWidget(theme, size: 20);
              },
            ),
          );

        default:
          return group.getIconWidget(theme, size: 20);
      }
    }

    // Fallback to emoji
    return group.getIconWidget(theme, size: 20);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final currencySymbol = localeProvider.currencySymbol;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: theme.colorScheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: FittedBox(
          child: Text(
            _isEditing ? 'Edit Schedule' : 'Schedule Payment',
            style: fontProvider.getTextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _saving ? null : _delete,
              tooltip: 'Delete Schedule',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What to pay?',
              style: fontProvider.getTextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<Envelope>>(
              stream: widget.repo.envelopesStream(),
              builder: (context, envSnapshot) {
                return StreamBuilder<List<EnvelopeGroup>>(
                  stream: widget.repo.groupsStream,
                  builder: (context, groupSnapshot) {
                    final envelopes = envSnapshot.data ?? [];
                    final groups = groupSnapshot.data ?? [];

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      child: DropdownButton<String>(
                        isExpanded: true,
                        underline: const SizedBox(),
                        hint: Text(
                          'Select envelope or group',
                          style: fontProvider.getTextStyle(fontSize: 18),
                        ),
                        // Determine value based on IDs
                        value: _selectedEnvelopeId != null
                            ? 'env_$_selectedEnvelopeId'
                            : (_selectedGroupId != null
                                  ? 'grp_$_selectedGroupId'
                                  : null),
                        items: [
                          if (envelopes.isNotEmpty)
                            DropdownMenuItem(
                              enabled: false,
                              child: Text(
                                'ENVELOPES',
                                style: fontProvider.getTextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ...envelopes.map(
                            (e) => DropdownMenuItem(
                              value: 'env_${e.id}',
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: e.getIconWidget(theme, size: 24),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      e.name,
                                      style: fontProvider.getTextStyle(
                                        fontSize: 18,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (groups.isNotEmpty)
                            DropdownMenuItem(
                              enabled: false,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'GROUPS',
                                  style: fontProvider.getTextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                          ...groups.map(
                            (g) => DropdownMenuItem(
                              value: 'grp_${g.id}',
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: Center(
                                      child: _buildGroupIcon(g, theme),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      g.name,
                                      style: fontProvider.getTextStyle(
                                        fontSize: 18,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              if (value.startsWith('env_')) {
                                _selectedEnvelopeId = value.substring(4);
                                _selectedGroupId = null;
                              } else {
                                _selectedGroupId = value.substring(4);
                                _selectedEnvelopeId = null;
                              }
                            });
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 24),

            Text(
              'Description (optional)',
              style: fontProvider.getTextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionCtrl,
              style: fontProvider.getTextStyle(fontSize: 18),
              decoration: InputDecoration(
                hintText: 'e.g., Monthly rent payment',
                hintStyle: fontProvider.getTextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.colorScheme.surface,
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Amount',
              style: fontProvider.getTextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),

            // Payment Type Toggle (only show for envelope payments)
            if (_selectedEnvelopeId != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet, color: theme.colorScheme.secondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Use envelope balance',
                            style: fontProvider.getTextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Deduct whatever is in the envelope at payment time',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _paymentType == ScheduledPaymentType.envelopeBalance,
                      onChanged: (value) {
                        setState(() {
                          _paymentType = value
                              ? ScheduledPaymentType.envelopeBalance
                              : ScheduledPaymentType.fixedAmount;
                        });
                      },
                      activeThumbColor: theme.colorScheme.secondary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Amount field (only show for fixed amount type)
            if (_paymentType == ScheduledPaymentType.fixedAmount)
              TextField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: '0.00',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 16, right: 8),
                    child: Center(
                      widthFactor: 1.0,
                      child: Text(
                        currencySymbol,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                    ),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calculate),
                    onPressed: () async {
                      final result = await showDialog<double>(
                        context: context,
                        barrierDismissible: true,
                        barrierColor: Colors.black54,
                        builder: (context) => Stack(
                          children: const [
                            CalculatorWidget(),
                          ],
                        ),
                      );
                      if (result != null && mounted) {
                        setState(() {
                          _amountCtrl.text = result.toStringAsFixed(2);
                        });
                      }
                    },
                    tooltip: 'Open Calculator',
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: theme.colorScheme.secondary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'The entire envelope balance will be deducted on the payment date',
                        style: fontProvider.getTextStyle(
                          fontSize: 16,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            Text(
              _isEditing ? 'Next Due Date' : 'When?',
              style: fontProvider.getTextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TableCalendar(
                firstDay: DateTime.now().subtract(const Duration(days: 365)),
                lastDay: DateTime.now().add(const Duration(days: 365 * 2)),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
                calendarFormat: CalendarFormat.month,
                startingDayOfWeek: StartingDayOfWeek.monday,
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: fontProvider.getTextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                calendarStyle: CalendarStyle(
                  selectedDecoration: BoxDecoration(
                    color: theme.colorScheme.secondary,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  defaultTextStyle: fontProvider.getTextStyle(),
                  weekendTextStyle: fontProvider.getTextStyle(),
                ),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDate = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'How often?',
              style: fontProvider.getTextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'Every',
                        style: fontProvider.getTextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: fontProvider.getTextStyle(fontSize: 18),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                            ),
                          ),
                          controller: TextEditingController(
                            text: _frequencyValue.toString(),
                          ),
                          onChanged: (value) {
                            final num = int.tryParse(value);
                            if (num != null && num > 0) {
                              setState(() => _frequencyValue = num);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButton<PaymentFrequencyUnit>(
                          isExpanded: true,
                          value: _frequencyUnit,
                          items: PaymentFrequencyUnit.values.map((unit) {
                            return DropdownMenuItem(
                              value: unit,
                              child: Text(
                                unit.name,
                                style: fontProvider.getTextStyle(fontSize: 18),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _frequencyUnit = value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _frequencyString,
                    style: fontProvider
                        .getTextStyle(
                          fontSize: 18,
                          color: theme.colorScheme.secondary,
                        )
                        .copyWith(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Color',
              style: fontProvider.getTextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: CalendarColors.colorNames.map((colorName) {
                final isSelected = _selectedColorName == colorName;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColorName = colorName),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Color(CalendarColors.getColorValue(colorName)),
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(
                                  color: theme.colorScheme.primary,
                                  width: 3,
                                )
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 70,
                        child: Text(
                          colorName,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.autorenew, color: theme.colorScheme.secondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Auto-execute',
                          style: fontProvider.getTextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Automatically process on due date',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isAutomatic,
                    onChanged: (value) => setState(() => _isAutomatic = value),
                    activeThumbColor: theme.colorScheme.secondary,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : Text(
                        _isEditing ? 'Update Payment' : 'Save Payment',
                        style: fontProvider.getTextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
