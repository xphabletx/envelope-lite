// lib/screens/workspace_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../services/workspace_helper.dart';
import '../services/envelope_repo.dart';
import '../models/envelope.dart';
import '../models/envelope_group.dart';
import '../services/localization_service.dart';
import '../providers/font_provider.dart';

class WorkspaceSettingsScreen extends StatefulWidget {
  const WorkspaceSettingsScreen({
    super.key,
    required this.workspaceId,
    required this.currentUserId,
    required this.repo,
    required this.onWorkspaceLeft,
    this.showJoinCodeInitially = false,
  });

  final String workspaceId;
  final String currentUserId;
  final EnvelopeRepo repo;
  final VoidCallback onWorkspaceLeft;
  final bool showJoinCodeInitially;

  @override
  State<WorkspaceSettingsScreen> createState() =>
      _WorkspaceSettingsScreenState();
}

class _WorkspaceSettingsScreenState extends State<WorkspaceSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  String _workspaceName = '';
  String _joinCode = '';
  List<WorkspaceMember> _members = [];
  int _selectedNavIndex = 2; // Start on settings tab

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
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
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
      // Clear workspace from repo and SharedPreferences
      await widget.repo.setWorkspace(null);
      await WorkspaceHelper.setActiveWorkspaceId(null);

      // Remove from workspace members
      await WorkspaceHelper.leaveWorkspace(
        widget.workspaceId,
        widget.currentUserId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('workspace_left_success'))));
      widget.onWorkspaceLeft();
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${tr('error_generic')}: $e')));
    }
  }

  void _onNavTapped(int index) {
    setState(() => _selectedNavIndex = index);

    if (index == 0) {
      // Envelopes - Navigate to home
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else if (index == 1) {
      // Binders - Navigate to home then to binders screen
      Navigator.of(context).popUntil((route) => route.isFirst);
      // You'll need to trigger binders screen navigation here
      // This depends on your home screen navigation structure
    }
    // index == 2 is Settings - stay on this screen
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('workspace_settings')), elevation: 0),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr('workspace_settings'),
          style: fontProvider.getTextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          tabs: [
            Tab(text: tr('workspace_tab_sharing')),
            Tab(text: tr('workspace_tab_members')),
            Tab(text: tr('workspace_tab_workspace')),
          ],
        ),
      ),
      body: Column(
        children: [
          // JOIN CODE HEADER - Visible on all tabs for quick access
          if (_joinCode.isNotEmpty)
            Container(
              width: double.infinity,
              color: theme.colorScheme.primary.withValues(alpha:0.1),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Join Code: ",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  SelectableText(
                    _joinCode,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
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
      // BOTTOM NAV BAR FIX: Added navigation bar
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedNavIndex,
        onTap: _onNavTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.mail_outline),
            label: 'Envelopes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_outlined),
            label: 'Binders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildSharingTab() {
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          tr('workspace_my_envelopes'),
          style: fontProvider.getTextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<Envelope>>(
          stream: widget.repo.envelopesStream(showPartnerEnvelopes: false),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final myEnvelopes = snapshot.data!;
            if (myEnvelopes.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(child: Text(tr('home_no_envelopes'))),
                ),
              );
            }
            return Card(
              child: Column(
                children: myEnvelopes.map((env) {
                  return CheckboxListTile(
                    value: env.isShared,
                    onChanged: (value) async {
                      await widget.repo.updateEnvelope(
                        envelopeId: env.id,
                        isShared: value ?? true,
                      );
                    },
                    title: Text(
                      env.name,
                      style: fontProvider.getTextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      env.isShared
                          ? tr('workspace_visible_to_partner')
                          : tr('workspace_hidden_from_partner'),
                      style: TextStyle(
                        fontSize: 12,
                        color: env.isShared ? Colors.green : Colors.grey,
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
        const SizedBox(height: 32),
        Text(
          tr('workspace_my_binders'),
          style: fontProvider.getTextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<EnvelopeGroup>>(
          stream: widget.repo.groupsStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final myGroups = snapshot.data!
                .where((g) => g.userId == widget.currentUserId)
                .toList();
            if (myGroups.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(child: Text(tr('group_no_binders'))),
                ),
              );
            }
            return Card(
              child: Column(
                children: myGroups.map((group) {
                  return CheckboxListTile(
                    value: group.isShared,
                    onChanged: (value) async {
                      await FirebaseFirestore.instance
                          .collection('workspaces')
                          .doc(widget.workspaceId)
                          .collection('groups')
                          .doc(group.id)
                          .update({'isShared': value ?? true});
                    },
                    title: Text(
                      group.name,
                      style: fontProvider.getTextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      group.isShared
                          ? tr('workspace_visible_to_partner')
                          : tr('workspace_hidden_from_partner'),
                      style: TextStyle(
                        fontSize: 12,
                        color: group.isShared ? Colors.green : Colors.grey,
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMembersTab() {
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ..._members.map((member) {
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Text(
                  member.displayName.isNotEmpty ? member.displayName[0] : '?',
                ),
              ),
              title: Text(
                member.nickname ?? member.displayName,
                style: fontProvider.getTextStyle(
                  fontSize: 20,
                  fontWeight: member.isCurrentUser
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
              subtitle: Text(member.email),
              trailing: member.isCurrentUser
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _editNickname(member),
                    ),
            ),
          );
        }),
      ],
    );
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

  Widget _buildWorkspaceTab() {
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.edit),
            title: Text(
              'Rename Workspace',
              style: fontProvider.getTextStyle(fontSize: 20),
            ),
            subtitle: Text(_workspaceName),
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
        const SizedBox(height: 20),
        Card(
          color: Colors.red.shade50,
          child: ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.red),
            title: const Text(
              'Leave Workspace',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
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
