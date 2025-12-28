import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive/hive.dart';
import '../models/envelope.dart';
import '../models/account.dart';
import '../models/transaction.dart' as model;
import '../models/envelope_group.dart';
import '../models/scheduled_payment.dart';
import '../models/pay_day_settings.dart';
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
      final userData = userDoc.data();
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

    try {
      // ==========================================
      // DELETE FROM HIVE (PRIMARY STORAGE)
      // ==========================================

      debugPrint('[AccountSecurity::_performGDPRCascade] 🗑️ Deleting Hive data for user: $userId');

      // 1. Delete Envelopes
      final envelopeBox = Hive.box<Envelope>('envelopes');
      final envelopesToDelete = envelopeBox.keys
          .where((key) {
            final envelope = envelopeBox.get(key);
            return envelope != null && envelope.userId == userId;
          })
          .toList();

      for (final key in envelopesToDelete) {
        await envelopeBox.delete(key);
      }
      debugPrint('[AccountSecurity::_performGDPRCascade] ✅ Deleted ${envelopesToDelete.length} envelopes from Hive');

      // 2. Delete Accounts
      final accountBox = Hive.box<Account>('accounts');
      final accountsToDelete = accountBox.keys
          .where((key) {
            final account = accountBox.get(key);
            return account != null && account.userId == userId;
          })
          .toList();

      for (final key in accountsToDelete) {
        await accountBox.delete(key);
      }
      debugPrint('[AccountSecurity::_performGDPRCascade] ✅ Deleted ${accountsToDelete.length} accounts from Hive');

      // 3. Delete Transactions
      final transactionBox = Hive.box<model.Transaction>('transactions');
      final transactionsToDelete = transactionBox.keys
          .where((key) {
            final transaction = transactionBox.get(key);
            return transaction != null && transaction.userId == userId;
          })
          .toList();

      for (final key in transactionsToDelete) {
        await transactionBox.delete(key);
      }
      debugPrint('[AccountSecurity::_performGDPRCascade] ✅ Deleted ${transactionsToDelete.length} transactions from Hive');

      // 4. Delete Groups (Binders)
      final groupBox = Hive.box<EnvelopeGroup>('groups');
      final groupsToDelete = groupBox.keys
          .where((key) {
            final group = groupBox.get(key);
            return group != null && group.userId == userId;
          })
          .toList();

      for (final key in groupsToDelete) {
        await groupBox.delete(key);
      }
      debugPrint('[AccountSecurity::_performGDPRCascade] ✅ Deleted ${groupsToDelete.length} groups from Hive');

      // 5. Delete Scheduled Payments
      final paymentBox = Hive.box<ScheduledPayment>('scheduledPayments');
      final paymentsToDelete = paymentBox.keys
          .where((key) {
            final payment = paymentBox.get(key);
            return payment != null && payment.userId == userId;
          })
          .toList();

      for (final key in paymentsToDelete) {
        await paymentBox.delete(key);
      }
      debugPrint('[AccountSecurity::_performGDPRCascade] ✅ Deleted ${paymentsToDelete.length} scheduled payments from Hive');

      // 6. Delete Pay Day Settings
      final payDayBox = Hive.box<PayDaySettings>('payDaySettings');
      final payDayToDelete = payDayBox.keys
          .where((key) {
            final settings = payDayBox.get(key);
            return settings != null && settings.userId == userId;
          })
          .toList();

      for (final key in payDayToDelete) {
        await payDayBox.delete(key);
      }
      debugPrint('[AccountSecurity::_performGDPRCascade] ✅ Deleted ${payDayToDelete.length} pay day settings from Hive');

      // ==========================================
      // DELETE FROM FIREBASE (USER PROFILE ONLY)
      // ==========================================

      WriteBatch batch = _firestore.batch();

      // Delete notifications
      final notificationsSnap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .get();
      debugPrint('[AccountSecurity::_performGDPRCascade] Deleting ${notificationsSnap.docs.length} notifications from Firebase');
      for (var doc in notificationsSnap.docs) {
        batch.delete(doc.reference);
      }

      // Delete User Profile (last!)
      batch.delete(_firestore.doc('users/$userId'));
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
