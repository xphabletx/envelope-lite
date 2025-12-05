import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../models/envelope.dart';

class EnvelopeHeaderCard extends StatelessWidget {
  const EnvelopeHeaderCard({super.key, required this.envelope, this.onTap});

  final Envelope envelope;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormatter = NumberFormat.currency(symbol: '£');

    // Calculate progress percentage
    final progress = envelope.targetAmount != null && envelope.targetAmount! > 0
        ? (envelope.currentAmount / envelope.targetAmount!).clamp(0.0, 1.0)
        : 0.0;

    // Calculate pay days until target (if auto-fill is enabled)
    int? payDaysUntilTarget;
    if (envelope.targetAmount != null &&
        envelope.autoFillEnabled &&
        envelope.autoFillAmount != null &&
        envelope.autoFillAmount! > 0) {
      final remaining = envelope.targetAmount! - envelope.currentAmount;
      if (remaining > 0) {
        payDaysUntilTarget = (remaining / envelope.autoFillAmount!).ceil();
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // The beautiful 3D envelope (Wider "Bank Note" Aspect Ratio)
            _RealisticEnvelope(
              emoji: envelope.emoji ?? '💰',
              primaryColor: theme.colorScheme.primary,
            ),

            const SizedBox(height: 24),

            // Current Amount (large)
            Text(
              currencyFormatter.format(envelope.currentAmount),
              style: GoogleFonts.caveat(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),

            // Target info (if set)
            if (envelope.targetAmount != null) ...[
              const SizedBox(height: 4),
              Text(
                'of ${currencyFormatter.format(envelope.targetAmount!)}',
                style: GoogleFonts.caveat(
                  fontSize: 24,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.secondary,
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Subtitle (if set)
            if (envelope.subtitle != null && envelope.subtitle!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  envelope.subtitle!,
                  style: GoogleFonts.caveat(
                    fontSize: 18,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            // Info chips row
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                // Auto-fill status chip
                if (envelope.autoFillEnabled && envelope.autoFillAmount != null)
                  _InfoChip(
                    icon: Icons.autorenew,
                    label:
                        'Auto-fill: ${currencyFormatter.format(envelope.autoFillAmount!)}',
                    color: theme.colorScheme.secondary,
                  ),

                // Pay days until target chip
                if (payDaysUntilTarget != null)
                  _InfoChip(
                    icon: Icons.calendar_today,
                    label: payDaysUntilTarget == 1
                        ? '1 pay day to target'
                        : '$payDaysUntilTarget pay days to target',
                    color:
                        theme.colorScheme.tertiary ?? theme.colorScheme.primary,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Info chip widget for auto-fill and pay day calculations
class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// The gorgeous 3D envelope (Refactored with bottom flap and deeper shadows)
class _RealisticEnvelope extends StatelessWidget {
  final String emoji;
  final Color primaryColor;

  const _RealisticEnvelope({required this.emoji, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    // Dimensions for "Bank Note" aspect ratio
    const envelopeWidth = 320.0;
    const envelopeHeight = 160.0;
    const flapHeight = 90.0;
    const emojiSize = 42.0;

    // Define color variations for depth based on the theme's primary color
    final HSLColor primaryHSL = HSLColor.fromColor(primaryColor);
    final Color backBodyColor = primaryHSL.withLightness(0.85).toColor();
    // Top flap is slightly lighter to catch "light"
    final Color topFlapColor = primaryHSL.withLightness(0.88).toColor();
    // Bottom flap is slightly darker to show it's "inside" or under the top flap
    final Color bottomFlapColor = primaryHSL.withLightness(0.82).toColor();

    return SizedBox(
      width: envelopeWidth,
      height: envelopeHeight + 40, // Increased extra space for deeper shadow
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // LAYER 1: The Main Body Background (Rectangular base)
          Positioned(
            top: flapHeight * 0.35,
            child: Container(
              height: envelopeHeight - (flapHeight * 0.35),
              width: envelopeWidth,
              decoration: BoxDecoration(
                color: backBodyColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2), // Darker shadow
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
            ),
          ),

          // LAYER 2: The Bottom Pocket Flap (The new part!)
          // This is painted over the background body
          Positioned(
            top: flapHeight * 0.35,
            child: CustomPaint(
              size: Size(envelopeWidth, envelopeHeight - (flapHeight * 0.35)),
              painter: BottomPocketPainter(
                color: bottomFlapColor,
                shadowColor: primaryColor.withOpacity(0.3),
              ),
            ),
          ),

          // LAYER 3: The Top Flap with Physical Shadow
          Positioned(
            top: 0,
            child: PhysicalShape(
              color: topFlapColor,
              elevation: 14.0, // Increased elevation for more depth
              shadowColor: primaryColor.withOpacity(0.6), // Stronger shadow
              clipper: _EnvelopeFlapClipper(flapHeight: flapHeight),
              child: Container(
                height: flapHeight,
                width: envelopeWidth,
                decoration: BoxDecoration(
                  // Subtle gradient to make the flap look curved
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white.withOpacity(0.5), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),

          // LAYER 4: The Emoji Sticker (Raised higher with deeper shadow)
          Positioned(
            top: flapHeight - (emojiSize / 1.1), // Raised position slightly
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                shape: BoxShape.circle,
                boxShadow: [
                  // Deeper, multi-layered shadow for a "floating" sticker effect
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                  BoxShadow(
                    color: primaryColor.withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: -2,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Text(emoji, style: TextStyle(fontSize: emojiSize)),
            ),
          ),
        ],
      ),
    );
  }
}

// Painter for the bottom triangular pocket
class BottomPocketPainter extends CustomPainter {
  final Color color;
  final Color shadowColor;

  BottomPocketPainter({required this.color, required this.shadowColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    // Start at bottom left
    path.moveTo(0, size.height);
    // Draw to bottom right
    path.lineTo(size.width, size.height);
    // Draw up to the center point, slightly below the top edge of this layer
    path.lineTo(size.width / 2, size.height * 0.15);
    // Close back to bottom left
    path.close();

    // Draw a subtle shadow underneath the top edge of this pocket
    // to separate it from the inside of the envelope
    canvas.drawShadow(path.shift(const Offset(0, -2)), shadowColor, 4, false);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom Clipper for the top flap
class _EnvelopeFlapClipper extends CustomClipper<Path> {
  final double flapHeight;

  _EnvelopeFlapClipper({required this.flapHeight});

  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0); // Top left
    path.lineTo(size.width, 0); // Top right

    // Draw down to the bottom center tip with a soft curve
    path.lineTo(size.width / 2 + 15, flapHeight - 6);
    path.quadraticBezierTo(
      size.width / 2,
      flapHeight + 6, // Control point below tip
      size.width / 2 - 15,
      flapHeight - 6, // End point
    );

    path.lineTo(0, 0); // Back to top left
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
