// lib/widgets/insight_tile.dart
// 👁️‍🗨️ Insight - Unified financial planning tile
// Combines Horizon, Autopilot, and Cash Flow into one intelligent interface

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/insight_data.dart';
import '../models/pay_day_settings.dart';
import '../services/pay_day_settings_service.dart';
import '../providers/font_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/calculator_helper.dart';
import 'common/smart_text_field.dart';

class InsightTile extends StatefulWidget {
  final String userId;
  final Function(InsightData) onInsightChanged;
  final InsightData? initialData;
  final bool initiallyExpanded;

  const InsightTile({
    super.key,
    required this.userId,
    required this.onInsightChanged,
    this.initialData,
    this.initiallyExpanded = false,
  });

  @override
  State<InsightTile> createState() => _InsightTileState();
}

class _InsightTileState extends State<InsightTile> {
  late InsightData _data;
  bool _isExpanded = false;
  PayDaySettings? _payDaySettings;
  bool _isLoadingPayDay = true;
  bool _showManualOverride = false;

  // Controllers
  late TextEditingController _horizonAmountCtrl;
  late TextEditingController _autopilotAmountCtrl;
  late TextEditingController _manualCashFlowCtrl;

  // Focus nodes
  final _horizonAmountFocus = FocusNode();
  final _autopilotAmountFocus = FocusNode();
  final _manualCashFlowFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _data = widget.initialData ?? InsightData();

    // Initialize controllers
    _horizonAmountCtrl = TextEditingController(
      text: _data.horizonAmount?.toString() ?? '',
    );
    _autopilotAmountCtrl = TextEditingController(
      text: _data.autopilotAmount?.toString() ?? '',
    );
    _manualCashFlowCtrl = TextEditingController(
      text: _data.manualCashFlowOverride?.toString() ?? '',
    );

    _showManualOverride = _data.isManualOverride;

    _loadPayDaySettings();

    // Add listeners to recalculate on changes
    _horizonAmountCtrl.addListener(_recalculate);
    _autopilotAmountCtrl.addListener(_recalculate);
    _manualCashFlowCtrl.addListener(_updateManualOverride);
  }

  Future<void> _loadPayDaySettings() async {
    try {
      final service = PayDaySettingsService(null, widget.userId);
      final settings = await service.getSettings();
      if (mounted) {
        setState(() {
          _payDaySettings = settings;
          _isLoadingPayDay = false;
        });
        _recalculate(); // Recalculate with loaded settings
      }
    } catch (e) {
      debugPrint('Error loading Pay Day settings: $e');
      if (mounted) {
        setState(() => _isLoadingPayDay = false);
      }
    }
  }

  void _recalculate() {
    if (!mounted) return;

    final horizonAmount = double.tryParse(_horizonAmountCtrl.text);
    final autopilotAmount = double.tryParse(_autopilotAmountCtrl.text);

    // Update amounts in data
    _data = _data.copyWith(
      horizonAmount: horizonAmount,
      autopilotAmount: autopilotAmount,
    );

    // Calculate cash flow if we have pay day settings
    if (_payDaySettings != null && (horizonAmount != null || autopilotAmount != null)) {
      final calculations = _calculateCashFlow(
        horizonAmount: horizonAmount,
        horizonDate: _data.horizonDate,
        autopilotAmount: autopilotAmount,
        autopilotFrequency: _data.autopilotFrequency,
      );

      setState(() {
        _data = _data.copyWith(
          calculatedCashFlow: calculations['cashFlow'],
          payPeriodsToHorizon: calculations['horizonPeriods'],
          payPeriodsToAutopilot: calculations['autopilotPeriods'],
          percentageOfIncome: calculations['percentage'],
          availableIncome: calculations['available'],
          isAffordable: calculations['affordable'],
          warningMessage: calculations['warning'],
        );
      });
    } else {
      setState(() {
        _data = _data.copyWith(
          calculatedCashFlow: 0.0,
          payPeriodsToHorizon: null,
          payPeriodsToAutopilot: null,
          percentageOfIncome: null,
          isAffordable: true,
          warningMessage: null,
        );
      });
    }

    widget.onInsightChanged(_data);
  }

  Map<String, dynamic> _calculateCashFlow({
    double? horizonAmount,
    DateTime? horizonDate,
    double? autopilotAmount,
    String? autopilotFrequency,
  }) {
    if (_payDaySettings == null) {
      return {
        'cashFlow': 0.0,
        'horizonPeriods': null,
        'autopilotPeriods': null,
        'percentage': null,
        'available': null,
        'affordable': true,
        'warning': null,
      };
    }

    double totalCashFlow = 0.0;
    int? horizonPeriods;
    int? autopilotPeriods;

    final now = DateTime.now();
    final nextPayDate = _payDaySettings!.nextPayDate ?? now;

    // Calculate Horizon cash flow
    if (horizonAmount != null && horizonAmount > 0) {
      if (horizonDate != null) {
        // Calculate pay periods until target date
        horizonPeriods = _calculatePayPeriods(nextPayDate, horizonDate);
        if (horizonPeriods > 0) {
          totalCashFlow += horizonAmount / horizonPeriods.toDouble();
        } else {
          // Target date is before next pay day - need full amount now
          totalCashFlow += horizonAmount;
        }
      } else {
        // No date set - can't calculate periods, just note the amount
        horizonPeriods = null;
      }
    }

    // Calculate Autopilot cash flow
    if (autopilotAmount != null && autopilotAmount > 0) {
      // For autopilot, we need to ensure enough is saved before the bill is due
      // Estimate based on frequency
      final periodsPerAutopilot = _getPayPeriodsPerAutopilot(
        _payDaySettings!.payFrequency,
        autopilotFrequency ?? 'monthly',
      );

      if (periodsPerAutopilot > 0) {
        autopilotPeriods = periodsPerAutopilot;
        totalCashFlow += autopilotAmount / periodsPerAutopilot.toDouble();
      }
    }

    // Calculate percentage of income
    double? percentage;
    double? available;
    bool affordable = true;
    String? warning;

    final expectedPay = _payDaySettings!.expectedPayAmount;
    if (expectedPay != null && expectedPay > 0) {
      percentage = (totalCashFlow / expectedPay) * 100;
      available = expectedPay; // TODO: Subtract existing commitments

      if (totalCashFlow > available) {
        affordable = false;
        warning = 'This requires ${totalCashFlow.toStringAsFixed(2)} per paycheck but you only have ${available.toStringAsFixed(2)} available. Consider adjusting your targets.';
      }
    }

    return {
      'cashFlow': totalCashFlow,
      'horizonPeriods': horizonPeriods,
      'autopilotPeriods': autopilotPeriods,
      'percentage': percentage,
      'available': available,
      'affordable': affordable,
      'warning': warning,
    };
  }

  int _calculatePayPeriods(DateTime startDate, DateTime endDate) {
    if (endDate.isBefore(startDate)) return 0;

    final frequency = _payDaySettings!.payFrequency;
    int periods = 0;
    DateTime currentDate = startDate;

    while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
      periods++;
      currentDate = PayDaySettings.calculateNextPayDate(currentDate, frequency);

      // Safety check to prevent infinite loops
      if (periods > 1000) break;
    }

    return periods;
  }

  int _getPayPeriodsPerAutopilot(String payFrequency, String autopilotFrequency) {
    // Estimate how many pay periods occur before each autopilot payment
    const daysPerWeek = 7.0;
    const daysPerMonth = 30.44; // Average
    const daysPerYear = 365.25;

    double payDays = 0;
    switch (payFrequency) {
      case 'weekly':
        payDays = daysPerWeek;
        break;
      case 'biweekly':
        payDays = daysPerWeek * 2;
        break;
      case 'fourweekly':
        payDays = daysPerWeek * 4;
        break;
      case 'monthly':
        payDays = daysPerMonth;
        break;
    }

    double autopilotDays = 0;
    switch (autopilotFrequency) {
      case 'weekly':
        autopilotDays = daysPerWeek;
        break;
      case 'biweekly':
        autopilotDays = daysPerWeek * 2;
        break;
      case 'fourweekly':
        autopilotDays = daysPerWeek * 4;
        break;
      case 'monthly':
        autopilotDays = daysPerMonth;
        break;
      case 'yearly':
        autopilotDays = daysPerYear;
        break;
    }

    if (payDays == 0) return 1;
    return (autopilotDays / payDays).ceil();
  }

  void _updateManualOverride() {
    if (!mounted) return;
    final manual = double.tryParse(_manualCashFlowCtrl.text);
    setState(() {
      _data = _data.copyWith(
        manualCashFlowOverride: manual,
        manualOverrideCleared: manual == null || manual <= 0,
      );
    });
    widget.onInsightChanged(_data);
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  Future<void> _pickHorizonDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _data.horizonDate ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 10)),
      helpText: 'Select target date',
    );

    if (picked != null && mounted) {
      setState(() {
        _data = _data.copyWith(horizonDate: picked);
      });
      _recalculate();
    }
  }

  void _clearHorizonDate() {
    setState(() {
      _data = _data.copyWith(horizonDateCleared: true);
    });
    _recalculate();
  }

  Future<void> _pickAutopilotDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _data.autopilotFirstDate ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
      helpText: 'Select first payment date',
    );

    if (picked != null && mounted) {
      setState(() {
        _data = _data.copyWith(
          autopilotFirstDate: picked,
          autopilotDayOfMonth: picked.day,
        );
      });
      _recalculate();
    }
  }

  @override
  void dispose() {
    _horizonAmountCtrl.dispose();
    _autopilotAmountCtrl.dispose();
    _manualCashFlowCtrl.dispose();
    _horizonAmountFocus.dispose();
    _autopilotAmountFocus.dispose();
    _manualCashFlowFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.1),
      ),
      child: Column(
        children: [
          // COLLAPSED HEADER
          InkWell(
            onTap: _toggleExpanded,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text('👁️‍🗨️', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Insight - Financial Planning',
                          style: fontProvider.getTextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        if (!_isExpanded) ...[
                          const SizedBox(height: 4),
                          Text(
                            _data.getSummary(localeProvider.currencySymbol),
                            style: fontProvider.getTextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),

          // EXPANDED CONTENT
          if (_isExpanded) ...[
            Divider(height: 1, color: theme.colorScheme.outline),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // PAY DAY INFO
                  _buildPayDayInfo(theme, fontProvider, localeProvider),

                  const SizedBox(height: 24),
                  Divider(color: theme.colorScheme.outline),
                  const SizedBox(height: 24),

                  // HORIZON SECTION
                  _buildHorizonSection(theme, fontProvider, localeProvider),

                  const SizedBox(height: 24),
                  Divider(color: theme.colorScheme.outline),
                  const SizedBox(height: 24),

                  // AUTOPILOT SECTION
                  _buildAutopilotSection(theme, fontProvider, localeProvider),

                  const SizedBox(height: 24),
                  Divider(color: theme.colorScheme.outline),
                  const SizedBox(height: 24),

                  // CASH FLOW CALCULATION SECTION
                  _buildCashFlowSection(theme, fontProvider, localeProvider),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPayDayInfo(ThemeData theme, FontProvider fontProvider, LocaleProvider localeProvider) {
    if (_isLoadingPayDay) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Loading Pay Day settings...'),
          ],
        ),
      );
    }

    if (_payDaySettings == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: theme.colorScheme.error, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Pay Day Not Configured',
                  style: fontProvider.getTextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Insight needs your Pay Day information to calculate savings plans. Please configure Pay Day in Settings.',
              style: fontProvider.getTextStyle(fontSize: 14),
            ),
          ],
        ),
      );
    }

    final nextPay = _payDaySettings!.nextPayDate;
    final expectedPay = _payDaySettings!.expectedPayAmount;
    final frequency = _payDaySettings!.payFrequency;

    String frequencyLabel = frequency;
    switch (frequency) {
      case 'weekly':
        frequencyLabel = 'Weekly';
        break;
      case 'biweekly':
        frequencyLabel = 'Bi-weekly';
        break;
      case 'fourweekly':
        frequencyLabel = 'Every 4 weeks';
        break;
      case 'monthly':
        frequencyLabel = 'Monthly';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '💡 Your Pay Day Info',
            style: fontProvider.getTextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          if (nextPay != null)
            _buildInfoRow(
              'Next Pay Day:',
              '${nextPay.day}/${nextPay.month}/${nextPay.year}',
              fontProvider,
            ),
          _buildInfoRow('Frequency:', frequencyLabel, fontProvider),
          if (expectedPay != null)
            _buildInfoRow(
              'Expected Income:',
              '${localeProvider.currencySymbol}${expectedPay.toStringAsFixed(2)}',
              fontProvider,
            ),
          // TODO: Add available after commitments calculation
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, FontProvider fontProvider) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: fontProvider.getTextStyle(fontSize: 14)),
          Text(
            value,
            style: fontProvider.getTextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizonSection(ThemeData theme, FontProvider fontProvider, LocaleProvider localeProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '🎯 HORIZON - Savings Goal',
          style: fontProvider.getTextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Set a target for future savings and wealth building',
          style: fontProvider.getTextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 12),
        SmartTextField(
          controller: _horizonAmountCtrl,
          focusNode: _horizonAmountFocus,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Target Amount',
            prefixText: localeProvider.currencySymbol,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: Icon(Icons.calculate, color: theme.colorScheme.onPrimary),
                onPressed: () async {
                  final result = await CalculatorHelper.showCalculator(context);
                  if (result != null && mounted) {
                    _horizonAmountCtrl.text = result;
                  }
                },
                tooltip: 'Open Calculator',
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _pickHorizonDate,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Target Date (Optional)',
                        style: fontProvider.getTextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _data.horizonDate == null
                            ? 'Tap to set deadline'
                            : '${_data.horizonDate!.day}/${_data.horizonDate!.month}/${_data.horizonDate!.year}',
                        style: fontProvider.getTextStyle(
                          fontSize: 13,
                          color: _data.horizonDate == null
                              ? theme.colorScheme.onSurface.withValues(alpha: 0.6)
                              : theme.colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_data.horizonDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: _clearHorizonDate,
                    tooltip: 'Clear date',
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAutopilotSection(ThemeData theme, FontProvider fontProvider, LocaleProvider localeProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚡ AUTOPILOT - Recurring Bills',
                    style: fontProvider.getTextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Automatic payments for regular expenses',
                    style: fontProvider.getTextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _data.autopilotEnabled,
              onChanged: (enabled) {
                setState(() {
                  _data = _data.copyWith(autopilotEnabled: enabled);
                });
                _recalculate();
              },
            ),
          ],
        ),
        if (_data.autopilotEnabled) ...[
          const SizedBox(height: 12),
          SmartTextField(
            controller: _autopilotAmountCtrl,
            focusNode: _autopilotAmountFocus,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Bill Amount',
              prefixText: localeProvider.currencySymbol,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: Icon(Icons.calculate, color: theme.colorScheme.onPrimary),
                  onPressed: () async {
                    final result = await CalculatorHelper.showCalculator(context);
                    if (result != null && mounted) {
                      _autopilotAmountCtrl.text = result;
                    }
                  },
                  tooltip: 'Open Calculator',
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _data.autopilotFrequency,
            decoration: InputDecoration(
              labelText: 'Payment Frequency',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: const [
              DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
              DropdownMenuItem(value: 'biweekly', child: Text('Bi-weekly')),
              DropdownMenuItem(value: 'fourweekly', child: Text('Every 4 Weeks')),
              DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
              DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _data = _data.copyWith(autopilotFrequency: value);
                });
                _recalculate();
              }
            },
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickAutopilotDate,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outline),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'First Payment Date',
                          style: fontProvider.getTextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _data.autopilotFirstDate == null
                              ? 'Tap to select date'
                              : '${_data.autopilotFirstDate!.day}/${_data.autopilotFirstDate!.month}/${_data.autopilotFirstDate!.year}',
                          style: fontProvider.getTextStyle(
                            fontSize: 13,
                            color: _data.autopilotFirstDate == null
                                ? theme.colorScheme.onSurface.withValues(alpha: 0.6)
                                : theme.colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _data.autopilotAutoExecute,
            onChanged: (value) {
              setState(() {
                _data = _data.copyWith(autopilotAutoExecute: value);
              });
              widget.onInsightChanged(_data);
            },
            title: Text(
              'Auto-execute payment',
              style: fontProvider.getTextStyle(fontSize: 14),
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ],
    );
  }

  Widget _buildCashFlowSection(ThemeData theme, FontProvider fontProvider, LocaleProvider localeProvider) {
    final hasCalculation = _data.calculatedCashFlow != null && _data.calculatedCashFlow! > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '💰 CASH FLOW - Savings Plan',
          style: fontProvider.getTextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),

        // CALCULATION DISPLAY
        if (hasCalculation) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _data.isAffordable
                  ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.3)
                  : theme.colorScheme.errorContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _data.isAffordable
                    ? theme.colorScheme.secondary.withValues(alpha: 0.3)
                    : theme.colorScheme.error.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('✨', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                    Text(
                      'Insight Calculation',
                      style: fontProvider.getTextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Horizon calculation
                if (_data.horizonAmount != null && _data.horizonAmount! > 0) ...[
                  _buildCalculationRow(
                    '🎯 Horizon Goal:',
                    '${localeProvider.currencySymbol}${_data.horizonAmount!.toStringAsFixed(2)}',
                    fontProvider,
                  ),
                  if (_data.horizonDate != null && _data.payPeriodsToHorizon != null)
                    _buildCalculationRow(
                      '   Pay periods:',
                      '${_data.payPeriodsToHorizon} until ${_data.horizonDate!.day}/${_data.horizonDate!.month}/${_data.horizonDate!.year}',
                      fontProvider,
                      isSubItem: true,
                    ),
                  const SizedBox(height: 8),
                ],

                // Autopilot calculation
                if (_data.autopilotEnabled && _data.autopilotAmount != null && _data.autopilotAmount! > 0) ...[
                  _buildCalculationRow(
                    '⚡ Autopilot Bill:',
                    '${localeProvider.currencySymbol}${_data.autopilotAmount!.toStringAsFixed(2)}',
                    fontProvider,
                  ),
                  if (_data.payPeriodsToAutopilot != null)
                    _buildCalculationRow(
                      '   Pay periods:',
                      '${_data.payPeriodsToAutopilot} before next bill',
                      fontProvider,
                      isSubItem: true,
                    ),
                  const SizedBox(height: 8),
                ],

                const Divider(),
                const SizedBox(height: 8),

                // Total calculation
                _buildCalculationRow(
                  '💰 Save per paycheck:',
                  '${localeProvider.currencySymbol}${_data.calculatedCashFlow!.toStringAsFixed(2)}',
                  fontProvider,
                  isBold: true,
                ),
                if (_data.percentageOfIncome != null)
                  _buildCalculationRow(
                    '   % of income:',
                    '${_data.percentageOfIncome!.toStringAsFixed(1)}%',
                    fontProvider,
                    isSubItem: true,
                  ),

                // Warning message
                if (_data.warningMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning, color: theme.colorScheme.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _data.warningMessage!,
                            style: fontProvider.getTextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Enable Cash Flow switch
          SwitchListTile(
            value: _data.cashFlowEnabled,
            onChanged: (value) {
              setState(() {
                _data = _data.copyWith(cashFlowEnabled: value);
              });
              widget.onInsightChanged(_data);
            },
            title: Text(
              'Enable Cash Flow auto-fill',
              style: fontProvider.getTextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              'Automatically deposit calculated amount on Pay Day',
              style: fontProvider.getTextStyle(fontSize: 12),
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Text('💡', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Enter a Horizon or Autopilot amount above to calculate your savings plan',
                    style: fontProvider.getTextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // MANUAL OVERRIDE SECTION
        if (hasCalculation || _showManualOverride) ...[
          TextButton.icon(
            onPressed: () {
              setState(() {
                _showManualOverride = !_showManualOverride;
              });
            },
            icon: Icon(_showManualOverride ? Icons.expand_less : Icons.expand_more),
            label: Text(_showManualOverride ? 'Hide Manual Override' : 'Manual Override'),
          ),

          if (_showManualOverride) ...[
            const SizedBox(height: 8),
            SmartTextField(
              controller: _manualCashFlowCtrl,
              focusNode: _manualCashFlowFocus,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Custom Cash Flow Amount',
                prefixText: localeProvider.currencySymbol,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                helperText: 'Override calculated amount with your own',
                suffixIcon: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.calculate, color: theme.colorScheme.onPrimary),
                    onPressed: () async {
                      final result = await CalculatorHelper.showCalculator(context);
                      if (result != null && mounted) {
                        _manualCashFlowCtrl.text = result;
                      }
                    },
                    tooltip: 'Open Calculator',
                  ),
                ),
              ),
            ),
            if (_data.isManualOverride) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: theme.colorScheme.tertiary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Using manual override: ${localeProvider.currencySymbol}${_data.manualCashFlowOverride!.toStringAsFixed(2)}',
                        style: fontProvider.getTextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.tertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ],
    );
  }

  Widget _buildCalculationRow(String label, String value, FontProvider fontProvider, {bool isBold = false, bool isSubItem = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4, left: isSubItem ? 16 : 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: fontProvider.getTextStyle(
              fontSize: isSubItem ? 12 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: fontProvider.getTextStyle(
              fontSize: isSubItem ? 12 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
