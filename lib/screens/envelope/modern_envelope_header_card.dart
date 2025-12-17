// lib/screens/envelope/modern_envelope_header_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/envelope.dart';
import '../../models/scheduled_payment.dart';
import '../../providers/font_provider.dart';
import '../../services/envelope_repo.dart';
import '../../services/group_repo.dart';
import '../../services/account_repo.dart';
import '../../services/scheduled_payment_repo.dart';
import '../add_scheduled_payment_screen.dart'; // Adjust path if necessary
import 'envelope_settings_sheet.dart';
import '../stats_history_screen.dart';

class ModernEnvelopeHeaderCard extends StatelessWidget {
  const ModernEnvelopeHeaderCard({
    super.key,
    required this.envelope,
    required this.repo,
    required this.groupRepo,
    required this.accountRepo,
    required this.scheduledPaymentRepo,
  });

  final Envelope envelope;
  final EnvelopeRepo repo;
  final GroupRepo groupRepo;
  final AccountRepo accountRepo;
  final ScheduledPaymentRepo scheduledPaymentRepo;

  void _showScheduledPaymentsList(
    BuildContext context,
    List<ScheduledPayment> payments,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Scheduled Payments',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (payments.isEmpty)
                const Text('No scheduled payments for this envelope.'),
              ...payments.map(
                (p) => ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(p.name),
                  subtitle: Text(
                    'Due: ${DateFormat('d MMM yyyy').format(p.nextDueDate)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        NumberFormat.simpleCurrency(
                          locale: 'en_GB',
                        ).format(p.amount),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                  onTap: () {
                    // LINK: Edit existing payment
                    Navigator.pop(context); // Close sheet
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddScheduledPaymentScreen(
                          repo: repo,
                          paymentToEdit: p, // Pass the payment for editing
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context); // Close sheet
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddScheduledPaymentScreen(
                        repo: repo,
                        preselectedEnvelopeId: envelope.id,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Another Payment'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

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
        // 1. THE ENVELOPE (Vector Paint + Data Overlay)
        Container(
          height: 240,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            // The "Raised" Shadow effect
            boxShadow: [
              BoxShadow(
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

              // LAYER 3: The "Wax Seal" Emoji
              Positioned(
                top: 100,
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

              // LAYER 4: Progress Bar
              if (envelope.targetAmount != null)
                Positioned(
                  bottom: 20,
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
                      const SizedBox(height: 12),
                      Text(
                        '${(progress * 100).toInt()}% of ${currency.format(envelope.targetAmount)}',
                        style: fontProvider.getTextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

              // LAYER 5: Icon Buttons on Envelope
              Positioned(
                top: 16,
                right: 16,
                child: Row(
                  children: [
                    _EnvelopeIconButton(
                      icon: Icons.bar_chart,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => StatsHistoryScreen(
                              repo: repo,
                              initialEnvelopeIds: {envelope.id},
                              title: '${envelope.name} - History',
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    _EnvelopeIconButton(
                      icon: Icons.settings,
                      onTap: () {
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
                              accountRepo: accountRepo,
                            ),
                          ),
                        );
                      },
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
          child: StreamBuilder<List<ScheduledPayment>>(
            stream: scheduledPaymentRepo.getPaymentsForEnvelope(envelope.id),
            builder: (context, snapshot) {
              final payments = snapshot.data ?? [];
              final hasPayments = payments.isNotEmpty;
              ScheduledPayment? nextPayment;

              if (hasPayments) {
                // Find nearest future payment
                payments.sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));
                nextPayment = payments.first;
              }

              return Row(
                children: [
                  // 1. Auto-Fill Chip
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
                              accountRepo: accountRepo,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 2. Target Chip
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
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          '/home',
                          (route) => false,
                          arguments: 2, // Budget tab index
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 3. Scheduled Payment Chip
                  Expanded(
                    child: _InfoChip(
                      icon: Icons.calendar_month,
                      label: hasPayments
                          ? 'Due: ${DateFormat('d MMM').format(nextPayment!.nextDueDate)}'
                          : 'Schedule: Off',
                      subLabel: hasPayments
                          // FIX: Added '!' to assert nextPayment is not null here
                          ? currency.format(nextPayment!.amount)
                          : 'Tap to add',
                      color: hasPayments
                          ? theme.colorScheme.tertiaryContainer
                          : theme.colorScheme.surfaceContainerHighest,
                      textColor: hasPayments
                          ? theme.colorScheme.onTertiaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                      onTap: () {
                        if (hasPayments) {
                          _showScheduledPaymentsList(context, payments);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddScheduledPaymentScreen(
                                repo: repo,
                                preselectedEnvelopeId: envelope.id,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              );
            },
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
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
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subLabel,
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.7),
                  fontSize: 10,
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

// --- PAINTER: CLOSED ENVELOPE LOOK ---
class ClosedEnvelopePainter extends CustomPainter {
  final Color color;

  ClosedEnvelopePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final hsl = HSLColor.fromColor(color);

    // Body
    final bodyPaint = Paint()
      ..color = hsl
          .withLightness((hsl.lightness - 0.05).clamp(0.0, 1.0))
          .toColor()
      ..style = PaintingStyle.fill;

    // Flap
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

    // 2. Draw "Seam" lines
    final seamPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final seamPath = Path();
    seamPath.moveTo(0, size.height);
    seamPath.lineTo(size.width / 2, size.height * 0.55);
    seamPath.lineTo(size.width, size.height);
    canvas.drawPath(seamPath, seamPaint);

    // 3. Draw Flap
    final flapPath = Path();
    flapPath.moveTo(0, 0);
    flapPath.lineTo(size.width, 0);
    flapPath.quadraticBezierTo(
      size.width / 2,
      size.height * 0.55,
      size.width / 2,
      size.height * 0.50,
    );
    flapPath.quadraticBezierTo(size.width / 2, size.height * 0.55, 0, 0);
    flapPath.close();

    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawShadow(flapPath, Colors.black, 6.0, true);
    canvas.drawPath(flapPath, flapPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- HELPER WIDGET: ENVELOPE ICON BUTTON ---
class _EnvelopeIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _EnvelopeIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
