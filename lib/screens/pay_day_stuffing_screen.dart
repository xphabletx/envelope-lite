// lib/screens/pay_day_stuffing_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/envelope.dart';
import '../services/envelope_repo.dart';
import '../providers/font_provider.dart';

class PayDayStuffingScreen extends StatefulWidget {
  const PayDayStuffingScreen({
    super.key,
    required this.repo,
    required this.allocations,
    required this.envelopes,
    required this.totalAmount,
  });

  final EnvelopeRepo repo;
  final Map<String, double> allocations;
  final List<Envelope> envelopes;
  final double totalAmount;

  @override
  State<PayDayStuffingScreen> createState() => _PayDayStuffingScreenState();
}

class _PayDayStuffingScreenState extends State<PayDayStuffingScreen>
    with SingleTickerProviderStateMixin {
  int currentIndex = 0;
  double currentProgress = 0.0;
  bool stuffingComplete = false;
  String? errorMessage;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Setup pulse animation for current envelope
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startStuffing();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startStuffing() async {
    for (int i = 0; i < widget.envelopes.length; i++) {
      if (!mounted) return;

      setState(() {
        currentIndex = i;
        currentProgress = 0.0;
      });

      final env = widget.envelopes[i];
      final amount = widget.allocations[env.id] ?? 0.0;

      // Animate progress bar filling up
      for (double progress = 0.0; progress <= 1.0; progress += 0.05) {
        await Future.delayed(const Duration(milliseconds: 50));
        if (mounted) {
          setState(() => currentProgress = progress);
        }
      }

      // Actually deposit the money into Firestore
      try {
        await widget.repo.deposit(
          envelopeId: env.id,
          amount: amount,
          description: 'Pay Day',
          date: DateTime.now(),
        );
      } catch (e) {
        debugPrint('Error depositing to ${env.name}: $e');
        if (mounted) {
          setState(() => errorMessage = 'Error filling ${env.name}');
        }
        // Wait a bit to show error, then continue
        await Future.delayed(const Duration(seconds: 1));
      }

      // Small pause before moving to next envelope
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // All done!
    if (mounted) {
      setState(() => stuffingComplete = true);

      // Show success dialog after brief pause
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        _showSuccessDialog();
      }
    }
  }

  void _showSuccessDialog() {
    final totalStuffed = widget.allocations.values.fold(0.0, (a, b) => a + b);
    final currency = NumberFormat.currency(symbol: '£');
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final theme = Theme.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ScaleTransition(
        scale: CurvedAnimation(
          parent: _pulseController,
          curve: Curves.elasticOut,
        ),
        child: AlertDialog(
          backgroundColor: theme.scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 72)),
              const SizedBox(height: 16),
              Text(
                'Pay Day Complete!',
                style: fontProvider.getTextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                currency.format(totalStuffed),
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.secondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.envelopes.length} ${widget.envelopes.length == 1 ? 'envelope' : 'envelopes'} filled!',
                style: fontProvider.getTextStyle(
                  fontSize: 20,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext); // Close dialog
                Navigator.pop(context); // Close stuffing screen
                Navigator.pop(context); // Close allocation screen
                Navigator.pop(context); // Close amount screen
              },
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.secondary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
              child: Text(
                'Done!',
                style: fontProvider.getTextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final currency = NumberFormat.currency(symbol: '£');

    return WillPopScope(
      // Prevent back button during stuffing
      onWillPop: () async => stuffingComplete,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Title
                Text(
                  'Stuffing Envelopes... 🎉',
                  style: fontProvider.getTextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Show error if any
                if (errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMessage!,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Envelope list with progress
                Expanded(
                  child: ListView.builder(
                    itemCount: widget.envelopes.length,
                    itemBuilder: (context, i) {
                      final env = widget.envelopes[i];
                      final amount = widget.allocations[env.id] ?? 0.0;
                      final isComplete = i < currentIndex;
                      final isCurrent = i == currentIndex;
                      final isPending = i > currentIndex;
                      final progress = isCurrent
                          ? currentProgress
                          : (isComplete ? 1.0 : 0.0);

                      Widget card = Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isComplete
                              ? theme.colorScheme.primaryContainer
                              : (isCurrent
                                    ? theme.colorScheme.secondaryContainer
                                    : theme.colorScheme.surface),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCurrent
                                ? theme.colorScheme.secondary
                                : (isComplete
                                      ? theme.colorScheme.primary.withValues(
                                          alpha: 0.3,
                                        )
                                      : theme.colorScheme.outline),
                            width: isCurrent ? 3 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Envelope header
                            Row(
                              children: [
                                // Emoji
                                Text(
                                  env.emoji ?? '📨',
                                  style: const TextStyle(fontSize: 24),
                                ),
                                const SizedBox(width: 12),

                                // Name
                                Expanded(
                                  child: Text(
                                    env.name,
                                    style: fontProvider.getTextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: isPending
                                          ? theme.colorScheme.onSurface
                                                .withValues(alpha: 0.5)
                                          : null,
                                    ),
                                  ),
                                ),

                                // Status icon
                                if (isComplete)
                                  Icon(
                                    Icons.check_circle,
                                    color: theme.colorScheme.primary,
                                    size: 28,
                                  )
                                else if (isCurrent)
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      color: theme.colorScheme.secondary,
                                    ),
                                  )
                                else
                                  Icon(
                                    Icons.schedule,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.3),
                                    size: 24,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Progress bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 8,
                                backgroundColor: Colors.grey.shade300,
                                valueColor: AlwaysStoppedAnimation(
                                  isCurrent
                                      ? theme.colorScheme.secondary
                                      : theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Amount
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  currency.format(amount * progress),
                                  style: fontProvider.getTextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isCurrent
                                        ? theme.colorScheme.secondary
                                        : theme.colorScheme.primary,
                                  ),
                                ),
                                if (!isComplete)
                                  Text(
                                    '/ ${currency.format(amount)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );

                      // Add pulse animation to current envelope
                      if (isCurrent) {
                        return ScaleTransition(
                          scale: _pulseAnimation,
                          child: card,
                        );
                      }

                      return card;
                    },
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
