// lib/screens/settings/appearance_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/theme_provider.dart';
import '../../providers/font_provider.dart';
import '../../providers/locale_provider.dart';
import '../../theme/app_themes.dart';
import 'theme_picker_screen.dart';
import '../../services/localization_service.dart';
import '../../widgets/envelope/omni_icon_picker_modal.dart';
import '../../services/icon_search_service_unlimited.dart';
import '../../utils/responsive_helper.dart';

class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final fontProvider = Provider.of<FontProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final responsive = context.responsive;
    final isLandscape = responsive.isLandscape;

    // Common style for section headers
    final headerStyle = fontProvider.getTextStyle(
      fontSize: isLandscape ? 12 : 14,
      fontWeight: FontWeight.bold,
      color: theme.colorScheme.primary,
    );

    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          child: Text(
            tr('settings_appearance'),
            style: fontProvider.getTextStyle(
              fontSize: isLandscape ? 20 : 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(
          vertical: isLandscape ? 12 : 20,
          horizontal: isLandscape ? 12 : 0,
        ),
        children: [
          // --- THEME SECTION ---
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isLandscape ? 16 : 20,
              vertical: isLandscape ? 6 : 8,
            ),
            child: Text(
              tr('appearance_theme').toUpperCase(),
              style: headerStyle,
            ),
          ),
          _SettingsTile(
            title: AppThemes.getThemeName(themeProvider.currentThemeId),
            subtitle: tr('appearance_change_theme_hint'),
            leading: Container(
              width: isLandscape ? 28 : 32,
              height: isLandscape ? 28 : 32,
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
            isLandscape: isLandscape,
          ),

          SizedBox(height: isLandscape ? 16 : 24),

          // --- FONT SECTION ---
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isLandscape ? 16 : 20,
              vertical: isLandscape ? 6 : 8,
            ),
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
              size: isLandscape ? 20 : 24,
            ),
            onTap: () => _showFontPicker(context, isLandscape),
            isLandscape: isLandscape,
          ),

          SizedBox(height: isLandscape ? 16 : 24),

          // --- CELEBRATION SECTION ---
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isLandscape ? 16 : 20,
              vertical: isLandscape ? 6 : 8,
            ),
            child: Text(
              tr('appearance_celebration').toUpperCase(),
              style: headerStyle,
            ),
          ),
          _SettingsTile(
            title: tr('appearance_target_emoji'),
            subtitle: tr('appearance_target_emoji_hint'),
            leading: Text(
              localeProvider.celebrationEmoji,
              style: TextStyle(fontSize: isLandscape ? 20 : 24),
            ),
            onTap: () => _showSmartEmojiPicker(context, localeProvider),
            isLandscape: isLandscape,
          ),
        ],
      ),
    );
  }

  // --- NEW EMOJI PICKER LOGIC ---
  Future<void> _showSmartEmojiPicker(
    BuildContext context,
    LocaleProvider provider,
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

    if (result != null && result['type'] == 'emoji') {
      // Only accept emoji type for celebration emoji
      final emoji = result['value'] as String;
      provider.setCelebrationEmoji(emoji);
    }
  }

  // --- REUSED FONT PICKER (Cleaned up) ---
  Future<void> _showFontPicker(BuildContext context, bool isLandscape) async {
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final fonts = FontProvider.getAllFonts();
    final theme = Theme.of(context);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * (isLandscape ? 0.8 : 0.6),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(isLandscape ? 16 : 20),
              child: Text(
                tr('appearance_choose_font'),
                style: fontProvider.getTextStyle(
                  fontSize: isLandscape ? 18 : 22,
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
                  final baseFontSize = isLandscape ? 16.0 : 18.0;
                  switch (font.id) {
                    case FontProvider.caveatId:
                      sampleStyle = GoogleFonts.caveat(fontSize: baseFontSize + 4);
                      break;
                    case FontProvider.indieFlowerId:
                      sampleStyle = GoogleFonts.indieFlower(fontSize: baseFontSize + 2);
                      break;
                    case FontProvider.robotoId:
                      sampleStyle = GoogleFonts.roboto(fontSize: baseFontSize);
                      break;
                    case FontProvider.openSansId:
                      sampleStyle = GoogleFonts.openSans(fontSize: baseFontSize);
                      break;
                    default:
                      sampleStyle = TextStyle(fontSize: baseFontSize);
                  }

                  return ListTile(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: isLandscape ? 20 : 24,
                      vertical: isLandscape ? 4 : 8,
                    ),
                    leading: isSelected
                        ? Icon(
                            Icons.check_circle,
                            color: theme.colorScheme.primary,
                            size: isLandscape ? 20 : 24,
                          )
                        : Icon(
                            Icons.circle_outlined,
                            color: Colors.grey,
                            size: isLandscape ? 20 : 24,
                          ),
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
  final bool isLandscape;

  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.onTap,
    this.isLandscape = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isLandscape ? 12 : 16,
        vertical: isLandscape ? 3 : 4,
      ),
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
        contentPadding: EdgeInsets.symmetric(
          horizontal: isLandscape ? 16 : 20,
          vertical: isLandscape ? 6 : 8,
        ),
        leading: leading,
        title: Text(
          title,
          style: fontProvider.getTextStyle(
            fontSize: isLandscape ? 16 : 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: isLandscape ? 11 : 13,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          size: isLandscape ? 20 : 24,
        ),
        onTap: onTap,
      ),
    );
  }
}
