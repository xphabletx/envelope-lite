// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback, SystemNavigator;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../utils/calculator_helper.dart';

import '../services/envelope_repo.dart';
import '../services/group_repo.dart';
import '../services/run_migrations_once.dart';
import '../services/user_service.dart';
import '../services/pay_day_settings_service.dart';
import '../providers/font_provider.dart';
import '../providers/time_machine_provider.dart';
import '../services/account_repo.dart';
import '../widgets/time_machine_indicator.dart';
import '../widgets/verification_banner.dart';

import '../widgets/envelope_tile.dart';
import '../widgets/envelope_creator.dart';
import '../widgets/group_editor.dart' as editor;
import '../widgets/partner_badge.dart';
import './accounts/account_list_screen.dart';

import '../models/envelope.dart';
import '../models/envelope_group.dart';
import '../models/transaction.dart';
import '../models/user_profile.dart';

import '../services/workspace_helper.dart';
import '../services/localization_service.dart';
import '../widgets/tutorial_wrapper.dart';
import '../data/tutorial_sequences.dart';

import '../screens/envelope/envelopes_detail_screen.dart';
import 'stats_history_screen.dart';
import 'settings_screen.dart';
import 'calendar_screen.dart';
import 'budget_screen.dart';
import 'groups_home_screen.dart';
import 'pay_day/pay_day_amount_screen.dart';

// Themed SpeedDial child style
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
    onTap: () {
      debugPrint('[HomeScreen] 🔔 SpeedDialChild tapped: $label');
      onTap();
    },
  );
}

const String kPrefsKeyWorkspace = 'last_workspace_id';
const String kPrefsKeyWorkspaceName = 'last_workspace_name';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repo,
    this.initialIndex = 0,
    this.projectionDate,
    this.notificationRepo,
  });

  final EnvelopeRepo repo;
  final int initialIndex;
  final DateTime? projectionDate;
  final dynamic notificationRepo; // NotificationRepo - using dynamic to avoid import

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _selectedIndex;
  String? _workspaceName;
  DateTime? _lastBackPress;

  // TUTORIAL KEYS
  final GlobalKey _fabKey = GlobalKey();
  final GlobalKey _createEnvelopeKey = GlobalKey();
  final GlobalKey _createBinderKey = GlobalKey();
  final GlobalKey _calendarTabKey = GlobalKey();
  final GlobalKey _statsTabKey = GlobalKey();
  final GlobalKey _budgetTabKey = GlobalKey();
  final GlobalKey _firstEnvelopeKey = GlobalKey();
  final GlobalKey _sortButtonKey = GlobalKey();
  final GlobalKey _mineOnlyToggleKey = GlobalKey();

  // Key to access _AllEnvelopesState from FAB
  final GlobalKey<_AllEnvelopesState> _allEnvelopesKey = GlobalKey<_AllEnvelopesState>();

  final ValueNotifier<bool> _isSpeedDialOpen = ValueNotifier(false);
  final ValueNotifier<bool> _isMultiSelect = ValueNotifier(false);

  // Initialize repos once
  late final GroupRepo _groupRepo;
  late final AccountRepo _accountRepo;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;

    // Initialize repos once
    _groupRepo = GroupRepo(widget.repo);
    _accountRepo = AccountRepo(widget.repo);

    _restoreLastWorkspaceName();

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
      final prefs = await SharedPreferences.getInstance();
      final savedWorkspaceId = prefs.getString(kPrefsKeyWorkspace);
      if (savedWorkspaceId != null && savedWorkspaceId.isNotEmpty) {
        _listenToWorkspaceChanges(savedWorkspaceId);
      }
    });
  }

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

  /// Build body with optional verification banner for unverified email/password users
  Widget _buildBodyWithVerificationBanner(Widget child) {
    final user = FirebaseAuth.instance.currentUser;

    // Only show banner for unverified email/password users
    final shouldShowBanner = user != null &&
        !user.emailVerified &&
        !user.isAnonymous &&
        user.providerData.isNotEmpty &&
        user.providerData.first.providerId == 'password';

    if (!shouldShowBanner) {
      return child;
    }

    return Column(
      children: [
        const VerificationBanner(),
        Expanded(child: child),
      ],
    );
  }

  @override
  void dispose() {
    _isSpeedDialOpen.dispose();
    _isMultiSelect.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    final pages = <Widget>[
      _AllEnvelopes(
        key: _allEnvelopesKey,
        repo: widget.repo,
        groupRepo: _groupRepo,
        accountRepo: _accountRepo,
        firstEnvelopeKey: _firstEnvelopeKey,
        sortButtonKey: _sortButtonKey,
        mineOnlyToggleKey: _mineOnlyToggleKey,
        isMultiSelectNotifier: _isMultiSelect,
      ),
      GroupsHomeScreen(repo: widget.repo, groupRepo: _groupRepo),
      BudgetScreen(
        repo: widget.repo,
        initialProjectionDate: widget.projectionDate,
      ),
      CalendarScreenV2(
        repo: widget.repo,
        notificationRepo: widget.notificationRepo,
      ),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;

        // Double-tap to exit pattern
        final now = DateTime.now();
        final backButtonHasNotBeenPressedOrSnackBarHasBeenClosed =
            _lastBackPress == null ||
            now.difference(_lastBackPress!) > const Duration(seconds: 2);

        if (backButtonHasNotBeenPressedOrSnackBarHasBeenClosed) {
          _lastBackPress = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          // Exit app
          SystemNavigator.pop();
        }
      },
      child: TutorialWrapper(
        tutorialSequence: homeTutorial,
        spotlightKeys: {
          'fab': _fabKey,
          'sort_button': _sortButtonKey,
          'mine_only_toggle': _mineOnlyToggleKey,
        },
        child: Scaffold(
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
              final profile = snapshot.data;
              final displayName = profile?.displayName ?? tr('your_envelopes');
              final photoURL = profile?.photoURL;

              return Row(
                children: [
                  if (photoURL != null && photoURL.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: CircleAvatar(
                        backgroundImage: NetworkImage(photoURL),
                        radius: 20,
                      ),
                    ),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        displayName,
                        style: fontProvider.getTextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            // NEW: Moved Account List (Wallet) icon here
            IconButton(
              icon: const Icon(Icons.account_balance_wallet, size: 28),
              tooltip: 'Manage Accounts',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AccountListScreen(envelopeRepo: widget.repo),
                  ),
                );
              },
              color: theme.colorScheme.primary,
            ),
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
        body: _buildBodyWithVerificationBanner(pages[_selectedIndex]),
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
              icon: const Icon(Icons.menu_book_outlined),
              activeIcon: const Icon(Icons.menu_book),
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
                allEnvelopesKey: _allEnvelopesKey,
                isMultiSelectNotifier: _isMultiSelect,
              )
            : null,
        ),
      ),
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
    required this.allEnvelopesKey,
    required this.isMultiSelectNotifier,
  });

  final EnvelopeRepo repo;
  final GroupRepo groupRepo;
  final GlobalKey fabKey;
  final GlobalKey createEnvelopeKey;
  final GlobalKey createBinderKey;
  final ValueNotifier<bool> isSpeedDialOpen;
  final GlobalKey<_AllEnvelopesState> allEnvelopesKey;
  final ValueNotifier<bool> isMultiSelectNotifier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ValueListenableBuilder<bool>(
      valueListenable: isMultiSelectNotifier,
      builder: (context, isMulti, child) {
        final allEnvelopesState = allEnvelopesKey.currentState;

        debugPrint('[HomeScreen] 🔄 _AllEnvelopesFAB building - isMulti: $isMulti, state found: ${allEnvelopesState != null}');

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
      onPress: isMulti ? () {
        debugPrint('[HomeScreen] ✅ FAB onPress called (isMulti=true)');
        allEnvelopesState?.clearSelection();
      } : null,
      children: isMulti
          ? []
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
                icon: Icons.chrome_reader_mode,
                label: tr('group_new_binder'),
                key: createBinderKey,
                onTap: () async {
                  // Check Time Machine mode
                  final timeMachine = Provider.of<TimeMachineProvider>(context, listen: false);
                  if (timeMachine.shouldBlockModifications()) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(timeMachine.getBlockedActionMessage()),
                        backgroundColor: Colors.orange,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                    return;
                  }

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
                  // Check Time Machine mode
                  final timeMachine = Provider.of<TimeMachineProvider>(context, listen: false);
                  if (timeMachine.shouldBlockModifications()) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(timeMachine.getBlockedActionMessage()),
                        backgroundColor: Colors.orange,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                    return;
                  }

                  final homeScreenState = context.findAncestorStateOfType<_HomeScreenState>();
                  await showEnvelopeCreator(
                    context,
                    repo: repo,
                    groupRepo: groupRepo,
                    accountRepo: homeScreenState!._accountRepo,
                  );
                  allEnvelopesState?.refresh();
                },
              ),
              sdChild(
                context: context,
                icon: Icons.edit_note,
                label: 'Delete Envelopes',
                onTap: () {
                  // Check Time Machine mode
                  final timeMachine = Provider.of<TimeMachineProvider>(context, listen: false);
                  if (timeMachine.shouldBlockModifications()) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(timeMachine.getBlockedActionMessage()),
                        backgroundColor: Colors.orange,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                    return;
                  }

                  debugPrint('[HomeScreen] 🔍 Delete Envelopes button tapped');
                  debugPrint('[HomeScreen] 🔍 allEnvelopesState is null: ${allEnvelopesState == null}');
                  if (allEnvelopesState == null) {
                    debugPrint('[HomeScreen] ❌ ERROR: Could not find _AllEnvelopesState ancestor');
                  } else {
                    debugPrint('[HomeScreen] ✅ Found _AllEnvelopesState, calling enableMultiSelect()');
                    allEnvelopesState.enableMultiSelect();
                  }
                  // Close the speed dial after enabling multi-select
                  Future.microtask(() {
                    debugPrint('[HomeScreen] 🔍 Closing speed dial');
                    isSpeedDialOpen.value = false;
                  });
                },
              ),
            ],
        );
      },
    );
  }
}

// ====== All Envelopes ======
class _AllEnvelopes extends StatefulWidget {
  const _AllEnvelopes({
    super.key,
    required this.repo,
    required this.groupRepo,
    required this.accountRepo,
    required this.firstEnvelopeKey,
    required this.sortButtonKey,
    required this.mineOnlyToggleKey,
    required this.isMultiSelectNotifier,
  });
  final EnvelopeRepo repo;
  final GroupRepo groupRepo;
  final AccountRepo accountRepo;
  final GlobalKey firstEnvelopeKey;
  final GlobalKey sortButtonKey;
  final GlobalKey mineOnlyToggleKey;
  final ValueNotifier<bool> isMultiSelectNotifier;

  @override
  State<_AllEnvelopes> createState() => _AllEnvelopesState();
}

class _AllEnvelopesState extends State<_AllEnvelopes>
    with SingleTickerProviderStateMixin {
  bool isMulti = false;
  final selected = <String>{};
  String _sortBy = 'name';
  bool _mineOnly = false;

  // Pay Day animation
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize pulse animation for Pay Day button
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    // Start animation if it's pay day
    _checkPayDayAndAnimate();
  }

  Future<void> _checkPayDayAndAnimate() async {
    if (await _isPayDayToday()) {
      _pulseController.repeat(reverse: true);
    }
  }

  /// Check if today is pay day based on settings
  Future<bool> _isPayDayToday() async {
    try {
      final payDayService = PayDaySettingsService(
        widget.repo.db,
        widget.repo.currentUserId,
      );
      final settings = await payDayService.getPayDaySettings();

      if (settings == null || settings.nextPayDate == null) {
        return false;
      }

      final today = DateTime.now();
      DateTime payDate = settings.nextPayDate!;

      // Apply weekend adjustment if enabled
      if (settings.adjustForWeekends) {
        payDate = settings.adjustForWeekend(payDate);
      }

      // Check if today matches pay day (ignoring time)
      return today.year == payDate.year &&
             today.month == payDate.month &&
             today.day == payDate.day;
    } catch (e) {
      debugPrint('[HomeScreen] Error checking pay day: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _deleteSelected() async {
    debugPrint('[HomeScreen] 📋 Showing bulk delete confirmation for ${selected.length} envelopes');
    debugPrint('[HomeScreen] Envelope IDs: $selected');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${selected.length} envelopes?'),
        content: const Text(
          'This will permanently delete the selected envelopes and all their transactions. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      debugPrint('[HomeScreen] ✅ User confirmed bulk delete');
      debugPrint('[HomeScreen] 📞 Calling repo.deleteEnvelopes with ${selected.length} IDs...');
      try {
        await widget.repo.deleteEnvelopes(selected);
        debugPrint('[HomeScreen] ✅ Bulk delete completed successfully');
        clearSelection();
      } catch (e) {
        debugPrint('[HomeScreen] ❌ Bulk delete failed: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting envelopes: $e')),
          );
        }
      }
    } else {
      debugPrint('[HomeScreen] ❌ User cancelled bulk delete');
    }
  }

  void _toggle(String id) {
    debugPrint('[HomeScreen] 🔄 Toggling envelope selection: $id');
    HapticFeedback.selectionClick();
    setState(() {
      if (selected.contains(id)) {
        selected.remove(id);
        debugPrint('[HomeScreen] Removed from selection. Total selected: ${selected.length}');
      } else {
        selected.add(id);
        debugPrint('[HomeScreen] Added to selection. Total selected: ${selected.length}');
      }
      isMulti = selected.isNotEmpty;
      widget.isMultiSelectNotifier.value = isMulti;
      if (!isMulti) {
        clearSelection();
      }
    });
  }

  void enableMultiSelect() {
    debugPrint('[HomeScreen] 🎯 enableMultiSelect() called');
    HapticFeedback.mediumImpact();
    setState(() {
      isMulti = true;
      widget.isMultiSelectNotifier.value = true;
      debugPrint('[HomeScreen] ✅ isMulti set to true');
      // Selection mode activated via FAB
    });
  }

  void clearSelection() {
    debugPrint('[HomeScreen] 🧹 clearSelection() called');
    setState(() {
      selected.clear();
      isMulti = false;
      widget.isMultiSelectNotifier.value = false;
      debugPrint('[HomeScreen] ✅ Selection cleared, isMulti set to false');
    });
  }

  void refresh() {
    setState(() {});
  }

  void _openDetails(Envelope envelope) async {
    // Prevent access to partner's envelopes
    if (envelope.userId != widget.repo.currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You cannot view details of your partner's envelopes"),
        ),
      );
      return;
    }
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
        builder: (_) => PayDayAmountScreen(
          repo: widget.repo,
          groupRepo: widget.groupRepo,
          accountRepo: widget.accountRepo,
        ),
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
    final isWorkspace = widget.repo.inWorkspace;
    final showPartnerEnvelopes = !_mineOnly;
    final timeMachine = Provider.of<TimeMachineProvider>(context);

    return PopScope(
      canPop: !isMulti,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop && isMulti) {
          clearSelection();
        }
      },
      child: StreamBuilder<List<Envelope>>(
      initialData: widget.repo.getEnvelopesSync(showPartnerEnvelopes: showPartnerEnvelopes), // ✅ Instant data!
      stream: widget.repo.envelopesStream(
        showPartnerEnvelopes: showPartnerEnvelopes,
      ),
      builder: (c1, s1) {
        final realEnvs = s1.data ?? [];

        // Apply Time Machine projection if active
        final displayEnvs = timeMachine.isActive
            ? realEnvs.map((e) => timeMachine.getProjectedEnvelope(e)).toList()
            : realEnvs;

        return StreamBuilder<List<EnvelopeGroup>>(
          initialData: widget.repo.getGroupsSync(), // ✅ Instant data!
          stream: widget.repo.groupsStream,
          builder: (c2, s2) {
            return StreamBuilder<List<Transaction>>(
              initialData: widget.repo.getTransactionsSync(), // ✅ Instant data!
              stream: widget.repo.transactionsStream,
              builder: (c3, s3) {
                final sortedEnvs = _sortEnvelopes(displayEnvs);
                return Scaffold(
                  appBar: isMulti ? AppBar(
                    scrolledUnderElevation: 0,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: clearSelection,
                      tooltip: 'Cancel',
                    ),
                    title: Text(
                      '${selected.length} selected',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          setState(() {
                            // Toggle: if all selected, deselect all; otherwise select all
                            final allSelected = selected.length == sortedEnvs.length;
                            if (allSelected) {
                              selected.clear();
                            } else {
                              selected.clear();
                              for (final e in sortedEnvs) {
                                selected.add(e.id);
                              }
                            }
                          });
                        },
                        child: Text(
                          selected.length == sortedEnvs.length ? 'Deselect All' : 'Select All',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ) : AppBar(
                    scrolledUnderElevation: 0,
                    backgroundColor: theme.scaffoldBackgroundColor,
                    elevation: 0,
                    title: Row(
                      children: [
                        FutureBuilder<bool>(
                          future: _isPayDayToday(),
                          builder: (context, snapshot) {
                            final isPayDay = snapshot.data ?? false;

                            return AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: isPayDay ? _scaleAnimation.value : 1.0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: isPayDay
                                          ? [
                                              BoxShadow(
                                                color: theme.colorScheme.secondary
                                                    .withValues(alpha: _glowAnimation.value),
                                                blurRadius: 20,
                                                spreadRadius: 2,
                                              ),
                                            ]
                                          : [],
                                    ),
                                    child: ElevatedButton.icon(
                                      onPressed: timeMachine.isActive ? null : _openPayDayScreen,
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
                                        elevation: isPayDay ? 8 : 3,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                    actions: [
                      if (isWorkspace)
                        Row(
                          children: [
                            Text(
                              'Mine Only',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            Switch(
                              key: widget.mineOnlyToggleKey,
                              value: _mineOnly,
                              activeTrackColor: theme.colorScheme.primary,
                              onChanged: (val) => setState(() => _mineOnly = val),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      PopupMenuButton<String>(
                        key: widget.sortButtonKey,
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
                            // Time Machine Indicator at the top
                            const TimeMachineIndicator(),

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
                                                allEnvelopes: displayEnvs,
                                                repo: widget.repo,
                                                isSelected: isSel,
                                                isMultiSelectMode: isMulti,
                                                // REMOVED: onLongPress (use FAB to enter selection mode)
                                                onTap: isMulti
                                                    ? () => _toggle(e.id)
                                                    : () => _openDetails(e),
                                              ),
                                              if (isPartner && !_mineOnly)
                                                Positioned(
                                                  bottom: 24,
                                                  right: 16,
                                                  child: FutureBuilder<String>(
                                                    future:
                                                        WorkspaceHelper.getUserDisplayName(
                                                          e.userId,
                                                          widget.repo.currentUserId,
                                                        ),
                                                    builder: (context, snapshot) {
                                                      return PartnerBadge(
                                                        partnerName:
                                                            snapshot.data ?? 'Partner',
                                                        size: PartnerBadgeSize.normal,
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
                  bottomNavigationBar: isMulti
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, -2),
                              ),
                            ],
                          ),
                          child: SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  selected.isEmpty
                                      ? 'Select envelopes to delete'
                                      : '${selected.length} envelope${selected.length > 1 ? 's' : ''} selected',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  onPressed:
                                      selected.isEmpty ? null : _deleteSelected,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    disabledBackgroundColor:
                                        Colors.grey.shade300,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 14,
                                    ),
                                  ),
                                  icon: const Icon(Icons.delete),
                                  label: const Text('Delete'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : null,
                );
              },
            );
          },
        );
      },
      ),
    );
  }
}
