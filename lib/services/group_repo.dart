// lib/services/group_repo.dart
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/envelope_group.dart';
import 'envelope_repo.dart';
import 'hive_service.dart';

class GroupRepo {
  GroupRepo(this._db, this._envelopeRepo) {
    // Initialize Hive box
    _groupBox = HiveService.getBox<EnvelopeGroup>('groups');
  }

  final fs.FirebaseFirestore _db;
  final EnvelopeRepo _envelopeRepo;
  late final Box<EnvelopeGroup> _groupBox;

  bool get _inWorkspace => _envelopeRepo.inWorkspace;
  String get _userId => _envelopeRepo.currentUserId;

  fs.CollectionReference<Map<String, dynamic>> groupsCol() {
    // Always use the user's solo collection for groups
    // In workspace mode, groups are shared via isShared field
    return _db
        .collection('users')
        .doc(_userId)
        .collection('solo')
        .doc('data')
        .collection('groups');
  }

  Future<String> createGroup({
    required String name,
    String? emoji,
    String? iconType,
    String? iconValue,
    int? iconColor,
    int? colorIndex,
    bool? payDayEnabled,
  }) async {
    // DEBUG: Check workspace status
    final prefs = await SharedPreferences.getInstance();
    final workspaceId = prefs.getString('active_workspace_id');

    debugPrint('[GroupRepo] DEBUG CREATE:');
    debugPrint('  - Group name: $name');
    debugPrint('  - WorkspaceId from prefs: ${workspaceId ?? "NULL"}');
    debugPrint('  - _inWorkspace flag: $_inWorkspace');

    final ref = groupsCol().doc();

    // Create EnvelopeGroup object
    final group = EnvelopeGroup(
      id: ref.id,
      name: name,
      userId: _userId,
      emoji: emoji ?? '📁',
      iconType: iconType,
      iconValue: iconValue,
      iconColor: iconColor,
      colorIndex: colorIndex ?? 0,
      payDayEnabled: payDayEnabled ?? false,
      isShared: _inWorkspace,
    );

    // ALWAYS write to Hive
    await _groupBox.put(ref.id, group);
    debugPrint('[GroupRepo] ✅ Group saved to Hive: ${ref.id}');

    // ONLY write to Firebase if in workspace mode
    if (_inWorkspace && workspaceId != null) {
      debugPrint('[GroupRepo] 🔥 Syncing to Firebase workspace: $workspaceId');
      await ref.set({
        'id': ref.id,
        'name': name,
        'userId': _userId,
        'emoji': emoji ?? '📁',
        'iconType': iconType,
        'iconValue': iconValue,
        'iconColor': iconColor,
        'colorIndex': colorIndex ?? 0,
        'payDayEnabled': payDayEnabled ?? false,
        'isShared': _inWorkspace,
        'createdAt': fs.FieldValue.serverTimestamp(),
        'updatedAt': fs.FieldValue.serverTimestamp(),
      });
      debugPrint('[GroupRepo] ✅ Group synced to Firebase workspace');
    } else {
      debugPrint('[GroupRepo] ⏭️ Skipping Firebase (solo mode)');
    }

    return ref.id;
  }

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
    // DEBUG: Check workspace status
    final prefs = await SharedPreferences.getInstance();
    final workspaceId = prefs.getString('active_workspace_id');
    final envelopeRepoWorkspaceId = _envelopeRepo.workspaceId;

    debugPrint('[GroupRepo] DEBUG UPDATE:');
    debugPrint('  - Group ID: $groupId');
    debugPrint('  - WorkspaceId from prefs: ${workspaceId ?? "NULL"}');
    debugPrint('  - WorkspaceId from EnvelopeRepo: ${envelopeRepoWorkspaceId ?? "NULL"}');
    debugPrint('  - _inWorkspace flag: $_inWorkspace');

    // Get current group from Hive
    final group = _groupBox.get(groupId);
    if (group == null) {
      debugPrint('[GroupRepo] ❌ Group not found in Hive: $groupId');
      throw Exception('Group not found: $groupId');
    }

    // Create updated group
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
    );

    // ALWAYS write to Hive
    await _groupBox.put(groupId, updatedGroup);
    debugPrint('[GroupRepo] ✅ Group updated in Hive: $groupId');

    // Check Firebase sync
    if (_inWorkspace && workspaceId != null) {
      debugPrint('[GroupRepo] 🔥 Syncing to Firebase workspace: $workspaceId');
      try {
        final updateData = <String, dynamic>{
          'updatedAt': fs.FieldValue.serverTimestamp(),
        };

        if (name != null) updateData['name'] = name;
        if (emoji != null) updateData['emoji'] = emoji;
        if (iconType != null) updateData['iconType'] = iconType;
        if (iconValue != null) updateData['iconValue'] = iconValue;
        if (iconColor != null) updateData['iconColor'] = iconColor;
        if (colorIndex != null) updateData['colorIndex'] = colorIndex;
        if (payDayEnabled != null) {
          updateData['payDayEnabled'] = payDayEnabled;
        }

        await groupsCol().doc(groupId).update(updateData);
        debugPrint('[GroupRepo] ✅ Firebase sync successful');
      } catch (e) {
        debugPrint('[GroupRepo] ❌ Firebase sync failed: $e');
      }
    } else if (_inWorkspace && workspaceId == null) {
      debugPrint('[GroupRepo] ⚠️ _inWorkspace is TRUE but workspaceId is NULL!');
      debugPrint('[GroupRepo] ⚠️ This is a bug - EnvelopeRepo workspace status is stale');
    } else {
      debugPrint('[GroupRepo] ⏭️ Skipping Firebase (solo mode)');
    }
  }

  Future<void> deleteGroup({required String groupId}) async {
    // DEBUG: Check workspace status
    final prefs = await SharedPreferences.getInstance();
    final workspaceId = prefs.getString('active_workspace_id');

    debugPrint('[GroupRepo] DEBUG DELETE:');
    debugPrint('  - Group ID: $groupId');
    debugPrint('  - WorkspaceId from prefs: ${workspaceId ?? "NULL"}');
    debugPrint('  - _inWorkspace flag: $_inWorkspace');

    // Delete from Hive
    await _groupBox.delete(groupId);
    debugPrint('[GroupRepo] ✅ Group deleted from Hive: $groupId');

    // If in workspace mode, also delete from Firebase
    if (_inWorkspace && workspaceId != null) {
      debugPrint('[GroupRepo] 🔥 Deleting from Firebase workspace: $workspaceId');
      try {
        final batch = _db.batch();

        // 1. Delete all scheduled payments for this group
        final paymentSnapshot = await _db
            .collection('users')
            .doc(_userId)
            .collection('solo')
            .doc('data')
            .collection('scheduledPayments')
            .where('groupId', isEqualTo: groupId)
            .get();

        for (final doc in paymentSnapshot.docs) {
          batch.delete(doc.reference);
        }

        // 2. Unlink all envelopes from this group (set groupId to null)
        final envelopeSnapshot = await _db
            .collection('users')
            .doc(_userId)
            .collection('solo')
            .doc('data')
            .collection('envelopes')
            .where('groupId', isEqualTo: groupId)
            .get();

        for (final doc in envelopeSnapshot.docs) {
          batch.update(doc.reference, {
            'groupId': null,
            'updatedAt': fs.FieldValue.serverTimestamp(),
          });
        }

        // 3. Delete the group document
        batch.delete(groupsCol().doc(groupId));

        await batch.commit();
        debugPrint('[GroupRepo] ✅ Group deleted from Firebase workspace');
      } catch (e) {
        debugPrint('[GroupRepo] ❌ Firebase delete failed: $e');
      }
    } else {
      debugPrint('[GroupRepo] ⏭️ Skipping Firebase (solo mode)');
    }
  }
}
