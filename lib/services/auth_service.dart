// lib/services/auth_service.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../services/run_migrations_once.dart';
import '../services/paywall_service.dart';

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
    await runMigrationsOncePerBuild(
      db: FirebaseFirestore.instance,
      explicitUid: cred.user?.uid,
    );

    // NEW: Identify user in RevenueCat
    if (cred.user != null) {
      await PaywallService().identifyUser(cred.user!.uid);
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
    await runMigrationsOncePerBuild(
      db: FirebaseFirestore.instance,
      explicitUid: cred.user?.uid,
    );

    // NEW: Identify user in RevenueCat
    if (cred.user != null) {
      await PaywallService().identifyUser(cred.user!.uid);
    }

    return cred;
  }

  static Future<UserCredential> createWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    debugPrint('[AuthService::createWithEmail] Creating account for: $email');

    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    if (displayName != null && displayName.trim().isNotEmpty) {
      await cred.user!.updateDisplayName(displayName.trim());
    }

    await _touchUserDoc(cred.user, displayNameOverride: displayName);
    await runMigrationsOncePerBuild(
      db: FirebaseFirestore.instance,
      explicitUid: cred.user?.uid,
    );

    // NEW: Identify user in RevenueCat
    if (cred.user != null) {
      await PaywallService().identifyUser(cred.user!.uid);
    }

    // Send verification email immediately
    if (cred.user != null) {
      try {
        await cred.user!.sendEmailVerification();
        debugPrint('[AuthService::createWithEmail] ✅ Verification email sent to: $email');
      } catch (e) {
        debugPrint('[AuthService::createWithEmail] ⚠️ Failed to send verification email: $e');
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
      await runMigrationsOncePerBuild(
        db: FirebaseFirestore.instance,
        explicitUid: cred.user?.uid,
      );

      // NEW: Identify user in RevenueCat
      if (cred.user != null) {
        await PaywallService().identifyUser(cred.user!.uid);
      }

      debugPrint('[AuthService::signInWithApple] ✅ Apple Sign-In successful for user: ${cred.user?.uid}');
      return cred;
    } on SignInWithAppleAuthorizationException catch (e) {
      debugPrint('[AuthService::signInWithApple] ❌ Apple Sign-In cancelled or failed: ${e.code} - ${e.message}');
      throw FirebaseAuthException(
        code: 'apple-signin-cancelled',
        message: 'Apple Sign-In was cancelled',
      );
    } catch (e) {
      debugPrint('[AuthService::signInWithApple] ❌ Apple Sign-In error: $e');
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
      await runMigrationsOncePerBuild(
        db: FirebaseFirestore.instance,
        explicitUid: cred.user?.uid,
      );
      debugPrint('[AuthService::signInAnonymously] ✅ Anonymous sign-in successful');
      return cred;
    } catch (e) {
      debugPrint('[AuthService::signInAnonymously] ❌ Anonymous sign-in failed: $e');
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
          debugPrint('[AuthService::linkAnonymousToEmail] ✅ Verification email sent to: $email');
        } catch (e) {
          debugPrint('[AuthService::linkAnonymousToEmail] ⚠️ Failed to send verification email: $e');
        }
      }

      debugPrint('[AuthService::linkAnonymousToEmail] ✅ Successfully linked anonymous account to email');
      return linkedCred;
    } catch (e) {
      debugPrint('[AuthService::linkAnonymousToEmail] ❌ Failed to link anonymous account: $e');
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
      debugPrint('[AuthService::linkAnonymousToGoogle] ✅ Successfully linked anonymous account to Google');
      return linkedCred;
    } catch (e) {
      debugPrint('[AuthService::linkAnonymousToGoogle] ❌ Failed to link anonymous account: $e');
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
      debugPrint('[AuthService::linkAnonymousToApple] ✅ Successfully linked anonymous account to Apple');
      return linkedCred;
    } catch (e) {
      debugPrint('[AuthService::linkAnonymousToApple] ❌ Failed to link anonymous account: $e');
      rethrow;
    }
  }

  /// Check if current user is anonymous
  static bool get isAnonymous => _auth.currentUser?.isAnonymous ?? false;

  static Future<void> signOut() async {
    try {
      // Log out from RevenueCat
      await PaywallService().logOut();

      await _auth.signOut();
      try {
        await _google.signOut();
        await _google.disconnect();
      } catch (e) {
        // Continue even if Google sign-out fails - Firebase sign-out is more important
        debugPrint('[AuthService::signOut] Google sign-out error (continuing): $e');
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_workspace_id');
      await prefs.remove('last_workspace_name');

      debugPrint('[AuthService::signOut] ✅ Signed out successfully');
    } catch (e) {
      debugPrint('[AuthService::signOut] Error during sign out: $e');
      rethrow;
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
    await users.doc(user.uid).set({
      'displayName': displayNameOverride ?? user.displayName,
      'email': user.email,
      'providers': user.providerData.map((p) => p.providerId).toList(),
      'lastLoginAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
