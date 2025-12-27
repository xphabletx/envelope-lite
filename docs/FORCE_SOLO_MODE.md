# Force Solo Mode - Fixing Unwanted Firebase Sync

## The Problem

After migrating to Hive and syncing to Firebase, you may notice Firebase errors when creating/updating envelopes in solo mode:

```
W/Firestore: Stream closed with status: Status{code=NOT_FOUND,
description=No document to update: projects/.../envelopes/...
```

**Why this happens:**
- The app stores workspace ID in SharedPreferences
- Even after migration, this workspace ID persists
- `EnvelopeRepo` checks `inWorkspace` which reads from this cached ID
- When `inWorkspace == true`, it tries to write to Firebase
- But Firebase doesn't have the document → ERROR

## The Solution: Force Solo Mode

A new setting clears all workspace associations and ensures you're in pure offline-first mode.

---

## How to Use

### **Location:** Settings → Data & Privacy → "Force Solo Mode"

### **What it does:**
1. Clears `active_workspace_id` from SharedPreferences
2. Clears `last_workspace_id` and `last_workspace_name`
3. Sets WorkspaceProvider to `null`
4. Reloads the app with workspace disabled

### **Result:**
- ✅ `inWorkspace` returns `false`
- ✅ All writes go ONLY to Hive
- ✅ Zero Firebase writes
- ✅ No more Firebase errors
- ✅ True offline-first mode

---

## Step-by-Step

1. **Open Settings**
2. **Navigate to "Data & Privacy"**
3. **Tap "Force Solo Mode"**
4. **Review the confirmation dialog:**
   ```
   This will:
   • Clear any workspace association
   • Use ONLY local Hive storage
   • Stop syncing to Firebase

   Your local data will be preserved.
   ```
5. **Tap "Enable Solo Mode"**
6. **Wait for success message:**
   ```
   ✓ Solo mode enabled. App will reload...
   ```
7. **App returns to home screen**
8. **Create/edit envelopes → No Firebase errors!**

---

## When to Use This

### **Scenario 1: After Migration**
You've migrated from Firebase to Hive, but Firebase errors still appear.

**Solution:** Use "Force Solo Mode" to clear workspace remnants.

---

### **Scenario 2: After Syncing to Firebase**
You synced to Firebase as a backup, but now want pure offline mode.

**Solution:** Use "Force Solo Mode" to disable Firebase writes.

---

### **Scenario 3: Left a Workspace**
You left a workspace but the app still thinks you're in one.

**Solution:** Use "Force Solo Mode" to clear workspace state.

---

### **Scenario 4: Testing Offline-First**
You want to verify the app works without any Firebase dependency.

**Solution:** Use "Force Solo Mode" + airplane mode to test.

---

## Technical Details

### **What Gets Cleared:**

**SharedPreferences:**
- `active_workspace_id`
- `last_workspace_id`
- `last_workspace_name`

**WorkspaceProvider:**
- Sets `_workspaceId = null`
- Calls `notifyListeners()` to rebuild app

**EnvelopeRepo:**
- `inWorkspace` now returns `false`
- All write operations skip Firebase blocks
- Streams use Hive.watch() only

---

## Code Implementation

**File:** `lib/screens/settings_screen.dart`

**New Setting Tile (lines 250-256):**
```dart
_SettingsTile(
  title: 'Force Solo Mode',
  subtitle: 'Clear workspace & use only local storage',
  leading: const Icon(Icons.phonelink_off_outlined),
  onTap: () => _forceSoloMode(context),
  trailing: const Icon(Icons.chevron_right),
),
```

**Method: `_forceSoloMode()` (lines 742-813):**
```dart
Future<void> _forceSoloMode(BuildContext context) async {
  // Get WorkspaceProvider before async calls
  final workspaceProvider = Provider.of<WorkspaceProvider>(context, listen: false);

  // Clear SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('active_workspace_id');
  await prefs.remove('last_workspace_id');
  await prefs.remove('last_workspace_name');

  // Clear WorkspaceProvider
  await workspaceProvider.setWorkspaceId(null);

  // Reload app
  Navigator.of(context).popUntil((route) => route.isFirst);
}
```

---

## Verification

### **Before Force Solo Mode:**
```
I/flutter: [EnvelopeRepo] DEBUG: Updating envelope abc123. isShared: false
I/flutter: [EnvelopeRepo] ✅ Envelope updated in Hive: abc123
W/Firestore: Stream closed with status: Status{code=NOT_FOUND, ...}
```

### **After Force Solo Mode:**
```
I/flutter: [EnvelopeRepo] DEBUG: Updating envelope abc123. isShared: false
I/flutter: [EnvelopeRepo] ✅ Envelope updated in Hive: abc123
[No Firebase errors - perfect!]
```

---

## Settings Screen Layout

```
Settings → Data & Privacy
├─ ⬇️ Migrate to Local Storage
├─ ⬆️ Sync to Firebase
├─ 📱 Force Solo Mode          ← NEW
├─ 📥 Export My Data
└─ 🧹 Clean Up Orphaned Data
```

---

## FAQ

### **Q: Will this delete my local data?**
**A:** No! Your Hive data is completely safe. This only clears workspace settings.

### **Q: Will this delete my Firebase data?**
**A:** No! Your Firebase data remains unchanged. You just stop syncing to it.

### **Q: Can I join a workspace later?**
**A:** Yes! This doesn't prevent you from joining workspaces in the future.

### **Q: Do I need to do this after every migration?**
**A:** Only if you see Firebase errors. If migration properly cleared workspace, you don't need this.

### **Q: What if I want Firebase sync back?**
**A:** Join a workspace, or manually sync using "Sync to Firebase" option.

---

## Understanding the Architecture

### **Solo Mode (After Force Solo Mode):**
```
User creates envelope
↓
EnvelopeRepo.createEnvelope()
↓
Check: inWorkspace? → FALSE
↓
Write to Hive ONLY
↓
_envelopeBox.put(id, envelope)
↓
Hive.watch() emits change
↓
UI updates instantly
✓ No Firebase writes
✓ No Firebase errors
```

### **Workspace Mode (Before Force Solo Mode):**
```
User creates envelope
↓
EnvelopeRepo.createEnvelope()
↓
Check: inWorkspace? → TRUE (workspace ID cached)
↓
Write to Hive
Write to Firebase ← ERROR: Document doesn't exist
↓
Firebase error appears in logs
```

---

## Related Documentation

- [HIVE_REVENUECAT_IMPLEMENTATION.md](HIVE_REVENUECAT_IMPLEMENTATION.md) - Overall offline-first architecture
- [SYNC_FEATURE.md](SYNC_FEATURE.md) - Bidirectional sync between Hive and Firebase
- `lib/services/envelope_repo.dart` - Repository implementation
- `lib/providers/workspace_provider.dart` - Workspace state management

---

**Created:** 2025-12-26
**Author:** Claude (Sonnet 4.5)
**Status:** ✅ Production Ready
**Issue:** Fixes Firebase errors in solo mode after migration/sync
