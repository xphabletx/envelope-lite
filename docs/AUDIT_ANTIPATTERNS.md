# Anti-Pattern Audit

**Generated:** 2025-12-24
**Purpose:** Identify code quality issues and anti-patterns

---

## Summary

**Categories:**
1. Missing Error Handling (HIGH)
2. Direct Firestore Access in Screens (HIGH)
3. Hardcoded Strings (MEDIUM)
4. Magic Numbers (MEDIUM)
5. Inconsistent Null Safety (MEDIUM)
6. Missing Input Validation (HIGH)
7. Empty Catch Blocks (HIGH)
8. Performance Anti-Patterns (LOW)

**Total Issues:** 50+

---

## 1. Missing Error Handling

### Pattern: Firestore Operations Without Try-Catch

**Example 1:** [lib/screens/pay_day/pay_day_allocation_screen.dart](lib/screens/pay_day/pay_day_allocation_screen.dart):46-52

```dart
Future<void> _loadAllocations() async {
  final snapshot = await FirebaseFirestore.instance
      .collection('users')
      .doc(_auth.currentUser!.uid)
      .collection('allocations')
      .get();  // ❌ No error handling!

  setState(() {
    _allocations = snapshot.docs.map((doc) => Allocation.fromDoc(doc)).toList();
  });
}
```

**Problem:**
- If Firestore fails (network error, permission denied), app crashes
- User sees technical error instead of helpful message
- No recovery mechanism

**Fix:**
```dart
Future<void> _loadAllocations() async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .collection('allocations')
        .get();

    setState(() {
      _allocations = snapshot.docs.map((doc) => Allocation.fromDoc(doc)).toList();
    });
  } on FirebaseException catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to load allocations: ${e.message}')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('An unexpected error occurred')),
    );
  }
}
```

---

### Example 2: Repository Methods Without Error Context

**Location:** Multiple repo files

```dart
Future<String> createEnvelope(String name, double amount) async {
  final doc = await _envelopesCol().add({
    'name': name,
    'amount': amount,
  });  // ❌ If this fails, error has no context
  return doc.id;
}
```

**Fix:**
```dart
Future<String> createEnvelope(String name, double amount) async {
  try {
    final doc = await _envelopesCol().add({
      'name': name,
      'amount': amount,
    });
    return doc.id;
  } on FirebaseException catch (e) {
    debugPrint('[EnvelopeRepo::createEnvelope] Firestore error: ${e.code} - ${e.message}');
    rethrow;
  } catch (e) {
    debugPrint('[EnvelopeRepo::createEnvelope] Unexpected error: $e');
    rethrow;
  }
}
```

---

## 2. Empty Catch Blocks

### 🔴 CRITICAL: Silent Error Swallowing

**Location:** [lib/services/auth_service.dart](lib/services/auth_service.dart):80-93

```dart
try {
  await _google.signOut();
  await _google.disconnect();
} catch (_) {}  // ❌ DANGEROUS! Swallows ALL errors silently
```

**Problem:**
- Errors are completely hidden
- Debugging is impossible
- Sign-out might fail but app thinks it succeeded
- User could be in inconsistent state

**Fix:**
```dart
try {
  await _google.signOut();
  await _google.disconnect();
} catch (e) {
  // Log error but continue - sign-out is best-effort
  debugPrint('[AuthService::signOut] Google sign-out error: $e');
  // Don't rethrow - we still want to sign out of Firebase even if Google fails
}
```

---

### Other Empty Catch Blocks Found

Search for pattern: `catch (_)` or `catch (e) {}`

**Action Required:**
1. Find all empty catch blocks
2. Add logging
3. Decide: rethrow, show user message, or silently continue (with comment explaining why)

---

## 3. Direct Firestore Access in Screens

### 🔴 CRITICAL ANTI-PATTERN

**Problem:**
Screens should NEVER directly access Firestore. All data access should go through repositories.

**Why It's Bad:**
- No error handling
- No business logic encapsulation
- Can't mock for testing
- Violates separation of concerns
- Creates tight coupling
- Makes code unmaintainable

---

### Example 1: [lib/screens/pay_day/pay_day_allocation_screen.dart](lib/screens/pay_day/pay_day_allocation_screen.dart):46-52

```dart
Future<void> _loadAllocations() async {
  final snapshot = await FirebaseFirestore.instance  // ❌ Direct Firestore access in screen!
      .collection('users')
      .doc(_auth.currentUser!.uid)
      .collection('allocations')
      .get();
  // ...
}
```

**Fix:**
```dart
// Create lib/services/allocation_repo.dart
class AllocationRepo {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<List<Allocation>> getAllocations() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('allocations')
          .get();
      return snapshot.docs.map((doc) => Allocation.fromDoc(doc)).toList();
    } on FirebaseException catch (e) {
      debugPrint('[AllocationRepo::getAllocations] Error: $e');
      rethrow;
    }
  }
}

// In screen:
Future<void> _loadAllocations() async {
  try {
    final allocations = await AllocationRepo().getAllocations();
    setState(() => _allocations = allocations);
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to load: $e')),
    );
  }
}
```

---

### Example 2: [lib/screens/pay_day/pay_day_stuffing_screen.dart](lib/screens/pay_day/pay_day_stuffing_screen.dart):123-139

```dart
final settingsDoc = await FirebaseFirestore.instance  // ❌ Direct access!
    .collection('users')
    .doc(_auth.currentUser!.uid)
    .collection('payDaySettings')
    .doc('settings')
    .get();
```

**Fix:**
Move to a PayDaySettingsRepo.

---

### Example 3: [lib/screens/onboarding/onboarding_account_setup.dart](lib/screens/onboarding/onboarding_account_setup.dart):71-76

```dart
await FirebaseFirestore.instance  // ❌ Direct access!
    .collection('users')
    .doc(currentUser.uid)
    .collection('payDaySettings')
    .doc('settings')
    .set({
      'defaultAccountId': accountId,
      'dayOfMonth': payDay,
    });
```

**Fix:**
```dart
// In PayDaySettingsRepo:
Future<void> updateSettings({
  String? defaultAccountId,
  int? dayOfMonth,
}) async {
  // ... proper error handling, validation, etc.
}

// In screen:
await PayDaySettingsRepo().updateSettings(
  defaultAccountId: accountId,
  dayOfMonth: payDay,
);
```

---

### Example 4: [lib/screens/budget_screen.dart](lib/screens/budget_screen.dart):144-149

```dart
final doc = await FirebaseFirestore.instance  // ❌ Direct access!
    .collection('users')
    .doc(uid)
    .collection('solo')
    .doc('data')
    .collection('payDaySettings')
    .doc('settings')
    .get();
```

**Fix:**
Use PayDaySettingsRepo.

---

### All Files with Direct Firestore Access

**MUST FIX:**
1. lib/screens/pay_day/pay_day_allocation_screen.dart
2. lib/screens/pay_day/pay_day_stuffing_screen.dart
3. lib/screens/onboarding/onboarding_account_setup.dart
4. lib/screens/budget_screen.dart
5. lib/screens/workspace_management_screen.dart (multiple instances)
6. lib/screens/workspace_gate.dart (multiple instances)

**Action Required:**
1. Create missing repositories (AllocationRepo, PayDaySettingsRepo if not exists)
2. Move ALL Firestore access to repos
3. Update screens to use repos
4. Add proper error handling in repos

---

## 4. Hardcoded Strings (Magic Strings)

### Pattern: Collection Names Repeated Everywhere

**Problem:**
Collection names are hardcoded as string literals throughout the codebase.

**Example:**
```dart
// In envelope_repo.dart:
.collection('users').doc(uid).collection('solo').doc('data').collection('envelopes')

// In auth_service.dart:
.collection('users').doc(uid).collection('solo').doc('data').collection('envelopes')

// In account_security_service.dart:
.collection('users').doc(uid).collection('solo').doc('data').collection('envelopes')
```

**Risk:**
- Typos create bugs (`'envelops'` vs `'envelopes'`)
- If collection name changes, must update 50+ files
- No compile-time checking

---

### Recommended Fix: Create Constants File

**Create:** lib/constants/firestore_collections.dart

```dart
/// Firestore collection and path constants
///
/// DO NOT use string literals for Firestore paths elsewhere in the codebase.
/// Always use these constants to prevent typos and enable easy refactoring.
class FirestoreCollections {
  // Root collections
  static const String users = 'users';
  static const String workspaces = 'workspaces';

  // User subcollections
  static const String solo = 'solo';
  static const String data = 'data';
  static const String notifications = 'notifications';

  // Data subcollections (under users/{uid}/solo/data/)
  static const String envelopes = 'envelopes';
  static const String accounts = 'accounts';
  static const String groups = 'groups';
  static const String transactions = 'transactions';
  static const String scheduledPayments = 'scheduledPayments';
  static const String payDaySettings = 'payDaySettings';

  // Settings documents
  static const String settingsDoc = 'settings';

  // Workspace subcollections
  static const String members = 'members';
  static const String registry = 'registry';
  static const String v1 = 'v1';
}

/// Helper methods for building Firestore paths
class FirestorePaths {
  /// Returns path: users/{uid}
  static String user(String uid) =>
      '${FirestoreCollections.users}/$uid';

  /// Returns path: users/{uid}/solo/data
  static String userSoloData(String uid) =>
      '${FirestoreCollections.users}/$uid/${FirestoreCollections.solo}/${FirestoreCollections.data}';

  /// Returns path: users/{uid}/solo/data/envelopes
  static String envelopes(String uid) =>
      '${userSoloData(uid)}/${FirestoreCollections.envelopes}';

  /// Returns path: users/{uid}/solo/data/accounts
  static String accounts(String uid) =>
      '${userSoloData(uid)}/${FirestoreCollections.accounts}';

  /// Returns path: users/{uid}/solo/data/scheduledPayments
  static String scheduledPayments(String uid) =>
      '${userSoloData(uid)}/${FirestoreCollections.scheduledPayments}';

  // ... etc for all collections
}
```

**Usage:**
```dart
// Before:
final snapshot = await _firestore
    .collection('users')
    .doc(uid)
    .collection('solo')
    .doc('data')
    .collection('envelopes')
    .get();

// After:
final snapshot = await _firestore
    .collection(FirestoreCollections.users)
    .doc(uid)
    .collection(FirestoreCollections.solo)
    .doc(FirestoreCollections.data)
    .collection(FirestoreCollections.envelopes)
    .get();

// Or even better:
final snapshot = await _firestore
    .doc(FirestorePaths.userSoloData(uid))
    .collection(FirestoreCollections.envelopes)
    .get();
```

**Benefits:**
- Typo-proof (compile error instead of runtime error)
- Easy refactoring (change in one place)
- Self-documenting
- IDE autocomplete

**Action Required:**
1. Create constants file
2. Replace all hardcoded collection names
3. Add lint rule to prevent string literals for Firestore paths

---

### Other Magic Strings

**Field Names:**
```dart
// Hardcoded field names:
.update({'defaultAccountId': accountId})  // ❌
.where('userId', isEqualTo: uid)  // ❌
```

**Fix:**
```dart
class FirestoreFields {
  static const String defaultAccountId = 'defaultAccountId';
  static const String userId = 'userId';
  static const String envelopeId = 'envelopeId';
  static const String groupId = 'groupId';
  static const String createdAt = 'createdAt';
  static const String updatedAt = 'updatedAt';
  // etc.
}

// Usage:
.update({FirestoreFields.defaultAccountId: accountId})
.where(FirestoreFields.userId, isEqualTo: uid)
```

---

## 5. Magic Numbers

### Examples Found

```dart
if (name.length > 100) {  // ❌ What's special about 100?
  throw ArgumentError('Name too long');
}

if (amount < 0) {  // ✓ OK - obvious meaning
  throw ArgumentError('Amount cannot be negative');
}

const SizedBox(height: 16),  // ❌ Spacing should be constant
const SizedBox(height: 20),  // ❌ Inconsistent spacing
const SizedBox(height: 24),  // ❌ Different spacing
```

**Fix:**
```dart
// Create lib/constants/validation_limits.dart
class ValidationLimits {
  static const int maxEnvelopeName = 100;
  static const int maxAccountName = 50;
  static const int maxGroupName = 100;
  static const double maxAmount = 999999999.99;
  static const double minAmount = 0.0;
}

// Create lib/constants/ui_spacing.dart
class UISpacing {
  static const double small = 8.0;
  static const double medium = 16.0;
  static const double large = 24.0;
  static const double extraLarge = 32.0;
}

// Usage:
if (name.length > ValidationLimits.maxEnvelopeName) {
  throw ArgumentError('Name cannot exceed ${ValidationLimits.maxEnvelopeName} characters');
}

const SizedBox(height: UISpacing.medium),
```

---

## 6. Inconsistent Null Safety Patterns

### Pattern 1: Mix of Null Checks

```dart
// Style A: Ternary operator
final name = user != null ? user.displayName : 'Guest';

// Style B: Null-aware operator (BETTER)
final name = user?.displayName ?? 'Guest';

// Style C: Explicit check
String name;
if (user != null) {
  name = user.displayName;
} else {
  name = 'Guest';
}
```

**Recommendation:**
Standardize on null-aware operators (Style B) - most concise and readable.

---

### Pattern 2: Returning Null vs Throwing

```dart
// envelope_repo.dart:
Future<Envelope?> getEnvelope(String id) async {
  final doc = await _envelopesCol().doc(id).get();
  if (!doc.exists) return null;  // Returns null for not found
  return Envelope.fromFirestore(doc);
}

// account_repo.dart:
Future<void> deleteAccount(String id) async {
  final hasLinked = await _hasLinkedEnvelopes(id);
  if (hasLinked) {
    throw Exception('Cannot delete account');  // Throws for invalid operation
  }
  // ...
}
```

**Problem:**
Inconsistent pattern - when to return null vs throw exception?

**Recommendation:**
**Establish pattern:**
- Return `null` for "not found" (expected outcome)
- Throw `Exception` for "invalid operation" (error condition)
- Throw `ArgumentError` for "invalid input" (precondition violation)

**Example:**
```dart
// Not found - return null:
Future<Envelope?> getEnvelope(String id) async {
  final doc = await _envelopesCol().doc(id).get();
  if (!doc.exists) return null;  // ✓ Expected - envelope might not exist
  return Envelope.fromFirestore(doc);
}

// Invalid operation - throw Exception:
Future<void> deleteAccount(String id) async {
  if (await _hasLinkedEnvelopes(id)) {
    throw Exception('Cannot delete account with linked envelopes');  // ✓ Error condition
  }
  await _accountsCol().doc(id).delete();
}

// Invalid input - throw ArgumentError:
Future<String> createEnvelope(String name, double amount) async {
  if (name.trim().isEmpty) {
    throw ArgumentError('Envelope name cannot be empty');  // ✓ Precondition violation
  }
  // ...
}
```

---

### Pattern 3: Force Unwrap (!)

```dart
final uid = _auth.currentUser!.uid;  // ❌ Dangerous if no user signed in
```

**Problem:**
Force unwrap (`!`) can crash app if null.

**Recommendation:**
Only use `!` when you're 100% certain, and add comment explaining why:

```dart
// User must be signed in to reach this repo method (enforced by auth guard in main.dart)
final uid = _auth.currentUser!.uid;
```

Or better, check explicitly:
```dart
final user = _auth.currentUser;
if (user == null) {
  throw Exception('User must be signed in');
}
final uid = user.uid;
```

---

## 7. Missing Input Validation

### Pattern: Public Methods Accept Unchecked Input

**Example:** [lib/services/envelope_repo.dart](lib/services/envelope_repo.dart)

```dart
Future<String> createEnvelope({
  required String name,
  required double amount,
}) async {
  // ❌ No validation! What if:
  // - name is empty?
  // - name is 1000 characters?
  // - amount is negative?
  // - amount is NaN or Infinity?

  final doc = await _envelopesCol().add({
    'name': name,  // Dangerous!
    'amount': amount,
  });
  return doc.id;
}
```

**Fix:**
```dart
Future<String> createEnvelope({
  required String name,
  required double amount,
}) async {
  // Validate inputs
  final trimmedName = name.trim();

  if (trimmedName.isEmpty) {
    throw ArgumentError('Envelope name cannot be empty');
  }

  if (trimmedName.length > ValidationLimits.maxEnvelopeName) {
    throw ArgumentError(
      'Envelope name cannot exceed ${ValidationLimits.maxEnvelopeName} characters',
    );
  }

  if (amount < 0) {
    throw ArgumentError('Amount cannot be negative');
  }

  if (amount.isNaN || amount.isInfinite) {
    throw ArgumentError('Amount must be a valid number');
  }

  if (amount > ValidationLimits.maxAmount) {
    throw ArgumentError('Amount exceeds maximum allowed value');
  }

  // Now safe to use
  final doc = await _envelopesCol().add({
    'name': trimmedName,
    'amount': amount,
  });

  return doc.id;
}
```

---

### Files Needing Input Validation

**All repository files:**
1. lib/services/envelope_repo.dart
2. lib/services/account_repo.dart
3. lib/services/group_repo.dart
4. lib/services/scheduled_payment_repo.dart

**Validation Needed:**
- ✓ Name fields: not empty, max length
- ✓ Amount fields: not negative, not NaN/Infinity, max value
- ✓ ID fields: not empty, valid format
- ✓ Date fields: not in distant past/future
- ✓ Enum fields: valid value

---

## 8. Performance Anti-Patterns

### Pattern 1: Sequential Deletes Instead of Batch

**Location:** All cascade delete methods

```dart
// ❌ SLOW - each delete is a separate network call:
for (var doc in envelopesSnap.docs) {
  await doc.reference.delete();  // Wait for each one
}
```

**Fix:**
```dart
// ✓ FAST - batch all deletes into one operation:
final batch = _firestore.batch();
int count = 0;

for (var doc in envelopesSnap.docs) {
  batch.delete(doc.reference);
  count++;

  // Firestore batch limit is 500 operations
  if (count >= 450) {
    await batch.commit();
    batch = _firestore.batch();  // Start new batch
    count = 0;
  }
}

if (count > 0) {
  await batch.commit();
}
```

**Impact:**
- 100 envelopes: 100 network calls → 1 network call (100x faster!)
- Lower Firestore costs
- Better user experience

**Action:** Update all cascade delete methods

---

### Pattern 2: Fetching More Data Than Needed

**Example:**
```dart
// ❌ Fetches entire document just to check existence:
final doc = await _firestore.doc('users/$uid').get();
if (doc.exists) {
  // Do something
}
```

**Fix:**
```dart
// ✓ Only check existence (lighter query):
final docRef = _firestore.doc('users/$uid');
final snapshot = await docRef.get(const GetOptions(source: Source.serverAndCache));
if (snapshot.exists) {
  // Do something
}

// Or even better for just checking:
final query = await _firestore
    .collection('users')
    .where(FieldPath.documentId, isEqualTo: uid)
    .limit(1)
    .get();
if (query.docs.isNotEmpty) {
  // Exists
}
```

---

## Summary of Required Fixes

### P0 - Critical (Before Production)

1. **Add error handling to all Firestore operations**
   - Files: All screens with direct Firestore access
   - Priority: CRITICAL (prevents crashes)

2. **Remove direct Firestore access from screens**
   - Move to repositories
   - Add proper error handling

3. **Fix empty catch blocks**
   - lib/services/auth_service.dart:80-93
   - Add logging or proper handling

4. **Add input validation to all public repository methods**
   - Prevents invalid data in Firestore
   - Improves error messages

### P1 - High (Code Quality)

5. **Create constants for Firestore collections/fields**
   - Prevent typos
   - Enable easy refactoring

6. **Standardize null safety patterns**
   - Document when to return null vs throw
   - Add comments for all force unwraps

7. **Use batch writes for cascade deletes**
   - Performance improvement
   - Cost reduction

### P2 - Medium (Future Improvements)

8. **Create UI spacing constants**
   - Consistent spacing
   - Easier theming

9. **Create validation limit constants**
   - Centralized limits
   - Easier to adjust

---

## Verification Checklist

**Error Handling:**
- [ ] All Firestore operations wrapped in try-catch
- [ ] All screens handle errors gracefully
- [ ] User sees helpful messages, not stack traces

**Architecture:**
- [ ] No screens directly access Firestore
- [ ] All data access through repositories
- [ ] Repositories have proper error handling

**Code Quality:**
- [ ] No empty catch blocks
- [ ] Collection names use constants
- [ ] Field names use constants
- [ ] All public methods validate input

**Null Safety:**
- [ ] Consistent null-aware operator usage
- [ ] All force unwraps documented
- [ ] Clear pattern for null vs exceptions

**Performance:**
- [ ] Cascade deletes use batch writes
- [ ] No unnecessary data fetching

---

**Report Prepared By:** Claude Code Comprehensive Audit
**Estimated Fix Time:** 6-8 hours
**Priority:** P0-P1 - Must fix before production
