// lib/widgets/emoji_picker_button.dart
import 'package:flutter/material.dart';

/// A button that opens a clean emoji picker dialog
/// Uses native keyboard but with better UX than a raw TextField
class EmojiPickerButton extends StatelessWidget {
  const EmojiPickerButton({
    super.key,
    required this.currentEmoji,
    required this.onEmojiSelected,
    this.size = 60.0,
    this.maxLength = 2,
  });

  final String currentEmoji;
  final ValueChanged<String> onEmojiSelected;
  final double size;
  final int maxLength;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showEmojiPicker(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Center(
          child: Text(currentEmoji, style: TextStyle(fontSize: size * 0.5)),
        ),
      ),
    );
  }

  Future<void> _showEmojiPicker(BuildContext context) async {
    final controller = TextEditingController(text: currentEmoji);

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Choose Emoji', style: TextStyle(fontSize: 20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tap below to open emoji keyboard',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            // The actual emoji input field
            GestureDetector(
              onTap: () {
                // Focus the hidden text field
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                child: TextField(
                  controller: controller,
                  autofocus: false, // Changed from true
                  maxLength: maxLength,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 80),
                  showCursor: false, // Hide cursor for cleaner look
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                    hintText: '🥰',
                    hintStyle: TextStyle(fontSize: 80),
                  ),
                  onChanged: (value) {
                    if (value.characters.length > maxLength) {
                      controller.text = value.characters.take(maxLength).join();
                      controller.selection = TextSelection.fromPosition(
                        TextPosition(offset: controller.text.length),
                      );
                    }
                  },
                  onTap: () {
                    // Select all on tap for easy replacement
                    controller.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: controller.text.length,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Pick any emoji from your keyboard',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final emoji = controller.text.trim();
              if (emoji.isNotEmpty) {
                onEmojiSelected(emoji);
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
