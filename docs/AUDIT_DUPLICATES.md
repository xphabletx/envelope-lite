# Code Duplication Audit Report

**Generated:** 2025-12-24
**Purpose:** Identify duplicate logic that creates inconsistency and bugs

## Summary
Total duplications found: 3
Critical: 1
Minor: 2

---

## Critical Duplications

### 1. Account Deletion Logic - CRITICAL DUPLICATE

**Files:**
- [lib/services/auth_service.dart](lib/services/auth_service.dart) lines 97-157
- [lib/services/account_security_service.dart](lib/services/account_security_service.dart) lines 12-251

**Issue:**
Two completely different implementations of user account deletion with conflicting logic:

#### auth_service.dart::deleteAccount()
```dart
static Future<void> deleteAccount() async {
  final user = _auth.currentUser;
  if (user == null) throw Exception('No user signed in');
  final uid = user.uid;

  // NO re-authentication (security risk!)
  // NO workspace cleanup
  // NO UI confirmation dialogs
  // NO error handling for partial failures
  // WRONG PATH for scheduled_payments

  await _firestore.collection('users').doc(uid).collection('solo').doc('data').collection('envelopes').get();
  // ... deletes envelopes, groups, transactions

  await _firestore.collection('users').doc(uid).collection('scheduled_payments').get();  // WRONG PATH!

  await user.delete();  // Could leave zombie account if Firestore fails
}
```

#### account_security_service.dart::deleteAccount()
```dart
Future<bool> deleteAccount(BuildContext context) async {
  // ✓ Re-authenticates user for security
  // ✓ Shows confirmation dialog
  // ✓ Removes from workspace
  // ✓ Clears SharedPreferences
  // ✓ Comprehensive error handling
  // ✓ Prevents zombie accounts
  // ✗ WRONG PATH for scheduled_payments
  // ✗ MISSING accounts collection
  // ✗ MISSING notifications collection
  // ✗ MISSING payDaySettings

  // ... much more thorough implementation
}
```

**Comparison:**

| Feature | auth_service.dart | account_security_service.dart |
|---------|-------------------|-------------------------------|
| Re-authentication | ✗ No | ✓ Yes |
| UI Confirmation | ✗ No | ✓ Yes |
| Workspace Cleanup | ✗ No | ✓ Yes |
| SharedPrefs Cleanup | ✗ No | ✓ Yes |
| Error Handling | ✗ Minimal | ✓ Comprehensive |
| Zombie Prevention | ✗ No | ✓ Yes |
| Scheduled Payments Path | ✗ WRONG | ✗ WRONG |
| Deletes Accounts | ✗ No | ✗ No |
| Deletes Notifications | ✗ No | ✗ No |
| Deletes PayDaySettings | ✗ No | ✗ No |

**Collections Deleted by Each:**

auth_service.dart:
- ✓ Envelopes
- ✓ Groups
- ✓ Transactions
- ✗ Scheduled Payments (wrong path, won't find them)
- ✗ Accounts (MISSING)
- ✗ Notifications (MISSING)
- ✗ PayDaySettings (MISSING)
- ✓ User profile

account_security_service.dart:
- ✓ Envelopes
- ✓ Groups
- ✓ Transactions
- ✗ Scheduled Payments (wrong path, won't find them)
- ✗ Accounts (MISSING)
- ✗ Notifications (MISSING)
- ✗ PayDaySettings (MISSING)
- ✓ User profile
- ✓ Workspace membership

**Impact:**
**CRITICAL** - Two different code paths for the same critical operation. If anyone calls auth_service.deleteAccount():
- Account can be deleted WITHOUT user confirmation
- No re-authentication (security vulnerability)
- Orphaned data left in Firestore
- Workspace not cleaned up properly
- User could end up in zombie state if operation fails partway

**Where is each called?**

auth_service.dart::deleteAccount():
- ✗ NOT called anywhere in codebase (DEAD CODE!)

account_security_service.dart::deleteAccount():
- ✓ Called from [lib/screens/settings_screen.dart](lib/screens/settings_screen.dart)

**Recommendation:**

**IMMEDIATE ACTION:**
1. **DELETE** auth_service.dart::deleteAccount() entirely (lines 97-157)
2. Add a comment in its place:
```dart
// ACCOUNT DELETION
// User account deletion is handled by AccountSecurityService for security reasons.
// That service includes re-authentication, proper cascade deletes, and GDPR compliance.
//
// To delete a user account, use:
// await AccountSecurityService().deleteAccount(context);
//
// DO NOT implement account deletion here - it must go through the security service.
```

3. **FIX** account_security_service.dart::_performGDPRCascade() to:
   - Use correct path: `users/{uid}/solo/data/scheduledPayments`
   - Add missing collections: accounts, notifications, payDaySettings

**Why keep account_security_service version?**
- It's production-ready with proper security
- It's actually being used
- It has comprehensive error handling
- It prevents zombie accounts
- It handles workspace cleanup
- Just needs path fixes

**Why delete auth_service version?**
- It's not being called anywhere (dead code)
- It's missing critical security features
- It would be dangerous if someone used it
- Having two implementations creates confusion

---

## Minor Duplications

### 2. Google Sign-In Instance Creation

**Files:**
- [lib/services/auth_service.dart](lib/services/auth_service.dart):13 (class-level static)
- [lib/services/account_security_service.dart](lib/services/account_security_service.dart):157 (local instance for re-auth)

**Issue:**
account_security_service creates its own GoogleSignIn instance for re-authentication instead of using AuthService's instance.

**Code:**

auth_service.dart:
```dart
static final GoogleSignIn _google = GoogleSignIn(scopes: ['email']);

static Future<UserCredential> signInWithGoogle() async {
  final googleUser = await _google.signIn();
  // ...
}
```

account_security_service.dart:
```dart
// In _handleReauthentication method
final GoogleSignIn googleSignIn = GoogleSignIn(scopes: ['email']);
await googleSignIn.signOut();  // Force account picker
final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
```

**Impact:**
LOW - Works correctly but creates unnecessary instance. Could cause confusion about sign-in state.

**Recommendation:**
This is actually CORRECT behavior. For re-authentication, we WANT a separate instance so we can call `signOut()` to force the account picker without affecting the main signed-in state.

**Action:** KEEP AS-IS - this is intentional and correct.

---

### 3. Firestore Collection References (Pattern Duplication)

**Issue:**
Many files build the same Firestore path patterns manually instead of using helper functions.

**Example:**
```dart
// Pattern 1: Manual path construction
_firestore.collection('users').doc(userId).collection('solo').doc('data').collection('envelopes')

// Pattern 2: Helper method
CollectionReference<Envelope> _envelopesCol([String? uid]) {
  final u = uid ?? _auth.currentUser!.uid;
  return _firestore
      .collection('users')
      .doc(u)
      .collection('solo')
      .doc('data')
      .collection('envelopes')
      .withConverter<Envelope>(
        fromFirestore: (snap, _) => Envelope.fromFirestore(snap),
        toFirestore: (env, _) => env.toMap(),
      );
}
```

**Impact:**
MEDIUM - Makes code harder to maintain. If path structure changes, must update many files.

**Recommendation:**
Create a centralized FirestorePaths helper class:

```dart
class FirestorePaths {
  static const String users = 'users';
  static const String solo = 'solo';
  static const String data = 'data';

  static String userSoloData(String uid) => 'users/$uid/solo/data';

  static CollectionReference envelopes(String uid, FirebaseFirestore db) {
    return db.collection('users/$uid/solo/data/envelopes');
  }

  static CollectionReference accounts(String uid, FirebaseFirestore db) {
    return db.collection('users/$uid/solo/data/accounts');
  }

  // etc. for all collections
}
```

**Action:**
Consider implementing in a future refactor (not critical for App Store release).

---

## Recommendations Summary

### Immediate (Before Production)
1. **DELETE** auth_service.dart::deleteAccount() - it's dead code and dangerous
2. **FIX** account_security_service.dart paths

### Future Improvements
1. Create FirestorePaths helper class
2. Standardize all Firestore access patterns

---

## Verification Checklist

After implementing fixes:

- [ ] auth_service.dart::deleteAccount() is completely removed
- [ ] Comment added explaining why deletion is not in auth_service
- [ ] account_security_service.dart uses correct paths
- [ ] No other account deletion logic exists elsewhere
- [ ] Settings screen still works correctly (uses account_security_service)
- [ ] Code compiles without errors
- [ ] No references to deleted code exist

---

**Total Critical Duplications:** 1 (Account Deletion Logic)
**Action Required:** DELETE auth_service.dart::deleteAccount(), FIX account_security_service.dart paths
**Priority:** P0 - MUST FIX before production release
