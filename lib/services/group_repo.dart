// lib/services/group_repo.dart
import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/envelope_group.dart';
import 'envelope_repo.dart';
import 'hive_service.dart';
import 'sync_manager.dart';

/// Group repository - Syncs to Firebase for cloud backup
///
/// CRITICAL: Groups MUST sync to prevent data loss on logout/login
/// Syncs to: /users/{userId}/groups (solo mode) or /workspaces/{workspaceId}/groups (workspace mode)
class GroupRepo {
  GroupRepo(this._envelopeRepo) {
    _groupBox = HiveService.getBox<EnvelopeGroup>('groups');
  }

  final EnvelopeRepo _envelopeRepo;
  late final Box<EnvelopeGroup> _groupBox;
  final SyncManager _syncManager = SyncManager();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get _userId => _envelopeRepo.currentUserId;
  bool get _inWorkspace => _envelopeRepo.inWorkspace;
  String? get _workspaceId => _envelopeRepo.workspaceId;

  // ======================= CREATE =======================

  /// Create group
  Future<String> createGroup({
    required String name,
    String? emoji,
    String? iconType,
    String? iconValue,
    int? iconColor,
    int? colorIndex,
    bool? payDayEnabled,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();

    final group = EnvelopeGroup(
      id: id,
      name: name,
      userId: _userId,
      emoji: emoji,
      iconType: iconType ?? 'assetImage',
      iconValue: iconValue ?? 'assets/default/stufficon.png',
      iconColor: iconColor,
      colorIndex: colorIndex ?? 0,
      payDayEnabled: payDayEnabled ?? false,
      isShared: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _groupBox.put(id, group);
    debugPrint('[GroupRepo] ✅ Group created in Hive: $name');

    // CRITICAL: Sync to Firebase to prevent data loss
    if (_inWorkspace && _workspaceId != null) {
      // Workspace mode: sync to workspace collection
      debugPrint('[GroupRepo] DEBUG: Syncing group to workspace: $_workspaceId');
      await _db
          .collection('workspaces')
          .doc(_workspaceId!)
          .collection('groups')
          .doc(id)
          .set(group.toMap());
    } else {
      // Solo mode: sync to user collection
      _syncManager.pushGroup(group, _userId);
    }

    return id;
  }

  // ======================= UPDATE =======================

  /// Update group
  Future<void> updateGroup({
    required String groupId,
    String? name,
    String? emoji,
    String? iconType,
    String? iconValue,
    int? iconColor,
    int? colorIndex,
    bool? payDayEnabled,
  }) async {
    final group = _groupBox.get(groupId);
    if (group == null) {
      throw Exception('Group not found: $groupId');
    }

    final updatedGroup = EnvelopeGroup(
      id: group.id,
      name: name ?? group.name,
      userId: group.userId,
      emoji: emoji ?? group.emoji,
      iconType: iconType ?? group.iconType,
      iconValue: iconValue ?? group.iconValue,
      iconColor: iconColor ?? group.iconColor,
      colorIndex: colorIndex ?? group.colorIndex,
      payDayEnabled: payDayEnabled ?? group.payDayEnabled,
      isShared: group.isShared,
      createdAt: group.createdAt,
      updatedAt: DateTime.now(),
    );

    await _groupBox.put(groupId, updatedGroup);
    debugPrint('[GroupRepo] ✅ Group updated in Hive: $groupId');

    // CRITICAL: Sync to Firebase to prevent data loss
    if (_inWorkspace && _workspaceId != null) {
      // Workspace mode: sync to workspace collection
      debugPrint('[GroupRepo] DEBUG: Syncing updated group to workspace: $_workspaceId');
      await _db
          .collection('workspaces')
          .doc(_workspaceId!)
          .collection('groups')
          .doc(groupId)
          .set(updatedGroup.toMap());
    } else {
      // Solo mode: sync to user collection
      _syncManager.pushGroup(updatedGroup, _userId);
    }
  }

  // ======================= DELETE =======================

  /// Delete group
  Future<void> deleteGroup({required String groupId}) async {
    // Note: Envelope unlinking is handled by EnvelopeRepo
    // Scheduled payments cleanup is handled by ScheduledPaymentRepo

    await _groupBox.delete(groupId);
    debugPrint('[GroupRepo] ✅ Group deleted from Hive: $groupId');

    // CRITICAL: Sync deletion to Firebase to prevent data loss
    if (_inWorkspace && _workspaceId != null) {
      // Workspace mode: delete from workspace collection
      debugPrint('[GroupRepo] DEBUG: Deleting group from workspace: $_workspaceId');
      await _db
          .collection('workspaces')
          .doc(_workspaceId!)
          .collection('groups')
          .doc(groupId)
          .delete();
    } else {
      // Solo mode: delete from user collection
      _syncManager.deleteGroup(groupId, _userId);
    }
  }

  // ======================= GETTERS =======================

  /// Get a single group by ID
  EnvelopeGroup? getGroup(String groupId) {
    return _groupBox.get(groupId);
  }

  /// Get a single group by ID as a Future
  Future<EnvelopeGroup?> getGroupAsync(String groupId) async {
    return _groupBox.get(groupId);
  }

  /// Get all groups (synchronous - for initial data)
  List<EnvelopeGroup> getAllGroups() {
    // In workspace mode, groups are already filtered by the Firebase sync
    // and cached in Hive, so we just return all groups in Hive for this user
    // The workspace filtering happens at the Firebase collection level
    return _groupBox.values
        .where((group) => group.userId == _userId)
        .toList();
  }

  /// Get all groups as a Future
  Future<List<EnvelopeGroup>> getAllGroupsAsync() async {
    return getAllGroups();
  }

  /// Stream of all groups (for reactive UI)
  Stream<List<EnvelopeGroup>> groupsStream() {
    if (_inWorkspace && _workspaceId != null) {
      // WORKSPACE MODE: Stream from Firebase with Hive cache
      return _db
          .collection('workspaces')
          .doc(_workspaceId!)
          .collection('groups')
          .snapshots()
          .asyncMap((snapshot) async {
        final groups = <EnvelopeGroup>[];

        for (final doc in snapshot.docs) {
          try {
            final data = doc.data();
            final group = EnvelopeGroup.fromMap({...data, 'id': doc.id});

            // Cache in Hive
            await _groupBox.put(doc.id, group);
            groups.add(group);
          } catch (e) {
            debugPrint('[GroupRepo] ERROR: Failed to parse group ${doc.id}: $e');
          }
        }

        return groups;
      });
    } else {
      // SOLO MODE: Stream from Hive only
      final initial = getAllGroups();

      return Stream<List<EnvelopeGroup>>.multi((controller) {
        // Emit initial value
        controller.add(initial);

        // Listen to box changes
        final subscription = _groupBox.watch().listen((_) {
          controller.add(getAllGroups());
        });

        controller.onCancel = () {
          subscription.cancel();
        };
      });
    }
  }
}
