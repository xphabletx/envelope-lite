// lib/services/tutorial_controller.dart

import 'package:shared_preferences/shared_preferences.dart';
import '../data/tutorial_sequences.dart';

class TutorialController {
  static const String _completedScreensKey = 'tutorial_completed_screens';

  // Check if screen tutorial is complete
  static Future<bool> isScreenComplete(String screenId) async {
    final prefs = await SharedPreferences.getInstance();
    final completedScreens = prefs.getStringList(_completedScreensKey) ?? [];
    return completedScreens.contains(screenId);
  }

  // Mark screen tutorial as complete
  static Future<void> markScreenComplete(String screenId) async {
    final prefs = await SharedPreferences.getInstance();
    final completedScreens = prefs.getStringList(_completedScreensKey) ?? [];
    if (!completedScreens.contains(screenId)) {
      completedScreens.add(screenId);
      await prefs.setStringList(_completedScreensKey, completedScreens);
    }
  }

  // Reset specific screen
  static Future<void> resetScreen(String screenId) async {
    final prefs = await SharedPreferences.getInstance();
    final completedScreens = prefs.getStringList(_completedScreensKey) ?? [];
    completedScreens.remove(screenId);
    await prefs.setStringList(_completedScreensKey, completedScreens);
  }

  // Reset all tutorials
  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_completedScreensKey);
  }

  // Get completion status for all screens
  static Future<Map<String, bool>> getAllCompletionStatus() async {
    final Map<String, bool> status = {};
    for (final tutorial in allTutorials) {
      status[tutorial.screenId] = await isScreenComplete(tutorial.screenId);
    }
    return status;
  }
}
