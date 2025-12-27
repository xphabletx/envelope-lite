import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'workspace_helper.dart';

class AccountSecurityService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> deleteAccount(BuildContext context) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    // 1. "Scary" Confirmation Dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'This action cannot be undone. All your envelopes, transactions, and settings will be permanently destroyed.\n\n'
          'Shared data in workspaces you do not own may remain, but will be anonymized.',
          style: TextStyle(color: Colors.red),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('PERMANENTLY DELETE'),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;

    if (!context.mounted) return false;

    // 2. Re-authentication FIRST (before deleting any data)
    bool reAuthSuccess = await _handleReauthentication(context, user);
    if (!reAuthSuccess) return false;

    // 3. Loading State
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
    }

    bool dataDeleted = false;
    try {
      // 4. Execute Firestore Cascade
      await _performGDPRCascade(user.uid);
      dataDeleted = true;

      // 5. Delete Auth Account
      await user.delete();

      // 6. Navigation
      if (context.mounted) {
        Navigator.of(context).pop(); // Dismiss loader
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
      return true;
    } catch (e) {
      // CRITICAL: If data was deleted but auth deletion failed, force sign out
      // This prevents "zombie account" state
      if (dataDeleted) {
        await _auth.signOut();
        if (context.mounted) {
          Navigator.of(context).pop(); // Dismiss loader
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(
            const SnackBar(
              content: Text(
                'Your data was deleted but account deletion failed. You have been signed out.',
              ),
            ),
          );
        }
        return false;
      }

      if (context.mounted) {
        Navigator.of(context).pop(); // Dismiss loader
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting account: $e')));
      }
      return false;
    }
  }

  Future<bool> _handleReauthentication(BuildContext context, User user) async {
    // Determine provider
    final providerId = user.providerData.isNotEmpty
        ? user.providerData.first.providerId
        : 'password';

    if (providerId == 'google.com') {
      // Trigger actual Google Sign In
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) return false; // User cancelled

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      try {
        await user.reauthenticateWithCredential(credential);
        return true;
      } on FirebaseAuthException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Google verification failed: ${e.message}')),
          );
        }
        return false;
      }
    } else {
      // Email/Password Flow
      final password = await _promptForPassword(context);
      if (password == null) return false;

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      try {
        await user.reauthenticateWithCredential(credential);
        return true;
      } on FirebaseAuthException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Verification failed: ${e.message}')),
          );
        }
        return false;
      }
    }
  }

  Future<String?> _promptForPassword(BuildContext context) {
    String? inputPassword;
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Password'),
        content: TextField(
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Password'),
          onChanged: (val) => inputPassword = val,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, inputPassword),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  Future<void> _performGDPRCascade(String userId) async {
    debugPrint('[AccountSecurity::_performGDPRCascade] Starting cascade delete for user: $userId');

    // CRITICAL: Get user's workspace memberships BEFORE deleting user doc
    final userDoc = await _firestore.doc('users/$userId').get();
    String? workspaceId;

    if (userDoc.exists) {
      final userData = userDoc.data() as Map<String, dynamic>?;
      workspaceId = userData?['activeWorkspaceId'] as String?;
    }

    // Remove from workspace if applicable
    if (workspaceId != null) {
      try {
        await WorkspaceHelper.leaveWorkspace(workspaceId, userId);
        debugPrint('[AccountSecurity::_performGDPRCascade] Removed user from workspace: $workspaceId');
      } catch (e) {
        debugPrint('[AccountSecurity::_performGDPRCascade] Error leaving workspace: $e');
        // Continue with deletion even if workspace removal fails
      }
    }

    // Clear workspace from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_workspace_id');
    await prefs.remove('last_workspace_id');
    await prefs.remove('last_workspace_name');
    debugPrint('[AccountSecurity::_performGDPRCascade] Cleared workspace from SharedPreferences');

    // Use batch for atomic deletion (max 500 operations per batch)
    // If user has >500 items in any collection, we'll need multiple batches
    WriteBatch batch = _firestore.batch();
    int operationCount = 0;

    // Helper to commit batch if approaching limit
    Future<void> commitIfNeeded() async {
      if (operationCount >= 450) {
        // Leave buffer for safety
        await batch.commit();
        batch = _firestore.batch(); // Start new batch
        operationCount = 0;
        debugPrint('[AccountSecurity::_performGDPRCascade] Committed batch (approaching 500 operation limit)');
      }
    }

    try {
      // 1. Delete Envelopes
      final envelopesSnap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('solo')
          .doc('data')
          .collection('envelopes')
          .get();
      debugPrint('[AccountSecurity::_performGDPRCascade] Deleting ${envelopesSnap.docs.length} envelopes');
      for (var doc in envelopesSnap.docs) {
        batch.delete(doc.reference);
        operationCount++;
        await commitIfNeeded();
      }

      // 2. Delete Groups (Binders)
      final groupsSnap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('solo')
          .doc('data')
          .collection('groups')
          .get();
      debugPrint('[AccountSecurity::_performGDPRCascade] Deleting ${groupsSnap.docs.length} groups');
      for (var doc in groupsSnap.docs) {
        batch.delete(doc.reference);
        operationCount++;
        await commitIfNeeded();
      }

      // 3. Delete Transactions
      final txSnap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('solo')
          .doc('data')
          .collection('transactions')
          .get();
      debugPrint('[AccountSecurity::_performGDPRCascade] Deleting ${txSnap.docs.length} transactions');
      for (var doc in txSnap.docs) {
        batch.delete(doc.reference);
        operationCount++;
        await commitIfNeeded();
      }

      // 4. Delete Scheduled Payments (FIXED PATH)
      final schedSnap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('solo')
          .doc('data')
          .collection('scheduledPayments')
          .get();
      debugPrint('[AccountSecurity::_performGDPRCascade] Deleting ${schedSnap.docs.length} scheduled payments');
      for (var doc in schedSnap.docs) {
        batch.delete(doc.reference);
        operationCount++;
        await commitIfNeeded();
      }

      // 5. Delete Accounts (WAS MISSING!)
      final accountsSnap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('solo')
          .doc('data')
          .collection('accounts')
          .get();
      debugPrint('[AccountSecurity::_performGDPRCascade] Deleting ${accountsSnap.docs.length} accounts');
      for (var doc in accountsSnap.docs) {
        batch.delete(doc.reference);
        operationCount++;
        await commitIfNeeded();
      }

      // 6. Delete Notifications (WAS MISSING!)
      final notificationsSnap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .get();
      debugPrint('[AccountSecurity::_performGDPRCascade] Deleting ${notificationsSnap.docs.length} notifications');
      for (var doc in notificationsSnap.docs) {
        batch.delete(doc.reference);
        operationCount++;
        await commitIfNeeded();
      }

      // 7. Delete PayDaySettings (WAS MISSING!)
      try {
        final paySettingsRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('solo')
            .doc('data')
            .collection('payDaySettings')
            .doc('settings');

        final paySettingsDoc = await paySettingsRef.get();
        if (paySettingsDoc.exists) {
          batch.delete(paySettingsRef);
          operationCount++;
          debugPrint('[AccountSecurity::_performGDPRCascade] Deleted PayDaySettings');
        }
      } catch (e) {
        debugPrint('[AccountSecurity::_performGDPRCascade] Error deleting PayDaySettings: $e');
        // Continue anyway
      }

      // 8. Delete solo/data container doc
      final soloDataDoc = _firestore
          .collection('users')
          .doc(userId)
          .collection('solo')
          .doc('data');
      batch.delete(soloDataDoc);
      operationCount++;
      debugPrint('[AccountSecurity::_performGDPRCascade] Marked solo/data container for deletion');

      // 9. Note: solo container collection is automatically cleaned up by Firestore
      // when all its documents/subcollections are deleted

      // 10. Delete User Profile (last!)
      batch.delete(_firestore.doc('users/$userId'));
      operationCount++;
      debugPrint('[AccountSecurity::_performGDPRCascade] Marked user profile for deletion');

      // Final commit
      await batch.commit();
      debugPrint('[AccountSecurity::_performGDPRCascade] ✅ Cascade delete completed successfully for user: $userId');
    } catch (e) {
      debugPrint('[AccountSecurity::_performGDPRCascade] ❌ Error during cascade delete: $e');
      rethrow;
    }
  }
}
