// lib/services/user_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';

class UserService {
  final FirebaseFirestore _db;
  final String userId;

  UserService(this._db, this.userId);

  // Get user profile stream
  Stream<UserProfile?> get userProfileStream {
    return _db.collection('users').doc(userId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return UserProfile.fromMap(snap.data()!, userId);
    });
  }

  // Get user profile once
  Future<UserProfile?> getUserProfile() async {
    final snap = await _db.collection('users').doc(userId).get();
    if (!snap.exists) return null;
    return UserProfile.fromMap(snap.data()!, userId);
  }

  // Create new user profile (onboarding)
  Future<void> createUserProfile({
    required String displayName,
    String? photoURL,
    String selectedTheme = 'latte_love',
    bool hasCompletedOnboarding = false, // Default to false - will be set to true when onboarding completes
  }) async {
    final profile = UserProfile(
      uid: userId,
      displayName: displayName,
      photoURL: photoURL,
      selectedTheme: selectedTheme,
      hasCompletedOnboarding: hasCompletedOnboarding,
      showTutorial: true,
      createdAt: DateTime.now(),
    );

    await _db.collection('users').doc(userId).set(profile.toMap());
  }

  // Update user profile
  Future<void> updateUserProfile({
    String? displayName,
    String? photoURL,
    String? selectedTheme,
    bool? hasCompletedOnboarding,
    bool? showTutorial,
  }) async {
    final Map<String, dynamic> updates = {};

    if (displayName != null) updates['displayName'] = displayName;
    if (photoURL != null) updates['photoURL'] = photoURL;
    if (selectedTheme != null) updates['selectedTheme'] = selectedTheme;
    if (hasCompletedOnboarding != null) {
      updates['hasCompletedOnboarding'] = hasCompletedOnboarding;
    }
    if (showTutorial != null) updates['showTutorial'] = showTutorial;

    if (updates.isNotEmpty) {
      await _db.collection('users').doc(userId).update(updates);
    }
  }

  // Check if user has completed onboarding
  Future<bool> hasCompletedOnboarding() async {
    final profile = await getUserProfile();
    return profile?.hasCompletedOnboarding ?? false;
  }

  // Mark tutorial as seen
  Future<void> markTutorialAsSeen() async {
    await updateUserProfile(showTutorial: false);
  }
}
