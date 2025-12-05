// lib/widgets/group_editor.dart
// FONT PROVIDER INTEGRATED: All GoogleFonts.caveat() replaced with FontProvider
// All button text wrapped in FittedBox to prevent wrapping

import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // NEW IMPORT
import 'package:google_fonts/google_fonts.dart';
import '../services/group_repo.dart';
import '../services/envelope_repo.dart';
import '../models/envelope_group.dart';
import '../models/envelope.dart';
import '../services/localization_service.dart';
import '../providers/font_provider.dart'; // NEW IMPORT

Future<void> showGroupEditor({
  required BuildContext context,
  required GroupRepo groupRepo,
  required EnvelopeRepo envelopeRepo,
  EnvelopeGroup? group,
}) async {
  final isEdit = group != null;
  final nameCtrl = TextEditingController(text: group?.name ?? '');
  final formKey = GlobalKey<FormState>();

  // State
  final selectedEnvelopeIds = <String>{};
  String selectedEmoji = group?.emoji ?? '📁';
  String selectedColor = group?.colorName ?? 'Primary';
  bool payDayEnabled = group?.payDayEnabled ?? false;

  bool saving = false;
  bool didInitSelection = false;
  bool showColorPreview = false;
  final String? editingGroupId = group?.id;

  final scrollController = ScrollController();

  // Helper to get the "Real" color for the picker UI (so Black looks Black, not White)
  Color _getPickerColor(String colorName, ColorScheme theme) {
    switch (colorName) {
      case 'Black':
        return const Color(0xFF212121);
      case 'Brown':
        return const Color(0xFF5D4037); // Matches the Walnut base
      case 'Grey':
        return const Color(0xFF757575);
      default:
        // For standard colors, the Identity color is the color itself
        return GroupColors.getThemedColor(colorName, theme);
    }
  }

  await Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final theme = Theme.of(ctx);

          // Use standard logic for the "Preview" elements (Identity/Tint)
          final groupIdentityColor = GroupColors.getThemedColor(
            selectedColor,
            theme.colorScheme,
          );

          // For buttons, if identity is White (Black binder), we need a dark button background
          // So we use the "Picker Color" for button backgrounds to ensure visibility
          final buttonColor = _getPickerColor(selectedColor, theme.colorScheme);
          final buttonTextColor = GroupColors.getContrastingTextColor(
            buttonColor,
          );

          final bgTint = GroupColors.getBackgroundTint(groupIdentityColor);
          final fontProvider = Provider.of<FontProvider>(ctx, listen: false);

          Future<void> save() async {
            if (!formKey.currentState!.validate()) return;
            setLocal(() => saving = true);

            String? currentGroupId = editingGroupId;

            try {
              if (isEdit) {
                await groupRepo.updateGroup(
                  groupId: editingGroupId!,
                  name: nameCtrl.text.trim(),
                  emoji: selectedEmoji,
                  colorName: selectedColor,
                  payDayEnabled: payDayEnabled,
                );
              } else {
                currentGroupId = await groupRepo.createGroup(
                  name: nameCtrl.text.trim(),
                  emoji: selectedEmoji,
                  colorName: selectedColor,
                  payDayEnabled: payDayEnabled,
                );
              }

              await envelopeRepo.updateGroupMembership(
                groupId: currentGroupId!,
                newEnvelopeIds: selectedEnvelopeIds,
                allEnvelopesStream: envelopeRepo.envelopesStream(),
              );

              if (!ctx.mounted) return;
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text(
                    isEdit
                        ? tr('success_binder_updated')
                        : tr('success_binder_created'),
                  ),
                ),
              );
            } catch (e) {
              setLocal(() => saving = false);
              if (!ctx.mounted) return;
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(content: Text('${tr('error_generic')}: $e')),
              );
            }
          }

          Future<void> showEmojiPicker() async {
            final controller = TextEditingController(text: selectedEmoji);
            await showDialog(
              context: ctx,
              builder: (dialogContext) => AlertDialog(
                title: Text(
                  tr('appearance_choose_emoji'),
                  // UPDATED: FontProvider
                  style: fontProvider.getTextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: SingleChildScrollView(
                  child: SizedBox(
                    width: 200,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tr('appearance_emoji_instructions_short'),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
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
                            if (value.isNotEmpty) {
                              controller.text = value.characters.first;
                              controller.selection = TextSelection.fromPosition(
                                const TextPosition(offset: 1),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      setLocal(() => selectedEmoji = '📁');
                    },
                    child: FittedBox(
                      // UPDATED: FittedBox
                      fit: BoxFit.scaleDown,
                      child: Text(
                        tr('reset'),
                        // UPDATED: FontProvider
                        style: fontProvider.getTextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      setLocal(
                        () => selectedEmoji = controller.text.isNotEmpty
                            ? controller.text
                            : '📁',
                      );
                    },
                    child: FittedBox(
                      // UPDATED: FittedBox
                      fit: BoxFit.scaleDown,
                      child: Text(
                        tr('save'),
                        // UPDATED: FontProvider
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
                              groupIdentityColor.withOpacity(0.3),
                              bgTint.withOpacity(0.3),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                SafeArea(
                  child: Form(
                    key: formKey,
                    child: Column(
                      children: [
                        // 1. HEADER (Fixed)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Text(
                                isEdit
                                    ? tr('group_edit_binder')
                                    : tr('group_new_binder'),
                                // UPDATED: FontProvider
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
                                onPressed: () => Navigator.of(ctx).pop(),
                              ),
                            ],
                          ),
                        ),

                        // 2. SCROLLABLE CONTENT (Form Fields + Envelope List)
                        Expanded(
                          child: CustomScrollView(
                            controller: scrollController,
                            slivers: [
                              // 2a. Form Fields (Moved into ScrollView to avoid overflow)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Emoji + Color
                                      Row(
                                        children: [
                                          InkWell(
                                            onTap: showEmojiPicker,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            child: Container(
                                              width: 70,
                                              height: 70,
                                              decoration: BoxDecoration(
                                                color: bgTint,
                                                borderRadius:
                                                    BorderRadius.circular(16),
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
                                                  // UPDATED: FontProvider
                                                  style: fontProvider
                                                      .getTextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                                const SizedBox(height: 8),
                                                Wrap(
                                                  spacing: 8,
                                                  runSpacing: 8,
                                                  children: GroupColors.colorNames.map((
                                                    colorName,
                                                  ) {
                                                    // USE PICKER COLOR FOR BUBBLES
                                                    final color =
                                                        _getPickerColor(
                                                          colorName,
                                                          theme.colorScheme,
                                                        );

                                                    final isSelected =
                                                        selectedColor ==
                                                        colorName;
                                                    return GestureDetector(
                                                      onTap: () => setLocal(
                                                        () => selectedColor =
                                                            colorName,
                                                      ),
                                                      onLongPress: () {
                                                        setLocal(() {
                                                          selectedColor =
                                                              colorName;
                                                          showColorPreview =
                                                              true;
                                                        });
                                                        Future.delayed(
                                                          const Duration(
                                                            seconds: 2,
                                                          ),
                                                          () {
                                                            if (ctx.mounted) {
                                                              setLocal(
                                                                () =>
                                                                    showColorPreview =
                                                                        false,
                                                              );
                                                            }
                                                          },
                                                        );
                                                      },
                                                      child: Container(
                                                        width: 36,
                                                        height: 36,
                                                        decoration: BoxDecoration(
                                                          color: color,
                                                          shape:
                                                              BoxShape.circle,
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
                                                  }).toList(),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),

                                      // Name Field
                                      TextFormField(
                                        controller: nameCtrl,
                                        textCapitalization:
                                            TextCapitalization.words,
                                        decoration: InputDecoration(
                                          labelText: tr(
                                            'group_binder_name_label',
                                          ),
                                          // UPDATED: FontProvider
                                          labelStyle: fontProvider.getTextStyle(
                                            fontSize: 16,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        // UPDATED: FontProvider
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

                                      // PAY DAY TOGGLE
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: payDayEnabled
                                              ? theme.colorScheme.secondary
                                                    .withOpacity(0.1)
                                              : Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
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
                                                    // UPDATED: FontProvider
                                                    style: fontProvider
                                                        .getTextStyle(
                                                          fontSize: 20,
                                                          fontWeight:
                                                              FontWeight.bold,
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
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Switch(
                                              value: payDayEnabled,
                                              onChanged: (v) => setLocal(
                                                () => payDayEnabled = v,
                                              ),
                                              activeColor:
                                                  theme.colorScheme.secondary,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 16),

                                      Text(
                                        tr('group_assign_envelopes'),
                                        // UPDATED: FontProvider
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

                              // 2b. Envelope List (StreamBuilder -> SliverList)
                              StreamBuilder<List<Envelope>>(
                                stream: envelopeRepo.envelopesStream(),
                                builder: (context, snapshot) {
                                  final allEnvelopes =
                                      (snapshot.data ?? [])
                                          .where(
                                            (e) =>
                                                e.userId ==
                                                envelopeRepo.currentUserId,
                                          )
                                          .toList()
                                        ..sort(
                                          (a, b) => a.name.compareTo(b.name),
                                        );

                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
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
                                      final isSelected = selectedEnvelopeIds
                                          .contains(e.id);

                                      // Use Identity color for border when selected
                                      // (For Black/Brown, this will be White/Cream)
                                      // For standard colors, it will be the color itself
                                      final borderColor = isSelected
                                          ? groupIdentityColor
                                          : Colors.grey.shade300;

                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 4,
                                        ),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            // FIX: Background is bgTint.
                                            // For Brown/Black, bgTint is Dark.
                                            color: isSelected
                                                ? bgTint
                                                : Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: borderColor,
                                              width: isSelected ? 2 : 1,
                                            ),
                                          ),
                                          child: CheckboxListTile(
                                            value: isSelected,
                                            onChanged: (v) {
                                              setLocal(
                                                () => v == true
                                                    ? selectedEnvelopeIds.add(
                                                        e.id,
                                                      )
                                                    : selectedEnvelopeIds
                                                          .remove(e.id),
                                              );
                                            },
                                            activeColor: groupIdentityColor,
                                            checkColor:
                                                buttonTextColor, // Ensure checkmark is visible against identity color
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
                                                    // FIX: Explicitly set text color
                                                    style: fontProvider
                                                        .getTextStyle(
                                                          fontSize: 18,
                                                          fontWeight:
                                                              FontWeight.bold,
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
                              // Bottom padding for scrolling
                              const SliverToBoxAdapter(
                                child: SizedBox(height: 20),
                              ),
                            ],
                          ),
                        ),

                        // 3. BUTTONS (Fixed at bottom)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.scaffoldBackgroundColor,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
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
                                    // Use "Picker Color" (solid) for button background
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
                                          // UPDATED: FittedBox
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            isEdit
                                                ? tr('save_changes')
                                                : tr('group_create_binder'),
                                            // UPDATED: FontProvider
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
                                      // UPDATED: FittedBox
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        tr('group_delete_binder'),
                                        // UPDATED: FontProvider
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
                                    onPressed: saving
                                        ? null
                                        : () async {
                                            setLocal(() => saving = true);
                                            await envelopeRepo
                                                .updateGroupMembership(
                                                  groupId: editingGroupId!,
                                                  newEnvelopeIds: {},
                                                  allEnvelopesStream:
                                                      envelopeRepo
                                                          .envelopesStream(),
                                                );
                                            await groupRepo.deleteGroup(
                                              groupId: editingGroupId!,
                                            );
                                            if (ctx.mounted) {
                                              Navigator.pop(ctx);
                                            }
                                          },
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
        },
      ),
    ),
  );
}
