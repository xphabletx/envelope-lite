// lib/services/notification_repo.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/app_notification.dart';

class NotificationRepo {
  NotificationRepo({required String userId}) : _userId = userId;

  final String _userId;
  bool _disposed = false;
  Box<AppNotification> get _notificationBox => Hive.box<AppNotification>('notifications');

  /// Dispose the repository
  ///
  /// Since NotificationRepo is always local-only (no Firestore streams),
  /// this is a no-op but included for consistency
  void dispose() {
    if (_disposed) {
      debugPrint('[NotificationRepo] ⚠️ Already disposed, skipping');
      return;
    }

    debugPrint('[NotificationRepo] 🔄 Disposing (local-only repo, no active streams)');
    _disposed = true;
    debugPrint('[NotificationRepo] ✅ Disposed');
  }

  // Stream of notifications (newest first)
  Stream<List<AppNotification>> get notificationsStream {
    // GUARD: Return empty stream if user is not authenticated (during logout)
    if (FirebaseAuth.instance.currentUser == null) {
      debugPrint('[NotificationRepo] ⚠️ No authenticated user - returning empty stream');
      return Stream.value([]);
    }

    final initial = _notificationBox.values
        .where((n) => n.userId == _userId)
        .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Stream.value(initial).asyncExpand((initialList) async* {
      yield initialList;
      yield* _notificationBox.watch().asyncMap((_) async {
        return _notificationBox.values
            .where((n) => n.userId == _userId)
            .toList()
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      });
    });
  }

  // Stream of unread count
  Stream<int> get unreadCountStream {
    return notificationsStream.map((notifications) {
      return notifications.where((n) => !n.isRead).length;
    });
  }

  // Create notification
  Future<String> createNotification({
    required NotificationType type,
    required String title,
    required String message,
    Map<String, dynamic>? metadata,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();

    final notification = AppNotification(
      id: id,
      userId: _userId,
      type: type,
      title: title,
      message: message,
      timestamp: DateTime.now(),
      metadata: metadata,
    );

    await _notificationBox.put(id, notification);
    debugPrint('[NotificationRepo] ✅ Created notification: $title');
    return id;
  }

  // Mark as read
  Future<void> markAsRead(String notificationId) async {
    final notification = _notificationBox.get(notificationId);
    if (notification != null) {
      await _notificationBox.put(
        notificationId,
        notification.copyWith(isRead: true),
      );
      debugPrint('[NotificationRepo] ✅ Marked as read: $notificationId');
    }
  }

  // Mark all as read
  Future<void> markAllAsRead() async {
    final unread = _notificationBox.values
        .where((n) => n.userId == _userId && !n.isRead)
        .toList();

    for (final notification in unread) {
      await _notificationBox.put(
        notification.id,
        notification.copyWith(isRead: true),
      );
    }
    debugPrint('[NotificationRepo] ✅ Marked ${unread.length} notifications as read');
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    await _notificationBox.delete(notificationId);
    debugPrint('[NotificationRepo] ✅ Deleted notification: $notificationId');
  }

  // Delete all read notifications
  Future<void> deleteAllRead() async {
    final read = _notificationBox.values
        .where((n) => n.userId == _userId && n.isRead)
        .map((n) => n.id)
        .toList();

    for (final id in read) {
      await _notificationBox.delete(id);
    }
    debugPrint('[NotificationRepo] ✅ Deleted ${read.length} read notifications');
  }
}
