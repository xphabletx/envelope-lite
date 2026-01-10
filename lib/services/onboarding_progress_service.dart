// lib/services/onboarding_progress_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/onboarding_progress.dart';

/// Service to manage onboarding progress
/// PRIMARY STORAGE: SharedPreferences (local-first, works offline)
/// SECONDARY SYNC: Firestore (optional, best-effort sync)
/// Data stays in this separate space until onboarding completion
class OnboardingProgressService {
  final FirebaseFirestore _firestore;
  final String userId;

  OnboardingProgressService(this._firestore, this.userId);

  /// Get the document reference for onboarding progress (Firestore)
  DocumentReference get _progressDoc =>
      _firestore.collection('users').doc(userId).collection('onboarding').doc('progress');

  /// SharedPreferences key for this user's onboarding progress
  String get _prefsKey => 'onboarding_progress_$userId';

  /// Save current onboarding progress (local-first with Firestore sync)
  Future<void> saveProgress(OnboardingProgress progress) async {
    debugPrint('[Onboarding:ProgressService] 💾 Saving progress - userId: $userId, currentStep: ${progress.currentStep}, userName: ${progress.userName}, isAccountMode: ${progress.isAccountMode}');

    // 1. Save to SharedPreferences (primary, always works offline)
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(progress.toMap());
      await prefs.setString(_prefsKey, json);
      debugPrint('[Onboarding:ProgressService] ✅ Saved to SharedPreferences - key: $_prefsKey');
    } catch (e) {
      debugPrint('[Onboarding:ProgressService] ❌ Failed to save to SharedPreferences: $e');
    }

    // 2. Best-effort sync to Firestore (optional, fails silently offline)
    try {
      await _progressDoc.set(progress.toFirestore());
      debugPrint('[Onboarding:ProgressService] ✅ Synced to Firestore - path: users/$userId/onboarding/progress');
    } catch (e) {
      debugPrint('[Onboarding:ProgressService] ⚠️ Failed to sync to Firestore (offline?): $e');
    }
  }

  /// Load saved onboarding progress (local-first)
  Future<OnboardingProgress?> loadProgress() async {
    debugPrint('[Onboarding:ProgressService] 🔍 Loading progress for userId: $userId');

    // 1. Try loading from SharedPreferences first (primary, works offline)
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_prefsKey);

      if (json != null) {
        debugPrint('[Onboarding:ProgressService] 📥 Found progress in SharedPreferences');
        final map = jsonDecode(json) as Map<String, dynamic>;
        final progress = OnboardingProgress.fromMap(map);
        debugPrint('[Onboarding:ProgressService] ✅ Loaded from SharedPreferences - currentStep: ${progress.currentStep}, userName: ${progress.userName}, isAccountMode: ${progress.isAccountMode}');
        return progress;
      } else {
        debugPrint('[Onboarding:ProgressService] 📭 No progress found in SharedPreferences');
      }
    } catch (e) {
      debugPrint('[Onboarding:ProgressService] ❌ Error loading from SharedPreferences: $e');
    }

    // 2. Fallback to Firestore if local data not found (requires network)
    try {
      debugPrint('[Onboarding:ProgressService] 🔥 Checking Firestore for progress...');
      final doc = await _progressDoc.get();
      if (doc.exists) {
        debugPrint('[Onboarding:ProgressService] 📥 Found progress in Firestore');
        final progress = OnboardingProgress.fromFirestore(doc);

        // Cache to SharedPreferences for offline access
        try {
          final prefs = await SharedPreferences.getInstance();
          final json = jsonEncode(progress.toMap());
          await prefs.setString(_prefsKey, json);
          debugPrint('[Onboarding:ProgressService] ✅ Cached Firestore data to SharedPreferences');
        } catch (e) {
          debugPrint('[Onboarding:ProgressService] ⚠️ Failed to cache to SharedPreferences: $e');
        }

        debugPrint('[Onboarding:ProgressService] ✅ Loaded from Firestore - currentStep: ${progress.currentStep}, userName: ${progress.userName}, isAccountMode: ${progress.isAccountMode}');
        return progress;
      } else {
        debugPrint('[Onboarding:ProgressService] 📭 No progress found in Firestore');
      }
    } catch (e) {
      debugPrint('[Onboarding:ProgressService] ⚠️ Error loading from Firestore (offline?): $e');
    }

    debugPrint('[Onboarding:ProgressService] 📭 No progress found anywhere - returning null');
    return null;
  }

  /// Update specific fields of onboarding progress
  Future<void> updateProgress(Map<String, dynamic> updates) async {
    debugPrint('[Onboarding:ProgressService] 🔄 Updating progress fields: ${updates.keys.join(", ")}');
    // Load current progress, update fields, and save
    final current = await loadProgress();
    if (current != null) {
      final updated = current.copyWithMap(updates);
      await saveProgress(updated);
      debugPrint('[Onboarding:ProgressService] ✅ Progress updated successfully');
    } else {
      debugPrint('[Onboarding:ProgressService] ⚠️ No existing progress to update');
    }
  }

  /// Clear onboarding progress (called after successful completion)
  Future<void> clearProgress() async {
    debugPrint('[Onboarding:ProgressService] 🗑️ Clearing progress for userId: $userId');

    // 1. Clear from SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
      debugPrint('[Onboarding:ProgressService] ✅ Cleared from SharedPreferences');
    } catch (e) {
      debugPrint('[Onboarding:ProgressService] ❌ Failed to clear from SharedPreferences: $e');
    }

    // 2. Best-effort delete from Firestore
    try {
      await _progressDoc.delete();
      debugPrint('[Onboarding:ProgressService] ✅ Deleted from Firestore');
    } catch (e) {
      debugPrint('[Onboarding:ProgressService] ⚠️ Failed to delete from Firestore (offline?): $e');
    }
  }

  /// Check if onboarding progress exists
  Future<bool> hasProgress() async {
    debugPrint('[Onboarding:ProgressService] 🔍 Checking if progress exists for userId: $userId');

    // Check SharedPreferences first (always available offline)
    try {
      final prefs = await SharedPreferences.getInstance();
      final exists = prefs.containsKey(_prefsKey);
      debugPrint('[Onboarding:ProgressService] ${exists ? "✅" : "📭"} Progress ${exists ? "exists" : "does not exist"}');
      return exists;
    } catch (e) {
      debugPrint('[Onboarding:ProgressService] ❌ Error checking for progress: $e');
      return false;
    }
  }
}
