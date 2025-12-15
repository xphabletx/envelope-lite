import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../models/envelope.dart';
import '../../../providers/font_provider.dart';
import '../../../services/envelope_repo.dart';
import '../../../services/group_repo.dart';
import 'envelope_settings_sheet.dart';

class ModernEnvelopeHeaderCard extends StatelessWidget {
  const ModernEnvelopeHeaderCard({
    super.key,
    required this.envelope,
    required this.repo,
  });

  final Envelope envelope;
  final EnvelopeRepo repo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final currency = NumberFormat.simpleCurrency(locale: 'en_GB');

    // Logic: Progress
    double progress = 0;
    if (envelope.targetAmount != null && envelope.targetAmount! > 0) {
      progress = (envelope.currentAmount / envelope.targetAmount!).clamp(
        0.0,
        1.0,
      );
    }

    // Logic: Pay Days text
    String? payDayText;
    if (envelope.targetAmount != null &&
        envelope.autoFillEnabled &&
        envelope.autoFillAmount != null &&
        envelope.autoFillAmount! > 0) {
      final remaining = envelope.targetAmount! - envelope.currentAmount;
      if (remaining > 0) {
        final cycles = (remaining / envelope.autoFillAmount!).ceil();
        payDayText = '$cycles pay days left';
      } else {
        payDayText = 'Goal reached!';
      }
    }

    return Column(
      children: [
        // 1. THE ENVELOPE (Visual Only)
        Container(
          height: 240,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            // The "Raised" Shadow effect
            boxShadow: [
              BoxShadow(
                // FIX: Modernize deprecation
                color: theme.colorScheme.shadow.withValues(alpha: 0.15),
                blurRadius: 15,
                offset: const Offset(0, 8),
                spreadRadius: 2,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // LAYER 1: The Envelope Body & Flap Painter
              Positioned.fill(
                child: CustomPaint(
                  painter: ClosedEnvelopePainter(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),

              // LAYER 2: The Amount on the Flap
              Positioned(
                top: 45,
                child: Column(
                  children: [
                    Text(
                      currency.format(envelope.currentAmount),
                      // FIX: Use copyWith() for shadows since getTextStyle doesn't support it directly
                      style: fontProvider
                          .getTextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          )
                          .copyWith(
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                    ),
                  ],
                ),
              ),

              // LAYER 3: The "Wax Seal" Emoji (At the tip of the flap)
              Positioned(
                top: 105, // Roughly 45% down where the flap tip lands
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(
                    envelope.emoji ?? '💰',
                    style: const TextStyle(fontSize: 36),
                  ),
                ),
              ),

              // LAYER 4: Progress Bar (Near Bottom)
              if (envelope.targetAmount != null)
                Positioned(
                  bottom: 30,
                  left: 40,
                  right: 40,
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.black.withValues(alpha: 0.2),
                          valueColor: const AlwaysStoppedAnimation(
                            Colors.white,
                          ),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // "50% of £1,000"
                      Text(
                        '${(progress * 100).toInt()}% of ${currency.format(envelope.targetAmount)}',
                        style: fontProvider.getTextStyle(
                          // FIX: Modernize deprecation
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // 2. THE CHIPS (Action Buttons)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Auto-Fill Chip -> Links to Settings
              Expanded(
                child: _InfoChip(
                  icon: Icons.autorenew,
                  label: envelope.autoFillEnabled
                      ? 'Auto-fill: ${currency.format(envelope.autoFillAmount ?? 0)}'
                      : 'Auto-fill Off',
                  subLabel: 'Tap to configure',
                  color: theme.colorScheme.secondaryContainer,
                  textColor: theme.colorScheme.onSecondaryContainer,
                  onTap: () {
                    final groupRepo = GroupRepo(repo.db, repo);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        child: EnvelopeSettingsSheet(
                          envelopeId: envelope.id,
                          repo: repo,
                          groupRepo: groupRepo,
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(width: 12),

              // Target Chip -> Links to Budget (Home Index 2)
              Expanded(
                child: _InfoChip(
                  icon: Icons.track_changes,
                  label: payDayText ?? 'Set Target',
                  subLabel: envelope.targetAmount != null
                      ? 'Goal: ${currency.format(envelope.targetAmount)}'
                      : 'Tap to set goal',
                  color: theme.colorScheme.primaryContainer,
                  textColor: theme.colorScheme.onPrimaryContainer,
                  onTap: () {
                    // Navigate to Budget Tab (Index 2)
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/home',
                      (route) => false,
                      arguments: 2, // 2 is typically the Budget tab index
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- HELPER WIDGET: LARGE ACTION CHIP ---
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subLabel;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.subLabel,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: textColor, size: 20),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subLabel,
                style: TextStyle(
                  // FIX: Modernize deprecation
                  color: textColor.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- NEW PAINTER: CLOSED ENVELOPE LOOK ---
class ClosedEnvelopePainter extends CustomPainter {
  final Color color;

  ClosedEnvelopePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final hsl = HSLColor.fromColor(color);

    // Body (Medium-Dark - mimics the front face behind the flap)
    final bodyPaint = Paint()
      ..color = hsl
          .withLightness((hsl.lightness - 0.05).clamp(0.0, 1.0))
          .toColor()
      ..style = PaintingStyle.fill;

    // Flap (Lightest - hits the light because it's on top)
    final flapPaint = Paint()
      ..color = hsl
          .withLightness((hsl.lightness + 0.05).clamp(0.0, 1.0))
          .toColor()
      ..style = PaintingStyle.fill;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(24),
    );

    // 1. Draw Body
    canvas.drawRRect(rrect, bodyPaint);

    // 2. Draw "Seam" lines for the bottom folds (Optional, subtle detail)
    // This draws the "X" fold lines at the bottom of a closed envelope
    final seamPaint = Paint()
      // FIX: Modernize deprecation
      ..color = Colors.black.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final seamPath = Path();
    seamPath.moveTo(0, size.height);
    seamPath.lineTo(size.width / 2, size.height * 0.55);
    seamPath.lineTo(size.width, size.height);
    canvas.drawPath(seamPath, seamPaint);

    // 3. Draw Flap (Triangle pointing down)
    // Since it's closed, the flap goes further down (~50-55%)
    final flapPath = Path();
    flapPath.moveTo(0, 0);
    flapPath.lineTo(size.width, 0);

    // Curve to tip
    flapPath.quadraticBezierTo(
      size.width / 2,
      size.height * 0.55, // Control point
      size.width / 2,
      size.height * 0.50, // Tip of flap (50% down)
    );
    flapPath.quadraticBezierTo(size.width / 2, size.height * 0.55, 0, 0);
    flapPath.close();

    // Clip flap to rounded corners
    canvas.save();
    canvas.clipRRect(rrect);

    // Drop shadow UNDER the flap to show it sits on top of the body
    canvas.drawShadow(flapPath, Colors.black, 6.0, true);
    canvas.drawPath(flapPath, flapPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
