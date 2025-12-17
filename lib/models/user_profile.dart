// lib/models/user_profile.dart

class UserProfile {
  final String uid;
  final String displayName;
  final String? photoURL;
  final String selectedTheme; // 'latte_love', 'blush_gold', etc.
  final bool hasCompletedOnboarding;
  final bool showTutorial;
  final DateTime createdAt;

  UserProfile({
    required this.uid,
    required this.displayName,
    this.photoURL,
    this.selectedTheme = 'latte_love',
    this.hasCompletedOnboarding = false,
    this.showTutorial = true,
    required this.createdAt,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map, String uid) {
    DateTime createdAtDate = DateTime.now();
    if (map['createdAt'] != null) {
      final createdAtValue = map['createdAt'];
      if (createdAtValue is int) {
        createdAtDate = DateTime.fromMillisecondsSinceEpoch(createdAtValue);
      } else {
        try {
          createdAtDate = (createdAtValue as dynamic).toDate();
        } catch (e) {
          createdAtDate = DateTime.now();
        }
      }
    }

    return UserProfile(
      uid: uid,
      displayName: map['displayName'] ?? 'User',
      photoURL: map['photoURL'],
      selectedTheme: map['selectedTheme'] ?? 'latte_love',
      hasCompletedOnboarding: map['hasCompletedOnboarding'] ?? false,
      showTutorial: map['showTutorial'] ?? true,
      createdAt: createdAtDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'photoURL': photoURL,
      'selectedTheme': selectedTheme,
      'hasCompletedOnboarding': hasCompletedOnboarding,
      'showTutorial': showTutorial,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  UserProfile copyWith({
    String? displayName,
    String? photoURL,
    String? selectedTheme,
    bool? hasCompletedOnboarding,
    bool? showTutorial,
  }) {
    return UserProfile(
      uid: uid,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      selectedTheme: selectedTheme ?? this.selectedTheme,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      showTutorial: showTutorial ?? this.showTutorial,
      createdAt: createdAt,
    );
  }
}
