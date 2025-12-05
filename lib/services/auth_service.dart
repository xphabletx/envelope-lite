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

  // --- Sign In Methods (Unchanged) ---

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
    await runMigrationsOncePerBuild(
      db: FirebaseFirestore.instance,
      explicitUid: cred.user?.uid,
    );
    return cred;
  }

  static Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  static Future<void> signOut() async {
    try {
      await _auth.signOut();
      try {
        await _google.signOut();
        await _google.disconnect();
      } catch (_) {}
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_workspace_id');
      await prefs.remove('last_workspace_name');
    } catch (e) {
      // ignore: avoid_print
      print('Error during sign out: $e');
    }
  }

  // --- ACCOUNT DELETION (Corrected Paths) ---

  static Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user signed in');

    final uid = user.uid;
    final db = FirebaseFirestore.instance;

    try {
      // 1. Define the data root path
      // Path: users/{uid}/solo/data/
      final userSoloData = db
          .collection('users')
          .doc(uid)
          .collection('solo')
          .doc('data');

      // 2. Delete Envelopes
      final envelopes = await userSoloData.collection('envelopes').get();
      for (var doc in envelopes.docs) {
        await doc.reference.delete();
      }

      // 3. Delete Transactions
      final transactions = await userSoloData.collection('transactions').get();
      for (var doc in transactions.docs) {
        await doc.reference.delete();
      }

      // 4. Delete Groups
      final groups = await userSoloData.collection('groups').get();
      for (var doc in groups.docs) {
        await doc.reference.delete();
      }

      // 5. Delete the data container doc ('solo/data')
      await userSoloData.delete();

      // 6. Delete Scheduled Payments (if they exist at root level or elsewhere)
      // Checking root collection 'scheduled_payments' inside user
      final scheduled = await db
          .collection('users')
          .doc(uid)
          .collection('scheduled_payments')
          .get();
      for (var doc in scheduled.docs) {
        await doc.reference.delete();
      }

      // 7. Delete User Profile Doc
      await db.collection('users').doc(uid).delete();

      // 8. Clean up local prefs
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_workspace_id');
      await prefs.remove('last_workspace_name');

      // 9. Delete Auth Account
      await user.delete();
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error deleting account: $e');
      rethrow;
    }
  }

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
