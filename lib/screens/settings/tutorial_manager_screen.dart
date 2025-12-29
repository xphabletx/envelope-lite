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
    debugPrint('[TutorialManager] ═══════════════════════════════════════');
    debugPrint('[TutorialManager] User requested navigation to: $screenId');

    // First, reset the tutorial so it will show again
    TutorialController.resetScreen(screenId).then((_) {
      debugPrint('[TutorialManager] ✅ Tutorial "$screenId" reset successfully');

      // Show helpful message based on the screen
      String message;
      switch (screenId) {
        case 'home':
          message = 'Tutorial reset! ✅\n\nClose settings and return to Home to see it.';
          break;
        case 'binders':
          message = 'Tutorial reset! ✅\n\nNavigate to the Binders tab to see it.';
          break;
        case 'envelope_detail':
          message = 'Tutorial reset! ✅\n\nOpen any envelope to see this tutorial.';
          break;
        case 'calendar':
          message = 'Tutorial reset! ✅\n\nNavigate to the Calendar tab to see it.';
          break;
        case 'accounts':
          message = 'Tutorial reset! ✅\n\nNavigate to Accounts to see this tutorial.';
          break;
        case 'settings':
          message = 'Tutorial reset! ✅\n\nYou\'re already in Settings - back out and return to see it.';
          break;
        case 'pay_day':
          message = 'Tutorial reset! ✅\n\nNavigate to Pay Day to see this tutorial.';
          break;
        case 'time_machine':
          message = 'Tutorial reset! ✅\n\nNavigate to Time Machine to see this tutorial.';
          break;
        case 'workspace':
          message = 'Tutorial reset! ✅\n\nNavigate to Workspace Management to see this tutorial.';
          break;
        default:
          message = 'Tutorial reset! ✅\n\nNavigate to the "$screenId" screen to see it.';
      }

      debugPrint('[TutorialManager] Showing message: $message');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
            ),
          ),
        );

        // Refresh the completion status
        _loadStatus();
      }

      debugPrint('[TutorialManager] ═══════════════════════════════════════');
    });
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
                  size: 32,
                ),
                title: Text(
                  tutorial.screenName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${tutorial.steps.length} tips • ${isComplete ? "Completed" : "Not started"}',
                  style: theme.textTheme.bodySmall,
                ),
                trailing: IconButton(
                  icon: Icon(
                    Icons.play_circle_outline,
                    color: theme.colorScheme.primary,
                    size: 32,
                  ),
                  onPressed: () => _navigateToScreen(tutorial.screenId),
                  tooltip: isComplete ? 'Review Tutorial' : 'Start Tutorial',
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
