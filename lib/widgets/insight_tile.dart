// lib/widgets/insight_tile.dart
// 👁️‍🗨️ Insight - Unified financial planning tile
// Combines Horizon, Autopilot, and Cash Flow into one intelligent interface

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/insight_data.dart';
import '../models/pay_day_settings.dart';
import '../models/scheduled_payment.dart';
import '../models/envelope.dart';
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
  final double? startingAmount; // Envelope's starting amount to calculate gap
  final double? accountBalance; // User's actual main account balance
  final EnvelopeRepo? envelopeRepo; // Optional: for calculating existing commitments
  final List<ScheduledPayment>? scheduledPayments; // Scheduled payments for this envelope
  final String? envelopeId; // Optional: envelope ID to exclude from commitments calculation

  const InsightTile({
    super.key,
    required this.userId,
    required this.onInsightChanged,
    this.initialData,
    this.initiallyExpanded = false,
    this.startingAmount,
    this.accountBalance,
    this.envelopeRepo,
    this.scheduledPayments,
    this.envelopeId,
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
  bool _hasInitializedFromScheduledPayments = false; // Track if we've loaded autopilot data

  // Horizon mode state
  HorizonAllocationMode _horizonMode = HorizonAllocationMode.date;

  // Controllers
  late TextEditingController _horizonAmountCtrl;
  late TextEditingController _autopilotAmountCtrl;
  late TextEditingController _manualCashFlowCtrl;
  late TextEditingController _percentageCtrl;
  late TextEditingController _fixedAmountCtrl;

  // Focus nodes
  final _horizonAmountFocus = FocusNode();
  final _autopilotAmountFocus = FocusNode();
  final _manualCashFlowFocus = FocusNode();
  final _percentageFocus = FocusNode();
  final _fixedAmountFocus = FocusNode();

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
    _percentageCtrl = TextEditingController(
      text: _data.horizonPercentage?.toString() ?? '',
    );
    _fixedAmountCtrl = TextEditingController(
      text: _data.horizonFixedAmount?.toString() ?? '',
    );

    _showManualOverride = _data.isManualOverride;
    _horizonMode = _data.horizonMode ?? HorizonAllocationMode.date;

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

    // Check if initialData changed (e.g., from FutureBuilder completing with scheduled payments)
    // Only apply once when autopilot data first arrives, not on every rebuild
    if (!_hasInitializedFromScheduledPayments &&
        widget.initialData != null &&
        widget.initialData!.autopilotEnabled &&
        widget.initialData!.autopilotAmount != null) {

      setState(() {
        _data = widget.initialData!;
        // Update controllers to match new data
        _autopilotAmountCtrl.text = _data.autopilotAmount?.toString() ?? '';
        _horizonAmountCtrl.text = _data.horizonAmount?.toString() ?? '';
        _manualCashFlowCtrl.text = _data.manualCashFlowOverride?.toString() ?? '';
        // Mark as initialized so we don't overwrite user changes
        _hasInitializedFromScheduledPayments = true;
      });

      // Recalculate with new data
      _recalculateInternal();
    }

    // Recalculate if starting amount changed
    if (widget.startingAmount != oldWidget.startingAmount) {
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
        // Exclude current envelope from commitments calculation
        if (widget.envelopeId != null && envelope.id == widget.envelopeId) {
          continue;
        }

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


    // Update amounts in data (don't update warning yet, will be set below)
    _data = _data.copyWith(
      horizonAmount: horizonAmount,
      autopilotAmount: autopilotAmount,
      updateWarning: false,
    );

    // Calculate cash flow if we have pay day settings
    if (_payDaySettings != null &&
        (horizonAmount != null || autopilotAmount != null)) {
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
          autopilotPaymentsCovered: calculations['paymentsCovered'],
          autopilotAlwaysCovered: calculations['alwaysCovered'],
          coverageSuggestion: calculations['coverageSuggestion'],
          // Setup phase data
          initialCatchUpAmount: calculations['initialCatchUpAmount'],
          ongoingCashFlow: calculations['ongoingCashFlow'],
          isInSetupPhase: calculations['isInSetupPhase'],
          setupPhaseEndDate: calculations['setupPhaseEndDate'],
          payPeriodsUntilSteadyState: calculations['payPeriodsUntilSteadyState'],
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
    final startingAmount = widget.startingAmount ?? 0.0;


    // Detect allocation mode
    final horizonMode = _data.horizonMode ?? HorizonAllocationMode.date;

    // Calculate available income for percentage/fixed amount allocation
    final expectedPay = _payDaySettings!.expectedPayAmount ?? 0.0;
    final availableIncome = expectedPay - _existingCommitments;


    // CRITICAL: Determine if autopilot payment happens BEFORE next payday
    // This affects how we allocate the starting amount between goals
    bool autopilotBeforePayday = false;
    double effectiveStartingForHorizon = startingAmount;
    double effectiveStartingForAutopilot = startingAmount;

    if (_data.autopilotEnabled &&
        autopilotAmount != null &&
        autopilotAmount > 0 &&
        _data.autopilotFirstDate != null) {
      autopilotBeforePayday = _data.autopilotFirstDate!.isBefore(nextPayDate);


      if (autopilotBeforePayday) {
        // Autopilot payment happens BEFORE payday
        // The starting amount will be consumed by autopilot payment
        // So Horizon should NOT benefit from it
        effectiveStartingForHorizon = 0.0;
        effectiveStartingForAutopilot = startingAmount;

      } else {
        // Payday happens BEFORE autopilot payment
        // Both goals can benefit from starting amount in their calculations
        effectiveStartingForHorizon = startingAmount;
        effectiveStartingForAutopilot = startingAmount;

      }
    } else {
    }

    // Calculate Horizon cash flow (ONLY if enabled)
    if (_data.horizonEnabled && horizonAmount != null && horizonAmount > 0) {

      if (horizonMode == HorizonAllocationMode.percentage && _data.horizonPercentage != null) {
        // === PERCENTAGE MODE ===

        // Calculate contribution per paycheck
        final contributionPerPay = availableIncome * (_data.horizonPercentage! / 100);

        // Calculate gap to target
        final gap = horizonAmount - effectiveStartingForHorizon;

        if (gap > 0 && contributionPerPay > 0) {
          // Calculate number of pay periods needed
          final periodsNeeded = (gap / contributionPerPay).ceil();
          horizonPeriods = periodsNeeded;

          // Calculate projected arrival date
          final projectedDate = _calculateProjectedDate(nextPayDate, periodsNeeded);
          _data = _data.copyWith(
            projectedArrivalDate: projectedDate,
            projectedMonthlyContribution: contributionPerPay,
          );

          // Add to total cash flow
          totalCashFlow += contributionPerPay;
        } else if (gap <= 0) {
        } else {
        }
      } else if (horizonMode == HorizonAllocationMode.date) {
        // === DATE MODE (user sets date, system calculates contribution) ===

        // Calculate the gap: target - effective starting amount
        final gap = horizonAmount - effectiveStartingForHorizon;

        if (gap > 0) {
          if (horizonDate != null) {
          // Calculate pay periods until target date
          horizonPeriods = _calculatePayPeriods(nextPayDate, horizonDate);

          // IMPORTANT: If both Horizon and Autopilot are enabled,
          // we need to account for autopilot payments during the horizon period
          // BUT ONLY if autopilot has a gap (needs funding)
          double adjustedGap = gap;

          if (_data.autopilotEnabled && autopilotAmount != null && autopilotAmount > 0) {
            // Check if autopilot needs funding (gap > 0)
            final autopilotGap = autopilotAmount - effectiveStartingForAutopilot;

            // Only add autopilot costs if autopilot itself needs cash flow funding
            // If starting amount >= autopilot amount, those payments are already covered
            if (autopilotGap > 0) {
              // Calculate how many autopilot payments will occur before horizon date
              int autopilotPaymentsDuringHorizon = 0;

              if (_data.autopilotFirstDate != null && horizonDate.isAfter(_data.autopilotFirstDate!)) {
                // Count autopilot payments between first payment and horizon date
                DateTime currentAutopilotDate = _data.autopilotFirstDate!;
                while (currentAutopilotDate.isBefore(horizonDate) || currentAutopilotDate.isAtSameMomentAs(horizonDate)) {
                  autopilotPaymentsDuringHorizon++;
                  currentAutopilotDate = _getNextAutopilotDate(currentAutopilotDate, autopilotFrequency ?? 'monthly');

                  // Safety check
                  if (autopilotPaymentsDuringHorizon > 1000) break;
                }

                // Add the cost of these autopilot payments to the horizon gap
                final totalAutopilotCost = autopilotPaymentsDuringHorizon * autopilotAmount;
                adjustedGap = gap + totalAutopilotCost;

              }
            } else {
            }
          }

          if (horizonPeriods > 0) {
            final horizonCashFlow = adjustedGap / horizonPeriods.toDouble();
            totalCashFlow += horizonCashFlow;

            // Set projected arrival date to the user's chosen horizon date
            _data = _data.copyWith(
              projectedArrivalDate: horizonDate,
            );
          } else {
            // Target date is before next pay day - need full gap amount now
            totalCashFlow += adjustedGap;

            // Still set the projected arrival date to show the target
            _data = _data.copyWith(
              projectedArrivalDate: horizonDate,
            );
          }
          } else {
            // No date set - can't calculate periods, just note we need to save the gap
            horizonPeriods = null;
          }
        } else {
        }
        // If gap <= 0, target is already met or exceeded, no cash flow needed for horizon
      } else if (horizonMode == HorizonAllocationMode.fixedAmount) {
        // === FIXED AMOUNT MODE (user sets amount, system calculates arrival date) ===

        // Get the fixed amount from horizonFixedAmount (user's input, isolated from autopilot)
        final fixedContribution = _data.horizonFixedAmount ?? 0.0;

        // Calculate the gap: target - effective starting amount
        final gap = horizonAmount - effectiveStartingForHorizon;

        if (gap > 0 && fixedContribution > 0) {
          // Calculate number of pay periods needed
          final periodsNeeded = (gap / fixedContribution).ceil();
          horizonPeriods = periodsNeeded;

          // Calculate projected arrival date
          final projectedDate = _calculateProjectedDate(nextPayDate, periodsNeeded);
          _data = _data.copyWith(
            projectedArrivalDate: projectedDate,
            projectedMonthlyContribution: fixedContribution,
          );

          // Use the fixed contribution as the cash flow (for horizon only)
          totalCashFlow += fixedContribution;
        } else if (gap <= 0) {
        } else {
        }
      }
    }

    // Calculate Autopilot cash flow (ONLY if enabled)
    int? paymentsCovered;
    bool? alwaysCovered;
    String? coverageSuggestion;

    if (_data.autopilotEnabled &&
        autopilotAmount != null &&
        autopilotAmount > 0) {

      // Calculate the gap: bill amount - effective starting amount for autopilot
      final gap = autopilotAmount - effectiveStartingForAutopilot;

      // Only calculate if we need to save more
      if (gap > 0) {
        // Clear any old coverage suggestion since we now have a gap
        coverageSuggestion = null;

        // If autopilot has a first date set, calculate actual pay periods until that date
        if (_data.autopilotFirstDate != null) {
          autopilotPeriods = _calculatePayPeriods(
            nextPayDate,
            _data.autopilotFirstDate!,
          );

          if (autopilotPeriods > 0) {
            final autopilotCashFlow = gap / autopilotPeriods.toDouble();
            totalCashFlow += autopilotCashFlow;
          } else {
            // SETUP PHASE: Bill is due before next pay day
            // Calculate BOTH initial catch-up AND ongoing amount

            // Initial amount needed NOW
            final initialCatchUp = gap;

            // Calculate ongoing amount (for after first bill is paid)
            final ongoingPeriods = _getPayPeriodsPerAutopilot(
              _payDaySettings!.payFrequency,
              autopilotFrequency ?? 'monthly',
            );
            final ongoingAmount = ongoingPeriods > 0
                ? autopilotAmount / ongoingPeriods.toDouble()
                : autopilotAmount;


            // Store setup phase data
            _data = _data.copyWith(
              isInSetupPhase: true,
              initialCatchUpAmount: initialCatchUp,
              ongoingCashFlow: ongoingAmount,
              setupPhaseEndDate: _data.autopilotFirstDate,
              payPeriodsUntilSteadyState: ongoingPeriods,
            );

            // Use initial catch-up for current cash flow calculation
            totalCashFlow += initialCatchUp;
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
            final autopilotCashFlow = gap / periodsPerAutopilot.toDouble();
            totalCashFlow += autopilotCashFlow;
          }
        }
      } else {
        // Smart handling: gap <= 0, meaning starting amount >= bill amount
        // Calculate how many payments are covered and provide intelligent suggestions

        // First, estimate a baseline cash flow (the amount needed per pay period for the bill)
        final periodsPerAutopilot = _data.autopilotFirstDate != null
            ? _calculatePayPeriods(nextPayDate, _data.autopilotFirstDate!)
            : _getPayPeriodsPerAutopilot(
                _payDaySettings!.payFrequency,
                autopilotFrequency ?? 'monthly',
              );

        final baselineCashFlow = periodsPerAutopilot > 0
            ? autopilotAmount / periodsPerAutopilot.toDouble()
            : autopilotAmount;


        // Use existing manual override or calculate baseline
        final testCashFlow = _data.manualCashFlowOverride ?? baselineCashFlow;

        // Calculate coverage with this cash flow
        final coverage = _calculateAutopilotCoverage(
          startingAmount: startingAmount,
          billAmount: autopilotAmount,
          autopilotFrequency: autopilotFrequency ?? 'monthly',
          payPerPeriod: testCashFlow,
          firstBillDate: _data.autopilotFirstDate,
        );

        paymentsCovered = coverage['paymentsCovered'] as int;
        alwaysCovered = coverage['alwaysCovered'] as bool;
        coverageSuggestion = coverage['suggestion'] as String?;


        // Use the recommended cash flow if no manual override
        if (_data.manualCashFlowOverride == null) {
          final recommendedCashFlow = coverage['recommendedCashFlow'] as double?;
          if (recommendedCashFlow != null && recommendedCashFlow > 0) {
            totalCashFlow += recommendedCashFlow;
          }
        } else {
        }
      }
    }

    // Calculate percentage of income
    double? percentage;
    double? available;
    bool affordable = true;
    String? warning;
    bool requiresCurrentBalance = false;


    if (expectedPay > 0) {
      percentage = (totalCashFlow / expectedPay) * 100;
      // Subtract existing commitments from other envelopes
      available = expectedPay - _existingCommitments;


      // Calculate unallocated account balance (account balance - existing commitments)
      final unallocatedBalance = widget.accountBalance != null
          ? (widget.accountBalance! - _existingCommitments).clamp(0.0, double.infinity)
          : startingAmount;


      if (totalCashFlow > available) {
        // Cash flow exceeds available income per paycheck
        final shortfall = totalCashFlow - available;

        // Calculate how many paychecks worth of shortfall the unallocated balance can cover
        final payPeriodsOfCoverage = shortfall > 0 ? (unallocatedBalance / shortfall).floor() : 0;

        // Check if unallocated balance can sustain the shortfall for a reasonable period
        // We consider it affordable if it can cover at least 2-3 pay periods
        if (payPeriodsOfCoverage >= 2) {
          // Unallocated balance provides cushion for initial period
          requiresCurrentBalance = true;
          affordable = true;
          warning =
              'This requires \$${totalCashFlow.toStringAsFixed(2)} per paycheck but you only have \$${available.toStringAsFixed(2)} available after existing commitments. '
              'Your unallocated account balance (\$${unallocatedBalance.toStringAsFixed(2)}) can cover the \$${shortfall.toStringAsFixed(2)} shortfall for approximately $payPeriodsOfCoverage pay periods. '
              'Consider adjusting targets to make this sustainable long-term, or use this as a temporary bridge.';
        } else if (payPeriodsOfCoverage == 1) {
          // Only covers one period - marginal affordability
          requiresCurrentBalance = true;
          affordable = true;
          warning =
              'This requires \$${totalCashFlow.toStringAsFixed(2)} per paycheck but you only have \$${available.toStringAsFixed(2)} available after existing commitments. '
              'Your unallocated balance (\$${unallocatedBalance.toStringAsFixed(2)}) can only cover the shortfall for about 1 pay period. '
              'This plan is risky and not sustainable. Consider reducing your targets.';
        } else {
          // Not affordable - insufficient unallocated balance
          affordable = false;
          warning =
              'This requires \$${totalCashFlow.toStringAsFixed(2)} per paycheck, but you only have \$${available.toStringAsFixed(2)} available after existing commitments (\$${_existingCommitments.toStringAsFixed(2)} already committed). '
              'Your unallocated account balance (\$${unallocatedBalance.toStringAsFixed(2)}) cannot sustain this ongoing shortfall. Reduce targets or increase income.';
        }
      } else {
      }

      // Check for over-allocation (percentage mode)
      String? overAllocationWarning;
      if (horizonMode == HorizonAllocationMode.percentage && _data.horizonPercentage != null) {
        final totalPercentage = _data.horizonPercentage!;

        // Calculate percentage used by existing commitments
        final commitmentsPercentage = expectedPay > 0
            ? (_existingCommitments / expectedPay) * 100
            : 0.0;

        final totalUsed = commitmentsPercentage + totalPercentage;

        if (totalUsed > 100) {
          overAllocationWarning = 'Total allocations (${totalUsed.toStringAsFixed(0)}%) exceed available income (100%). ';

          // Check if autopilot is affected
          if (_data.autopilotEnabled && _data.autopilotFirstDate != null) {
            final daysToAutopilot = _data.autopilotFirstDate!.difference(DateTime.now()).inDays;
            if (daysToAutopilot < 7) {
              overAllocationWarning += 'Autopilot payment due in $daysToAutopilot days may be affected.';
            }
          }
        }
      }

      // Merge with existing warning
      if (overAllocationWarning != null) {
        warning = warning == null
            ? overAllocationWarning
            : '$warning\n$overAllocationWarning';
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
      'requiresCurrentBalance': requiresCurrentBalance,
      'paymentsCovered': paymentsCovered,
      'alwaysCovered': alwaysCovered,
      'coverageSuggestion': coverageSuggestion,
      // Setup phase data
      'initialCatchUpAmount': _data.initialCatchUpAmount,
      'ongoingCashFlow': _data.ongoingCashFlow,
      'isInSetupPhase': _data.isInSetupPhase,
      'setupPhaseEndDate': _data.setupPhaseEndDate,
      'payPeriodsUntilSteadyState': _data.payPeriodsUntilSteadyState,
      // Allocation data for UI clarity
      'horizonEffectiveStarting': effectiveStartingForHorizon,
      'autopilotEffectiveStarting': effectiveStartingForAutopilot,
      'autopilotBeforePayday': autopilotBeforePayday,
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

  /// Calculate projected arrival date based on pay periods needed
  DateTime _calculateProjectedDate(DateTime startDate, int payPeriods) {
    if (_payDaySettings == null || payPeriods <= 0) return startDate;

    final frequency = _payDaySettings!.payFrequency;
    DateTime projected = startDate;

    for (int i = 0; i < payPeriods; i++) {
      switch (frequency) {
        case 'weekly':
          projected = projected.add(const Duration(days: 7));
          break;
        case 'biweekly':
          projected = projected.add(const Duration(days: 14));
          break;
        case 'fourweekly':
          projected = projected.add(const Duration(days: 28));
          break;
        case 'monthly':
          projected = DateTime(projected.year, projected.month + 1, projected.day);
          break;
      }
    }

    return projected;
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

  /// Calculate smart autopilot coverage when starting amount >= bill amount
  /// Returns map with: paymentsCovered, alwaysCovered, suggestion, recommendedCashFlow
  Map<String, dynamic> _calculateAutopilotCoverage({
    required double startingAmount,
    required double billAmount,
    required String autopilotFrequency,
    required double payPerPeriod, // Cash flow added per pay period
    DateTime? firstBillDate,
  }) {

    if (_payDaySettings == null) {
      return {
        'paymentsCovered': 0,
        'alwaysCovered': false,
        'suggestion': null,
        'recommendedCashFlow': billAmount,
      };
    }

    final now = DateTime.now();
    final nextPayDate = _payDaySettings!.nextPayDate ?? now;

    // Calculate pay periods per autopilot cycle
    int payPeriodsPerBill;
    DateTime? nextBillDate;

    if (firstBillDate != null) {
      // Use actual date if provided
      payPeriodsPerBill = _calculatePayPeriods(nextPayDate, firstBillDate);
      nextBillDate = firstBillDate;
    } else {
      // Estimate based on frequency
      payPeriodsPerBill = _getPayPeriodsPerAutopilot(
        _payDaySettings!.payFrequency,
        autopilotFrequency,
      );
      // Estimate next bill date
      final daysUntilBill = _getDaysForFrequency(autopilotFrequency);
      nextBillDate = now.add(Duration(days: daysUntilBill.round()));
    }

    // Simulate balance over time to see how many payments are covered
    double balance = startingAmount;
    int paymentsCovered = 0;
    const maxPaymentsToCheck = 12; // Check up to 1 year ahead
    DateTime currentDate = nextPayDate;
    DateTime currentBillDate = nextBillDate;
    int payPeriodsUntilNextBill = payPeriodsPerBill;


    for (int payment = 0; payment < maxPaymentsToCheck; payment++) {

      // Add cash flow for pay periods until bill is due
      for (int i = 0; i < payPeriodsUntilNextBill; i++) {
        balance += payPerPeriod;
        currentDate = PayDaySettings.calculateNextPayDate(
          currentDate,
          _payDaySettings!.payFrequency,
        );
      }


      // Check if we can pay the bill
      if (balance >= billAmount) {
        balance -= billAmount;
        paymentsCovered++;
      } else {
        // Can't afford this payment
        break;
      }

      // Move to next bill cycle
      currentBillDate = _getNextAutopilotDate(currentBillDate, autopilotFrequency);
      payPeriodsUntilNextBill = _calculatePayPeriods(currentDate, currentBillDate);

      if (payPeriodsUntilNextBill <= 0) {
        payPeriodsUntilNextBill = _getPayPeriodsPerAutopilot(
          _payDaySettings!.payFrequency,
          autopilotFrequency,
        );
      }
    }

    // Determine if always covered (balance stays above bill amount after steady state)
    final alwaysCovered = paymentsCovered >= maxPaymentsToCheck;


    // Generate intelligent suggestion
    String? suggestion;
    double? recommendedCashFlow;


    if (alwaysCovered) {
      // Cash flow always keeps balance above bill amount
      // IMPORTANT: When payPeriodsPerBill is 0 (bill before next payday), use ongoing cycle estimate
      final effectivePeriodsPerBill = payPeriodsPerBill > 0
          ? payPeriodsPerBill
          : _getPayPeriodsPerAutopilot(
              _payDaySettings!.payFrequency,
              autopilotFrequency,
            );

      final optimalCashFlow = effectivePeriodsPerBill > 0
          ? billAmount / effectivePeriodsPerBill.toDouble()
          : billAmount; // Fallback if still 0


      // Check if Horizon goal exists to provide contextual message
      final hasHorizon = _data.horizonEnabled && _data.horizonAmount != null && _data.horizonAmount! > 0;

      if (payPerPeriod > optimalCashFlow) {
        if (hasHorizon) {
          suggestion = 'Autopilot needs ${optimalCashFlow.toStringAsFixed(2)}/paycheck. Your total cash flow (${payPerPeriod.toStringAsFixed(2)}) also includes savings for your Horizon goal.';
        } else {
          suggestion = 'Your balance will always exceed the bill amount. Insight recommends ${optimalCashFlow.toStringAsFixed(2)} per paycheck for optimal coverage. Consider setting up a Horizon goal to save the excess.';
        }
        recommendedCashFlow = optimalCashFlow;
      } else {
        if (hasHorizon) {
          suggestion = '✅ Balance Covered\n\n'
              '💰 Current Balance: \$${startingAmount.toStringAsFixed(2)}\n'
              '📋 Bill Amount: \$${billAmount.toStringAsFixed(2)}\n'
              '🔄 Suggested Cash Flow: \$${payPerPeriod.toStringAsFixed(2)}/paycheck\n\n'
              'Why? Your Autopilot bill needs \$${payPerPeriod.toStringAsFixed(2)} per paycheck to maintain coverage. This is included in your total cash flow calculation alongside your Horizon goal.';
        } else {
          suggestion = '✅ Balance Covered\n\n'
              '💰 Current Balance: \$${startingAmount.toStringAsFixed(2)}\n'
              '📋 Bill Amount: \$${billAmount.toStringAsFixed(2)}\n'
              '🔄 Suggested Cash Flow: \$${payPerPeriod.toStringAsFixed(2)}/paycheck\n\n'
              'Why? Your balance fully covers the bill. The suggested cash flow maintains this coverage for future payments.';
        }
        recommendedCashFlow = payPerPeriod;
      }
    } else if (paymentsCovered > 0) {
      // Covers some payments but not all
      // Use ongoing cycle estimate for recommendation
      final effectivePeriodsPerBill = payPeriodsPerBill > 0
          ? payPeriodsPerBill
          : _getPayPeriodsPerAutopilot(
              _payDaySettings!.payFrequency,
              autopilotFrequency,
            );

      recommendedCashFlow = effectivePeriodsPerBill > 0
          ? billAmount / effectivePeriodsPerBill.toDouble()
          : billAmount;


      // Create clear math breakdown
      final periodsText = effectivePeriodsPerBill == 1 ? 'paycheck' : '$effectivePeriodsPerBill paychecks';

      if (startingAmount >= billAmount * 2) {
        suggestion = '⚠️ Partial Coverage\n\n'
            '💰 Current Balance: \$${startingAmount.toStringAsFixed(2)}\n'
            '📋 Bill Amount: \$${billAmount.toStringAsFixed(2)}\n'
            '✅ Covers: $paymentsCovered payment(s)\n'
            '🔄 Suggested Cash Flow: \$${recommendedCashFlow.toStringAsFixed(2)}/paycheck\n\n'
            'Why? You have approximately $periodsText between bills. \$${billAmount.toStringAsFixed(2)} ÷ $effectivePeriodsPerBill = \$${recommendedCashFlow.toStringAsFixed(2)} per paycheck maintains coverage.\n\n'
            '💡 Tip: Your balance is high - consider a manual payment to reduce excess if desired.';
      } else {
        suggestion = '⚠️ Partial Coverage\n\n'
            '💰 Current Balance: \$${startingAmount.toStringAsFixed(2)}\n'
            '📋 Bill Amount: \$${billAmount.toStringAsFixed(2)}\n'
            '✅ Covers: $paymentsCovered payment(s)\n'
            '🔄 Suggested Cash Flow: \$${recommendedCashFlow.toStringAsFixed(2)}/paycheck\n\n'
            'Why? You have approximately $periodsText between bills. \$${billAmount.toStringAsFixed(2)} ÷ $effectivePeriodsPerBill = \$${recommendedCashFlow.toStringAsFixed(2)} per paycheck maintains coverage.';
      }
    } else {
      // No payments covered or starting amount equals bill amount exactly
      // Use ongoing cycle estimate for recommendation
      final effectivePeriodsPerBill = payPeriodsPerBill > 0
          ? payPeriodsPerBill
          : _getPayPeriodsPerAutopilot(
              _payDaySettings!.payFrequency,
              autopilotFrequency,
            );

      recommendedCashFlow = effectivePeriodsPerBill > 0
          ? billAmount / effectivePeriodsPerBill.toDouble()
          : billAmount;


      if (startingAmount == billAmount) {
        if (firstBillDate != null) {
          final isBeforePayday = firstBillDate.isBefore(nextPayDate);
          final periodsText = effectivePeriodsPerBill == 1 ? 'paycheck' : '$effectivePeriodsPerBill paychecks';

          if (isBeforePayday) {
            suggestion = '⚠️ Bill Due Before Payday\n\n'
                '💰 Current Balance: \$${startingAmount.toStringAsFixed(2)}\n'
                '📋 Bill Amount: \$${billAmount.toStringAsFixed(2)}\n'
                '📅 Bill Date: ${firstBillDate.day}/${firstBillDate.month}/${firstBillDate.year}\n'
                '🔄 Suggested Cash Flow: \$${recommendedCashFlow.toStringAsFixed(2)}/paycheck\n\n'
                'Why? After the first bill pays, you\'ll have $periodsText between payments. \$${billAmount.toStringAsFixed(2)} ÷ $effectivePeriodsPerBill = \$${recommendedCashFlow.toStringAsFixed(2)} per paycheck.';
          } else {
            suggestion = '✅ Ready for First Payment\n\n'
                '💰 Current Balance: \$${startingAmount.toStringAsFixed(2)}\n'
                '📋 Bill Amount: \$${billAmount.toStringAsFixed(2)}\n'
                '🔄 Suggested Cash Flow: \$${recommendedCashFlow.toStringAsFixed(2)}/paycheck\n\n'
                'Why? You\'ll have $periodsText to rebuild after payment. \$${billAmount.toStringAsFixed(2)} ÷ $effectivePeriodsPerBill = \$${recommendedCashFlow.toStringAsFixed(2)} per paycheck.';
          }
        } else {
          suggestion = '✅ Exact Amount\n\n'
              '💰 Current Balance: \$${startingAmount.toStringAsFixed(2)}\n'
              '📋 Bill Amount: \$${billAmount.toStringAsFixed(2)}\n'
              '🔄 Suggested Cash Flow: \$${recommendedCashFlow.toStringAsFixed(2)}/paycheck\n\n'
              'Why? You have exactly enough for the next payment. The suggested cash flow maintains coverage for future bills.';
        }
      } else {
        final gap = billAmount - startingAmount;
        suggestion = '❌ Insufficient Balance\n\n'
            '💰 Current Balance: \$${startingAmount.toStringAsFixed(2)}\n'
            '📋 Bill Amount: \$${billAmount.toStringAsFixed(2)}\n'
            '⚠️ Shortfall: \$${gap.toStringAsFixed(2)}\n\n'
            'You need \$${gap.toStringAsFixed(2)} more before the first payment. Consider adding funds or adjusting the bill amount.';
      }
    }


    return {
      'paymentsCovered': paymentsCovered,
      'alwaysCovered': alwaysCovered,
      'suggestion': suggestion,
      'recommendedCashFlow': recommendedCashFlow,
    };
  }

  /// Get the next autopilot date based on frequency
  DateTime _getNextAutopilotDate(DateTime currentDate, String frequency) {
    switch (frequency) {
      case 'weekly':
        return currentDate.add(const Duration(days: 7));
      case 'biweekly':
        return currentDate.add(const Duration(days: 14));
      case 'fourweekly':
        return currentDate.add(const Duration(days: 28));
      case 'monthly':
        // Add one month
        final year = currentDate.month == 12 ? currentDate.year + 1 : currentDate.year;
        final month = currentDate.month == 12 ? 1 : currentDate.month + 1;
        return DateTime(year, month, currentDate.day);
      case 'yearly':
        return DateTime(currentDate.year + 1, currentDate.month, currentDate.day);
      default:
        return currentDate.add(const Duration(days: 30));
    }
  }

  /// Get days for a given frequency (for estimation)
  double _getDaysForFrequency(String frequency) {
    switch (frequency) {
      case 'weekly':
        return 7.0;
      case 'biweekly':
        return 14.0;
      case 'fourweekly':
        return 28.0;
      case 'monthly':
        return 30.44;
      case 'yearly':
        return 365.25;
      default:
        return 30.44;
    }
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
      helpText: 'Select payment date',
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
    _percentageCtrl.dispose();
    _fixedAmountCtrl.dispose();
    _horizonAmountFocus.dispose();
    _autopilotAmountFocus.dispose();
    _manualCashFlowFocus.dispose();
    _percentageFocus.dispose();
    _fixedAmountFocus.dispose();
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
            const SizedBox(height: 8),
            _buildInfoRow(
              'Expected Income:',
              '${localeProvider.currencySymbol}${expectedPay.toStringAsFixed(2)}',
              fontProvider,
            ),
            if (_existingCommitments > 0)
              _buildInfoRow(
                'Existing Commitments:',
                '${localeProvider.currencySymbol}${_existingCommitments.toStringAsFixed(2)}',
                fontProvider,
                isWarning: true,
              ),
            _buildInfoRow(
              'Available per Paycheck:',
              '${localeProvider.currencySymbol}${(expectedPay - _existingCommitments).toStringAsFixed(2)}',
              fontProvider,
              isHighlight: true,
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            if (widget.accountBalance != null) ...[
              _buildInfoRow(
                'Current Account Balance:',
                '${localeProvider.currencySymbol}${widget.accountBalance!.toStringAsFixed(2)}',
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
                  softWrap: true,
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
              helperText: 'Your savings goal (required for cash flow calculation)',
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
          // Mode toggle (three-way)
          SegmentedButton<HorizonAllocationMode>(
            segments: [
              const ButtonSegment(
                value: HorizonAllocationMode.date,
                label: Text('Date'),
                icon: Icon(Icons.event, size: 16),
              ),
              ButtonSegment(
                value: HorizonAllocationMode.fixedAmount,
                label: Text(localeProvider.currencySymbol),
              ),
              const ButtonSegment(
                value: HorizonAllocationMode.percentage,
                label: Text('%'),
              ),
            ],
            selected: {_horizonMode},
            onSelectionChanged: (Set<HorizonAllocationMode> selection) {
              setState(() {
                final previousMode = _horizonMode;
                _horizonMode = selection.first;
                _data = _data.copyWith(horizonMode: _horizonMode);

                // Mode conversion logic
                if (_payDaySettings?.expectedPayAmount != null) {
                  final availIncome = _payDaySettings!.expectedPayAmount! - _existingCommitments;

                  if (_horizonMode == HorizonAllocationMode.percentage) {
                    // Converting TO percentage mode
                    if (previousMode == HorizonAllocationMode.fixedAmount && _data.horizonFixedAmount != null && availIncome > 0) {
                      // From fixedAmount: use the user's fixed amount input
                      final percentage = (_data.horizonFixedAmount! / availIncome) * 100;
                      _data = _data.copyWith(horizonPercentage: percentage);
                      _percentageCtrl.text = percentage.toStringAsFixed(1);
                    } else if (previousMode == HorizonAllocationMode.date && _data.calculatedCashFlow != null && _data.horizonAmount != null && availIncome > 0) {
                      // From date: use calculated cash flow to determine percentage
                      // ONLY if there was a horizon target set (otherwise calculatedCashFlow is just autopilot)
                      final percentage = (_data.calculatedCashFlow! / availIncome) * 100;
                      _data = _data.copyWith(horizonPercentage: percentage);
                      _percentageCtrl.text = percentage.toStringAsFixed(1);
                    }
                  } else if (_horizonMode == HorizonAllocationMode.fixedAmount) {
                    // Converting TO fixed amount mode
                    if (previousMode == HorizonAllocationMode.percentage && _data.horizonPercentage != null && availIncome > 0) {
                      // From percentage: calculate dollar amount
                      final amount = (availIncome * _data.horizonPercentage!) / 100;
                      // Store this in horizonFixedAmount (user's input field)
                      _data = _data.copyWith(horizonFixedAmount: amount);
                      _fixedAmountCtrl.text = amount.toStringAsFixed(2);
                    } else if (previousMode == HorizonAllocationMode.date && _data.calculatedCashFlow != null && _data.horizonAmount != null) {
                      // From date: use the calculated cash flow from the date mode
                      // ONLY if there was a horizon target set (otherwise calculatedCashFlow is just autopilot)
                      _data = _data.copyWith(horizonFixedAmount: _data.calculatedCashFlow);
                      _fixedAmountCtrl.text = _data.calculatedCashFlow!.toStringAsFixed(2);
                    }
                    _data = _data.copyWith(
                      horizonPercentage: null,
                      projectedArrivalDate: null,
                    );
                  } else if (_horizonMode == HorizonAllocationMode.date) {
                    // Converting TO date mode
                    // Keep existing cash flow calculation, it will be recalculated
                    _data = _data.copyWith(
                      horizonPercentage: null,
                      horizonFixedAmount: null,
                      projectedArrivalDate: null,
                    );
                  }
                }

                _recalculate();
              });
            },
          ),
          // Context-specific input field based on mode
          if (_horizonMode == HorizonAllocationMode.date) ...[
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
                            'Horizon Date',
                            style: fontProvider.getTextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _data.horizonDate == null
                                ? 'Tap to set target date'
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
          if (_horizonMode == HorizonAllocationMode.fixedAmount) ...[
            const SizedBox(height: 12),
            SmartTextField(
              controller: _fixedAmountCtrl,
              focusNode: _fixedAmountFocus,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) {
                final amount = double.tryParse(value);
                _data = _data.copyWith(horizonFixedAmount: amount);
                _recalculate();
              },
              decoration: InputDecoration(
                labelText: 'Fixed Amount per Payday',
                hintText: '0.00',
                prefixText: localeProvider.currencySymbol,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
          if (_horizonMode == HorizonAllocationMode.percentage) ...[
            const SizedBox(height: 12),
            SmartTextField(
              controller: _percentageCtrl,
              focusNode: _percentageFocus,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) {
                final percentage = double.tryParse(value);
                _data = _data.copyWith(horizonPercentage: percentage);
                _recalculate();
              },
              decoration: InputDecoration(
                labelText: '% of Available Income (after existing commitments)',
                hintText: '0.0',
                suffixText: '%',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
          // Display enriched arrival info for all modes
          if (_data.projectedArrivalDate != null && _data.calculatedCashFlow != null && _data.payPeriodsToHorizon != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.timeline, size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _horizonMode == HorizonAllocationMode.percentage
                              ? '${_data.horizonPercentage?.toStringAsFixed(1) ?? '0'}% (${localeProvider.currencySymbol}${_data.calculatedCashFlow!.toStringAsFixed(2)}) per payday'
                              : '${localeProvider.currencySymbol}${_data.calculatedCashFlow!.toStringAsFixed(2)} per payday',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const SizedBox(width: 24),
                      Text(
                        '@ ${_data.payPeriodsToHorizon} paydays = arrives ${_data.projectedArrivalDate!.day}/${_data.projectedArrivalDate!.month}/${_data.projectedArrivalDate!.year}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
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
                          'Payment Date',
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

                // STARTING AMOUNT ALLOCATION (show when both goals exist)
                if (_data.horizonEnabled &&
                    _data.horizonAmount != null &&
                    _data.horizonAmount! > 0 &&
                    _data.autopilotEnabled &&
                    _data.autopilotAmount != null &&
                    _data.autopilotAmount! > 0 &&
                    widget.startingAmount != null &&
                    widget.startingAmount! > 0) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.account_balance_wallet,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Starting Amount Allocation',
                              style: fontProvider.getTextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        () {
                          // Determine allocation based on autopilot date
                          final hasAutopilotDate = _data.autopilotFirstDate != null;
                          final nextPayDate = _payDaySettings?.nextPayDate;
                          final autopilotBeforePayday = hasAutopilotDate &&
                              nextPayDate != null &&
                              _data.autopilotFirstDate!.isBefore(nextPayDate);

                          if (autopilotBeforePayday) {
                            return Text(
                              '${localeProvider.currencySymbol}${widget.startingAmount!.toStringAsFixed(2)} → ⚡ Autopilot (bill due before payday)\nHorizon calculation starts from \$0',
                              style: fontProvider.getTextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface,
                              ),
                            );
                          } else {
                            return Text(
                              '${localeProvider.currencySymbol}${widget.startingAmount!.toStringAsFixed(2)} → Both goals use this amount in their calculations',
                              style: fontProvider.getTextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface,
                              ),
                            );
                          }
                        }(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

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
                    '${localeProvider.currencySymbol}${_data.autopilotAmount!.toStringAsFixed(2)}',
                    fontProvider,
                  ),
                  if (_data.autopilotFirstDate != null)
                    _buildCalculationRow(
                      '   Due date:',
                      '${_data.autopilotFirstDate!.day}/${_data.autopilotFirstDate!.month}/${_data.autopilotFirstDate!.year}',
                      fontProvider,
                      isSubItem: true,
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
                    // SETUP PHASE: Show both NOW and NEXT amounts
                    if (_data.isInSetupPhase &&
                        _data.initialCatchUpAmount != null &&
                        _data.ongoingCashFlow != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.secondary.withValues(alpha: 0.5),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.rocket_launch,
                                  color: theme.colorScheme.secondary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '🔄 SETUP PHASE',
                                  style: fontProvider.getTextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.secondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // NOW amount
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    '💰 Initial Payment (NOW):',
                                    style: fontProvider.getTextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${localeProvider.currencySymbol}${_data.initialCatchUpAmount!.toStringAsFixed(2)}',
                                  style: fontProvider.getTextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // NEXT amount
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    '🔄 After First Bill (ONGOING):',
                                    style: fontProvider.getTextStyle(
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${localeProvider.currencySymbol}${_data.ongoingCashFlow!.toStringAsFixed(2)}/paycheck',
                                  style: fontProvider.getTextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.secondary,
                                  ),
                                ),
                              ],
                            ),
                            if (_data.setupPhaseEndDate != null) ...[
                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 8),
                              // Math breakdown
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '📊 The Math:',
                                      style: fontProvider.getTextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Bill Amount: ${localeProvider.currencySymbol}${_data.autopilotAmount?.toStringAsFixed(2) ?? '0.00'}',
                                      style: fontProvider.getTextStyle(
                                        fontSize: 11,
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                                      ),
                                    ),
                                    Text(
                                      'Pay Frequency: ${_payDaySettings?.payFrequency ?? 'N/A'}',
                                      style: fontProvider.getTextStyle(
                                        fontSize: 11,
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                                      ),
                                    ),
                                    if (_data.payPeriodsUntilSteadyState != null) ...[
                                      Text(
                                        'Paychecks per cycle: ${_data.payPeriodsUntilSteadyState}',
                                        style: fontProvider.getTextStyle(
                                          fontSize: 11,
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                                        ),
                                      ),
                                      Text(
                                        '${localeProvider.currencySymbol}${_data.autopilotAmount?.toStringAsFixed(2) ?? '0.00'} ÷ ${_data.payPeriodsUntilSteadyState} = ${localeProvider.currencySymbol}${_data.ongoingCashFlow!.toStringAsFixed(2)}/paycheck',
                                        style: fontProvider.getTextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.secondary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.notification_important,
                                    size: 16,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'After bill payment on ${_data.setupPhaseEndDate!.day}/${_data.setupPhaseEndDate!.month}/${_data.setupPhaseEndDate!.year}, Insight will notify you to adjust cash flow to ${localeProvider.currencySymbol}${_data.ongoingCashFlow!.toStringAsFixed(2)}. You\'ll be able to accept, keep current, or adjust manually.',
                                      style: fontProvider.getTextStyle(
                                        fontSize: 11,
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ] else ...[
                      _buildCalculationRow(
                        '   ⚠️ Due before next payday!',
                        'Need full amount now',
                        fontProvider,
                        isSubItem: true,
                      ),
                    ],
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

                // BREAKDOWN (when both goals exist)
                if (_data.horizonEnabled &&
                    _data.horizonAmount != null &&
                    _data.horizonAmount! > 0 &&
                    _data.autopilotEnabled &&
                    _data.autopilotAmount != null &&
                    _data.autopilotAmount! > 0 &&
                    _data.calculatedCashFlow != null &&
                    _data.calculatedCashFlow! > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: () {
                      // Calculate components
                      final horizonGap = _data.horizonAmount! - (widget.startingAmount ?? 0.0);
                      final horizonComponent = _data.payPeriodsToHorizon != null &&
                                                _data.payPeriodsToHorizon! > 0 &&
                                                horizonGap > 0
                          ? horizonGap / _data.payPeriodsToHorizon!.toDouble()
                          : 0.0;

                      final autopilotComponent = _data.calculatedCashFlow! - horizonComponent;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Breakdown:',
                            style: fontProvider.getTextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (horizonComponent > 0)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '🎯 Horizon',
                                  style: fontProvider.getTextStyle(fontSize: 11),
                                ),
                                Text(
                                  '${localeProvider.currencySymbol}${horizonComponent.toStringAsFixed(2)}',
                                  style: fontProvider.getTextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          if (autopilotComponent > 0)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '⚡ Autopilot',
                                  style: fontProvider.getTextStyle(fontSize: 11),
                                ),
                                Text(
                                  '${localeProvider.currencySymbol}${autopilotComponent.toStringAsFixed(2)}',
                                  style: fontProvider.getTextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      );
                    }(),
                  ),
                ],

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
                            softWrap: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Coverage suggestion (smart autopilot analysis)
                if (_data.coverageSuggestion != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Insight Analysis',
                                style: fontProvider.getTextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _data.coverageSuggestion!,
                                style: fontProvider.getTextStyle(
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurface,
                                ),
                                softWrap: true,
                              ),
                              if (_data.autopilotPaymentsCovered != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Payments covered: ${_data.autopilotPaymentsCovered}${_data.autopilotAlwaysCovered == true ? '+ (ongoing)' : ''}',
                                  style: fontProvider.getTextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ],
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
