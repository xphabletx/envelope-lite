import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

class EnvelopeActionButtons extends StatelessWidget {
  const EnvelopeActionButtons({
    super.key,
    required this.onAddMoney,
    required this.onTakeMoney,
    required this.onMoveMoney,
    required this.onCalculator,
  });

  final VoidCallback onAddMoney;
  final VoidCallback onTakeMoney;
  final VoidCallback onMoveMoney;
  final VoidCallback onCalculator;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SpeedDial(
      icon: Icons.add,
      activeIcon: Icons.close,
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: Colors.white,
      activeBackgroundColor: theme.colorScheme.secondary,
      activeForegroundColor: Colors.white,
      spacing: 12,
      spaceBetweenChildren: 12,
      children: [
        SpeedDialChild(
          child: const Icon(Icons.add_circle, color: Colors.white),
          backgroundColor: Colors.green.shade600,
          label: 'Add Money',
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          onTap: onAddMoney,
        ),
        SpeedDialChild(
          child: const Icon(Icons.remove_circle, color: Colors.white),
          backgroundColor: Colors.red.shade600,
          label: 'Take Money',
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          onTap: onTakeMoney,
        ),
        SpeedDialChild(
          child: const Icon(Icons.swap_horiz, color: Colors.white),
          backgroundColor: Colors.blue.shade600,
          label: 'Move Money',
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          onTap: onMoveMoney,
        ),
        SpeedDialChild(
          child: const Icon(Icons.calculate, color: Colors.white),
          backgroundColor: Colors.orange.shade600,
          label: 'Calculator',
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          onTap: onCalculator,
        ),
      ],
    );
  }
}
