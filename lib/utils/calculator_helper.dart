// lib/utils/calculator_helper.dart
import 'package:flutter/material.dart';
import '../widgets/calculator_widget.dart';

class CalculatorHelper {
  static Future<String?> showCalculator(BuildContext context) async {
    String? result;
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

    return result;
  }
}
