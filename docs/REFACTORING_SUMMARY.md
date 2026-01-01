# Local-First Architecture Refactoring - Implementation Guide

## 🎯 Objective
Eliminate UI lag by implementing a Hive-first, local-optimized data layer with background Firebase sync and multi-device support.

---

## ✅ COMPLETED INFRASTRUCTURE

### 1. **Model Updates** (✓ Complete)

#### Files Modified:
- [`lib/models/envelope.dart`](lib/models/envelope.dart:82-86)
- [`lib/models/account.dart`](lib/models/account.dart:77-78)
- [`lib/models/transaction.dart`](lib/models/transaction.dart:86-90)

#### Changes:
```dart
// Added to all models
@HiveField(25) // or appropriate field number
final bool isSynced;

@HiveField(26)
final DateTime lastUpdated;
```

#### Purpose:
- `isSynced`: Track which items need Firebase sync
- `lastUpdated`: Timestamp for conflict resolution

---

### 2. **SyncManager Service** (✓ Complete)

#### File: [`lib/services/sync_manager.dart`](lib/services/sync_manager.dart)

#### Features:
- ✅ **Singleton pattern** for global access
- ✅ **Queue-based sync** to prevent Firebase throttling
- ✅ **isFuture filter** to prevent syncing TimeMachine projections
- ✅ **Non-blocking** fire-and-forget operations
- ✅ **Workspace-aware** (only syncs in workspace mode)

#### Key Methods:
```dart
final syncManager = SyncManager();

// Envelopes
syncManager.pushEnvelope(envelope, workspaceId);
syncManager.deleteEnvelope(envelopeId, workspaceId);

// Transactions (only partner transfers)
syncManager.pushTransaction(transaction, workspaceId, isPartnerTransfer: true);
syncManager.deleteTransaction(transactionId, workspaceId, isPartnerTransfer: true);
```

#### Critical Protection:
```dart
// NEVER syncs projected transactions from TimeMachine
if (transaction.isFuture) {
  debugPrint('[SyncManager] ⚠️ Skipping future transaction (projection)');
  return;
}
```

---

### 3. **CloudMigrationService** (✓ Complete)

#### File: [`lib/services/cloud_migration_service.dart`](lib/services/cloud_migration_service.dart)

#### Features:
- ✅ **Bulk operations** using `box.putAll()` for performance
- ✅ **Progress tracking** via StreamController
- ✅ **User mismatch detection** (GDPR compliance)
- ✅ **Auto-cleanup** on user switch
- ✅ **Error resilience** (continues even if migration fails)

#### Usage:
```dart
final migrationService = CloudMigrationService();

// Get progress stream for UI
Stream<MigrationProgress> progressStream = migrationService.progressStream;

// Trigger migration on login
final migrated = await migrationService.migrateIfNeeded(
  userId: currentUser.uid,
  workspaceId: workspaceId,
);
```

#### Flow:
1. Check for user mismatch → Clear data if different user
2. Check if Hive boxes empty → Skip if already populated
3. Fetch from Firebase (accounts → envelopes → transactions)
4. Bulk insert using `putAll()` (O(1) performance)
5. Emit progress updates throughout

---

### 4. **Migration UI Overlay** (✓ Complete)

#### File: [`lib/widgets/migration_overlay.dart`](lib/widgets/migration_overlay.dart)

#### Features:
- ✅ **Blocking overlay** prevents app access during migration
- ✅ **Progress indicator** with percentage and step description
- ✅ **Error handling** with retry option
- ✅ **Completion screen** with success message

#### Usage:
```dart
// In your auth gate or home screen
StreamBuilder<MigrationProgress>(
  stream: migrationService.progressStream,
  builder: (context, snapshot) {
    if (snapshot.hasData && !snapshot.data!.isComplete) {
      return RestorationOverlay(
        progressStream: migrationService.progressStream,
        onCancel: () => Navigator.of(context).pop(),
      );
    }
    return YourHomeScreen();
  },
)
```

---

### 5. **Synchronous Data Access Methods** (✓ Complete)

#### Files Modified:
- [`lib/services/envelope_repo.dart`](lib/services/envelope_repo.dart:206-251)
- [`lib/services/account_repo.dart`](lib/services/account_repo.dart:86-107)

#### EnvelopeRepo Methods:
```dart
// Instant access to Hive data (no await, no streams)
List<Envelope> getEnvelopesSync({bool showPartnerEnvelopes = true});
Envelope? getEnvelopeSync(String id);
List<Transaction> getTransactionsSync();
List<Transaction> getTransactionsForEnvelopeSync(String envelopeId);
List<EnvelopeGroup> getGroupsSync();
```

#### AccountRepo Methods:
```dart
List<Account> getAccountsSync();
Account? getAccountSync(String accountId);
Account? getDefaultAccountSync();
```

---

## 📋 NEXT STEPS (Implementation Guide)

### Step 1: Integrate SyncManager into Repository Write Operations

**Priority**: 🔴 **CRITICAL** (eliminates lag)

**Pattern to implement** in all write methods (deposit, withdraw, transfer, etc.):

```dart
// In EnvelopeRepo
final _syncManager = SyncManager();

Future<void> deposit({
  required String envelopeId,
  required double amount,
  String description = '',
}) async {
  // 1. Get current envelope
  final envelope = _envelopeBox.get(envelopeId);
  if (envelope == null) throw Exception('Envelope not found');

  // 2. Update Hive IMMEDIATELY (instant UI update)
  final updatedEnvelope = envelope.copyWith(
    currentAmount: envelope.currentAmount + amount,
    isSynced: false, // Mark as pending sync
    lastUpdated: DateTime.now(),
  );
  await _envelopeBox.put(envelopeId, updatedEnvelope);

  // 3. Create transaction in Hive
  final transaction = Transaction(
    id: generateId(),
    envelopeId: envelopeId,
    type: TransactionType.deposit,
    amount: amount,
    date: DateTime.now(),
    description: description,
    userId: _userId,
    isSynced: false,
    lastUpdated: DateTime.now(),
  );
  await _transactionBox.put(transaction.id, transaction);

  // 4. Background sync (fire-and-forget, non-blocking)
  _syncManager.pushEnvelope(updatedEnvelope, _workspaceId);

  // Note: Transaction sync only if partner transfer
  // Regular deposits don't sync
}
```

**Files to update**:
- `lib/services/envelope_repo.dart`: deposit(), withdraw(), transfer(), createEnvelope(), updateEnvelope(), deleteEnvelope()
- `lib/services/account_repo.dart`: All write methods

---

### Step 2: Update UI Screens to Use Sync Methods with initialData

**Priority**: 🔴 **CRITICAL** (eliminates loading spinners)

**Before** (laggy):
```dart
// lib/screens/home_screen.dart
StreamBuilder<List<Envelope>>(
  stream: envelopeRepo.envelopesStream(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) {
      return Center(child: CircularProgressIndicator()); // ❌ Shows spinner!
    }
    final envelopes = snapshot.data!;
    return EnvelopeList(envelopes: envelopes);
  },
)
```

**After** (instant):
```dart
StreamBuilder<List<Envelope>>(
  initialData: envelopeRepo.getEnvelopesSync(), // ✅ Instant data!
  stream: envelopeRepo.envelopesStream(),
  builder: (context, snapshot) {
    final envelopes = snapshot.data ?? [];
    return EnvelopeList(envelopes: envelopes);
  },
)
```

**Files to update**:
- `lib/screens/home_screen.dart`
- `lib/screens/envelope/envelopes_detail_screen.dart`
- `lib/screens/account_detail_screen.dart`
- `lib/screens/stats_history_screen.dart`
- Any other screen using StreamBuilder with envelope/account/transaction data

---

### Step 3: Add Migration Overlay to Auth Flow

**Priority**: 🟠 **HIGH** (enables multi-device)

**Integration point**: `lib/screens/auth_gate.dart` or wherever you handle post-login navigation

```dart
class AuthGate extends StatefulWidget {
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _migrationService = CloudMigrationService();
  bool _migrationChecked = false;

  @override
  void dispose() {
    _migrationService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        // Not logged in
        if (!authSnapshot.hasData) {
          return LoginScreen();
        }

        final user = authSnapshot.data!;

        // Logged in - check if migration needed
        if (!_migrationChecked) {
          _checkMigration(user);
        }

        // Show migration overlay if in progress
        return StreamBuilder<MigrationProgress>(
          stream: _migrationService.progressStream,
          builder: (context, progressSnapshot) {
            final progress = progressSnapshot.data;

            // Migration in progress or not started
            if (progress != null && !progress.isComplete) {
              return RestorationOverlay(
                progressStream: _migrationService.progressStream,
                onCancel: () {
                  // Allow user to continue offline
                  setState(() => _migrationChecked = true);
                },
              );
            }

            // Migration complete or not needed
            return HomeScreen();
          },
        );
      },
    );
  }

  Future<void> _checkMigration(User user) async {
    setState(() => _migrationChecked = true);

    // Get workspace ID from user preferences or state
    final workspaceId = await _getWorkspaceId();

    // Trigger migration
    await _migrationService.migrateIfNeeded(
      userId: user.uid,
      workspaceId: workspaceId,
    );
  }

  Future<String?> _getWorkspaceId() async {
    // Implement based on your app's workspace logic
    // Could be from SharedPreferences, Firestore, or user state
    return null; // Replace with actual implementation
  }
}
```

---

### Step 4: Implement Data Cleanup on Logout/Delete Account

**Priority**: 🟠 **HIGH** (GDPR compliance)

**Files to update**: `lib/services/auth_service.dart` or wherever you handle auth

```dart
import 'package:hive/hive.dart';
import '../models/envelope.dart';
import '../models/account.dart';
import '../models/transaction.dart' as model;

class AuthService {
  Future<void> signOut() async {
    // 1. Clear all Hive data
    await _clearAllLocalData();

    // 2. Clear SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // 3. Sign out from Firebase
    await FirebaseAuth.instance.signOut();
  }

  Future<void> deleteAccount() async {
    // 1. Delete from Firebase (optional - implement based on your backend)
    // await _deleteUserDataFromFirebase();

    // 2. Clear all local data (GDPR requirement)
    await _clearAllLocalData();

    // 3. Clear preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // 4. Delete Firebase Auth account
    await FirebaseAuth.instance.currentUser?.delete();
  }

  Future<void> _clearAllLocalData() async {
    try {
      final envelopeBox = await Hive.openBox<Envelope>('envelopes');
      final accountBox = await Hive.openBox<Account>('accounts');
      final transactionBox = await Hive.openBox<model.Transaction>('transactions');

      await Future.wait([
        envelopeBox.clear(),
        accountBox.clear(),
        transactionBox.clear(),
      ]);

      debugPrint('[AuthService] ✓ All local data cleared');
    } catch (e) {
      debugPrint('[AuthService] ✗ Failed to clear local data: $e');
      rethrow; // Important for GDPR compliance
    }
  }
}
```

---

### Step 5: Add Projection Service Memoization

**Priority**: 🟡 **MEDIUM** (performance optimization)

**File**: `lib/services/projection_service.dart`

**Current issue**: Time Machine recalculates projections on every call, even with identical inputs.

**Solution**: Add memoization cache

```dart
import 'dart:convert';
import 'package:crypto/crypto.dart';

class ProjectionService {
  // Cache: key = hash of inputs, value = calculated result
  final Map<String, ProjectionResult> _cache = {};

  // Max cache size to prevent memory issues
  static const int _maxCacheSize = 20;

  ProjectionResult calculateProjection({
    required List<Account> accounts,
    required List<Envelope> envelopes,
    required List<ScheduledPayment> scheduledPayments,
    required PayDaySettings payDaySettings,
    Scenario? scenario,
  }) {
    // 1. Generate cache key from inputs
    final cacheKey = _generateCacheKey(
      accounts: accounts,
      envelopes: envelopes,
      scheduledPayments: scheduledPayments,
      payDaySettings: payDaySettings,
      scenario: scenario,
    );

    // 2. Check cache
    if (_cache.containsKey(cacheKey)) {
      debugPrint('[ProjectionService] ✓ Cache hit, returning cached result');
      return _cache[cacheKey]!;
    }

    // 3. Cache miss - calculate
    debugPrint('[ProjectionService] ⚠️ Cache miss, calculating projection...');
    final result = _performCalculation(
      accounts: accounts,
      envelopes: envelopes,
      scheduledPayments: scheduledPayments,
      payDaySettings: payDaySettings,
      scenario: scenario,
    );

    // 4. Store in cache (with size limit)
    if (_cache.length >= _maxCacheSize) {
      // Remove oldest entry (simple FIFO)
      _cache.remove(_cache.keys.first);
    }
    _cache[cacheKey] = result;

    return result;
  }

  String _generateCacheKey({
    required List<Account> accounts,
    required List<Envelope> envelopes,
    required List<ScheduledPayment> scheduledPayments,
    required PayDaySettings payDaySettings,
    Scenario? scenario,
  }) {
    // Create a stable hash of all inputs
    final inputString = [
      accounts.map((a) => '${a.id}:${a.currentBalance}').join(','),
      envelopes.map((e) => '${e.id}:${e.currentAmount}:${e.autoFillAmount}').join(','),
      scheduledPayments.map((s) => '${s.id}:${s.amount}:${s.nextDueDate}').join(','),
      '${payDaySettings.frequency}:${payDaySettings.amount}',
      scenario?.id ?? 'null',
    ].join('|');

    return md5.convert(utf8.encode(inputString)).toString();
  }

  ProjectionResult _performCalculation({
    required List<Account> accounts,
    required List<Envelope> envelopes,
    required List<ScheduledPayment> scheduledPayments,
    required PayDaySettings payDaySettings,
    Scenario? scenario,
  }) {
    // Your existing calculation logic here
    // ...
  }

  /// Clear cache (call when data changes significantly)
  void clearCache() {
    _cache.clear();
    debugPrint('[ProjectionService] Cache cleared');
  }
}
```

**Important**: Call `clearCache()` when user makes significant changes (deposits, transfers, etc.)

---

## 🔥 Critical Gotchas & Edge Cases

### 1. **isFuture Transactions** (⚠️ CRITICAL)
**Problem**: TimeMachine generates projected transactions with `isFuture: true`. These must NEVER be synced to Firebase.

**Solution**: Already implemented in SyncManager:
```dart
if (transaction.isFuture) {
  return; // Never sync projections
}
```

### 2. **User Switching** (⚠️ CRITICAL - GDPR)
**Problem**: When user logs out and another logs in, old user's data could leak.

**Solution**: CloudMigrationService checks user mismatch and clears data automatically.

### 3. **Offline Writes During Migration**
**Problem**: User might make changes while migration is downloading data.

**Solution**: RestorationOverlay blocks UI until migration completes.

### 4. **Workspace ID Changes**
**Problem**: User switches from solo to workspace mode or vice versa.

**Solution**: Use `setWorkspace()` method in EnvelopeRepo and trigger re-sync.

### 5. **Firebase Quota Limits**
**Problem**: Too many sync operations can trigger Firebase throttling.

**Solution**: SyncManager uses queue with 100ms delay between operations.

---

## 📊 Performance Benchmarks (Expected)

| Metric | Before | After | Improvement |
|--------|---------|-------|-------------|
| Initial load time | 2-3 seconds | **Instant** | 100% |
| Deposit/Withdraw lag | 500-1000ms | **< 16ms** | 95%+ |
| Time Machine lag (50 payments) | 1-2 seconds | **< 100ms** | 95%+ |
| StreamBuilder rebuilds | Every write | Only on Hive change | 70%+ |
| Firebase operations | Blocking | Background | 100% |

---

## 🧪 Testing Checklist

### Functional Tests:
- [ ] Solo mode: Deposit/withdraw shows instant UI update
- [ ] Workspace mode: Partner transfers sync to Firebase
- [ ] Migration: New device pulls all data on first login
- [ ] Logout: All Hive data cleared
- [ ] User switch: Old user data cleared, new user data loaded
- [ ] Offline: App works fully without network
- [ ] Time Machine: Projections don't sync to Firebase

### Edge Cases:
- [ ] Migration failure: App continues offline
- [ ] Firebase throttling: Queue prevents errors
- [ ] User switches workspace mid-session
- [ ] Rapid deposits (10+ in 1 second)
- [ ] 500+ envelopes, 10,000+ transactions

---

## 📁 File Summary

### New Files Created:
1. `lib/services/sync_manager.dart` - Background sync service
2. `lib/services/cloud_migration_service.dart` - Device migration
3. `lib/widgets/migration_overlay.dart` - Migration UI

### Files Modified:
1. `lib/models/envelope.dart` - Added `isSynced`, `lastUpdated`
2. `lib/models/account.dart` - Added `isSynced`, `lastUpdated`
3. `lib/models/transaction.dart` - Added `isSynced`, `lastUpdated`
4. `lib/services/envelope_repo.dart` - Added sync methods
5. `lib/services/account_repo.dart` - Added sync methods

### Files to Modify (Your Tasks):
1. `lib/services/envelope_repo.dart` - Integrate SyncManager
2. `lib/services/account_repo.dart` - Integrate SyncManager
3. `lib/screens/home_screen.dart` - Add initialData
4. `lib/screens/envelope/envelopes_detail_screen.dart` - Add initialData
5. `lib/screens/account_detail_screen.dart` - Add initialData
6. `lib/screens/auth_gate.dart` - Add migration overlay
7. `lib/services/auth_service.dart` - Add data cleanup
8. `lib/services/projection_service.dart` - Add memoization (optional)

---

## 🚀 Migration Path

### Phase 1: Infrastructure (✅ DONE)
- Model updates
- SyncManager
- CloudMigrationService
- Migration UI
- Sync methods in repos

### Phase 2: Integration (YOUR TASKS)
1. Add SyncManager to repository writes (1-2 hours)
2. Update UI screens with initialData (1 hour)
3. Add migration overlay to auth flow (30 mins)
4. Implement data cleanup (30 mins)

### Phase 3: Optimization (OPTIONAL)
1. Add projection memoization (1 hour)
2. Performance testing and tuning

### Phase 4: Testing & Validation
1. Functional testing
2. Edge case testing
3. Performance benchmarking

---

## 💡 Key Architectural Principles

1. **Local-First**: Hive is source of truth, always
2. **Fire-and-Forget Sync**: Firebase operations never block UI
3. **Instant UI**: All reads from Hive (synchronous), all writes immediate
4. **Background Sync**: SyncManager handles Firebase in background
5. **Multi-Device**: CloudMigration enables seamless device switching
6. **Privacy First**: Data cleared on logout (GDPR compliant)
7. **Offline-Ready**: App fully functional without network

---

## 📞 Support & Questions

For implementation questions or issues, refer to:
- Gemini's technical blueprint (provided)
- This summary document
- Inline code comments in new services

**Happy refactoring! 🎉**
