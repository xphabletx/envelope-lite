// lib/widgets/migration_overlay.dart
// Migration UI overlay that blocks user interaction during cloud restore
// Ensures data integrity by preventing access to partially-loaded Hive boxes

import 'package:flutter/material.dart';

/// Full-screen overlay shown during cloud migration
///
/// Design principles:
/// - **Blocking**: Prevents user from accessing app until migration completes
/// - **Informative**: Shows progress and status messages
/// - **Error-resilient**: Displays errors without crashing
class RestorationOverlay extends StatelessWidget {
  final Stream<MigrationProgress> progressStream;
  final VoidCallback? onCancel;

  const RestorationOverlay({
    super.key,
    required this.progressStream,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: StreamBuilder<MigrationProgress>(
            stream: progressStream,
            builder: (context, snapshot) {
              final progress = snapshot.data ?? MigrationProgress.initial();

              if (progress.hasError) {
                return _buildErrorView(context, progress);
              }

              if (progress.isComplete) {
                return _buildCompleteView(context);
              }

              return _buildProgressView(context, progress);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildProgressView(BuildContext context, MigrationProgress progress) {
    final percentage = (progress.progress * 100).toInt();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Animated progress indicator
        SizedBox(
          width: 80,
          height: 80,
          child: CircularProgressIndicator(
            value: progress.progress,
            strokeWidth: 6,
            backgroundColor: Colors.grey.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Main title
        Text(
          'Restoring your budget...',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        // Subtitle
        Text(
          'This only happens once.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // Percentage and current step
        Text(
          '$percentage%',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        // Current step description
        if (progress.currentStep.isNotEmpty)
          Text(
            progress.currentStep,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),

        // Item count if available
        if (progress.itemsProcessed > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${progress.itemsProcessed} items restored',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),

        // Cancel button (optional)
        if (onCancel != null)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: TextButton(
              onPressed: onCancel,
              child: const Text('Cancel and use offline'),
            ),
          ),
      ],
    );
  }

  Widget _buildCompleteView(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.check_circle,
          size: 80,
          color: Colors.green,
        ),
        const SizedBox(height: 24),
        Text(
          'Restoration complete!',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Loading your budget...',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView(BuildContext context, MigrationProgress progress) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.error_outline,
          size: 80,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: 24),
        Text(
          'Restoration failed',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          progress.errorMessage ?? 'An unknown error occurred',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: onCancel,
              child: const Text('Continue offline'),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: () {
                // Trigger retry - implementation depends on your setup
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Progress data model for migration
class MigrationProgress {
  final double progress; // 0.0 to 1.0
  final String currentStep;
  final int itemsProcessed;
  final bool isComplete;
  final bool hasError;
  final String? errorMessage;

  MigrationProgress({
    required this.progress,
    required this.currentStep,
    required this.itemsProcessed,
    this.isComplete = false,
    this.hasError = false,
    this.errorMessage,
  });

  factory MigrationProgress.initial() {
    return MigrationProgress(
      progress: 0.0,
      currentStep: 'Initializing...',
      itemsProcessed: 0,
    );
  }

  factory MigrationProgress.step({
    required double progress,
    required String step,
    int itemsProcessed = 0,
  }) {
    return MigrationProgress(
      progress: progress,
      currentStep: step,
      itemsProcessed: itemsProcessed,
    );
  }

  factory MigrationProgress.complete({int itemsProcessed = 0}) {
    return MigrationProgress(
      progress: 1.0,
      currentStep: 'Complete',
      itemsProcessed: itemsProcessed,
      isComplete: true,
    );
  }

  factory MigrationProgress.error(String message) {
    return MigrationProgress(
      progress: 0.0,
      currentStep: 'Failed',
      itemsProcessed: 0,
      hasError: true,
      errorMessage: message,
    );
  }
}
