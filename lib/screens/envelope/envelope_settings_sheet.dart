// lib/screens/envelope/envelope_settings_sheet.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/envelope.dart';
import '../../models/envelope_group.dart';
import '../../models/account.dart'; // NEW
import '../../services/envelope_repo.dart';
import '../../services/group_repo.dart';
import '../../services/account_repo.dart'; // NEW
import '../../widgets/group_editor.dart' as editor;
import '../../providers/font_provider.dart';
import '../../providers/locale_provider.dart';
import '../add_scheduled_payment_screen.dart';
import '../../widgets/envelope/omni_icon_picker_modal.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_themes.dart';
import '../../utils/calculator_helper.dart';
import '../../services/scheduled_payment_repo.dart';

enum EnvelopeSettingsSection {
  top,
  autofill,
  scheduledPayments,
}

class EnvelopeSettingsSheet extends StatefulWidget {
  const EnvelopeSettingsSheet({
    super.key,
    required this.envelopeId,
    required this.repo,
    required this.groupRepo,
    required this.accountRepo, // NEW
    this.initialSection = EnvelopeSettingsSection.top,
    this.scheduledPaymentRepo, // NEW
  });

  final String envelopeId;
  final EnvelopeRepo repo;
  final GroupRepo groupRepo;
  final AccountRepo accountRepo; // NEW
  final EnvelopeSettingsSection initialSection;
  final ScheduledPaymentRepo? scheduledPaymentRepo; // NEW

  @override
  State<EnvelopeSettingsSheet> createState() => _EnvelopeSettingsSheetState();
}

class _EnvelopeSettingsSheetState extends State<EnvelopeSettingsSheet> {
  final _nameController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _targetController = TextEditingController();
  final _autoFillAmountController = TextEditingController();
  final _scrollController = ScrollController();

  // Keys for scrolling to specific sections
  final _autofillKey = GlobalKey();
  final _scheduledPaymentsKey = GlobalKey();

  // Scheduled payment repo
  late final ScheduledPaymentRepo _scheduledPaymentRepo;

  String? _selectedEmoji;
  String? _iconType;
  String? _iconValue;
  String? _selectedBinderId;
  String? _selectedAccountId; // NEW
  DateTime? _selectedTargetDate;
  TargetStartDateType? _targetStartDateType;
  DateTime? _customTargetStartDate;
  bool _autoFillEnabled = false;
  bool _isLoading = false;
  bool _initialized = false;
  List<EnvelopeGroup> _binders = [];
  bool _bindersLoaded = false;

  // Track original values for unsaved changes detection
  String? _originalName;
  String? _originalSubtitle;
  String? _originalTarget;
  String? _originalAutoFillAmount;
  String? _originalEmoji;
  String? _originalIconType;
  String? _originalIconValue;
  String? _originalBinderId;
  String? _originalAccountId;
  DateTime? _originalTargetDate;
  bool _originalAutoFillEnabled = false;

  @override
  void initState() {
    super.initState();
    _scheduledPaymentRepo = widget.scheduledPaymentRepo ?? ScheduledPaymentRepo(widget.repo.currentUserId);
    _loadBinders();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _subtitleController.dispose();
    _targetController.dispose();
    _autoFillAmountController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSection(EnvelopeSettingsSection section) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      switch (section) {
        case EnvelopeSettingsSection.autofill:
          // For autofill, scroll to the bottom to ensure the section is visible above sticky buttons
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
          break;
        case EnvelopeSettingsSection.scheduledPayments:
          final targetKey = _scheduledPaymentsKey;
          if (targetKey.currentContext != null) {
            final context = targetKey.currentContext!;
            final renderBox = context.findRenderObject() as RenderBox?;
            if (renderBox != null) {
              final offset = renderBox.localToGlobal(Offset.zero).dy;
              final scrollOffset = _scrollController.offset + offset - 100;
              _scrollController.animateTo(
                scrollOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
              );
            }
          }
          break;
        case EnvelopeSettingsSection.top:
          _scrollController.jumpTo(0);
          break;
      }
    });
  }

  Future<void> _loadBinders() async {
    if (_bindersLoaded) return;

    try {
      // Use getAllGroupsAsync to read from Hive (works in both solo and workspace mode)
      final allBinders = await widget.groupRepo.getAllGroupsAsync();

      if (mounted) {
        setState(() {
          _binders = allBinders..sort((a, b) => a.name.compareTo(b.name));
          _bindersLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _binders = [];
          _bindersLoaded = true;
        });
      }
    }
  }

  Future<void> _createNewBinder() async {
    await editor.showGroupEditor(
      context: context,
      groupRepo: widget.groupRepo,
      envelopeRepo: widget.repo,
    );
    setState(() => _bindersLoaded = false);
    await _loadBinders();
  }

  Future<void> _pickIcon(Envelope envelope) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OmniIconPickerModal(
        initialQuery: envelope.name, // Pre-populate with envelope name
      ),
    );

    if (result != null) {
      setState(() {
        _iconType = result['type'] as String;
        _iconValue = result['value'] as String;
        if (_iconType == 'emoji') {
          _selectedEmoji = _iconValue;
        }
      });
    }
  }

  bool _hasUnsavedChanges() {
    // Check if any fields differ from original values
    return _nameController.text != _originalName ||
           _subtitleController.text != _originalSubtitle ||
           _targetController.text != _originalTarget ||
           _autoFillAmountController.text != _originalAutoFillAmount ||
           _selectedEmoji != _originalEmoji ||
           _iconType != _originalIconType ||
           _iconValue != _originalIconValue ||
           _selectedBinderId != _originalBinderId ||
           _selectedAccountId != _originalAccountId ||
           _selectedTargetDate != _originalTargetDate ||
           _autoFillEnabled != _originalAutoFillEnabled;
  }

  Future<bool?> _confirmDiscard() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text('You have unsaved changes. Are you sure you want to go back?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkAndNavigateToScheduledPayment(Envelope envelope) async {
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final locale = Provider.of<LocaleProvider>(context, listen: false);
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);

    // Get existing scheduled payments for this envelope
    final existingPayments = await _scheduledPaymentRepo.getPaymentsForEnvelope(envelope.id).first;

    if (existingPayments.isEmpty) {
      // No existing payments, navigate directly
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddScheduledPaymentScreen(
            repo: widget.repo,
            preselectedEnvelopeId: envelope.id,
          ),
        ),
      );
      return;
    }

    // Show warning dialog with existing payment details
    if (!mounted) return;
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Existing Scheduled Payment${existingPayments.length > 1 ? 's' : ''}',
          style: fontProvider.getTextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This envelope already has ${existingPayments.length} scheduled payment${existingPayments.length > 1 ? 's' : ''}:',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              ...existingPayments.map((payment) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(payment.colorValue).withAlpha(51),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Color(payment.colorValue).withAlpha(128),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment.name,
                      style: fontProvider.getTextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Amount: ${currency.format(payment.amount)}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      'Next Due: ${DateFormat('MMM d, yyyy').format(payment.nextDueDate)}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      'Frequency: ${payment.frequencyString}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 8),
              Text(
                'Do you want to add another scheduled payment?',
                style: fontProvider.getTextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: fontProvider.getTextStyle(fontSize: 16),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Add Anyway',
              style: fontProvider.getTextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldProceed == true && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddScheduledPaymentScreen(
            repo: widget.repo,
            preselectedEnvelopeId: envelope.id,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return StreamBuilder<Envelope>(
      stream: widget.repo.envelopeStream(widget.envelopeId),
      builder: (context, envelopeSnapshot) {
        // Handle envelope deletion - close the sheet if envelope is deleted
        if (envelopeSnapshot.hasError) {
          debugPrint('[EnvelopeSettingsSheet] Stream error: ${envelopeSnapshot.error}');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pop();
            }
          });
          return const Center(child: CircularProgressIndicator());
        }

        if (!envelopeSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final envelope = envelopeSnapshot.data!;

        if (!_bindersLoaded) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!_initialized && _bindersLoaded) {
          _nameController.text = envelope.name;
          _subtitleController.text = envelope.subtitle ?? '';
          _targetController.text =
              envelope.targetAmount?.toStringAsFixed(2) ?? '';
          _autoFillAmountController.text =
              envelope.autoFillAmount?.toStringAsFixed(2) ?? '';
          _selectedEmoji = envelope.emoji;
          _iconType = envelope.iconType;
          _iconValue = envelope.iconValue;
          _selectedAccountId = envelope.linkedAccountId; // NEW
          _selectedTargetDate = envelope.targetDate;
          _targetStartDateType = envelope.targetStartDateType ?? TargetStartDateType.fromToday;
          _customTargetStartDate = envelope.customTargetStartDate;

          if (envelope.groupId != null &&
              _binders.any((b) => b.id == envelope.groupId)) {
            _selectedBinderId = envelope.groupId;
          } else {
            _selectedBinderId = null;
          }

          _autoFillEnabled = envelope.autoFillEnabled;

          // Save original values for unsaved changes detection
          _originalName = envelope.name;
          _originalSubtitle = envelope.subtitle ?? '';
          _originalTarget = envelope.targetAmount?.toStringAsFixed(2) ?? '';
          _originalAutoFillAmount = envelope.autoFillAmount?.toStringAsFixed(2) ?? '';
          _originalEmoji = envelope.emoji;
          _originalIconType = envelope.iconType;
          _originalIconValue = envelope.iconValue;
          _originalBinderId = _selectedBinderId;
          _originalAccountId = envelope.linkedAccountId;
          _originalTargetDate = envelope.targetDate;
          _originalAutoFillEnabled = envelope.autoFillEnabled;

          _initialized = true;

          // Scroll to the requested section after initialization
          if (widget.initialSection != EnvelopeSettingsSection.top) {
            _scrollToSection(widget.initialSection);
          }
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, dynamic result) async {
            if (didPop) return;

            // Check if there are unsaved changes
            if (_hasUnsavedChanges()) {
              final shouldPop = await _confirmDiscard();
              if (shouldPop == true) {
                if (!context.mounted) return;
                Navigator.of(context).pop();
              }
            } else {
              // No unsaved changes, allow pop
              if (!context.mounted) return;
              Navigator.of(context).pop();
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
            children: [
              // Header section (non-scrollable)
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Icon(
                      Icons.settings,
                      size: 28,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Envelope Settings',
                        style: fontProvider.getTextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Scrollable content section
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  physics: const ClampingScrollPhysics(),
                  children: [
                    // NAME INPUT
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      style: fontProvider.getTextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Envelope Name',
                        labelStyle: fontProvider.getTextStyle(fontSize: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.mail),
                      ),
                      onTap: () {
                        _nameController.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: _nameController.text.length,
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // ICON PICKER
                    InkWell(
                      onTap: () => _pickIcon(envelope),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.colorScheme.outline),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.emoji_emotions),
                            const SizedBox(width: 16),
                            Text(
                              'Icon',
                              style: fontProvider.getTextStyle(fontSize: 18),
                            ),
                            const Spacer(),
                            envelope
                                .copyWith(
                                  iconType: _iconType,
                                  iconValue: _iconValue,
                                  emoji: _selectedEmoji,
                                )
                                .getIconWidget(theme, size: 32),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // SUBTITLE
                    TextField(
                      controller: _subtitleController,
                      maxLines: 1,
                      textCapitalization: TextCapitalization.words,
                      style: fontProvider
                          .getTextStyle(fontSize: 18)
                          .copyWith(fontStyle: FontStyle.italic),
                      decoration: InputDecoration(
                        labelText: 'Subtitle (optional)',
                        labelStyle: fontProvider.getTextStyle(fontSize: 16),
                        hintText: 'e.g., "Weekly shopping"',
                        hintStyle: fontProvider
                            .getTextStyle(fontSize: 16, color: Colors.grey)
                            .copyWith(fontStyle: FontStyle.italic),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.notes),
                      ),
                      onTap: () {
                        _subtitleController.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: _subtitleController.text.length,
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // TARGET AMOUNT
                    Consumer<LocaleProvider>(
                      builder: (context, locale, _) => TextField(
                        controller: _targetController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: fontProvider.getTextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Target Amount (${locale.currencySymbol})',
                          labelStyle: fontProvider.getTextStyle(fontSize: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.flag),
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
                                if (result != null) {
                                  _targetController.text = result;
                                }
                              },
                              tooltip: 'Calculator',
                            ),
                          ),
                        ),
                        onTap: () {
                          _targetController.selection = TextSelection(
                            baseOffset: 0,
                            extentOffset: _targetController.text.length,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // TARGET DATE
                    InkWell(
                      onTap: () async {
                        // Check if target amount is set before allowing date selection
                        final targetAmount = _targetController.text.isEmpty
                            ? null
                            : double.tryParse(_targetController.text);

                        if (targetAmount == null || targetAmount <= 0) {
                          // Show warning dialog
                          await showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(
                                'Target Amount Required',
                                style: fontProvider.getTextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              content: const Text(
                                'You must set a target amount before setting a target date.\n\nPlease enter a target amount first.',
                                style: TextStyle(fontSize: 16),
                              ),
                              actions: [
                                FilledButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(
                                    'OK',
                                    style: fontProvider.getTextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                          return;
                        }

                        // Target amount is valid, proceed with date selection
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _selectedTargetDate ?? DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                          helpText: 'Select Target Date',
                        );

                        if (date != null) {
                          setState(() {
                            _selectedTargetDate = date;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Target Date (Optional)',
                          labelStyle: fontProvider.getTextStyle(fontSize: 18),
                          hintText: 'Tap to select date',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.calendar_today),
                          suffixIcon: _selectedTargetDate != null
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() {
                                      _selectedTargetDate = null;
                                    });
                                  },
                                  tooltip: 'Clear date',
                                )
                              : null,
                        ),
                        child: Text(
                          _selectedTargetDate != null
                              ? DateFormat('MMM dd, yyyy').format(_selectedTargetDate!)
                              : 'No date set',
                          style: fontProvider.getTextStyle(
                            fontSize: 18,
                            color: _selectedTargetDate != null
                                ? theme.textTheme.bodyLarge?.color
                                : theme.hintColor,
                          ),
                        ),
                      ),
                    ),

                    // TARGET START DATE TYPE (only show when target date is set)
                    if (_selectedTargetDate != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Start Date for Progress Tracking',
                        style: fontProvider.getTextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Column(
                        children: [
                          RadioListTile<TargetStartDateType>(
                            title: Text(
                              'From Today',
                              style: fontProvider.getTextStyle(fontSize: 16),
                            ),
                            subtitle: Text(
                              'Progress starts from now (${DateFormat('MMM dd, yyyy').format(DateTime.now())})',
                              style: fontProvider.getTextStyle(
                                fontSize: 14,
                                color: theme.hintColor,
                              ),
                            ),
                            value: TargetStartDateType.fromToday,
                            groupValue: _targetStartDateType,
                            onChanged: (value) {
                              setState(() {
                                _targetStartDateType = value;
                              });
                            },
                          ),
                          StreamBuilder<List<Envelope>>(
                            stream: widget.repo.envelopesStream(),
                            builder: (context, snapshot) {
                              final envelope = snapshot.data?.firstWhere(
                                (e) => e.id == widget.envelopeId,
                                orElse: () => throw Exception('Envelope not found'),
                              );
                              final createdAt = envelope?.createdAt;

                              return RadioListTile<TargetStartDateType>(
                                title: Text(
                                  'From Envelope Creation',
                                  style: fontProvider.getTextStyle(fontSize: 16),
                                ),
                                subtitle: Text(
                                  createdAt != null
                                      ? 'Progress from when envelope was created (${DateFormat('MMM dd, yyyy').format(createdAt)})'
                                      : 'Progress from envelope creation (date unavailable for old envelopes)',
                                  style: fontProvider.getTextStyle(
                                    fontSize: 14,
                                    color: theme.hintColor,
                                  ),
                                ),
                                value: TargetStartDateType.fromEnvelopeCreation,
                                groupValue: _targetStartDateType,
                                onChanged: createdAt != null
                                    ? (value) {
                                        setState(() {
                                          _targetStartDateType = value;
                                        });
                                      }
                                    : null, // Disable if no createdAt
                              );
                            },
                          ),
                          RadioListTile<TargetStartDateType>(
                            title: Text(
                              'Custom Date',
                              style: fontProvider.getTextStyle(fontSize: 16),
                            ),
                            subtitle: Text(
                              _customTargetStartDate != null
                                  ? 'Progress from ${DateFormat('MMM dd, yyyy').format(_customTargetStartDate!)}'
                                  : 'Choose a specific start date',
                              style: fontProvider.getTextStyle(
                                fontSize: 14,
                                color: theme.hintColor,
                              ),
                            ),
                            value: TargetStartDateType.customDate,
                            groupValue: _targetStartDateType,
                            onChanged: (value) async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _customTargetStartDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: _selectedTargetDate ?? DateTime.now(),
                                helpText: 'Select Start Date',
                              );

                              if (date != null) {
                                setState(() {
                                  _targetStartDateType = value;
                                  _customTargetStartDate = date;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 24),
                    Divider(color: theme.colorScheme.outline),
                    const SizedBox(height: 16),

                    // BINDER SELECTOR
                    Text(
                      'Binder',
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
                              labelText: 'Add to Binder',
                              labelStyle: fontProvider.getTextStyle(
                                fontSize: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.folder),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: null,
                                child: Text(
                                  'No Binder',
                                  style: fontProvider.getTextStyle(
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              ..._binders.map((binder) {
                                final binderColorOption =
                                    ThemeBinderColors.getColorsForTheme(
                                      themeProvider.currentThemeId,
                                    )[binder.colorIndex];
                                // Use envelopeTextColor for better contrast, especially for light binders
                                final textColor =
                                    binderColorOption.envelopeTextColor;
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
                                          style: fontProvider.getTextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
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
                          tooltip: 'Create new binder',
                          onPressed: _createNewBinder,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    Divider(color: theme.colorScheme.outline),
                    const SizedBox(height: 16),

                    // ACCOUNT LINKING SECTION (NEW)
                    Text(
                      'Account Link',
                      style: fontProvider.getTextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Where does money for this envelope come from?',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withAlpha(153),
                      ),
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<List<Account>>(
                      stream: widget.accountRepo.accountsStream(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const LinearProgressIndicator();
                        }
                        final accounts = snapshot.data!;

                        return DropdownButtonFormField<String?>(
                          initialValue: _selectedAccountId,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(
                              Icons.account_balance_wallet,
                            ),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: null,
                              child: Text(
                                'Not linked',
                                style: fontProvider.getTextStyle(fontSize: 16),
                              ),
                            ),
                            ...accounts.map(
                              (account) => DropdownMenuItem(
                                value: account.id,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      height: 24,
                                      child: Align(
                                        alignment: Alignment.center,
                                        child: Text(
                                          account.emoji ?? '💳',
                                          style: const TextStyle(
                                            fontSize: 20,
                                            height: 1.2,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        account.name,
                                        style: fontProvider.getTextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            setState(() => _selectedAccountId = val);
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 24),
                    Divider(color: theme.colorScheme.outline),
                    const SizedBox(height: 16),

                    // SCHEDULE PAYMENT LINK
                    ListTile(
                      key: _scheduledPaymentsKey,
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withAlpha(26),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.calendar_today,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      title: Text(
                        'Schedule Payment',
                        style: fontProvider.getTextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        'Set up recurring deposits/withdrawals',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface.withAlpha(153),
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        _checkAndNavigateToScheduledPayment(envelope);
                      },
                    ),

                    const SizedBox(height: 24),
                    Divider(color: theme.colorScheme.outline),
                    const SizedBox(height: 16),

                    // AUTO-FILL SECTION
                    Text(
                      'Pay Day Auto-Fill',
                      key: _autofillKey,
                      style: fontProvider.getTextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: _autoFillEnabled,
                      onChanged: (value) {
                        setState(() => _autoFillEnabled = value);
                        // When enabled, scroll to bottom to reveal the amount field
                        if (value && _scrollController.hasClients) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted || !_scrollController.hasClients) return;
                            _scrollController.animateTo(
                              _scrollController.position.maxScrollExtent,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          });
                        }
                      },
                      title: Text(
                        'Enable Auto-Fill',
                        style: fontProvider.getTextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        'Automatically add money on pay day',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface.withAlpha(153),
                        ),
                      ),
                    ),
                    if (_autoFillEnabled) ...[
                      const SizedBox(height: 16),
                      Consumer<LocaleProvider>(
                        builder: (context, locale, _) => TextField(
                          controller: _autoFillAmountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: fontProvider.getTextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Auto-Fill Amount (${locale.currencySymbol})',
                            labelStyle: fontProvider.getTextStyle(fontSize: 18),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.autorenew),
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
                                  if (result != null) {
                                    _autoFillAmountController.text = result;
                                  }
                                },
                                tooltip: 'Calculator',
                              ),
                            ),
                            helperText: 'Amount to add each pay day',
                            helperStyle: fontProvider.getTextStyle(fontSize: 14),
                          ),
                          onTap: () {
                            _autoFillAmountController.selection = TextSelection(
                              baseOffset: 0,
                              extentOffset: _autoFillAmountController.text.length,
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),

              // Sticky buttons section at bottom
              Container(
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  border: Border(
                    top: BorderSide(
                      color: theme.colorScheme.outline.withAlpha(77),
                      width: 1,
                    ),
                  ),
                ),
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 16,
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // SAVE BUTTON
                    FilledButton(
                      onPressed: _isLoading
                          ? null
                          : () => _saveChanges(envelope),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: const Size(double.infinity, 0),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Save Changes',
                              style: fontProvider.getTextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),

                    // DELETE BUTTON
                    OutlinedButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              debugPrint(
                                '[EnvelopeSettingsSheet] 🔴 Delete button tapped',
                              );
                              _confirmDelete(envelope);
                            },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.red.shade600),
                        minimumSize: const Size(double.infinity, 0),
                      ),
                      child: Text(
                        'Delete Envelope',
                        style: fontProvider.getTextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveChanges(Envelope envelope) async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Envelope name cannot be empty')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final targetAmount = _targetController.text.isEmpty
          ? null
          : double.tryParse(_targetController.text);

      // Validate: target date requires target amount
      if (_selectedTargetDate != null && (targetAmount == null || targetAmount <= 0)) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Target date requires a target amount. Please enter a target amount to set a deadline.'),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      final autoFillAmount =
          _autoFillEnabled && _autoFillAmountController.text.isNotEmpty
          ? double.tryParse(_autoFillAmountController.text)
          : null;

      // Update envelope using repo
      await widget.repo.updateEnvelope(
        envelopeId: widget.envelopeId,
        name: _nameController.text.trim(),
        emoji: _selectedEmoji,
        iconType: _iconType,
        iconValue: _iconValue,
        targetAmount: targetAmount,
        targetDate: _selectedTargetDate,
        autoFillEnabled: _autoFillEnabled,
        linkedAccountId: _selectedAccountId,
        updateLinkedAccountId: true, // Always update linkedAccountId (allows unlinking)
        updateTargetAmount: true, // Always update targetAmount (allows clearing)
        updateTargetDate: true, // Always update targetDate (allows clearing)
        subtitle: _subtitleController.text.trim().isEmpty
            ? null
            : _subtitleController.text.trim(),
        groupId: _selectedBinderId,
        autoFillAmount: (_autoFillEnabled && autoFillAmount != null)
            ? autoFillAmount
            : null,
        targetStartDateType: _selectedTargetDate != null ? _targetStartDateType : null,
        customTargetStartDate: _targetStartDateType == TargetStartDateType.customDate ? _customTargetStartDate : null,
        updateTargetStartDateType: true, // Always update (allows clearing when target date is removed)
        updateCustomTargetStartDate: true, // Always update (allows clearing)
      );

      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Changes saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating envelope: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _confirmDelete(Envelope envelope) async {
    debugPrint('[EnvelopeSettingsSheet] 📋 Showing delete confirmation dialog');
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Envelope?',
          style: fontProvider.getTextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${envelope.name}"?\n\n'
          'This will also delete:\n'
          '• All associated transactions\n'
          '• All scheduled payments for this envelope\n\n'
          'This action cannot be undone.',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: fontProvider.getTextStyle(fontSize: 18),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            child: Text(
              'Delete',
              style: fontProvider.getTextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      debugPrint('[EnvelopeSettingsSheet] ✅ User confirmed delete');
      debugPrint('[EnvelopeSettingsSheet] Envelope ID: ${widget.envelopeId}');
      debugPrint('[EnvelopeSettingsSheet] Envelope name: ${envelope.name}');

      // CRITICAL: Close the settings sheet BEFORE deleting
      // This prevents the sheet from trying to stream the deleted envelope
      Navigator.pop(context);

      try {
        debugPrint('[EnvelopeSettingsSheet] 📞 Calling repo.deleteEnvelope...');
        await widget.repo.deleteEnvelope(widget.envelopeId);
        debugPrint('[EnvelopeSettingsSheet] ✅ Delete completed successfully');

        if (mounted) {
          debugPrint(
            '[EnvelopeSettingsSheet] Showing success message',
          );
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Envelope deleted')));
        }
      } catch (e) {
        debugPrint('[EnvelopeSettingsSheet] ❌ Delete failed with error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting envelope: $e')),
          );
        }
      }
    } else if (confirmed == false) {
      debugPrint('[EnvelopeSettingsSheet] ❌ User cancelled delete');
    } else if (!mounted) {
      debugPrint(
        '[EnvelopeSettingsSheet] ⚠️ Widget not mounted, skipping delete',
      );
    }
  }
}
