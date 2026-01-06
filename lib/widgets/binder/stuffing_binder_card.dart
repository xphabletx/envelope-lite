// lib/widgets/binder/stuffing_binder_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/envelope_group.dart';
import '../../models/envelope.dart';
import '../../providers/font_provider.dart';
import '../../providers/locale_provider.dart';
import '../../theme/app_themes.dart';
import '../emoji_pie_chart.dart';

class StuffingBinderCard extends StatefulWidget {
  final EnvelopeGroup binder;
  final List<Envelope> envelopes;
  final BinderColorOption binderColors;
  final bool isOpen;
  final VoidCallback? onTap;
  final int? currentStuffingIndex; // Which envelope is currently being stuffed

  const StuffingBinderCard({
    super.key,
    required this.binder,
    required this.envelopes,
    required this.binderColors,
    this.isOpen = false,
    this.onTap,
    this.currentStuffingIndex,
  });

  @override
  State<StuffingBinderCard> createState() => _StuffingBinderCardState();
}

class _StuffingBinderCardState extends State<StuffingBinderCard>
    with SingleTickerProviderStateMixin {

  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOut,
    );

    if (widget.isOpen) {
      _expandController.forward();
    }
  }

  @override
  void didUpdateWidget(StuffingBinderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen != oldWidget.isOpen) {
      if (widget.isOpen) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);
    final locale = Provider.of<LocaleProvider>(context);
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);

    // Calculate binder totals
    final currentTotal = widget.envelopes.fold(
      0.0,
      (sum, e) => sum + e.currentAmount,
    );
    final targetTotal = widget.envelopes.fold(
      0.0,
      (sum, e) => sum + (e.targetAmount ?? 0),
    );

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: CustomPaint(
          painter: _OpenBinderPainter(
            color: widget.binderColors.binderColor,
            spineWidth: 40.0,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: widget.binderColors.paperColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.binderColors.binderColor,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: widget.binder.getIconWidget(theme, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.binder.name,
                        style: fontProvider.getTextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: widget.binderColors.envelopeTextColor,
                        ),
                      ),
                    ),
                    Text(
                      currency.format(currentTotal),
                      style: fontProvider.getTextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: widget.binderColors.envelopeTextColor,
                      ),
                    ),
                  ],
                ),

                // Envelope list (expands when open)
                SizeTransition(
                  sizeFactor: _expandAnimation,
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      Divider(color: widget.binderColors.binderColor.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      ...List.generate(widget.envelopes.length, (index) {
                        final envelope = widget.envelopes[index];
                        final isCurrent = widget.currentStuffingIndex == index;
                        return StuffingEnvelopeRow(
                          envelope: envelope,
                          binderColors: widget.binderColors,
                          isCurrent: isCurrent,
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Painter for the open binder look (extracted from groups_home_screen.dart)
class _OpenBinderPainter extends CustomPainter {
  final Color color;
  final double spineWidth;

  _OpenBinderPainter({
    required this.color,
    this.spineWidth = 60.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final hsl = HSLColor.fromColor(color);
    final baseColor = color;
    final darkerColor =
        hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
    final lighterColor =
        hsl.withLightness((hsl.lightness + 0.1).clamp(0.0, 1.0)).toColor();

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(24),
    );

    // 1. Draw Main Body (Leather Texture Effect)
    final bodyPaint = Paint()..color = baseColor;
    canvas.drawRRect(rrect, bodyPaint);

    // 2. Draw Spine (3D Cylinder Effect)
    final spineRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: spineWidth,
      height: size.height,
    );

    final spineGradient = LinearGradient(
      colors: [baseColor, darkerColor, lighterColor, darkerColor, baseColor],
      stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
    );

    final spinePaint = Paint()..shader = spineGradient.createShader(spineRect);

    // Clip the spine to the rounded corners of the binder
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(spineRect, spinePaint);

    // Add vertical lines to spine to simulate ridges
    final linePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.1)
      ..strokeWidth = 1;

    final ridgeOffset = spineWidth / 3;
    canvas.drawLine(
      Offset(size.width / 2 - ridgeOffset, 0),
      Offset(size.width / 2 - ridgeOffset, size.height),
      linePaint,
    );
    canvas.drawLine(
      Offset(size.width / 2 + ridgeOffset, 0),
      Offset(size.width / 2 + ridgeOffset, size.height),
      linePaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_OpenBinderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.spineWidth != spineWidth;
  }
}

// Simplified envelope row for stuffing screen
class StuffingEnvelopeRow extends StatelessWidget {
  final Envelope envelope;
  final BinderColorOption binderColors;
  final bool isCurrent;

  const StuffingEnvelopeRow({
    super.key,
    required this.envelope,
    required this.binderColors,
    this.isCurrent = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Provider.of<LocaleProvider>(context);
    final fontProvider = Provider.of<FontProvider>(context);
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);

    double? percentage;
    if (envelope.targetAmount != null && envelope.targetAmount! > 0) {
      percentage = (envelope.currentAmount / envelope.targetAmount!).clamp(0.0, 1.0);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrent
            ? binderColors.binderColor.withValues(alpha: 0.1)
            : binderColors.paperColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent
              ? binderColors.binderColor
              : binderColors.binderColor.withValues(alpha: 0.2),
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // Icon
          SizedBox(
            width: 32,
            height: 32,
            child: envelope.getIconWidget(theme, size: 32),
          ),

          const SizedBox(width: 12),

          // Name
          Expanded(
            child: Text(
              envelope.name,
              style: fontProvider.getTextStyle(
                fontSize: 14,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                color: binderColors.envelopeTextColor,
              ),
            ),
          ),

          // Pie chart
          if (percentage != null)
            EmojiPieChart(percentage: percentage, size: 36),

          const SizedBox(width: 12),

          // Amount (animated)
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 400),
            tween: Tween(begin: 0, end: envelope.currentAmount),
            builder: (context, value, child) {
              return Text(
                currency.format(value),
                style: fontProvider.getTextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: binderColors.envelopeTextColor,
                ),
              );
            },
          ),

          // Current indicator
          if (isCurrent) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: binderColors.binderColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
