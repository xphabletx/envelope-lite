import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_error.dart';

/// Global error handler service for the Stuffrite app.
///
/// Provides centralized error handling with automatic UI response based on severity:
/// - Critical/High severity: Shows blocking pop-up dialog
/// - Medium/Low severity: Shows bottom snackbar
/// - Validation severity: Returns error string for inline display
///
/// Usage:
/// ```dart
/// try {
///   await someOperation();
/// } catch (e) {
///   await ErrorHandler.handle(context, e);
/// }
/// ```
class ErrorHandler {
  ErrorHandler._();

  /// Handles any error and displays appropriate UI based on severity.
  ///
  /// Returns true if error was handled, false otherwise.
  static Future<bool> handle(
    BuildContext context,
    dynamic error, {
    VoidCallback? onRetry,
    VoidCallback? onDismiss,
  }) async {
    if (!context.mounted) return false;

    final appError = _convertToAppError(error);

    // Log error for debugging
    debugPrint(appError.toDebugString());

    switch (appError.severity) {
      case ErrorSeverity.critical:
      case ErrorSeverity.high:
        await _showErrorDialog(context, appError, onRetry: onRetry);
        break;

      case ErrorSeverity.medium:
      case ErrorSeverity.low:
        _showErrorSnackbar(context, appError, onRetry: onRetry);
        break;

      case ErrorSeverity.validation:
        // Validation errors should be handled inline by the caller
        debugPrint('Validation error should be handled inline: ${appError.userMessage}');
        break;
    }

    onDismiss?.call();
    return true;
  }

  /// Shows a blocking error dialog for critical/high severity errors.
  static Future<void> _showErrorDialog(
    BuildContext context,
    AppError error, {
    VoidCallback? onRetry,
  }) async {
    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: error.severity != ErrorSeverity.critical,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _getIconForCategory(error.category),
              color: _getColorForSeverity(error.severity),
            ),
            const SizedBox(width: 12),
            const Text('Error'),
          ],
        ),
        content: Text(error.userMessage),
        actions: [
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: const Text('Retry'),
            ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Shows a bottom snackbar for medium/low severity errors.
  static void _showErrorSnackbar(
    BuildContext context,
    AppError error, {
    VoidCallback? onRetry,
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _getIconForCategory(error.category),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(error.userMessage)),
          ],
        ),
        backgroundColor: _getColorForSeverity(error.severity),
        duration: error.severity == ErrorSeverity.low
            ? const Duration(seconds: 2)
            : const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  /// Converts any error/exception to an AppError with appropriate severity.
  static AppError _convertToAppError(dynamic error) {
    if (error is AppError) {
      return error;
    }

    // Firebase Auth errors
    if (error is FirebaseAuthException) {
      return _convertFirebaseAuthError(error);
    }

    // Firebase errors (generic)
    if (error is FirebaseException) {
      return AppError.network(
        code: error.code,
        userMessage: _getFriendlyFirebaseMessage(error),
        technicalDetails: error.message,
        originalException: error,
      );
    }

    // Generic exceptions with messages
    if (error is Exception) {
      final message = error.toString().replaceFirst('Exception: ', '');

      // Check for common patterns
      if (message.toLowerCase().contains('insufficient funds') ||
          message.toLowerCase().contains('insufficient balance')) {
        return AppError.business(
          code: 'INSUFFICIENT_FUNDS',
          userMessage: message,
          severity: ErrorSeverity.medium,
        );
      }

      if (message.toLowerCase().contains('not found')) {
        return AppError.data(
          code: 'NOT_FOUND',
          userMessage: message,
          severity: ErrorSeverity.medium,
          originalException: error,
        );
      }

      if (message.toLowerCase().contains('already exists') ||
          message.toLowerCase().contains('duplicate')) {
        return AppError.validation(
          code: 'DUPLICATE',
          userMessage: message,
        );
      }

      return AppError.medium(
        code: 'UNKNOWN_EXCEPTION',
        userMessage: message,
        originalException: error,
      );
    }

    // Fallback for unknown errors
    return AppError.medium(
      code: 'UNKNOWN_ERROR',
      userMessage: 'An unexpected error occurred. Please try again.',
      technicalDetails: error?.toString(),
    );
  }

  /// Converts Firebase Auth errors to user-friendly AppErrors.
  static AppError _convertFirebaseAuthError(FirebaseAuthException error) {
    String userMessage;
    ErrorSeverity severity = ErrorSeverity.high;

    switch (error.code) {
      case 'user-not-found':
        userMessage = 'No account found with this email address.';
        break;
      case 'wrong-password':
      case 'invalid-credential':
        userMessage = 'Incorrect email or password. Please try again.';
        break;
      case 'email-already-in-use':
        userMessage = 'An account with this email already exists.';
        break;
      case 'weak-password':
        userMessage = 'Password is too weak. Please use a stronger password.';
        severity = ErrorSeverity.validation;
        break;
      case 'invalid-email':
        userMessage = 'Invalid email address format.';
        severity = ErrorSeverity.validation;
        break;
      case 'operation-not-allowed':
        userMessage = 'This sign-in method is not enabled.';
        severity = ErrorSeverity.critical;
        break;
      case 'user-disabled':
        userMessage = 'This account has been disabled.';
        severity = ErrorSeverity.critical;
        break;
      case 'too-many-requests':
        userMessage = 'Too many failed attempts. Please try again later.';
        break;
      case 'network-request-failed':
        userMessage = 'Network error. Please check your internet connection.';
        severity = ErrorSeverity.medium;
        break;
      case 'requires-recent-login':
        userMessage = 'Please sign in again to continue.';
        break;
      default:
        userMessage = error.message ?? 'Authentication failed. Please try again.';
    }

    return AppError.auth(
      code: error.code,
      userMessage: userMessage,
      technicalDetails: error.message,
      severity: severity,
      originalException: error,
    );
  }

  /// Gets a friendly message for Firebase errors.
  static String _getFriendlyFirebaseMessage(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'You do not have permission to perform this action.';
      case 'unavailable':
        return 'Service temporarily unavailable. Please try again.';
      case 'not-found':
        return 'The requested data was not found.';
      case 'already-exists':
        return 'This item already exists.';
      case 'cancelled':
        return 'Operation was cancelled.';
      case 'data-loss':
        return 'Data loss or corruption detected.';
      case 'deadline-exceeded':
        return 'Operation timed out. Please try again.';
      default:
        return error.message ?? 'A service error occurred. Please try again.';
    }
  }

  /// Gets the appropriate icon for an error category.
  static IconData _getIconForCategory(ErrorCategory category) {
    switch (category) {
      case ErrorCategory.auth:
        return Icons.lock_outline;
      case ErrorCategory.validation:
        return Icons.warning_amber_rounded;
      case ErrorCategory.business:
        return Icons.info_outline;
      case ErrorCategory.data:
        return Icons.storage_outlined;
      case ErrorCategory.network:
        return Icons.wifi_off_outlined;
      case ErrorCategory.permission:
        return Icons.block_outlined;
      case ErrorCategory.unknown:
        return Icons.error_outline;
    }
  }

  /// Gets the appropriate color for an error severity.
  static Color _getColorForSeverity(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.critical:
        return Colors.red.shade700;
      case ErrorSeverity.high:
        return Colors.red.shade600;
      case ErrorSeverity.medium:
        return Colors.orange.shade700;
      case ErrorSeverity.low:
        return Colors.blue.shade600;
      case ErrorSeverity.validation:
        return Colors.orange.shade600;
    }
  }

  /// Shows a success snackbar (for positive feedback).
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Shows an info snackbar (for neutral information).
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue.shade600,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        action: action,
      ),
    );
  }

  /// Shows a warning snackbar.
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange.shade600,
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
