// lib/widgets/envelope_creator.dart
// FONT PROVIDER INTEGRATED: All GoogleFonts.caveat() replaced with FontProvider
// All button text wrapped in FittedBox to prevent wrapping

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// REMOVED unused google_fonts import
import '../services/envelope_repo.dart';
import '../services/group_repo.dart';
import '../models/envelope_group.dart';
import '../screens/add_scheduled_payment_screen.dart';
import '../widgets/group_editor.dart' as editor;
import '../services/localization_service.dart';
import '../providers/font_provider.dart';

Future<void> showEnvelopeCreator(
  BuildContext context, {
  required EnvelopeRepo repo,
  required GroupRepo groupRepo,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EnvelopeCreatorSheet(repo: repo, groupRepo: groupRepo),
  );
}

class _EnvelopeCreatorSheet extends StatefulWidget {
  const _EnvelopeCreatorSheet({required this.repo, required this.groupRepo});
  final EnvelopeRepo repo;
  final GroupRepo groupRepo;

  @override
  State<_EnvelopeCreatorSheet> createState() => _EnvelopeCreatorSheetState();
}

class _EnvelopeCreatorSheetState extends State<_EnvelopeCreatorSheet> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameCtrl = TextEditingController();
  final _amtCtrl = TextEditingController(text: '0.00');
  final _targetCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  final _autoFillAmountCtrl = TextEditingController();

  // Focus nodes to control keyboard navigation
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

  // Emoji selection state
  String? _selectedEmoji;

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    // Load binders
    _loadBinders();

    // Auto-focus the name field when the sheet opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameFocus.requestFocus();
    });

    // Select all text in amount when it gains focus
    _amountFocus.addListener(() {
      if (_amountFocus.hasFocus) {
        _amtCtrl.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _amtCtrl.text.length,
        );
      }
    });

    // Select all in target when it gains focus
    _targetFocus.addListener(() {
      if (_targetFocus.hasFocus) {
        _targetCtrl.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _targetCtrl.text.length,
        );
      }
    });

    // Select all in auto-fill amount when it gains focus
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

      // Deduplicate by ID
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
      print('Error loading binders: $e');
      setState(() => _bindersLoaded = true);
    }
  }

  Future<void> _createNewBinder() async {
    await editor.showGroupEditor(
      context: context,
      groupRepo: widget.groupRepo,
      envelopeRepo: widget.repo,
    );
    // Reload binders after creation
    await _loadBinders();
  }

  Future<void> _pickEmoji() async {
    final controller = TextEditingController(text: _selectedEmoji ?? '');
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          tr('appearance_choose_emoji'),
          style: fontProvider.getTextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr('appearance_emoji_instructions'),
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 1,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 60),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                onChanged: (value) {
                  if (value.characters.length > 1) {
                    controller.text = value.characters.first;
                    controller.selection = TextSelection.fromPosition(
                      TextPosition(offset: controller.text.length),
                    );
                  }
                },
                onSubmitted: (value) {
                  Navigator.pop(context);
                  final emoji = value.characters.isEmpty
                      ? null
                      : value.characters.first;
                  setState(() => _selectedEmoji = emoji);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _selectedEmoji = null);
            },
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                tr('remove'),
                style: fontProvider.getTextStyle(fontSize: 18),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                tr('cancel'),
                style: fontProvider.getTextStyle(fontSize: 18),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              final emoji = controller.text.characters.isEmpty
                  ? null
                  : controller.text.characters.first;
              setState(() => _selectedEmoji = emoji);
            },
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                tr('save'),
                style: fontProvider.getTextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
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

    // starting amount (blank -> 0.00)
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

    // target (optional)
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

    // Auto-fill amount (required if auto-fill enabled)
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
        emoji: _selectedEmoji, // Pass emoji to create method
        autoFillEnabled: _autoFillEnabled,
        autoFillAmount: autoFillAmount,
        groupId: _selectedBinderId,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // close the sheet

      // If user wants to add scheduled payment, open that screen
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
    final media = MediaQuery.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
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

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Icon(
                    Icons.mail_outline,
                    size: 28,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      tr('envelope_new'),
                      style: fontProvider.getTextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Scrollable form content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  bottom: media.viewInsets.bottom + 24,
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
                        autofocus: true,
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
                        ),
                        onEditingComplete: () => _subtitleFocus.requestFocus(),
                      ),
                      const SizedBox(height: 16),

                      // Emoji picker
                      InkWell(
                        onTap: _pickEmoji,
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
                                tr('emoji'),
                                style: fontProvider.getTextStyle(fontSize: 18),
                              ),
                              const Spacer(),
                              Text(
                                _selectedEmoji ?? '📨',
                                style: const TextStyle(fontSize: 32),
                              ),
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
                        // FIX: Use .copyWith() instead of passing fontStyle parameter
                        style: fontProvider
                            .getTextStyle(fontSize: 18)
                            .copyWith(fontStyle: FontStyle.italic),
                        decoration: InputDecoration(
                          labelText: tr('envelope_subtitle_optional'),
                          labelStyle: fontProvider.getTextStyle(fontSize: 16),
                          hintText: tr('envelope_subtitle_hint'),
                          // FIX: Use .copyWith() here as well
                          hintStyle: fontProvider
                              .getTextStyle(fontSize: 16, color: Colors.grey)
                              .copyWith(fontStyle: FontStyle.italic),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.notes),
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
                          prefixIcon: const Icon(Icons.account_balance_wallet),
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
                        ),
                        onEditingComplete: () {
                          if (_autoFillEnabled) {
                            _autoFillAmountFocus.requestFocus();
                          } else {
                            _handleSave();
                          }
                        },
                      ),
                      const SizedBox(height: 24),

                      Divider(color: theme.colorScheme.outline),
                      const SizedBox(height: 16),

                      // Binder selection section
                      if (_bindersLoaded) ...[
                        Text(
                          tr('binder'),
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
                                  prefixIcon: const Icon(Icons.folder),
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
                                    final binderColor =
                                        GroupColors.getThemedColor(
                                          binder.colorName,
                                          theme.colorScheme,
                                        );
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
                                              style: fontProvider.getTextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
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
                                onChanged: (value) {
                                  setState(() => _selectedBinderId = value);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(
                                Icons.add_circle,
                                color: theme.colorScheme.secondary,
                              ),
                              tooltip: tr('group_create_binder_tooltip'),
                              onPressed: _createNewBinder,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Divider(color: theme.colorScheme.outline),
                        const SizedBox(height: 16),
                      ],

                      // Auto-fill section
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
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
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
                            labelStyle: fontProvider.getTextStyle(fontSize: 18),
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
                          ),
                          onEditingComplete: _handleSave,
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

                      // Schedule Payment section
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
                          setState(() => _addScheduledPayment = value ?? false);
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
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
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
                      const SizedBox(height: 16),
                    ],
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
