# Bidirectional Hive ↔ Firebase Sync

## Overview

The app now supports **bidirectional syncing** between local Hive storage and Firebase cloud storage.

---

## Features

### 1. **Migrate to Local Storage** (Firebase → Hive)
- Downloads all your data from Firebase to local device storage
- Use when: First time migrating to offline-first mode
- Location: Settings → Data & Privacy → "Migrate to Local Storage"

### 2. **Sync to Firebase** (Hive → Firebase) ✨ **NEW**
- Uploads all your local data to Firebase cloud storage
- Creates a cloud backup of your offline-first data
- Use when:
  - You want to create a cloud backup
  - Preparing to enable workspace mode
  - Restoring lost Firebase data from local storage
  - Switching between devices

---

## How to Use

### **Upload Local Data to Firebase**

1. Open Settings
2. Navigate to "Data & Privacy"
3. Tap "Sync to Firebase"
4. Review the confirmation dialog
5. Tap "Sync Now"
6. Wait for sync to complete
7. Review sync results

**What gets synced:**
- ✅ All envelopes
- ✅ All accounts
- ✅ All groups
- ✅ All transactions
- ✅ All scheduled payments

**Important Notes:**
- Only syncs **your** data (filtered by userId)
- Uses merge mode (won't delete existing Firebase data)
- Batches large transaction syncs for performance
- Shows detailed progress and results

---

## UI Flow

### Confirmation Dialog
```
┌────────────────────────────────┐
│ Sync to Firebase?              │
├────────────────────────────────┤
│ This will upload all your      │
│ local data to Firebase cloud   │
│ storage.                        │
│                                 │
│ Use this to:                    │
│ • Create a cloud backup        │
│ • Prepare for workspace mode   │
│ • Restore data to Firebase     │
│                                 │
│ This may take a few moments    │
│ for large datasets.            │
├────────────────────────────────┤
│  [Cancel]    [Sync Now]        │
└────────────────────────────────┘
```

### Progress Dialog
```
┌────────────────────────────────┐
│  ⟳  Loading...                 │
│  Syncing envelopes...          │
└────────────────────────────────┘
```

### Success Dialog
```
┌────────────────────────────────┐
│ ✓ Sync Complete                │
├────────────────────────────────┤
│ Successfully synced:           │
│                                 │
│ • 45 envelopes                 │
│ • 3 accounts                   │
│ • 8 groups                     │
│ • 1,234 transactions           │
│ • 12 scheduled payments        │
├────────────────────────────────┤
│            [Done]              │
└────────────────────────────────┘
```

---

## Technical Details

### Implementation

**File:** `lib/screens/settings_screen.dart`

**Method:** `_syncToFirebase(BuildContext context)`

**Backend Service:** `HiveMigrationService.syncToFirebase()`

**Features:**
- Progress callbacks for UI updates
- Error handling with user-friendly messages
- Batched writes for large datasets (500 per batch)
- Uses `SetOptions(merge: true)` to prevent data loss

### Code Example

```dart
final migrationService = HiveMigrationService(
  FirebaseFirestore.instance,
  FirebaseAuth.instance,
);

final result = await migrationService.syncToFirebase(
  onProgress: (progress) {
    print('Progress: $progress');
  },
);

if (result['success'] == true) {
  print('Synced ${result['envelopes']} envelopes');
  print('Synced ${result['accounts']} accounts');
  print('Synced ${result['groups']} groups');
  print('Synced ${result['transactions']} transactions');
  print('Synced ${result['scheduledPayments']} scheduled payments');
}
```

---

## Use Cases

### **1. Create Cloud Backup**
**Scenario:** You've been using solo mode and want a cloud backup

**Steps:**
1. Go to Settings → Sync to Firebase
2. Tap "Sync Now"
3. Your local data is now backed up to Firebase

---

### **2. Prepare for Workspace Mode**
**Scenario:** You want to share envelopes with a partner

**Steps:**
1. Sync your local data to Firebase first
2. Join or create a workspace
3. Firebase already has your data ready to sync

---

### **3. Restore Firebase Data**
**Scenario:** You deleted Firebase data by mistake

**Steps:**
1. Your local Hive data is still intact
2. Go to Settings → Sync to Firebase
3. All your data is restored to Firebase

---

### **4. Switch Devices**
**Scenario:** Getting a new phone

**Old Phone:**
1. Sync to Firebase (uploads local data)

**New Phone:**
1. Sign in
2. Migrate to Local Storage (downloads from Firebase)
3. All your data is now on the new device

---

## Safety Features

### ✅ **Non-Destructive**
- Uses `SetOptions(merge: true)`
- Won't delete existing Firebase data
- Only updates/adds documents

### ✅ **User-Filtered**
- Only syncs data where `userId == currentUser.uid`
- Won't accidentally sync other users' data

### ✅ **Batched for Performance**
- Transactions use batched writes (500 per batch)
- Prevents Firebase timeout errors
- Shows progress for large datasets

### ✅ **Error Handling**
- Try-catch blocks around all operations
- User-friendly error messages
- Automatic rollback on batch failures

---

## Logs

**Successful Sync:**
```
I/flutter: [ReverseSync] Starting Hive → Firebase sync for user: abc123
I/flutter: [ReverseSync] Syncing envelopes...
I/flutter: [ReverseSync] ✅ Synced 45 envelopes
I/flutter: [ReverseSync] Syncing accounts...
I/flutter: [ReverseSync] ✅ Synced 3 accounts
I/flutter: [ReverseSync] Syncing groups...
I/flutter: [ReverseSync] ✅ Synced 8 groups
I/flutter: [ReverseSync] Syncing transactions...
I/flutter: [ReverseSync] Committed batch of 500 transactions
I/flutter: [ReverseSync] Committed batch of 500 transactions
I/flutter: [ReverseSync] ✅ Synced 1234 transactions
I/flutter: [ReverseSync] Syncing scheduled payments...
I/flutter: [ReverseSync] ✅ Synced 12 scheduled payments
I/flutter: [ReverseSync] ✅ Sync complete for user: abc123
```

---

## Settings Screen Location

**Path:** Settings → Data & Privacy

**Options:**
1. ⬇️ Migrate to Local Storage (Firebase → Hive)
2. ⬆️ **Sync to Firebase** (Hive → Firebase) ✨ **NEW**
3. 📥 Export My Data (.xlsx)
4. 🧹 Clean Up Orphaned Data

---

## Future Enhancements

### Potential Improvements:
- [ ] Show estimated time for large syncs
- [ ] Add "Verify Sync" option to compare Hive vs Firebase
- [ ] Schedule automatic cloud backups (daily/weekly)
- [ ] Differential sync (only changed data)
- [ ] Conflict resolution UI for data mismatches

---

## Related Documentation

- [HIVE_REVENUECAT_IMPLEMENTATION.md](HIVE_REVENUECAT_IMPLEMENTATION.md) - Overall offline-first architecture
- `lib/services/hive_migration_service.dart` - Migration & sync service implementation
- `lib/screens/settings_screen.dart` - Settings UI implementation

---

**Created:** 2025-12-26
**Author:** Claude (Sonnet 4.5)
**Status:** ✅ Complete & Production Ready
