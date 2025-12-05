// lib/screens/add_to_pay_day_modal.dart
// FONT PROVIDER INTEGRATED: All GoogleFonts.caveat() replaced with FontProvider
// All button text wrapped in FittedBox to prevent wrapping
// REMOVED unused currency variable

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/envelope.dart';
import '../models/envelope_group.dart';
import '../providers/font_provider.dart';

class PayDayAddition {
  final String? envelopeId;
  final String? binderId;
  final double? customAmount;

  PayDayAddition({this.envelopeId, this.binderId, this.customAmount});
}

class AddToPayDayModal extends StatefulWidget {
  const AddToPayDayModal({
    super.key,
    required this.allEnvelopes,
    required this.allGroups,
    required this.alreadyDisplayedEnvelopes,
    required this.alreadyDisplayedBinders,
  });

  final List<Envelope> allEnvelopes;
  final List<EnvelopeGroup> allGroups;
  final Set<String> alreadyDisplayedEnvelopes;
  final Set<String> alreadyDisplayedBinders;

  @override
  State<AddToPayDayModal> createState() => _AddToPayDayModalState();
}

class _AddToPayDayModalState extends State<AddToPayDayModal> {
  final Map<String, TextEditingController> _controllers = {};
  String? _selectedType; // 'envelope' or 'binder'
  String? _selectedId;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addItem() {
    if (_selectedType == null || _selectedId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select an item')));
      return;
    }

    if (_selectedType == 'envelope') {
      final controller = _controllers[_selectedId];
      final customAmount = controller != null
          ? double.tryParse(controller.text)
          : null;

      if (customAmount == null || customAmount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid amount')),
        );
        return;
      }

      Navigator.pop(
        context,
        PayDayAddition(envelopeId: _selectedId, customAmount: customAmount),
      );
    } else {
      // Adding a binder
      Navigator.pop(context, PayDayAddition(binderId: _selectedId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    // Filter out already displayed items
    final availableEnvelopes = widget.allEnvelopes.where((env) {
      // Don't show if already displayed
      if (widget.alreadyDisplayedEnvelopes.contains(env.id)) return false;
      // Don't show if part of a displayed binder
      if (env.groupId != null &&
          widget.alreadyDisplayedBinders.contains(env.groupId)) {
        return false;
      }
      return true;
    }).toList()..sort((a, b) => a.name.compareTo(b.name));

    final availableBinders =
        widget.allGroups
            .where((g) => !widget.alreadyDisplayedBinders.contains(g.id))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 24,
        left: 24,
        right: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Text(
                'Add to Pay Day',
                style: fontProvider.getTextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Content
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // BINDERS SECTION
                  if (availableBinders.isNotEmpty) ...[
                    Text(
                      'Binders',
                      style: fontProvider.getTextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...availableBinders.map((group) {
                      final isSelected =
                          _selectedType == 'binder' && _selectedId == group.id;
                      final groupColor = GroupColors.getThemedColor(
                        group.colorName,
                        theme.colorScheme,
                      );

                      // Count envelopes with auto-pay in this binder
                      final envelopesWithAutoPay = widget.allEnvelopes
                          .where(
                            (e) =>
                                e.groupId == group.id &&
                                e.autoFillEnabled &&
                                e.autoFillAmount != null,
                          )
                          .length;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          // FIX: withOpacity -> withValues
                          color: isSelected
                              ? groupColor.withValues(alpha: 0.26)
                              : theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? groupColor
                                : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: RadioListTile<String>(
                          value: group.id,
                          groupValue: _selectedType == 'binder'
                              ? _selectedId
                              : null,
                          onChanged: (v) {
                            setState(() {
                              _selectedType = 'binder';
                              _selectedId = v;
                            });
                          },
                          activeColor: groupColor,
                          title: Row(
                            children: [
                              Text(
                                group.emoji ?? '📁',
                                style: const TextStyle(fontSize: 20),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      group.name,
                                      style: fontProvider.getTextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '$envelopesWithAutoPay envelopes with auto-pay',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                  ],

                  // ENVELOPES SECTION
                  if (availableEnvelopes.isNotEmpty) ...[
                    Text(
                      'Envelopes',
                      style: fontProvider.getTextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...availableEnvelopes.map((env) {
                      final isSelected =
                          _selectedType == 'envelope' && _selectedId == env.id;
                      final controller = _controllers.putIfAbsent(
                        env.id,
                        () => TextEditingController(
                          text: env.autoFillAmount?.toStringAsFixed(2) ?? '',
                        ),
                      );

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            RadioListTile<String>(
                              value: env.id,
                              groupValue: _selectedType == 'envelope'
                                  ? _selectedId
                                  : null,
                              onChanged: (v) {
                                setState(() {
                                  _selectedType = 'envelope';
                                  _selectedId = v;
                                });
                              },
                              activeColor: theme.colorScheme.primary,
                              title: Row(
                                children: [
                                  if (env.emoji != null) ...[
                                    Text(
                                      env.emoji!,
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Expanded(
                                    child: Text(
                                      env.name,
                                      style: fontProvider.getTextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  16,
                                ),
                                child: TextField(
                                  controller: controller,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Amount',
                                    prefixText: '£',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  autofocus: true,
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  ],

                  // Empty state
                  if (availableBinders.isEmpty &&
                      availableEnvelopes.isEmpty) ...[
                    const SizedBox(height: 32),
                    Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'All items already added!',
                            style: fontProvider.getTextStyle(
                              fontSize: 24,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Add button
          ElevatedButton(
            onPressed: (availableBinders.isEmpty && availableEnvelopes.isEmpty)
                ? null
                : _addItem,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Add to Pay Day',
                style: fontProvider.getTextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
