import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/binder_templates.dart';
import '../../providers/font_provider.dart';

/// A widget that allows users to select envelopes from ANY template
/// Not restricted to a single template - users can pick and choose from all available templates
class TemplateEnvelopeSelector extends StatefulWidget {
  final String userId;
  final String? existingBinderId; // If adding to an existing binder

  const TemplateEnvelopeSelector({
    super.key,
    required this.userId,
    this.existingBinderId,
  });

  @override
  State<TemplateEnvelopeSelector> createState() => _TemplateEnvelopeSelectorState();
}

class _TemplateEnvelopeSelectorState extends State<TemplateEnvelopeSelector> {
  final Map<String, Set<String>> _selectedEnvelopesByTemplate = {};
  BinderTemplate? _expandedTemplate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Select Template Envelopes',
          style: fontProvider.getTextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _selectedEnvelopesByTemplate.isEmpty
                ? null
                : () => _proceedToQuickSetup(),
            child: Text(
              'Next',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _selectedEnvelopesByTemplate.isEmpty
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
                    : theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header with selection count
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              border: Border(
                bottom: BorderSide(color: theme.dividerColor),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose envelopes from any template',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getTotalSelectedCount() == 0
                      ? 'No envelopes selected'
                      : '${_getTotalSelectedCount()} envelope(s) selected',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),

          // Template list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: binderTemplates.length,
              itemBuilder: (context, index) {
                final template = binderTemplates[index];

                // Skip "from scratch" template
                if (template.id == 'from_scratch') return const SizedBox.shrink();

                final isExpanded = _expandedTemplate?.id == template.id;
                final selectedCount = _selectedEnvelopesByTemplate[template.id]?.length ?? 0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Text(template.emoji, style: const TextStyle(fontSize: 32)),
                        title: Text(
                          template.name,
                          style: fontProvider.getTextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          selectedCount == 0
                              ? '${template.envelopes.length} envelopes'
                              : '$selectedCount of ${template.envelopes.length} selected',
                          style: TextStyle(
                            color: selectedCount > 0
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        trailing: Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                        ),
                        onTap: () {
                          setState(() {
                            _expandedTemplate = isExpanded ? null : template;
                          });
                        },
                      ),

                      if (isExpanded) ...[
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              TextButton(
                                onPressed: () => _selectAllFromTemplate(template),
                                child: const Text('Select All'),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () => _deselectAllFromTemplate(template),
                                child: const Text('Deselect All'),
                              ),
                            ],
                          ),
                        ),
                        ...template.envelopes.map((envelope) {
                          final isSelected = _selectedEnvelopesByTemplate[template.id]
                                  ?.contains(envelope.id) ??
                              false;

                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (checked) {
                              setState(() {
                                _selectedEnvelopesByTemplate.putIfAbsent(
                                  template.id,
                                  () => {},
                                );
                                if (checked == true) {
                                  _selectedEnvelopesByTemplate[template.id]!.add(envelope.id);
                                } else {
                                  _selectedEnvelopesByTemplate[template.id]!.remove(envelope.id);
                                  // Clean up empty sets
                                  if (_selectedEnvelopesByTemplate[template.id]!.isEmpty) {
                                    _selectedEnvelopesByTemplate.remove(template.id);
                                  }
                                }
                              });
                            },
                            secondary: Text(envelope.emoji, style: const TextStyle(fontSize: 24)),
                            title: Text(
                              envelope.name,
                              style: fontProvider.getTextStyle(fontSize: 16),
                            ),
                            subtitle: envelope.defaultAmount != null
                                ? Text('Suggested: £${envelope.defaultAmount!.toStringAsFixed(2)}')
                                : null,
                          );
                        }),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  int _getTotalSelectedCount() {
    return _selectedEnvelopesByTemplate.values.fold(
      0,
      (sum, set) => sum + set.length,
    );
  }

  void _selectAllFromTemplate(BinderTemplate template) {
    setState(() {
      _selectedEnvelopesByTemplate[template.id] =
          template.envelopes.map((e) => e.id).toSet();
    });
  }

  void _deselectAllFromTemplate(BinderTemplate template) {
    setState(() {
      _selectedEnvelopesByTemplate.remove(template.id);
    });
  }

  void _proceedToQuickSetup() {
    // For now, just pop with the selected data
    // We'll implement the quick setup flow next
    Navigator.of(context).pop(_selectedEnvelopesByTemplate);
  }
}
