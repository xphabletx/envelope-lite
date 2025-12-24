// lib/widgets/budget/time_machine_transition.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/font_provider.dart';

class TimeMachineTransition extends StatefulWidget {
  const TimeMachineTransition({
    super.key,
    required this.targetDate,
  });

  final DateTime targetDate;

  @override
  State<TimeMachineTransition> createState() => _TimeMachineTransitionState();
}

class _TimeMachineTransitionState extends State<TimeMachineTransition>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.elasticOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final dateFormat = DateFormat('MMMM d, yyyy');

    return Material(
      color: Colors.black.withValues(alpha: 0.9),
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 120,
                      color: theme.colorScheme.secondary.withValues(
                        alpha: _fadeAnimation.value,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'TIME MACHINE',
                      style: fontProvider.getTextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.secondary.withValues(
                          alpha: _fadeAnimation.value,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Traveling to...',
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.white.withValues(
                          alpha: _fadeAnimation.value * 0.7,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dateFormat.format(widget.targetDate),
                      style: fontProvider.getTextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withValues(
                          alpha: _fadeAnimation.value,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
