// lib/screens/settings/faq_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/faq_data.dart';
import '../../utils/responsive_helper.dart';
import '../../providers/font_provider.dart';

class FAQScreen extends StatefulWidget {
  const FAQScreen({super.key});

  @override
  State<FAQScreen> createState() => _FAQScreenState();
}

class _FAQScreenState extends State<FAQScreen> {
  String _searchQuery = '';

  List<FAQItem> get _filteredFAQs {
    if (_searchQuery.isEmpty) return faqItems;

    final query = _searchQuery.toLowerCase();
    return faqItems.where((faq) {
      return faq.question.toLowerCase().contains(query) ||
          faq.answer.toLowerCase().contains(query) ||
          faq.tags.any((tag) => tag.toLowerCase().contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final responsive = context.responsive;
    final isLandscape = responsive.isLandscape;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Help & FAQ',
          style: fontProvider.getTextStyle(
            fontSize: isLandscape ? 20 : 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: EdgeInsets.all(isLandscape ? 12 : 16),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              textCapitalization: TextCapitalization.words,
              style: TextStyle(fontSize: isLandscape ? 14 : 16),
              decoration: InputDecoration(
                hintText: 'Search for help...',
                hintStyle: TextStyle(fontSize: isLandscape ? 14 : 16),
                prefixIcon: Icon(Icons.search, size: isLandscape ? 20 : 24),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, size: isLandscape ? 20 : 24),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isLandscape ? 12 : 16,
                  vertical: isLandscape ? 10 : 16,
                ),
              ),
            ),
          ),

          // Results count
          if (_searchQuery.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isLandscape ? 12 : 16),
              child: Text(
                '${_filteredFAQs.length} result${_filteredFAQs.length == 1 ? '' : 's'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: isLandscape ? 11 : null,
                ),
              ),
            ),

          // FAQ list
          Expanded(
            child: _filteredFAQs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: isLandscape ? 48 : 64,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        SizedBox(height: isLandscape ? 12 : 16),
                        Text(
                          'No results found',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: isLandscape ? 14 : null,
                          ),
                        ),
                        SizedBox(height: isLandscape ? 6 : 8),
                        Text(
                          'Try different keywords',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                            fontSize: isLandscape ? 11 : null,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(isLandscape ? 12 : 16),
                    itemCount: _filteredFAQs.length,
                    itemBuilder: (context, index) {
                      final faq = _filteredFAQs[index];

                      return Card(
                        margin: EdgeInsets.only(bottom: isLandscape ? 8 : 12),
                        child: ExpansionTile(
                          leading: Text(
                            faq.emoji,
                            style: TextStyle(fontSize: isLandscape ? 22 : 28),
                          ),
                          title: Text(
                            faq.question,
                            style: TextStyle(fontSize: isLandscape ? 14 : 16),
                          ),
                          children: [
                            Padding(
                              padding: EdgeInsets.all(isLandscape ? 12 : 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    faq.answer,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontSize: isLandscape ? 14 : null,
                                    ),
                                  ),

                                  // Screenshot placeholder
                                  if (faq.screenshotPath != null) ...[
                                    SizedBox(height: isLandscape ? 12 : 16),
                                    Container(
                                      height: isLandscape ? 150 : 200,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.image_outlined,
                                              size: isLandscape ? 36 : 48,
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.3),
                                            ),
                                            SizedBox(height: isLandscape ? 6 : 8),
                                            Text(
                                              'Screenshot: ${faq.screenshotPath}',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                color: theme
                                                    .colorScheme.onSurface
                                                    .withValues(alpha: 0.5),
                                                fontSize: isLandscape ? 11 : null,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
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
}
