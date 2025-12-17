// lib/widgets/budget/projection_tool.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/account.dart';
import '../../models/envelope.dart';
import '../../models/scheduled_payment.dart';
import '../../models/pay_day_settings.dart';
import '../../models/projection.dart';
import '../../services/account_repo.dart';
import '../../services/envelope_repo.dart';
import '../../services/group_repo.dart';
import '../../services/projection_service.dart';
import '../../providers/font_provider.dart';
import 'scenario_editor_modal.dart';

class ProjectionTool extends StatefulWidget {
  const ProjectionTool({
    super.key,
    required this.accountRepo,
    required this.envelopeRepo,
    this.initialDate, // NEW: Accept an initial date
  });

  final AccountRepo accountRepo;
  final EnvelopeRepo envelopeRepo;
  final DateTime? initialDate; // NEW

  @override
  State<ProjectionTool> createState() => _ProjectionToolState();
}

class _ProjectionToolState extends State<ProjectionTool> {
  late DateTime _selectedDate; // CHANGED: Now initialized in initState
  DateTime? _nextPayDate;
  final _payAmountController = TextEditingController();
  String _payFrequency = 'biweekly';

  bool _calculating = false;
  ProjectionResult? _result;
  PayDaySettings? _paySettings;

  @override
  void initState() {
    super.initState();
    // NEW: Use the passed initialDate if available, otherwise default to 30 days
    _selectedDate =
        widget.initialDate ?? DateTime.now().add(const Duration(days: 30));
    _loadPaySettings();
  }

  @override
  void dispose() {
    _payAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadPaySettings() async {
    final userId = widget.envelopeRepo.currentUserId;
    final doc = await widget.envelopeRepo.db
        .collection('users')
        .doc(userId)
        .collection('payDaySettings')
        .doc('settings')
        .get();

    if (doc.exists) {
      final settings = PayDaySettings.fromFirestore(doc);
      if (mounted) {
        setState(() {
          _paySettings = settings;
          _payAmountController.text =
              settings.lastPayAmount?.toStringAsFixed(2) ?? '0.00';
          _payFrequency = settings.payFrequency;
          _nextPayDate = settings.lastPayDate ?? DateTime.now();
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _paySettings = PayDaySettings(userId: userId);
          _payAmountController.text = '0.00';
          _nextPayDate = DateTime.now();
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      helpText: 'Select target date',
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickNextPayDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextPayDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      helpText: 'When is your next pay day?',
    );
    if (picked != null) {
      setState(() => _nextPayDate = picked);
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

    if (_nextPayDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your next pay date')),
      );
      return;
    }

    setState(() => _calculating = true);

    try {
      final List<Account> accounts = await widget.accountRepo
          .accountsStream()
          .first;
      final List<Envelope> envelopes = await widget.envelopeRepo
          .envelopesStream()
          .first;

      final paymentsSnapshot = await widget.envelopeRepo.db
          .collection('users')
          .doc(widget.envelopeRepo.currentUserId)
          .collection('scheduledPayments')
          .get();

      final scheduledPayments = paymentsSnapshot.docs
          .map((doc) => ScheduledPayment.fromFirestore(doc))
          .toList();

      final customSettings = PayDaySettings(
        userId: widget.envelopeRepo.currentUserId,
        lastPayAmount: payAmount,
        payFrequency: _payFrequency,
        payDayOfMonth: _paySettings?.payDayOfMonth ?? _nextPayDate!.day,
        lastPayDate: _nextPayDate!,
        defaultAccountId: _paySettings?.defaultAccountId,
      );

      final result = await ProjectionService.calculateProjection(
        targetDate: _selectedDate,
        accounts: accounts,
        envelopes: envelopes,
        scheduledPayments: scheduledPayments,
        paySettings: customSettings,
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
        ).showSnackBar(SnackBar(content: Text('Error calculating: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.secondary.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 28,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Future Projection',
                  style: fontProvider.getTextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Text(
            'Target date',
            style: fontProvider.getTextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickDate,
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
                  Icon(Icons.calendar_today, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      DateFormat('MMMM d, yyyy').format(_selectedDate),
                      style: fontProvider.getTextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Next pay date',
            style: fontProvider.getTextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickNextPayDate,
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
                  Icon(Icons.event_available, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _nextPayDate != null
                          ? DateFormat('MMMM d, yyyy').format(_nextPayDate!)
                          : 'Select next pay date',
                      style: fontProvider.getTextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _nextPayDate != null
                            ? null
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Pay amount',
            style: fontProvider.getTextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _payAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: fontProvider.getTextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              prefixText: '£ ',
              prefixStyle: fontProvider.getTextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: theme.colorScheme.surface,
            ),
            onTap: () {
              _payAmountController.selection = TextSelection(
                baseOffset: 0,
                extentOffset: _payAmountController.text.length,
              );
            },
          ),
          const SizedBox(height: 16),

          Text(
            'Pay frequency',
            style: fontProvider.getTextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
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
                      style: fontProvider.getTextStyle(fontSize: 18),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'biweekly',
                    child: Text(
                      'Biweekly',
                      style: fontProvider.getTextStyle(fontSize: 18),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'monthly',
                    child: Text(
                      'Monthly',
                      style: fontProvider.getTextStyle(fontSize: 18),
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
          const SizedBox(height: 24),

          FilledButton(
            onPressed: _calculating ? null : _calculate,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: theme.colorScheme.secondary,
            ),
            child: _calculating
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
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

          if (_result != null) ...[
            const SizedBox(height: 32),
            Divider(color: theme.colorScheme.secondary),
            const SizedBox(height: 16),

            Row(
              children: [
                Icon(
                  Icons.bar_chart,
                  color: theme.colorScheme.secondary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Results',
                  style: fontProvider.getTextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Text(
              'On ${DateFormat('MMMM d, yyyy').format(_selectedDate)}:',
              style: fontProvider.getTextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),

            ..._result!.accountProjections.values.map((projection) {
              final currency = NumberFormat.currency(symbol: '£');

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      projection.accountName,
                      style: fontProvider.getTextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Balance:',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                        Text(
                          currency.format(projection.projectedBalance),
                          style: fontProvider.getTextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Available:',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                        Text(
                          '${currency.format(projection.availableAmount)} ✨',
                          style: fontProvider.getTextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 16),

            OutlinedButton.icon(
              onPressed: () async {
                final paySettings =
                    _paySettings ??
                    PayDaySettings(userId: widget.envelopeRepo.currentUserId);

                if (!mounted) return;

                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ScenarioEditorModal(
                      accountRepo: widget.accountRepo,
                      envelopeRepo: widget.envelopeRepo,
                      groupRepo: GroupRepo(
                        widget.envelopeRepo.db,
                        widget.envelopeRepo,
                      ),
                      initialStartDate: DateTime.now(),
                      initialEndDate: _selectedDate,
                      paySettings: paySettings,
                    ),
                    fullscreenDialog: true,
                  ),
                );
              },
              icon: const Icon(Icons.edit),
              label: Text(
                'Edit Scenario',
                style: fontProvider.getTextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                minimumSize: const Size(double.infinity, 48),
                side: BorderSide(color: theme.colorScheme.secondary, width: 2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
