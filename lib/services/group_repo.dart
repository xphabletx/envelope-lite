// lib/services/group_repo.dart
import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';
import '../models/envelope_group.dart';
import 'envelope_repo.dart';
import 'hive_service.dart';

/// Group repository - PURE HIVE (No Firebase sync)
///
/// Groups are ALWAYS local-only, even in workspace mode.
/// They are never synced to Firebase or shared with workspace partners.
class GroupRepo {
  GroupRepo(this._envelopeRepo) {
    _groupBox = HiveService.getBox<EnvelopeGroup>('groups');
  }

  final EnvelopeRepo _envelopeRepo;
  late final Box<EnvelopeGroup> _groupBox;

  String get _userId => _envelopeRepo.currentUserId;

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
      emoji: emoji ?? '📁',
      iconType: iconType,
      iconValue: iconValue,
      iconColor: iconColor,
      colorIndex: colorIndex ?? 0,
      payDayEnabled: payDayEnabled ?? false,
      isShared: false,
    );

    await _groupBox.put(id, group);
    debugPrint('[GroupRepo] ✅ Group created in Hive: $name');

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
    );

    await _groupBox.put(groupId, updatedGroup);
    debugPrint('[GroupRepo] ✅ Group updated in Hive: $groupId');
  }

  // ======================= DELETE =======================

  /// Delete group
  Future<void> deleteGroup({required String groupId}) async {
    // Note: Envelope unlinking is handled by EnvelopeRepo
    // Scheduled payments cleanup is handled by ScheduledPaymentRepo

    await _groupBox.delete(groupId);
    debugPrint('[GroupRepo] ✅ Group deleted from Hive: $groupId');
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

  /// Get all groups
  List<EnvelopeGroup> getAllGroups() {
    return _groupBox.values
        .where((group) => group.userId == _userId)
        .toList();
  }

  /// Get all groups as a Future
  Future<List<EnvelopeGroup>> getAllGroupsAsync() async {
    return _groupBox.values
        .where((group) => group.userId == _userId)
        .toList();
  }
}
