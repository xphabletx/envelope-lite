// lib/services/auth_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:provider/provider.dart';

import '../services/subscription_service.dart';
import '../services/hive_service.dart';
import '../services/repository_manager.dart';
import '../providers/workspace_provider.dart';
import '../providers/repository_provider.dart';
import '../main.dart' show navigatorKey;
import '../screens/auth/auth_wrapper.dart' show AuthWrapperState;

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _google = GoogleSignIn(
    scopes: <String>['email'],
  );

  // --- Sign In Methods ---

  static Future<UserCredential> signInWithGoogle() async {
    final googleUser = await _google.signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'canceled',
        message: 'Google sign-in cancelled',
      );
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final cred = await _auth.signInWithCredential(credential);
    await _touchUserDoc(cred.user);

    // NEW: Identify user in RevenueCat
    if (cred.user != null) {
      await SubscriptionService().identifyUser(cred.user!.uid);
    }

    return cred;
  }

  static Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await _touchUserDoc(cred.user);

    // NEW: Identify user in RevenueCat
    if (cred.user != null) {
      await SubscriptionService().identifyUser(cred.user!.uid);
    }

    return cred;
  }

  static Future<UserCredential> createWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    if (displayName != null && displayName.trim().isNotEmpty) {
      await cred.user!.updateDisplayName(displayName.trim());
    }

    await _touchUserDoc(cred.user, displayNameOverride: displayName);

    // NEW: Identify user in RevenueCat
    if (cred.user != null) {
      await SubscriptionService().identifyUser(cred.user!.uid);
    }

    // Send verification email immediately
    if (cred.user != null) {
      try {
        await cred.user!.sendEmailVerification();
      } catch (e) {
        // Don't throw - account creation succeeded, just log the error
      }
    }

    return cred;
  }

  static Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // --- Apple Sign-In (iOS App Store Requirement) ---

  /// Sign in with Apple (iOS only)
  ///
  /// Required by Apple App Store guidelines for apps that offer other social login options.
  ///
  /// Throws [FirebaseAuthException] if sign-in fails
  /// Throws [SignInWithAppleAuthorizationException] if user cancels
  ///
  /// IMPORTANT: Before using this method in production, you must:
  /// 1. Enable "Sign in with Apple" capability in Xcode
  /// 2. Create a Service ID in Apple Developer portal
  /// 3. Configure OAuth redirect domains in Firebase Console
  /// 4. Replace 'YOUR_SERVICE_ID' and 'YOUR_REDIRECT_URI' below with actual values
  ///
  /// For web support, you must provide webAuthenticationOptions.
  /// For iOS-only apps, this parameter can be omitted.
  static Future<UserCredential> signInWithApple() async {
    try {
      // Request Apple ID credential
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        // For web/Android support, uncomment and configure:
        // webAuthenticationOptions: WebAuthenticationOptions(
        //   clientId: 'YOUR_SERVICE_ID',
        //   redirectUri: Uri.parse('YOUR_REDIRECT_URI'),
        // ),
      );

      // Create OAuth credential for Firebase
      final oAuthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      // Sign in to Firebase
      final cred = await _auth.signInWithCredential(oAuthCredential);

      // Apple might not provide email on subsequent sign-ins
      // Use the name from first sign-in if available
      if (appleCredential.givenName != null ||
          appleCredential.familyName != null) {
        final displayName =
            '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'
                .trim();
        if (displayName.isNotEmpty) {
          await cred.user?.updateDisplayName(displayName);
        }
      }

      await _touchUserDoc(cred.user);

      // NEW: Identify user in RevenueCat
      if (cred.user != null) {
        await SubscriptionService().identifyUser(cred.user!.uid);
      }

      return cred;
    } on SignInWithAppleAuthorizationException catch (e) {
      throw FirebaseAuthException(
        code: 'apple-signin-cancelled',
        message: 'Apple Sign-In was cancelled',
      );
    } catch (e) {
      throw FirebaseAuthException(
        code: 'apple-signin-failed',
        message: 'Apple Sign-In failed: ${e.toString()}',
      );
    }
  }

  // --- Anonymous Sign-In (Try Before You Buy) ---

  /// Sign in anonymously (allows users to try the app without creating an account)
  ///
  /// Anonymous users can later be upgraded to permanent accounts using
  /// [linkAnonymousToEmail], [linkAnonymousToGoogle], or [linkAnonymousToApple]
  ///
  /// Anonymous accounts are temporary and will be lost if:
  /// - User signs out
  /// - User clears app data
  /// - User uninstalls the app
  ///
  /// Returns the UserCredential for the anonymous user
  static Future<UserCredential> signInAnonymously() async {
    try {
      final cred = await _auth.signInAnonymously();
      await _touchUserDoc(cred.user, displayNameOverride: 'Guest User');
      return cred;
    } catch (e) {
      rethrow;
    }
  }

  /// Link anonymous account to email/password credentials
  ///
  /// Converts a temporary anonymous account to a permanent email account.
  /// All user data is preserved during the conversion.
  ///
  /// Throws [Exception] if current user is not anonymous.
  /// Throws [FirebaseAuthException] if linking fails (e.g., email already in use)
  static Future<UserCredential> linkAnonymousToEmail({
    required String email,
    required String password,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user signed in');
    }
    if (!user.isAnonymous) {
      throw Exception('Current user is not anonymous - cannot link');
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: email.trim(),
        password: password,
      );

      final linkedCred = await user.linkWithCredential(credential);
      await _touchUserDoc(linkedCred.user);

      // Send verification email after linking
      if (linkedCred.user != null) {
        try {
          await linkedCred.user!.sendEmailVerification();
        } catch (e) {
          // Failed to send verification email
        }
      }

      return linkedCred;
    } catch (e) {
      rethrow;
    }
  }

  /// Link anonymous account to Google credentials
  ///
  /// Converts a temporary anonymous account to a permanent Google account.
  /// All user data is preserved during the conversion.
  ///
  /// Throws [Exception] if current user is not anonymous.
  /// Throws [FirebaseAuthException] if linking fails
  static Future<UserCredential> linkAnonymousToGoogle() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user signed in');
    }
    if (!user.isAnonymous) {
      throw Exception('Current user is not anonymous - cannot link');
    }

    try {
      final googleUser = await _google.signIn();
      if (googleUser == null) {
        throw FirebaseAuthException(
          code: 'canceled',
          message: 'Google sign-in cancelled',
        );
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final linkedCred = await user.linkWithCredential(credential);
      await _touchUserDoc(linkedCred.user);
      return linkedCred;
    } catch (e) {
      rethrow;
    }
  }

  /// Link anonymous account to Apple credentials
  ///
  /// Converts a temporary anonymous account to a permanent Apple account.
  /// All user data is preserved during the conversion.
  ///
  /// Throws [Exception] if current user is not anonymous.
  /// Throws [FirebaseAuthException] if linking fails
  static Future<UserCredential> linkAnonymousToApple() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user signed in');
    }
    if (!user.isAnonymous) {
      throw Exception('Current user is not anonymous - cannot link');
    }

    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oAuthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final linkedCred = await user.linkWithCredential(oAuthCredential);

      // Update display name if provided
      if (appleCredential.givenName != null ||
          appleCredential.familyName != null) {
        final displayName =
            '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'
                .trim();
        if (displayName.isNotEmpty) {
          await linkedCred.user?.updateDisplayName(displayName);
        }
      }

      await _touchUserDoc(linkedCred.user);
      return linkedCred;
    } catch (e) {
      rethrow;
    }
  }

  /// Check if current user is anonymous
  static bool get isAnonymous => _auth.currentUser?.isAnonymous ?? false;

  /// Clear local onboarding flags for a specific user
  /// This ensures brand new users start onboarding from scratch
  static Future<void> clearLocalOnboardingFlags(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Remove onboarding completion flag
      await prefs.remove('hasCompletedOnboarding_$userId');

      // Remove current onboarding step
      await prefs.remove('onboarding_step_$userId');

      // Clear any profile photo path from previous account
      await prefs.remove('profile_photo_path');

      // Clear target icon preferences from previous account
      await prefs.remove('target_icon_type');
      await prefs.remove('target_icon_value');

    } catch (e) {
      // Don't rethrow - this is not critical
    }
  }

  /// Clear Hive boxes if they contain data from a different user
  /// This prevents ghost data from appearing for new users
  static Future<void> clearHiveIfDifferentUser(String currentUserId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUserId = prefs.getString('last_hive_user_id');

      if (lastUserId != null && lastUserId != currentUserId) {
        // Clear all Hive boxes
        await HiveService.clearAllData();
      }

      // Update the last user ID
      await prefs.setString('last_hive_user_id', currentUserId);

    } catch (e) {
      // Don't rethrow - this is not critical
    }
  }

  static Future<void> signOut() async {
    try {
      // STEP 0: Sync onboarding status to Firestore BEFORE clearing local data
      // This ensures the user doesn't lose their onboarding progress
      final currentUser = _auth.currentUser;
      if (currentUser != null && !currentUser.isAnonymous) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final hasCompletedOnboarding = prefs.getBool('hasCompletedOnboarding_${currentUser.uid}') ?? false;

          if (hasCompletedOnboarding) {
            debugPrint('[AuthService] 🔄 Syncing onboarding completion to Firestore before logout');
            await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .set({
              'hasCompletedOnboarding': true,
              'lastSyncAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            debugPrint('[AuthService] ✅ Onboarding status synced to Firestore');
          }
        } catch (e) {
          debugPrint('[AuthService] ⚠️ Failed to sync onboarding status: $e');
          // Continue with logout even if sync fails
        }
      }

      // STEP 1: Clear auth wrapper initialization state
      // This allows the next user to run through initialization properly
      AuthWrapperState.clearInitializationState();

      // STEP 2: Dispose all repositories to cancel Firestore streams
      // This prevents PERMISSION_DENIED errors when we sign out from Firebase
      RepositoryManager().disposeAllRepositories();

      // Also clear the RepositoryProvider if available
      try {
        final context = navigatorKey.currentContext;
        if (context != null) {
          Provider.of<RepositoryProvider>(context, listen: false).clearRepositories();
        }
      } catch (e) {
        // Continue if provider not available
      }

      // STEP 2: HARD-KILL Firestore listeners at engine level
      // This is the ONLY way to guarantee PERMISSION_DENIED errors stop
      // before the UI finishes its transition
      try {
        await FirebaseFirestore.instance.terminate();
      } catch (e) {
        // Continue on error
      }

      try {
        await FirebaseFirestore.instance.clearPersistence();
      } catch (e) {
        // Continue on error
      }

      // STEP 3: Log out from RevenueCat
      await SubscriptionService().logOut();

      // STEP 4: Sign out from Firebase Auth
      await _auth.signOut();

      // STEP 5: Sign out from Google if there's an active session
      try {
        final googleUser = await _google.signInSilently();
        if (googleUser != null) {
          await _google.signOut();
        }
      } catch (e) {
        // Continue even if Google sign-out fails - Firebase sign-out is more important
      }

      // STEP 6: Clear all local data (Hive boxes)
      await HiveService.clearAllData();

      // STEP 7: Clear all SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // STEP 8: Force navigation to sign-in screen
      // This ensures UI fully resets even if StreamBuilder hasn't updated yet
      final navigator = navigatorKey.currentState;
      if (navigator != null && navigator.mounted) {
        // Use pushNamedAndRemoveUntil to clear the entire navigation stack
        // This prevents any back navigation to authenticated screens
        navigator.pushNamedAndRemoveUntil('/', (route) => false);
      }

    } catch (e) {
      rethrow;
    } finally {
      // CRITICAL: Always reset logout state in finally block
      // This ensures the guard is lifted even if logout fails
      final context = navigatorKey.currentContext;
      if (context != null) {
        try {
          Provider.of<WorkspaceProvider>(context, listen: false).resetLogoutState();
        } catch (e) {
          // Could not reset logout state
        }
      }
    }
  }

  // --- ACCOUNT DELETION ---
  //
  // ⚠️ IMPORTANT: Account deletion is NOT implemented in AuthService.
  //
  // User account deletion must be handled by AccountSecurityService for security reasons.
  // That service provides:
  // - User re-authentication before deletion (security requirement)
  // - UI confirmation dialogs
  // - Complete GDPR-compliant cascade deletion of all user data
  // - Workspace cleanup
  // - Prevention of zombie accounts (partial deletion failures)
  //
  // To delete a user account, use:
  //
  //   import '../services/account_security_service.dart';
  //   await AccountSecurityService().deleteAccount(context);
  //
  // DO NOT implement account deletion in this file. Account deletion is a sensitive
  // operation that requires proper security measures and complete data cleanup.
  //
  // See: lib/services/account_security_service.dart for the implementation

  static Future<void> _touchUserDoc(
    User? user, {
    String? displayNameOverride,
  }) async {
    if (user == null) return;
    final users = FirebaseFirestore.instance.collection('users');

    // Build the user document with all required fields
    final Map<String, dynamic> userData = {
      'displayName': displayNameOverride ?? user.displayName ?? user.email?.split('@').first ?? 'User',
      'email': user.email,
      'providers': user.providerData.map((p) => p.providerId).toList(),
      'lastLoginAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      // UserProfile fields (only set on first creation, not on subsequent logins)
      'selectedTheme': 'latte_love',
      'hasCompletedOnboarding': false,
      'showTutorial': true,
    };

    // Add photoURL if available (Google/Apple sign-in provides this)
    if (user.photoURL != null) {
      userData['photoURL'] = user.photoURL;
    }

    await users.doc(user.uid).set(userData, SetOptions(merge: true));
  }
}
