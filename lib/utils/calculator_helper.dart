// lib/utils/calculator_helper.dart
import 'package:flutter/material.dart';
import '../widgets/calculator_widget.dart';

class CalculatorHelper {
  /// Shows calculator modal and returns result if user completes a calculation.
  /// Returns null if user dismisses without completing.
  /// After dismissal, keyboard is NOT automatically opened.
  static Future<String?> showCalculator(BuildContext context) async {
    String? result;

    // Unfocus any current field to prevent keyboard from re-appearing
    FocusScope.of(context).unfocus();

    await showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        return Stack(
          children: [
            CalculatorWidget(
              onResultSelected: (value) {
                result = value;
              },
            ),
          ],
        );
      },
    );

    // CRITICAL: After calculator closes, ensure keyboard doesn't auto-open
    // We do this by maintaining unfocused state
    if (context.mounted) {
      FocusScope.of(context).unfocus();
    }

    return result;
  }
}
