// lib/screens/workspace_settings_screen.dart
// FONT PROVIDER INTEGRATED: All GoogleFonts.caveat() replaced with FontProvider
// All button text wrapped in FittedBox to prevent wrapping

import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // NEW IMPORT
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/workspace_helper.dart';
import '../services/envelope_repo.dart';
import '../models/envelope.dart';
import '../models/envelope_group.dart';
import 'workspace_gate.dart';
import '../services/localization_service.dart';
import '../providers/font_provider.dart'; // NEW IMPORT

class WorkspaceSettingsScreen extends StatefulWidget {
  const WorkspaceSettingsScreen({
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
  State<WorkspaceSettingsScreen> createState() =>
      _WorkspaceSettingsScreenState();
}

class _WorkspaceSettingsScreenState extends State<WorkspaceSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  String _workspaceName = '';
  List<WorkspaceMember> _members = [];

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
    final name = await WorkspaceHelper.getWorkspaceName(widget.workspaceId);
    final members = await _getMembers();

    if (mounted) {
      setState(() {
        _workspaceName = name;
        _members = members;
        _loading = false;
      });
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

        // Get nickname
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
          // UPDATED: FontProvider
          style: fontProvider.getTextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(tr('workspace_leave_warning')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: FittedBox(
              // UPDATED: FittedBox
              fit: BoxFit.scaleDown,
              child: Text(
                tr('cancel'),
                // UPDATED: FontProvider
                style: fontProvider.getTextStyle(),
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: FittedBox(
              // UPDATED: FittedBox
              fit: BoxFit.scaleDown,
              child: Text(
                tr('workspace_leave_button'),
                // UPDATED: FontProvider
                style: fontProvider.getTextStyle(),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
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

  void _openWorkspaceManage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            WorkspaceGate(workspaceId: widget.workspaceId, onJoined: (_) {}),
      ),
    ).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            tr('workspace_settings'),
            // UPDATED: FontProvider
            style: fontProvider.getTextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr('workspace_settings'),
          // UPDATED: FontProvider
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
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSharingTab(),
          _buildMembersTab(),
          _buildWorkspaceTab(),
        ],
      ),
    );
  }

  // TAB 1: Sharing (My Envelopes & Binders)
  Widget _buildSharingTab() {
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          tr('workspace_my_envelopes'),
          // UPDATED: FontProvider
          style: fontProvider.getTextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tr('workspace_sharing_envelopes_subtitle'),
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
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
                    value: env.isShared ?? true,
                    onChanged: (value) async {
                      await widget.repo.updateEnvelope(
                        envelopeId: env.id,
                        isShared: value ?? true,
                      );
                    },
                    title: Row(
                      children: [
                        if (env.emoji != null)
                          Text(
                            env.emoji!,
                            style: const TextStyle(fontSize: 20),
                          ),
                        const SizedBox(width: 8),
                        Text(
                          env.name,
                          // UPDATED: FontProvider
                          style: fontProvider.getTextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      (env.isShared ?? true)
                          ? tr('workspace_visible_to_partner')
                          : tr('workspace_hidden_from_partner'),
                      style: TextStyle(
                        fontSize: 12,
                        color: (env.isShared ?? true)
                            ? Colors.green
                            : Colors.grey,
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
          // UPDATED: FontProvider
          style: fontProvider.getTextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tr('workspace_sharing_binders_subtitle'),
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
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
                    value: group.isShared ?? true,
                    onChanged: (value) async {
                      // TODO: Add updateGroup isShared param
                      await FirebaseFirestore.instance
                          .collection('workspaces')
                          .doc(widget.workspaceId)
                          .collection('groups')
                          .doc(group.id)
                          .update({'isShared': value ?? true});
                    },
                    title: Row(
                      children: [
                        Text(
                          group.emoji ?? '📁',
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          group.name,
                          // UPDATED: FontProvider
                          style: fontProvider.getTextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      (group.isShared ?? true)
                          ? tr('workspace_visible_to_partner')
                          : tr('workspace_hidden_from_partner'),
                      style: TextStyle(
                        fontSize: 12,
                        color: (group.isShared ?? true)
                            ? Colors.green
                            : Colors.grey,
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

  // TAB 2: Members
  Widget _buildMembersTab() {
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ..._members.map((member) {
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: member.isCurrentUser
                    ? Theme.of(context).colorScheme.primary.withAlpha(77)
                    : Theme.of(context).colorScheme.secondary.withAlpha(77),
                child: Text(
                  member.displayName.isNotEmpty
                      ? member.displayName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: member.isCurrentUser
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                member.nickname ?? member.displayName,
                // UPDATED: FontProvider
                style: fontProvider.getTextStyle(
                  fontSize: 20,
                  fontWeight: member.isCurrentUser
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                member.isCurrentUser
                    ? '${member.email} (${tr('workspace_you')})'
                    : member.email,
                style: const TextStyle(fontSize: 12),
              ),
              trailing: member.isCurrentUser
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => _editNickname(member),
                      tooltip: tr('workspace_set_nickname_tooltip'),
                    ),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _editNickname(WorkspaceMember member) async {
    final nicknameCtrl = TextEditingController(text: member.nickname ?? '');
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '${tr('workspace_set_nickname_for')} ${member.displayName}',
          // UPDATED: FontProvider
          style: fontProvider.getTextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('workspace_nickname_privacy_note'),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nicknameCtrl,
              decoration: InputDecoration(
                labelText: tr('workspace_nickname'),
                hintText: tr('workspace_nickname_hint'),
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: FittedBox(
              // UPDATED: FittedBox
              fit: BoxFit.scaleDown,
              child: Text(
                tr('cancel'),
                // UPDATED: FontProvider
                style: fontProvider.getTextStyle(),
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, nicknameCtrl.text.trim()),
            child: FittedBox(
              // UPDATED: FittedBox
              fit: BoxFit.scaleDown,
              child: Text(
                tr('save'),
                // UPDATED: FontProvider
                style: fontProvider.getTextStyle(),
              ),
            ),
          ),
        ],
      ),
    );

    if (result == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .set({
            'nicknames': {
              member.userId: result.isEmpty ? FieldValue.delete() : result,
            },
          }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isEmpty
                ? tr('workspace_nickname_cleared')
                : '${tr('workspace_nickname_saved')}: $result',
          ),
        ),
      );

      _loadData(); // Refresh
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${tr('error_generic')}: $e')));
    }
  }

  // TAB 3: Workspace
  Widget _buildWorkspaceTab() {
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: ListTile(
            leading: Icon(
              Icons.workspaces,
              color: Theme.of(context).colorScheme.primary,
              size: 32,
            ),
            title: Text(
              _workspaceName,
              // UPDATED: FontProvider
              style: fontProvider.getTextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(tr('workspace_name_label')),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _openWorkspaceManage,
              tooltip: tr('workspace_edit_details_tooltip'),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Card(
          child: ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.red),
            title: Text(
              tr('workspace_leave_button'),
              // UPDATED: FontProvider
              style: fontProvider.getTextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            subtitle: Text(tr('workspace_leave_subtitle')),
            onTap: _leaveWorkspace,
          ),
        ),
        const SizedBox(height: 24),
        Card(
          color: Theme.of(context).colorScheme.secondary.withAlpha(26),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.secondary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tr('workspace_about_title'),
                      // UPDATED: FontProvider
                      style: fontProvider.getTextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  tr('workspace_about_content'),
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha(179),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// === MISSING CLASS DEFINITION ADDED BELOW ===

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
