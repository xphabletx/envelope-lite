// lib/widgets/tutorial_overlay.dart
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

/// Custom tutorial overlay that highlights widgets with holes and shows tooltips
class TutorialOverlay extends StatefulWidget {
  final GlobalKey? targetKey;
  final String title;
  final String description;
  final VoidCallback? onNext;
  final VoidCallback? onSkipTour;
  final VoidCallback? onSkipStep;
  final bool showSkipStep;
  final String? stepCounter;
  final bool blockInteraction;

  const TutorialOverlay({
    super.key,
    this.targetKey,
    required this.title,
    required this.description,
    this.onNext,
    this.onSkipTour,
    this.onSkipStep,
    this.showSkipStep = true,
    this.stepCounter,
    this.blockInteraction = true,
  });

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  Rect? _targetRect;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateTargetRect();
    });
  }

  @override
  void didUpdateWidget(TutorialOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.targetKey != oldWidget.targetKey) {
      _calculateTargetRect();
      _fadeController.reset();
      _fadeController.forward();
    }
  }

  void _calculateTargetRect() {
    if (widget.targetKey?.currentContext == null) {
      setState(() => _targetRect = null);
      return;
    }

    final RenderBox? renderBox =
        widget.targetKey!.currentContext!.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      setState(() => _targetRect = null);
      return;
    }

    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    setState(() {
      _targetRect = Rect.fromLTWH(
        offset.dx,
        offset.dy,
        size.width,
        size.height,
      );
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Dimmed overlay with hole
            CustomPaint(
              painter: _HolePainter(targetRect: _targetRect, holeRadius: 12.0),
              child: Container(),
            ),

            // Tooltip
            if (_targetRect != null)
              _buildTooltip(context)
            else
              _buildCenteredTooltip(context),

            // Block interaction overlay (invisible but catches taps)
            if (widget.blockInteraction)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    // Eat taps to prevent interaction with underlying widgets
                  },
                  child: Container(color: Colors.transparent),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTooltip(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final theme = Theme.of(context);

    // Determine tooltip position based on target location
    bool showBelow = _targetRect!.bottom < screenSize.height / 2;
    bool showAbove = !showBelow;

    double? top;
    double? bottom;
    double left = 16.0;
    double right = 16.0;

    if (showBelow) {
      top = _targetRect!.bottom + 16.0;
    } else if (showAbove) {
      bottom = screenSize.height - _targetRect!.top + 16.0;
    }

    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: _buildTooltipCard(context, theme, showBelow),
    );
  }

  Widget _buildCenteredTooltip(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: _buildTooltipCard(context, theme, true),
      ),
    );
  }

  Widget _buildTooltipCard(
    BuildContext context,
    ThemeData theme,
    bool arrowDown,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.stepCounter != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                widget.stepCounter!,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Text(
            widget.title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.description,
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (widget.onSkipTour != null)
                TextButton(
                  onPressed: () async {
                    await _fadeController.reverse();
                    widget.onSkipTour!();
                  },
                  child: const Text(
                    'Skip Tour',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              const Spacer(),
              if (widget.onSkipStep != null && widget.showSkipStep)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextButton(
                    onPressed: () async {
                      await _fadeController.reverse();
                      widget.onSkipStep!();
                    },
                    child: const Text(
                      'Skip Step',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              if (widget.onNext != null)
                ElevatedButton(
                  onPressed: () async {
                    await _fadeController.reverse();
                    widget.onNext!();
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Next',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Custom painter that creates a dimmed overlay with a hole
class _HolePainter extends CustomPainter {
  final Rect? targetRect;
  final double holeRadius;

  _HolePainter({required this.targetRect, required this.holeRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;

    final holePaint = Paint()
      ..color = Colors.transparent
      ..blendMode = BlendMode.clear;

    // Draw full overlay
    canvas.saveLayer(Rect.largest, Paint());
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Cut out hole if target exists
    if (targetRect != null) {
      final expandedRect = targetRect!.inflate(8.0);
      final rrect = RRect.fromRectAndRadius(
        expandedRect,
        Radius.circular(holeRadius),
      );
      canvas.drawRRect(rrect, holePaint);

      // Draw border around hole
      final borderPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawRRect(rrect, borderPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_HolePainter oldDelegate) {
    return targetRect != oldDelegate.targetRect ||
        holeRadius != oldDelegate.holeRadius;
  }
}

/// Helper widget for typing animation with keyboard sounds
class TypedTextField extends StatefulWidget {
  final TextEditingController controller;
  final String targetText;
  final VoidCallback? onComplete;
  final int typingSpeedMs;

  const TypedTextField({
    super.key,
    required this.controller,
    required this.targetText,
    this.onComplete,
    this.typingSpeedMs = 100,
  });

  @override
  State<TypedTextField> createState() => _TypedTextFieldState();
}

class _TypedTextFieldState extends State<TypedTextField> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _typingTimer;
  int _currentIndex = 0;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  Future<void> _startTyping() async {
    if (_isTyping) return;
    _isTyping = true;

    await Future.delayed(const Duration(milliseconds: 500));

    _typingTimer = Timer.periodic(
      Duration(milliseconds: widget.typingSpeedMs),
      (timer) async {
        if (_currentIndex < widget.targetText.length) {
          setState(() {
            widget.controller.text = widget.targetText.substring(
              0,
              _currentIndex + 1,
            );
            widget.controller.selection = TextSelection.fromPosition(
              TextPosition(offset: widget.controller.text.length),
            );
          });

          // Play keyboard sound
          final char = widget.targetText[_currentIndex];
          if (char == ' ') {
            _playSound('keyboard_space.mp3');
          } else {
            _playSound('keyboard_click.mp3');
          }

          _currentIndex++;
        } else {
          timer.cancel();
          _isTyping = false;
          widget.onComplete?.call();
        }
      },
    );
  }

  Future<void> _playSound(String filename) async {
    try {
      await _audioPlayer.play(AssetSource('sounds/$filename'), volume: 0.3);
    } catch (e) {
      debugPrint('Could not play sound: $filename');
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
