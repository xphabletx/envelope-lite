import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../services/group_repo.dart';
import '../services/envelope_repo.dart';
import '../services/account_repo.dart';
import '../models/envelope_group.dart';
import 'envelope/omni_icon_picker_modal.dart';
import '../models/envelope.dart';
import '../services/localization_service.dart';
import '../providers/font_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_themes.dart';
import '../data/material_icons_database.dart';
import '../data/binder_templates.dart';
import 'binder_template_selector.dart';
import 'envelope_creator.dart';

// CHANGED: Returns String? (the group ID) instead of void
Future<String?> showGroupEditor({
  required BuildContext context,
  required GroupRepo groupRepo,
  required EnvelopeRepo envelopeRepo,
  EnvelopeGroup? group,
  String? draftEnvelopeName,
}) async {
  // If creating a new binder (not editing), show template selector first
  BinderTemplate? selectedTemplate;

  if (group == null) {
    // Get existing envelopes to check which templates have been used
    final existingEnvelopes = await envelopeRepo.envelopesStream().first;

    if (!context.mounted) return null;

    // Show template selector
    final template = await Navigator.push<BinderTemplate?>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => BinderTemplateSelector(
          existingEnvelopes: existingEnvelopes,
        ),
      ),
    );

    // If user cancelled the template selector (null), return null
    if (template == null) {
      return null;
    }

    // If user selected "from scratch", don't set a template
    if (template.id != 'from_scratch') {
      selectedTemplate = template;
    }
  }

  if (!context.mounted) return null;

  // Now show the binder editor with the selected template
  return await Navigator.of(context).push<String?>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (ctx) => _GroupEditorScreen(
        groupRepo: groupRepo,
        envelopeRepo: envelopeRepo,
        group: group,
        draftEnvelopeName: draftEnvelopeName,
        initialTemplate: selectedTemplate,
      ),
    ),
  );
}

class _GroupEditorScreen extends StatefulWidget {
  const _GroupEditorScreen({
    required this.groupRepo,
    required this.envelopeRepo,
    this.group,
    this.draftEnvelopeName,
    this.initialTemplate,
  });

  final GroupRepo groupRepo;
  final EnvelopeRepo envelopeRepo;
  final EnvelopeGroup? group;
  final String? draftEnvelopeName;
  final BinderTemplate? initialTemplate;

  @override
  State<_GroupEditorScreen> createState() => _GroupEditorScreenState();
}

class _GroupEditorScreenState extends State<_GroupEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  final _scrollController = ScrollController();

  late bool isEdit;
  late Set<String> selectedEnvelopeIds;
  late String selectedEmoji;
  late String? selectedIconType;
  late String? selectedIconValue;
  late int? selectedIconColor;
  late int selectedColorIndex;
  late bool payDayEnabled;
  late String? editingGroupId;

  bool saving = false;
  bool didInitSelection = false;
  bool showColorPreview = false;

  // Track newly created envelopes in this session
  Set<String> newlyCreatedEnvelopeIds = {};

  // Track selected template to create envelopes on save
  BinderTemplate? _selectedTemplate;

  // Constant for draft logic
  static const String _draftId = 'DRAFT_NEW_ENVELOPE';

  @override
  void initState() {
    super.initState();
    isEdit = widget.group != null;
    _nameCtrl = TextEditingController(text: widget.group?.name ?? '');
    selectedEnvelopeIds = <String>{};
    selectedEmoji = widget.group?.emoji ?? '📁';
    selectedIconType = widget.group?.iconType;
    selectedIconValue = widget.group?.iconValue;
    selectedIconColor = widget.group?.iconColor;
    payDayEnabled = widget.group?.payDayEnabled ?? false;
    editingGroupId = widget.group?.id;
    selectedColorIndex = widget.group?.colorIndex ?? 0;

    if (widget.draftEnvelopeName != null) {
      selectedEnvelopeIds.add(_draftId);
    }

    // If a template was selected, apply it immediately
    if (widget.initialTemplate != null) {
      _applyTemplate(widget.initialTemplate!);
    }
  }

  void _applyTemplate(BinderTemplate template) {
    // Pre-fill name and emoji from template
    _nameCtrl.text = template.name;
    selectedEmoji = template.emoji;
    selectedIconType = 'emoji';
    selectedIconValue = template.emoji;

    // Store template for later (will create envelopes when binder is saved)
    _selectedTemplate = template;

    // Create draft IDs for each template envelope and add to selection
    for (int i = 0; i < template.envelopes.length; i++) {
      final draftId = 'DRAFT_TEMPLATE_${template.id}_$i';
      selectedEnvelopeIds.add(draftId);
      newlyCreatedEnvelopeIds.add(draftId); // Mark as NEW
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => saving = true);

    String? currentGroupId = editingGroupId;

    try {
      if (isEdit) {
        await widget.groupRepo.updateGroup(
          groupId: editingGroupId!,
          name: _nameCtrl.text.trim(),
          emoji: selectedEmoji,
          iconType: selectedIconType,
          iconValue: selectedIconValue,
          iconColor: selectedIconColor,
          colorIndex: selectedColorIndex,
          payDayEnabled: payDayEnabled,
        );
      } else {
        currentGroupId = await widget.groupRepo.createGroup(
          name: _nameCtrl.text.trim(),
          emoji: selectedEmoji,
          iconType: selectedIconType,
          iconValue: selectedIconValue,
          iconColor: selectedIconColor,
          colorIndex: selectedColorIndex,
          payDayEnabled: payDayEnabled,
        );
      }

      // Create envelopes from template NOW (if a template was selected)
      if (_selectedTemplate != null && currentGroupId != null) {
        debugPrint('[GroupEditor] Creating envelopes from template...');
        final createdIds = await _createEnvelopesFromTemplateNow(
          _selectedTemplate!,
          currentGroupId,
        );

        debugPrint('[GroupEditor] Adding ${createdIds.length} created IDs to selectedEnvelopeIds');
        debugPrint('[GroupEditor] selectedEnvelopeIds before: ${selectedEnvelopeIds.length}');
        selectedEnvelopeIds.addAll(createdIds);
        debugPrint('[GroupEditor] selectedEnvelopeIds after: ${selectedEnvelopeIds.length}');
        debugPrint('[GroupEditor] All selected IDs: $selectedEnvelopeIds');
      }

      // FILTER OUT DRAFT IDs before saving relationships
      final realIdsToSave = selectedEnvelopeIds
          .where((id) => id != _draftId && !id.startsWith('DRAFT_TEMPLATE_'))
          .toSet();

      debugPrint('[GroupEditor] ========================================');
      debugPrint('[GroupEditor] Updating group membership for binder: $currentGroupId');
      debugPrint('[GroupEditor] Envelope IDs to assign: ${realIdsToSave.length}');
      debugPrint('[GroupEditor] IDs: $realIdsToSave');
      debugPrint('[GroupEditor] ========================================');

      await widget.envelopeRepo.updateGroupMembership(
        groupId: currentGroupId!,
        newEnvelopeIds: realIdsToSave,
        allEnvelopesStream: widget.envelopeRepo.envelopesStream(),
      );

      debugPrint('[GroupEditor] ✅ Group membership updated successfully');

      if (!mounted) return;
      Navigator.of(context).pop(currentGroupId); // RETURN ID

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdit
                ? tr('success_binder_updated')
                : tr('success_binder_created'),
          ),
        ),
      );
    } catch (e) {
      setState(() => saving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${tr('error_generic')}: $e')));
    }
  }

  // UPDATED: Confirmation Dialog for Delete with two options
  Future<void> _confirmDelete() async {
    // CRITICAL: Dismiss keyboard BEFORE showing dialog to prevent screen squeeze
    FocusScope.of(context).unfocus();

    // Small delay to ensure keyboard is fully dismissed
    await Future.delayed(const Duration(milliseconds: 100));

    if (!mounted) return;

    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final theme = Theme.of(context);

    final deleteOption = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('delete_binder_title')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('delete_binder_confirm_msg'),
                style: fontProvider.getTextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
            // Option 1: Delete binder only
            InkWell(
              onTap: () => Navigator.pop(context, 'binder_only'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.folder_delete_outlined,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            tr('delete_binder_only'),
                            style: fontProvider.getTextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 40),
                      child: Text(
                        tr('delete_binder_only_desc'),
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Option 2: Delete binder and envelopes
            InkWell(
              onTap: () => Navigator.pop(context, 'binder_and_envelopes'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red.withAlpha((255 * 0.5).round())),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.red.withAlpha((255 * 0.05).round()),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.delete_forever,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            tr('delete_binder_and_envelopes'),
                            style: fontProvider.getTextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 40),
                      child: Text(
                        tr('delete_binder_and_envelopes_desc'),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.red.withAlpha((255 * 0.8).round()),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text(tr('cancel')),
          ),
        ],
      ),
    );

    if (deleteOption != null) {
      setState(() => saving = true);
      try {
        if (deleteOption == 'binder_and_envelopes') {
          // Get all envelopes in this binder
          final allEnvelopes = await widget.envelopeRepo.envelopesStream().first;
          final envelopesToDelete = allEnvelopes
              .where((e) => e.groupId == editingGroupId)
              .map((e) => e.id)
              .toList();

          // Delete all envelopes in the binder
          for (final envelopeId in envelopesToDelete) {
            await widget.envelopeRepo.deleteEnvelope(envelopeId);
          }
        } else {
          // Just remove envelopes from the binder (don't delete them)
          await widget.envelopeRepo.updateGroupMembership(
            groupId: editingGroupId!,
            newEnvelopeIds: {},
            allEnvelopesStream: widget.envelopeRepo.envelopesStream(),
          );
        }

        // Delete the binder itself
        await widget.groupRepo.deleteGroup(groupId: editingGroupId!);

        if (mounted) Navigator.pop(context);
      } catch (e) {
        setState(() => saving = false);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting binder: $e')));
        }
      }
    }
  }

  Future<void> pickEmoji() async {
    // Dismiss keyboard before showing modal
    FocusScope.of(context).unfocus();

    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OmniIconPickerModal(
        initialQuery: _nameCtrl.text.trim(), // Pre-populate with binder name
      ),
    );

    if (result != null) {
      final iconType = result['type'] as String;
      final iconValue = result['value'] as String;
      final iconColor = result['color'] as int?;

      setState(() {
        selectedIconType = iconType;
        selectedIconValue = iconValue;
        selectedIconColor = iconColor;

        // Keep emoji for backwards compatibility
        if (iconType == 'emoji') {
          selectedEmoji = iconValue;
        }
      });
    }
  }

  /// Actually create envelopes from template when binder is saved
  Future<List<String>> _createEnvelopesFromTemplateNow(
    BinderTemplate template,
    String groupId,
  ) async {
    debugPrint('[Template] ========================================');
    debugPrint('[Template] Creating envelopes from template: ${template.name}');
    debugPrint('[Template] Binder ID: $groupId');
    debugPrint('[Template] Template has ${template.envelopes.length} envelopes');
    debugPrint('[Template] ========================================');

    final createdIds = <String>[];

    try {
      // Create all envelopes from template with emojis and groupId
      for (final envelope in template.envelopes) {
        debugPrint('[Template] Creating envelope: ${envelope.name} (${envelope.emoji})');

        final envelopeId = await widget.envelopeRepo.createEnvelope(
          name: envelope.name,
          startingAmount: 0.0,
          targetAmount: null,
          emoji: envelope.emoji,
          subtitle: null,
          autoFillEnabled: false,
          autoFillAmount: null,
          groupId: groupId, // Assign to binder immediately
        );

        createdIds.add(envelopeId);
        debugPrint('[Template] ✅ Created: ${envelope.name} → Binder: $groupId (ID: $envelopeId)');
      }

      debugPrint('[Template] ========================================');
      debugPrint('[Template] ✅ Created ${createdIds.length} envelopes');
      debugPrint('[Template] Envelope IDs: $createdIds');
      debugPrint('[Template] ========================================');
    } catch (e, stackTrace) {
      debugPrint('[Template] ❌ FAILED to create envelopes: $e');
      debugPrint('[Template] Stack trace: $stackTrace');
      rethrow;
    }

    return createdIds;
  }

  Future<void> _createNewEnvelope() async {
    final accountRepo = AccountRepo(widget.envelopeRepo);

    // Store IDs before opening creator
    final beforeIds = await widget.envelopeRepo.envelopesStream().first;
    final beforeIdSet = beforeIds.map((e) => e.id).toSet();

    await showEnvelopeCreator(
      context, // ignore: use_build_context_synchronously
      repo: widget.envelopeRepo,
      groupRepo: widget.groupRepo,
      accountRepo: accountRepo,
      preselectedBinderId: editingGroupId,
    );

    // Check for newly created envelope
    if (mounted) {
      final afterIds = await widget.envelopeRepo.envelopesStream().first;
      final afterIdSet = afterIds.map((e) => e.id).toSet();
      final newIds = afterIdSet.difference(beforeIdSet);

      if (newIds.isNotEmpty) {
        setState(() {
          selectedEnvelopeIds.addAll(newIds);
          newlyCreatedEnvelopeIds.addAll(newIds);
        });

        // Scroll to bottom to show the new envelope
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }
  }

  Widget _buildIconDisplay(ThemeData theme) {
    // Use new icon system if available
    if (selectedIconType != null && selectedIconValue != null) {
      switch (selectedIconType) {
        case 'emoji':
          return Text(
            selectedIconValue!,
            style: const TextStyle(fontSize: 36),
          );

        case 'materialIcon':
          final iconData = materialIconsDatabase[selectedIconValue!]?['icon'] as IconData? ?? Icons.circle;
          return Icon(
            iconData,
            size: 36,
            color: selectedIconColor != null
                ? Color(selectedIconColor!)
                : theme.colorScheme.primary,
          );

        case 'companyLogo':
          final logoUrl =
              'https://www.google.com/s2/favicons?sz=128&domain=$selectedIconValue';
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: logoUrl,
              width: 36,
              height: 36,
              fit: BoxFit.contain,
              placeholder: (context, url) => SizedBox(
                width: 36,
                height: 36,
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              errorWidget: (context, url, error) {
                return Text(
                  selectedEmoji,
                  style: const TextStyle(fontSize: 36),
                );
              },
            ),
          );

        default:
          return Text(
            selectedEmoji,
            style: const TextStyle(fontSize: 36),
          );
      }
    }

    // Fallback to emoji
    return Text(
      selectedEmoji,
      style: const TextStyle(fontSize: 36),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context);

    final availableColors =
        ThemeBinderColors.getColorsForTheme(themeProvider.currentThemeId);
    final binderColorOption = availableColors[selectedColorIndex];

    final groupIdentityColor = binderColorOption.binderColor;
    final buttonTextColor =
        ThemeData.estimateBrightnessForColor(groupIdentityColor) ==
                Brightness.dark
            ? Colors.white
            : Colors.black;
    final bgTint = binderColorOption.paperColor;

    return Scaffold(
      resizeToAvoidBottomInset: false, // Prevent screen squeeze when keyboard appears
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          if (showColorPreview)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        groupIdentityColor.withAlpha((255 * 0.3).round()),
                        bgTint.withAlpha((255 * 0.3).round()),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Text(
                          isEdit
                              ? tr('group_edit_binder')
                              : tr('group_new_binder'),
                          style: fontProvider.getTextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            color: theme.colorScheme.primary,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Binder Color Selection (moved to top)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tr('group_binder_color'),
                                      style: fontProvider.getTextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: availableColors
                                          .asMap()
                                          .entries
                                          .map((entry) {
                                        final index = entry.key;
                                        final colorOption = entry.value;
                                        final isSelected =
                                            selectedColorIndex == index;
                                        return GestureDetector(
                                          onTap: () => setState(
                                            () => selectedColorIndex = index,
                                          ),
                                          child: Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: colorOption.binderColor,
                                              shape: BoxShape.circle,
                                              border: isSelected
                                                  ? Border.all(
                                                      color: Colors.black,
                                                      width: 3,
                                                    )
                                                  : Border.all(
                                                      color:
                                                          Colors.grey.shade300,
                                                    ),
                                            ),
                                            child: isSelected
                                                ? Icon(
                                                    Icons.check,
                                                    color: buttonTextColor,
                                                    size: 20,
                                                  )
                                                : null,
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                // Binder Name Field
                                TextFormField(
                                  controller: _nameCtrl,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: InputDecoration(
                                    labelText: tr('group_binder_name_label'),
                                    labelStyle: fontProvider.getTextStyle(
                                      fontSize: 16,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  style: fontProvider.getTextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  validator: (v) => (v == null ||
                                          v.trim().isEmpty)
                                      ? tr('error_enter_name')
                                      : null,
                                  onTap: () => _nameCtrl.selection = TextSelection(
                                    baseOffset: 0,
                                    extentOffset: _nameCtrl.text.length,
                                  ),
                                  onEditingComplete: () {
                                    // Dismiss keyboard when user presses done
                                    FocusScope.of(context).unfocus();
                                  },
                                  onTapOutside: (_) {
                                    // Dismiss keyboard when user taps outside
                                    FocusScope.of(context).unfocus();
                                  },
                                ),
                                const SizedBox(height: 16),
                                // Icon picker
                                InkWell(
                                  onTap: pickEmoji,
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
                                        if (selectedIconType != null &&
                                            selectedIconValue != null)
                                          SizedBox(
                                            width: 32,
                                            height: 32,
                                            child: _buildIconDisplay(theme),
                                          )
                                        else
                                          const Icon(
                                            Icons.add_photo_alternate_outlined,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: payDayEnabled
                                        ? theme.colorScheme.secondary
                                            .withAlpha((255 * 0.1).round())
                                        : theme.colorScheme.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: payDayEnabled
                                          ? theme.colorScheme.secondary
                                          : theme.colorScheme.outline,
                                      width: 2,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.monetization_on,
                                        color: payDayEnabled
                                            ? theme.colorScheme.secondary
                                            : theme.colorScheme.onSurface
                                                .withAlpha((255 * 0.6).round()),
                                        size: 28,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              tr('group_pay_day_auto'),
                                              style: fontProvider.getTextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: payDayEnabled
                                                    ? theme
                                                        .colorScheme.secondary
                                                    : theme.colorScheme.onSurface,
                                              ),
                                            ),
                                            Text(
                                              tr('group_pay_day_hint'),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: theme.colorScheme.onSurface
                                                    .withAlpha((255 * 0.6).round()),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Switch(
                                        value: payDayEnabled,
                                        onChanged: (v) =>
                                            setState(() => payDayEnabled = v),
                                        activeThumbColor:
                                            theme.colorScheme.secondary,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  tr('group_assign_envelopes'),
                                  style: fontProvider.getTextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // "Create New Envelope" button
                                InkWell(
                                  onTap: _createNewEnvelope,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: theme.colorScheme.primary,
                                        width: 2,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.add,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Create New Envelope',
                                                style: fontProvider.getTextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: theme.colorScheme.onPrimaryContainer,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Add a custom envelope to this binder',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: theme.colorScheme.onPrimaryContainer.withAlpha(179),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.arrow_forward_ios,
                                          size: 16,
                                          color: theme.colorScheme.onPrimaryContainer,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                            ),
                          ),
                        ),
                        StreamBuilder<List<Envelope>>(
                          stream: widget.envelopeRepo.envelopesStream(),
                          builder: (context, snapshot) {
                            var allEnvelopes = (snapshot.data ?? [])
                                .where(
                                  (e) =>
                                      e.userId ==
                                      widget.envelopeRepo.currentUserId,
                                )
                                .toList()
                              ..sort((a, b) => a.name.compareTo(b.name));

                            // Add draft envelope from envelope creator (if any)
                            if (widget.draftEnvelopeName != null &&
                                widget.draftEnvelopeName!.isNotEmpty) {
                              final draftEnv = Envelope(
                                id: _draftId,
                                name: "${widget.draftEnvelopeName} (New)",
                                userId: widget.envelopeRepo.currentUserId,
                                emoji: '📁',
                                currentAmount: 0,
                              );
                              allEnvelopes.insert(0, draftEnv);
                            }

                            // Add draft envelopes from template (if any)
                            if (_selectedTemplate != null) {
                              for (int i = 0; i < _selectedTemplate!.envelopes.length; i++) {
                                final templateEnv = _selectedTemplate!.envelopes[i];
                                final draftId = 'DRAFT_TEMPLATE_${_selectedTemplate!.id}_$i';
                                final draftEnv = Envelope(
                                  id: draftId,
                                  name: '${templateEnv.name} (New)',
                                  userId: widget.envelopeRepo.currentUserId,
                                  emoji: templateEnv.emoji,
                                  currentAmount: 0,
                                );
                                allEnvelopes.insert(0, draftEnv);
                              }
                            }

                            if (snapshot.connectionState ==
                                    ConnectionState.waiting &&
                                allEnvelopes.isEmpty) {
                              return const SliverToBoxAdapter(
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            if (isEdit && !didInitSelection) {
                              for (final e in allEnvelopes) {
                                if (e.groupId == editingGroupId) {
                                  selectedEnvelopeIds.add(e.id);
                                }
                              }
                              didInitSelection = true;
                            }
                            return SliverList(
                              delegate: SliverChildBuilderDelegate((
                                context,
                                i,
                              ) {
                                final e = allEnvelopes[i];
                                final isSelected = selectedEnvelopeIds.contains(
                                  e.id,
                                );
                                final borderColor = isSelected
                                    ? groupIdentityColor
                                    : theme.colorScheme.outline;

                                return Padding(
                                  key: ValueKey(e.id),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? bgTint
                                          : theme.colorScheme.surface,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: borderColor,
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: CheckboxListTile(
                                      value: isSelected,
                                      onChanged: (v) => setState(
                                        () => v == true
                                            ? selectedEnvelopeIds.add(e.id)
                                            : selectedEnvelopeIds.remove(e.id),
                                      ),
                                      activeColor: groupIdentityColor,
                                      checkColor: buttonTextColor,
                                      title: Row(
                                        children: [
                                          if (e.emoji != null)
                                            Text(
                                              e.emoji!,
                                              style: const TextStyle(
                                                fontSize: 20,
                                              ),
                                            ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              e.name,
                                              style: fontProvider.getTextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: isSelected
                                                    ? ThemeData.estimateBrightnessForColor(bgTint) == Brightness.dark
                                                        ? Colors.white
                                                        : Colors.black
                                                    : theme.colorScheme.onSurface,
                                              ),
                                            ),
                                          ),
                                          // NEW badge for newly created envelopes
                                          if (newlyCreatedEnvelopeIds.contains(e.id))
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: theme.colorScheme.secondary,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                'NEW',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }, childCount: allEnvelopes.length),
                            );
                          },
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 20)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withAlpha((255 * 0.05).round()),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: groupIdentityColor,
                              foregroundColor: buttonTextColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: saving ? null : save,
                            child: saving
                                ? CircularProgressIndicator(
                                    color: buttonTextColor,
                                  )
                                : FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      isEdit
                                          ? tr('save_changes')
                                          : tr('group_create_binder'),
                                      style: fontProvider.getTextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        if (isEdit) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton.icon(
                              icon: const Icon(
                                Icons.delete_forever,
                                color: Colors.red,
                              ),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  tr('group_delete_binder'),
                                  style: fontProvider.getTextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Colors.red,
                                  width: 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              // CHANGED: Now calls _confirmDelete
                              onPressed: saving ? null : _confirmDelete,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
