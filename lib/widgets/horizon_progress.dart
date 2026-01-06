// lib/widgets/horizon_progress.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;

class HorizonProgress extends StatelessWidget {
  const HorizonProgress({super.key, required this.percentage, this.size = 60});

  final double percentage; // 0.0 to 1.0
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _HorizonPainter(
          percentage: percentage,
          // Use theme primary for the horizon line
          horizonColor: theme.colorScheme.primary.withValues(alpha: 0.5),
          sunGradient: const LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Color(0xFF8B6F47), // Deep Latte Brown base
              Color(0xFFD4AF37), // Branded Gold
              Color(0xFFFFD700), // Radiant Yellow top
            ],
          ),
          glowColor: const Color(0xFFD4AF37).withValues(alpha: 0.3),
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(bottom: size * 0.08),
            child: Text(
              '${(percentage * 100).toInt()}%',
              style: TextStyle(
                fontSize: size * 0.18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HorizonPainter extends CustomPainter {
  _HorizonPainter({
    required this.percentage,
    required this.horizonColor,
    required this.sunGradient,
    required this.glowColor,
  });

  final double percentage;
  final Color horizonColor;
  final Gradient sunGradient;
  final Color glowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.45;
    final horizonY = center.dy + (radius * 0.15); // The line position

    // 1. Draw the "Magical Glow"
    if (percentage > 0.05) {
      final glowPaint = Paint()
        ..color = glowColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(
        Offset(center.dx, horizonY),
        radius * percentage,
        glowPaint,
      );
    }

    // 2. Draw the Sun (The Horizon Progress)
    // Clip to ensure the sun only appears above the line
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, horizonY));

    final sunPaint = Paint()
      ..shader = sunGradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      )
      ..style = PaintingStyle.fill;

    // The sun "rises" by shifting the center down relative to the percentage
    final verticalShift = radius * (1.0 - percentage);
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(center.dx, horizonY + verticalShift),
        radius: radius,
      ),
      math.pi, // Start from 180 degrees (left)
      math.pi, // Sweep 180 degrees (to the right)
      true,
      sunPaint,
    );
    canvas.restore();

    // 3. Draw the Horizon Line
    final linePaint = Paint()
      ..color = horizonColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(center.dx - radius, horizonY),
      Offset(center.dx + radius, horizonY),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(_HorizonPainter oldDelegate) =>
      oldDelegate.percentage != percentage ||
      oldDelegate.horizonColor != horizonColor;
}
