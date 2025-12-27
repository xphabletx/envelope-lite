# Cascade Delete Audit

**Generated:** 2025-12-24
**Purpose:** Verify all deletion operations properly cascade to related data

---

## Summary

**Entities with Cascade Logic:** 4
- User Account Deletion
- Envelope Deletion
- Account Deletion
- Group Deletion

**Critical Issues Found:** 5
- Missing collections in user deletion
- Wrong Firestore paths in user deletion

---

## User Account Deletion

### Current Implementation
**File:** [lib/services/account_security_service.dart](lib/services/account_security_service.dart)
**Method:** `_performGDPRCascade()` (lines 183-251)
**Also:** [lib/services/auth_service.dart](lib/services/auth_service.dart):deleteAccount() (SHOULD BE DELETED - see AUDIT_DUPLICATES.md)

### What SHOULD Be Deleted

When a user deletes their account, ALL of the following must be removed to comply with GDPR and prevent orphaned data:

1. **User Data Collections:**
   - ✅ Envelopes (`users/{uid}/solo/data/envelopes`)
   - ✅ Groups (`users/{uid}/solo/data/groups`)
   - ✅ Transactions (`users/{uid}/solo/data/transactions`)
   - ❌ **Scheduled Payments** (WRONG PATH - won't actually delete)
   - ❌ **Accounts** (MISSING from cascade)
   - ❌ **Notifications** (MISSING from cascade)
   - ❌ **Pay Day Settings** (MISSING from cascade)

2. **User Profile:**
   - ✅ User document (`users/{uid}`)

3. **Workspace Cleanup:**
   - ✅ Remove user from workspace members
   - ✅ Clear workspace from SharedPreferences
   - ⚠️ Envelope registry entries (partial cleanup - see notes below)

4. **Local Storage:**
   - ✅ SharedPreferences cleared

---

### Current Implementation Analysis

#### account_security_service.dart::_performGDPRCascade()

```dart
// Lines 183-251
Future<void> _performGDPRCascade(String userId) async {
  debugPrint('[GDPR] Starting cascade delete for user: $userId');

  // Get workspace info BEFORE deleting user doc
  final userDoc = await _firestore.doc('users/$userId').get();
  String? workspaceId;
  if (userDoc.exists) {
    final userData = userDoc.data() as Map<String, dynamic>?;
    workspaceId = userData?['activeWorkspaceId'] as String?;
  }

  // Remove from workspace
  if (workspaceId != null) {
    try {
      await WorkspaceHelper.leaveWorkspace(workspaceId, userId);
      debugPrint('[GDPR] Removed user from workspace: $workspaceId');
    } catch (e) {
      debugPrint('[GDPR] Error leaving workspace: $e');
    }
  }

  // Clear SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  debugPrint('[GDPR] Cleared SharedPreferences');

  try {
    // 1. Delete Envelopes
    final envelopesSnap = await _firestore
        .collection('users/$userId/solo/data/envelopes')
        .get();
    for (var doc in envelopesSnap.docs) {
      await doc.reference.delete();
    }
    debugPrint('[GDPR] Deleted ${envelopesSnap.docs.length} envelopes');

    // 2. Delete Groups
    final groupsSnap = await _firestore
        .collection('users/$userId/solo/data/groups')
        .get();
    for (var doc in groupsSnap.docs) {
      await doc.reference.delete();
    }
    debugPrint('[GDPR] Deleted ${groupsSnap.docs.length} groups');

    // 3. Delete Transactions
    final txSnap = await _firestore
        .collection('users/$userId/solo/data/transactions')
        .get();
    for (var doc in txSnap.docs) {
      await doc.reference.delete();
    }
    debugPrint('[GDPR] Deleted ${txSnap.docs.length} transactions');

    // ❌ BUG: Wrong path for scheduled payments
    final schedSnap = await _firestore
        .collection('scheduled_payments')  // ❌ WRONG! Root collection doesn't exist
        .where('userId', isEqualTo: userId)
        .get();
    for (var doc in schedSnap.docs) {
      await doc.reference.delete();
    }
    debugPrint('[GDPR] Deleted ${schedSnap.docs.length} scheduled payments');

    // ❌ MISSING: Accounts collection not deleted at all!

    // ❌ MISSING: Notifications collection not deleted at all!

    // ❌ MISSING: Pay Day Settings not deleted at all!

    // 4. Delete User Profile (last!)
    await _firestore.doc('users/$userId').delete();
    debugPrint('[GDPR] ✅ Cascade delete completed for user: $userId');

  } catch (e) {
    debugPrint('[GDPR] ❌ Error during cascade delete: $e');
    rethrow;
  }
}
```

---

### Issues Found

#### ❌ CRITICAL ISSUE #1: Scheduled Payments - Wrong Path
**Problem:**
```dart
.collection('scheduled_payments')  // Queries root collection (doesn't exist)
.where('userId', isEqualTo: userId)
```

**Correct Path:**
```dart
.collection('users')
.doc(userId)
.collection('solo')
.doc('data')
.collection('scheduledPayments')
.get()
```

**Impact:**
- Scheduled payments are NOT deleted
- Orphaned data remains in Firestore
- GDPR violation (user data not fully removed)
- User could see old scheduled payments if they recreate account

**Fix Required:** Change to correct subcollection path

---

#### ❌ CRITICAL ISSUE #2: Accounts Collection Not Deleted
**Missing Code:**
```dart
// Should be added after transactions:
final accountsSnap = await _firestore
    .collection('users')
    .doc(userId)
    .collection('solo')
    .doc('data')
    .collection('accounts')
    .get();
for (var doc in accountsSnap.docs) {
  await doc.reference.delete();
}
debugPrint('[GDPR] Deleted ${accountsSnap.docs.length} accounts');
```

**Impact:**
- Account records remain after user deletion
- Orphaned data in Firestore
- GDPR violation

**Fix Required:** Add accounts deletion to cascade

---

#### ❌ CRITICAL ISSUE #3: Notifications Not Deleted
**Missing Code:**
```dart
// Should be added after accounts:
final notificationsSnap = await _firestore
    .collection('users')
    .doc(userId)
    .collection('notifications')
    .get();
for (var doc in notificationsSnap.docs) {
  await doc.reference.delete();
}
debugPrint('[GDPR] Deleted ${notificationsSnap.docs.length} notifications');
```

**Impact:**
- Notification records remain after user deletion
- Orphaned data in Firestore
- GDPR violation

**Fix Required:** Add notifications deletion to cascade

---

#### ❌ CRITICAL ISSUE #4: Pay Day Settings Not Deleted
**Missing Code:**
```dart
// Should be added after notifications:
// Note: Path may need to be standardized first (see AUDIT_FIRESTORE_PATHS.md)
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
    await paySettingsRef.delete();
    debugPrint('[GDPR] Deleted PayDaySettings');
  }
} catch (e) {
  debugPrint('[GDPR] Error deleting PayDaySettings: $e');
}
```

**Impact:**
- Pay day settings remain after user deletion
- Orphaned data in Firestore
- GDPR violation

**Fix Required:** Add pay day settings deletion to cascade

---

#### ⚠️ PERFORMANCE ISSUE: Sequential Deletes
**Current Pattern:**
```dart
for (var doc in envelopesSnap.docs) {
  await doc.reference.delete();  // ← Sequential, slow
}
```

**Better Pattern (using batch):**
```dart
final batch = _firestore.batch();
int count = 0;

for (var doc in envelopesSnap.docs) {
  batch.delete(doc.reference);
  count++;

  // Firestore batch limit is 500 operations
  if (count >= 450) {
    await batch.commit();
    count = 0;
  }
}

if (count > 0) {
  await batch.commit();
}
```

**Impact:**
- Slow deletion for users with many items
- More Firestore read/write operations (costs more)
- User sees longer loading times

**Fix Recommended:** Use batch writes (max 500 operations per batch)

---

#### ⚠️ PARTIAL ISSUE: Workspace Registry Cleanup
**Current Behavior:**
- Calls `WorkspaceHelper.leaveWorkspace()`
- Removes user from workspace members ✓
- Individual envelope deletions clean up their own registry entries ✓

**Potential Issue:**
If GDPR cascade fails partway through, could leave stale envelope registry entries.

**Recommendation:**
Consider adding explicit bulk cleanup:
```dart
// After leaving workspace, before deleting data:
if (workspaceId != null) {
  final registrySnap = await _firestore
      .collection('workspaces')
      .doc(workspaceId)
      .collection('registry')
      .doc('v1')
      .collection('envelopes')
      .where('userId', isEqualTo: userId)  // If userId is stored
      .get();

  for (var doc in registrySnap.docs) {
    await doc.reference.delete();
  }
}
```

**Impact:**
LOW - Envelope deletion already handles this, only an issue if deletion fails partway.

---

### Fixed Implementation Needed

See **PHASE 2: CRITICAL FIXES** in main audit instructions for complete fixed code.

**Summary of Changes Needed:**
1. Fix scheduled payments path
2. Add accounts deletion
3. Add notifications deletion
4. Add pay day settings deletion
5. Use batch writes for performance
6. Add operation count tracking (500 limit per batch)

---

## Envelope Deletion

### Current Implementation
**File:** [lib/services/envelope_repo.dart](lib/services/envelope_repo.dart)
**Method:** `deleteEnvelope()` (lines 717-764)

### What Should Be Deleted

When an envelope is deleted:
1. All transactions for that envelope
2. All scheduled payments for that envelope
3. Remove envelope from any groups (update envelopeIds array)
4. Remove from workspace registry (if in workspace)
5. The envelope document itself

---

### Implementation Analysis

```dart
Future<void> deleteEnvelope(String envelopeId) async {
  final uid = _auth.currentUser!.uid;

  // 1. Delete all transactions for this envelope
  final txSnap = await _firestore
      .collection('users')
      .doc(uid)
      .collection('solo')
      .doc('data')
      .collection('transactions')
      .where('envelopeId', isEqualTo: envelopeId)
      .get();

  for (var doc in txSnap.docs) {
    await doc.reference.delete();
  }

  // 2. Delete all scheduled payments for this envelope
  final schedSnap = await _firestore
      .collection('users')
      .doc(uid)
      .collection('solo')
      .doc('data')
      .collection('scheduledPayments')
      .where('envelopeId', isEqualTo: envelopeId)
      .get();

  for (var doc in schedSnap.docs) {
    await doc.reference.delete();
  }

  // 3. Remove envelope from any groups
  final groupsSnap = await _firestore
      .collection('users')
      .doc(uid)
      .collection('solo')
      .doc('data')
      .collection('groups')
      .where('envelopeIds', arrayContains: envelopeId)
      .get();

  for (var doc in groupsSnap.docs) {
    await doc.reference.update({
      'envelopeIds': FieldValue.arrayRemove([envelopeId]),
    });
  }

  // 4. Remove from workspace registry if applicable
  final userDoc = await _firestore.doc('users/$uid').get();
  if (userDoc.exists) {
    final userData = userDoc.data() as Map<String, dynamic>?;
    final workspaceId = userData?['activeWorkspaceId'] as String?;

    if (workspaceId != null) {
      await _firestore
          .collection('workspaces')
          .doc(workspaceId)
          .collection('registry')
          .doc('v1')
          .collection('envelopes')
          .doc(envelopeId)
          .delete();
    }
  }

  // 5. Delete the envelope itself
  await _envelopesCol().doc(envelopeId).delete();
}
```

---

### Analysis

✅ **COMPLETE** - All necessary cascades implemented correctly

**Strengths:**
- Deletes transactions ✓
- Deletes scheduled payments ✓
- Unlinks from groups ✓
- Cleans workspace registry ✓
- Proper deletion order (children first, parent last) ✓

**Could Improve:**
- Use batch writes for performance (same as user deletion)
- Add transaction to make atomic (prevent partial deletion)

**Recommendation:** Works correctly, optimization is optional for future.

---

## Account Deletion

### Current Implementation
**File:** [lib/services/account_repo.dart](lib/services/account_repo.dart)
**Method:** `deleteAccount()` (lines 164-192)

### What Should Happen

When an account (bank account) is deleted:
1. **PREVENT** deletion if any envelopes are linked to it
2. If no linked envelopes:
   - Clear defaultAccountId from PayDaySettings if this is the default
   - Delete the account document

**Note:** Accounts should NOT cascade delete envelopes - users must unlink first.

---

### Implementation Analysis

```dart
Future<void> deleteAccount(String accountId) async {
  final uid = _auth.currentUser!.uid;

  // 1. Check if any envelopes are linked to this account
  final linkedEnvelopes = await _firestore
      .collection('users')
      .doc(uid)
      .collection('solo')
      .doc('data')
      .collection('envelopes')
      .where('accountId', isEqualTo: accountId)
      .limit(1)
      .get();

  if (linkedEnvelopes.docs.isNotEmpty) {
    throw Exception(
      'Cannot delete account with linked envelopes. '
      'Please unlink all envelopes first.',
    );
  }

  // 2. Clear from PayDaySettings if it's the default account
  try {
    final paySettingsRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('payDaySettings')  // ⚠️ Path may need standardization
        .doc('settings');

    final paySettings = await paySettingsRef.get();
    if (paySettings.exists) {
      final data = paySettings.data() as Map<String, dynamic>?;
      if (data?['defaultAccountId'] == accountId) {
        await paySettingsRef.update({'defaultAccountId': null});
      }
    }
  } catch (e) {
    debugPrint('[AccountRepo] Error clearing defaultAccountId: $e');
    // Continue with deletion even if this fails
  }

  // 3. Delete the account
  await _accountsCol().doc(accountId).delete();
}
```

---

### Analysis

✅ **CORRECT APPROACH** - Prevents deletion rather than cascading

**Strengths:**
- Checks for linked envelopes ✓
- Prevents deletion if linked (correct behavior) ✓
- Clears from PayDaySettings ✓
- Good error message ✓

**Issue:**
⚠️ Uses `collection('payDaySettings')` path - may need standardization (see AUDIT_FIRESTORE_PATHS.md)

**Recommendation:**
Update payDaySettings path to match standardized path, otherwise logic is correct.

---

## Group Deletion

### Current Implementation
**File:** [lib/services/group_repo.dart](lib/services/group_repo.dart)
**Method:** `deleteGroup()` (lines 79-117)

### What Should Be Deleted

When a group (binder) is deleted:
1. All scheduled payments for that group
2. Unlink all envelopes (set groupId to null)
3. The group document itself

---

### Implementation Analysis

```dart
Future<void> deleteGroup(String groupId) async {
  final uid = _auth.currentUser!.uid;

  // 1. Delete all scheduled payments for this group
  final schedSnap = await _firestore
      .collection('users')
      .doc(uid)
      .collection('solo')
      .doc('data')
      .collection('scheduledPayments')
      .where('groupId', isEqualTo: groupId)
      .get();

  for (var doc in schedSnap.docs) {
    await doc.reference.delete();
  }

  // 2. Unlink all envelopes from this group
  final envelopesSnap = await _firestore
      .collection('users')
      .doc(uid)
      .collection('solo')
      .doc('data')
      .collection('envelopes')
      .where('groupId', isEqualTo: groupId)
      .get();

  for (var doc in envelopesSnap.docs) {
    await doc.reference.update({'groupId': null});
  }

  // 3. Delete the group itself
  await _groupsCol().doc(groupId).delete();
}
```

---

### Analysis

✅ **COMPLETE** - All necessary cascades implemented correctly

**Strengths:**
- Deletes scheduled payments ✓
- Unlinks envelopes (sets groupId to null) ✓
- Proper deletion order ✓

**Could Improve:**
- Use batch writes for performance
- Add transaction for atomicity

**Recommendation:** Works correctly, optimization is optional for future.

---

## Summary Table

| Deletion Operation | Critical Issues | Missing Cascades | Performance Issues | Status |
|-------------------|-----------------|------------------|-------------------|---------|
| **User Account** | 🔴 Wrong paths<br>🔴 Missing collections | Accounts<br>Notifications<br>PayDaySettings | Sequential deletes | ❌ **MUST FIX** |
| **Envelope** | None | None | Sequential deletes | ✅ Complete |
| **Account** | ⚠️ Path inconsistency | None | N/A | ✅ Mostly OK |
| **Group** | None | None | Sequential deletes | ✅ Complete |

---

## Required Fixes Summary

### P0 - Critical (Before Production)

1. **User Deletion: Fix Scheduled Payments Path**
   - File: account_security_service.dart:240
   - Change to: `users/{uid}/solo/data/scheduledPayments`

2. **User Deletion: Add Accounts Collection**
   - File: account_security_service.dart
   - Add deletion of `users/{uid}/solo/data/accounts`

3. **User Deletion: Add Notifications Collection**
   - File: account_security_service.dart
   - Add deletion of `users/{uid}/notifications`

4. **User Deletion: Add Pay Day Settings**
   - File: account_security_service.dart
   - Add deletion of `users/{uid}/solo/data/payDaySettings`

5. **DELETE auth_service.dart::deleteAccount()**
   - Entire method (lines 97-157)
   - See AUDIT_DUPLICATES.md

### P1 - High (Performance/Reliability)

6. **User Deletion: Use Batch Writes**
   - Replace sequential deletes with batch operations
   - Handle 500 operation limit per batch

7. **Account Deletion: Standardize PayDaySettings Path**
   - File: account_repo.dart:178
   - Update to match standardized path

---

## Verification Checklist

After implementing fixes:

**User Deletion:**
- [ ] Scheduled payments deleted (correct path)
- [ ] Accounts deleted
- [ ] Notifications deleted
- [ ] Pay day settings deleted
- [ ] Envelopes deleted
- [ ] Groups deleted
- [ ] Transactions deleted
- [ ] User profile deleted
- [ ] Workspace membership removed
- [ ] SharedPreferences cleared
- [ ] NO orphaned data remains in Firestore

**Test Each Deletion Type:**
- [ ] Create test user with all data types
- [ ] Delete user account
- [ ] Verify all collections empty in Firestore console
- [ ] Test envelope deletion (verify cascade)
- [ ] Test account deletion (verify prevention if linked)
- [ ] Test group deletion (verify cascade)

---

**Report Prepared By:** Claude Code Comprehensive Audit
**Priority:** P0 - CRITICAL - GDPR compliance required for production
**Estimated Fix Time:** 3-4 hours
