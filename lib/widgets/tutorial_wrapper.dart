// lib/widgets/tutorial_wrapper.dart

import 'package:flutter/material.dart';
import '../data/tutorial_sequences.dart';
import '../services/tutorial_controller.dart';
import 'tutorial_overlay.dart';

/// A wrapper widget that automatically shows a tutorial overlay on first visit
///
/// Usage:
/// ```dart
/// return TutorialWrapper(
///   tutorialSequence: homeTutorial,
///   spotlightKeys: {
///     'fab': _fabKey,
///     'sort_button': _sortButtonKey,
///   },
///   child: Scaffold(...),
/// );
/// ```
class TutorialWrapper extends StatefulWidget {
  final Widget child;
  final TutorialSequence tutorialSequence;
  final Map<String, GlobalKey>? spotlightKeys;

  const TutorialWrapper({
    super.key,
    required this.child,
    required this.tutorialSequence,
    this.spotlightKeys,
  });

  @override
  State<TutorialWrapper> createState() => _TutorialWrapperState();
}

class _TutorialWrapperState extends State<TutorialWrapper>
    with WidgetsBindingObserver, RouteAware {
  bool _showTutorial = false;
  bool _isLoading = true;
  RouteObserver<ModalRoute<dynamic>>? _routeObserver;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkTutorialStatus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route changes
    _routeObserver = RouteObserver<ModalRoute<dynamic>>();
    final route = ModalRoute.of(context);
    if (route != null) {
      _routeObserver!.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _routeObserver?.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // Called when a route has been popped off, and this route is now visible
    // This is when user navigates back from settings after resetting tutorials
    _checkTutorialStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check tutorial status when app comes to foreground
    // This handles the case where user resets tutorials and returns to the screen
    if (state == AppLifecycleState.resumed) {
      _checkTutorialStatus();
    }
  }

  Future<void> _checkTutorialStatus() async {
    debugPrint('[Tutorial] Checking status for screen: ${widget.tutorialSequence.screenId}');

    final isComplete = await TutorialController.isScreenComplete(
      widget.tutorialSequence.screenId,
    );

    debugPrint('[Tutorial] Screen ${widget.tutorialSequence.screenId} - Complete: $isComplete, Will show: ${!isComplete}');

    if (mounted) {
      setState(() {
        _showTutorial = !isComplete;
        _isLoading = false;
      });

      if (_showTutorial) {
        debugPrint('[Tutorial] ✅ Tutorial will be shown for ${widget.tutorialSequence.screenId}');
      } else {
        debugPrint('[Tutorial] ⏭️ Tutorial already completed for ${widget.tutorialSequence.screenId}');
      }
    }
  }

  void _hideTutorial() {
    setState(() {
      _showTutorial = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.child; // Show child immediately, tutorial will overlay
    }

    return Stack(
      children: [
        widget.child,
        if (_showTutorial)
          TutorialOverlay(
            sequence: widget.tutorialSequence,
            onComplete: _hideTutorial,
            spotlightKeys: widget.spotlightKeys,
          ),
      ],
    );
  }
}
