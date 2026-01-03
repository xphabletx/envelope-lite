// lib/screens/workspace_management_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import '../services/workspace_helper.dart';
import '../services/envelope_repo.dart';
import '../services/account_repo.dart';
import '../services/localization_service.dart';
import '../providers/font_provider.dart';
import '../providers/workspace_provider.dart';
import '../models/envelope.dart';
import '../models/envelope_group.dart';
import '../models/account.dart';
import '../widgets/partner_badge.dart';
import '../widgets/tutorial_wrapper.dart';
import '../data/tutorial_sequences.dart';
import '../utils/responsive_helper.dart';

class WorkspaceManagementScreen extends StatefulWidget {
  const WorkspaceManagementScreen({
    super.key,
    required this.workspaceId,
    required this.currentUserId,
    required this.repo,
    required this.onWorkspaceLeft,
  });

  final String workspaceId;
  final String currentUserId;
  final EnvelopeRepo repo;
  final VoidCallback onWorkspaceLeft;

  @override
  State<WorkspaceManagementScreen> createState() =>
      _WorkspaceManagementScreenState();
}

class _WorkspaceManagementScreenState extends State<WorkspaceManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  String _workspaceName = '';
  String _joinCode = '';
  List<WorkspaceMember> _members = [];
  final int _selectedNavIndex = 0; // Default to first tab (envelopes)
  bool _showPartnerOnly = false; // For "Mine only" toggle
  bool _hideFutureEnvelopes = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('workspaces')
          .doc(widget.workspaceId)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        _workspaceName = data['displayName'] ?? data['name'] ?? '';
        _joinCode = data['joinCode'] ?? '';
      }

      // Load hide future envelopes preference
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        _hideFutureEnvelopes =
            userData?['workspacePreferences']?['hideFutureEnvelopes'] ?? false;
      }

      final members = await _getMembers();

      if (mounted) {
        setState(() {
          _members = members;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading workspace data: $e');
    }
  }

  Future<List<WorkspaceMember>> _getMembers() async {
    try {
      final workspaceDoc = await FirebaseFirestore.instance
          .collection('workspaces')
          .doc(widget.workspaceId)
          .get();

      if (!workspaceDoc.exists) return [];

      final data = workspaceDoc.data();
      final memberIds = ((data?['members'] as Map<String, dynamic>?) ?? {}).keys
          .toList();

      final List<WorkspaceMember> members = [];

      for (final memberId in memberIds) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(memberId)
            .get();
        final userData = userDoc.data();
        final displayName =
            (userData?['displayName'] as String?) ?? tr('unknown_user');
        final email = (userData?['email'] as String?) ?? '';
        final nickname = await WorkspaceHelper.getUserDisplayName(
          memberId,
          widget.currentUserId,
        );

        members.add(
          WorkspaceMember(
            userId: memberId,
            displayName: displayName,
            email: email,
            nickname: nickname != displayName ? nickname : null,
            isCurrentUser: memberId == widget.currentUserId,
          ),
        );
      }
      return members;
    } catch (_) {
      return [];
    }
  }

  Future<void> _leaveWorkspace() async {
    // Get provider references before async operations
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final workspaceProvider = Provider.of<WorkspaceProvider>(context, listen: false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          tr('workspace_leave_confirm'),
          style: fontProvider.getTextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(tr('workspace_leave_warning')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(tr('workspace_leave_button')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Remove from workspace members
      await WorkspaceHelper.leaveWorkspace(
        widget.workspaceId,
        widget.currentUserId,
      );

      // CRITICAL FIX: Update global WorkspaceProvider to trigger rebuild
      await workspaceProvider.setWorkspaceId(null);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('workspace_left_success'))));

      // Pop back to home - it will rebuild without workspace
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${tr('error_generic')}: $e')));
    }
  }

  Future<void> _editNickname(WorkspaceMember member) async {
    final nicknameCtrl = TextEditingController(text: member.nickname ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Nickname'),
        content: TextField(controller: nicknameCtrl),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, nicknameCtrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .set({
            'nicknames': {
              member.userId: result.isEmpty ? FieldValue.delete() : result,
            },
          }, SetOptions(merge: true));
      _loadData(); // reload
    }
  }

  void _onNavTapped(int index) {
    // Navigate back to home with the correct tab
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/home',
      (route) => false,
      arguments: index,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final responsive = context.responsive;
    final isLandscape = responsive.isLandscape;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: FittedBox(
            child: Text(
              tr('workspace_management'),
              style: fontProvider.getTextStyle(
                fontSize: isLandscape ? 20 : 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          elevation: 0),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return TutorialWrapper(
      tutorialSequence: workspaceTutorial,
      spotlightKeys: const {},
      child: Scaffold(
      appBar: AppBar(
        title: FittedBox(
          child: Text(
            'Workspace Management',
            style: fontProvider.getTextStyle(
              fontSize: isLandscape ? 20 : 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          labelStyle: fontProvider.getTextStyle(
            fontSize: isLandscape ? 12 : 14,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: fontProvider.getTextStyle(
            fontSize: isLandscape ? 11 : 13,
          ),
          tabs: [
            Tab(text: tr('workspace_tab_sharing')),
            Tab(text: tr('workspace_tab_members')),
            Tab(text: tr('workspace_tab_workspace')),
          ],
        ),
      ),
      body: Column(
        children: [
          // JOIN CODE HEADER
          if (_joinCode.isNotEmpty)
            Container(
              width: double.infinity,
              color: theme.colorScheme.primary.withValues(alpha:0.1),
              padding: EdgeInsets.symmetric(
                vertical: isLandscape ? 8 : 12,
                horizontal: isLandscape ? 12 : 16,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Join Code: ",
                    style: TextStyle(
                      fontSize: isLandscape ? 12 : 14,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  SelectableText(
                    _joinCode,
                    style: TextStyle(
                      fontSize: isLandscape ? 14 : 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: isLandscape ? 1.2 : 1.5,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  SizedBox(width: isLandscape ? 6 : 8),
                  IconButton(
                    icon: Icon(Icons.copy, size: isLandscape ? 16 : 20),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _joinCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copied!')),
                      );
                    },
                    tooltip: 'Copy Code',
                  ),
                ],
              ),
            ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSharingTab(),
                _buildMembersTab(),
                _buildWorkspaceTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: Colors.grey.shade600,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        iconSize: isLandscape ? 20 : 24,
        selectedLabelStyle: fontProvider.getTextStyle(
          fontSize: isLandscape ? 11 : 14,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: fontProvider.getTextStyle(
          fontSize: isLandscape ? 10 : 12,
        ),
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.mail_outline, size: isLandscape ? 20 : 24),
            activeIcon: Icon(Icons.mail, size: isLandscape ? 20 : 24),
            label: tr('home_envelopes_tab'),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_open_outlined, size: isLandscape ? 20 : 24),
            activeIcon: Icon(Icons.folder_copy, size: isLandscape ? 20 : 24),
            label: tr('home_binders_tab'),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined, size: isLandscape ? 20 : 24),
            activeIcon: Icon(Icons.account_balance_wallet, size: isLandscape ? 20 : 24),
            label: tr('home_budget_tab'),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined, size: isLandscape ? 20 : 24),
            activeIcon: Icon(Icons.calendar_today, size: isLandscape ? 20 : 24),
            label: tr('home_calendar_tab'),
          ),
        ],
        currentIndex: _selectedNavIndex,
        onTap: _onNavTapped,
      ),
    ),
    );
  }

  Widget _buildSharingTab() {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final responsive = context.responsive;
    final isLandscape = responsive.isLandscape;

    return Column(
      children: [
        // Filter bar with "Mine only" toggle
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isLandscape ? 16 : 20,
            vertical: isLandscape ? 8 : 12,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Manage Sharing',
                style: fontProvider.getTextStyle(
                  fontSize: isLandscape ? 14 : 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Mine only',
                        style: fontProvider.getTextStyle(
                          fontSize: isLandscape ? 10 : 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      Switch(
                        value: !_showPartnerOnly,
                        activeTrackColor: theme.colorScheme.secondary,
                        onChanged: (val) => setState(() => _showPartnerOnly = !val),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        // Hide future envelopes toggle
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isLandscape ? 16 : 20),
          child: SwitchListTile(
            title: Text(
              tr('workspace_hide_future'),
              style: fontProvider.getTextStyle(fontSize: isLandscape ? 14 : 16),
            ),
            subtitle: Text(
              'New envelopes will be private by default',
              style: TextStyle(
                fontSize: isLandscape ? 11 : 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            value: _hideFutureEnvelopes,
            onChanged: (val) async {
              setState(() => _hideFutureEnvelopes = val);
              await FirebaseFirestore.instance.collection('users').doc(widget.currentUserId).set({
                'workspacePreferences': {'hideFutureEnvelopes': val},
              }, SetOptions(merge: true));
            },
            activeTrackColor: theme.colorScheme.primary,
          ),
        ),
        const Divider(),

        Expanded(
          child: ListView(
            padding: EdgeInsets.all(isLandscape ? 12 : 20),
            children: [
              Text(
                tr('workspace_my_envelopes'),
                style: fontProvider.getTextStyle(
                  fontSize: isLandscape ? 18 : 24,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              SizedBox(height: isLandscape ? 8 : 12),
              StreamBuilder<List<Envelope>>(
                stream: widget.repo.envelopesStream(showPartnerEnvelopes: true),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  var envelopes = snapshot.data!;

                  // Filter based on "Mine only" toggle
                  if (!_showPartnerOnly) {
                    envelopes = envelopes
                        .where((env) => env.userId == widget.currentUserId)
                        .toList();
                  }

                  if (envelopes.isEmpty) {
                    return Card(
                      child: Padding(
                        padding: EdgeInsets.all(isLandscape ? 16 : 24),
                        child: Center(
                          child: Text(
                            tr('home_no_envelopes'),
                            style: fontProvider.getTextStyle(
                              fontSize: isLandscape ? 12 : 14,
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  return Card(
                    child: Column(
                      children: envelopes.map((env) {
                        final isPartner = env.userId != widget.currentUserId;
                        return CheckboxListTile(
                          value: env.isShared,
                          enabled: !isPartner, // Can't toggle partner's envelopes
                          onChanged: isPartner ? null : (value) async {
                            await widget.repo.updateEnvelope(
                              envelopeId: env.id,
                              isShared: value ?? true,
                            );
                          },
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  env.name,
                                  style: fontProvider.getTextStyle(
                                    fontSize: isLandscape ? 14 : 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (isPartner)
                                FutureBuilder<String>(
                                  future: WorkspaceHelper.getUserDisplayName(
                                    env.userId,
                                    widget.currentUserId,
                                  ),
                                  builder: (context, snapshot) {
                                    return PartnerBadge(
                                      partnerName: snapshot.data ?? 'Partner',
                                      size: PartnerBadgeSize.small,
                                    );
                                  },
                                ),
                            ],
                          ),
                          subtitle: Text(
                            isPartner
                                ? "Partner's envelope (read-only)"
                                : (env.isShared
                                    ? tr('workspace_visible_to_partner')
                                    : tr('workspace_hidden_from_partner')),
                            style: TextStyle(
                              fontSize: isLandscape ? 11 : 12,
                              color: isPartner
                                  ? Colors.blue
                                  : (env.isShared ? Colors.green : Colors.grey),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
              SizedBox(height: isLandscape ? 20 : 32),
              Text(
                tr('workspace_my_binders'),
                style: fontProvider.getTextStyle(
                  fontSize: isLandscape ? 18 : 24,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              SizedBox(height: isLandscape ? 8 : 12),
              StreamBuilder<List<EnvelopeGroup>>(
                stream: widget.repo.groupsStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  var groups = snapshot.data!;

                  // Filter based on "Mine only" toggle
                  if (!_showPartnerOnly) {
                    groups = groups
                        .where((g) => g.userId == widget.currentUserId)
                        .toList();
                  }

                  if (groups.isEmpty) {
                    return Card(
                      child: Padding(
                        padding: EdgeInsets.all(isLandscape ? 16 : 24),
                        child: Center(
                          child: Text(
                            tr('group_no_binders'),
                            style: fontProvider.getTextStyle(
                              fontSize: isLandscape ? 12 : 14,
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  return Card(
                    child: Column(
                      children: groups.map((group) {
                        final isPartner = group.userId != widget.currentUserId;
                        return CheckboxListTile(
                          value: group.isShared,
                          enabled: !isPartner,
                          onChanged: isPartner ? null : (value) async {
                            // Update in Hive
                            final groupBox = Hive.box<EnvelopeGroup>('groups');
                            final updatedGroup = group.copyWith(isShared: value ?? true);
                            await groupBox.put(group.id, updatedGroup);
                          },
                          title: Row(
                            children: [
                              Text(
                                group.emoji ?? '📁',
                                style: TextStyle(fontSize: isLandscape ? 16 : 20),
                              ),
                              SizedBox(width: isLandscape ? 6 : 8),
                              Expanded(
                                child: Text(
                                  group.name,
                                  style: fontProvider.getTextStyle(
                                    fontSize: isLandscape ? 14 : 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (isPartner)
                                FutureBuilder<String>(
                                  future: WorkspaceHelper.getUserDisplayName(
                                    group.userId,
                                    widget.currentUserId,
                                  ),
                                  builder: (context, snapshot) {
                                    return PartnerBadge(
                                      partnerName: snapshot.data ?? 'Partner',
                                      size: PartnerBadgeSize.small,
                                    );
                                  },
                                ),
                            ],
                          ),
                          subtitle: Text(
                            isPartner
                                ? "Partner's binder (read-only)"
                                : (group.isShared
                                    ? tr('workspace_visible_to_partner')
                                    : tr('workspace_hidden_from_partner')),
                            style: TextStyle(
                              fontSize: isLandscape ? 11 : 12,
                              color: isPartner
                                  ? Colors.blue
                                  : (group.isShared ? Colors.green : Colors.grey),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
              SizedBox(height: isLandscape ? 20 : 32),
              Text(
                'Accounts',
                style: fontProvider.getTextStyle(
                  fontSize: isLandscape ? 18 : 24,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              SizedBox(height: isLandscape ? 8 : 12),
              StreamBuilder<List<Account>>(
                stream: AccountRepo(widget.repo).accountsStream(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  var accounts = snapshot.data!;

                  // Filter based on "Mine only" toggle
                  if (!_showPartnerOnly) {
                    accounts = accounts
                        .where((acc) => acc.userId == widget.currentUserId)
                        .toList();
                  }

                  if (accounts.isEmpty) {
                    return Card(
                      child: Padding(
                        padding: EdgeInsets.all(isLandscape ? 16 : 24),
                        child: Center(
                          child: Text(
                            'No accounts',
                            style: fontProvider.getTextStyle(
                              fontSize: isLandscape ? 12 : 14,
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  return Card(
                    child: Column(
                      children: accounts.map((account) {
                        final isPartner = account.userId != widget.currentUserId;
                        return CheckboxListTile(
                          value: account.isShared,
                          enabled: !isPartner,
                          onChanged: isPartner ? null : (value) async {
                            // Update in Hive
                            final accountBox = Hive.box<Account>('accounts');
                            final updatedAccount = account.copyWith(isShared: value ?? true);
                            await accountBox.put(account.id, updatedAccount);
                          },
                          title: Row(
                            children: [
                              Text(
                                account.emoji ?? '💳',
                                style: TextStyle(fontSize: isLandscape ? 16 : 20),
                              ),
                              SizedBox(width: isLandscape ? 6 : 8),
                              Expanded(
                                child: Text(
                                  account.name,
                                  style: fontProvider.getTextStyle(
                                    fontSize: isLandscape ? 14 : 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (isPartner)
                                FutureBuilder<String>(
                                  future: WorkspaceHelper.getUserDisplayName(
                                    account.userId,
                                    widget.currentUserId,
                                  ),
                                  builder: (context, snapshot) {
                                    return PartnerBadge(
                                      partnerName: snapshot.data ?? 'Partner',
                                      size: PartnerBadgeSize.small,
                                    );
                                  },
                                ),
                            ],
                          ),
                          subtitle: Text(
                            isPartner
                                ? "Partner's account (read-only)"
                                : (account.isShared
                                    ? tr('workspace_visible_to_partner')
                                    : tr('workspace_hidden_from_partner')),
                            style: TextStyle(
                              fontSize: isLandscape ? 11 : 12,
                              color: isPartner
                                  ? Colors.blue
                                  : (account.isShared ? Colors.green : Colors.grey),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMembersTab() {
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final responsive = context.responsive;
    final isLandscape = responsive.isLandscape;

    return ListView(
      padding: EdgeInsets.all(isLandscape ? 12 : 20),
      children: [
        ..._members.map((member) {
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                radius: isLandscape ? 16 : 20,
                child: Text(
                  member.displayName.isNotEmpty ? member.displayName[0] : '?',
                  style: TextStyle(fontSize: isLandscape ? 14 : 18),
                ),
              ),
              title: Text(
                member.nickname ?? member.displayName,
                style: fontProvider.getTextStyle(
                  fontSize: isLandscape ? 14 : 18,
                  fontWeight: member.isCurrentUser
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                member.email,
                style: TextStyle(fontSize: isLandscape ? 11 : 13),
              ),
              trailing: member.isCurrentUser
                  ? null
                  : IconButton(
                      icon: Icon(Icons.edit, size: isLandscape ? 20 : 24),
                      onPressed: () => _editNickname(member),
                    ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildWorkspaceTab() {
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final responsive = context.responsive;
    final isLandscape = responsive.isLandscape;

    return ListView(
      padding: EdgeInsets.all(isLandscape ? 12 : 20),
      children: [
        Card(
          child: ListTile(
            leading: Icon(Icons.edit, size: isLandscape ? 20 : 24),
            title: Text(
              'Rename Workspace',
              style: fontProvider.getTextStyle(fontSize: isLandscape ? 14 : 18),
            ),
            subtitle: Text(
              _workspaceName,
              style: TextStyle(fontSize: isLandscape ? 12 : 14),
            ),
            onTap: () async {
              final ctrl = TextEditingController(text: _workspaceName);
              final newName = await showDialog<String>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("Rename Workspace"),
                  content: TextField(controller: ctrl),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Cancel"),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, ctrl.text),
                      child: const Text("Save"),
                    ),
                  ],
                ),
              );

              if (newName != null && newName.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('workspaces')
                    .doc(widget.workspaceId)
                    .update({'displayName': newName});
                setState(() => _workspaceName = newName);
              }
            },
          ),
        ),
        SizedBox(height: isLandscape ? 12 : 20),
        Card(
          color: Colors.red.shade50,
          child: ListTile(
            leading: Icon(
              Icons.exit_to_app,
              color: Colors.red,
              size: isLandscape ? 20 : 24,
            ),
            title: Text(
              'Leave Workspace',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: isLandscape ? 14 : 16,
              ),
            ),
            onTap: _leaveWorkspace,
          ),
        ),
      ],
    );
  }
}

class WorkspaceMember {
  final String userId;
  final String displayName;
  final String email;
  final String? nickname;
  final bool isCurrentUser;

  WorkspaceMember({
    required this.userId,
    required this.displayName,
    required this.email,
    this.nickname,
    required this.isCurrentUser,
  });
}
