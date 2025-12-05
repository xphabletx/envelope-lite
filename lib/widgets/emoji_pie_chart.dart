// lib/widgets/emoji_pie_chart.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../providers/app_preferences_provider.dart';

class EmojiPieChart extends StatelessWidget {
  const EmojiPieChart({super.key, required this.percentage, this.size = 60});

  final double percentage; // 0.0 to 1.0
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefsProvider = Provider.of<AppPreferencesProvider>(context);

    // At 100%, show custom celebration emoji instead of pie
    if (percentage >= 1.0) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 500),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: Text(
                prefsProvider.celebrationEmoji,
                style: const TextStyle(fontSize: 40),
              ),
            );
          },
        ),
      );
    }

    // Otherwise show pie chart
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PiePainter(
          percentage: percentage,
          backgroundColor: theme.colorScheme.surface,
          fillColor: theme.colorScheme.secondary,
          borderColor: theme.colorScheme.primary,
        ),
        child: Center(
          child: Text(
            '${(percentage * 100).toInt()}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _PiePainter extends CustomPainter {
  _PiePainter({
    required this.percentage,
    required this.backgroundColor,
    required this.fillColor,
    required this.borderColor,
  });

  final double percentage;
  final Color backgroundColor;
  final Color fillColor;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background circle (empty)
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // Filled pie (using theme secondary color)
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    const startAngle = -math.pi / 2; // Start at top
    final sweepAngle = 2 * math.pi * percentage;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      true,
      fillPaint,
    );

    // Border
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, borderPaint);
  }

  @override
  bool shouldRepaint(_PiePainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.borderColor != borderColor;
  }
}
