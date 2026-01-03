// lib/screens/theme_picker_screen.dart
// FONT PROVIDER INTEGRATED: NO GoogleFonts.caveat() calls found, skipped changes.
// No imports added as file doesn't use custom fonts.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_themes.dart';
import '../utils/responsive_helper.dart';
import '../providers/font_provider.dart';

class ThemePickerScreen extends StatelessWidget {
  const ThemePickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final themes = AppThemes.getAllThemes();
    final responsive = context.responsive;
    final isLandscape = responsive.isLandscape;

    // Responsive sizing
    final gridPadding = isLandscape ? 12.0 : 16.0;
    final crossAxisCount = isLandscape ? 3 : 2;
    final crossAxisSpacing = isLandscape ? 12.0 : 16.0;
    final mainAxisSpacing = isLandscape ? 12.0 : 16.0;
    final childAspectRatio = isLandscape ? 1.0 : 0.85;
    final cardPadding = isLandscape ? 12.0 : 16.0;
    final circleSize = isLandscape ? 48.0 : 60.0;
    final checkIconSize = isLandscape ? 24.0 : 32.0;
    final titleFontSize = isLandscape ? 14.0 : 16.0;
    final descriptionFontSize = isLandscape ? 10.0 : 12.0;
    final spacing = isLandscape ? 12.0 : 16.0;
    final descSpacing = isLandscape ? 6.0 : 8.0;

    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          child: Text(
            'Choose Theme',
            style: fontProvider.getTextStyle(
              fontSize: isLandscape ? 20 : 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      body: GridView.builder(
        padding: EdgeInsets.all(gridPadding),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: crossAxisSpacing,
          mainAxisSpacing: mainAxisSpacing,
          childAspectRatio: childAspectRatio,
        ),
        itemCount: themes.length,
        itemBuilder: (context, index) {
          final theme = themes[index];
          final isSelected = themeProvider.currentThemeId == theme.id;

          return GestureDetector(
            onTap: () async {
              await themeProvider.setTheme(theme.id);
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: theme.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? theme.primaryColor : Colors.transparent,
                  width: 3,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(cardPadding),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: circleSize,
                      height: circleSize,
                      decoration: BoxDecoration(
                        color: theme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: isSelected
                          ? Icon(
                              Icons.check,
                              color: Colors.white,
                              size: checkIconSize,
                            )
                          : null,
                    ),
                    SizedBox(height: spacing),
                    Text(
                      theme.name,
                      style: fontProvider.getTextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: descSpacing),
                    Text(
                      theme.description,
                      style: TextStyle(
                        fontSize: descriptionFontSize,
                        color: theme.primaryColor.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
