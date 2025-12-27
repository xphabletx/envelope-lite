// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../utils/calculator_helper.dart';

import '../services/envelope_repo.dart';
import '../services/group_repo.dart';
import '../services/run_migrations_once.dart';
import '../services/user_service.dart';
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
import '../services/tutorial_controller.dart';

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
    onTap: onTap,
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

  // TUTORIAL KEYS
  final GlobalKey _fabKey = GlobalKey();
  final GlobalKey _createEnvelopeKey = GlobalKey();
  final GlobalKey _createBinderKey = GlobalKey();
  final GlobalKey _calendarTabKey = GlobalKey();
  final GlobalKey _statsTabKey = GlobalKey();
  final GlobalKey _budgetTabKey = GlobalKey();
  final GlobalKey _firstEnvelopeKey = GlobalKey();

  final ValueNotifier<bool> _isSpeedDialOpen = ValueNotifier(false);

  GroupRepo get _groupRepo => GroupRepo(widget.repo.db, widget.repo);

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
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
    super.dispose();
  }

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
      BudgetScreen(
        repo: widget.repo,
        initialProjectionDate: widget.projectionDate,
      ),
      CalendarScreenV2(
        repo: widget.repo,
        notificationRepo: widget.notificationRepo,
      ),
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
                    )
                  : null,
            ),
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
                    accountRepo: AccountRepo(repo.db, repo),
                  );
                  allEnvelopesState?.refresh();
                },
              ),
              sdChild(
                context: context,
                icon: Icons.edit_note,
                label: 'Delete Envelopes',
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
  bool _mineOnly = false;

  @override
  void initState() {
    super.initState();
  }

  void _showDeleteSnackBar() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${selected.length} envelopes selected'),
        duration: const Duration(days: 1), // Keep it open
        action: SnackBarAction(
          label: 'DELETE',
          textColor: Colors.red,
          onPressed: _deleteSelected,
        ),
      ),
    );
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
    setState(() {
      if (selected.contains(id)) {
        selected.remove(id);
        debugPrint('[HomeScreen] Removed from selection. Total selected: ${selected.length}');
      } else {
        selected.add(id);
        debugPrint('[HomeScreen] Added to selection. Total selected: ${selected.length}');
      }
      isMulti = selected.isNotEmpty;
      if (!isMulti) {
        clearSelection();
      } else {
        _showDeleteSnackBar();
      }
    });
  }

  void enableMultiSelect() {
    setState(() {
      isMulti = true;
      // You can optionally show a snackbar here that says "Select envelopes to delete"
      // but the user's action of long-pressing will immediately show the count.
    });
  }

  void clearSelection() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() {
      selected.clear();
      isMulti = false;
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
          accountRepo: AccountRepo(widget.repo.db, widget.repo),
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

    return StreamBuilder<List<Envelope>>(
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
          stream: widget.repo.groupsStream,
          builder: (c2, s2) {
            return StreamBuilder<List<Transaction>>(
              stream: widget.repo.transactionsStream,
              builder: (c3, s3) {
                final sortedEnvs = _sortEnvelopes(displayEnvs);
                return Scaffold(
                  appBar: AppBar(
                    scrolledUnderElevation: 0,
                    backgroundColor: theme.scaffoldBackgroundColor,
                    elevation: 0,
                    title: Row(
                      children: [
                        ElevatedButton.icon(
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
                              value: _mineOnly,
                              activeColor: theme.colorScheme.primary,
                              onChanged: (val) => setState(() => _mineOnly = val),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
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
                                                onLongPress: () =>
                                                    _toggle(e.id),
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
                );
              },
            );
          },
        );
      },
    );
  }
}
