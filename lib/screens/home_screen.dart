// lib/screens/home_screen.dart
// FONT PROVIDER INTEGRATED: All GoogleFonts.caveat() replaced with FontProvider
// All button text wrapped in FittedBox to prevent wrapping

import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // NEW IMPORT
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:google_fonts/google_fonts.dart'; // Kept as requested

import '../services/envelope_repo.dart';
import '../services/group_repo.dart';
import '../services/run_migrations_once.dart';
import '../services/user_service.dart';
import '../providers/font_provider.dart'; // NEW IMPORT

import '../widgets/envelope_tile.dart';
import '../widgets/envelope_creator.dart';
import '../widgets/group_editor.dart' as editor;
import '../widgets/calculator_widget.dart';
import '../widgets/partner_visibility_toggle.dart';
import '../widgets/partner_badge.dart';

import '../models/envelope.dart';
import '../models/envelope_group.dart';
import '../models/transaction.dart';
import '../models/user_profile.dart';

import '../services/workspace_helper.dart';
import '../services/localization_service.dart';

import '../screens/envelope/envelopes_detail_screen.dart';
import 'stats_history_screen.dart';
import 'settings_screen.dart';
import 'pay_day_preview_screen.dart';
import 'calendar_screen_v2.dart';
import 'budget_screen.dart';
import 'groups_home_screen.dart';

// Themed SpeedDial child style (matches envelope detail screen)
SpeedDialChild sdChild({
  required BuildContext context,
  required IconData icon,
  required String label,
  required VoidCallback onTap,
}) {
  final theme = Theme.of(context);
  final iconColor = theme.colorScheme.onPrimaryContainer;
  final fontProvider = Provider.of<FontProvider>(context, listen: false);

  return SpeedDialChild(
    child: Icon(icon, color: iconColor),
    backgroundColor: theme.colorScheme.primaryContainer,
    label: label,
    // UPDATED: Use FontProvider
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
  const HomeScreen({super.key, required this.repo});
  final EnvelopeRepo repo;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Cache a friendly workspace name for the chip
  String? _workspaceName;

  GroupRepo get _groupRepo => GroupRepo(widget.repo.db, widget.repo);

  @override
  void initState() {
    super.initState();
    _restoreLastWorkspaceName();

    // Run migrations once per build for the current user on first entry
    Future.microtask(() {
      return runMigrationsOncePerBuild(
        db: widget.repo.db,
        explicitUid: widget.repo.currentUserId,
      );
    });

    // If already in a workspace, start listening to changes
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

          // Also update SharedPreferences
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    final pages = <Widget>[
      _AllEnvelopes(repo: widget.repo, groupRepo: _groupRepo),
      GroupsHomeScreen(repo: widget.repo, groupRepo: _groupRepo),
      BudgetScreen(repo: widget.repo),
      CalendarScreenV2(repo: widget.repo),
    ];

    return Scaffold(
      appBar: AppBar(
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
              // UPDATED: Use FontProvider
              style: fontProvider.getTextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            );
          },
        ),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        actions: [
          IconButton(
            tooltip: tr('settings'),
            icon: Icon(Icons.settings, color: theme.colorScheme.primary),
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
        // UPDATED: Use FontProvider
        selectedLabelStyle: fontProvider.getTextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        // UPDATED: Use FontProvider
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
            label: tr('home_groups_tab'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            activeIcon: const Icon(Icons.account_balance_wallet),
            label: tr('home_budget_tab'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.calendar_today_outlined),
            activeIcon: const Icon(Icons.calendar_today),
            label: tr('home_calendar_tab'),
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }
}

// ====== All Envelopes ======
class _AllEnvelopes extends StatefulWidget {
  const _AllEnvelopes({required this.repo, required this.groupRepo});
  final EnvelopeRepo repo;
  final GroupRepo groupRepo;

  @override
  State<_AllEnvelopes> createState() => _AllEnvelopesState();
}

class _AllEnvelopesState extends State<_AllEnvelopes> {
  bool isMulti = false;
  final selected = <String>{};
  String _sortBy = 'name';
  bool _showPartnerEnvelopes = true; // NEW: Partner visibility toggle

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

  String? _calcDisplay;
  String? _calcExpression;
  bool _calcMinimized = false;
  Offset _calcPosition = const Offset(20, 100);

  void _openCalculator() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final calcKey = GlobalKey<CalculatorWidgetState>();
        if (_calcDisplay != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            calcKey.currentState?.restoreState(
              _calcDisplay!,
              _calcExpression ?? '',
              _calcMinimized,
              _calcPosition,
            );
          });
        }
        return WillPopScope(
          onWillPop: () async {
            final state = calcKey.currentState;
            if (state != null) {
              _calcDisplay = state.display;
              _calcExpression = state.expression;
              _calcMinimized = state.isMinimized;
              _calcPosition = state.position;
            }
            return true;
          },
          child: Stack(children: [CalculatorWidget(key: calcKey)]),
        );
      },
    );
  }

  void _openDetails(Envelope envelope) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            EnvelopeDetailScreen(envelopeId: envelope.id, repo: widget.repo),
      ),
    );
  }

  void _openStatsScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StatsHistoryScreen(repo: widget.repo)),
    );
  }

  Future<void> _openGroupCreator() async {
    await editor.showGroupEditor(
      context: context,
      groupRepo: widget.groupRepo,
      envelopeRepo: widget.repo,
    );
  }

  void _openPayDayScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PayDayPreviewScreen(repo: widget.repo, groupRepo: widget.groupRepo),
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
                    title: Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _openPayDayScreen,
                          icon: const Icon(Icons.monetization_on, size: 20),
                          label: FittedBox(
                            // UPDATED: FittedBox
                            fit: BoxFit.scaleDown,
                            child: Text(
                              tr('home_pay_day_button'),
                              // UPDATED: FontProvider
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
                    elevation: 0,
                    actions: [
                      PopupMenuButton<String>(
                        tooltip: tr('sort_by'),
                        icon: const Icon(Icons.sort, color: Colors.black),
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
                      IconButton(
                        icon: const Icon(Icons.bar_chart_sharp, size: 28),
                        onPressed: _openStatsScreen,
                        color: Colors.black,
                      ),
                    ],
                  ),
                  body: sortedEnvs.isEmpty && !s1.hasData
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          children: [
                            // Partner visibility toggle (only in workspace)
                            if (widget.repo.inWorkspace)
                              PartnerVisibilityToggle(
                                isEnvelopes: true,
                                onChanged: (show) {
                                  setState(() => _showPartnerEnvelopes = show);
                                },
                              ),

                            // Envelope list
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
                                            // UPDATED: FontProvider
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
                                      children: sortedEnvs.map((e) {
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
                                                envelope: e,
                                                allEnvelopes: envs,
                                                isSelected: isSel,
                                                onLongPress: () =>
                                                    _toggle(e.id),
                                                onTap: isMulti
                                                    ? () => _toggle(e.id)
                                                    : () => _openDetails(e),
                                                repo: widget.repo,
                                                isMultiSelectMode: isMulti,
                                              ),
                                              // Partner badge
                                              if (isPartner)
                                                Positioned(
                                                  top: 8,
                                                  right: 8,
                                                  child: FutureBuilder<String>(
                                                    future:
                                                        WorkspaceHelper.getUserDisplayName(
                                                          e.userId,
                                                          widget
                                                              .repo
                                                              .currentUserId,
                                                        ),
                                                    builder:
                                                        (context, snapshot) {
                                                          return PartnerBadge(
                                                            partnerName:
                                                                snapshot.data ??
                                                                'Partner',
                                                            size:
                                                                PartnerBadgeSize
                                                                    .small,
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
                  floatingActionButton: SpeedDial(
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
                    children: isMulti
                        ? [
                            sdChild(
                              context: context,
                              icon: Icons.delete_forever,
                              label:
                                  '${tr('delete')} (${selected.length})', // Interpolation kept
                              onTap: () async {
                                await widget.repo.deleteEnvelopes(selected);
                                setState(() {
                                  selected.clear();
                                  isMulti = false;
                                });
                              },
                            ),
                            sdChild(
                              context: context,
                              icon: Icons.cancel,
                              label: tr('cancel_selection'),
                              onTap: () => setState(() {
                                selected.clear();
                                isMulti = false;
                              }),
                            ),
                          ]
                        : [
                            sdChild(
                              context: context,
                              icon: Icons.calculate,
                              label: tr('calculator'),
                              onTap: () => _openCalculator(),
                            ),
                            sdChild(
                              context: context,
                              icon: Icons.people_alt,
                              label: tr('group_new'),
                              onTap: _openGroupCreator,
                            ),
                            sdChild(
                              context: context,
                              icon: Icons.mail_outline,
                              label: tr('envelope_new'),
                              onTap: () async {
                                await showEnvelopeCreator(
                                  context,
                                  repo: widget.repo,
                                  groupRepo: widget.groupRepo,
                                );
                              },
                            ),
                            sdChild(
                              context: context,
                              icon: Icons.edit_note,
                              label: tr('multi_select_mode'),
                              onTap: () => setState(() => isMulti = true),
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
