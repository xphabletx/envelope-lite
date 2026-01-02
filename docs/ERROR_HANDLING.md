# Global Error Handling System

## Overview

The Stuffrite app uses a unified global error handling system that automatically determines the appropriate UI response based on error severity. This ensures a consistent user experience across the entire application.

## Core Principles

### UI Response by Severity

Following modern UX best practices for mobile-first design:

| Severity | UI Response | Use Case | Example |
|----------|------------|----------|---------|
| **Critical** | Blocking Pop-up Dialog | User cannot continue without addressing the error | Account deletion, app update required, data corruption |
| **High** | Blocking Pop-up Dialog | Requires immediate user attention | Authentication failures, destructive actions confirmation |
| **Medium** | Bottom Snackbar | Recoverable errors, user can continue | Insufficient funds, duplicate names, validation failures |
| **Low** | Auto-dismiss Snackbar | Informational messages, temporary issues | Background sync failed, success confirmations |
| **Validation** | Inline text under field | Form-specific errors | Empty field, invalid email, password mismatch |

### The "Reachability" Factor

Modern phones have large screens making the top harder to reach with thumbs:
- **Snackbars** appear at the bottom (thumb-friendly zone)
- **Pop-ups** appear in the center (requires grip adjustment)
- **Inline errors** appear directly under the problematic field

## Architecture

### 1. Error Model (`lib/models/app_error.dart`)

```dart
class AppError implements Exception {
  final String code;              // Machine-readable error code
  final String userMessage;       // User-friendly message
  final ErrorSeverity severity;   // Determines UI response
  final ErrorCategory category;   // Error classification
  final String? technicalDetails; // Debug information
  final Map<String, dynamic>? metadata; // Additional context
  final Exception? originalException; // Original error if wrapped
}
```

#### Error Severity Levels

```dart
enum ErrorSeverity {
  critical,   // Blocks user completely (e.g., account deletion)
  high,       // Requires immediate attention (e.g., auth failure)
  medium,     // Recoverable error (e.g., insufficient funds)
  low,        // Informational (e.g., sync failed)
  validation, // Form validation (e.g., empty field)
}
```

#### Error Categories

```dart
enum ErrorCategory {
  auth,        // Authentication/authorization
  validation,  // Input validation
  business,    // Business logic (insufficient funds, duplicates)
  data,        // Database/storage errors
  network,     // Network/API errors
  permission,  // Access/permission errors
  unknown,     // Unexpected errors
}
```

### 2. Error Handler Service (`lib/services/error_handler_service.dart`)

The `ErrorHandler` service provides centralized error handling:

```dart
class ErrorHandler {
  // Main handler - automatically determines UI response
  static Future<bool> handle(
    BuildContext context,
    dynamic error, {
    VoidCallback? onRetry,
    VoidCallback? onDismiss,
  });

  // Utility methods for specific feedback
  static void showSuccess(BuildContext context, String message);
  static void showInfo(BuildContext context, String message);
  static void showWarning(BuildContext context, String message);
}
```

#### Automatic Error Conversion

The handler automatically converts common errors:
- **FirebaseAuthException** → User-friendly auth messages
- **FirebaseException** → Appropriate network/data errors
- **Generic Exceptions** → Analyzed for patterns (insufficient funds, not found, duplicates)

### 3. Dialog Helpers (`lib/utils/dialog_helpers.dart`)

Reusable dialog utilities for user confirmations:

```dart
class DialogHelpers {
  // Destructive action confirmation (red button)
  static Future<bool> showDestructiveConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Delete',
    String cancelLabel = 'Cancel',
  });

  // Choice between two options
  static Future<bool?> showChoiceDialog({
    required BuildContext context,
    required String title,
    required String message,
    required String primaryLabel,
    required String secondaryLabel,
    bool isPrimaryDestructive = false,
  });

  // Informational dialog
  static Future<void> showInfoDialog({
    required BuildContext context,
    required String title,
    required String message,
    String buttonLabel = 'OK',
  });

  // Bulk operation confirmation
  static Future<bool> showBulkActionConfirmation({
    required BuildContext context,
    required String title,
    required int itemCount,
    required String itemType,
    required String action,
  });

  // Loading dialog (returns close function)
  static VoidCallback showLoadingDialog(
    BuildContext context,
    String message,
  );

  // Text input dialog
  static Future<String?> showTextInputDialog({
    required BuildContext context,
    required String title,
    String? hintText,
    String? Function(String?)? validator,
  });
}
```

## Usage Examples

### Basic Error Handling

```dart
try {
  await someRiskyOperation();
} catch (e) {
  await ErrorHandler.handle(context, e);
}
```

### Creating Custom AppErrors

```dart
// Insufficient funds (medium severity, snackbar)
throw AppError.business(
  code: 'INSUFFICIENT_FUNDS',
  userMessage: 'Insufficient funds in ${envelopeName}',
  severity: ErrorSeverity.medium,
  metadata: {
    'availableBalance': 100.0,
    'requestedAmount': 150.0,
  },
);

// Authentication error (high severity, dialog)
throw AppError.auth(
  code: 'INVALID_CREDENTIALS',
  userMessage: 'Incorrect email or password',
  severity: ErrorSeverity.high,
);

// Validation error (medium severity, snackbar)
throw AppError.validation(
  code: 'INVALID_EMAIL',
  userMessage: 'Please enter a valid email address',
);
```

### Success/Info Messages

```dart
// Success feedback
ErrorHandler.showSuccess(context, 'Transfer successful');

// Informational message
ErrorHandler.showInfo(context, 'Syncing changes...');

// Warning message
ErrorHandler.showWarning(context, 'Time machine mode active');
```

### Confirmation Dialogs

```dart
// Destructive action confirmation
final confirmed = await DialogHelpers.showDestructiveConfirmation(
  context: context,
  title: 'Delete Envelope?',
  message: 'This action cannot be undone.',
  confirmLabel: 'Delete',
  icon: Icons.delete_outline,
);

if (confirmed) {
  // Proceed with deletion
}

// Choice dialog
final result = await DialogHelpers.showChoiceDialog(
  context: context,
  title: 'Unsaved Changes',
  message: 'You have unsaved changes. What would you like to do?',
  primaryLabel: 'Discard',
  secondaryLabel: 'Keep Editing',
  isPrimaryDestructive: true,
);

if (result == true) {
  // Discard changes
} else if (result == false) {
  // Keep editing
}

// Loading dialog
final closeDialog = DialogHelpers.showLoadingDialog(
  context,
  'Deleting account...',
);

try {
  await performLongOperation();
} finally {
  closeDialog();
}
```

### Form Validation

For form-specific errors, use inline validation instead of popups/snackbars:

```dart
TextFormField(
  validator: (value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a name'; // Inline error
    }
    if (value.length < 3) {
      return 'Name must be at least 3 characters';
    }
    return null;
  },
)
```

### With Retry Logic

```dart
await ErrorHandler.handle(
  context,
  error,
  onRetry: () async {
    // Retry the operation
    await retryOperation();
  },
);
```

## Integration Points

### Current Implementations

The following components have been updated to use the global error handling system:

1. **Envelope Transfers** (`lib/screens/envelope/modals/transfer_modal.dart`)
   - Validation errors → Medium severity snackbars
   - Insufficient funds → Business error with metadata
   - Success → Green success snackbar
   - Time machine warnings → Warning snackbar

2. **Envelope Repository** (`lib/services/envelope_repo.dart`)
   - Enhanced error messages with available/required amounts
   - Throws detailed exceptions for insufficient funds

3. **Scheduled Payments** (`lib/services/scheduled_payment_processor.dart`)
   - Already has robust notification system
   - Creates notifications for failures with metadata
   - Handles envelope deletion gracefully

### Files Still Using Legacy Error Handling

These files should be migrated to use the global error handling system:

- `lib/widgets/envelope_creator.dart` - Uses ScaffoldMessenger directly
- `lib/screens/sign_in_screen.dart` - Manual FirebaseAuth error handling
- `lib/services/account_security_service.dart` - Custom error dialogs
- `lib/widgets/group_editor.dart` - Mixed snackbar/dialog patterns
- `lib/screens/home_screen.dart` - Bulk delete confirmations
- `lib/widgets/accounts/account_editor_modal.dart` - Validation snackbars
- `lib/screens/accounts/account_settings_screen.dart` - Validation snackbars

## Best Practices

### DO ✅

1. **Use appropriate severity levels**
   ```dart
   // Good: Insufficient funds is recoverable
   throw AppError.business(
     code: 'INSUFFICIENT_FUNDS',
     userMessage: 'Not enough balance',
     severity: ErrorSeverity.medium,
   );
   ```

2. **Include helpful metadata**
   ```dart
   throw AppError.business(
     code: 'INSUFFICIENT_FUNDS',
     userMessage: 'Insufficient funds in Groceries',
     metadata: {
       'availableBalance': 50.0,
       'requestedAmount': 75.0,
       'envelopeId': 'env_123',
     },
   );
   ```

3. **Use factory methods for common scenarios**
   ```dart
   // Auth errors
   AppError.auth(code: 'INVALID_CRED', userMessage: '...');

   // Business logic errors
   AppError.business(code: 'DUPLICATE_NAME', userMessage: '...');

   // Network errors
   AppError.network(code: 'TIMEOUT', userMessage: '...');
   ```

4. **Wrap and preserve original exceptions**
   ```dart
   try {
     await firebaseOperation();
   } catch (e) {
     throw AppError.network(
       code: 'FIREBASE_ERROR',
       userMessage: 'Failed to sync data',
       technicalDetails: e.toString(),
       originalException: e is Exception ? e : null,
     );
   }
   ```

### DON'T ❌

1. **Don't use popups for form validation**
   ```dart
   // Bad: Popup disconnects error from field
   if (email.isEmpty) {
     await ErrorHandler.handle(context, AppError.high(...));
   }

   // Good: Inline validation
   TextFormField(
     validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
   );
   ```

2. **Don't use critical severity unless absolutely necessary**
   ```dart
   // Bad: Overusing critical severity
   throw AppError.critical(
     code: 'DUPLICATE_NAME',
     userMessage: 'Name already exists',
   );

   // Good: Medium severity for recoverable errors
   throw AppError.medium(
     code: 'DUPLICATE_NAME',
     userMessage: 'An envelope with this name already exists',
   );
   ```

3. **Don't show raw exception messages to users**
   ```dart
   // Bad: Technical jargon
   ScaffoldMessenger.of(context).showSnackBar(
     SnackBar(content: Text('Error: $e')),
   );

   // Good: User-friendly message
   await ErrorHandler.handle(context, e);
   ```

4. **Don't use snackbars for destructive actions**
   ```dart
   // Bad: Snackbar for account deletion
   ErrorHandler.showWarning(context, 'Account will be deleted');

   // Good: Blocking confirmation dialog
   final confirmed = await DialogHelpers.showDestructiveConfirmation(
     context: context,
     title: 'Delete Account?',
     message: 'This action cannot be undone',
   );
   ```

## Error Severity Decision Tree

```
Is the error blocking the user from continuing?
├─ Yes: Is it related to data loss or critical security?
│  ├─ Yes → CRITICAL (e.g., account deletion, data corruption)
│  └─ No → HIGH (e.g., auth failure, network unavailable)
└─ No: Can the user recover or continue working?
   ├─ Yes: Is it just informational?
   │  ├─ Yes → LOW (e.g., sync failed, success message)
   │  └─ No → MEDIUM (e.g., insufficient funds, duplicate name)
   └─ No: Is it form-specific?
      └─ Yes → VALIDATION (e.g., empty field, invalid email)
```

## Migration Guide

### Step 1: Import the Error Handling System

```dart
import 'package:stuffrite/models/app_error.dart';
import 'package:stuffrite/services/error_handler_service.dart';
import 'package:stuffrite/utils/dialog_helpers.dart'; // If using dialogs
```

### Step 2: Replace ScaffoldMessenger with ErrorHandler

**Before:**
```dart
try {
  await operation();
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Success')),
  );
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: $e')),
  );
}
```

**After:**
```dart
try {
  await operation();
  ErrorHandler.showSuccess(context, 'Success');
} catch (e) {
  await ErrorHandler.handle(context, e);
}
```

### Step 3: Replace showDialog with DialogHelpers

**Before:**
```dart
final confirmed = await showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Delete?'),
    content: const Text('This cannot be undone'),
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
```

**After:**
```dart
final confirmed = await DialogHelpers.showDestructiveConfirmation(
  context: context,
  title: 'Delete Envelope?',
  message: 'This action cannot be undone',
  confirmLabel: 'Delete',
  icon: Icons.delete_outline,
);
```

### Step 4: Enhance Error Messages

**Before:**
```dart
if (amount > balance) {
  throw Exception('Insufficient funds');
}
```

**After:**
```dart
if (amount > balance) {
  throw AppError.business(
    code: 'INSUFFICIENT_FUNDS',
    userMessage: 'Insufficient funds in $envelopeName',
    severity: ErrorSeverity.medium,
    metadata: {
      'availableBalance': balance,
      'requestedAmount': amount,
    },
  );
}
```

## Testing Guidelines

### Unit Tests

```dart
test('handles insufficient funds error correctly', () async {
  final error = AppError.business(
    code: 'INSUFFICIENT_FUNDS',
    userMessage: 'Not enough balance',
  );

  expect(error.severity, ErrorSeverity.medium);
  expect(error.category, ErrorCategory.business);
  expect(error.userMessage, contains('balance'));
});
```

### Widget Tests

```dart
testWidgets('shows snackbar for medium severity errors', (tester) async {
  await tester.pumpWidget(MyApp());

  final error = AppError.medium(
    code: 'TEST_ERROR',
    userMessage: 'Test error message',
  );

  await ErrorHandler.handle(
    tester.element(find.byType(Scaffold)),
    error,
  );

  await tester.pump();

  expect(find.byType(SnackBar), findsOneWidget);
  expect(find.text('Test error message'), findsOneWidget);
});
```

## Accessibility Considerations

1. **Screen Readers**: Error messages are automatically announced
2. **Color**: Icons accompany all errors (not color-only)
3. **Timing**: Low severity snackbars auto-dismiss (2s), medium severity stay longer (4s)
4. **Reachability**: Bottom snackbars are thumb-friendly on large devices

## Future Enhancements

- [ ] Analytics integration (track error frequencies)
- [ ] Remote error logging (Crashlytics/Sentry)
- [ ] Localization support for error messages
- [ ] Offline error queuing
- [ ] Error retry strategies (exponential backoff)
- [ ] User error reporting ("Send feedback" button)

## Changelog

### v1.0.0 (2026-01-02)
- Initial implementation of global error handling system
- Created AppError model with severity and category classification
- Implemented ErrorHandler service with automatic UI response
- Added DialogHelpers for consistent confirmations
- Migrated envelope transfers to use new system
- Enhanced envelope_repo error messages
