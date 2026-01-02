# Migration Guide: Legacy to Global Error Handling

## Quick Reference

### Before (Legacy Pattern)
```dart
// ❌ OLD WAY
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text('Error: $e')),
);
```

### After (Global Error Handling)
```dart
// ✅ NEW WAY
await ErrorHandler.handle(context, e);
```

---

## File-by-File Migration Examples

### 1. envelope_creator.dart ✅ **COMPLETED**

**What Changed:**
- Added imports for `ErrorHandler` and `AppError`
- Replaced all `ScaffoldMessenger.showSnackBar` with appropriate error handling
- Time machine warnings now use `ErrorHandler.showWarning()`
- Success messages use `ErrorHandler.showSuccess()`
- Validation errors use `AppError.medium()` with category validation
- Business logic errors use `AppError.business()`

**Example Migration:**
```dart
// Before
if (duplicateName) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('An envelope named "$name" already exists.'),
      backgroundColor: Colors.orange,
    ),
  );
  return;
}

// After
if (duplicateName) {
  await ErrorHandler.handle(
    context,
    AppError.business(
      code: 'DUPLICATE_ENVELOPE_NAME',
      userMessage: 'An envelope named "$name" already exists. Please choose a different name.',
      severity: ErrorSeverity.medium,
    ),
  );
  return;
}
```

---

### 2. sign_in_screen.dart - **TO MIGRATE**

**Current Pattern:**
```dart
// Lines 29-121: Manual FirebaseAuth error handling
try {
  await _auth.signInWithEmailAndPassword(email: email, password: password);
} catch (e) {
  String errorMessage = 'Sign in failed';
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'user-not-found':
        errorMessage = 'No account found with this email';
        break;
      case 'wrong-password':
        errorMessage = 'Incorrect password';
        break;
      // ... more cases
    }
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(errorMessage)),
  );
}
```

**Migration Steps:**
1. Add imports:
   ```dart
   import '../services/error_handler_service.dart';
   import '../models/app_error.dart';
   ```

2. Replace try-catch with automatic Firebase error conversion:
   ```dart
   try {
     await _auth.signInWithEmailAndPassword(email: email, password: password);
     ErrorHandler.showSuccess(context, 'Signed in successfully');
   } catch (e) {
     await ErrorHandler.handle(context, e); // Automatically converts Firebase errors
   }
   ```

**Benefits:**
- `ErrorHandler` automatically converts FirebaseAuthException to user-friendly messages
- Consistent error styling across the app
- Less code to maintain

---

### 3. group_editor.dart - **TO MIGRATE**

**Current Patterns:**
- Delete confirmation dialogs (lines 175-280)
- Duplicate name validation snackbars (lines 282-453)

**Migration:**

```dart
// Before: Custom delete dialog
final confirmed = await showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Delete Binder?'),
    content: const Text('This cannot be undone...'),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, true),
        child: const Text('Delete'),
      ),
    ],
  ),
);

// After: Use DialogHelpers
import '../utils/dialog_helpers.dart';

final confirmed = await DialogHelpers.showDestructiveConfirmation(
  context: context,
  title: 'Delete Binder?',
  message: 'This action cannot be undone. All envelopes in this binder will be moved to "No Binder".',
  confirmLabel: 'Delete',
  icon: Icons.delete_outline,
);
```

---

### 4. home_screen.dart - **TO MIGRATE**

**Current Pattern:**
- Bulk delete confirmations (lines 695-738)
- Partner access blocks

**Migration:**

```dart
// Before: Manual bulk delete confirmation
final confirmed = await showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Delete Selected Envelopes?'),
    content: Text('Are you sure you want to delete $selectedCount envelopes?'),
    actions: [/* ... */],
  ),
);

// After: Use DialogHelpers.showBulkActionConfirmation
import '../utils/dialog_helpers.dart';

final confirmed = await DialogHelpers.showBulkActionConfirmation(
  context: context,
  title: 'Delete Selected Envelopes?',
  itemCount: selectedCount,
  itemType: 'envelope',
  action: 'delete',
  additionalWarning: 'This action cannot be undone.',
);
```

---

### 5. account_editor_modal.dart - **TO MIGRATE**

**Current Pattern:**
- Validation errors shown as snackbars
- Similar to envelope_creator.dart

**Migration:** Follow the same pattern as envelope_creator.dart:

```dart
// Before
if (amount == null || amount < 0) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Invalid amount')),
  );
  return;
}

// After
if (amount == null || amount < 0) {
  await ErrorHandler.handle(
    context,
    AppError.medium(
      code: 'INVALID_AMOUNT',
      userMessage: 'Please enter a valid amount',
      category: ErrorCategory.validation,
    ),
  );
  return;
}
```

---

### 6. account_security_service.dart - **TO MIGRATE**

**Current Pattern:**
- Custom account deletion dialogs with password verification
- Complex error states during GDPR cascade

**Migration:**

```dart
// Before: Custom account deletion flow
final confirmed = await showDialog<bool>(/* complex dialog */);

// After: Use DialogHelpers with loading state
import '../utils/dialog_helpers.dart';
import '../services/error_handler_service.dart';

final confirmed = await DialogHelpers.showDestructiveConfirmation(
  context: context,
  title: 'Delete Account?',
  message: 'This will permanently delete your account and all data. This action cannot be undone.',
  confirmLabel: 'Delete Account',
  icon: Icons.warning_amber_rounded,
);

if (confirmed) {
  final closeDialog = DialogHelpers.showLoadingDialog(
    context,
    'Deleting account...',
  );

  try {
    await performGDPRCascade();
    closeDialog();
    ErrorHandler.showSuccess(context, 'Account deleted successfully');
  } catch (e) {
    closeDialog();
    await ErrorHandler.handle(context, e);
  }
}
```

---

## Common Migration Patterns

### Pattern 1: Simple Snackbar Replacement

```dart
// Before
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text('Operation failed')),
);

// After
await ErrorHandler.handle(
  context,
  AppError.medium(
    code: 'OPERATION_FAILED',
    userMessage: 'Operation failed',
  ),
);
```

### Pattern 2: Success Message

```dart
// Before
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text('Saved successfully')),
);

// After
ErrorHandler.showSuccess(context, 'Saved successfully');
```

### Pattern 3: Warning Message

```dart
// Before
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('Warning message'),
    backgroundColor: Colors.orange,
  ),
);

// After
ErrorHandler.showWarning(context, 'Warning message');
```

### Pattern 4: Destructive Action Confirmation

```dart
// Before
final confirmed = await showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Delete?'),
    content: const Text('Are you sure?'),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, true),
        style: FilledButton.styleFrom(backgroundColor: Colors.red),
        child: const Text('Delete'),
      ),
    ],
  ),
);

// After
import '../utils/dialog_helpers.dart';

final confirmed = await DialogHelpers.showDestructiveConfirmation(
  context: context,
  title: 'Delete Item?',
  message: 'Are you sure you want to delete this item?',
  confirmLabel: 'Delete',
  icon: Icons.delete_outline,
);
```

### Pattern 5: Try-Catch with Generic Exception

```dart
// Before
try {
  await someOperation();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Success')),
  );
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: $e')),
  );
}

// After
try {
  await someOperation();
  ErrorHandler.showSuccess(context, 'Success');
} catch (e) {
  await ErrorHandler.handle(context, e);
}
```

### Pattern 6: Validation Errors in Forms

```dart
// Before - Don't use snackbars for form validation!
if (email.isEmpty) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Email is required')),
  );
  return;
}

// After - Use inline validation
TextFormField(
  validator: (value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    if (!value.contains('@')) {
      return 'Invalid email format';
    }
    return null;
  },
)
```

---

## Testing After Migration

### 1. Visual Testing
- [ ] Verify snackbars appear at bottom (not top)
- [ ] Check color coding: Red (high), Orange (medium), Blue (low), Green (success)
- [ ] Confirm icons appear next to messages
- [ ] Test on large screen device (reachability)

### 2. Functional Testing
- [ ] Test critical error → Shows dialog
- [ ] Test medium error → Shows snackbar
- [ ] Test success message → Green snackbar, auto-dismisses
- [ ] Test validation error → Inline text (not snackbar/dialog)
- [ ] Test destructive action → Confirmation dialog with red button

### 3. Edge Cases
- [ ] Test rapid-fire errors (should queue properly)
- [ ] Test error during navigation (context should be checked)
- [ ] Test FirebaseAuthException auto-conversion
- [ ] Test generic Exception pattern matching

---

## Migration Checklist

For each file you migrate:

- [ ] Add imports (`ErrorHandler`, `AppError`, optionally `DialogHelpers`)
- [ ] Replace `ScaffoldMessenger.showSnackBar` with appropriate error handling
- [ ] Replace custom dialogs with `DialogHelpers` methods
- [ ] Use `ErrorHandler.showSuccess()` for success messages
- [ ] Use `ErrorHandler.showWarning()` for warnings
- [ ] Use inline validation for form errors (not snackbars)
- [ ] Add error codes for tracking/debugging
- [ ] Include metadata for complex errors
- [ ] Test the migration in the UI
- [ ] Remove unused imports

---

## Priority Order for Migration

Based on user impact and frequency of use:

1. ✅ **envelope_creator.dart** - COMPLETED
2. **sign_in_screen.dart** - High priority (authentication errors common)
3. **account_security_service.dart** - High priority (critical operations)
4. **group_editor.dart** - Medium priority (frequent use)
5. **home_screen.dart** - Medium priority (bulk operations)
6. **account_editor_modal.dart** - Low priority (less frequently used)
7. **account_settings_screen.dart** - Low priority (settings changes)

---

## Benefits of Migration

1. **Consistency**: All errors look and behave the same way
2. **Maintainability**: One place to update error styling/behavior
3. **UX**: Automatic severity-based UI (dialogs vs snackbars)
4. **Accessibility**: Icons + text, proper timing, reachability
5. **Debugging**: Error codes, metadata, original exception tracking
6. **Analytics-Ready**: Centralized logging point for future analytics
7. **Localization-Ready**: Centralized string management

---

## Common Mistakes to Avoid

### ❌ Don't Do This

```dart
// Don't use dialogs for recoverable errors
await ErrorHandler.handle(
  context,
  AppError.high(code: 'DUPLICATE_NAME', userMessage: 'Name exists'),
);

// Don't use snackbars for critical errors
await ErrorHandler.handle(
  context,
  AppError.low(code: 'ACCOUNT_DELETED', userMessage: 'Account deleted'),
);

// Don't use popups for form validation
if (email.isEmpty) {
  await ErrorHandler.handle(context, AppError.high(...));
}
```

### ✅ Do This Instead

```dart
// Use medium severity for recoverable errors
await ErrorHandler.handle(
  context,
  AppError.medium(code: 'DUPLICATE_NAME', userMessage: 'Name exists'),
);

// Use high/critical for serious errors
await ErrorHandler.handle(
  context,
  AppError.critical(code: 'ACCOUNT_DELETED', userMessage: 'Account deleted'),
);

// Use inline validation for forms
TextFormField(
  validator: (value) => value?.isEmpty ?? true ? 'Email required' : null,
)
```

---

## Getting Help

If you're unsure about:
- **Which severity to use**: See the decision tree in `ERROR_HANDLING.md`
- **Dialog vs Snackbar**: Follow the "Can user continue?" rule
- **Error codes**: Use SCREAMING_SNAKE_CASE, be descriptive
- **Custom errors**: Create AppError with appropriate category

Example questions to ask yourself:
1. Can the user continue without fixing this? → Snackbar (medium/low)
2. Is this blocking their workflow? → Dialog (high/critical)
3. Is this related to a specific form field? → Inline validation
4. Is this a confirmation for a destructive action? → Destructive dialog
