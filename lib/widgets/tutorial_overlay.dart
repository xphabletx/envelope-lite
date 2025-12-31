// lib/widgets/tutorial_overlay.dart

import 'package:flutter/material.dart';
import '../data/tutorial_sequences.dart';
import '../services/tutorial_controller.dart';

class TutorialOverlay extends StatefulWidget {
  final TutorialSequence sequence;
  final VoidCallback onComplete;
  final Map<String, GlobalKey>? spotlightKeys; // Optional keys for highlighting

  const TutorialOverlay({
    super.key,
    required this.sequence,
    required this.onComplete,
    this.spotlightKeys,
  });

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  int _currentStepIndex = 0;
  Rect? _spotlightRect;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  TutorialStep get _currentStep => widget.sequence.steps[_currentStepIndex];
  bool get _isLastStep =>
      _currentStepIndex == widget.sequence.steps.length - 1;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateSpotlight();
    });
  }

  @override
  void didUpdateWidget(TutorialOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateSpotlight();
    });
  }

  void _calculateSpotlight() {
    final spotlightKey = _currentStep.spotlightWidgetKey;
    if (spotlightKey == null || widget.spotlightKeys == null) {
      setState(() => _spotlightRect = null);
      return;
    }

    final key = widget.spotlightKeys![spotlightKey];
    if (key?.currentContext == null) {
      setState(() => _spotlightRect = null);
      return;
    }

    final RenderBox? renderBox =
        key!.currentContext!.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      setState(() => _spotlightRect = null);
      return;
    }

    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    // Special handling for FAB - SpeedDial widget has internal structure
    // The actual button is centered within the widget, so we need to adjust
    Rect spotlightRect;
    if (spotlightKey == 'fab') {
      // For FAB, assume it's a 56x56 button positioned at bottom-right
      // Center the spotlight on the actual FAB button
      final fabSize = 56.0;
      final centerX = offset.dx + (size.width / 2);
      final centerY = offset.dy + (size.height / 2);

      spotlightRect = Rect.fromCenter(
        center: Offset(centerX, centerY),
        width: fabSize,
        height: fabSize,
      );
    } else {
      spotlightRect = Rect.fromLTWH(
        offset.dx,
        offset.dy,
        size.width,
        size.height,
      );
    }

    setState(() {
      _spotlightRect = spotlightRect;
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_isLastStep) {
      _complete();
    } else {
      setState(() {
        _currentStepIndex++;
        _spotlightRect = null; // Reset spotlight
      });
      _animationController.reset();
      _animationController.forward();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _calculateSpotlight();
      });
    }
  }

  void _complete() async {
    await TutorialController.markScreenComplete(widget.sequence.screenId);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Dark overlay with optional spotlight hole
            CustomPaint(
              painter: _SpotlightPainter(
                spotlightRect: _spotlightRect,
                holeRadius: 12.0,
              ),
              child: Container(),
            ),

            // Prevent background taps
            Positioned.fill(
              child: GestureDetector(
                onTap: () {}, // Block taps
                child: Container(color: Colors.transparent),
              ),
            ),

            // Tooltip card
            _buildTooltipCard(context, theme, mediaQuery),
          ],
        ),
      ),
    );
  }

  Widget _buildTooltipCard(
    BuildContext context,
    ThemeData theme,
    MediaQueryData mediaQuery,
  ) {
    // Position tooltip intelligently based on spotlight
    double? top;
    double? bottom;
    final left = 20.0;
    final right = 20.0;

    if (_spotlightRect != null) {
      // Position below or above spotlight based on available space
      final screenHeight = mediaQuery.size.height;
      final spaceAbove = _spotlightRect!.top;
      final spaceBelow = screenHeight - _spotlightRect!.bottom;

      if (spaceBelow > spaceAbove && spaceBelow > 300) {
        // Position below
        top = _spotlightRect!.bottom + 16.0;
      } else if (spaceAbove > 300) {
        // Position above
        bottom = screenHeight - _spotlightRect!.top + 16.0;
      } else {
        // Not enough space, use bottom default
        bottom = 100.0;
      }
    } else {
      // Default position at bottom
      bottom = 100.0;
    }

    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Emoji + Title
            Row(
              children: [
                Text(
                  _currentStep.emoji,
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _currentStep.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Description
            Text(
              _currentStep.description,
              style: theme.textTheme.bodyLarge,
            ),

            const SizedBox(height: 20),

            // Progress indicator
            Row(
              children: [
                Text(
                  '${_currentStepIndex + 1} of ${widget.sequence.steps.length}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LinearProgressIndicator(
                    value: (_currentStepIndex + 1) /
                        widget.sequence.steps.length,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(
                      theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _complete,
                  child: const Text('Skip Tutorial'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _nextStep,
                  child: Text(_isLastStep ? 'Got It! 🎉' : 'Next Tip'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter that creates a dark overlay with an optional spotlight hole
class _SpotlightPainter extends CustomPainter {
  final Rect? spotlightRect;
  final double holeRadius;

  _SpotlightPainter({
    required this.spotlightRect,
    required this.holeRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    final holePaint = Paint()
      ..color = Colors.transparent
      ..blendMode = BlendMode.clear;

    // Draw full overlay
    canvas.saveLayer(Rect.largest, Paint());
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Cut out spotlight hole if present
    if (spotlightRect != null) {
      final expandedRect = spotlightRect!.inflate(8.0);
      final rrect = RRect.fromRectAndRadius(
        expandedRect,
        Radius.circular(holeRadius),
      );
      canvas.drawRRect(rrect, holePaint);

      // Draw glowing border around spotlight
      final borderPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawRRect(rrect, borderPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) {
    return spotlightRect != oldDelegate.spotlightRect ||
        holeRadius != oldDelegate.holeRadius;
  }
}
