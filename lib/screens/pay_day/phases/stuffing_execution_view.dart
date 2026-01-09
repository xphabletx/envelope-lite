// lib/screens/pay_day/phases/stuffing_execution_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../../../providers/pay_day_cockpit_provider.dart';
import '../../../providers/font_provider.dart';
import '../../../providers/locale_provider.dart';
import '../../../models/envelope.dart';
import '../../../widgets/horizon_progress.dart';

class StuffingExecutionView extends StatefulWidget {
  final Map<String, double> calculatedBoosts;
  final double initialAccountBalance;
  final Function(double) onInitialAccountBalanceSet;

  const StuffingExecutionView({
    super.key,
    required this.calculatedBoosts,
    required this.initialAccountBalance,
    required this.onInitialAccountBalanceSet,
  });

  @override
  State<StuffingExecutionView> createState() => _StuffingExecutionViewState();
}

class _StuffingExecutionViewState extends State<StuffingExecutionView> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _envelopeKeys = {};
  bool _hasScrolledToTopForGold = false;
  bool _hasStartedExecution = false;

  @override
  void initState() {
    super.initState();
    // Start execution on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startExecutionIfNeeded();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startExecutionIfNeeded();
  }

  void _startExecutionIfNeeded() {
    final provider = context.read<PayDayCockpitProvider>();

    // Store initial account balance IMMEDIATELY before any animation
    // Use post-frame callback to avoid setState during build
    if (provider.isAccountMode &&
        provider.defaultAccount != null &&
        widget.initialAccountBalance == 0.0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onInitialAccountBalanceSet(provider.defaultAccount!.currentBalance);
      });
    }

    // Start the execution immediately with boosts (only once!)
    if (provider.currentPhase == CockpitPhase.stuffingExecution &&
        !_hasStartedExecution) {
      _hasStartedExecution = true;
      // Use the pre-calculated boosts (both implicit and explicit)
      provider.executeStuffing(boosts: widget.calculatedBoosts);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _envelopeKeys.clear();
    super.dispose();
  }

  double _calculateRemainingSource(PayDayCockpitProvider provider) {
    if (provider.isAccountMode && provider.defaultAccount != null) {
      // In account mode: source only decreases during account deposit animation
      // Once money is in the account, source stays at 0
      final accountDepositProgress = provider.accountDepositProgress;
      return provider.externalInflow - accountDepositProgress;
    } else {
      // In non-account mode, source decreases as envelopes fill
      final totalStuffedSoFar = provider.stuffingProgress.values.fold(
        0.0,
        (sum, amount) => sum + amount,
      );
      return provider.externalInflow - totalStuffedSoFar;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PayDayCockpitProvider>();
    final theme = Theme.of(context);
    final fontProvider = context.read<FontProvider>();
    final locale = context.read<LocaleProvider>();
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);

    // Get current stage
    final isGoldStage = provider.stuffingStage == StuffingStage.gold;
    final isComplete = provider.stuffingStage == StuffingStage.complete;

    // Get envelopes to display based on stage
    List<Envelope> envelopesBeingStuffed;

    if (isGoldStage || isComplete) {
      // GOLD STAGE or COMPLETE: Show ONLY boosted envelopes
      // Keep showing gold list during complete stage to avoid visual glitch
      envelopesBeingStuffed = provider.allocations.entries
          .where(
            (e) =>
                widget.calculatedBoosts.containsKey(e.key) &&
                (widget.calculatedBoosts[e.key] ?? 0) > 0,
          )
          .map(
            (e) => provider.allEnvelopes.firstWhere((env) => env.id == e.key),
          )
          .toList();

      // If no boosts, show all envelopes (fallback for complete stage)
      if (envelopesBeingStuffed.isEmpty) {
        envelopesBeingStuffed = provider.allocations.entries
            .map(
              (e) => provider.allEnvelopes.firstWhere((env) => env.id == e.key),
            )
            .toList();
      }
    } else {
      // SILVER STAGE: Show all envelopes in normal order
      envelopesBeingStuffed = provider.allocations.entries
          .map(
            (e) => provider.allEnvelopes.firstWhere((env) => env.id == e.key),
          )
          .toList();
    }

    // Calculate overall progress (how many envelopes completed)
    final totalEnvelopes = envelopesBeingStuffed.length;
    final completedEnvelopes = provider.currentEnvelopeAnimationIndex + 1;
    final overallProgress = totalEnvelopes > 0
        ? (completedEnvelopes / totalEnvelopes).clamp(0.0, 1.0)
        : 0.0;

    // Scroll to top when gold stage starts
    if (isGoldStage &&
        !_hasScrolledToTopForGold &&
        _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          );
          _hasScrolledToTopForGold = true;
        }
      });
    }

    // Reset scroll flag only when returning to silver stage (not during complete)
    if (!isGoldStage && !isComplete) {
      _hasScrolledToTopForGold = false;
    }

    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        children: [
          // Glowing Sun Header - Redesigned (smaller, shows decreasing amount)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                // Smaller custom painted sun that gets brighter
                _GlowingSun(brightness: overallProgress, size: 60),
                const SizedBox(height: 12),
                Text(
                  'Source of Income',
                  style: fontProvider.getTextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                  ),
                ),
                const SizedBox(height: 8),
                // AnimatedSwitcher for smooth number updates (decreasing amount)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                  child: Text(
                    currency.format(_calculateRemainingSource(provider)),
                    key: ValueKey<double>(_calculateRemainingSource(provider)),
                    style: fontProvider.getTextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Account tier (if hasAccount)
          if (provider.isAccountMode && provider.defaultAccount != null) ...[
            // Waterfall connector from sun to account
            Center(
              child: Container(
                height: 40,
                width: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.amber.shade300.withValues(alpha: overallProgress),
                      Colors.amber.shade500.withValues(
                        alpha: overallProgress * 0.5,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Account container - Redesigned to look like account cards with increasing balance
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Account icon from provider
                  provider.defaultAccount!.getIconWidget(theme, size: 32),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.defaultAccount!.name,
                        style: fontProvider.getTextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // AnimatedSwitcher for smooth number updates (account balance changes)
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                        child: Builder(
                          builder: (context) {
                            // Calculate current account balance:
                            // Initial + deposit progress - total stuffed into envelopes
                            final envelopesStuffedTotal = provider
                                .stuffingProgress
                                .values
                                .fold(0.0, (sum, amount) => sum + amount);
                            final currentAccountBalance =
                                widget.initialAccountBalance +
                                provider.accountDepositProgress -
                                envelopesStuffedTotal;
                            return Text(
                              currency.format(currentAccountBalance),
                              key: ValueKey<double>(currentAccountBalance),
                              style: fontProvider.getTextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Waterfall connector from account to envelopes
            Center(
              child: Container(
                height: 40,
                width: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.blue.shade400.withValues(alpha: overallProgress),
                      Colors.amber.shade500.withValues(
                        alpha: overallProgress * 0.5,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else ...[
            // Direct waterfall from source to envelopes (no account)
            Center(
              child: Container(
                height: 40,
                width: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.amber.shade300.withValues(alpha: overallProgress),
                      Colors.amber.shade500.withValues(
                        alpha: overallProgress * 0.5,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          // Stage indicator
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              isGoldStage ? '✨ Gold Boost Active' : '⚡ Filling Envelopes',
              style: fontProvider.getTextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isGoldStage
                    ? Colors.amber.shade700
                    : theme.colorScheme.primary,
              ),
            ),
          ),

          // All envelopes in a column with padding
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Generate all envelope widgets
                ...List.generate(envelopesBeingStuffed.length, (index) {
                  final envelope = envelopesBeingStuffed[index];
                  final stuffedAmount =
                      provider.stuffingProgress[envelope.id] ?? 0.0;
                  final targetAmount = provider.allocations[envelope.id] ?? 0.0;
                  final isActive =
                      provider.currentEnvelopeAnimationIndex == index;
                  final fillProgress = targetAmount > 0
                      ? (stuffedAmount / targetAmount).clamp(0.0, 1.0)
                      : 0.0;
                  final horizonProgress =
                      envelope.targetAmount != null &&
                          envelope.targetAmount! > 0
                      ? ((envelope.currentAmount + stuffedAmount) /
                                envelope.targetAmount!)
                            .clamp(0.0, 1.0)
                      : 0.0;

                  // Check if this envelope is getting gold boost (from calculated boosts)
                  final hasBoost =
                      widget.calculatedBoosts.containsKey(envelope.id) &&
                      (widget.calculatedBoosts[envelope.id] ?? 0) > 0;
                  final isGoldActive = isGoldStage && isActive && hasBoost;

                  // Determine if this envelope has completed or is ahead of current animation
                  final isCompleted =
                      index < provider.currentEnvelopeAnimationIndex;
                  final isPending =
                      index > provider.currentEnvelopeAnimationIndex;

                  // Create or get GlobalKey for this envelope
                  _envelopeKeys.putIfAbsent(index, () => GlobalKey());

                  // Auto-scroll to active envelope
                  if (isActive) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final keyContext = _envelopeKeys[index]?.currentContext;
                      if (keyContext != null && _scrollController.hasClients) {
                        Scrollable.ensureVisible(
                          keyContext,
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                          alignment:
                              0.3, // Position at 30% from top of viewport
                        );
                      }
                    });
                  }

                  return AnimatedContainer(
                    key: _envelopeKeys[index],
                    duration: const Duration(milliseconds: 400),
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: isGoldActive
                          ? LinearGradient(
                              colors: [
                                Colors.amber.shade50,
                                Colors.orange.shade100,
                              ],
                            )
                          : (isActive && !isGoldStage
                                ? LinearGradient(
                                    colors: [
                                      Colors.blue.shade50,
                                      Colors.cyan.shade50,
                                    ],
                                  )
                                : null),
                      color: isGoldActive || (isActive && !isGoldStage)
                          ? null
                          : (isCompleted
                                ? theme.colorScheme.surfaceContainerHigh
                                : (isPending
                                      ? theme.colorScheme.surface.withValues(
                                          alpha: 0.5,
                                        )
                                      : theme
                                            .colorScheme
                                            .surfaceContainerHighest)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isGoldActive
                            ? Colors.amber.shade700
                            : (isActive && !isGoldStage
                                  ? Colors.blue.shade600
                                  : (isCompleted
                                        ? Colors.green.shade400
                                        : Colors.grey.shade300)),
                        width: isActive ? 3 : 1,
                      ),
                      boxShadow: isGoldActive
                          ? [
                              BoxShadow(
                                color: Colors.amber.shade400.withValues(
                                  alpha: 0.6,
                                ),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ]
                          : (isActive && !isGoldStage
                                ? [
                                    BoxShadow(
                                      color: Colors.blue.shade400.withValues(
                                        alpha: 0.4,
                                      ),
                                      blurRadius: 15,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null),
                    ),
                    child: Row(
                      children: [
                        envelope.getIconWidget(theme, size: 40),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                envelope.name,
                                style: fontProvider.getTextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Animated stuffing progress bar with gradual filling animation
                              TweenAnimationBuilder<double>(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeInOut,
                                tween: Tween<double>(
                                  begin: 0.0,
                                  end: fillProgress,
                                ),
                                builder: (context, animatedProgress, child) {
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Stack(
                                      children: [
                                        LinearProgressIndicator(
                                          value: animatedProgress,
                                          minHeight: 12,
                                          backgroundColor: Colors.grey.shade200,
                                          valueColor:
                                              const AlwaysStoppedAnimation(
                                                Colors.transparent,
                                              ),
                                        ),
                                        // Light-filled progress
                                        FractionallySizedBox(
                                          widthFactor: animatedProgress,
                                          child: Container(
                                            height: 12,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: isGoldActive
                                                    ? [
                                                        Colors.amber.shade200,
                                                        Colors.amber.shade400,
                                                        Colors.orange.shade500,
                                                      ]
                                                    : [
                                                        Colors.amber.shade300,
                                                        Colors.yellow.shade400,
                                                        Colors.amber.shade500,
                                                      ],
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: isGoldActive
                                                      ? Colors.amber.withValues(
                                                          alpha: 0.8,
                                                        )
                                                      : Colors.amber.withValues(
                                                          alpha: 0.5,
                                                        ),
                                                  blurRadius: isGoldActive
                                                      ? 12
                                                      : 8,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              if (isGoldActive)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '✨ GOLD BOOST',
                                    style: fontProvider.getTextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber.shade900,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                '${currency.format(stuffedAmount)} / ${currency.format(targetAmount)}',
                                style: fontProvider.getTextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        if (envelope.targetAmount != null)
                          AnimatedOpacity(
                            opacity: isActive ? 1.0 : (isCompleted ? 0.9 : 0.6),
                            duration: const Duration(milliseconds: 300),
                            child: Transform.scale(
                              scale: isActive ? 1.1 : 1.0,
                              child: TweenAnimationBuilder<double>(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeInOut,
                                tween: Tween<double>(
                                  begin: 0.0,
                                  end: horizonProgress,
                                ),
                                builder:
                                    (context, animatedHorizonProgress, child) {
                                      return HorizonProgress(
                                        percentage: animatedHorizonProgress,
                                        size: 50,
                                      );
                                    },
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// CUSTOM WIDGETS
// ============================================================================

/// Animated glowing sun that gets brighter as stuffing progresses
class _GlowingSun extends StatefulWidget {
  final double brightness; // 0.0 to 1.0
  final double size; // Size of the sun

  const _GlowingSun({required this.brightness, this.size = 120});

  @override
  State<_GlowingSun> createState() => _GlowingSunState();
}

class _GlowingSunState extends State<_GlowingSun>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulseValue = _pulseController.value;
        final brightness = widget.brightness.clamp(
          0.3,
          1.0,
        ); // Minimum 30% brightness

        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _SunPainter(brightness: brightness, pulse: pulseValue),
        );
      },
    );
  }
}

class _SunPainter extends CustomPainter {
  final double brightness; // 0.0 to 1.0
  final double pulse; // 0.0 to 1.0 for animation

  _SunPainter({required this.brightness, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width / 3;

    // Outer glow (multiple layers for intense brightness)
    for (int i = 5; i > 0; i--) {
      final glowRadius = baseRadius + (i * 15 * brightness) + (pulse * 5);
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            Color.lerp(
              Colors.yellow.shade200,
              Colors.white,
              brightness * 0.8,
            )!.withValues(alpha: 0.1 * brightness),
            Colors.transparent,
          ],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: glowRadius));

      canvas.drawCircle(center, glowRadius, glowPaint);
    }

    // Core sun with gradient
    final sunPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Color.lerp(Colors.yellow.shade100, Colors.white, brightness * 0.9)!,
          Color.lerp(
            Colors.yellow.shade400,
            Colors.amber.shade200,
            brightness * 0.5,
          )!,
          Color.lerp(
            Colors.orange.shade500,
            Colors.amber.shade600,
            brightness * 0.3,
          )!,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: baseRadius));

    canvas.drawCircle(center, baseRadius, sunPaint);

    // Sun rays (more prominent with higher brightness)
    final rayCount = 12;
    final rayPaint = Paint()
      ..color = Color.lerp(
        Colors.yellow.shade300,
        Colors.white,
        brightness * 0.7,
      )!.withValues(alpha: 0.6 * brightness)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < rayCount; i++) {
      final angle = (i * 2 * math.pi / rayCount) + (pulse * math.pi / 6);
      final rayStart = baseRadius + 5;
      final rayEnd = baseRadius + 15 + (brightness * 10);

      final startX = center.dx + rayStart * math.cos(angle);
      final startY = center.dy + rayStart * math.sin(angle);
      final endX = center.dx + rayEnd * math.cos(angle);
      final endY = center.dy + rayEnd * math.sin(angle);

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), rayPaint);
    }

    // Inner bright core (gets brighter)
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: brightness * 0.9),
          Colors.white.withValues(alpha: brightness * 0.3),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: baseRadius * 0.5));

    canvas.drawCircle(center, baseRadius * 0.5, corePaint);
  }

  @override
  bool shouldRepaint(_SunPainter oldDelegate) {
    return oldDelegate.brightness != brightness || oldDelegate.pulse != pulse;
  }
}
