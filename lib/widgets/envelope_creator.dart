// lib/widgets/envelope_creator.dart
// FONT PROVIDER INTEGRATED: All GoogleFonts.caveat() replaced with FontProvider
// All button text wrapped in FittedBox to prevent wrapping

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/envelope_repo.dart';
import '../services/group_repo.dart';
import '../models/envelope_group.dart';
import '../screens/add_scheduled_payment_screen.dart';
import '../widgets/group_editor.dart' as editor;
import '../services/localization_service.dart';
import '../providers/font_provider.dart';
import 'envelope/omni_icon_picker_modal.dart';
import '../models/envelope.dart';
import '../providers/theme_provider.dart';
import '../theme/app_themes.dart';

// FULL SCREEN DIALOG IMPLEMENTATION
Future<void> showEnvelopeCreator(
  BuildContext context, {
  required EnvelopeRepo repo,
  required GroupRepo groupRepo,
}) async {
  await Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _EnvelopeCreatorScreen(repo: repo, groupRepo: groupRepo),
    ),
  );
}

class _EnvelopeCreatorScreen extends StatefulWidget {
  const _EnvelopeCreatorScreen({required this.repo, required this.groupRepo});
  final EnvelopeRepo repo;
  final GroupRepo groupRepo;

  @override
  State<_EnvelopeCreatorScreen> createState() => _EnvelopeCreatorScreenState();
}

class _EnvelopeCreatorScreenState extends State<_EnvelopeCreatorScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameCtrl = TextEditingController();
  final _amtCtrl = TextEditingController(text: '0.00');
  final _targetCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  final _autoFillAmountCtrl = TextEditingController();

  // Focus nodes
  final _nameFocus = FocusNode();
  final _amountFocus = FocusNode();
  final _targetFocus = FocusNode();
  final _subtitleFocus = FocusNode();
  final _autoFillAmountFocus = FocusNode();

  // Auto-fill state
  bool _autoFillEnabled = false;
  bool _addScheduledPayment = false;

  // Binder selection state
  String? _selectedBinderId;
  List<EnvelopeGroup> _binders = [];
  bool _bindersLoaded = false;

  // Icon selection state
  String? _iconType;
  String? _iconValue;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadBinders();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _nameFocus.requestFocus();
      }
    });

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

    _autoFillAmountFocus.addListener(() {
      if (_autoFillAmountFocus.hasFocus) {
        _autoFillAmountCtrl.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _autoFillAmountCtrl.text.length,
        );
      }
    });
  }

  Future<void> _loadBinders() async {
    try {
      final snapshot = await widget.groupRepo.groupsCol().get();
      final allBinders = snapshot.docs
          .map((doc) => EnvelopeGroup.fromFirestore(doc))
          .toList();

      final uniqueBinders = <String, EnvelopeGroup>{};
      for (final binder in allBinders) {
        uniqueBinders[binder.id] = binder;
      }

      setState(() {
        _binders = uniqueBinders.values.toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        _bindersLoaded = true;
      });
    } catch (e) {
      debugPrint('Error loading binders: $e');
      setState(() => _bindersLoaded = true);
    }
  }

  Future<void> _createNewBinder() async {
    // Pass draft name so user can select the envelope they are currently creating
    // Capture the newBinderId returned by the editor
    final newBinderId = await editor.showGroupEditor(
      context: context,
      groupRepo: widget.groupRepo,
      envelopeRepo: widget.repo,
      draftEnvelopeName: _nameCtrl.text.isNotEmpty ? _nameCtrl.text : null,
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
      final iconType = result['type'].toString().split('.').last;
      final iconValue = result['value'] as String;

      setState(() {
        _iconType = iconType;
        _iconValue = iconValue;
      });
    }
  }

  void _handleNameSubmit() {
    _subtitleFocus.requestFocus();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amtCtrl.dispose();
    _targetCtrl.dispose();
    _subtitleCtrl.dispose();
    _autoFillAmountCtrl.dispose();
    _nameFocus.dispose();
    _amountFocus.dispose();
    _targetFocus.dispose();
    _subtitleFocus.dispose();
    _autoFillAmountFocus.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_saving) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final name = _nameCtrl.text.trim();
    final subtitle = _subtitleCtrl.text.trim();

    // starting amount
    double start = 0.0;
    final rawStart = _amtCtrl.text.trim();
    if (rawStart.isNotEmpty) {
      final parsed = double.tryParse(rawStart);
      if (parsed == null || parsed < 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('error_invalid_starting_amount'))),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('error_invalid_target'))));
        return;
      }
      target = parsed;
    }

    // Auto-fill amount
    double? autoFillAmount;
    if (_autoFillEnabled) {
      final rawAutoFill = _autoFillAmountCtrl.text.trim();
      if (rawAutoFill.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('error_autofill_amount_required'))),
        );
        return;
      }
      final parsed = double.tryParse(rawAutoFill);
      if (parsed == null || parsed <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('error_invalid_autofill'))));
        return;
      }
      autoFillAmount = parsed;
    }

    setState(() => _saving = true);

    try {
      final envelopeId = await widget.repo.createEnvelope(
        name: name,
        startingAmount: start,
        targetAmount: target,
        subtitle: subtitle.isEmpty ? null : subtitle,
        emoji: null, // OLD, DEPRECATED
        iconType: _iconType,
        iconValue: _iconValue,
        autoFillEnabled: _autoFillEnabled,
        autoFillAmount: autoFillAmount,
        groupId: _selectedBinderId,
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      if (_addScheduledPayment) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddScheduledPaymentScreen(
              repo: widget.repo,
              preselectedEnvelopeId: envelopeId,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('success_envelope_created'))));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr('error_creating_envelope')}: $e')),
      );
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
                        // Name field
                        TextField(
                          controller: _nameCtrl,
                          focusNode: _nameFocus,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
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
                          onEditingComplete: _handleNameSubmit,
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
                                const Icon(Icons.emoji_emotions),
                                const SizedBox(width: 16),
                                Text(
                                  tr('Icon'),
                                  style: fontProvider.getTextStyle(
                                    fontSize: 18,
                                  ),
                                ),
                                const Spacer(),
                                if (_iconValue != null)
                                  Envelope(
                                    id: '',
                                    name: '',
                                    userId: '',
                                    iconType: _iconType,
                                    iconValue: _iconValue,
                                  ).getIconWidget(theme, size: 32)
                                else
                                  const Icon(Icons.add_photo_alternate_outlined),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Subtitle field
                        TextField(
                          controller: _subtitleCtrl,
                          focusNode: _subtitleFocus,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.next,
                          maxLength: 50,
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
                            // FIX 3: Added contentPadding
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 20,
                            ),
                          ),
                          onEditingComplete: () => _amountFocus.requestFocus(),
                        ),
                        const SizedBox(height: 16),

                        // Starting amount field
                        TextField(
                          controller: _amtCtrl,
                          focusNode: _amountFocus,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textInputAction: TextInputAction.next,
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
                            // FIX 3: Added contentPadding
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 20,
                            ),
                          ),
                          onEditingComplete: () => _targetFocus.requestFocus(),
                          onTap: () {
                            _amtCtrl.selection = TextSelection(
                              baseOffset: 0,
                              extentOffset: _amtCtrl.text.length,
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // Target field
                        TextField(
                          controller: _targetCtrl,
                          focusNode: _targetFocus,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textInputAction: TextInputAction.done,
                          style: fontProvider.getTextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            labelText: tr('envelope_target_amount'),
                            labelStyle: fontProvider.getTextStyle(fontSize: 18),
                            hintText: 'e.g. 1000.00',
                            hintStyle: fontProvider.getTextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.flag),
                            // FIX 3: Added contentPadding
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 20,
                            ),
                          ),
                          onEditingComplete: () {
                            if (_autoFillEnabled) {
                              _autoFillAmountFocus.requestFocus();
                            } else {
                              FocusScope.of(context).unfocus();
                            }
                          },
                        ),
                        const SizedBox(height: 24),

                        Divider(color: theme.colorScheme.outline),
                        const SizedBox(height: 16),

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
                                  value: _selectedBinderId,
                                  decoration: InputDecoration(
                                    labelText: tr('envelope_add_to_binder'),
                                    labelStyle: fontProvider.getTextStyle(
                                      fontSize: 16,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    prefixIcon: const Icon(Icons.folder),
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
                                    ..._binders.map((binder) {
                                      final binderColorOption =
                                          ThemeBinderColors.getColorsForTheme(
                                              themeProvider.currentThemeId)[binder.colorIndex];
                                      final binderColor =
                                          binderColorOption.binderColor;
                                      return DropdownMenuItem(
                                        value: binder.id,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (binder.emoji != null) ...[
                                              Text(
                                                binder.emoji!,
                                                style: const TextStyle(
                                                  fontSize: 20,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                            ],
                                            Flexible(
                                              child: Text(
                                                binder.name,
                                                style: fontProvider
                                                    .getTextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: binderColor,
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

                        // Auto-fill
                        Text(
                          tr('group_pay_day_auto'),
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
                          },
                          title: Text(
                            tr('envelope_enable_autofill'),
                            style: fontProvider.getTextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            tr('envelope_autofill_subtitle'),
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onSurface.withAlpha(153),
                            ),
                          ),
                        ),
                        if (_autoFillEnabled) ...[
                          const SizedBox(height: 16),
                          TextField(
                            controller: _autoFillAmountCtrl,
                            focusNode: _autoFillAmountFocus,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textInputAction: TextInputAction.done,
                            style: fontProvider.getTextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: InputDecoration(
                              labelText: tr('envelope_autofill_amount'),
                              labelStyle: fontProvider.getTextStyle(
                                fontSize: 18,
                              ),
                              hintText: 'e.g. 50.00',
                              hintStyle: fontProvider.getTextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.autorenew),
                              helperText: tr('envelope_autofill_helper'),
                              helperStyle: fontProvider.getTextStyle(
                                fontSize: 14,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 20,
                              ),
                            ),
                            onEditingComplete: () =>
                                FocusScope.of(context).unfocus(),
                            onTap: () {
                              _autoFillAmountCtrl.selection = TextSelection(
                                baseOffset: 0,
                                extentOffset: _autoFillAmountCtrl.text.length,
                              );
                            },
                          ),
                        ],
                        const SizedBox(height: 24),

                        Divider(color: theme.colorScheme.outline),
                        const SizedBox(height: 16),

                        // Schedule Payment
                        Text(
                          tr('envelope_schedule_payment'),
                          style: fontProvider.getTextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          value: _addScheduledPayment,
                          onChanged: (value) {
                            setState(
                              () => _addScheduledPayment = value ?? false,
                            );
                          },
                          title: Text(
                            tr('envelope_add_recurring_payment'),
                            style: fontProvider.getTextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            tr('envelope_recurring_payment_subtitle'),
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onSurface.withAlpha(153),
                            ),
                          ),
                          secondary: Icon(
                            Icons.calendar_today,
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                        const SizedBox(height: 32),

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