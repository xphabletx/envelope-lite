// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
// FIXED: Hide Transaction to prevent conflict with your model
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;

import '../utils/calculator_helper.dart';

import '../services/envelope_repo.dart';
import '../services/group_repo.dart';
import '../services/run_migrations_once.dart';
import '../services/user_service.dart';
import '../services/auto_payment_service.dart';
import '../providers/font_provider.dart';

import '../widgets/envelope_tile.dart';
import '../widgets/envelope_creator.dart';
import '../widgets/group_editor.dart' as editor;
import '../widgets/partner_visibility_toggle.dart';
import '../widgets/partner_badge.dart';
// import '../widgets/tutorial_overlay.dart'; // TUTORIAL DISABLED

import '../models/envelope.dart';
import '../models/envelope_group.dart';
import '../models/transaction.dart';
import '../models/user_profile.dart';

import '../services/workspace_helper.dart';
import '../services/localization_service.dart';
import '../services/tutorial_controller.dart';

import '../screens/envelope/envelopes_detail_screen.dart';
import 'stats_history_screen.dart';
import 'settings_screen.dart';
import 'pay_day_settings_screen.dart';
import 'calendar_screen.dart';
import 'budget_screen.dart';
import 'groups_home_screen.dart';
import 'pay_day_amount_screen.dart';

// Themed SpeedDial child style - UPDATED to accept Key
SpeedDialChild sdChild({
  required BuildContext context,
  required IconData icon,
  required String label,
  required VoidCallback onTap,
  Key? key,
}) {
  final theme = Theme.of(context);
  final iconColor = theme.colorScheme.onPrimaryContainer;
  final fontProvider = Provider.of<FontProvider>(context, listen: false);

  return SpeedDialChild(
    key: key,
    child: Icon(icon, color: iconColor),
    backgroundColor: theme.colorScheme.primaryContainer,
    label: label,
    labelStyle: fontProvider.getTextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
    ),
    labelBackgroundColor: theme.colorScheme.surface,
    onTap: onTap,
  );
}

const String kPrefsKeyWorkspace = 'last_workspace_id';
const String kPrefsKeyWorkspaceName = 'last_workspace_name';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.repo, this.initialIndex = 0});

  final EnvelopeRepo repo;
  final int initialIndex;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _selectedIndex;
  String? _workspaceName;

  // TUTORIAL KEYS
  final GlobalKey _fabKey = GlobalKey();
  final GlobalKey _createEnvelopeKey = GlobalKey();
  final GlobalKey _createBinderKey = GlobalKey();
  final GlobalKey _calendarTabKey = GlobalKey();
  final GlobalKey _statsTabKey = GlobalKey();
  final GlobalKey _budgetTabKey = GlobalKey();
  // Used for target in Step 3
  final GlobalKey _firstEnvelopeKey = GlobalKey();

  // SpeedDial controller for programmatic open/close
  final ValueNotifier<bool> _isSpeedDialOpen = ValueNotifier(false);

  GroupRepo get _groupRepo => GroupRepo(widget.repo.db, widget.repo);

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _restoreLastWorkspaceName();

    // TUTORIAL CHECK - DISABLED
    /*
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final tutorialController = Provider.of<TutorialController>(
        context,
        listen: false,
      );
      await tutorialController.loadState();

      debugPrint(
        '🎯 Tutorial loaded. Current step: ${tutorialController.currentStep}',
      );

      // If tutorial not started and no envelopes exist, start it
      if (tutorialController.currentStep == TutorialStep.notStarted) {
        final hasEnvelopes = await _hasEnvelopes();
        debugPrint('🎯 Has envelopes: $hasEnvelopes');
        if (!hasEnvelopes) {
          debugPrint('🎯 Starting tutorial!');
          await tutorialController.start();
          debugPrint(
            '🎯 Tutorial started! New step: ${tutorialController.currentStep}',
          );
        }
      }
    });
    */

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is int) {
        setState(() => _selectedIndex = args);
      }
    });

    Future.microtask(() {
      return runMigrationsOncePerBuild(
        db: widget.repo.db,
        explicitUid: widget.repo.currentUserId,
      );
    });

    Future.microtask(() async {
      final service = AutoPaymentService();
      final processedCount = await service.processDuePayments(
        widget.repo.currentUserId,
      );
      if (processedCount > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$processedCount scheduled payments processed successfully.',
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    });

    Future.microtask(() async {
      final prefs = await SharedPreferences.getInstance();
      final savedWorkspaceId = prefs.getString(kPrefsKeyWorkspace);
      if (savedWorkspaceId != null && savedWorkspaceId.isNotEmpty) {
        _listenToWorkspaceChanges(savedWorkspaceId);
      }
    });
  }

  // TUTORIAL HELPER - DISABLED
  /*
  Future<bool> _hasEnvelopes() async {
    try {
      final snapshot = await widget.repo.db
          .collection('users')
          .doc(widget.repo.currentUserId)
          .collection('envelopes')
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  */

  Future<void> _restoreLastWorkspaceName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _workspaceName = prefs.getString(kPrefsKeyWorkspaceName));
  }

  Future<void> _saveWorkspaceSelection({String? id, String? name}) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null || id.isEmpty) {
      await prefs.remove(kPrefsKeyWorkspace);
      await prefs.remove(kPrefsKeyWorkspaceName);
    } else {
      await prefs.setString(kPrefsKeyWorkspace, id);
      if (name != null && name.isNotEmpty) {
        await prefs.setString(kPrefsKeyWorkspaceName, name);
      }
    }
  }

  void _listenToWorkspaceChanges(String workspaceId) {
    widget.repo.db.collection('workspaces').doc(workspaceId).snapshots().listen(
      (snap) {
        if (!mounted) return;
        final data = snap.data();
        final displayName = (data?['displayName'] as String?)?.trim();
        final name = (data?['name'] as String?)?.trim();

        final newName = displayName?.isNotEmpty == true ? displayName : name;

        if (newName != _workspaceName) {
          setState(() {
            _workspaceName = newName;
          });
          _saveWorkspaceSelection(id: workspaceId, name: newName);
        }
      },
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SettingsScreen(repo: widget.repo)),
    );
  }

  @override
  void dispose() {
    _isSpeedDialOpen.dispose();
    super.dispose();
  }

  // ============================================================================
  // TUTORIAL HELPER METHODS - DISABLED
  // ============================================================================

  /*
  Future<void> _autoCreateTutorialEnvelope() async {
    try {
      debugPrint('🎯 Auto-creating tutorial envelope...');

      final now = Timestamp.now();

      // Create binder first
      final binderData = {
        'name': 'Savings Challenges',
        'emoji': '🏦',
        'color': Colors.green.value,
        'payDayEnabled': true,
        'createdAt': now,
        'userId': widget.repo.currentUserId,
      };

      final binderRef = await widget.repo.db
          .collection('users')
          .doc(widget.repo.currentUserId)
          .collection('groups')
          .add(binderData);

      // Create envelope
      final envelopeData = {
        'name': 'Savings',
        'emoji': '💰',
        'subtitle': 'For a rainy day',
        'currentAmount': 0.0,
        'targetAmount': 1000.0,
        'payDayEnabled': true,
        'payDayAmount': 100.0,
        'groupId': binderRef.id,
        'createdAt': now,
        'updatedAt': now,
        'userId': widget.repo.currentUserId,
      };

      await widget.repo.db
          .collection('users')
          .doc(widget.repo.currentUserId)
          .collection('envelopes')
          .add(envelopeData);

      debugPrint('🎯 Tutorial envelope created! Waiting for confirmation...');

      int retries = 0;
      while (retries < 20) {
        await Future.delayed(const Duration(milliseconds: 250));
        if (mounted) setState(() {});
        final exists = await _hasEnvelopes();
        if (exists) return; 
        retries++;
      }
    } catch (e) {
      debugPrint('❌ Error: $e');
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => AlertDialog(
            title: Row(
              children: const [
                Text('Tutorial Complete! '),
                Text('🎉', style: TextStyle(fontSize: 24)),
              ],
            ),
            content: const Text(
              'You\'re all set! Feel free to explore Envelope Lite.\n\n'
              'Need help? Check Settings → Help anytime!',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  Provider.of<TutorialController>(
                    context,
                    listen: false,
                  ).complete();
                },
                child: const Text('Get Started!'),
              ),
            ],
          ),
    );
  }

  GlobalKey? _getTargetKeyForCurrentStep(TutorialController controller) {
    switch (controller.currentStep) {
      case TutorialStep.envelopeCreated:
      case TutorialStep.swipeGesture:
        return _firstEnvelopeKey;
      default:
        return null;
    }
  }

  String _getTitleForCurrentStep(TutorialController controller) {
    switch (controller.currentStep) {
      case TutorialStep.welcome:
        return "Welcome to Envelope Lite! 🎉";
      case TutorialStep.autoCreating:
        return "Creating Your First Envelope...";
      case TutorialStep.envelopeCreated:
        return "Envelope Created! 💰";
      case TutorialStep.swipeGesture:
        return "Quick Actions";
      case TutorialStep.complete:
        return "You're All Set! 🎉";
      default:
        return "Tutorial";
    }
  }

  String _getDescriptionForCurrentStep(TutorialController controller) {
    switch (controller.currentStep) {
      case TutorialStep.welcome:
        return "Let's get you started! We'll create your first Savings envelope together. Ready?";

      case TutorialStep.autoCreating:
        return "Creating a Savings envelope with £1,000 target and £100 auto-fill...";

      case TutorialStep.envelopeCreated:
        return "Here's your new Savings envelope! It's organized in a 'Savings Challenges' binder.";

      case TutorialStep.swipeGesture:
        return "Swipe left or right on your envelope to quickly add or remove money!";

      case TutorialStep.complete:
        return "You're ready to go! Explore features anytime in Settings → Help.";

      default:
        return "";
    }
  }

  String _getStepCounter(TutorialController controller) {
    final step = controller.currentStep.index;
    if (step == 0 || step >= TutorialStep.values.length - 1) return "";
    return "$step/4";
  }
  */

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    final pages = <Widget>[
      _AllEnvelopes(
        repo: widget.repo,
        groupRepo: _groupRepo,
        firstEnvelopeKey: _firstEnvelopeKey,
      ),
      GroupsHomeScreen(repo: widget.repo, groupRepo: _groupRepo),
      BudgetScreen(repo: widget.repo),
      CalendarScreenV2(repo: widget.repo),
    ];

    return Consumer<TutorialController>(
      builder: (context, tutorialController, child) {
        return Stack(
          children: [
            Scaffold(
              appBar: AppBar(
                scrolledUnderElevation: 0,
                backgroundColor: theme.scaffoldBackgroundColor,
                elevation: 0,
                title: StreamBuilder<UserProfile?>(
                  stream: UserService(
                    widget.repo.db,
                    widget.repo.currentUserId,
                  ).userProfileStream,
                  builder: (context, snapshot) {
                    final displayName =
                        snapshot.data?.displayName ?? tr('your_envelopes');
                    return Text(
                      displayName,
                      style: fontProvider.getTextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    );
                  },
                ),
                actions: [
                  IconButton(
                    key: _statsTabKey,
                    icon: const Icon(Icons.bar_chart_sharp, size: 28),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => StatsHistoryScreen(repo: widget.repo),
                        ),
                      );
                    },
                    color: theme.colorScheme.primary,
                  ),
                  IconButton(
                    tooltip: tr('settings'),
                    icon: Icon(
                      Icons.settings,
                      color: theme.colorScheme.primary,
                    ),
                    onPressed: _openSettings,
                  ),
                ],
              ),
              body: pages[_selectedIndex],
              bottomNavigationBar: BottomNavigationBar(
                backgroundColor: theme.scaffoldBackgroundColor,
                selectedItemColor: theme.colorScheme.primary,
                unselectedItemColor: Colors.grey.shade600,
                elevation: 8,
                type: BottomNavigationBarType.fixed,
                selectedLabelStyle: fontProvider.getTextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: fontProvider.getTextStyle(fontSize: 14),
                items: [
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.mail_outline),
                    activeIcon: const Icon(Icons.mail),
                    label: tr('home_envelopes_tab'),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.folder_open_outlined),
                    activeIcon: const Icon(Icons.folder_copy),
                    label: tr('home_binders_tab'),
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(
                      Icons.account_balance_wallet_outlined,
                      key: _budgetTabKey,
                    ),
                    activeIcon: const Icon(Icons.account_balance_wallet),
                    label: tr('home_budget_tab'),
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(
                      Icons.calendar_today_outlined,
                      key: _calendarTabKey,
                    ),
                    activeIcon: const Icon(Icons.calendar_today),
                    label: tr('home_calendar_tab'),
                  ),
                ],
                currentIndex: _selectedIndex,
                onTap: (i) => setState(() => _selectedIndex = i),
              ),
              floatingActionButton: _selectedIndex == 0
                  ? _AllEnvelopesFAB(
                      repo: widget.repo,
                      groupRepo: _groupRepo,
                      fabKey: _fabKey,
                      createEnvelopeKey: _createEnvelopeKey,
                      createBinderKey: _createBinderKey,
                      isSpeedDialOpen: _isSpeedDialOpen,
                    )
                  : null,
            ),

            // TUTORIAL OVERLAY - DISABLED
            /*
            if (tutorialController.isActive &&
                tutorialController.currentStep != TutorialStep.complete)
              TutorialOverlay(
                targetKey: _getTargetKeyForCurrentStep(tutorialController),
                title: _getTitleForCurrentStep(tutorialController),
                description: _getDescriptionForCurrentStep(tutorialController),
                stepCounter: _getStepCounter(tutorialController),
                onNext: () async {
                  // ... tutorial logic ...
                },
                // ... other handlers ...
                showSkipStep: true,
                blockInteraction: false,
              ),
            */
          ],
        );
      },
    );
  }
}

// ====== Floating Action Button for All Envelopes ======
class _AllEnvelopesFAB extends StatelessWidget {
  const _AllEnvelopesFAB({
    required this.repo,
    required this.groupRepo,
    required this.fabKey,
    required this.createEnvelopeKey,
    required this.createBinderKey,
    required this.isSpeedDialOpen,
  });

  final EnvelopeRepo repo;
  final GroupRepo groupRepo;
  final GlobalKey fabKey;
  final GlobalKey createEnvelopeKey;
  final GlobalKey createBinderKey;
  final ValueNotifier<bool> isSpeedDialOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // tutorial logic removed for now
    // final tutorialController = Provider.of<TutorialController>(context);

    final allEnvelopesState = context
        .findAncestorStateOfType<_AllEnvelopesState>();
    final isMulti = allEnvelopesState?.isMulti ?? false;
    final selected = allEnvelopesState?.selected ?? {};

    return SpeedDial(
      key: fabKey,
      icon: isMulti ? Icons.check : Icons.add,
      activeIcon: Icons.close,
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: theme.colorScheme.onPrimary,
      overlayColor: Colors.black,
      overlayOpacity: 0.5,
      spacing: 12,
      spaceBetweenChildren: 8,
      buttonSize: const Size(56, 56),
      childrenButtonSize: const Size(56, 56),
      renderOverlay: true,
      openCloseDial: isSpeedDialOpen,
      onOpen: () {},
      children: isMulti
          ? [
              sdChild(
                context: context,
                icon: Icons.delete_forever,
                label: '${tr('delete')} (${selected.length})',
                onTap: () async {
                  await repo.deleteEnvelopes(selected);
                  allEnvelopesState?.clearSelection();
                },
              ),
              sdChild(
                context: context,
                icon: Icons.cancel,
                label: tr('cancel_selection'),
                onTap: () {
                  allEnvelopesState?.clearSelection();
                },
              ),
            ]
          : [
              sdChild(
                context: context,
                icon: Icons.calculate,
                label: tr('calculator'),
                onTap: () async {
                  await CalculatorHelper.showCalculator(context);
                },
              ),
              sdChild(
                context: context,
                icon: Icons.people_alt,
                label: tr('group_new'),
                key: createBinderKey,
                onTap: () async {
                  await editor.showGroupEditor(
                    context: context,
                    groupRepo: groupRepo,
                    envelopeRepo: repo,
                  );
                },
              ),
              sdChild(
                context: context,
                icon: Icons.mail_outline,
                label: tr('envelope_new'),
                key: createEnvelopeKey,
                onTap: () async {
                  await showEnvelopeCreator(
                    context,
                    repo: repo,
                    groupRepo: groupRepo,
                  );
                  allEnvelopesState?.refresh();
                },
              ),
              sdChild(
                context: context,
                icon: Icons.edit_note,
                label: tr('multi_select_mode'),
                onTap: () {
                  allEnvelopesState?.enableMultiSelect();
                },
              ),
            ],
    );
  }
}

// ====== All Envelopes ======
class _AllEnvelopes extends StatefulWidget {
  const _AllEnvelopes({
    required this.repo,
    required this.groupRepo,
    required this.firstEnvelopeKey,
  });
  final EnvelopeRepo repo;
  final GroupRepo groupRepo;
  final GlobalKey firstEnvelopeKey;

  @override
  State<_AllEnvelopes> createState() => _AllEnvelopesState();
}

class _AllEnvelopesState extends State<_AllEnvelopes> {
  bool isMulti = false;
  final selected = <String>{};
  String _sortBy = 'name';
  bool _showPartnerEnvelopes = true;

  @override
  void initState() {
    super.initState();
  }

  void _toggle(String id) {
    setState(() {
      if (selected.contains(id)) {
        selected.remove(id);
      } else {
        selected.add(id);
      }
      isMulti = selected.isNotEmpty;
      if (!isMulti) selected.clear();
    });
  }

  void enableMultiSelect() {
    setState(() => isMulti = true);
  }

  void clearSelection() {
    setState(() {
      selected.clear();
      isMulti = false;
    });
  }

  void refresh() {
    setState(() {});
  }

  void _openDetails(Envelope envelope) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            EnvelopeDetailScreen(envelopeId: envelope.id, repo: widget.repo),
      ),
    );
  }

  void _openPayDayScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PayDayAmountScreen(repo: widget.repo, groupRepo: widget.groupRepo),
      ),
    );
  }

  List<Envelope> _sortEnvelopes(List<Envelope> envelopes) {
    final sorted = envelopes.toList();
    switch (_sortBy) {
      case 'name':
        sorted.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      case 'balance':
        sorted.sort((a, b) => b.currentAmount.compareTo(a.currentAmount));
        break;
      case 'target':
        sorted.sort((a, b) {
          final aTarget = a.targetAmount ?? 0;
          final bTarget = b.targetAmount ?? 0;
          return bTarget.compareTo(aTarget);
        });
        break;
      case 'percent':
        sorted.sort((a, b) {
          final aPercent = (a.targetAmount != null && a.targetAmount! > 0)
              ? (a.currentAmount / a.targetAmount!) * 100
              : 0.0;
          final bPercent = (b.targetAmount != null && b.targetAmount! > 0)
              ? (b.currentAmount / b.targetAmount!) * 100
              : 0.0;
          return bPercent.compareTo(aPercent);
        });
        break;
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return StreamBuilder<List<Envelope>>(
      stream: widget.repo.envelopesStream(
        showPartnerEnvelopes: _showPartnerEnvelopes,
      ),
      builder: (c1, s1) {
        final envs = s1.data ?? [];
        return StreamBuilder<List<EnvelopeGroup>>(
          stream: widget.repo.groupsStream,
          builder: (c2, s2) {
            return StreamBuilder<List<Transaction>>(
              stream: widget.repo.transactionsStream,
              builder: (c3, s3) {
                final sortedEnvs = _sortEnvelopes(envs);
                return Scaffold(
                  appBar: AppBar(
                    scrolledUnderElevation: 0,
                    backgroundColor: theme.scaffoldBackgroundColor,
                    elevation: 0,
                    title: Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _openPayDayScreen,
                          icon: const Icon(Icons.monetization_on, size: 20),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              tr('home_pay_day_button'),
                              style: fontProvider.getTextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.secondary,
                            foregroundColor: Colors.white,
                            elevation: 3,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      PopupMenuButton<String>(
                        tooltip: tr('sort_by'),
                        icon: Icon(
                          Icons.sort,
                          color: theme.colorScheme.primary,
                        ),
                        onSelected: (value) => setState(() => _sortBy = value),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'name',
                            child: Text(tr('sort_az')),
                          ),
                          PopupMenuItem(
                            value: 'balance',
                            child: Text(tr('sort_balance')),
                          ),
                          PopupMenuItem(
                            value: 'target',
                            child: Text(tr('sort_target')),
                          ),
                          PopupMenuItem(
                            value: 'percent',
                            child: Text(tr('sort_percent')),
                          ),
                        ],
                      ),
                    ],
                  ),
                  body: sortedEnvs.isEmpty && !s1.hasData
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          children: [
                            if (widget.repo.inWorkspace)
                              PartnerVisibilityToggle(
                                isEnvelopes: true,
                                onChanged: (show) {
                                  setState(() => _showPartnerEnvelopes = show);
                                },
                              ),

                            Expanded(
                              child: sortedEnvs.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.mail_outline,
                                            size: 80,
                                            color: Colors.grey.shade300,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            tr('home_no_envelopes'),
                                            style: fontProvider.getTextStyle(
                                              fontSize: 28,
                                              color: Colors.grey.shade400,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            tr('home_create_first'),
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade400,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        16,
                                        16,
                                        96,
                                      ),
                                      children: sortedEnvs.asMap().entries.map((
                                        entry,
                                      ) {
                                        final index = entry.key;
                                        final e = entry.value;
                                        final isSel = selected.contains(e.id);
                                        final isPartner = isPartnerEnvelope(
                                          e.userId,
                                          widget.repo.currentUserId,
                                        );

                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 12.0,
                                          ),
                                          child: Stack(
                                            children: [
                                              EnvelopeTile(
                                                key: index == 0
                                                    ? widget.firstEnvelopeKey
                                                    : null,
                                                envelope: e,
                                                allEnvelopes: envs,
                                                repo: widget.repo,
                                                isSelected: isSel,
                                                isMultiSelectMode: isMulti,
                                                onLongPress: () =>
                                                    _toggle(e.id),
                                                onTap: isMulti
                                                    ? () => _toggle(e.id)
                                                    : () => _openDetails(e),
                                              ),
                                              if (isPartner)
                                                Positioned(
                                                  top: 8,
                                                  right: 8,
                                                  child: FutureBuilder<bool>(
                                                    future:
                                                        WorkspaceHelper.isCurrentlyInWorkspace(),
                                                    builder: (context, workspaceSnap) {
                                                      if (workspaceSnap.data ==
                                                          false) {
                                                        return const SizedBox.shrink();
                                                      }

                                                      return FutureBuilder<
                                                        String
                                                      >(
                                                        future:
                                                            WorkspaceHelper.getUserDisplayName(
                                                              e.userId,
                                                              widget
                                                                  .repo
                                                                  .currentUserId,
                                                            ),
                                                        builder: (context, snapshot) {
                                                          return PartnerBadge(
                                                            partnerName:
                                                                snapshot.data ??
                                                                'Partner',
                                                            size:
                                                                PartnerBadgeSize
                                                                    .small,
                                                          );
                                                        },
                                                      );
                                                    },
                                                  ),
                                                ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                            ),
                          ],
                        ),
                );
              },
            );
          },
        );
      },
    );
  }
}
