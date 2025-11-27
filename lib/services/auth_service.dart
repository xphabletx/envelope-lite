import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/run_migrations_once.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _google = GoogleSignIn(
    scopes: <String>['email'],
    signInOption: SignInOption.standard,
  );

  /// Sign in with Google (returns the Firebase [UserCredential])
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

    // Ensure user doc exists/updated
    await _touchUserDoc(cred.user);

    // Run schema/data migrations once per build for this user (safe no-op if already run)
    await runMigrationsOncePerBuild(
      db: FirebaseFirestore.instance,
      explicitUid: cred.user?.uid,
    );

    return cred;
  }

  /// Email + password sign-in
  static Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    await _touchUserDoc(cred.user);

    // Kick migrations (idempotent per build + uid)
    await runMigrationsOncePerBuild(
      db: FirebaseFirestore.instance,
      explicitUid: cred.user?.uid,
    );

    return cred;
  }

  /// Email + password account creation (optionally sets a displayName)
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
    try {
      await cred.user!.sendEmailVerification();
    } catch (_) {
      // non-fatal
    }

    await _touchUserDoc(cred.user, displayNameOverride: displayName);

    // Kick migrations (idempotent per build + uid)
    await runMigrationsOncePerBuild(
      db: FirebaseFirestore.instance,
      explicitUid: cred.user?.uid,
    );

    return cred;
  }

  /// Send a password reset email
  static Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Sign out of Firebase + Google; also clears saved workspace prefs
  static Future<void> signOut() async {
    try {
      await _auth.signOut();
      try {
        await _google.signOut();
        await _google.disconnect();
      } catch (_) {
        // ignore secondary signout errors
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_workspace_id');
      await prefs.remove('last_workspace_name'); // also clear friendly name
    } catch (e) {
      // Optional: forward to crashlytics/logs
      // ignore: avoid_print
      print('Error during sign out: $e');
    }
  }

  /// Creates/updates a lightweight user doc for metadata & future joins
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
      'createdAt': FieldValue.serverTimestamp(), // merge keeps original
    }, SetOptions(merge: true));
  }
}
