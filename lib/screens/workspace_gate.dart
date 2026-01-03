// lib/screens/workspace_gate.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';
import '../models/envelope.dart';
import '../models/envelope_group.dart';
import '../models/account.dart';
import '../services/localization_service.dart';
import '../services/envelope_repo.dart';
import '../providers/font_provider.dart';
import '../providers/workspace_provider.dart';
import 'workspace_management_screen.dart';
import '../utils/responsive_helper.dart';

class WorkspaceGate extends StatefulWidget {
  const WorkspaceGate({
    super.key,
    required this.onJoined,
    this.workspaceId,
    this.repo,
  });

  final ValueChanged<String> onJoined;
  final String? workspaceId;
  final EnvelopeRepo? repo;

  @override
  State<WorkspaceGate> createState() => _WorkspaceGateState();
}

class _WorkspaceGateState extends State<WorkspaceGate> {
  final _joinCtrl = TextEditingController();

  // New Flow Logic
  void _initiateCreate() {
    // print('[WorkspaceGate] DEBUG: Initiating Create Workspace flow.');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkspaceSharingSelectionScreen(
          mode: WorkspaceSharingMode.create,
          repo: widget.repo,
          onComplete: (workspaceId) async {
            // CRITICAL FIX: Update global WorkspaceProvider to trigger rebuild
            final workspaceProvider = Provider.of<WorkspaceProvider>(context, listen: false);
            await workspaceProvider.setWorkspaceId(workspaceId);

            widget.onJoined(workspaceId);
            if (mounted) {
              // Navigate to workspace management screen
              _navigateToManagementScreen(workspaceId);
            }
          },
        ),
      ),
    );
  }

  void _initiateJoin() {
    final code = _joinCtrl.text.trim().toUpperCase();
    // print('[WorkspaceGate] DEBUG: Initiating Join Workspace flow with code: $code');
    if (code.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkspaceSharingSelectionScreen(
          mode: WorkspaceSharingMode.join,
          joinCode: code,
          repo: widget.repo,
          onComplete: (workspaceId) async {
            // CRITICAL FIX: Update global WorkspaceProvider to trigger rebuild
            final workspaceProvider = Provider.of<WorkspaceProvider>(context, listen: false);
            await workspaceProvider.setWorkspaceId(workspaceId);

            widget.onJoined(workspaceId);
            if (mounted) {
              // Navigate to workspace management screen
              _navigateToManagementScreen(workspaceId);
            }
          },
        ),
      ),
    );
  }

  void _navigateToManagementScreen(String workspaceId) {
    // print('[WorkspaceGate] DEBUG: Navigating to WorkspaceManagementScreen with workspaceId: $workspaceId');
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final repo = widget.repo ??
        EnvelopeRepo.firebase(
          FirebaseFirestore.instance,
          userId: currentUserId,
          workspaceId: workspaceId,
        );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => WorkspaceManagementScreen(
          workspaceId: workspaceId,
          currentUserId: currentUserId,
          repo: repo,
          onWorkspaceLeft: () {
            // After leaving workspace, go back to home
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final isLandscape = responsive.isLandscape;
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    if (widget.workspaceId != null) {
      return const Center(child: Text("Manage Mode Placeholder"));
    }

    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          child: Text(
            tr('workspace_start_or_join'),
            style: fontProvider.getTextStyle(
              fontSize: isLandscape ? 20 : 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isLandscape ? 16 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _initiateCreate,
                  icon: Icon(Icons.add_business, size: isLandscape ? 20 : 24),
                  label: Text(
                    tr('workspace_create_new'),
                    style: fontProvider.getTextStyle(
                      fontSize: isLandscape ? 14 : 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      vertical: isLandscape ? 12 : 16,
                      horizontal: isLandscape ? 16 : 20,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: isLandscape ? 20 : 30),
                child: const Divider(color: Colors.black26),
              ),
              Text(
                tr('workspace_join_existing'),
                style: fontProvider.getTextStyle(
                  fontSize: isLandscape ? 14 : 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: isLandscape ? 12 : 16),
              TextField(
                controller: _joinCtrl,
                textAlign: TextAlign.center,
                maxLength: 6,
                textCapitalization: TextCapitalization.characters,
                style: fontProvider.getTextStyle(
                  fontSize: isLandscape ? 16 : 20,
                  fontWeight: FontWeight.bold,
                ),
                inputFormatters: [
                  // UPPERCASE FIX: Force all input to uppercase
                  UpperCaseTextFormatter(),
                ],
                decoration: InputDecoration(
                  labelText: tr('workspace_enter_code'),
                  labelStyle: TextStyle(fontSize: isLandscape ? 12 : 14),
                  hintText: 'ABC123',
                  counterText: '',
                ),
                onTap: () => _joinCtrl.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _joinCtrl.text.length,
                ),
              ),
              SizedBox(height: isLandscape ? 12 : 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _initiateJoin,
                  icon: Icon(Icons.login, size: isLandscape ? 20 : 24),
                  label: Text(
                    tr('workspace_join_button'),
                    style: fontProvider.getTextStyle(
                      fontSize: isLandscape ? 14 : 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      vertical: isLandscape ? 12 : 16,
                      horizontal: isLandscape ? 16 : 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// UPPERCASE FIX: Text formatter to force uppercase
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

// --- SHARING SELECTION SCREEN ---

enum WorkspaceSharingMode { create, join }

class WorkspaceSharingSelectionScreen extends StatefulWidget {
  final WorkspaceSharingMode mode;
  final String? joinCode;
  final EnvelopeRepo? repo;
  final Function(String workspaceId) onComplete;

  const WorkspaceSharingSelectionScreen({
    super.key,
    required this.mode,
    this.joinCode,
    this.repo,
    required this.onComplete,
  });

  @override
  State<WorkspaceSharingSelectionScreen> createState() =>
      _WorkspaceSharingSelectionScreenState();
}

class _WorkspaceSharingSelectionScreenState
    extends State<WorkspaceSharingSelectionScreen> {
  final _db = FirebaseFirestore.instance;
  bool _loading = true;
  bool _processing = false;

  // Set of IDs to HIDE. If ID is here, isShared = false.
  final Set<String> _hiddenEnvelopeIds = {};
  final Set<String> _hiddenGroupIds = {};
  final Set<String> _hiddenAccountIds = {};
  bool _hideFutureEnvelopes = false; // New Checkbox

  List<dynamic> _myEnvelopes = [];
  List<dynamic> _myGroups = [];
  List<dynamic> _myAccounts = [];

  @override
  void initState() {
    super.initState();
    _fetchMyData();
  }

  Future<void> _fetchMyData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      // FETCH FROM HIVE (PRIMARY STORAGE)
      final envelopeBox = Hive.box<Envelope>('envelopes');
      final groupBox = Hive.box<EnvelopeGroup>('groups');
      final accountBox = Hive.box<Account>('accounts');

      final myEnvelopes = envelopeBox.values
          .where((e) => e.userId == uid)
          .toList();

      final myGroups = groupBox.values
          .where((g) => g.userId == uid)
          .toList();

      final myAccounts = accountBox.values
          .where((a) => a.userId == uid)
          .toList();

      if (mounted) {
        setState(() {
          _myEnvelopes = myEnvelopes;
          _myGroups = myGroups;
          _myAccounts = myAccounts;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching data from Hive: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  String _randomCode(int n) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(n, (_) => chars[r.nextInt(chars.length)]).join();
  }

  Future<void> _finish() async {
    // print('[WorkspaceSharingSelectionScreen] DEBUG: _finish called.');
    setState(() => _processing = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
    // print('[WorkspaceSharingSelectionScreen] DEBUG: User is not authenticated.');
      return;
    }

    try {
      String workspaceId = '';

      // 1. Create or Join Workspace
    // print('[WorkspaceSharingSelectionScreen] DEBUG: Step 1 - Create or Join Workspace.');
      if (widget.mode == WorkspaceSharingMode.create) {
        final code = _randomCode(6);
        final ref = _db.collection('workspaces').doc();
        await ref.set({
          'joinCode': code,
          'displayName': 'My Workspace',
          'name': code,
          'createdAt': FieldValue.serverTimestamp(),
          'members': {uid: true},
        });
        workspaceId = ref.id;
    // print('[WorkspaceSharingSelectionScreen] DEBUG: Created workspace with id: $workspaceId');
      } else {
        final snap = await _db
            .collection('workspaces')
            .where('joinCode', isEqualTo: widget.joinCode)
            .limit(1)
            .get();
        if (snap.docs.isEmpty) throw Exception(tr('error_workspace_not_found'));
        final doc = snap.docs.first;
        await doc.reference.update({'members.$uid': true});
        workspaceId = doc.id;
    // print('[WorkspaceSharingSelectionScreen] DEBUG: Joined workspace with id: $workspaceId');
      }

      // 2. Update Sharing Preferences in Hive
    // print('[WorkspaceSharingSelectionScreen] DEBUG: Step 2 - Update Sharing Preferences in Hive.');
      final envelopeBox = Hive.box<Envelope>('envelopes');
      final groupBox = Hive.box<EnvelopeGroup>('groups');
      final accountBox = Hive.box<Account>('accounts');

      for (var envelope in _myEnvelopes) {
        final hide = _hiddenEnvelopeIds.contains(envelope.id);
        envelope.isShared = !hide;
        await envelopeBox.put(envelope.id, envelope);
      }
      for (var group in _myGroups) {
        final hide = _hiddenGroupIds.contains(group.id);
        group.isShared = !hide;
        await groupBox.put(group.id, group);
      }
      for (var account in _myAccounts) {
        final hide = _hiddenAccountIds.contains(account.id);
        account.isShared = !hide;
        await accountBox.put(account.id, account);
      }

      // 3. Save "Hide Future" Preference to Firebase (user profile)
    // print('[WorkspaceSharingSelectionScreen] DEBUG: Step 3 - Save "Hide Future" Preference.');
      await _db.collection('users').doc(uid).set({
        'workspacePreferences': {'hideFutureEnvelopes': _hideFutureEnvelopes},
      }, SetOptions(merge: true));
    // print('[WorkspaceSharingSelectionScreen] DEBUG: Preferences saved successfully.');

      if (mounted) {
    // print('[WorkspaceSharingSelectionScreen] DEBUG: Calling onComplete with workspaceId: $workspaceId');
        widget.onComplete(workspaceId);
      }
    } catch (e) {
    // print('[WorkspaceSharingSelectionScreen] DEBUG: Error in _finish: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _processing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final responsive = context.responsive;
    final isLandscape = responsive.isLandscape;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          child: Text(
            tr('workspace_sharing_setup'),
            style: fontProvider.getTextStyle(
              fontSize: isLandscape ? 20 : 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(isLandscape ? 12 : 16),
            child: Text(
              tr('workspace_select_to_hide'),
              style: fontProvider.getTextStyle(
                fontSize: isLandscape ? 14 : 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // HIDE FUTURE TOGGLE
          SwitchListTile(
            title: Text(
              tr('workspace_hide_future'),
              style: fontProvider.getTextStyle(fontSize: isLandscape ? 14 : 16),
            ),
            value: _hideFutureEnvelopes,
            onChanged: (val) => setState(() => _hideFutureEnvelopes = val),
            activeTrackColor: theme.colorScheme.primary,
          ),
          const Divider(),

          Expanded(
            child: (_myEnvelopes.isEmpty && _myGroups.isEmpty && _myAccounts.isEmpty)
                ? Center(
                    child: Text(
                      "No items to share",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: isLandscape ? 12 : 14,
                      ),
                    ),
                  )
                : ListView(
                    children: [
                      if (_myGroups.isNotEmpty) ...[
                        Padding(
                          padding: EdgeInsets.all(isLandscape ? 12 : 16),
                          child: Text(
                            tr('binders'),
                            style: fontProvider.getTextStyle(
                              fontSize: isLandscape ? 14 : 16,
                              color: theme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ..._myGroups.map((group) {
                          final isHidden = _hiddenGroupIds.contains(group.id);
                          return CheckboxListTile(
                            value: isHidden,
                            title: Text(
                              group.name ?? 'Unnamed',
                              style: fontProvider.getTextStyle(
                                fontSize: isLandscape ? 14 : 16,
                              ),
                            ),
                            secondary: Text(
                              group.emoji ?? '📁',
                              style: TextStyle(fontSize: isLandscape ? 16 : 20),
                            ),
                            subtitle: Text(
                              isHidden ? "Private" : "Shared",
                              style: TextStyle(
                                fontSize: isLandscape ? 11 : 12,
                                color: isHidden ? Colors.red : Colors.green,
                              ),
                            ),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _hiddenGroupIds.add(group.id);
                                } else {
                                  _hiddenGroupIds.remove(group.id);
                                }
                              });
                            },
                          );
                        }),
                      ],
                      if (_myEnvelopes.isNotEmpty) ...[
                        Padding(
                          padding: EdgeInsets.all(isLandscape ? 12 : 16),
                          child: Text(
                            tr('envelopes'),
                            style: fontProvider.getTextStyle(
                              fontSize: isLandscape ? 14 : 16,
                              color: theme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ..._myEnvelopes.map((envelope) {
                          final isHidden = _hiddenEnvelopeIds.contains(envelope.id);
                          return CheckboxListTile(
                            value: isHidden,
                            title: Text(
                              envelope.name ?? 'Unnamed',
                              style: fontProvider.getTextStyle(
                                fontSize: isLandscape ? 14 : 16,
                              ),
                            ),
                            secondary: Icon(
                              Icons.mail_outline,
                              size: isLandscape ? 20 : 24,
                            ),
                            subtitle: Text(
                              isHidden ? "Private" : "Shared",
                              style: TextStyle(
                                fontSize: isLandscape ? 11 : 12,
                                color: isHidden ? Colors.red : Colors.green,
                              ),
                            ),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _hiddenEnvelopeIds.add(envelope.id);
                                } else {
                                  _hiddenEnvelopeIds.remove(envelope.id);
                                }
                              });
                            },
                          );
                        }),
                      ],
                      if (_myAccounts.isNotEmpty) ...[
                        Padding(
                          padding: EdgeInsets.all(isLandscape ? 12 : 16),
                          child: Text(
                            'Accounts',
                            style: fontProvider.getTextStyle(
                              fontSize: isLandscape ? 14 : 16,
                              color: theme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ..._myAccounts.map((account) {
                          final isHidden = _hiddenAccountIds.contains(account.id);
                          return CheckboxListTile(
                            value: isHidden,
                            title: Text(
                              account.name ?? 'Unnamed Account',
                              style: fontProvider.getTextStyle(
                                fontSize: isLandscape ? 14 : 16,
                              ),
                            ),
                            secondary: Icon(
                              Icons.account_balance_wallet,
                              size: isLandscape ? 20 : 24,
                            ),
                            subtitle: Text(
                              isHidden ? "Private" : "Shared",
                              style: TextStyle(
                                fontSize: isLandscape ? 11 : 12,
                                color: isHidden ? Colors.red : Colors.green,
                              ),
                            ),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _hiddenAccountIds.add(account.id);
                                } else {
                                  _hiddenAccountIds.remove(account.id);
                                }
                              });
                            },
                          );
                        }),
                      ],
                    ],
                  ),
          ),
          Padding(
            padding: EdgeInsets.all(isLandscape ? 16 : 24),
            child: SizedBox(
              width: double.infinity,
              height: isLandscape ? 44 : 50,
              child: ElevatedButton(
                onPressed: _processing ? null : _finish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: _processing
                    ? SizedBox(
                        width: isLandscape ? 16 : 20,
                        height: isLandscape ? 16 : 20,
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        widget.mode == WorkspaceSharingMode.create
                            ? tr('workspace_create_confirm')
                            : tr('workspace_join_confirm'),
                        style: fontProvider.getTextStyle(
                          fontSize: isLandscape ? 14 : 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
