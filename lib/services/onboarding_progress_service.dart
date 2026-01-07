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
    // 1. Save to SharedPreferences (primary, always works offline)
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(progress.toMap());
      await prefs.setString(_prefsKey, json);
    } catch (e) {
      debugPrint('[OnboardingProgressService] ❌ Failed to save to SharedPreferences: $e');
    }

    // 2. Best-effort sync to Firestore (optional, fails silently offline)
    try {
      await _progressDoc.set(progress.toFirestore());
    } catch (e) {
      debugPrint('[OnboardingProgressService] ⚠️ Firestore sync failed (offline?): $e');
    }
  }

  /// Load saved onboarding progress (local-first)
  Future<OnboardingProgress?> loadProgress() async {
    // 1. Try loading from SharedPreferences first (primary, works offline)
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_prefsKey);

      if (json != null) {
        final map = jsonDecode(json) as Map<String, dynamic>;
        return OnboardingProgress.fromMap(map);
      }
    } catch (e) {
      debugPrint('[OnboardingProgressService] ⚠️ Failed to load from SharedPreferences: $e');
    }

    // 2. Fallback to Firestore if local data not found (requires network)
    try {
      final doc = await _progressDoc.get();
      if (doc.exists) {
        final progress = OnboardingProgress.fromFirestore(doc);

        // Cache to SharedPreferences for offline access
        try {
          final prefs = await SharedPreferences.getInstance();
          final json = jsonEncode(progress.toMap());
          await prefs.setString(_prefsKey, json);
        } catch (e) {
          debugPrint('[OnboardingProgressService] Failed to cache Firestore data: $e');
        }

        return progress;
      }
    } catch (e) {
      debugPrint('[OnboardingProgressService] ⚠️ Firestore load failed (offline?): $e');
    }

    return null;
  }

  /// Update specific fields of onboarding progress
  Future<void> updateProgress(Map<String, dynamic> updates) async {
    // Load current progress, update fields, and save
    final current = await loadProgress();
    if (current != null) {
      final updated = current.copyWithMap(updates);
      await saveProgress(updated);
    }
  }

  /// Clear onboarding progress (called after successful completion)
  Future<void> clearProgress() async {
    // 1. Clear from SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (e) {
      debugPrint('[OnboardingProgressService] Failed to clear SharedPreferences: $e');
    }

    // 2. Best-effort delete from Firestore
    try {
      await _progressDoc.delete();
    } catch (e) {
      debugPrint('[OnboardingProgressService] Firestore delete failed (offline?): $e');
    }
  }

  /// Check if onboarding progress exists
  Future<bool> hasProgress() async {
    // Check SharedPreferences first (always available offline)
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_prefsKey);
    } catch (e) {
      debugPrint('[OnboardingProgressService] Failed to check SharedPreferences: $e');
      return false;
    }
  }
}
