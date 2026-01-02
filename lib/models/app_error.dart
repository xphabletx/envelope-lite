// Global error handling model for the Stuffrite app.
// Provides a unified error classification system with severity levels
// to determine appropriate UI responses (dialog, snackbar, inline).

enum ErrorSeverity {
  /// Critical errors that block the user from continuing.
  /// Examples: Account deletion, app update required, data corruption.
  /// UI Response: Pop-up dialog (blocking).
  critical,

  /// High-priority errors requiring user attention.
  /// Examples: Authentication failures, destructive actions, network unavailable.
  /// UI Response: Pop-up dialog (blocking).
  high,

  /// Medium-priority errors that are recoverable.
  /// Examples: Insufficient funds, validation failures, duplicate names.
  /// UI Response: Snackbar with optional action (non-blocking).
  medium,

  /// Low-priority informational messages or temporary issues.
  /// Examples: Background sync failed, operation successful, item added.
  /// UI Response: Snackbar (auto-dismiss, non-blocking).
  low,

  /// Form validation errors.
  /// Examples: Empty field, invalid email, password too short.
  /// UI Response: Inline text under the field.
  validation,
}

enum ErrorCategory {
  /// Authentication and authorization errors
  auth,

  /// Data validation errors
  validation,

  /// Business logic errors (insufficient funds, duplicate items, etc.)
  business,

  /// Database/storage errors
  data,

  /// Network and API errors
  network,

  /// Permission and access errors
  permission,

  /// Unknown/unexpected errors
  unknown,
}

class AppError implements Exception {
  final String code;
  final String userMessage;
  final String? technicalDetails;
  final ErrorSeverity severity;
  final ErrorCategory category;
  final Map<String, dynamic>? metadata;
  final Exception? originalException;

  const AppError({
    required this.code,
    required this.userMessage,
    this.technicalDetails,
    required this.severity,
    required this.category,
    this.metadata,
    this.originalException,
  });

  /// Creates a critical error (blocks user, requires dialog)
  factory AppError.critical({
    required String code,
    required String userMessage,
    String? technicalDetails,
    ErrorCategory category = ErrorCategory.unknown,
    Map<String, dynamic>? metadata,
    Exception? originalException,
  }) {
    return AppError(
      code: code,
      userMessage: userMessage,
      technicalDetails: technicalDetails,
      severity: ErrorSeverity.critical,
      category: category,
      metadata: metadata,
      originalException: originalException,
    );
  }

  /// Creates a high-priority error (requires dialog)
  factory AppError.high({
    required String code,
    required String userMessage,
    String? technicalDetails,
    ErrorCategory category = ErrorCategory.unknown,
    Map<String, dynamic>? metadata,
    Exception? originalException,
  }) {
    return AppError(
      code: code,
      userMessage: userMessage,
      technicalDetails: technicalDetails,
      severity: ErrorSeverity.high,
      category: category,
      metadata: metadata,
      originalException: originalException,
    );
  }

  /// Creates a medium-priority error (uses snackbar)
  factory AppError.medium({
    required String code,
    required String userMessage,
    String? technicalDetails,
    ErrorCategory category = ErrorCategory.unknown,
    Map<String, dynamic>? metadata,
    Exception? originalException,
  }) {
    return AppError(
      code: code,
      userMessage: userMessage,
      technicalDetails: technicalDetails,
      severity: ErrorSeverity.medium,
      category: category,
      metadata: metadata,
      originalException: originalException,
    );
  }

  /// Creates a low-priority informational message (uses snackbar)
  factory AppError.low({
    required String code,
    required String userMessage,
    String? technicalDetails,
    ErrorCategory category = ErrorCategory.unknown,
    Map<String, dynamic>? metadata,
  }) {
    return AppError(
      code: code,
      userMessage: userMessage,
      technicalDetails: technicalDetails,
      severity: ErrorSeverity.low,
      category: category,
      metadata: metadata,
    );
  }

  /// Creates a validation error (inline display)
  factory AppError.validation({
    required String code,
    required String userMessage,
    Map<String, dynamic>? metadata,
  }) {
    return AppError(
      code: code,
      userMessage: userMessage,
      severity: ErrorSeverity.validation,
      category: ErrorCategory.validation,
      metadata: metadata,
    );
  }

  /// Creates an authentication error
  factory AppError.auth({
    required String code,
    required String userMessage,
    String? technicalDetails,
    ErrorSeverity severity = ErrorSeverity.high,
    Exception? originalException,
  }) {
    return AppError(
      code: code,
      userMessage: userMessage,
      technicalDetails: technicalDetails,
      severity: severity,
      category: ErrorCategory.auth,
      originalException: originalException,
    );
  }

  /// Creates a business logic error
  factory AppError.business({
    required String code,
    required String userMessage,
    String? technicalDetails,
    ErrorSeverity severity = ErrorSeverity.medium,
    Map<String, dynamic>? metadata,
  }) {
    return AppError(
      code: code,
      userMessage: userMessage,
      technicalDetails: technicalDetails,
      severity: severity,
      category: ErrorCategory.business,
      metadata: metadata,
    );
  }

  /// Creates a data/storage error
  factory AppError.data({
    required String code,
    required String userMessage,
    String? technicalDetails,
    ErrorSeverity severity = ErrorSeverity.high,
    Exception? originalException,
  }) {
    return AppError(
      code: code,
      userMessage: userMessage,
      technicalDetails: technicalDetails,
      severity: severity,
      category: ErrorCategory.data,
      originalException: originalException,
    );
  }

  /// Creates a network error
  factory AppError.network({
    required String code,
    required String userMessage,
    String? technicalDetails,
    ErrorSeverity severity = ErrorSeverity.medium,
    Exception? originalException,
  }) {
    return AppError(
      code: code,
      userMessage: userMessage,
      technicalDetails: technicalDetails,
      severity: severity,
      category: ErrorCategory.network,
      originalException: originalException,
    );
  }

  /// Creates a permission/access error
  factory AppError.permission({
    required String code,
    required String userMessage,
    ErrorSeverity severity = ErrorSeverity.medium,
  }) {
    return AppError(
      code: code,
      userMessage: userMessage,
      severity: severity,
      category: ErrorCategory.permission,
    );
  }

  @override
  String toString() {
    return 'AppError(code: $code, severity: $severity, category: $category, message: $userMessage)';
  }

  /// Gets the full debug information
  String toDebugString() {
    final buffer = StringBuffer();
    buffer.writeln('AppError:');
    buffer.writeln('  Code: $code');
    buffer.writeln('  Severity: $severity');
    buffer.writeln('  Category: $category');
    buffer.writeln('  User Message: $userMessage');
    if (technicalDetails != null) {
      buffer.writeln('  Technical Details: $technicalDetails');
    }
    if (metadata != null) {
      buffer.writeln('  Metadata: $metadata');
    }
    if (originalException != null) {
      buffer.writeln('  Original Exception: $originalException');
    }
    return buffer.toString();
  }
}
