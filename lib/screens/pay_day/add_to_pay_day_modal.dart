// lib/screens/pay_day/add_to_pay_day_modal.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/envelope.dart';
import '../../../models/envelope_group.dart';
import '../../../providers/font_provider.dart';
import '../../../providers/time_machine_provider.dart';
import '../../../utils/responsive_helper.dart';

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
    // Check if time machine mode is active - block modifications
    final timeMachine = Provider.of<TimeMachineProvider>(context, listen: false);
    if (timeMachine.shouldBlockModifications()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(timeMachine.getBlockedActionMessage()),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_selectedId == null) return;

    if (_selectedType == 'binder') {
      Navigator.pop(
        context,
        PayDayAddition(binderId: _selectedId, customAmount: null),
      );
    } else {
      Navigator.pop(
        context,
        PayDayAddition(envelopeId: _selectedId, customAmount: null),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final responsive = context.responsive;
    final isLandscape = responsive.isLandscape;

    // Filter out items already in the list
    final availableBinders = widget.allGroups
        .where((g) => !widget.alreadyDisplayedBinders.contains(g.id))
        .toList();

    final availableEnvelopes = widget.allEnvelopes
        .where((e) => !widget.alreadyDisplayedEnvelopes.contains(e.id))
        .toList();

    // Use a fixed max height in landscape to avoid Expanded overflow
    final maxHeight = isLandscape
        ? MediaQuery.of(context).size.height * 0.65
        : MediaQuery.of(context).size.height * 0.75;

    return Container(
      padding: EdgeInsets.all(isLandscape ? 16 : 24),
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Add Item to Pay Day',
            style: fontProvider.getTextStyle(
              fontSize: isLandscape ? 20 : 24,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isLandscape ? 12 : 24),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // BINDERS SECTION
                  if (availableBinders.isNotEmpty) ...[
                    Text(
                      'Binders',
                      style: fontProvider.getTextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...availableBinders.map((binder) {
                      final isSelected = _selectedId == binder.id;
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedType = 'binder';
                            _selectedId = isSelected ? null : binder.id;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3) : null,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            leading: Text(
                              binder.emoji ?? '📁',
                              style: const TextStyle(fontSize: 24),
                            ),
                            title: Text(
                              binder.name,
                              style: fontProvider.getTextStyle(fontSize: 16),
                            ),
                            trailing: Icon(
                              isSelected ? Icons.check_circle : Icons.circle_outlined,
                              color: isSelected ? theme.colorScheme.primary : null,
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                  ],

                  // ENVELOPES SECTION
                  if (availableEnvelopes.isNotEmpty) ...[
                    Text(
                      'Envelopes',
                      style: fontProvider.getTextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...availableEnvelopes.map((env) {
                      final isSelected = _selectedId == env.id;
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedType = 'envelope';
                            _selectedId = isSelected ? null : env.id;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3) : null,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            leading: Text(
                              env.emoji ?? '✉️',
                              style: const TextStyle(fontSize: 24),
                            ),
                            title: Text(
                              env.name,
                              style: fontProvider.getTextStyle(fontSize: 16),
                            ),
                            trailing: Icon(
                              isSelected ? Icons.check_circle : Icons.circle_outlined,
                              color: isSelected ? theme.colorScheme.primary : null,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],

                  if (availableBinders.isEmpty && availableEnvelopes.isEmpty)
                    Center(
                      child: Column(
                        children: [
                          const SizedBox(height: 32),
                          Icon(
                            Icons.check_circle_outline,
                            size: 48,
                            color: Colors.green.withAlpha(128),
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