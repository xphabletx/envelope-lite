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
import '../../services/account_repo.dart';
import 'add_to_pay_day_modal.dart';
import 'pay_day_stuffing_screen.dart';
import '../../providers/font_provider.dart'; // NEW IMPORT
import '../../providers/locale_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_themes.dart';
import '../../widgets/tutorial_wrapper.dart';
import '../../data/tutorial_sequences.dart';
import '../../utils/responsive_helper.dart';

class PayDayPreviewScreen extends StatefulWidget {
  const PayDayPreviewScreen({
    super.key,
    required this.repo,
    required this.groupRepo,
    required this.accountRepo,
    required this.totalAmount,
    required this.accountId,
    this.preselectedAllocations,
  });

  final EnvelopeRepo repo;
  final GroupRepo groupRepo;
  final AccountRepo accountRepo;
  final double totalAmount;
  final String accountId;
  final Map<String, double>? preselectedAllocations;

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

    // If we have preselected allocations from the allocation screen, use those
    if (widget.preselectedAllocations != null) {
      for (final envelopeId in widget.preselectedAllocations!.keys) {
        envelopeCheckedState[envelopeId] = true;
        customAmounts[envelopeId] = widget.preselectedAllocations![envelopeId]!;
      }
      return;
    }

    // Otherwise, use the original auto-fill logic
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
    // Build allocations map from checked envelopes
    final Map<String, double> allocations = {};
    final List<Envelope> envelopesToStuff = [];

    for (final env in allEnvelopes) {
      if (envelopeCheckedState[env.id] == true) {
        final amount = customAmounts[env.id] ?? env.autoFillAmount;
        if (amount != null && amount > 0) {
          allocations[env.id] = amount;
          envelopesToStuff.add(env);
        }
      }
    }

    if (envelopesToStuff.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one envelope'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Navigate to stuffing screen with animation
    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PayDayStuffingScreen(
            repo: widget.repo,
            accountRepo: widget.accountRepo,
            allocations: allocations,
            envelopes: envelopesToStuff,
            totalAmount: widget.totalAmount,
            accountId: widget.accountId,
          ),
        ),
      );

      // After stuffing completes, pop back to home
      if (mounted) {
        Navigator.pop(context); // Close preview screen
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
    final locale = Provider.of<LocaleProvider>(context, listen: false);
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context);

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

            return TutorialWrapper(
              tutorialSequence: payDayTutorial,
              spotlightKeys: {
                'welcome': _welcomeKey,
                'envelopeList': _envelopeListKey,
                'amounts': _amountsKey,
                'previewButton': _previewButtonKey,
                'confirmButton': _confirmButtonKey,
              },
              child: Scaffold(
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
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Pay Day Preview',
                        // UPDATED: FontProvider
                        style: fontProvider.getTextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
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
                padding: context.responsive.safePadding,
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

                      final binderColorOption =
                          ThemeBinderColors.getColorsForTheme(
                              themeProvider.currentThemeId)[group.colorIndex];
                      final groupColor = binderColorOption.binderColor;

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
                              // FIX: withOpacity -> withAlpha
                              color: groupColor.withAlpha(66),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                // FIX: withOpacity -> withAlpha
                                color: groupColor.withAlpha(196),
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
                                              // FIX: withOpacity -> withAlpha
                                              color: theme.colorScheme.onSurface
                                                  .withAlpha(179),
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
                                        // FIX: withOpacity -> withAlpha
                                        color: theme.colorScheme.onSurface
                                            .withAlpha(128),
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
                                    // FIX: withOpacity -> withAlpha
                                    color: isChecked
                                        ? groupColor.withAlpha(33)
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
                            // FIX: withOpacity -> withAlpha
                            color: theme.colorScheme.primary.withAlpha(196),
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
                onPressed: () => _executePayDay(allEnvelopes),
                backgroundColor: theme.colorScheme.secondary,
                icon: const Icon(Icons.check_circle),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Confirm Pay Day',
                    // UPDATED: FontProvider
                    style: fontProvider.getTextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
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
