// lib/widgets/group_editor.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/group_repo.dart';
import '../services/envelope_repo.dart';
import '../models/envelope_group.dart';
import '../models/envelope.dart';
import '../services/localization_service.dart';
import '../providers/font_provider.dart';
import 'emoji_picker_sheet.dart';

// CHANGED: Returns String? (the group ID) instead of void
Future<String?> showGroupEditor({
  required BuildContext context,
  required GroupRepo groupRepo,
  required EnvelopeRepo envelopeRepo,
  EnvelopeGroup? group,
  String? draftEnvelopeName,
}) async {
  return await Navigator.of(context).push<String?>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (ctx) => _GroupEditorScreen(
        groupRepo: groupRepo,
        envelopeRepo: envelopeRepo,
        group: group,
        draftEnvelopeName: draftEnvelopeName,
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
  });

  final GroupRepo groupRepo;
  final EnvelopeRepo envelopeRepo;
  final EnvelopeGroup? group;
  final String? draftEnvelopeName;

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
  late String selectedColor;
  late bool payDayEnabled;
  late String? editingGroupId;

  bool saving = false;
  bool didInitSelection = false;
  bool showColorPreview = false;

  // Constant for draft logic
  static const String _draftId = 'DRAFT_NEW_ENVELOPE';

  @override
  void initState() {
    super.initState();
    isEdit = widget.group != null;
    _nameCtrl = TextEditingController(text: widget.group?.name ?? '');
    selectedEnvelopeIds = <String>{};
    selectedEmoji = widget.group?.emoji ?? '📁';
    selectedColor = widget.group?.colorName ?? 'Primary';
    payDayEnabled = widget.group?.payDayEnabled ?? false;
    editingGroupId = widget.group?.id;

    if (widget.draftEnvelopeName != null) {
      selectedEnvelopeIds.add(_draftId);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Color _getPickerColor(String colorName, ColorScheme theme) {
    switch (colorName) {
      case 'Black':
        return const Color(0xFF212121);
      case 'Brown':
        return const Color(0xFF5D4037);
      case 'Grey':
        return const Color(0xFF757575);
      default:
        return GroupColors.getThemedColor(colorName, theme);
    }
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
          colorName: selectedColor,
          payDayEnabled: payDayEnabled,
        );
      } else {
        currentGroupId = await widget.groupRepo.createGroup(
          name: _nameCtrl.text.trim(),
          emoji: selectedEmoji,
          colorName: selectedColor,
          payDayEnabled: payDayEnabled,
        );
      }

      // FILTER OUT DRAFT ID before saving relationships
      final realIdsToSave = selectedEnvelopeIds
          .where((id) => id != _draftId)
          .toSet();

      await widget.envelopeRepo.updateGroupMembership(
        groupId: currentGroupId!,
        newEnvelopeIds: realIdsToSave,
        allEnvelopesStream: widget.envelopeRepo.envelopesStream(),
      );

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

  // UPDATED: Confirmation Dialog for Delete
  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('delete_binder_title')),
        content: Text(
          tr('delete_binder_confirm_msg'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('delete')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => saving = true);
      try {
        await widget.envelopeRepo.updateGroupMembership(
          groupId: editingGroupId!,
          newEnvelopeIds: {},
          allEnvelopesStream: widget.envelopeRepo.envelopesStream(),
        );
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
    final String? initial = selectedEmoji == '📁' ? null : selectedEmoji;

    final result = await showEmojiPickerSheet(
      context: context,
      initialEmoji: initial,
    );

    if (result != null) {
      setState(() {
        selectedEmoji = result.isEmpty ? '📁' : result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupIdentityColor = GroupColors.getThemedColor(
      selectedColor,
      theme.colorScheme,
    );
    final buttonColor = _getPickerColor(selectedColor, theme.colorScheme);
    final buttonTextColor = GroupColors.getContrastingTextColor(buttonColor);
    final bgTint = GroupColors.getBackgroundTint(groupIdentityColor);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return Scaffold(
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
                        groupIdentityColor.withValues(alpha: 0.3),
                        bgTint.withValues(alpha: 0.3),
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
                                Row(
                                  children: [
                                    InkWell(
                                      onTap: pickEmoji,
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        width: 70,
                                        height: 70,
                                        decoration: BoxDecoration(
                                          color: bgTint,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: groupIdentityColor,
                                            width: 2,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            selectedEmoji,
                                            style: const TextStyle(
                                              fontSize: 36,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            tr('group_binder_color'),
                                            style: fontProvider.getTextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            // UPDATED: Filter out 'Gold' and 'Yellow'
                                            children: GroupColors.colorNames
                                                .where(
                                                  (c) =>
                                                      c != 'Gold' &&
                                                      c != 'Yellow',
                                                )
                                                .map((colorName) {
                                                  final color = _getPickerColor(
                                                    colorName,
                                                    theme.colorScheme,
                                                  );
                                                  final isSelected =
                                                      selectedColor ==
                                                      colorName;
                                                  return GestureDetector(
                                                    onTap: () => setState(
                                                      () => selectedColor =
                                                          colorName,
                                                    ),
                                                    child: Container(
                                                      width: 36,
                                                      height: 36,
                                                      decoration: BoxDecoration(
                                                        color: color,
                                                        shape: BoxShape.circle,
                                                        border: isSelected
                                                            ? Border.all(
                                                                color: Colors
                                                                    .black,
                                                                width: 3,
                                                              )
                                                            : Border.all(
                                                                color: Colors
                                                                    .grey
                                                                    .shade300,
                                                              ),
                                                      ),
                                                      child: isSelected
                                                          ? Icon(
                                                              Icons.check,
                                                              color:
                                                                  GroupColors.getContrastingTextColor(
                                                                    color,
                                                                  ),
                                                              size: 20,
                                                            )
                                                          : null,
                                                    ),
                                                  );
                                                })
                                                .toList(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
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
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                      ? tr('error_enter_name')
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: payDayEnabled
                                        ? theme.colorScheme.secondary
                                              .withValues(alpha: 0.1)
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: payDayEnabled
                                          ? theme.colorScheme.secondary
                                          : Colors.grey.shade300,
                                      width: 2,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.monetization_on,
                                        color: payDayEnabled
                                            ? theme.colorScheme.secondary
                                            : Colors.grey.shade600,
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
                                                          .colorScheme
                                                          .secondary
                                                    : Colors.black,
                                              ),
                                            ),
                                            Text(
                                              tr('group_pay_day_hint'),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
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
                              ],
                            ),
                          ),
                        ),
                        StreamBuilder<List<Envelope>>(
                          stream: widget.envelopeRepo.envelopesStream(),
                          builder: (context, snapshot) {
                            var allEnvelopes =
                                (snapshot.data ?? [])
                                    .where(
                                      (e) =>
                                          e.userId ==
                                          widget.envelopeRepo.currentUserId,
                                    )
                                    .toList()
                                  ..sort((a, b) => a.name.compareTo(b.name));

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
                                    : Colors.grey.shade300;

                                return Padding(
                                  key: ValueKey(e.id),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isSelected ? bgTint : Colors.white,
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
                                                    ? GroupColors.getContrastingTextColor(
                                                        bgTint,
                                                      )
                                                    : Colors.black,
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
                          color: Colors.black.withValues(alpha: 0.05),
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
                              backgroundColor: buttonColor,
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
