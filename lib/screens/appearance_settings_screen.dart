// lib/screens/settings/appearance_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/theme_provider.dart';
import '../../providers/font_provider.dart';
import '../../providers/app_preferences_provider.dart';
import '../../theme/app_themes.dart';
import 'theme_picker_screen.dart';
import '../../services/localization_service.dart';
import '../../widgets/envelope/omni_icon_picker_modal.dart';
import '../../services/icon_search_service_unlimited.dart';

class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final fontProvider = Provider.of<FontProvider>(context);
    final prefsProvider = Provider.of<AppPreferencesProvider>(context);

    // Common style for section headers
    final headerStyle = fontProvider.getTextStyle(
      fontSize: 14,
      fontWeight: FontWeight.bold,
      color: theme.colorScheme.primary,
    );

    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          child: Text(
            tr('settings_appearance'),
            style: fontProvider.getTextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          // --- THEME SECTION ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              tr('appearance_theme').toUpperCase(),
              style: headerStyle,
            ),
          ),
          _SettingsTile(
            title: AppThemes.getThemeName(themeProvider.currentThemeId),
            subtitle: tr('appearance_change_theme_hint'),
            leading: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ThemePickerScreen()),
              );
            },
          ),

          const SizedBox(height: 24),

          // --- FONT SECTION ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              tr('appearance_font').toUpperCase(),
              style: headerStyle,
            ),
          ),
          _SettingsTile(
            title: FontProvider.getFontName(fontProvider.currentFontId),
            subtitle: tr('appearance_change_font_hint'),
            leading: Icon(
              Icons.font_download_outlined,
              color: theme.colorScheme.onSurface,
            ),
            onTap: () => _showFontPicker(context),
          ),

          const SizedBox(height: 24),

          // --- CELEBRATION SECTION ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              tr('appearance_celebration').toUpperCase(),
              style: headerStyle,
            ),
          ),
          _SettingsTile(
            title: tr('appearance_target_emoji'),
            subtitle: tr('appearance_target_emoji_hint'),
            leading: Text(
              prefsProvider.celebrationEmoji,
              style: const TextStyle(fontSize: 24),
            ),
            onTap: () => _showSmartEmojiPicker(context, prefsProvider),
          ),
        ],
      ),
    );
  }

  // --- NEW EMOJI PICKER LOGIC ---
  Future<void> _showSmartEmojiPicker(
    BuildContext context,
    AppPreferencesProvider provider,
  ) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OmniIconPickerModal(
        initialValue: provider.celebrationEmoji,
        initialType: IconType.emoji,
        initialQuery: '',
      ),
    );

    if (result != null && result['type'] == IconType.emoji) {
      // Only accept emoji type for celebration emoji
      final emoji = result['value'] as String;
      provider.setCelebrationEmoji(emoji);
    }
  }

  // --- REUSED FONT PICKER (Cleaned up) ---
  Future<void> _showFontPicker(BuildContext context) async {
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final fonts = FontProvider.getAllFonts();
    final theme = Theme.of(context);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                tr('appearance_choose_font'),
                style: fontProvider.getTextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                itemCount: fonts.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 1, indent: 20, endIndent: 20),
                itemBuilder: (context, index) {
                  final font = fonts[index];
                  final isSelected = fontProvider.currentFontId == font.id;

                  // Get sample style
                  TextStyle sampleStyle;
                  switch (font.id) {
                    case FontProvider.caveatId:
                      sampleStyle = GoogleFonts.caveat(fontSize: 22);
                      break;
                    case FontProvider.indieFlowerId:
                      sampleStyle = GoogleFonts.indieFlower(fontSize: 20);
                      break;
                    case FontProvider.robotoId:
                      sampleStyle = GoogleFonts.roboto(fontSize: 18);
                      break;
                    case FontProvider.openSansId:
                      sampleStyle = GoogleFonts.openSans(fontSize: 18);
                      break;
                    default:
                      sampleStyle = const TextStyle(fontSize: 18);
                  }

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    leading: isSelected
                        ? Icon(
                            Icons.check_circle,
                            color: theme.colorScheme.primary,
                          )
                        : const Icon(Icons.circle_outlined, color: Colors.grey),
                    title: Text(font.name, style: sampleStyle),
                    onTap: () async {
                      await fontProvider.setFont(font.id);
                      if (context.mounted) Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- HELPER WIDGET FOR SETTINGS TILES ---
class _SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget leading;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: leading,
        title: Text(
          title,
          style: fontProvider.getTextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
        ),
        onTap: onTap,
      ),
    );
  }
}
