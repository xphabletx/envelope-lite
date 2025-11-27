// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:google_fonts/google_fonts.dart';

import '../services/envelope_repo.dart';
import '../services/group_repo.dart';
import '../services/run_migrations_once.dart';
import '../services/user_service.dart';

import '../widgets/envelope_tile.dart';
import '../widgets/envelope_creator.dart';
import '../widgets/group_editor.dart' as editor;
import '../widgets/calculator_widget.dart';

import '../models/envelope.dart';
import '../models/envelope_group.dart';
import '../models/transaction.dart';
import '../models/user_profile.dart';
import '../providers/theme_provider.dart';

import '../theme/app_themes.dart';

import 'envelopes_detail_screen.dart';
import 'workspace_gate.dart';
import 'stats_history_screen.dart';
import 'settings_screen.dart';
import 'pay_day_screen.dart';
import 'calendar_screen.dart';
import 'budget_screen.dart';

// Unified SpeedDial child style
SpeedDialChild sdChild({
  required IconData icon,
  required String label,
  required VoidCallback onTap,
}) {
  return SpeedDialChild(
    child: Icon(icon, color: Colors.black),
    backgroundColor: Colors.grey.shade200,
    label: label,
    labelBackgroundColor: Colors.white,
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

  Future<String?> _fetchWorkspaceName(String id) async {
    try {
      final snap = await widget.repo.db.collection('workspaces').doc(id).get();
      if (!snap.exists) return null;
      final data = snap.data();

      // Prefer displayName over name (joinCode)
      final displayName = (data?['displayName'] as String?)?.trim();
      if (displayName?.isNotEmpty == true) {
        return displayName;
      }

      // Fallback to name (which is the join code)
      return (data?['name'] as String?)?.trim();
    } catch (_) {
      return null;
    }
  }

  Future<void> _openWorkspaceGate() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (gateCtx) => WorkspaceGate(
          onJoined: (wsId) async {
            // Set repo context first
            await widget.repo.setWorkspace(wsId);

            // Try to fetch a friendly name
            final fetchedName = await _fetchWorkspaceName(wsId);
            setState(() {
              _workspaceName = fetchedName;
            });

            // Persist both id + name locally
            await _saveWorkspaceSelection(id: wsId, name: fetchedName);

            // Start listening to workspace changes
            _listenToWorkspaceChanges(wsId);

            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Joined workspace.')));
          },
        ),
      ),
    );
  }

  Future<void> _leaveWorkspace() async {
    final wsId = widget.repo.workspaceId;

    if (wsId != null) {
      // Remove yourself from the workspace members list
      try {
        await widget.repo.db.collection('workspaces').doc(wsId).update({
          'members.${widget.repo.currentUserId}': fs.FieldValue.delete(),
        });
      } catch (e) {
        // Workspace might not exist anymore, ignore error
      }
    }

    await _saveWorkspaceSelection(id: null, name: null);
    widget.repo.setWorkspace(null);

    if (!mounted) return;
    setState(() => _workspaceName = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Left workspace. Now in Solo Mode.')),
    );
  }

  String get _workspaceLabel {
    if (!widget.repo.inWorkspace) return 'Solo Mode';

    // Show displayName if set, otherwise show the join code
    if (_workspaceName?.isNotEmpty == true) {
      return _workspaceName!;
    }

    // Fallback to join code
    final id = widget.repo.workspaceId!;
    final short = id.length > 6 ? id.substring(0, 6) : id;
    return short;
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
    final theme = Theme.of(context); // ADD THIS LINE

    final pages = <Widget>[
      _AllEnvelopes(repo: widget.repo, groupRepo: _groupRepo),
      _GroupsPage(repo: widget.repo, groupRepo: _groupRepo),
      BudgetScreen(repo: widget.repo),
      CalendarScreen(repo: widget.repo),
    ];

    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<UserProfile?>(
          stream: UserService(
            widget.repo.db,
            widget.repo.currentUserId,
          ).userProfileStream,
          builder: (context, snapshot) {
            final displayName = snapshot.data?.displayName ?? 'Team Envelopes';
            return Text(
              displayName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            );
          },
        ),
        elevation: 0,
        actions: [
          // Settings cog
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings, color: Colors.black),
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
        selectedLabelStyle: GoogleFonts.caveat(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: GoogleFonts.caveat(fontSize: 14),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.mail_outline),
            activeIcon: Icon(Icons.mail),
            label: 'Envelopes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_alt_outlined),
            activeIcon: Icon(Icons.people_alt),
            label: 'Groups',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: 'Budget',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'Calendar',
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
        builder: (context) =>
            EnvelopeDetailScreen(envelope: envelope, repo: widget.repo),
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
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PayDayScreen(repo: widget.repo)));
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
    final theme = Theme.of(context); // ADD THIS LINE

    return StreamBuilder<List<Envelope>>(
      stream: widget.repo.envelopesStream,
      builder: (c1, s1) {
        final envs = s1.data ?? [];
        return StreamBuilder<List<EnvelopeGroup>>(
          stream: widget.repo.groupsStream,
          builder: (c2, s2) {
            final _unusedGroups = s2.data ?? const <EnvelopeGroup>[];
            return StreamBuilder<List<Transaction>>(
              stream: widget.repo.transactionsStream,
              builder: (c3, s3) {
                final _ = s3.data ?? [];

                final sortedEnvs = _sortEnvelopes(envs);

                return Scaffold(
                  appBar: AppBar(
                    title: Row(
                      children: [
                        // Pay Day button
                        ElevatedButton.icon(
                          onPressed: _openPayDayScreen,
                          icon: const Icon(Icons.monetization_on, size: 20),
                          label: Text(
                            'PAY DAY',
                            style: GoogleFonts.caveat(
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              color: Colors.white,
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
                      // Sort dropdown
                      PopupMenuButton<String>(
                        tooltip: 'Sort by',
                        icon: const Icon(Icons.sort, color: Colors.black),
                        onSelected: (value) {
                          setState(() {
                            _sortBy = value;
                          });
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'name',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.sort_by_alpha,
                                  color: _sortBy == 'name'
                                      ? Colors.black
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'A-Z',
                                  style: TextStyle(
                                    fontWeight: _sortBy == 'name'
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'balance',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.monetization_on,
                                  color: _sortBy == 'balance'
                                      ? Colors.black
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Highest Balance',
                                  style: TextStyle(
                                    fontWeight: _sortBy == 'balance'
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'target',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.flag,
                                  color: _sortBy == 'target'
                                      ? Colors.black
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Highest Target',
                                  style: TextStyle(
                                    fontWeight: _sortBy == 'target'
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'percent',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.percent,
                                  color: _sortBy == 'percent'
                                      ? Colors.black
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '% to Target',
                                  style: TextStyle(
                                    fontWeight: _sortBy == 'percent'
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
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
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                          children: sortedEnvs.map((e) {
                            final isSel = selected.contains(e.id);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: EnvelopeTile(
                                envelope: e,
                                allEnvelopes: envs,
                                isSelected: isSel,
                                onLongPress: () => _toggle(e.id),
                                onTap: isMulti
                                    ? () => _toggle(e.id)
                                    : () => _openDetails(e),
                                repo: widget.repo,
                                isMultiSelectMode: isMulti,
                              ),
                            );
                          }).toList(),
                        ),
                  floatingActionButton: SpeedDial(
                    icon: isMulti ? Icons.check : Icons.add,
                    activeIcon: Icons.close,
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    overlayColor: Colors.black,
                    overlayOpacity: 0.5,
                    spacing: 12,
                    spaceBetweenChildren: 8,
                    children: isMulti
                        ? [
                            sdChild(
                              icon: Icons.delete_forever,
                              label: 'Delete (${selected.length})',
                              onTap: () async {
                                await widget.repo.deleteEnvelopes(selected);
                                setState(() {
                                  selected.clear();
                                  isMulti = false;
                                });
                              },
                            ),
                            sdChild(
                              icon: Icons.cancel,
                              label: 'Cancel Selection',
                              onTap: () => setState(() {
                                selected.clear();
                                isMulti = false;
                              }),
                            ),
                          ]
                        : [
                            sdChild(
                              icon: Icons.calculate,
                              label: 'Calculator',
                              onTap: () => _openCalculator(),
                            ),
                            sdChild(
                              icon: Icons.people_alt,
                              label: 'New Group',
                              onTap: _openGroupCreator,
                            ),
                            sdChild(
                              icon: Icons.mail_outline,
                              label: 'New Envelope',
                              onTap: () async {
                                await showEnvelopeCreator(
                                  context,
                                  repo: widget.repo,
                                );
                              },
                            ),
                            sdChild(
                              icon: Icons.edit_note,
                              label: 'Enter Multi-Select Mode',
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

// ====== Groups ======
class _GroupsPage extends StatelessWidget {
  const _GroupsPage({required this.repo, required this.groupRepo});
  final EnvelopeRepo repo;
  final GroupRepo groupRepo;

  Map<String, dynamic> _statsFor(EnvelopeGroup g, List<Envelope> envs) {
    final inGroup = envs.where((e) => e.groupId == g.id).toList();
    final totTarget = inGroup.fold(0.0, (s, e) => s + (e.targetAmount ?? 0));
    final totSaved = inGroup.fold(0.0, (s, e) => s + e.currentAmount);
    final pct = totTarget > 0
        ? (totSaved / totTarget).clamp(0.0, 1.0) * 100
        : 0.0;

    final overallTotalSaved = envs.fold(0.0, (s, e) => s + e.currentAmount);
    final overallGroupPercent = overallTotalSaved > 0
        ? (totSaved / overallTotalSaved) * 100
        : 0.0;

    return {
      'count': inGroup.length,
      'totalTarget': totTarget,
      'totalSaved': totSaved,
      'percentSaved': pct,
      'overallGroupPercent': overallGroupPercent,
    };
  }

  void _openGroupStatement(
    BuildContext context,
    EnvelopeGroup group,
    List<Envelope> envs,
    List<Transaction> txs,
  ) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => StatsHistoryScreen(repo: repo)));
  }

  Future<void> _openGroupEditor(
    BuildContext context,
    EnvelopeGroup? group,
  ) async {
    await editor.showGroupEditor(
      context: context,
      groupRepo: groupRepo,
      envelopeRepo: repo,
      group: group,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '£');
    return StreamBuilder<List<Envelope>>(
      stream: repo.envelopesStream,
      builder: (_, s1) {
        final envs = s1.data ?? [];
        return StreamBuilder<List<EnvelopeGroup>>(
          stream: repo.groupsStream,
          builder: (_, s2) {
            final groups = s2.data ?? [];
            return StreamBuilder<List<Transaction>>(
              stream: repo.transactionsStream,
              builder: (_, s3) {
                final txs = s3.data ?? [];

                return Scaffold(
                  appBar: AppBar(
                    title: const Text(
                      'Envelope Groups',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    elevation: 0,
                  ),
                  body: ListView(
                    padding: const EdgeInsets.all(16),
                    children: groups.map((g) {
                      final st = _statsFor(g, envs);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            backgroundColor: Colors.black,
                            child: Text(
                              g.name.isNotEmpty ? g.name[0] : '?',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            g.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${st['count']} envelopes | ${(st['percentSaved'] as double).toStringAsFixed(1)}% to target',
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                currency.format(st['totalSaved']),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '${(st['overallGroupPercent'] as double).toStringAsFixed(1)}% of total',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          onTap: () =>
                              _openGroupStatement(context, g, envs, txs),
                          onLongPress: () => _openGroupEditor(context, g),
                        ),
                      );
                    }).toList(),
                  ),
                  floatingActionButton: SpeedDial(
                    icon: Icons.add,
                    activeIcon: Icons.close,
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    spacing: 12,
                    spaceBetweenChildren: 8,
                    children: [
                      SpeedDialChild(
                        child: const Icon(
                          Icons.people_alt,
                          color: Colors.black,
                        ),
                        backgroundColor: Colors.grey.shade200,
                        label: 'New Group',
                        labelBackgroundColor: Colors.white,
                        onTap: () => _openGroupEditor(context, null),
                      ),
                      SpeedDialChild(
                        child: const Icon(Icons.edit_note, color: Colors.black),
                        backgroundColor: Colors.grey.shade200,
                        label: 'Edit/Delete Groups',
                        labelBackgroundColor: Colors.white,
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Long-press a group to edit/delete.'),
                          ),
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

// ====== Budget Placeholder ======
class _BudgetPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Budget Overview',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Coming soon!',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// ====== Calendar Placeholder ======
class _CalendarPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Calendar',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Coming soon!',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
