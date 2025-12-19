import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../services/group_repo.dart';
import '../services/envelope_repo.dart';
import '../models/envelope_group.dart';
import 'envelope/omni_icon_picker_modal.dart';
import '../models/envelope.dart';
import '../services/localization_service.dart';
import '../providers/font_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_themes.dart';
import '../data/material_icons_database.dart';

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
  late String? selectedIconType;
  late String? selectedIconValue;
  late int? selectedIconColor;
  late int selectedColorIndex;
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
    selectedIconType = widget.group?.iconType;
    selectedIconValue = widget.group?.iconValue;
    selectedIconColor = widget.group?.iconColor;
    payDayEnabled = widget.group?.payDayEnabled ?? false;
    editingGroupId = widget.group?.id;
    selectedColorIndex = widget.group?.colorIndex ?? 0;

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

      // FILTER OUT DRAFT ID before saving relationships
      final realIdsToSave =
          selectedEnvelopeIds.where((id) => id != _draftId).toSet();

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
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const OmniIconPickerModal(),
    );

    if (result != null) {
      final iconType = result['type'].toString().split('.').last;
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
                                          child: _buildIconDisplay(theme),
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
                                                  () =>
                                                      selectedColorIndex = index,
                                                ),
                                                child: Container(
                                                  width: 36,
                                                  height: 36,
                                                  decoration: BoxDecoration(
                                                    color:
                                                        colorOption.binderColor,
                                                    shape: BoxShape.circle,
                                                    border: isSelected
                                                        ? Border.all(
                                                            color: Colors.black,
                                                            width: 3,
                                                          )
                                                        : Border.all(
                                                            color: Colors.grey
                                                                .shade300,
                                                          ),
                                                  ),
                                                  child: isSelected
                                                      ? Icon(
                                                          Icons.check,
                                                          color:
                                                              buttonTextColor,
                                                          size: 20,
                                                        )
                                                      : null,
                                                ),
                                              );
                                            }).toList(),
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
                                  validator: (v) => (v == null ||
                                          v.trim().isEmpty)
                                      ? tr('error_enter_name')
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: payDayEnabled
                                        ? theme.colorScheme.secondary
                                            .withAlpha((255 * 0.1).round())
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
                                                        .colorScheme.secondary
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
                            var allEnvelopes = (snapshot.data ?? [])
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
                                      color: isSelected
                                          ? bgTint
                                          : Colors.white,
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
