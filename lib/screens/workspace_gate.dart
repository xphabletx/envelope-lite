// lib/screens/workspace_gate.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WorkspaceGate extends StatefulWidget {
  const WorkspaceGate({
    super.key,
    required this.onJoined,
    this.workspaceId, // if provided, show Manage section (rename)
  });

  final ValueChanged<String> onJoined;
  final String? workspaceId;

  @override
  State<WorkspaceGate> createState() => _WorkspaceGateState();
}

class _WorkspaceGateState extends State<WorkspaceGate> {
  final _db = FirebaseFirestore.instance;
  final _joinCtrl = TextEditingController();

  bool _creating = false;
  bool _joining = false;

  // Manage mode fields
  final _displayNameCtrl = TextEditingController();
  String? _joinCodeForManage;
  bool _savingName = false;
  bool _loadedManage = false;

  @override
  void initState() {
    super.initState();
    if (widget.workspaceId != null) {
      _loadManageData(widget.workspaceId!);
    }
  }

  Future<void> _loadManageData(String wsId) async {
    try {
      final snap = await _db.collection('workspaces').doc(wsId).get();
      if (!snap.exists) return;
      final data = snap.data() ?? {};
      _joinCodeForManage = (data['joinCode'] as String?)?.trim();
      _displayNameCtrl.text =
          ((data['displayName'] ?? data['name']) as String? ?? '').trim();
    } catch (_) {
      // swallow; keep UI usable
    } finally {
      if (mounted) setState(() => _loadedManage = true);
    }
  }

  String _randomCode(int n) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(n, (_) => chars[r.nextInt(chars.length)]).join();
  }

  Future<void> _create() async {
    setState(() => _creating = true);
    try {
      // Get current user ID from Firebase Auth
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) {
        throw Exception('No user logged in');
      }

      final ref = _db.collection('workspaces').doc();
      final code = _randomCode(6);

      // Create workspace with the creator as first member
      await ref.set({
        'joinCode': code,
        'displayName': '',
        'name': code,
        'createdAt': FieldValue.serverTimestamp(),
        'members': {
          currentUserId: true, // Add creator to members
        },
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Workspace created. Share this code: $code'),
          duration: const Duration(seconds: 5),
        ),
      );

      widget.onJoined(ref.id);
      if (mounted) Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error creating workspace: $e')));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _join() async {
    final code = _joinCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() => _joining = true);

    try {
      // Get current user ID
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) {
        throw Exception('No user logged in');
      }

      final snap = await _db
          .collection('workspaces')
          .where('joinCode', isEqualTo: code)
          .limit(1)
          .get();

      if (!mounted) return;
      if (snap.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No workspace found for that code')),
        );
        return;
      }

      final doc = snap.docs.first;

      // Add current user to workspace members
      await doc.reference.update({'members.$currentUserId': true});

      widget.onJoined(doc.id);
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error joining workspace: $e')));
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _saveDisplayName() async {
    final wsId = widget.workspaceId;
    if (wsId == null) return;

    final friendly = _displayNameCtrl.text.trim();
    setState(() => _savingName = true);
    try {
      await _db.collection('workspaces').doc(wsId).update({
        'displayName': friendly,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Workspace name updated.')));
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save name: $e')));
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  Future<void> _editNickname(String userId, String currentName) async {
    final nicknameCtrl = TextEditingController();

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final userDoc = await _db.collection('users').doc(currentUserId).get();
      final userData = userDoc.data();
      final nicknames = (userData?['nicknames'] as Map<String, dynamic>?) ?? {};
      nicknameCtrl.text = (nicknames[userId] as String?) ?? '';
    } catch (_) {
      // Ignore, start with empty
    }

    if (!mounted) return;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Set Nickname for $currentName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This nickname is only visible to you.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nicknameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nickname',
                hintText: 'e.g. Girl, Babe, Partner',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, nicknameCtrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null) return;

    try {
      await _db.collection('users').doc(currentUserId).set({
        'nicknames': {userId: result.isEmpty ? FieldValue.delete() : result},
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isEmpty ? 'Nickname cleared' : 'Nickname saved: $result',
          ),
        ),
      );

      // Force rebuild to fetch new nickname immediately
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save nickname: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loadingIndicator = const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
    );

    final inManageMode = widget.workspaceId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          inManageMode ? 'Workspace Settings' : 'Start or Join Workspace',
        ),
        elevation: 0,
        automaticallyImplyLeading: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!inManageMode) ...[
                // --- Create Workspace ---
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _creating || _joining ? null : _create,
                    icon: _creating
                        ? loadingIndicator
                        : const Icon(Icons.add_business),
                    label: Text(
                      _creating ? 'Creating...' : 'Create New Shared Workspace',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30.0),
                  child: Divider(color: Colors.black26),
                ),

                // --- Join Workspace ---
                const Text(
                  'Or join an existing one:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _joinCtrl,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  enabled: !_creating && !_joining,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Enter 6-digit Join Code',
                    hintText: 'e.g. ABC123',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _creating || _joining ? null : _join,
                    icon: _joining ? loadingIndicator : const Icon(Icons.login),
                    label: Text(
                      _joining ? 'Joining...' : 'Join Workspace',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ] else ...[
                // ----------------- Manage current workspace -----------------
                if (!_loadedManage)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Join Code (immutable)',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Chip(label: Text(_joinCodeForManage ?? '—')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _displayNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Display name (optional)',
                      hintText: 'e.g. Team Love',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Shown as "CODE (Display name)". Joining always uses CODE.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _savingName ? null : _saveDisplayName,
                      icon: _savingName
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(_savingName ? 'Saving...' : 'Save'),
                    ),
                  ),

                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),

                  // --- MEMBERS SECTION ---
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Workspace Members',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  StreamBuilder<DocumentSnapshot>(
                    stream: _db
                        .collection('workspaces')
                        .doc(widget.workspaceId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final workspaceData =
                          snapshot.data?.data() as Map<String, dynamic>?;
                      final members =
                          (workspaceData?['members']
                              as Map<String, dynamic>?) ??
                          {};

                      if (members.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No members yet',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        );
                      }

                      return Column(
                        children: members.keys.map((memberId) {
                          return FutureBuilder<DocumentSnapshot>(
                            future: _db.collection('users').doc(memberId).get(),
                            builder: (context, userSnapshot) {
                              final userData =
                                  userSnapshot.data?.data()
                                      as Map<String, dynamic>?;
                              final displayName =
                                  (userData?['displayName'] as String?) ??
                                  (userData?['email'] as String?) ??
                                  'Unknown User';
                              final email =
                                  (userData?['email'] as String?) ?? '';

                              final currentUserId =
                                  FirebaseAuth.instance.currentUser?.uid;
                              final isMe = memberId == currentUserId;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.blue.shade100,
                                    child: Text(
                                      displayName.isNotEmpty
                                          ? displayName[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        color: Colors.blue.shade800,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    displayName,
                                    style: TextStyle(
                                      fontWeight: isMe
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  subtitle: Text(
                                    isMe ? '$email (You)' : email,
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  trailing: isMe
                                      ? null
                                      : IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            size: 20,
                                          ),
                                          onPressed: () => _editNickname(
                                            memberId,
                                            displayName,
                                          ),
                                          tooltip: 'Set nickname',
                                        ),
                                ),
                              );
                            }, // ← This closes FutureBuilder builder
                          ); // ← This closes FutureBuilder
                        }).toList(), // ← This closes map
                      ); // ← This closes Column
                    }, // ← This closes StreamBuilder builder
                  ), // ← This closes StreamBuilder
                ], // ← This closes the "else" block for manage mode
              ], // ← This closes the main children list
            ], // Column
          ), // SingleChildScrollView
        ), // Center
      ), // body
    ); // Scaffold
  } // build
}  // class