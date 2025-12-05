// lib/services/group_repo.dart
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'envelope_repo.dart';

class GroupRepo {
  GroupRepo(this._db, this._envelopeRepo);

  final fs.FirebaseFirestore _db;
  final EnvelopeRepo _envelopeRepo;

  bool get _inWorkspace => _envelopeRepo.inWorkspace;
  String? get _workspaceId => _envelopeRepo.workspaceId;
  String get _userId => _envelopeRepo.currentUserId!;

  fs.CollectionReference<Map<String, dynamic>> groupsCol() {
    if (_inWorkspace && _workspaceId != null) {
      return _db
          .collection('workspaces')
          .doc(_workspaceId)
          .collection('groups');
    } else {
      return _db
          .collection('users')
          .doc(_userId)
          .collection('solo')
          .doc('data')
          .collection('groups');
    }
  }

  Future<String> createGroup({
    required String name,
    String? emoji,
    String? colorName,
    bool? payDayEnabled, // NEW
  }) async {
    final ref = groupsCol().doc();
    await ref.set({
      'id': ref.id,
      'name': name,
      'userId': _userId,
      'emoji': emoji ?? '📁',
      'colorName': colorName ?? 'Primary',
      'payDayEnabled': payDayEnabled ?? false, // NEW
      'createdAt': fs.FieldValue.serverTimestamp(),
      'updatedAt': fs.FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> updateGroup({
    required String groupId,
    String? name,
    String? emoji,
    String? colorName,
    bool? payDayEnabled, // NEW
  }) async {
    final updateData = <String, dynamic>{
      'updatedAt': fs.FieldValue.serverTimestamp(),
    };

    if (name != null) updateData['name'] = name;
    if (emoji != null) updateData['emoji'] = emoji;
    if (colorName != null) updateData['colorName'] = colorName;
    if (payDayEnabled != null)
      updateData['payDayEnabled'] = payDayEnabled; // NEW

    await groupsCol().doc(groupId).update(updateData);
  }

  Future<void> deleteGroup({required String groupId}) async {
    await groupsCol().doc(groupId).delete();
  }
}
