// lib/services/onboarding_progress_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/onboarding_progress.dart';

/// Service to manage onboarding progress
/// Saves progress incrementally to users/{userId}/onboarding/progress
/// Data stays in this separate space until onboarding completion
class OnboardingProgressService {
  final FirebaseFirestore _firestore;
  final String userId;

  OnboardingProgressService(this._firestore, this.userId);

  /// Get the document reference for onboarding progress
  DocumentReference get _progressDoc =>
      _firestore.collection('users').doc(userId).collection('onboarding').doc('progress');

  /// Save current onboarding progress
  Future<void> saveProgress(OnboardingProgress progress) async {
    await _progressDoc.set(progress.toFirestore());
  }

  /// Load saved onboarding progress
  Future<OnboardingProgress?> loadProgress() async {
    final doc = await _progressDoc.get();
    if (doc.exists) {
      return OnboardingProgress.fromFirestore(doc);
    }
    return null;
  }

  /// Update specific fields of onboarding progress
  Future<void> updateProgress(Map<String, dynamic> updates) async {
    updates['lastUpdated'] = Timestamp.now();
    await _progressDoc.update(updates);
  }

  /// Clear onboarding progress (called after successful completion)
  Future<void> clearProgress() async {
    await _progressDoc.delete();
  }

  /// Check if onboarding progress exists
  Future<bool> hasProgress() async {
    final doc = await _progressDoc.get();
    return doc.exists;
  }
}
