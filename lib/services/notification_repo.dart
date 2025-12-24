// lib/services/notification_repo.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_notification.dart';

class NotificationRepo {
  NotificationRepo(this._db, this._userId);

  final FirebaseFirestore _db;
  final String _userId;

  CollectionReference<Map<String, dynamic>> _collection() {
    return _db
        .collection('users')
        .doc(_userId)
        .collection('notifications');
  }

  // Stream of notifications (newest first)
  Stream<List<AppNotification>> get notificationsStream {
    return _collection()
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AppNotification.fromFirestore(doc))
              .toList(),
        );
  }

  // Stream of unread count
  Stream<int> get unreadCountStream {
    return _collection()
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Create notification
  Future<String> createNotification({
    required NotificationType type,
    required String title,
    required String message,
    Map<String, dynamic>? metadata,
  }) async {
    final doc = _collection().doc();

    final notification = AppNotification(
      id: doc.id,
      userId: _userId,
      type: type,
      title: title,
      message: message,
      timestamp: DateTime.now(),
      metadata: metadata,
    );

    await doc.set(notification.toFirestore());
    return doc.id;
  }

  // Mark as read
  Future<void> markAsRead(String notificationId) async {
    await _collection().doc(notificationId).update({'isRead': true});
  }

  // Mark all as read
  Future<void> markAllAsRead() async {
    final unreadDocs = await _collection()
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _db.batch();
    for (final doc in unreadDocs.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    await _collection().doc(notificationId).delete();
  }

  // Delete all read notifications
  Future<void> deleteAllRead() async {
    final readDocs = await _collection()
        .where('isRead', isEqualTo: true)
        .get();

    final batch = _db.batch();
    for (final doc in readDocs.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
