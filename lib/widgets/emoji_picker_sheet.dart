// lib/widgets/emoji_picker_sheet.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/font_provider.dart';
import '../services/localization_service.dart';

Future<String?> showEmojiPickerSheet({
  required BuildContext context,
  String? initialEmoji,
  String? title,
}) async {
  final controller = TextEditingController(text: initialEmoji ?? '');
  final fontProvider = Provider.of<FontProvider>(context, listen: false);
  final theme = Theme.of(context);

  return await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 24,
        left: 24,
        right: 24,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Text(
            title ?? tr('appearance_choose_emoji'),
            style: fontProvider.getTextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr('appearance_emoji_instructions'),
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),

          const SizedBox(height: 32),

          Center(
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: TextField(
                controller: controller,
                autofocus: true,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 48),
                // Allow a bit more space for compound emojis, but logic will trim
                maxLength: 4,
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(20),
                ),
                keyboardType: TextInputType.text,
                onChanged: (value) {
                  // If characters > 2, usually means user typed a new emoji.
                  // Take the LAST entered character (grapheme cluster)
                  if (value.characters.length > 1) {
                    // This logic attempts to keep the NEWEST emoji typed
                    // and discard the old one
                    final newText = value.characters.last.toString();
                    controller.value = TextEditingValue(
                      text: newText,
                      selection: TextSelection.collapsed(
                        offset: newText.length,
                      ),
                    );
                  }
                },
                // Select all on focus so typing replaces the existing one
                onTap: () {
                  controller.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: controller.text.length,
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 32),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context, '');
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(
                  tr('reset'),
                  style: fontProvider.getTextStyle(fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(foregroundColor: Colors.grey),
              ),

              FilledButton(
                onPressed: () {
                  final emoji = controller.text.trim();
                  Navigator.pop(context, emoji);
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  tr('save'),
                  style: fontProvider.getTextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
