// lib/screens/settings/tutorial_manager_screen.dart

import 'package:flutter/material.dart';
import '../../data/tutorial_sequences.dart';
import '../../services/tutorial_controller.dart';
import '../../services/envelope_repo.dart';

class TutorialManagerScreen extends StatefulWidget {
  const TutorialManagerScreen({
    super.key,
    this.repo,
  });

  final EnvelopeRepo? repo;

  @override
  State<TutorialManagerScreen> createState() => _TutorialManagerScreenState();
}

class _TutorialManagerScreenState extends State<TutorialManagerScreen> {
  Map<String, bool> _completionStatus = {};

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final status = await TutorialController.getAllCompletionStatus();
    setState(() => _completionStatus = status);
  }

  Future<void> _resetScreen(String screenId) async {
    await TutorialController.resetScreen(screenId);
    await _loadStatus();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tutorial reset! It will show next time you visit that screen.',
          ),
        ),
      );
    }
  }

  Future<void> _resetAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset All Tutorials?'),
        content: const Text(
          'All tutorials will show again when you visit each screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await TutorialController.resetAll();
      await _loadStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ All tutorials reset!')),
        );
      }
    }
  }

  void _navigateToScreen(String screenId) {
    // Navigate to the appropriate screen based on screenId
    // This will be implemented when the screen has TutorialWrapper
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Navigate to the "$screenId" tab in the main screen to see this tutorial.',
        ),
        duration: const Duration(seconds: 3),
      ),
    );

    // Close settings to return to main app
    Navigator.of(context).popUntil((route) => route.isFirst);

    // TODO: Navigate to specific tab based on screenId
    // This would require passing a callback or using a navigator key
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tutorial Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetAll,
            tooltip: 'Reset All',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Text(
            'Manage Tutorials',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Replay tutorials for specific screens. They\'ll show again next time you visit.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),

          // Tutorial list
          ...allTutorials.map((tutorial) {
            final isComplete = _completionStatus[tutorial.screenId] ?? false;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                onTap: () => _navigateToScreen(tutorial.screenId),
                leading: Icon(
                  isComplete ? Icons.check_circle : Icons.help_outline,
                  color: isComplete ? Colors.green : theme.colorScheme.primary,
                ),
                title: Text(tutorial.screenName),
                subtitle: Text(
                  '${tutorial.steps.length} tips • Tap to navigate',
                  style: theme.textTheme.bodySmall,
                ),
                trailing: isComplete
                    ? TextButton(
                        onPressed: () => _resetScreen(tutorial.screenId),
                        child: const Text('Replay'),
                      )
                    : Text(
                        'Not started',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
              ),
            );
          }),

          const SizedBox(height: 24),

          // Reset all button
          FilledButton.icon(
            onPressed: _resetAll,
            icon: const Icon(Icons.refresh),
            label: const Text('Reset All Tutorials'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ],
      ),
    );
  }
}
