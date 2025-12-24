// lib/screens/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/app_notification.dart';
import '../services/notification_repo.dart';
import '../providers/font_provider.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({
    super.key,
    required this.notificationRepo,
  });

  final NotificationRepo notificationRepo;

  IconData _getIconForType(NotificationType type) {
    switch (type) {
      case NotificationType.scheduledPaymentFailed:
        return Icons.error_outline;
      case NotificationType.scheduledPaymentProcessed:
        return Icons.check_circle_outline;
      case NotificationType.workspaceMemberJoined:
        return Icons.person_add_outlined;
      case NotificationType.workspaceMemberLeft:
        return Icons.person_remove_outlined;
    }
  }

  Color _getColorForType(NotificationType type, ColorScheme colorScheme) {
    switch (type) {
      case NotificationType.scheduledPaymentFailed:
        return Colors.red;
      case NotificationType.scheduledPaymentProcessed:
        return Colors.green;
      case NotificationType.workspaceMemberJoined:
        return colorScheme.primary;
      case NotificationType.workspaceMemberLeft:
        return Colors.orange;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat('MMM d, y').format(timestamp);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          'Notifications',
          style: fontProvider.getTextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: theme.colorScheme.primary,
            ),
            onSelected: (value) async {
              if (value == 'mark_all_read') {
                await notificationRepo.markAllAsRead();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All notifications marked as read'),
                    ),
                  );
                }
              } else if (value == 'clear_read') {
                await notificationRepo.deleteAllRead();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Read notifications cleared'),
                    ),
                  );
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'mark_all_read',
                child: Row(
                  children: [
                    Icon(Icons.done_all),
                    SizedBox(width: 12),
                    Text('Mark all as read'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_read',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep),
                    SizedBox(width: 12),
                    Text('Clear read notifications'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: notificationRepo.notificationsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading notifications',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            );
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications',
                    style: fontProvider.getTextStyle(
                      fontSize: 24,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            );
          }

          // Group notifications by read/unread
          final unreadNotifications =
              notifications.where((n) => !n.isRead).toList();
          final readNotifications =
              notifications.where((n) => n.isRead).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Unread notifications
              if (unreadNotifications.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Unread',
                    style: fontProvider.getTextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                ...unreadNotifications.map(
                  (notification) => _NotificationTile(
                    notification: notification,
                    notificationRepo: notificationRepo,
                    getIconForType: _getIconForType,
                    getColorForType: _getColorForType,
                    formatTimestamp: _formatTimestamp,
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Read notifications
              if (readNotifications.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Read',
                    style: fontProvider.getTextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
                ...readNotifications.map(
                  (notification) => _NotificationTile(
                    notification: notification,
                    notificationRepo: notificationRepo,
                    getIconForType: _getIconForType,
                    getColorForType: _getColorForType,
                    formatTimestamp: _formatTimestamp,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.notificationRepo,
    required this.getIconForType,
    required this.getColorForType,
    required this.formatTimestamp,
  });

  final AppNotification notification;
  final NotificationRepo notificationRepo;
  final IconData Function(NotificationType) getIconForType;
  final Color Function(NotificationType, ColorScheme) getColorForType;
  final String Function(DateTime) formatTimestamp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final iconColor = getColorForType(notification.type, theme.colorScheme);

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      onDismissed: (_) async {
        await notificationRepo.deleteNotification(notification.id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: notification.isRead
              ? theme.colorScheme.surface
              : theme.colorScheme.primaryContainer.withAlpha(128),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: notification.isRead
                ? Colors.grey.shade300
                : theme.colorScheme.primary.withAlpha(128),
            width: notification.isRead ? 1 : 2,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: CircleAvatar(
            backgroundColor: iconColor.withAlpha(51),
            child: Icon(
              getIconForType(notification.type),
              color: iconColor,
            ),
          ),
          title: Text(
            notification.title,
            style: fontProvider.getTextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                notification.message,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withAlpha(179),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatTimestamp(notification.timestamp),
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withAlpha(128),
                ),
              ),
            ],
          ),
          onTap: () async {
            if (!notification.isRead) {
              await notificationRepo.markAsRead(notification.id);
            }
          },
        ),
      ),
    );
  }
}
