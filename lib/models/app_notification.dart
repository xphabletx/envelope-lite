// lib/models/app_notification.dart
import 'package:hive/hive.dart';

part 'app_notification.g.dart';

@HiveType(typeId: 105)
enum NotificationType {
  @HiveField(0)
  scheduledPaymentFailed,

  @HiveField(1)
  scheduledPaymentProcessed,

  @HiveField(2)
  workspaceMemberJoined,

  @HiveField(3)
  workspaceMemberLeft,
}

@HiveType(typeId: 6)
class AppNotification {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String userId;

  @HiveField(2)
  final NotificationType type;

  @HiveField(3)
  final String title;

  @HiveField(4)
  final String message;

  @HiveField(5)
  final DateTime timestamp;

  @HiveField(6)
  final bool isRead;

  @HiveField(7)
  final Map<String, dynamic>? metadata;

  AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.metadata,
  });

  AppNotification copyWith({
    String? id,
    String? userId,
    NotificationType? type,
    String? title,
    String? message,
    DateTime? timestamp,
    bool? isRead,
    Map<String, dynamic>? metadata,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      metadata: metadata ?? this.metadata,
    );
  }
}
