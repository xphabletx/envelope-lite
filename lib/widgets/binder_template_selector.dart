// lib/widgets/binder_template_selector.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/binder_templates.dart';
import '../providers/font_provider.dart';
import '../models/envelope.dart';

class BinderTemplateSelector extends StatefulWidget {
  const BinderTemplateSelector({
    super.key,
    required this.existingEnvelopes,
  });

  final List<Envelope> existingEnvelopes;

  @override
  State<BinderTemplateSelector> createState() => _BinderTemplateSelectorState();
}

class _BinderTemplateSelectorState extends State<BinderTemplateSelector> {
  String? selectedTemplateId;

  /// Check if a template has already been used by seeing if all its envelope names exist
  bool _isTemplateAlreadyUsed(BinderTemplate template) {
    final existingNames = widget.existingEnvelopes.map((e) => e.name.toLowerCase()).toSet();

    // Check if all template envelope names already exist
    final matchCount = template.envelopes
        .where((env) => existingNames.contains(env.name.toLowerCase()))
        .length;

    // Consider template "used" if 80% or more of its envelopes exist
    return matchCount >= (template.envelopes.length * 0.8);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: theme.colorScheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Choose Binder Template',
          style: fontProvider.getTextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // From Scratch option
          _TemplateCard(
            title: 'From Scratch',
            emoji: '✏️',
            description: 'Create an empty binder and add envelopes manually',
            envelopeCount: null,
            isSelected: selectedTemplateId == null,
            onTap: () {
              setState(() => selectedTemplateId = null);
            },
            theme: theme,
            fontProvider: fontProvider,
          ),
          const SizedBox(height: 12),

          Text(
            'OR START WITH A TEMPLATE',
            style: fontProvider.getTextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withAlpha(128),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // Template options
          ...binderTemplates.map((template) {
            final isAlreadyUsed = _isTemplateAlreadyUsed(template);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TemplateCard(
                title: template.name,
                emoji: template.emoji,
                description: template.description,
                envelopeCount: template.envelopes.length,
                isSelected: selectedTemplateId == template.id,
                isDisabled: isAlreadyUsed,
                onTap: () {
                  if (!isAlreadyUsed) {
                    setState(() => selectedTemplateId = template.id);
                  }
                },
                theme: theme,
                fontProvider: fontProvider,
              ),
            );
          }),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Return the selected template ID (or null for "from scratch")
          final template = selectedTemplateId != null
              ? binderTemplates.firstWhere((t) => t.id == selectedTemplateId)
              : null;
          Navigator.pop(context, template);
        },
        backgroundColor: theme.colorScheme.secondary,
        icon: const Icon(Icons.check, color: Colors.white),
        label: Text(
          'Continue',
          style: fontProvider.getTextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.title,
    required this.emoji,
    required this.description,
    required this.envelopeCount,
    required this.isSelected,
    required this.onTap,
    required this.theme,
    required this.fontProvider,
    this.isDisabled = false,
  });

  final String title;
  final String emoji;
  final String description;
  final int? envelopeCount;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback onTap;
  final ThemeData theme;
  final FontProvider fontProvider;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isDisabled ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDisabled
                ? theme.colorScheme.surfaceContainerHighest
                : (isSelected
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surface),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDisabled
                  ? theme.colorScheme.outline.withAlpha(128)
                  : (isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline),
              width: isSelected ? 3 : 1,
            ),
            boxShadow: isSelected && !isDisabled
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withAlpha(51),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
        child: Row(
          children: [
            // Emoji
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary.withAlpha(51)
                    : theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 32),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: fontProvider.getTextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected
                          ? theme.colorScheme.onPrimaryContainer.withAlpha(179)
                          : theme.colorScheme.onSurface.withAlpha(179),
                    ),
                  ),
                  if (envelopeCount != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$envelopeCount envelopes',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                        if (isDisabled) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 14,
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Already Created',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onErrorContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Selection indicator
            if (!isDisabled)
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: theme.colorScheme.primary,
                  size: 32,
                )
              else
                Icon(
                  Icons.circle_outlined,
                  color: theme.colorScheme.outline,
                  size: 32,
                )
            else
              Icon(
                Icons.lock_outline,
                color: theme.colorScheme.outline,
                size: 32,
              ),
          ],
        ), // End Row
        ), // End Container
      ), // End Opacity
    ); // End InkWell
  }
}
