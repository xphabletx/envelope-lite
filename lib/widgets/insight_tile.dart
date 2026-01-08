// lib/widgets/insight_tile.dart
// 👁️‍🗨️ Insight - Unified financial planning tile
// Combines Horizon, Autopilot, and Cash Flow into one intelligent interface

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/insight_data.dart';
import '../models/pay_day_settings.dart';
import '../models/scheduled_payment.dart';
import '../services/pay_day_settings_service.dart';
import '../services/envelope_repo.dart';
import '../providers/font_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/calculator_helper.dart';
import 'common/smart_text_field.dart';

class InsightTile extends StatefulWidget {
  final String userId;
  final Function(InsightData) onInsightChanged;
  final InsightData? initialData;
  final bool initiallyExpanded;
  final double? startingAmount; // NEW: Starting amount to calculate gap
  final EnvelopeRepo? envelopeRepo; // Optional: for calculating existing commitments
  final List<ScheduledPayment>? scheduledPayments; // NEW: Scheduled payments for this envelope

  const InsightTile({
    super.key,
    required this.userId,
    required this.onInsightChanged,
    this.initialData,
    this.initiallyExpanded = false,
    this.startingAmount,
    this.envelopeRepo,
    this.scheduledPayments,
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
  double _existingCommitments = 0.0; // Total cash flow from other envelopes

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

    debugPrint('[InsightTile] 🚀 initState - Initial data:');
    debugPrint('  cashFlowEnabled: ${_data.cashFlowEnabled}');
    debugPrint('  autopilotAutoExecute: ${_data.autopilotAutoExecute}');
    debugPrint('  horizonAmount: ${_data.horizonAmount}');
    debugPrint('  autopilotAmount: ${_data.autopilotAmount}');

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
    _loadExistingCommitments();

    // Add listeners to recalculate on changes
    _horizonAmountCtrl.addListener(_recalculate);
    _autopilotAmountCtrl.addListener(_recalculate);
    _manualCashFlowCtrl.addListener(_updateManualOverride);
  }

  @override
  void didUpdateWidget(InsightTile oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Recalculate if starting amount changed
    if (widget.startingAmount != oldWidget.startingAmount) {
      debugPrint(
        '[InsightTile] 🔄 Starting amount changed: ${oldWidget.startingAmount} -> ${widget.startingAmount}',
      );
      // Recalculate immediately without notifying parent (prevents build-during-build)
      _recalculateInternal();
    }
  }

  Future<void> _loadExistingCommitments() async {
    if (widget.envelopeRepo == null) {
      setState(() => _existingCommitments = 0.0);
      return;
    }

    try {
      // IMPORTANT: Only get current user's envelopes (not partner's in workspace)
      final allEnvelopes = await widget.envelopeRepo!.envelopesStream(showPartnerEnvelopes: false).first;
      final envelopes = allEnvelopes
          .where((e) => e.userId == widget.envelopeRepo!.currentUserId)
          .toList();

      double total = 0.0;

      for (final envelope in envelopes) {
        // Only count envelopes with cash flow enabled
        if (envelope.cashFlowEnabled && envelope.cashFlowAmount != null) {
          total += envelope.cashFlowAmount!;
        }
      }

      if (mounted) {
        setState(() {
          _existingCommitments = total;
        });
        _recalculate(); // Recalculate with updated commitments
      }
    } catch (e) {
      debugPrint('Error loading existing commitments: $e');
      if (mounted) {
        setState(() => _existingCommitments = 0.0);
      }
    }
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

  /// Internal recalculation that updates state without notifying parent
  /// Used when parent triggers the update (prevents build-during-build)
  void _recalculateInternal() {
    if (!mounted) return;

    final horizonAmount = double.tryParse(_horizonAmountCtrl.text);
    final autopilotAmount = double.tryParse(_autopilotAmountCtrl.text);

    debugPrint('[InsightTile] 🔄 _recalculateInternal called:');
    debugPrint('  horizonAmount input: $horizonAmount');
    debugPrint('  autopilotAmount input: $autopilotAmount');
    debugPrint('  current cashFlowEnabled: ${_data.cashFlowEnabled}');

    // Update amounts in data (don't update warning yet, will be set below)
    _data = _data.copyWith(
      horizonAmount: horizonAmount,
      autopilotAmount: autopilotAmount,
      updateWarning: false,
    );

    // Calculate cash flow if we have pay day settings
    if (_payDaySettings != null &&
        (horizonAmount != null || autopilotAmount != null)) {
      debugPrint('[InsightTile] 💰 Calculating cash flow...');
      final calculations = _calculateCashFlow(
        horizonAmount: horizonAmount,
        horizonDate: _data.horizonDate,
        autopilotAmount: autopilotAmount,
        autopilotFrequency: _data.autopilotFrequency,
      );

      debugPrint('[InsightTile] 📊 Calculation results:');
      debugPrint('  cashFlow: ${calculations['cashFlow']}');
      debugPrint('  affordable: ${calculations['affordable']}');
      debugPrint('  warning: ${calculations['warning']}');

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
      debugPrint(
        '[InsightTile] ✅ After update - cashFlowEnabled: ${_data.cashFlowEnabled}',
      );
    } else {
      debugPrint(
        '[InsightTile] ⚠️ Resetting calculations (no pay day settings or amounts)',
      );
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

    // Don't notify parent - they already know (they triggered this change)
  }

  /// Public recalculation that also notifies parent
  /// Used when user interactions within this widget trigger changes
  void _recalculate() {
    _recalculateInternal();
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

    // Calculate Horizon cash flow (ONLY if enabled)
    if (_data.horizonEnabled && horizonAmount != null && horizonAmount > 0) {
      // Calculate the gap: target - starting amount
      final startingAmount = widget.startingAmount ?? 0.0;
      final gap = horizonAmount - startingAmount;

      if (gap > 0) {
        if (horizonDate != null) {
          // Calculate pay periods until target date
          horizonPeriods = _calculatePayPeriods(nextPayDate, horizonDate);
          if (horizonPeriods > 0) {
            totalCashFlow += gap / horizonPeriods.toDouble();
          } else {
            // Target date is before next pay day - need full gap amount now
            totalCashFlow += gap;
          }
        } else {
          // No date set - can't calculate periods, just note we need to save the gap
          horizonPeriods = null;
        }
      }
      // If gap <= 0, target is already met or exceeded, no cash flow needed for horizon
    }

    // Calculate Autopilot cash flow (ONLY if enabled)
    if (_data.autopilotEnabled &&
        autopilotAmount != null &&
        autopilotAmount > 0) {
      // Calculate the gap: bill amount - starting amount already saved
      final startingAmount = widget.startingAmount ?? 0.0;
      final gap = autopilotAmount - startingAmount;

      // Only calculate if we need to save more
      if (gap > 0) {
        // If autopilot has a first date set, calculate actual pay periods until that date
        if (_data.autopilotFirstDate != null) {
          autopilotPeriods = _calculatePayPeriods(
            nextPayDate,
            _data.autopilotFirstDate!,
          );
          if (autopilotPeriods > 0) {
            totalCashFlow += gap / autopilotPeriods.toDouble();
          } else {
            // Bill is due before next pay day - need full amount now
            totalCashFlow += gap;
            autopilotPeriods = 0;
          }
        } else {
          // No date set - estimate based on frequency
          final periodsPerAutopilot = _getPayPeriodsPerAutopilot(
            _payDaySettings!.payFrequency,
            autopilotFrequency ?? 'monthly',
          );

          if (periodsPerAutopilot > 0) {
            autopilotPeriods = periodsPerAutopilot;
            totalCashFlow += gap / periodsPerAutopilot.toDouble();
          }
        }
      }
      // If gap <= 0, we already have enough saved for the bill
    }

    // Calculate percentage of income
    double? percentage;
    double? available;
    bool affordable = true;
    String? warning;

    final expectedPay = _payDaySettings!.expectedPayAmount;
    if (expectedPay != null && expectedPay > 0) {
      percentage = (totalCashFlow / expectedPay) * 100;
      // Subtract existing commitments from other envelopes
      available = expectedPay - _existingCommitments;

      if (totalCashFlow > available) {
        affordable = false;
        warning =
            'This requires ${totalCashFlow.toStringAsFixed(2)} per paycheck, but you only have ${available.toStringAsFixed(2)} available after existing commitments (${_existingCommitments.toStringAsFixed(2)} already committed). Consider adjusting your targets.';
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

    while (currentDate.isBefore(endDate) ||
        currentDate.isAtSameMomentAs(endDate)) {
      periods++;
      currentDate = PayDaySettings.calculateNextPayDate(currentDate, frequency);

      // Safety check to prevent infinite loops
      if (periods > 1000) break;
    }

    return periods;
  }

  int _getPayPeriodsPerAutopilot(
    String payFrequency,
    String autopilotFrequency,
  ) {
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
        updateWarning:
            false, // Don't clear warning when updating manual override
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
        _data = _data.copyWith(
          horizonDate: picked,
          updateWarning: false, // Warning will be updated in _recalculate
        );
      });
      _recalculate();
    }
  }

  void _clearHorizonDate() {
    setState(() {
      _data = _data.copyWith(
        horizonDateCleared: true,
        updateWarning: false, // Warning will be updated in _recalculate
      );
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
          updateWarning: false, // Warning will be updated in _recalculate
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
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
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

  Widget _buildPayDayInfo(
    ThemeData theme,
    FontProvider fontProvider,
    LocaleProvider localeProvider,
  ) {
    if (_isLoadingPayDay) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.3,
          ),
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
          border: Border.all(
            color: theme.colorScheme.error.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: theme.colorScheme.error,
                  size: 20,
                ),
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
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
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
          if (expectedPay != null) ...[
            _buildInfoRow(
              'Expected Income:',
              '${localeProvider.currencySymbol}${expectedPay.toStringAsFixed(2)}',
              fontProvider,
            ),
            if (_existingCommitments > 0) ...[
              _buildInfoRow(
                'Existing Commitments:',
                '${localeProvider.currencySymbol}${_existingCommitments.toStringAsFixed(2)}',
                fontProvider,
                isWarning: true,
              ),
              _buildInfoRow(
                'Available:',
                '${localeProvider.currencySymbol}${(expectedPay - _existingCommitments).toStringAsFixed(2)}',
                fontProvider,
                isHighlight: true,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '💡 This calculation is a recommendation based on your Pay Day settings. '
                  'Available = Expected Income - Existing Commitments from other envelopes. '
                  'Adjust targets based on your actual financial situation.',
                  style: fontProvider.getTextStyle(
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    FontProvider fontProvider, {
    bool isWarning = false,
    bool isHighlight = false,
  }) {
    final theme = Theme.of(context);
    Color? valueColor;

    if (isWarning) {
      valueColor = theme.colorScheme.error;
    } else if (isHighlight) {
      valueColor = theme.colorScheme.secondary;
    }

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
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizonSection(
    ThemeData theme,
    FontProvider fontProvider,
    LocaleProvider localeProvider,
  ) {
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
                ],
              ),
            ),
            Switch(
              value: _data.horizonEnabled,
              onChanged: (enabled) {
                setState(() {
                  _data = _data.copyWith(
                    horizonEnabled: enabled,
                    updateWarning:
                        false, // Warning will be updated in _recalculate
                  );
                });
                _recalculate();
              },
            ),
          ],
        ),
        if (_data.horizonEnabled) ...[
          const SizedBox(height: 12),
          SmartTextField(
            controller: _horizonAmountCtrl,
            focusNode: _horizonAmountFocus,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onTap: () => _horizonAmountCtrl.selection = TextSelection(
              baseOffset: 0,
              extentOffset: _horizonAmountCtrl.text.length,
            ),
            decoration: InputDecoration(
              labelText: 'Target Amount',
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
                    final result = await CalculatorHelper.showCalculator(
                      context,
                    );
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
                                ? theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  )
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
      ],
    );
  }

  Widget _buildAutopilotSection(
    ThemeData theme,
    FontProvider fontProvider,
    LocaleProvider localeProvider,
  ) {
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
                  if (enabled && widget.scheduledPayments != null && widget.scheduledPayments!.isNotEmpty) {
                    // Auto-populate from first scheduled payment
                    final payment = widget.scheduledPayments!.first;
                    _autopilotAmountCtrl.text = payment.amount.toStringAsFixed(2);

                    _data = _data.copyWith(
                      autopilotEnabled: enabled,
                      autopilotAmount: payment.amount,
                      updateWarning: false,
                    );
                  } else {
                    _data = _data.copyWith(
                      autopilotEnabled: enabled,
                      updateWarning: false,
                    );
                  }
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
            onTap: () => _autopilotAmountCtrl.selection = TextSelection(
              baseOffset: 0,
              extentOffset: _autopilotAmountCtrl.text.length,
            ),
            decoration: InputDecoration(
              labelText: 'Bill Amount',
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
                    final result = await CalculatorHelper.showCalculator(
                      context,
                    );
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
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
              DropdownMenuItem(value: 'biweekly', child: Text('Bi-weekly')),
              DropdownMenuItem(
                value: 'fourweekly',
                child: Text('Every 4 Weeks'),
              ),
              DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
              DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _data = _data.copyWith(
                    autopilotFrequency: value,
                    updateWarning:
                        false, // Warning will be updated in _recalculate
                  );
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
                                ? theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  )
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
                _data = _data.copyWith(
                  autopilotAutoExecute: value,
                  updateWarning:
                      false, // Don't update warning when toggling auto-execute
                );
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

  Widget _buildCashFlowSection(
    ThemeData theme,
    FontProvider fontProvider,
    LocaleProvider localeProvider,
  ) {
    final hasCalculation =
        _data.calculatedCashFlow != null && _data.calculatedCashFlow! > 0;

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

                // Horizon calculation (ONLY if enabled)
                if (_data.horizonEnabled &&
                    _data.horizonAmount != null &&
                    _data.horizonAmount! > 0) ...[
                  _buildCalculationRow(
                    '🎯 Horizon Goal:',
                    '${localeProvider.currencySymbol}${_data.horizonAmount!.toStringAsFixed(2)}',
                    fontProvider,
                  ),
                  // Show starting amount if provided
                  if (widget.startingAmount != null &&
                      widget.startingAmount! > 0) ...[
                    _buildCalculationRow(
                      '   Starting amount:',
                      '${localeProvider.currencySymbol}${widget.startingAmount!.toStringAsFixed(2)}',
                      fontProvider,
                      isSubItem: true,
                    ),
                    _buildCalculationRow(
                      '   Gap to save:',
                      '${localeProvider.currencySymbol}${(_data.horizonAmount! - widget.startingAmount!).toStringAsFixed(2)}',
                      fontProvider,
                      isSubItem: true,
                    ),
                  ],
                  if (_data.horizonDate != null &&
                      _data.payPeriodsToHorizon != null)
                    _buildCalculationRow(
                      '   Pay periods:',
                      '${_data.payPeriodsToHorizon} until ${_data.horizonDate!.day}/${_data.horizonDate!.month}/${_data.horizonDate!.year}',
                      fontProvider,
                      isSubItem: true,
                    ),
                  // Show helpful message if no date is set
                  if (_data.horizonDate == null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(
                          alpha: 0.3,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '💡 Add a target date above for automatic cash flow calculation, or set manual cash flow below',
                                  style: fontProvider.getTextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Show "periods to goal" if manual cash flow is set
                          if (_data.manualCashFlowOverride != null &&
                              _data.manualCashFlowOverride! > 0) ...[
                            const SizedBox(height: 8),
                            () {
                              final startingAmount =
                                  widget.startingAmount ?? 0.0;
                              final gap = _data.horizonAmount! - startingAmount;
                              if (gap > 0) {
                                final periodsToGoal =
                                    (gap / _data.manualCashFlowOverride!)
                                        .ceil();
                                return Text(
                                  '📊 At ${localeProvider.currencySymbol}${_data.manualCashFlowOverride!.toStringAsFixed(2)}/paycheck, you\'ll reach your goal in ~$periodsToGoal pay periods',
                                  style: fontProvider.getTextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.secondary,
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            }(),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],

                // Autopilot calculation
                if (_data.autopilotEnabled &&
                    _data.autopilotAmount != null &&
                    _data.autopilotAmount! > 0) ...[
                  _buildCalculationRow(
                    '⚡ Autopilot Bill:',
                    '${localeProvider.currencySymbol}${_data.autopilotAmount!.toStringAsFixed(2)}${_data.autopilotFirstDate != null ? ' due ${_data.autopilotFirstDate!.day}/${_data.autopilotFirstDate!.month}/${_data.autopilotFirstDate!.year}' : ''}',
                    fontProvider,
                  ),
                  // Show starting amount if provided
                  if (widget.startingAmount != null &&
                      widget.startingAmount! > 0) ...[
                    _buildCalculationRow(
                      '   Starting amount:',
                      '${localeProvider.currencySymbol}${widget.startingAmount!.toStringAsFixed(2)}',
                      fontProvider,
                      isSubItem: true,
                    ),
                    _buildCalculationRow(
                      '   Gap to save:',
                      '${localeProvider.currencySymbol}${(_data.autopilotAmount! - widget.startingAmount!).toStringAsFixed(2)}',
                      fontProvider,
                      isSubItem: true,
                    ),
                  ],
                  if (_data.payPeriodsToAutopilot != null &&
                      _data.payPeriodsToAutopilot! > 0) ...[
                    _buildCalculationRow(
                      '   Pay periods until due:',
                      '${_data.payPeriodsToAutopilot}',
                      fontProvider,
                      isSubItem: true,
                    ),
                    _buildCalculationRow(
                      '   Per paycheck:',
                      '${localeProvider.currencySymbol}${_data.calculatedCashFlow!.toStringAsFixed(2)}',
                      fontProvider,
                      isSubItem: true,
                    ),
                  ] else if (_data.payPeriodsToAutopilot == 0) ...[
                    _buildCalculationRow(
                      '   ⚠️ Due before next payday!',
                      'Need full amount now',
                      fontProvider,
                      isSubItem: true,
                    ),
                  ],
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
                        Icon(
                          Icons.warning,
                          color: theme.colorScheme.error,
                          size: 20,
                        ),
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
                _data = _data.copyWith(
                  cashFlowEnabled: value,
                  updateWarning:
                      false, // Don't update warning when toggling cash flow
                );
              });
              widget.onInsightChanged(_data);
            },
            title: Text(
              'Enable Cash Flow',
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
          // No automatic calculation available - show info and manual input option
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.3,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Text('💡', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _payDaySettings == null
                        ? 'Configure Pay Day settings for automatic calculations, or enter a manual amount below'
                        : 'Enter a Horizon or Autopilot amount and date above for automatic calculations, or use manual input below',
                    style: fontProvider.getTextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // MANUAL CASH FLOW INPUT - Always available
        if (hasCalculation) ...[
          // If we have a calculation, show it as a collapsible "override" option
          TextButton.icon(
            onPressed: () {
              setState(() {
                _showManualOverride = !_showManualOverride;
              });
            },
            icon: Icon(
              _showManualOverride ? Icons.expand_less : Icons.expand_more,
            ),
            label: Text(
              _showManualOverride ? 'Hide Manual Override' : 'Manual Override',
            ),
          ),
        ],

        // Show manual input if: (1) we have calculation and user toggled it, OR (2) no calculation available
        if ((hasCalculation && _showManualOverride) || !hasCalculation) ...[
          if (!hasCalculation) ...[
            // Show a label for manual input when there's no calculation
            Text(
              'Manual Cash Flow Amount',
              style: fontProvider.getTextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          SmartTextField(
            controller: _manualCashFlowCtrl,
            focusNode: _manualCashFlowFocus,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onTap: () => _manualCashFlowCtrl.selection = TextSelection(
              baseOffset: 0,
              extentOffset: _manualCashFlowCtrl.text.length,
            ),
            decoration: InputDecoration(
              labelText: hasCalculation
                  ? 'Custom Cash Flow Amount'
                  : 'Cash Flow Amount',
              prefixText: localeProvider.currencySymbol,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              helperText: hasCalculation
                  ? 'Override calculated amount with your own'
                  : 'Amount to auto-fill on Pay Day',
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
                    final result = await CalculatorHelper.showCalculator(
                      context,
                    );
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
                color: theme.colorScheme.tertiaryContainer.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.tertiary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasCalculation
                          ? 'Using manual override: ${localeProvider.currencySymbol}${_data.manualCashFlowOverride!.toStringAsFixed(2)}'
                          : 'Cash Flow: ${localeProvider.currencySymbol}${_data.manualCashFlowOverride!.toStringAsFixed(2)}',
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

          // Enable Cash Flow toggle (when no automatic calculation)
          if (!hasCalculation && _data.isManualOverride) ...[
            const SizedBox(height: 16),
            SwitchListTile(
              value: _data.cashFlowEnabled,
              onChanged: (value) {
                setState(() {
                  _data = _data.copyWith(
                    cashFlowEnabled: value,
                    updateWarning: false,
                  );
                });
                widget.onInsightChanged(_data);
              },
              title: Text(
                'Enable Cash Flow',
                style: fontProvider.getTextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'Automatically deposit this amount on Pay Day',
                style: fontProvider.getTextStyle(fontSize: 12),
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildCalculationRow(
    String label,
    String value,
    FontProvider fontProvider, {
    bool isBold = false,
    bool isSubItem = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4, left: isSubItem ? 16 : 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: fontProvider.getTextStyle(
                fontSize: isSubItem ? 12 : 14,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
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
