// lib/screens/pay_day/widgets/stuffing_envelope_row_cockpit.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../models/envelope.dart';
import '../../../providers/font_provider.dart';
import '../../../providers/locale_provider.dart';
import '../../../providers/pay_day_cockpit_provider.dart';
import '../../../widgets/horizon_progress.dart';
import '../../../theme/app_themes.dart';

class StuffingEnvelopeRowCockpit extends StatefulWidget {
  final Envelope envelope;
  final BinderColorOption binderColors;
  final bool isCurrent;
  final double stuffingAmount;

  const StuffingEnvelopeRowCockpit({
    super.key,
    required this.envelope,
    required this.binderColors,
    this.isCurrent = false,
    required this.stuffingAmount,
  });

  @override
  State<StuffingEnvelopeRowCockpit> createState() => _StuffingEnvelopeRowCockpitState();
}

class _StuffingEnvelopeRowCockpitState extends State<StuffingEnvelopeRowCockpit>
    with SingleTickerProviderStateMixin {

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isCurrent) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(StuffingEnvelopeRowCockpit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrent && !oldWidget.isCurrent) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isCurrent && oldWidget.isCurrent) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Provider.of<LocaleProvider>(context);
    final fontProvider = Provider.of<FontProvider>(context);
    final provider = Provider.of<PayDayCockpitProvider>(context);
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);

    // Calculate real-time progress
    final realTimeProgress = provider.calculateRealTimeProgress(
      widget.envelope,
      widget.stuffingAmount,
    );

    // Calculate days saved
    final daysSaved = provider.calculateDaysSaved(
      widget.envelope,
      widget.stuffingAmount,
    );

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isCurrent ? _pulseAnimation.value : 1.0,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.isCurrent
                  ? widget.binderColors.binderColor.withValues(alpha: 0.15)
                  : widget.binderColors.paperColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.isCurrent
                    ? widget.binderColors.binderColor
                    : widget.binderColors.binderColor.withValues(alpha: 0.2),
                width: widget.isCurrent ? 3 : 1,
              ),
              boxShadow: widget.isCurrent
                  ? [
                      BoxShadow(
                        color: widget.binderColors.binderColor.withValues(alpha: 0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                // Icon
                SizedBox(
                  width: 40,
                  height: 40,
                  child: widget.envelope.getIconWidget(theme, size: 40),
                ),

                const SizedBox(width: 12),

                // Name and temporal delta
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.envelope.name,
                        style: fontProvider.getTextStyle(
                          fontSize: 16,
                          fontWeight: widget.isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: widget.binderColors.envelopeTextColor,
                        ),
                      ),
                      if (daysSaved.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          daysSaved,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Rising Sun (HorizonProgress)
                if (widget.envelope.targetAmount != null)
                  HorizonProgress(
                    percentage: realTimeProgress,
                    size: 60,
                  )
                else
                  const SizedBox(width: 60),

                const SizedBox(width: 12),

                // Amount (animated)
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 400),
                  tween: Tween(
                    begin: widget.envelope.currentAmount,
                    end: widget.envelope.currentAmount + widget.stuffingAmount,
                  ),
                  builder: (context, value, child) {
                    return Text(
                      currency.format(value),
                      style: fontProvider.getTextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: widget.binderColors.envelopeTextColor,
                      ),
                    );
                  },
                ),

                // Current indicator
                if (widget.isCurrent) ...[
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: widget.binderColors.binderColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
