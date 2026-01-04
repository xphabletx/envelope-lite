// lib/widgets/emoji_picker_sheet.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/font_provider.dart';
import '../services/localization_service.dart';
import '../widgets/common/smart_text_field.dart';

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
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr('appearance_emoji_instructions'),
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),

          const SizedBox(height: 24),

          // Big input field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            child: SmartTextField(
              controller: controller,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 64),
              decoration: const InputDecoration(
                border: InputBorder.none,
                counterText: '',
              ),
              maxLength: 1,
              onChanged: (value) {
                if (value.isNotEmpty) {
                  // Auto-close on selection if desired, or let them hit save
                }
              },
              onSubmitted: (value) {
                Navigator.pop(context, value);
              },
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
