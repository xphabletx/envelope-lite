// lib/services/tutorial_controller.dart

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/tutorial_sequences.dart';

class TutorialController {
  static const String _completedScreensKey = 'tutorial_completed_screens';

  // Check if screen tutorial is complete
  static Future<bool> isScreenComplete(String screenId) async {
    debugPrint('[Tutorial] ═══════════════════════════════════════');
    debugPrint('[Tutorial] Checking completion status for: $screenId');

    final prefs = await SharedPreferences.getInstance();
    final completedScreens = prefs.getStringList(_completedScreensKey) ?? [];
    final isComplete = completedScreens.contains(screenId);

    debugPrint('[Tutorial] SharedPreferences key: $_completedScreensKey');
    debugPrint('[Tutorial] Completed screens list: ${completedScreens.join(", ")}');
    debugPrint('[Tutorial] Is "$screenId" completed: ${isComplete ? "YES ✅" : "NO ❌"}');
    debugPrint('[Tutorial] ═══════════════════════════════════════');

    return isComplete;
  }

  // Mark screen tutorial as complete
  static Future<void> markScreenComplete(String screenId) async {
    debugPrint('[Tutorial] ═══════════════════════════════════════');
    debugPrint('[Tutorial] Marking as complete: $screenId');

    final prefs = await SharedPreferences.getInstance();
    final completedScreens = prefs.getStringList(_completedScreensKey) ?? [];

    if (!completedScreens.contains(screenId)) {
      completedScreens.add(screenId);
      await prefs.setStringList(_completedScreensKey, completedScreens);
      debugPrint('[Tutorial] ✅ Successfully marked "$screenId" as complete');
      debugPrint('[Tutorial] Updated list: ${completedScreens.join(", ")}');
    } else {
      debugPrint('[Tutorial] ⏭️ Screen "$screenId" was already marked complete');
    }

    debugPrint('[Tutorial] ═══════════════════════════════════════');
  }

  // Reset specific screen
  static Future<void> resetScreen(String screenId) async {
    debugPrint('[Tutorial] ═══════════════════════════════════════');
    debugPrint('[Tutorial] Resetting screen: $screenId');

    final prefs = await SharedPreferences.getInstance();
    final completedScreens = prefs.getStringList(_completedScreensKey) ?? [];

    final wasPresent = completedScreens.contains(screenId);
    completedScreens.remove(screenId);
    await prefs.setStringList(_completedScreensKey, completedScreens);

    if (wasPresent) {
      debugPrint('[Tutorial] ✅ Successfully reset "$screenId"');
      debugPrint('[Tutorial] Updated list: ${completedScreens.join(", ")}');
    } else {
      debugPrint('[Tutorial] ⚠️ Screen "$screenId" was not in completed list');
    }

    debugPrint('[Tutorial] ═══════════════════════════════════════');
  }

  // Reset all tutorials
  static Future<void> resetAll() async {
    debugPrint('[Tutorial] ═══════════════════════════════════════');
    debugPrint('[Tutorial] RESETTING ALL TUTORIALS');

    final prefs = await SharedPreferences.getInstance();
    final completedScreens = prefs.getStringList(_completedScreensKey) ?? [];

    debugPrint('[Tutorial] Previously completed: ${completedScreens.join(", ")}');
    await prefs.remove(_completedScreensKey);
    debugPrint('[Tutorial] ✅ All tutorials reset successfully');
    debugPrint('[Tutorial] ═══════════════════════════════════════');
  }

  // Get completion status for all screens
  static Future<Map<String, bool>> getAllCompletionStatus() async {
    debugPrint('[Tutorial] ═══════════════════════════════════════');
    debugPrint('[Tutorial] Getting completion status for all screens');

    final Map<String, bool> status = {};
    for (final tutorial in allTutorials) {
      status[tutorial.screenId] = await isScreenComplete(tutorial.screenId);
    }

    debugPrint('[Tutorial] Total tutorials: ${allTutorials.length}');
    final completedCount = status.values.where((v) => v).length;
    debugPrint('[Tutorial] Completed: $completedCount / ${allTutorials.length}');
    debugPrint('[Tutorial] ═══════════════════════════════════════');

    return status;
  }
}
