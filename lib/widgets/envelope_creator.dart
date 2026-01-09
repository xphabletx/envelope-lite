// lib/widgets/envelope_creator.dart
// FONT PROVIDER INTEGRATED: All GoogleFonts.caveat() replaced with FontProvider
// All button text wrapped in FittedBox to prevent wrapping

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/envelope_repo.dart';
import '../services/group_repo.dart';
import '../services/account_repo.dart';
import '../services/error_handler_service.dart';
import '../models/envelope_group.dart';
import '../models/envelope.dart';
import '../models/account.dart';
import '../models/app_error.dart';
import '../widgets/group_editor.dart' as editor;
import '../services/scheduled_payment_repo.dart';
import '../models/scheduled_payment.dart';
import '../services/localization_service.dart';
import '../providers/font_provider.dart';
import '../providers/time_machine_provider.dart';
import 'envelope/omni_icon_picker_modal.dart';
import '../providers/theme_provider.dart';
import '../theme/app_themes.dart';
import '../utils/calculator_helper.dart';
import 'common/smart_text_field.dart';
import '../models/creation_context.dart';
import '../models/insight_data.dart';
import 'insight_tile.dart';
import 'binder/template_envelope_selector.dart';
import '../data/binder_templates.dart';

// FULL SCREEN DIALOG IMPLEMENTATION
Future<void> showEnvelopeCreator(
  BuildContext context, {
  required EnvelopeRepo repo,
  required GroupRepo groupRepo,
  required AccountRepo accountRepo,
  required String userId,
  String? preselectedBinderId,
  CreationContext? creationContext,
}) async {
  await Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _EnvelopeCreatorScreen(
        repo: repo,
        groupRepo: groupRepo,
        accountRepo: accountRepo,
        userId: userId,
        preselectedBinderId: preselectedBinderId,
        creationContext: creationContext,
      ),
    ),
  );
}

class _EnvelopeCreatorScreen extends StatefulWidget {
  const _EnvelopeCreatorScreen({
    required this.repo,
    required this.groupRepo,
    required this.accountRepo,
    required this.userId,
    this.preselectedBinderId,
    this.creationContext,
  });
  final EnvelopeRepo repo;
  final GroupRepo groupRepo;
  final AccountRepo accountRepo;
  final String userId;
  final String? preselectedBinderId;
  final CreationContext? creationContext;

  @override
  State<_EnvelopeCreatorScreen> createState() => _EnvelopeCreatorScreenState();
}

class _EnvelopeCreatorScreenState extends State<_EnvelopeCreatorScreen> {
  final _formKey = GlobalKey<FormState>();

  // Constant for pending binder draft logic
  static const String _pendingBinderId = 'PENDING_NEW_BINDER';

  // Controllers
  final _nameCtrl = TextEditingController();
  final _amtCtrl = TextEditingController(text: '0.00');
  final _targetCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  final _cashFlowAmountCtrl = TextEditingController();

  // Focus nodes
  final _nameFocus = FocusNode();
  final _amountFocus = FocusNode();
  final _targetFocus = FocusNode();
  final _subtitleFocus = FocusNode();
  final _cashFlowAmountFocus = FocusNode();

  // Target date
  DateTime? _targetDate;

  // Cash flow state
  bool _cashFlowEnabled = true; // Default to enabled to match InsightData default
  bool _addScheduledPayment = false;

  // Store full insight data for autopilot
  InsightData? _insightData;

  // Binder selection state
  String? _selectedBinderId;
  List<EnvelopeGroup> _binders = [];
  bool _bindersLoaded = false;

  // Account selection state
  String? _selectedAccountId;
  List<Account> _accounts = [];
  bool _accountsLoaded = false;
  bool _hasAccounts = false; // Track if user has any accounts

  // Icon selection state
  String? _iconType;
  String? _iconValue;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Priority: explicit preselectedBinderId > creationContext.preselectedBinderId
    _selectedBinderId = widget.preselectedBinderId ??
                        widget.creationContext?.preselectedBinderId;

    // If we have a pending binder name (creating envelope inside a new binder),
    // select the pending binder option
    if (widget.creationContext?.hasPendingBinder == true) {
      _selectedBinderId = _pendingBinderId;
    }

    _loadBinders();
    _loadAccounts();

    // REMOVED: Auto-focus on name field - user must tap to open keyboard
    // This follows the global keyboard UX pattern

    _amountFocus.addListener(() {
      if (_amountFocus.hasFocus) {
        _amtCtrl.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _amtCtrl.text.length,
        );
      }
    });

    _targetFocus.addListener(() {
      if (_targetFocus.hasFocus) {
        _targetCtrl.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _targetCtrl.text.length,
        );
      }
    });

    _cashFlowAmountFocus.addListener(() {
      if (_cashFlowAmountFocus.hasFocus) {
        _cashFlowAmountCtrl.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _cashFlowAmountCtrl.text.length,
        );
      }
    });
  }

  Future<void> _loadBinders() async {
    try {
      // Use getAllGroupsAsync to read from Hive (works in both solo and workspace mode)
      final allBinders = await widget.groupRepo.getAllGroupsAsync();

      setState(() {
        _binders = allBinders
          ..sort((a, b) => a.name.compareTo(b.name));
        _bindersLoaded = true;
      });
    } catch (e) {
      debugPrint('Error loading binders: $e');
      setState(() => _bindersLoaded = true);
    }
  }

  Future<void> _loadAccounts() async {
    try {
      final allAccounts = await widget.accountRepo.accountsStream().first;

      setState(() {
        _accounts = allAccounts..sort((a, b) => a.name.compareTo(b.name));
        _hasAccounts = allAccounts.isNotEmpty;
        _accountsLoaded = true;

        // ACCOUNT MODE: Pre-select default account if accounts exist
        // If only one account, it's auto-selected
        // If multiple accounts, default account is pre-selected
        if (_hasAccounts) {
          final defaultAccount = allAccounts.firstWhere(
            (a) => a.isDefault,
            orElse: () => allAccounts.first,
          );
          _selectedAccountId = defaultAccount.id;
        }
      });
    } catch (e) {
      debugPrint('Error loading accounts: $e');
      setState(() => _accountsLoaded = true);
    }
  }

  Future<void> _createNewBinder() async {
    // Create context for creating a binder inside an envelope creator
    // This will show the current envelope name as a selectable option in the binder
    final context = _nameCtrl.text.isNotEmpty
        ? CreationContext.forBinderInsideEnvelope(_nameCtrl.text)
        : null;

    // Capture the newBinderId returned by the editor
    final newBinderId = await editor.showGroupEditor(
      context: this.context,
      groupRepo: widget.groupRepo,
      envelopeRepo: widget.repo,
      creationContext: context,
    );

    // Reload binders after creation to ensure the list is up to date
    await _loadBinders();

    // If a new binder was successfully created and an ID returned, select it
    if (newBinderId != null && mounted) {
      setState(() {
        _selectedBinderId = newBinderId;
      });
    }
  }

  Future<void> _pickIcon() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OmniIconPickerModal(
        initialQuery: _nameCtrl.text.trim(), // Pre-populate with envelope name
      ),
    );

    if (result != null) {
      final iconType = result['type'] as String;
      final iconValue = result['value'] as String;

      setState(() {
        _iconType = iconType;
        _iconValue = iconValue;
      });
    }
  }

  Future<void> _pickFromTemplate() async {
    // Navigate to template selector (which allows selecting from ANY template)
    final selectedEnvelopes = await Navigator.push<Map<String, Set<String>>>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => TemplateEnvelopeSelector(
          userId: widget.userId,
          singleSelectionMode: true, // Only allow selecting one envelope
        ),
      ),
    );

    if (selectedEnvelopes == null || selectedEnvelopes.isEmpty || !mounted) {
      return;
    }

    // User selected envelope(s) from templates
    // For envelope creator, we'll use the first selected envelope to populate the form
    String? firstTemplateId;
    String? firstEnvelopeId;

    for (final entry in selectedEnvelopes.entries) {
      if (entry.value.isNotEmpty) {
        firstTemplateId = entry.key;
        firstEnvelopeId = entry.value.first;
        break;
      }
    }

    if (firstTemplateId == null || firstEnvelopeId == null) return;

    // Find the template and envelope
    final template = binderTemplates.firstWhere((t) => t.id == firstTemplateId);
    final templateEnvelope = template.envelopes.firstWhere((e) => e.id == firstEnvelopeId);

    // Populate form fields with template data
    setState(() {
      _nameCtrl.text = templateEnvelope.name;
      _iconType = 'emoji';
      _iconValue = templateEnvelope.emoji;

      if (templateEnvelope.defaultAmount != null) {
        _amtCtrl.text = templateEnvelope.defaultAmount!.toStringAsFixed(2);
      }
    });
  }

  Widget _buildIconPreview(ThemeData theme) {
    // If no icon selected yet, show default
    if (_iconType == null || _iconValue == null) {
      return Image.asset(
        'assets/default/stufficon.png',
        width: 40,
        height: 40,
      );
    }

    // Create a temporary envelope to render the icon
    final tempEnvelope = Envelope(
      id: '',
      name: '',
      userId: '',
      iconType: _iconType,
      iconValue: _iconValue,
      iconColor: null,
    );

    return SizedBox(
      width: 40,
      height: 40,
      child: tempEnvelope.getIconWidget(theme, size: 40),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amtCtrl.dispose();
    _targetCtrl.dispose();
    _subtitleCtrl.dispose();
    _cashFlowAmountCtrl.dispose();
    _nameFocus.dispose();
    _amountFocus.dispose();
    _targetFocus.dispose();
    _subtitleFocus.dispose();
    _cashFlowAmountFocus.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    // Check if time machine mode is active - block modifications
    final timeMachine = Provider.of<TimeMachineProvider>(context, listen: false);
    if (timeMachine.shouldBlockModifications()) {
      ErrorHandler.showWarning(
        context,
        timeMachine.getBlockedActionMessage(),
      );
      return;
    }

    if (_saving) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final name = _nameCtrl.text.trim();
    final subtitle = _subtitleCtrl.text.trim();

    // Check for duplicate envelope names (only check current user's envelopes)
    final allEnvelopes = await widget.repo.envelopesStream(showPartnerEnvelopes: false).first;
    final existingEnvelopes = allEnvelopes
        .where((e) => e.userId == widget.repo.currentUserId)
        .toList();
    final duplicateName = existingEnvelopes.any((e) =>
      e.name.trim().toLowerCase() == name.toLowerCase()
    );

    if (duplicateName) {
      if (!mounted) return;
      await ErrorHandler.handle(
        context,
        AppError.business(
          code: 'DUPLICATE_ENVELOPE_NAME',
          userMessage: 'An envelope named "$name" already exists. Please choose a different name.',
          severity: ErrorSeverity.medium,
        ),
      );
      setState(() => _saving = false);
      return;
    }

    // starting amount
    double start = 0.0;
    final rawStart = _amtCtrl.text.trim();
    if (rawStart.isNotEmpty) {
      final parsed = double.tryParse(rawStart);
      if (parsed == null || parsed < 0) {
        if (!mounted) return;
        await ErrorHandler.handle(
          context,
          AppError.medium(
            code: 'INVALID_STARTING_AMOUNT',
            userMessage: tr('error_invalid_starting_amount'),
            category: ErrorCategory.validation,
          ),
        );
        return;
      }
      start = parsed;
    }

    // target
    double? target;
    final rawTarget = _targetCtrl.text.trim();
    if (rawTarget.isNotEmpty) {
      final parsed = double.tryParse(rawTarget);
      if (parsed == null || parsed < 0) {
        if (!mounted) return;
        await ErrorHandler.handle(
          context,
          AppError.medium(
            code: 'INVALID_TARGET',
            userMessage: tr('error_invalid_target'),
            category: ErrorCategory.validation,
          ),
        );
        return;
      }
      target = parsed;
    }

    // Validate: target date requires target amount
    if (_targetDate != null && (target == null || target <= 0)) {
      if (!mounted) return;
      await ErrorHandler.handle(
        context,
        AppError.medium(
          code: 'HORIZON_DATE_REQUIRES_GOAL',
          userMessage: 'Horizon date requires a horizon goal. Please enter a horizon goal to set a deadline.',
          category: ErrorCategory.validation,
        ),
      );
      return;
    }

    // CRITICAL VALIDATION: Account Mode enforcement
    // If user has accounts, they MUST link the envelope to an account (regardless of Cash Flow)
    if (_hasAccounts && _selectedAccountId == null) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) {
          final fontProvider = Provider.of<FontProvider>(context, listen: false);
          return AlertDialog(
            title: Text(
              'Account Link Required',
              style: fontProvider.getTextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'You have accounts configured, so all envelopes must be linked to an account.\n\n'
              'Please select an account from the dropdown above, or delete all accounts to use Budget Mode.',
              style: fontProvider.getTextStyle(fontSize: 16),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Go Back',
                  style: fontProvider.getTextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      );
      return;
    }

    // Cash flow amount
    double? cashFlowAmount;
    if (_cashFlowEnabled) {
      final rawCashFlow = _cashFlowAmountCtrl.text.trim();
      if (rawCashFlow.isEmpty) {
        if (!mounted) return;
        await ErrorHandler.handle(
          context,
          AppError.medium(
            code: 'AUTOFILL_AMOUNT_REQUIRED',
            userMessage: tr('error_autofill_amount_required'),
            category: ErrorCategory.validation,
          ),
        );
        return;
      }
      final parsed = double.tryParse(rawCashFlow);
      if (parsed == null || parsed <= 0) {
        if (!mounted) return;
        await ErrorHandler.handle(
          context,
          AppError.medium(
            code: 'INVALID_AUTOFILL',
            userMessage: tr('error_invalid_autofill'),
            category: ErrorCategory.validation,
          ),
        );
        return;
      }
      cashFlowAmount = parsed;
    }

    setState(() => _saving = true);

    try {
      // If the pending binder is selected, don't assign a groupId yet
      // The binder creator will handle adding this envelope after it's created
      final actualBinderId = _selectedBinderId == _pendingBinderId
          ? null
          : _selectedBinderId;

      final envelopeId = await widget.repo.createEnvelope(
        name: name,
        startingAmount: start,
        targetAmount: target,
        targetDate: _targetDate,
        subtitle: subtitle.isEmpty ? null : subtitle,
        emoji: null, // OLD, DEPRECATED
        iconType: _iconType,
        iconValue: _iconValue,
        cashFlowEnabled: _cashFlowEnabled,
        cashFlowAmount: cashFlowAmount,
        groupId: actualBinderId,
        linkedAccountId: _selectedAccountId,
      );

      if (!mounted) return;

      // AUTO-CREATE SCHEDULED PAYMENT if autopilot is enabled
      final shouldCreateAutopilot = _addScheduledPayment && _insightData != null && _insightData!.autopilotAmount != null;
      if (shouldCreateAutopilot) {
        await _createAutopilotPayment(envelopeId, _insightData!);
      }

      if (!mounted) return;
      Navigator.of(context).pop();

      // Show success message with autopilot info if applicable
      if (shouldCreateAutopilot) {
        ErrorHandler.showSuccess(
          context,
          '${tr('success_envelope_created')}\n\n⚡ Autopilot payment scheduled! You can adjust settings in the Calendar.',
        );
      } else {
        ErrorHandler.showSuccess(context, tr('success_envelope_created'));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      await ErrorHandler.handle(context, e);
    }
  }

  Future<void> _createAutopilotPayment(String envelopeId, InsightData insightData) async {
    try {
      // Create scheduled payment repo
      final scheduledPaymentRepo = ScheduledPaymentRepo(widget.userId);

      // Map frequency from insight format to scheduled payment format
      PaymentFrequencyUnit frequencyUnit;
      int frequencyValue;

      switch (insightData.autopilotFrequency) {
        case 'weekly':
          frequencyUnit = PaymentFrequencyUnit.weeks;
          frequencyValue = 1;
          break;
        case 'biweekly':
          frequencyUnit = PaymentFrequencyUnit.weeks;
          frequencyValue = 2;
          break;
        case 'fourweekly':
          frequencyUnit = PaymentFrequencyUnit.weeks;
          frequencyValue = 4;
          break;
        case 'monthly':
          frequencyUnit = PaymentFrequencyUnit.months;
          frequencyValue = 1;
          break;
        case 'yearly':
          frequencyUnit = PaymentFrequencyUnit.years;
          frequencyValue = 1;
          break;
        default:
          frequencyUnit = PaymentFrequencyUnit.months;
          frequencyValue = 1;
      }

      // Determine start date - use first date if set, otherwise use today + frequency
      final startDate = insightData.autopilotFirstDate ??
        DateTime.now().add(Duration(days: frequencyValue * (frequencyUnit == PaymentFrequencyUnit.weeks ? 7 : 30)));

      // Create the scheduled payment
      await scheduledPaymentRepo.createScheduledPayment(
        envelopeId: envelopeId,
        name: _nameCtrl.text.trim(),
        description: 'Autopilot payment',
        amount: insightData.autopilotAmount!,
        startDate: startDate,
        frequencyValue: frequencyValue,
        frequencyUnit: frequencyUnit,
        colorName: 'Autopilot',
        colorValue: 0xFF9C27B0, // Purple color for autopilot
        isAutomatic: insightData.autopilotAutoExecute,
        paymentType: ScheduledPaymentType.fixedAmount,
      );

      debugPrint('✅ Autopilot scheduled payment created for envelope: $envelopeId');
    } catch (e) {
      debugPrint('❌ Error creating autopilot payment: $e');
      // Don't throw - we don't want to block envelope creation if autopilot fails
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context);

    // FIX 1 & 2: Use Scaffold with standard AppBar to fix status bar overlap
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false, // We use custom action for 'X'
        title: Row(
          children: [
            Icon(
              Icons.mail_outline,
              size: 28,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 16),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  tr('envelope_new'),
                  style: fontProvider.getTextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  physics: const ClampingScrollPhysics(),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Template selector button
                        OutlinedButton.icon(
                          onPressed: _pickFromTemplate,
                          icon: const Icon(Icons.auto_awesome),
                          label: Text(
                            'Pick from Template',
                            style: fontProvider.getTextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Name field
                        SmartTextFormField(
                          controller: _nameCtrl,
                          focusNode: _nameFocus,
                          nextFocusNode: _subtitleFocus,
                          textCapitalization: TextCapitalization.words,
                          autocorrect: false,
                          style: fontProvider.getTextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            labelText: tr('envelope_name'),
                            labelStyle: fontProvider.getTextStyle(fontSize: 18),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.mail),
                            // FIX 3: Added contentPadding to prevent label cut-off with large fonts
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 20,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return tr('error_enter_name');
                            }
                            return null;
                          },
                          onTap: () => _nameCtrl.selection = TextSelection(
                            baseOffset: 0,
                            extentOffset: _nameCtrl.text.length,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Icon picker
                        InkWell(
                          onTap: _pickIcon,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: theme.colorScheme.outline,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                _buildIconPreview(theme),
                                const SizedBox(width: 16),
                                Text(
                                  tr('Icon'),
                                  style: fontProvider.getTextStyle(
                                    fontSize: 18,
                                  ),
                                ),
                                const Spacer(),
                                const Icon(Icons.add_photo_alternate_outlined),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Subtitle field
                        SmartTextFormField(
                          controller: _subtitleCtrl,
                          focusNode: _subtitleFocus,
                          nextFocusNode: _amountFocus,
                          textCapitalization: TextCapitalization.words,
                          autocorrect: false,
                          maxLines: 1, // FIX: Prevent multi-line expansion
                          style: fontProvider
                              .getTextStyle(fontSize: 18)
                              .copyWith(fontStyle: FontStyle.italic),
                          decoration: InputDecoration(
                            labelText: tr('envelope_subtitle_optional'),
                            labelStyle: fontProvider.getTextStyle(fontSize: 16),
                            hintText: tr('envelope_subtitle_hint'),
                            hintStyle: fontProvider
                                .getTextStyle(fontSize: 16, color: Colors.grey)
                                .copyWith(fontStyle: FontStyle.italic),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.notes),
                            counterText: '', // Hide character counter
                            // FIX 3: Added contentPadding
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 20,
                            ),
                          ),
                          onTap: () => _subtitleCtrl.selection = TextSelection(
                            baseOffset: 0,
                            extentOffset: _subtitleCtrl.text.length,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Starting amount field
                        SmartTextFormField(
                          controller: _amtCtrl,
                          focusNode: _amountFocus,
                          nextFocusNode: _targetFocus,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (value) {
                            // Trigger rebuild so InsightTile gets updated startingAmount
                            setState(() {});
                          },
                          style: fontProvider.getTextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            labelText: tr('envelope_starting_amount'),
                            labelStyle: fontProvider.getTextStyle(fontSize: 18),
                            hintText: 'e.g. 0.00',
                            hintStyle: fontProvider.getTextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(
                              Icons.account_balance_wallet,
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
                                  final result = await CalculatorHelper.showCalculator(context);
                                  if (result != null && mounted) {
                                    setState(() {
                                      _amtCtrl.text = result;
                                    });
                                  }
                                },
                                tooltip: 'Open Calculator',
                              ),
                            ),
                            // FIX 3: Added contentPadding
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 20,
                            ),
                          ),
                          onTap: () {
                            _amtCtrl.selection = TextSelection(
                              baseOffset: 0,
                              extentOffset: _amtCtrl.text.length,
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // ACCOUNT MODE ENFORCEMENT: Always show account dropdown when accounts exist
                        if (_accountsLoaded && _hasAccounts) ...[
                          Divider(color: theme.colorScheme.outline),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(Icons.info_outline,
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Account link is required when you have accounts',
                                  style: fontProvider.getTextStyle(
                                    fontSize: 14,
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Linked Account',
                            style: fontProvider.getTextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedAccountId,
                            decoration: InputDecoration(
                              labelText: 'Select Account',
                              labelStyle: fontProvider.getTextStyle(
                                fontSize: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.account_balance_wallet),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            items: _accounts.map((account) {
                              return DropdownMenuItem(
                                value: account.id,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    account.getIconWidget(theme, size: 20),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        account.name,
                                        style: fontProvider.getTextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (account.isDefault) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.star, color: Colors.amber, size: 16),
                                    ],
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (value) =>
                                setState(() => _selectedAccountId = value),
                          ),
                          const SizedBox(height: 24),
                          Divider(color: theme.colorScheme.outline),
                          const SizedBox(height: 16),
                        ],

                        // Binder selection
                        if (_bindersLoaded) ...[
                          Text(
                            tr('Binder'),
                            style: fontProvider.getTextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String?>(
                                  initialValue: _selectedBinderId,
                                  decoration: InputDecoration(
                                    labelText: tr('envelope_add_to_binder'),
                                    labelStyle: fontProvider.getTextStyle(
                                      fontSize: 16,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                  ),
                                  items: [
                                    DropdownMenuItem(
                                      value: null,
                                      child: Text(
                                        tr('envelope_no_binder'),
                                        style: fontProvider.getTextStyle(
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                    // Add pending binder option if we're creating envelope inside a new binder
                                    if (widget.creationContext?.hasPendingBinder == true)
                                      DropdownMenuItem(
                                        value: _pendingBinderId,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.folder, size: 20),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                '${widget.creationContext!.pendingBinderName} (New)',
                                                style: fontProvider.getTextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: theme.colorScheme.primary,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ..._binders.map((binder) {
                                      final binderColorOption =
                                          ThemeBinderColors.getColorsForTheme(
                                              themeProvider.currentThemeId)[binder.colorIndex];
                                      // Use envelopeTextColor for better contrast, especially for light binders
                                      final textColor = binderColorOption.envelopeTextColor;
                                      return DropdownMenuItem(
                                        value: binder.id,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            binder.getIconWidget(theme, size: 20),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                binder.name,
                                                style: fontProvider
                                                    .getTextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: textColor,
                                                    ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                  onChanged: (value) =>
                                      setState(() => _selectedBinderId = value),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(
                                  Icons.add_circle,
                                  color: theme.colorScheme.secondary,
                                ),
                                tooltip: tr('group_create_binder_tooltip'),
                                onPressed: () async {
                                  await _createNewBinder();
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Divider(color: theme.colorScheme.outline),
                          const SizedBox(height: 16),
                        ],

                        // 👁️‍🗨️ INSIGHT TILE - Unified financial planning
                        InsightTile(
                          userId: widget.userId,
                          startingAmount: double.tryParse(_amtCtrl.text),
                          envelopeRepo: widget.repo, // Pass repo for existing commitments calculation
                          onInsightChanged: (InsightData data) {
                            setState(() {
                              // Store full insight data
                              _insightData = data;

                              // Update target/horizon
                              if (data.horizonAmount != null) {
                                _targetCtrl.text = data.horizonAmount.toString();
                              }
                              _targetDate = data.horizonDate;

                              // Update cash flow
                              _cashFlowEnabled = data.cashFlowEnabled;
                              final cashFlow = data.effectiveCashFlow;
                              if (cashFlow != null) {
                                _cashFlowAmountCtrl.text = cashFlow.toString();
                              }

                              // Update autopilot flag
                              _addScheduledPayment = data.autopilotEnabled;
                            });
                          },
                          initialData: InsightData(
                            horizonEnabled: double.tryParse(_targetCtrl.text) != null,
                            horizonAmount: double.tryParse(_targetCtrl.text),
                            horizonDate: _targetDate,
                            cashFlowEnabled: _cashFlowEnabled,
                            calculatedCashFlow: double.tryParse(_cashFlowAmountCtrl.text),
                            autopilotEnabled: _addScheduledPayment,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Create button
                        FilledButton(
                          onPressed: _saving ? null : _handleSave,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    tr('envelope_create_button'),
                                    style: fontProvider.getTextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 32), // Bottom padding
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}