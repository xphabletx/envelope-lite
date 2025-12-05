// lib/screens/appearance_settings_screen.dart
// FONT PROVIDER INTEGRATED: All GoogleFonts.caveat() replaced with FontProvider
// All button text wrapped in FittedBox to prevent wrapping

import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // NEW IMPORT
import 'package:google_fonts/google_fonts.dart'; // Kept as requested

import '../providers/theme_provider.dart';
import '../providers/font_provider.dart';
import '../providers/app_preferences_provider.dart';
import '../theme/app_themes.dart';
import 'theme_picker_screen.dart';
import '../services/localization_service.dart';

class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final fontProvider = Provider.of<FontProvider>(context);
    final prefsProvider = Provider.of<AppPreferencesProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text(tr('settings_appearance'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Theme Section
          Text(
            tr('appearance_theme'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              title: Text(AppThemes.getThemeName(themeProvider.currentThemeId)),
              subtitle: Text(tr('appearance_change_theme_hint')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ThemePickerScreen()),
                );
              },
            ),
          ),

          const SizedBox(height: 32),

          // Font Section
          Text(
            tr('appearance_font'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.font_download_outlined, size: 28),
              title: Text(FontProvider.getFontName(fontProvider.currentFontId)),
              subtitle: Text(tr('appearance_change_font_hint')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showFontPicker(context),
            ),
          ),

          const SizedBox(height: 32),

          // Celebration Emoji Section
          Text(
            tr('appearance_celebration'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Text(
                prefsProvider.celebrationEmoji,
                style: const TextStyle(fontSize: 32),
              ),
              title: Text(tr('appearance_target_emoji')),
              subtitle: Text(tr('appearance_target_emoji_hint')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showEmojiPicker(context, prefsProvider),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showFontPicker(BuildContext context) async {
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final fonts = FontProvider.getAllFonts();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            tr('appearance_choose_font'),
            // UPDATED: FontProvider
            style: fontProvider.getTextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: fonts.length,
              itemBuilder: (context, index) {
                final font = fonts[index];
                final isSelected = fontProvider.currentFontId == font.id;

                // Get sample text style for this font
                TextStyle sampleStyle;
                switch (font.id) {
                  case FontProvider.caveatId:
                    sampleStyle = GoogleFonts.caveat(fontSize: 20);
                    break;
                  case FontProvider.indieFlowerId:
                    sampleStyle = GoogleFonts.indieFlower(fontSize: 20);
                    break;
                  case FontProvider.robotoId:
                    sampleStyle = GoogleFonts.roboto(fontSize: 20);
                    break;
                  case FontProvider.openSansId:
                    sampleStyle = GoogleFonts.openSans(fontSize: 20);
                    break;
                  case FontProvider.systemDefaultId:
                  default:
                    sampleStyle = const TextStyle(fontSize: 20);
                }

                return ListTile(
                  leading: isSelected
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : const Icon(Icons.radio_button_unchecked),
                  title: Text(font.name, style: sampleStyle),
                  subtitle: Text(font.description),
                  onTap: () async {
                    await fontProvider.setFont(font.id);
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: FittedBox(
                // UPDATED: FittedBox
                fit: BoxFit.scaleDown,
                child: Text(
                  tr('close'),
                  // UPDATED: FontProvider
                  style: fontProvider.getTextStyle(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEmojiPicker(
    BuildContext context,
    AppPreferencesProvider provider,
  ) async {
    final controller = TextEditingController(text: provider.celebrationEmoji);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          tr('appearance_choose_emoji'),
          // UPDATED: FontProvider
          style: fontProvider.getTextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr('appearance_emoji_instructions'),
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 2, // Allow compound emojis
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 60),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  counterText: '',
                  hintText: '🥰',
                ),
                onChanged: (value) {
                  if (value.characters.length > 2) {
                    controller.text = value.characters.take(2).join();
                    controller.selection = TextSelection.fromPosition(
                      TextPosition(offset: controller.text.length),
                    );
                  }
                },
              ),
              const SizedBox(height: 16),
              Text(
                tr('appearance_emoji_explanation'),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: FittedBox(
              // UPDATED: FittedBox
              fit: BoxFit.scaleDown,
              child: Text(
                tr('cancel'),
                // UPDATED: FontProvider
                style: fontProvider.getTextStyle(),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final emoji = controller.text.trim();
              if (emoji.isNotEmpty) {
                provider.setCelebrationEmoji(emoji);
              }
              Navigator.pop(dialogContext);
            },
            child: FittedBox(
              // UPDATED: FittedBox
              fit: BoxFit.scaleDown,
              child: Text(
                tr('save'),
                // UPDATED: FontProvider
                style: fontProvider.getTextStyle(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
