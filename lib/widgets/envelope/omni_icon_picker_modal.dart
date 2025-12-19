// lib/widgets/envelope/omni_icon_picker_modal.dart
// Beautiful modal for searching and selecting icons

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/icon_search_service_unlimited.dart';
import '../../providers/font_provider.dart';

class OmniIconPickerModal extends StatefulWidget {
  const OmniIconPickerModal({super.key, this.initialValue, this.initialType});

  final String? initialValue;
  final IconType? initialType;

  @override
  State<OmniIconPickerModal> createState() => _OmniIconPickerModalState();
}

class _OmniIconPickerModalState extends State<OmniIconPickerModal> {
  final _searchController = TextEditingController();
  OmniIconSearchResults? _results;
  IconSearchResult? _selectedIcon;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _onSearchChanged('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) async {
    setState(() {
      _isLoading = true;
    });
    final results = await IconSearchService.search(query);
    if (mounted) {
      setState(() {
        _results = results;
        _isLoading = false;
      });
    }
  }

  void _selectIcon(IconSearchResult icon) {
    setState(() {
      _selectedIcon = icon;
    });
  }

  void _confirm() {
    if (_selectedIcon != null) {
      Navigator.pop(context, {
        'type': _selectedIcon!.type,
        'value': _selectedIcon!.value,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  color: theme.colorScheme.secondary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Choose Icon',
                    style: fontProvider.getTextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                if (_selectedIcon != null)
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: _confirm,
                  ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search icons, logos, emojis...',
                hintStyle: fontProvider.getTextStyle(
                  fontSize: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.colorScheme.surface,
              ),
            ),
          ),

          // Results
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _results!.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.3,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No results found',
                              style: fontProvider.getTextStyle(
                                fontSize: 18,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Material Icons section
                            if (_results!.materialIcons.isNotEmpty) ...[
                              _SectionHeader(
                                icon: Icons.apps,
                                title: 'Flutter Icons',
                                count: _results!.materialIcons.length,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _results!.materialIcons.map((icon) {
                                  final isSelected =
                                      _selectedIcon?.value == icon.value;
                                  return _IconTile(
                                    icon: icon,
                                    isSelected: isSelected,
                                    onTap: () => _selectIcon(icon),
                                    color: theme.colorScheme.primary,
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 24),
                            ],

                            // Company Logos section (suggested)
                            if (_results!.companyLogos.isNotEmpty) ...[
                              _SectionHeader(
                                icon: Icons.business,
                                title: 'Company Logos',
                                count: _results!.companyLogos.length,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _results!.companyLogos.map((icon) {
                                  final isSelected =
                                      _selectedIcon?.value == icon.value;
                                  return _LogoTile(
                                    icon: icon,
                                    isSelected: isSelected,
                                    onTap: () => _selectIcon(icon),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 24),
                            ],

                            // Custom Domains section (NEW!)
                            if (_results!.customDomains.isNotEmpty) ...[
                              Row(
                                children: [
                                  Icon(
                                    Icons.public,
                                    color: theme.colorScheme.secondary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Found Online (${_results!.customDomains.length})',
                                    style: fontProvider.getTextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.secondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _results!.customDomains.map((icon) {
                                  final isSelected =
                                      _selectedIcon?.value == icon.value;
                                  return _LogoTile(
                                    icon: icon,
                                    isSelected: isSelected,
                                    onTap: () => _selectIcon(icon),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 24),
                            ],

                            // Emojis section
                            if (_results!.emojis.isNotEmpty) ...[
                              _SectionHeader(
                                icon: Icons.emoji_emotions,
                                title: _results!.emojis.first.source ==
                                        'keyboard'
                                    ? 'Your Emoji'
                                    : 'Emojis',
                                count: _results!.emojis.length,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _results!.emojis.map((icon) {
                                  final isSelected =
                                      _selectedIcon?.value == icon.value;
                                  return _EmojiTile(
                                    icon: icon,
                                    isSelected: isSelected,
                                    onTap: () => _selectIcon(icon),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ],
                        ),
                      ),
          ),

          // Bottom bar with selected icon
          if (_selectedIcon != null)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(child: _selectedIcon!.preview),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _selectedIcon!.displayName,
                          style: fontProvider.getTextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _getTypeLabel(_selectedIcon!.type),
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: _confirm,
                    child: const Text('Select'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _getTypeLabel(IconType type) {
    switch (type) {
      case IconType.materialIcon:
        return 'Flutter Icon';
      case IconType.companyLogo:
        return 'Company Logo';
      case IconType.emoji:
        return 'Emoji';
    }
  }
}

// Section header widget
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
  });

  final IconData icon;
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.secondary, size: 20),
        const SizedBox(width: 8),
        Text(
          '$title ($count)',
          style: fontProvider.getTextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.secondary,
          ),
        ),
      ],
    );
  }
}

// Icon tile widget
class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.color,
  });

  final IconSearchResult icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Icon(
            (icon.preview as Icon).icon,
            color: isSelected ? theme.colorScheme.primary : color,
            size: 32,
          ),
        ),
      ),
    );
  }
}

// Logo tile widget
class _LogoTile extends StatelessWidget {
  const _LogoTile({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final IconSearchResult icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 40, height: 40, child: icon.preview),
            const SizedBox(height: 4),
            Text(
              icon.displayName,
              style: fontProvider.getTextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// Emoji tile widget
class _EmojiTile extends StatelessWidget {
  const _EmojiTile({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final IconSearchResult icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(child: icon.preview),
      ),
    );
  }
}
