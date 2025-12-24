// lib/services/group_repo.dart
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'envelope_repo.dart';

class GroupRepo {
  GroupRepo(this._db, this._envelopeRepo);

  final fs.FirebaseFirestore _db;
  final EnvelopeRepo _envelopeRepo;

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
    final ref = groupsCol().doc();
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
      'isShared': _inWorkspace, // Share by default in workspace mode
      'createdAt': fs.FieldValue.serverTimestamp(),
      'updatedAt': fs.FieldValue.serverTimestamp(),
    });
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
  }

  Future<void> deleteGroup({required String groupId}) async {
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
  }
}
