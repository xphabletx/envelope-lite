import 'package:flutter/material.dart';

/// Centralized dialog helpers for consistent user confirmations across the app.
///
/// Follows the principle: Use pop-ups when user cannot continue without
/// making a decision or when the action is destructive/irreversible.

class DialogHelpers {
  DialogHelpers._();

  /// Shows a confirmation dialog for destructive actions.
  ///
  /// Returns true if user confirmed, false if cancelled.
  ///
  /// Use this for:
  /// - Deleting accounts, envelopes, binders
  /// - Permanent data loss scenarios
  /// - Actions that cannot be undone
  static Future<bool> showDestructiveConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Delete',
    String cancelLabel = 'Cancel',
    IconData? icon,
  }) async {
    if (!context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.red.shade600),
              const SizedBox(width: 12),
            ],
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade600,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// Shows a confirmation dialog with two distinct choices.
  ///
  /// Returns the user's choice as a boolean:
  /// - true: Primary action chosen
  /// - false: Secondary action chosen
  /// - null: Dialog dismissed without choice
  ///
  /// Use this for:
  /// - "Discard changes" vs "Keep editing"
  /// - "Save" vs "Don't save"
  /// - Any scenario with two valid options
  static Future<bool?> showChoiceDialog({
    required BuildContext context,
    required String title,
    required String message,
    required String primaryLabel,
    required String secondaryLabel,
    IconData? icon,
    bool isPrimaryDestructive = false,
  }) async {
    if (!context.mounted) return null;

    return await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            if (icon != null) ...[
              Icon(icon),
              const SizedBox(width: 12),
            ],
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(secondaryLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: isPrimaryDestructive
                ? FilledButton.styleFrom(backgroundColor: Colors.red.shade600)
                : null,
            child: Text(primaryLabel),
          ),
        ],
      ),
    );
  }

  /// Shows a simple informational dialog.
  ///
  /// Use this for:
  /// - App update required
  /// - Important announcements
  /// - Critical information that blocks progress
  static Future<void> showInfoDialog({
    required BuildContext context,
    required String title,
    required String message,
    String buttonLabel = 'OK',
    IconData? icon,
    bool barrierDismissible = true,
  }) async {
    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.blue.shade600),
              const SizedBox(width: 12),
            ],
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }

  /// Shows a confirmation dialog for bulk operations.
  ///
  /// Displays the count of items that will be affected.
  ///
  /// Use this for:
  /// - Bulk delete operations
  /// - Batch updates
  /// - Multiple item operations
  static Future<bool> showBulkActionConfirmation({
    required BuildContext context,
    required String title,
    required int itemCount,
    required String itemType,
    required String action,
    String? additionalWarning,
  }) async {
    if (!context.mounted) return false;

    final message = StringBuffer();
    message.write('Are you sure you want to $action $itemCount $itemType');
    message.write(itemCount == 1 ? '?' : 's?');

    if (additionalWarning != null) {
      message.write('\n\n$additionalWarning');
    }

    return await showDestructiveConfirmation(
      context: context,
      title: title,
      message: message.toString(),
      confirmLabel: action.substring(0, 1).toUpperCase() + action.substring(1),
      icon: Icons.warning_amber_rounded,
    );
  }

  /// Shows a loading dialog that blocks user interaction.
  ///
  /// Returns a function to close the dialog.
  ///
  /// Use this for:
  /// - Long-running operations (>2 seconds)
  /// - Network requests that block UI
  ///
  /// Example:
  /// ```dart
  /// final closeDialog = DialogHelpers.showLoadingDialog(context, 'Deleting account...');
  /// try {
  ///   await performLongOperation();
  /// } finally {
  ///   closeDialog();
  /// }
  /// ```
  static VoidCallback showLoadingDialog(
    BuildContext context,
    String message,
  ) {
    if (!context.mounted) return () {};

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    );

    return () {
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    };
  }

  /// Shows a dialog with a text input field.
  ///
  /// Returns the entered text, or null if cancelled.
  ///
  /// Use this for:
  /// - Renaming items
  /// - Adding notes/descriptions
  /// - Quick text input
  static Future<String?> showTextInputDialog({
    required BuildContext context,
    required String title,
    String? message,
    String? initialValue,
    String? hintText,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    int? maxLength,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) async {
    if (!context.mounted) return null;

    final controller = TextEditingController(text: initialValue);
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message != null) ...[
                Text(message),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: controller,
                autofocus: false,
                maxLength: maxLength,
                keyboardType: keyboardType,
                decoration: InputDecoration(
                  hintText: hintText,
                  border: const OutlineInputBorder(),
                ),
                validator: validator,
                onFieldSubmitted: (value) {
                  if (formKey.currentState?.validate() ?? false) {
                    Navigator.of(context).pop(value);
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(context).pop(controller.text);
              }
            },
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    controller.dispose();
    return result;
  }
}
