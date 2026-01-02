// lib/screens/envelope/modern_envelope_header_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/envelope.dart';
import '../../models/scheduled_payment.dart';
import '../../providers/font_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/time_machine_provider.dart';
import '../../services/envelope_repo.dart';
import '../../services/group_repo.dart';
import '../../services/account_repo.dart';
import '../../services/scheduled_payment_repo.dart';
import '../add_scheduled_payment_screen.dart'; // Adjust path if necessary
import 'envelope_settings_sheet.dart' show EnvelopeSettingsSheet, EnvelopeSettingsSection;
import '../stats_history_screen.dart';
import 'target_screen.dart';

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
    final locale = Provider.of<LocaleProvider>(context, listen: false);
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);

    showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: true,
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
                        currency.format(p.amount),
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
    final locale = Provider.of<LocaleProvider>(context);
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);
    final timeMachine = Provider.of<TimeMachineProvider>(context);

    // Use time machine reference date if active, otherwise current time
    final referenceDate = timeMachine.futureDate ?? DateTime.now();

    // Logic: Progress (Amount-based)
    double amountProgress = 0;
    if (envelope.targetAmount != null && envelope.targetAmount! > 0) {
      amountProgress = (envelope.currentAmount / envelope.targetAmount!).clamp(
        0.0,
        1.0,
      );
    }

    // Logic: Time Progress (Timestamp-based for granular progress)
    double timeProgress = 0;
    int daysRemaining = 0;
    DateTime? startDate;
    if (envelope.targetDate != null) {
      // Determine start date based on user's selected type
      final targetStartDateType = envelope.targetStartDateType ?? TargetStartDateType.fromToday;

      switch (targetStartDateType) {
        case TargetStartDateType.fromToday:
          // Start from beginning of today (00:00:01)
          startDate = DateTime(
            referenceDate.year,
            referenceDate.month,
            referenceDate.day,
            0, 0, 1,
          );
          break;

        case TargetStartDateType.fromEnvelopeCreation:
          // Use envelope creation date, or fallback to lastUpdated, or today
          if (envelope.createdAt != null) {
            startDate = DateTime(
              envelope.createdAt!.year,
              envelope.createdAt!.month,
              envelope.createdAt!.day,
              0, 0, 1,
            );
          } else if (envelope.lastUpdated != null) {
            // Fallback for legacy envelopes without createdAt
            startDate = DateTime(
              envelope.lastUpdated!.year,
              envelope.lastUpdated!.month,
              envelope.lastUpdated!.day,
              0, 0, 1,
            );
          } else {
            // Ultimate fallback - use today
            startDate = DateTime(
              referenceDate.year,
              referenceDate.month,
              referenceDate.day,
              0, 0, 1,
            );
          }
          break;

        case TargetStartDateType.customDate:
          // Use custom date if provided, otherwise fallback to today
          if (envelope.customTargetStartDate != null) {
            startDate = DateTime(
              envelope.customTargetStartDate!.year,
              envelope.customTargetStartDate!.month,
              envelope.customTargetStartDate!.day,
              0, 0, 1,
            );
          } else {
            // Fallback if custom date not set
            startDate = DateTime(
              referenceDate.year,
              referenceDate.month,
              referenceDate.day,
              0, 0, 1,
            );
          }
          break;
      }

      // Target date at midnight + 1 second (00:00:01)
      final targetWithTime = DateTime(
        envelope.targetDate!.year,
        envelope.targetDate!.month,
        envelope.targetDate!.day,
        0, 0, 1, // 00:00:01
      );

      // Calculate using full timestamps for granular progress (microseconds for 2 decimal precision)
      final totalDuration = targetWithTime.difference(startDate);
      final elapsedDuration = referenceDate.difference(startDate);

      // Progress based on actual time elapsed (not just days)
      // Using microseconds gives us sub-second precision for accurate percentage
      timeProgress = totalDuration.inMicroseconds > 0
          ? (elapsedDuration.inMicroseconds / totalDuration.inMicroseconds).clamp(0.0, 1.0)
          : 0.0;

      daysRemaining = targetWithTime.difference(referenceDate).inDays;
    }

    // Determine which progress to show
    double progress = 0;
    String progressText = '';

    if (envelope.targetAmount != null && envelope.targetDate != null) {
      // Both amount and time targets - show amount progress with time info
      progress = amountProgress;
      if (daysRemaining < 0) {
        final daysOverdue = daysRemaining.abs();
        progressText = '${(amountProgress * 100).toStringAsFixed(2)}% • $daysOverdue days overdue';
      } else {
        progressText = '${(amountProgress * 100).toStringAsFixed(2)}% • $daysRemaining days left';
      }
    } else if (envelope.targetAmount != null) {
      // Amount target only
      progress = amountProgress;
      progressText = '${(amountProgress * 100).toStringAsFixed(2)}% of ${currency.format(envelope.targetAmount)}';
    } else if (envelope.targetDate != null) {
      // Time target only
      progress = timeProgress;
      if (daysRemaining < 0) {
        final daysOverdue = daysRemaining.abs();
        progressText = '${(timeProgress * 100).toStringAsFixed(2)}% • $daysOverdue days overdue';
      } else {
        progressText = '${(timeProgress * 100).toStringAsFixed(2)}% • $daysRemaining days to ${DateFormat('MMM d').format(envelope.targetDate!)}';
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
                left: 40,
                right: 40,
                child: Column(
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
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
                  child: envelope.getIconWidget(theme, size: 36),
                ),
              ),

              // LAYER 4: Progress Bar
              if (envelope.targetAmount != null || envelope.targetDate != null)
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
                        progressText,
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
                        // Check if time machine is active
                        final timeMachine = Provider.of<TimeMachineProvider>(context, listen: false);
                        if (timeMachine.shouldBlockModifications()) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(timeMachine.getBlockedActionMessage()),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                          return;
                        }

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
                              scheduledPaymentRepo: scheduledPaymentRepo,
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

        // Swipe Hint
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            '← Swipe left or right for next/previous envelope →',
            style: fontProvider.getTextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            textAlign: TextAlign.center,
          ),
        ),

        // 2. THE CHIPS (2 Wider Chips for Auto-Fill & Scheduled Payments)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: StreamBuilder<List<ScheduledPayment>>(
            stream: scheduledPaymentRepo.getPaymentsForEnvelope(envelope.id),
            initialData: const [], // Provide initial data to prevent delay
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
                  // 1. Auto-Fill Chip (Wider)
                  Expanded(
                    flex: 1,
                    child: _InfoChip(
                      icon: Icons.autorenew,
                      label: envelope.autoFillEnabled
                          ? 'Auto-fill: ${currency.format(envelope.autoFillAmount ?? 0)}'
                          : 'Auto-fill Off',
                      subLabel: 'Tap for details',
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
                              scheduledPaymentRepo: scheduledPaymentRepo,
                              initialSection: EnvelopeSettingsSection.autofill,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 2. Scheduled Payment Chip (Wider)
                  Expanded(
                    flex: 1,
                    child: _InfoChip(
                      icon: Icons.calendar_month,
                      label: hasPayments
                          ? (payments.length > 1
                              ? '${payments.length} Payments'
                              : 'Due: ${DateFormat('d MMM').format(nextPayment!.nextDueDate)}')
                          : 'Schedule: Off',
                      subLabel: hasPayments
                          ? (payments.length > 1
                              ? 'Next: ${DateFormat('d MMM').format(nextPayment!.nextDueDate)}'
                              : currency.format(nextPayment!.amount))
                          : 'Tap for details',
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
                          // Show settings sheet scrolled to scheduled payments section
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
                                scheduledPaymentRepo: scheduledPaymentRepo,
                                initialSection: EnvelopeSettingsSection.scheduledPayments,
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

        // 3. LARGER TARGET TILE
        if (envelope.targetAmount != null || envelope.targetDate != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _LargeTargetTile(
              envelope: envelope,
              repo: repo,
              groupRepo: groupRepo,
              accountRepo: accountRepo,
              amountProgress: amountProgress,
              timeProgress: timeProgress,
              daysRemaining: daysRemaining,
              startDate: startDate,
              currency: currency,
              fontProvider: fontProvider,
              theme: theme,
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
                  height: 1.2,
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

// --- HELPER WIDGET: LARGE TARGET TILE ---
class _LargeTargetTile extends StatelessWidget {
  final Envelope envelope;
  final EnvelopeRepo repo;
  final GroupRepo groupRepo;
  final AccountRepo accountRepo;
  final double amountProgress;
  final double timeProgress;
  final int daysRemaining;
  final DateTime? startDate;
  final NumberFormat currency;
  final FontProvider fontProvider;
  final ThemeData theme;

  const _LargeTargetTile({
    required this.envelope,
    required this.repo,
    required this.groupRepo,
    required this.accountRepo,
    required this.amountProgress,
    required this.timeProgress,
    required this.daysRemaining,
    required this.startDate,
    required this.currency,
    required this.fontProvider,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final hasAmountTarget = envelope.targetAmount != null;
    final hasTimeTarget = envelope.targetDate != null;

    return Material(
      color: theme.colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TargetScreen(
                envelope: envelope,
                envelopeRepo: repo,
                groupRepo: groupRepo,
                accountRepo: accountRepo,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.track_changes,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Target Progress',
                      style: fontProvider.getTextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  Text(
                    'Tap for details',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.6),
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Amount Progress
              if (hasAmountTarget) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Amount Progress',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                      ),
                    ),
                    Text(
                      '${(amountProgress * 100).toStringAsFixed(1)}%',
                      style: fontProvider.getTextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: amountProgress,
                    backgroundColor: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation(theme.colorScheme.secondary),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${currency.format(envelope.currentAmount)} of ${currency.format(envelope.targetAmount)} • ${currency.format(envelope.targetAmount! - envelope.currentAmount)} remaining',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                  ),
                ),
                if (hasTimeTarget) const SizedBox(height: 16),
              ],

              // Time Progress
              if (hasTimeTarget) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Time Progress',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                      ),
                    ),
                    Text(
                      '${(timeProgress * 100).toStringAsFixed(1)}%',
                      style: fontProvider.getTextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: timeProgress,
                    backgroundColor: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation(theme.colorScheme.tertiary),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  startDate != null
                      ? '${DateFormat('MMM d').format(startDate!)} → ${DateFormat('MMM d, yyyy').format(envelope.targetDate!)} • $daysRemaining days remaining'
                      : '$daysRemaining days until ${DateFormat('MMM d, yyyy').format(envelope.targetDate!)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
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
