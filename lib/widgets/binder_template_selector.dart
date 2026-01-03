// lib/widgets/binder_template_selector.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/binder_templates.dart';
import '../providers/font_provider.dart';
import '../models/envelope.dart';
import '../utils/responsive_helper.dart';

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
    final responsive = context.responsive;
    final isLandscape = responsive.isLandscape;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: theme.colorScheme.primary, size: isLandscape ? 20 : 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Choose Binder Template',
          style: fontProvider.getTextStyle(
            fontSize: isLandscape ? 20 : 28,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(isLandscape ? 12 : 16),
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
            isLandscape: isLandscape,
          ),
          SizedBox(height: isLandscape ? 8 : 12),

          Text(
            'OR START WITH A TEMPLATE',
            style: fontProvider.getTextStyle(
              fontSize: isLandscape ? 12 : 14,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withAlpha(128),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isLandscape ? 8 : 12),

          // Template options
          ...binderTemplates.map((template) {
            final isAlreadyUsed = _isTemplateAlreadyUsed(template);
            return Padding(
              padding: EdgeInsets.only(bottom: isLandscape ? 8 : 12),
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
                isLandscape: isLandscape,
              ),
            );
          }),

          // INLINE BUTTON FOR LANDSCAPE
          if (isLandscape) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                final template = selectedTemplateId != null
                    ? binderTemplates.firstWhere((t) => t.id == selectedTemplateId)
                    : fromScratchTemplate;
                Navigator.pop(context, template);
              },
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.secondary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: const Size(double.infinity, 0),
              ),
              icon: const Icon(Icons.check, color: Colors.white, size: 20),
              label: Text(
                'Continue',
                style: fontProvider.getTextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
          ),
        ],
      ),
      floatingActionButton: isLandscape ? null : FloatingActionButton.extended(
        onPressed: () {
          // Return the selected template (or fromScratchTemplate for "from scratch")
          final template = selectedTemplateId != null
              ? binderTemplates.firstWhere((t) => t.id == selectedTemplateId)
              : fromScratchTemplate;
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
    this.isLandscape = false,
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
  final bool isLandscape;

  @override
  Widget build(BuildContext context) {
    final cardPadding = isLandscape ? 12.0 : 20.0;
    final emojiSize = isLandscape ? 44.0 : 60.0;
    final emojiFontSize = isLandscape ? 24.0 : 32.0;
    final titleFontSize = isLandscape ? 16.0 : 22.0;
    final descriptionFontSize = isLandscape ? 12.0 : 14.0;
    final spacing = isLandscape ? 12.0 : 16.0;
    final iconSize = isLandscape ? 24.0 : 32.0;

    return InkWell(
      onTap: isDisabled ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
        child: Container(
          padding: EdgeInsets.all(cardPadding),
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
              width: emojiSize,
              height: emojiSize,
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary.withAlpha(51)
                    : theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  emoji,
                  style: TextStyle(fontSize: emojiFontSize),
                ),
              ),
            ),
            SizedBox(width: spacing),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: fontProvider.getTextStyle(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: isLandscape ? 2 : 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: descriptionFontSize,
                      color: isSelected
                          ? theme.colorScheme.onPrimaryContainer.withAlpha(179)
                          : theme.colorScheme.onSurface.withAlpha(179),
                    ),
                  ),
                  if (envelopeCount != null) ...[
                    SizedBox(height: isLandscape ? 4 : 8),
                    Wrap(
                      spacing: isLandscape ? 6 : 8,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isLandscape ? 8 : 12,
                            vertical: isLandscape ? 3 : 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$envelopeCount envelopes',
                            style: TextStyle(
                              fontSize: isLandscape ? 10 : 12,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                        if (isDisabled)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isLandscape ? 8 : 12,
                              vertical: isLandscape ? 3 : 4,
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
                                  size: isLandscape ? 12 : 14,
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                                SizedBox(width: isLandscape ? 3 : 4),
                                Text(
                                  'Already Created',
                                  style: TextStyle(
                                    fontSize: isLandscape ? 10 : 12,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onErrorContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
                  size: iconSize,
                )
              else
                Icon(
                  Icons.circle_outlined,
                  color: theme.colorScheme.outline,
                  size: iconSize,
                )
            else
              Icon(
                Icons.lock_outline,
                color: theme.colorScheme.outline,
                size: iconSize,
              ),
          ],
        ), // End Row
        ), // End Container
      ), // End Opacity
    ); // End InkWell
  }
}
