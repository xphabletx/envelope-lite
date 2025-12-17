// lib/screens/pay_day/pay_day_preview_screen.dart
// FONT PROVIDER INTEGRATED: All GoogleFonts.caveat() replaced with FontProvider
// All button text wrapped in FittedBox to prevent wrapping
// CLEANUP: Removed all debug print statements

import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // NEW IMPORT
import 'package:intl/intl.dart';

import '../../models/envelope.dart';
import '../../models/envelope_group.dart';
import '../../services/envelope_repo.dart';
import '../../services/group_repo.dart';
import 'add_to_pay_day_modal.dart';
import '../../providers/font_provider.dart'; // NEW IMPORT
// TUTORIAL IMPORT REMOVED - Logic commented out below

class PayDayPreviewScreen extends StatefulWidget {
  const PayDayPreviewScreen({
    super.key,
    required this.repo,
    required this.groupRepo,
  });

  final EnvelopeRepo repo;
  final GroupRepo groupRepo;

  @override
  State<PayDayPreviewScreen> createState() => _PayDayPreviewScreenState();
}

class _PayDayPreviewScreenState extends State<PayDayPreviewScreen> {
  // Track checked state for THIS instance only
  Map<String, bool> envelopeCheckedState = {};
  Map<String, bool> binderCheckedState = {};

  // Remember original auto-pay states for restoration
  Map<String, Set<String>> binderOriginalEnvelopes = {};

  // Custom amounts for manually added items
  Map<String, double> customAmounts = {};

  bool _loading = false;

  // TUTORIAL KEYS
  final GlobalKey _welcomeKey = GlobalKey();
  final GlobalKey _envelopeListKey =
      GlobalKey(); // Points to list/binder section
  final GlobalKey _amountsKey = GlobalKey(); // Points to individual section
  final GlobalKey _previewButtonKey = GlobalKey(); // Points to add button
  final GlobalKey _confirmButtonKey = GlobalKey();

  void _initializeState(
    List<Envelope> allEnvelopes,
    List<EnvelopeGroup> allGroups,
  ) {
    if (envelopeCheckedState.isNotEmpty) return; // Already initialized

    // NEW LOGIC: Show binder if payDayEnabled=true OR has ANY auto-fill envelopes
    for (final group in allGroups) {
      // Check if this binder has ANY envelopes with auto-fill
      final hasAutoFillEnvelopes = allEnvelopes.any(
        (env) =>
            env.groupId == group.id &&
            env.autoFillEnabled &&
            env.autoFillAmount != null,
      );

      // Show binder if payDayEnabled OR has auto-fill envelopes
      if (group.payDayEnabled || hasAutoFillEnvelopes) {
        // Binder checkbox: checked ONLY if payDayEnabled=true
        binderCheckedState[group.id] = group.payDayEnabled;

        // Track which envelopes in this binder have auto-pay
        final originalSet = <String>{};

        for (final env in allEnvelopes) {
          if (env.groupId == group.id) {
            final isAutoPay = env.autoFillEnabled && env.autoFillAmount != null;
            // Envelope checkbox: checked if auto-fill is enabled
            envelopeCheckedState[env.id] = isAutoPay;
            if (isAutoPay) {
              originalSet.add(env.id);
            }
          }
        }

        binderOriginalEnvelopes[group.id] = originalSet;
      }
    }

    // Initialize individual envelopes (not in any binder) with auto-pay
    for (final env in allEnvelopes) {
      if (env.groupId == null || env.groupId!.isEmpty) {
        if (env.autoFillEnabled && env.autoFillAmount != null) {
          envelopeCheckedState[env.id] = true;
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _checkTutorial();
  }

  Future<void> _checkTutorial() async {
    // TODO: Implement Pay Day tutorial step using new TutorialController
    /*
    await Future.delayed(const Duration(milliseconds: 600));

    final phase = await TutorialService.getCurrentPhase();

    if (phase == TutorialPhase.bottomNav && mounted) {
      // Advance to PayDay phase
      await TutorialService.setPhase(TutorialPhase.payDay);

      TutorialService.showPayDayTutorial(
        context,
        welcomeKey: _welcomeKey,
        envelopeListKey: _envelopeListKey,
        amountsKey: _amountsKey,
        previewButtonKey: _previewButtonKey,
        confirmButtonKey: _confirmButtonKey,
      );
    }
    */
  }

  void _toggleBinder(String binderId, List<Envelope> allEnvelopes) {
    final newState = !(binderCheckedState[binderId] ?? false);
    setState(() {
      binderCheckedState[binderId] = newState;

      if (newState) {
        // RESTORE: Only check envelopes that were originally checked
        for (final envId in binderOriginalEnvelopes[binderId] ?? {}) {
          envelopeCheckedState[envId] = true;
        }
      } else {
        // UNCHECK ALL: Turn off all envelopes in this binder
        for (final env in allEnvelopes) {
          if (env.groupId == binderId) {
            envelopeCheckedState[env.id] = false;
          }
        }
      }
    });
  }

  void _toggleEnvelope(String envId) {
    setState(() {
      envelopeCheckedState[envId] = !(envelopeCheckedState[envId] ?? false);
    });
  }

  double _calculateTotalChecked(List<Envelope> allEnvelopes) {
    double total = 0;
    for (final env in allEnvelopes) {
      if (envelopeCheckedState[env.id] == true) {
        final amount = customAmounts[env.id] ?? env.autoFillAmount;
        if (amount != null) {
          total += amount;
        }
      }
    }
    return total;
  }

  double _calculateTotalPossible(List<Envelope> allEnvelopes) {
    double total = 0;
    for (final env in allEnvelopes) {
      if (env.autoFillAmount != null) {
        total += env.autoFillAmount!;
      }
    }
    return total;
  }

  double _getBinderCheckedTotal(String binderId, List<Envelope> allEnvelopes) {
    double total = 0;
    for (final env in allEnvelopes) {
      if (env.groupId == binderId && envelopeCheckedState[env.id] == true) {
        final amount = customAmounts[env.id] ?? env.autoFillAmount;
        if (amount != null) {
          total += amount;
        }
      }
    }
    return total;
  }

  double _getBinderPossibleTotal(String binderId, List<Envelope> allEnvelopes) {
    double total = 0;
    for (final env in allEnvelopes) {
      if (env.groupId == binderId && env.autoFillAmount != null) {
        total += env.autoFillAmount!;
      }
    }
    return total;
  }

  Future<void> _executePayDay(List<Envelope> allEnvelopes) async {
    setState(() => _loading = true);

    final today = DateTime.now();
    int successCount = 0;
    double totalDeposited = 0;
    // FIXED: Corrected currency symbol from 'ﾂ｣' to '£'
    final currency = NumberFormat.currency(symbol: '£');

    try {
      for (final env in allEnvelopes) {
        if (envelopeCheckedState[env.id] == true) {
          final amount = customAmounts[env.id] ?? env.autoFillAmount;
          if (amount != null && amount > 0) {
            await widget.repo.deposit(
              envelopeId: env.id,
              amount: amount,
              description: 'Pay Day',
              date: today,
            );
            successCount++;
            totalDeposited += amount;
          }
        }
      }

      // TODO: Re-implement tutorial completion with new Controller
      /*
      // TUTORIAL COMPLETE
      final phase = await TutorialService.getCurrentPhase();
      if (phase == TutorialPhase.payDay) {
        await TutorialService.completeTutorial();
      }
      */

      if (mounted) {
        Navigator.pop(context);

        // 💰 DOPAMINE RESTORED! 💰
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => _PayDaySuccessDialog(
            envelopesFilled: successCount,
            totalAmount: totalDeposited,
            currency: currency,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _openAddModal(
    List<Envelope> allEnvelopes,
    List<EnvelopeGroup> allGroups,
  ) async {
    final result = await showModalBottomSheet<PayDayAddition>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddToPayDayModal(
        allEnvelopes: allEnvelopes,
        allGroups: allGroups,
        alreadyDisplayedEnvelopes: envelopeCheckedState.keys.toSet(),
        alreadyDisplayedBinders: binderCheckedState.keys.toSet(),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        if (result.envelopeId != null) {
          // Add individual envelope
          envelopeCheckedState[result.envelopeId!] = true;
          if (result.customAmount != null) {
            customAmounts[result.envelopeId!] = result.customAmount!;
          }
        } else if (result.binderId != null) {
          // Add binder
          binderCheckedState[result.binderId!] = true;

          // Add all envelopes in binder with auto-pay
          final originalSet = <String>{};
          for (final env in allEnvelopes) {
            if (env.groupId == result.binderId) {
              final isAutoPay =
                  env.autoFillEnabled && env.autoFillAmount != null;
              envelopeCheckedState[env.id] = isAutoPay;
              if (isAutoPay) {
                originalSet.add(env.id);
              }
            }
          }
          binderOriginalEnvelopes[result.binderId!] = originalSet;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // FIXED: Corrected currency symbol from 'ﾂ｣' to '£'
    final currency = NumberFormat.currency(symbol: '£');
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return StreamBuilder<List<Envelope>>(
      stream: widget.repo.envelopesStream(),
      builder: (_, s1) {
        final allEnvelopes = s1.data ?? [];

        return StreamBuilder<List<EnvelopeGroup>>(
          stream: widget.repo.groupsStream,
          builder: (_, s2) {
            final allGroups = s2.data ?? [];

            // Initialize state on first build
            _initializeState(allEnvelopes, allGroups);

            final totalChecked = _calculateTotalChecked(allEnvelopes);
            final totalPossible = _calculateTotalPossible(allEnvelopes);

            // Get binders to display
            final bindersToDisplay = allGroups
                .where((g) => binderCheckedState.containsKey(g.id))
                .toList();

            // Get individual envelopes (not in displayed binders)
            final individualEnvelopes = allEnvelopes.where((env) {
              if (env.groupId == null || env.groupId!.isEmpty) {
                return envelopeCheckedState.containsKey(env.id);
              }
              return false;
            }).toList();

            return Scaffold(
              backgroundColor: theme.scaffoldBackgroundColor,
              appBar: AppBar(
                backgroundColor: theme.scaffoldBackgroundColor,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Column(
                  key: _welcomeKey, // TUTORIAL KEY
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pay Day Preview',
                      // UPDATED: FontProvider
                      style: fontProvider.getTextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Text(
                      'Total: ${currency.format(totalChecked)} / ${currency.format(totalPossible)} possible',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // BINDERS SECTION
                  if (bindersToDisplay.isNotEmpty) ...[
                    Text(
                      'Binders',
                      key:
                          _envelopeListKey, // TUTORIAL KEY (points to start of list)
                      // UPDATED: FontProvider
                      style: fontProvider.getTextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...bindersToDisplay.map((group) {
                      final envelopesInBinder =
                          allEnvelopes
                              .where((e) => e.groupId == group.id)
                              .toList()
                            ..sort((a, b) => a.name.compareTo(b.name));

                      final binderChecked = _getBinderCheckedTotal(
                        group.id,
                        allEnvelopes,
                      );
                      final binderPossible = _getBinderPossibleTotal(
                        group.id,
                        allEnvelopes,
                      );

                      final groupColor = GroupColors.getThemedColor(
                        group.colorName,
                        theme.colorScheme,
                      );

                      // NEW: Check if binder has auto-fill OFF but contains auto-fill envelopes
                      final hasAutoFillEnvelopes = envelopesInBinder.any(
                        (e) => e.autoFillEnabled && e.autoFillAmount != null,
                      );
                      final needsEnabling =
                          !group.payDayEnabled && hasAutoFillEnvelopes;

                      return Column(
                        children: [
                          // Binder header
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              // FIX: withOpacity -> withValues
                              color: groupColor.withValues(alpha: 0.26),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                // FIX: withOpacity -> withValues
                                color: groupColor.withValues(alpha: 0.77),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Checkbox(
                                      value:
                                          binderCheckedState[group.id] ?? false,
                                      onChanged: (v) =>
                                          _toggleBinder(group.id, allEnvelopes),
                                      activeColor: groupColor,
                                    ),
                                    Text(
                                      // FIXED: Corrected corrupted folder emoji '刀' to '📁'
                                      group.emoji ?? '📁',
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            group.name,
                                            // UPDATED: FontProvider
                                            style: fontProvider.getTextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: groupColor,
                                            ),
                                          ),
                                          Text(
                                            '${currency.format(binderChecked)} / ${currency.format(binderPossible)}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              // FIX: withOpacity -> withValues
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                // Simple info message if needs enabling
                                if (needsEnabling)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      'Binder auto-fill is off but envelopes are set to auto-fill',
                                      style: TextStyle(
                                        fontSize: 12,
                                        // FIX: withOpacity -> withValues
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.5),
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // Envelopes in binder
                          Padding(
                            padding: const EdgeInsets.only(left: 24),
                            child: Column(
                              children: envelopesInBinder.map((env) {
                                final isChecked =
                                    envelopeCheckedState[env.id] ?? false;
                                final amount =
                                    customAmounts[env.id] ?? env.autoFillAmount;
                                final hasAmount = amount != null;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    // FIX: withOpacity -> withValues
                                    color: isChecked
                                        ? groupColor.withValues(alpha: 0.13)
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Checkbox(
                                        value: isChecked,
                                        onChanged: hasAmount
                                            ? (v) => _toggleEnvelope(env.id)
                                            : null,
                                        activeColor: groupColor,
                                      ),
                                      if (env.emoji != null) ...[
                                        Text(
                                          env.emoji!,
                                          style: const TextStyle(fontSize: 18),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      Expanded(
                                        child: Text(
                                          env.name,
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: hasAmount
                                                ? theme.colorScheme.onSurface
                                                : Colors.grey,
                                          ),
                                        ),
                                      ),
                                      if (hasAmount)
                                        Text(
                                          currency.format(amount),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: groupColor,
                                          ),
                                        )
                                      else
                                        Text(
                                          'No amount',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade600,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                          const SizedBox(height: 16),
                        ],
                      );
                    }),
                  ],

                  // INDIVIDUAL ENVELOPES SECTION
                  if (individualEnvelopes.isNotEmpty) ...[
                    Text(
                      'Individual Envelopes',
                      key:
                          _amountsKey, // TUTORIAL KEY (point to section where users toggle/edit)
                      // UPDATED: FontProvider
                      style: fontProvider.getTextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...individualEnvelopes.map((env) {
                      final isChecked = envelopeCheckedState[env.id] ?? false;
                      final amount =
                          customAmounts[env.id] ?? env.autoFillAmount;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            // FIX: withOpacity -> withValues
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.77,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: isChecked,
                              onChanged: (v) => _toggleEnvelope(env.id),
                              activeColor: theme.colorScheme.primary,
                            ),
                            if (env.emoji != null) ...[
                              Text(
                                env.emoji!,
                                style: const TextStyle(fontSize: 20),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: Text(
                                env.name,
                                // UPDATED: FontProvider
                                style: fontProvider.getTextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (amount != null)
                              Text(
                                currency.format(amount),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  ],

                  // ADD BUTTON
                  const SizedBox(height: 16),
                  TextButton.icon(
                    key:
                        _previewButtonKey, // TUTORIAL KEY (Tutorial text says "Preview Changes", mapping to this action area)
                    onPressed: () => _openAddModal(allEnvelopes, allGroups),
                    icon: const Icon(Icons.add_circle_outline),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Add envelope or binder',
                        // UPDATED: FontProvider
                        style: fontProvider.getTextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.secondary,
                    ),
                  ),

                  const SizedBox(height: 80),
                ],
              ),
              floatingActionButton: FloatingActionButton.extended(
                key: _confirmButtonKey, // TUTORIAL KEY
                onPressed: _loading ? null : () => _executePayDay(allEnvelopes),
                backgroundColor: theme.colorScheme.secondary,
                icon: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.check_circle),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _loading ? 'Processing...' : 'Confirm Pay Day',
                    // UPDATED: FontProvider
                    style: fontProvider.getTextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ... rest of file (SuccessDialog) remains unchanged ...
class _PayDaySuccessDialog extends StatefulWidget {
  const _PayDaySuccessDialog({
    required this.envelopesFilled,
    required this.totalAmount,
    required this.currency,
  });

  final int envelopesFilled;
  final double totalAmount;
  final NumberFormat currency;

  @override
  State<_PayDaySuccessDialog> createState() => _PayDaySuccessDialogState();
}

class _PayDaySuccessDialogState extends State<_PayDaySuccessDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _controller.forward();

    // Auto-dismiss after 2.5 seconds
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return ScaleTransition(
      scale: _scaleAnimation,
      child: AlertDialog(
        backgroundColor: theme.scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // FIXED: Corrected corrupted confetti emoji '脂' to '🎉'
            const Text('🎉', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 16),
            Text(
              'Pay Day Complete!',
              // UPDATED: FontProvider
              style: fontProvider.getTextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              widget.currency.format(widget.totalAmount),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.secondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.envelopesFilled} ${widget.envelopesFilled == 1 ? 'envelope' : 'envelopes'} filled',
              // UPDATED: FontProvider
              style: fontProvider.getTextStyle(
                fontSize: 20,
                // FIX: withOpacity -> withValues
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
