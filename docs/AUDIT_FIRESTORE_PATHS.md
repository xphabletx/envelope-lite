# Firestore Collection Path Audit

**Generated:** 2025-12-24
**Purpose:** Document every Firestore collection path and identify inconsistencies

---

## Executive Summary

**Total Collections:** 9
**Inconsistencies Found:** 2 CRITICAL
**Correct Paths:** 7

### Critical Path Issues
1. **Scheduled Payments**: Wrong path used in 2 deletion methods
2. **Pay Day Settings**: Two different paths used across codebase

---

## Collection Path Reference

All user data is stored under the following structure:

```
users/
  {userId}/
    solo/
      data/
        envelopes/
        accounts/
        groups/
        transactions/
        scheduledPayments/
        payDaySettings/       ← Path unclear (see issues below)
    notifications/
    payDaySettings/           ← ALTERNATE PATH (inconsistent!)
      settings/

workspaces/
  {workspaceId}/
    registry/
      v1/
        envelopes/
```

---

## Per-Collection Analysis

### 1. Envelopes
**Correct Path:** `users/{userId}/solo/data/envelopes`

**Usage Audit:**

✅ **CORRECT USAGE:**
- [lib/services/envelope_repo.dart](lib/services/envelope_repo.dart):35
  ```dart
  .collection('users').doc(u).collection('solo').doc('data').collection('envelopes')
  ```
- [lib/services/account_repo.dart](lib/services/account_repo.dart):234
- [lib/services/auth_service.dart](lib/services/auth_service.dart):111
- [lib/services/account_security_service.dart](lib/services/account_security_service.dart):215
- [lib/services/data_cleanup_service.dart](lib/services/data_cleanup_service.dart):32

**Workspace Registry:**
- `workspaces/{workspaceId}/registry/v1/envelopes/{envelopeId}`
- Properly managed in [lib/services/envelope_repo.dart](lib/services/envelope_repo.dart):50-56

**Conclusion:** ✅ **CONSISTENT** - No issues found

---

### 2. Scheduled Payments
**Correct Path:** `users/{userId}/solo/data/scheduledPayments`

**Usage Audit:**

✅ **CORRECT USAGE:**
- [lib/services/scheduled_payment_repo.dart](lib/services/scheduled_payment_repo.dart):17
  ```dart
  .collection('users').doc(uid).collection('solo').doc('data').collection('scheduledPayments')
  ```
- [lib/services/envelope_repo.dart](lib/services/envelope_repo.dart):731 (deletion cascade)
- [lib/services/group_repo.dart](lib/services/group_repo.dart):88 (deletion cascade)
- [lib/services/data_cleanup_service.dart](lib/services/data_cleanup_service.dart):21

❌ **INCORRECT USAGE (CRITICAL BUGS):**

**BUG #1:** [lib/services/auth_service.dart](lib/services/auth_service.dart):137
```dart
await _firestore
    .collection('users')
    .doc(uid)
    .collection('scheduled_payments')  // ❌ WRONG PATH!
    .get();
```
**Should be:** `...doc(uid).collection('solo').doc('data').collection('scheduledPayments')`

**BUG #2:** [lib/services/account_security_service.dart](lib/services/account_security_service.dart):240
```dart
final schedSnap = await _firestore
    .collection('scheduled_payments')  // ❌ WRONG! Root collection doesn't exist
    .where('userId', isEqualTo: userId)
    .get();
```
**Should be:** `_firestore.collection('users').doc(userId).collection('solo').doc('data').collection('scheduledPayments').get()`

**Impact of Bugs:**
- Account deletion will NOT delete scheduled payments
- Orphaned scheduled payment data will remain after user deletion
- GDPR violation (user data not fully deleted)
- Users could see old scheduled payments reappear if they recreate account

**Action Required:**
1. Fix auth_service.dart:137 (or DELETE entire deleteAccount method - see AUDIT_DUPLICATES.md)
2. Fix account_security_service.dart:240

**Conclusion:** ❌ **CRITICAL INCONSISTENCY** - Must fix before production

---

### 3. Transactions
**Correct Path:** `users/{userId}/solo/data/transactions`

**Usage Audit:**

✅ **CORRECT USAGE:**
- [lib/services/envelope_repo.dart](lib/services/envelope_repo.dart):41 (deletion cascade)
  ```dart
  .collection('users').doc(uid).collection('solo').doc('data').collection('transactions')
  ```
- [lib/services/auth_service.dart](lib/services/auth_service.dart):121
- [lib/services/account_security_service.dart](lib/services/account_security_service.dart):227
- [lib/services/data_cleanup_service.dart](lib/services/data_cleanup_service.dart):50

**Conclusion:** ✅ **CONSISTENT** - No issues found

---

### 4. Groups (Binders)
**Correct Path:** `users/{userId}/solo/data/groups`

**Usage Audit:**

✅ **CORRECT USAGE:**
- [lib/services/group_repo.dart](lib/services/group_repo.dart):17
  ```dart
  .collection('users').doc(u).collection('solo').doc('data').collection('groups')
  ```
- [lib/services/envelope_repo.dart](lib/services/envelope_repo.dart):38 (for unlinking)
- [lib/services/auth_service.dart](lib/services/auth_service.dart):115
- [lib/services/account_security_service.dart](lib/services/account_security_service.dart):221
- [lib/services/data_cleanup_service.dart](lib/services/data_cleanup_service.dart):78

**Conclusion:** ✅ **CONSISTENT** - No issues found

---

### 5. Accounts
**Correct Path:** `users/{userId}/solo/data/accounts`

**Usage Audit:**

✅ **CORRECT USAGE:**
- [lib/services/account_repo.dart](lib/services/account_repo.dart):23
  ```dart
  .collection('users').doc(u).collection('solo').doc('data').collection('accounts')
  ```

❌ **MISSING FROM CASCADE DELETES:**
- [lib/services/auth_service.dart](lib/services/auth_service.dart):97-157 - NOT deleted
- [lib/services/account_security_service.dart](lib/services/account_security_service.dart):183-251 - NOT deleted

**Impact:**
- User deletion leaves orphaned account records
- GDPR violation
- Wasted Firestore storage

**Action Required:**
Add accounts deletion to both GDPR cascade methods (or just account_security_service after removing auth_service version).

**Conclusion:** ⚠️ **MISSING FROM CASCADES** - Must add to deletion logic

---

### 6. Pay Day Settings
**INCONSISTENT PATHS (CRITICAL BUG)**

**Two different paths found:**

#### Path A: `users/{userId}/payDaySettings/settings`
Used by:
- [lib/services/account_repo.dart](lib/services/account_repo.dart):178
  ```dart
  await _firestore
      .collection('users')
      .doc(uid)
      .collection('payDaySettings')
      .doc('settings')
      .update({'defaultAccountId': accountId});
  ```
- [lib/screens/onboarding/onboarding_account_setup.dart](lib/screens/onboarding/onboarding_account_setup.dart):74
  ```dart
  await FirebaseFirestore.instance
      .collection('users')
      .doc(currentUser.uid)
      .collection('payDaySettings')
      .doc('settings')
      .set({...});
  ```

#### Path B: `users/{userId}/solo/data/payDaySettings`
Used by:
- [lib/screens/pay_day/pay_day_stuffing_screen.dart](lib/screens/pay_day/pay_day_stuffing_screen.dart):128-139
  ```dart
  // Creates at path: users/{uid}/solo/data/payDaySettings (implied from structure)
  ```
- [lib/screens/budget_screen.dart](lib/screens/budget_screen.dart):147
  ```dart
  // Accesses via different pattern
  ```

**Impact:**
- Settings could be stored in TWO DIFFERENT LOCATIONS
- User sets default account → stored in `payDaySettings/settings`
- User sets pay day → stored in `solo/data/payDaySettings`
- Data split between two locations causes:
  - Settings appear to disappear
  - Some screens can't find settings created by other screens
  - User has to re-enter data
  - Confusing UX

**Recommendation:**
**STANDARDIZE TO:** `users/{userId}/solo/data/payDaySettings`
(Keep all user data under solo/data for consistency)

**Files to Fix:**
1. [lib/services/account_repo.dart](lib/services/account_repo.dart):178
2. [lib/screens/onboarding/onboarding_account_setup.dart](lib/screens/onboarding/onboarding_account_setup.dart):74
3. Verify [lib/screens/pay_day/pay_day_stuffing_screen.dart](lib/screens/pay_day/pay_day_stuffing_screen.dart) uses correct path
4. Verify [lib/screens/budget_screen.dart](lib/screens/budget_screen.dart) uses correct path

**Migration Needed:**
If any production users exist, need to migrate data from old path to new path:
```dart
// One-time migration
final oldPath = _firestore.collection('users').doc(uid).collection('payDaySettings').doc('settings');
final newPath = _firestore.collection('users').doc(uid).collection('solo').doc('data').collection('payDaySettings').doc('settings');

final oldData = await oldPath.get();
if (oldData.exists) {
  await newPath.set(oldData.data());
  await oldPath.delete();
}
```

**Conclusion:** ❌ **CRITICAL INCONSISTENCY** - Must fix before production

---

### 7. Notifications
**Correct Path:** `users/{userId}/notifications`

**Usage Audit:**

✅ **CORRECT USAGE:**
- [lib/services/notification_repo.dart](lib/services/notification_repo.dart):11
  ```dart
  .collection('users').doc(uid).collection('notifications')
  ```

❌ **MISSING FROM CASCADE DELETES:**
- Not deleted in [lib/services/auth_service.dart](lib/services/auth_service.dart):97-157
- Not deleted in [lib/services/account_security_service.dart](lib/services/account_security_service.dart):183-251

**Impact:**
- Orphaned notification data after user deletion
- GDPR violation

**Action Required:**
Add notifications deletion to GDPR cascade.

**Conclusion:** ⚠️ **MISSING FROM CASCADES** - Must add to deletion logic

---

### 8. User Profile
**Correct Path:** `users/{userId}`

**Usage Audit:**

✅ **CORRECT USAGE:**
- [lib/services/user_service.dart](lib/services/user_service.dart):13
  ```dart
  .collection('users').doc(uid)
  ```
- [lib/services/auth_service.dart](lib/services/auth_service.dart):149 (deletion)
- [lib/services/account_security_service.dart](lib/services/account_security_service.dart):247 (deletion)

**Conclusion:** ✅ **CONSISTENT** - No issues found

---

### 9. Workspaces
**Correct Path:** `workspaces/{workspaceId}`

**Sub-Collections:**
- `workspaces/{workspaceId}/members`
- `workspaces/{workspaceId}/registry/v1/envelopes`

**Usage Audit:**

✅ **CORRECT USAGE:**
- [lib/services/workspace_helper.dart](lib/services/workspace_helper.dart):62
  ```dart
  .collection('workspaces').doc(workspaceId)
  ```
- [lib/services/envelope_repo.dart](lib/services/envelope_repo.dart):50-56 (registry management)

**Cleanup on User Deletion:**
- ✅ [lib/services/account_security_service.dart](lib/services/account_security_service.dart):195-203
  - Calls WorkspaceHelper.leaveWorkspace()
  - Removes user from workspace members
  - Clears SharedPreferences

**Potential Issue:**
Individual envelope registry entries are cleaned up per-envelope, but if user deletion fails partway, could leave stale registry entries.

**Recommendation:**
Consider adding bulk cleanup of all user's envelope registry entries during GDPR cascade.

**Conclusion:** ✅ **MOSTLY CONSISTENT** - Minor improvement possible

---

## Summary Tables

### Path Consistency Matrix

| Collection | Correct Path | Consistent Usage? | Issues |
|------------|--------------|-------------------|--------|
| Envelopes | `users/{uid}/solo/data/envelopes` | ✅ Yes | None |
| Scheduled Payments | `users/{uid}/solo/data/scheduledPayments` | ❌ **NO** | **2 deletion methods use wrong path** |
| Transactions | `users/{uid}/solo/data/transactions` | ✅ Yes | None |
| Groups | `users/{uid}/solo/data/groups` | ✅ Yes | None |
| Accounts | `users/{uid}/solo/data/accounts` | ✅ Yes | Missing from cascade deletes |
| Pay Day Settings | `users/{uid}/solo/data/payDaySettings` | ❌ **NO** | **2 different paths used** |
| Notifications | `users/{uid}/notifications` | ✅ Yes | Missing from cascade deletes |
| User Profile | `users/{uid}` | ✅ Yes | None |
| Workspaces | `workspaces/{id}` | ✅ Yes | None |

---

### Cascade Delete Coverage

| Collection | Should Delete on User Deletion? | Currently Deleted? | Status |
|------------|----------------------------------|-------------------|--------|
| Envelopes | ✅ Yes | ✅ Yes | ✅ OK |
| Scheduled Payments | ✅ Yes | ❌ **No (wrong path)** | ❌ **BUG** |
| Transactions | ✅ Yes | ✅ Yes | ✅ OK |
| Groups | ✅ Yes | ✅ Yes | ✅ OK |
| Accounts | ✅ Yes | ❌ **No (missing)** | ❌ **BUG** |
| Pay Day Settings | ✅ Yes | ❌ **No (missing)** | ❌ **BUG** |
| Notifications | ✅ Yes | ❌ **No (missing)** | ❌ **BUG** |
| User Profile | ✅ Yes | ✅ Yes | ✅ OK |
| Workspace Membership | ✅ Yes | ✅ Yes | ✅ OK |

---

## Required Fixes

### P0 - Critical (Data Loss)

1. **Fix Scheduled Payments Path**
   - File: [lib/services/auth_service.dart](lib/services/auth_service.dart):137
   - Change: `collection('scheduled_payments')` → `collection('solo').doc('data').collection('scheduledPayments')`
   - OR: Delete entire deleteAccount method (see AUDIT_DUPLICATES.md)

2. **Fix Scheduled Payments Path #2**
   - File: [lib/services/account_security_service.dart](lib/services/account_security_service.dart):240
   - Change: Use correct subcollection path instead of root collection query

3. **Standardize Pay Day Settings Path**
   - Files:
     - [lib/services/account_repo.dart](lib/services/account_repo.dart):178
     - [lib/screens/onboarding/onboarding_account_setup.dart](lib/screens/onboarding/onboarding_account_setup.dart):74
   - Change: Use `users/{uid}/solo/data/payDaySettings` everywhere
   - Add migration for existing users

### P1 - High (GDPR Compliance)

4. **Add Accounts to Cascade Delete**
   - File: [lib/services/account_security_service.dart](lib/services/account_security_service.dart):183-251
   - Add: Delete `users/{uid}/solo/data/accounts` collection

5. **Add Notifications to Cascade Delete**
   - File: [lib/services/account_security_service.dart](lib/services/account_security_service.dart):183-251
   - Add: Delete `users/{uid}/notifications` collection

6. **Add Pay Day Settings to Cascade Delete**
   - File: [lib/services/account_security_service.dart](lib/services/account_security_service.dart):183-251
   - Add: Delete `users/{uid}/solo/data/payDaySettings` collection

---

## Verification Checklist

After implementing fixes:

**Path Consistency:**
- [ ] All scheduled payments access uses `users/{uid}/solo/data/scheduledPayments`
- [ ] All pay day settings access uses `users/{uid}/solo/data/payDaySettings`
- [ ] No references to old paths remain

**Cascade Delete Completeness:**
- [ ] Scheduled payments deleted (with correct path)
- [ ] Accounts deleted
- [ ] Notifications deleted
- [ ] Pay day settings deleted
- [ ] Test user deletion leaves NO orphaned data

**Migration:**
- [ ] Pay day settings migration script created (if production users exist)
- [ ] Migration tested on dev environment
- [ ] Migration documented in CHANGELOG.md

---

**Report Prepared By:** Claude Code Comprehensive Audit
**Priority:** P0 - CRITICAL - Must fix before production release
**Estimated Fix Time:** 2-3 hours
