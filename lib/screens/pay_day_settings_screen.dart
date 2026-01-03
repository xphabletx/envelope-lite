// lib/screens/pay_day_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/pay_day_settings.dart';
import '../services/pay_day_settings_service.dart';
import '../providers/font_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/responsive_helper.dart';

class PayDaySettingsScreen extends StatefulWidget {
  const PayDaySettingsScreen({
    super.key,
    required this.service,
  });

  final PayDaySettingsService service;

  @override
  State<PayDaySettingsScreen> createState() => _PayDaySettingsScreenState();
}

class _PayDaySettingsScreenState extends State<PayDaySettingsScreen> {
  final _amountController = TextEditingController();
  String _frequency = 'monthly';
  DateTime? _nextPayDate;
  bool _isEnabled = false;
  bool _saving = false;
  bool _adjustForWeekends = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await widget.service.getPayDaySettings();
    if (settings != null && mounted) {
      setState(() {
        _isEnabled = settings.expectedPayAmount != null;
        _amountController.text = settings.expectedPayAmount?.toStringAsFixed(2) ?? '0.00';
        _frequency = settings.payFrequency;
        _nextPayDate = settings.nextPayDate;
        _adjustForWeekends = settings.adjustForWeekends;
      });
    }
  }

  Future<void> _saveSettings() async {
    if (_saving) return;

    final amount = double.tryParse(_amountController.text);

    if (_isEnabled && (amount == null || amount <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid pay amount')),
      );
      return;
    }

    if (_isEnabled && _nextPayDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your next pay date')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      if (_isEnabled && amount != null && _nextPayDate != null) {
        // Create/update pay day settings
        final settings = PayDaySettings(
          userId: widget.service.userId,
          expectedPayAmount: amount,
          payFrequency: _frequency,
          nextPayDate: _nextPayDate,
          payDayOfMonth: _nextPayDate!.day,
          payDayOfWeek: _nextPayDate!.weekday,
          adjustForWeekends: _adjustForWeekends,
        );

        await widget.service.updatePayDaySettings(settings);

        debugPrint('[PayDaySettings] ✅ Pay day settings saved (will appear in Time Machine and Calendar)');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pay day settings saved! 💰'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Disable pay day - delete settings only
        await widget.service.deletePayDaySettings();

        debugPrint('[PayDaySettings] ✅ Pay day settings deleted');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pay day tracking disabled')),
          );
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final currencySymbol = localeProvider.currencySymbol;
    final responsive = context.responsive;
    final isLandscape = responsive.isLandscape;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pay Day Settings',
          style: fontProvider.getTextStyle(
            fontSize: isLandscape ? 20 : 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: SingleChildScrollView(
        padding: context.responsive.safePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enable/Disable Switch
            Container(
              padding: EdgeInsets.all(isLandscape ? 12 : 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(isLandscape ? 8 : 12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: theme.colorScheme.primary,
                    size: isLandscape ? 20 : 24,
                  ),
                  SizedBox(width: isLandscape ? 12 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Track Pay Day',
                          style: fontProvider.getTextStyle(
                            fontSize: isLandscape ? 14 : 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: isLandscape ? 2 : 4),
                        Text(
                          'Add recurring pay to calendar & projections',
                          style: TextStyle(
                            fontSize: isLandscape ? 11 : 12,
                            color: theme.colorScheme.onPrimaryContainer
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isEnabled,
                    onChanged: (value) {
                      setState(() => _isEnabled = value);
                    },
                  ),
                ],
              ),
            ),

            if (_isEnabled) ...[
              SizedBox(height: isLandscape ? 20 : 32),

              // Pay Amount
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: fontProvider.getTextStyle(
                  fontSize: isLandscape ? 16 : 20,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  labelText: 'Take-home pay amount',
                  labelStyle: TextStyle(fontSize: isLandscape ? 12 : 14),
                  hintText: '0.00',
                  helperText: 'Your regular pay after taxes',
                  helperStyle: TextStyle(fontSize: isLandscape ? 11 : 12),
                  prefixText: '$currencySymbol ',
                  prefixStyle: fontProvider.getTextStyle(
                    fontSize: isLandscape ? 16 : 20,
                    fontWeight: FontWeight.bold,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(isLandscape ? 8 : 12),
                  ),
                ),
                onTap: () {
                  _amountController.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: _amountController.text.length,
                  );
                },
              ),

              SizedBox(height: isLandscape ? 16 : 24),

              // Pay Frequency
              DropdownButtonFormField<String>(
                initialValue: _frequency,
                decoration: InputDecoration(
                  labelText: 'Pay frequency',
                  labelStyle: TextStyle(fontSize: isLandscape ? 12 : 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(isLandscape ? 8 : 12),
                  ),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'weekly',
                    child: Text(
                      'Weekly (every 7 days)',
                      style: fontProvider.getTextStyle(fontSize: isLandscape ? 14 : 16),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'biweekly',
                    child: Text(
                      'Bi-weekly (every 14 days)',
                      style: fontProvider.getTextStyle(fontSize: isLandscape ? 14 : 16),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'fourweekly',
                    child: Text(
                      'Four-weekly (every 28 days)',
                      style: fontProvider.getTextStyle(fontSize: isLandscape ? 14 : 16),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'monthly',
                    child: Text(
                      'Monthly',
                      style: fontProvider.getTextStyle(fontSize: isLandscape ? 14 : 16),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _frequency = value);
                  }
                },
              ),

              SizedBox(height: isLandscape ? 16 : 24),

              // Next Pay Date
              OutlinedButton.icon(
                onPressed: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _nextPayDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    helpText: 'Select your next pay date',
                  );
                  if (pickedDate != null) {
                    setState(() => _nextPayDate = pickedDate);
                  }
                },
                icon: Icon(Icons.calendar_today, size: isLandscape ? 18 : 24),
                label: Text(
                  _nextPayDate == null
                      ? 'Select next pay date'
                      : 'Next pay: ${DateFormat.yMMMd().format(_nextPayDate!)}',
                  style: fontProvider.getTextStyle(fontSize: isLandscape ? 14 : 16),
                ),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.all(isLandscape ? 12 : 16),
                  minimumSize: Size(double.infinity, isLandscape ? 44 : 56),
                ),
              ),

              SizedBox(height: isLandscape ? 16 : 24),

              // Weekend Adjustment Toggle
              Container(
                padding: EdgeInsets.all(isLandscape ? 12 : 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(isLandscape ? 8 : 12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.weekend,
                          color: theme.colorScheme.primary,
                          size: isLandscape ? 20 : 24,
                        ),
                        SizedBox(width: isLandscape ? 8 : 12),
                        Expanded(
                          child: Text(
                            'Adjust for Weekends',
                            style: fontProvider.getTextStyle(
                              fontSize: isLandscape ? 14 : 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Switch(
                          value: _adjustForWeekends,
                          onChanged: (value) {
                            setState(() => _adjustForWeekends = value);
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: isLandscape ? 6 : 8),
                    Text(
                      'If your pay day falls on a weekend, move it to Friday',
                      style: TextStyle(
                        fontSize: isLandscape ? 12 : 14,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),

                    // Show preview if weekend adjustment would apply
                    if (_adjustForWeekends && _nextPayDate != null) ...[
                      SizedBox(height: isLandscape ? 8 : 12),
                      Builder(
                        builder: (context) {
                          final tempSettings = PayDaySettings(
                            userId: 'temp',
                            nextPayDate: _nextPayDate!,
                          );
                          final adjustedDate = tempSettings.adjustForWeekend(_nextPayDate!);

                          if (adjustedDate != _nextPayDate) {
                            return Container(
                              padding: EdgeInsets.all(isLandscape ? 8 : 12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(isLandscape ? 6 : 8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.blue.shade700,
                                    size: isLandscape ? 16 : 20,
                                  ),
                                  SizedBox(width: isLandscape ? 6 : 8),
                                  Expanded(
                                    child: Text(
                                      'Next pay day would be ${DateFormat('EEEE, MMM d').format(adjustedDate)} (moved from ${DateFormat('EEEE').format(_nextPayDate!)})',
                                      style: TextStyle(
                                        fontSize: isLandscape ? 11 : 13,
                                        color: Colors.blue.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ],
                ),
              ),

              if (_nextPayDate != null) ...[
                SizedBox(height: isLandscape ? 12 : 16),
                Container(
                  padding: EdgeInsets.all(isLandscape ? 8 : 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(isLandscape ? 6 : 8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: isLandscape ? 14 : 16,
                            color: theme.colorScheme.secondary,
                          ),
                          SizedBox(width: isLandscape ? 6 : 8),
                          Text(
                            'Pay Schedule Preview',
                            style: TextStyle(
                              fontSize: isLandscape ? 11 : 12,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isLandscape ? 6 : 8),
                      ..._generateUpcomingPayDates().map((date) => Padding(
                        padding: EdgeInsets.symmetric(vertical: isLandscape ? 1 : 2),
                        child: Text(
                          '• ${DateFormat.yMMMd().format(date)}',
                          style: TextStyle(
                            fontSize: isLandscape ? 11 : 12,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      )),
                    ],
                  ),
                ),
              ],
            ],

            SizedBox(height: isLandscape ? 20 : 32),

            // Info Card
            Container(
              padding: EdgeInsets.all(isLandscape ? 12 : 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(isLandscape ? 8 : 12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: isLandscape ? 16 : 20,
                        color: theme.colorScheme.primary,
                      ),
                      SizedBox(width: isLandscape ? 6 : 8),
                      Text(
                        'How it works',
                        style: fontProvider.getTextStyle(
                          fontSize: isLandscape ? 12 : 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isLandscape ? 8 : 12),
                  Text(
                    '• Your pay day appears as a recurring event in the calendar\n'
                    '• Used for budget projections in Time Machine\n'
                    '• Update anytime if your pay schedule changes\n'
                    '• Tap calendar events to mark when you receive pay',
                    style: TextStyle(
                      fontSize: isLandscape ? 11 : 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isLandscape ? 12 : 16),
          child: FilledButton(
            onPressed: _saving ? null : _saveSettings,
            style: FilledButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: isLandscape ? 12 : 16),
              minimumSize: Size(double.infinity, isLandscape ? 44 : 56),
            ),
            child: _saving
                ? SizedBox(
                    width: isLandscape ? 16 : 20,
                    height: isLandscape ? 16 : 20,
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'Save Settings',
                    style: fontProvider.getTextStyle(
                      fontSize: isLandscape ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  List<DateTime> _generateUpcomingPayDates() {
    if (_nextPayDate == null) return [];

    final dates = <DateTime>[];
    var currentDate = _nextPayDate!;

    // Create temp settings object to access weekend adjustment logic
    final tempSettings = PayDaySettings(
      userId: 'temp',
      nextPayDate: currentDate,
      adjustForWeekends: _adjustForWeekends,
    );

    for (int i = 0; i < 3; i++) {
      // Apply weekend adjustment if enabled
      final adjustedDate = _adjustForWeekends
          ? tempSettings.adjustForWeekend(currentDate)
          : currentDate;

      dates.add(adjustedDate);
      currentDate = PayDaySettings.calculateNextPayDate(currentDate, _frequency);
    }

    return dates;
  }
}
