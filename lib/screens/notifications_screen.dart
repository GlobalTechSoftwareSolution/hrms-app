import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../providers/hrms_provider.dart';
import '../providers/notification_provider.dart';
import '../services/fcm_service.dart';
import '../models/notification_model.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late StreamSubscription<RemoteMessage> _messageSubscription;
  String? _fcmToken;

  @override
  void initState() {
    super.initState();
    // Listen to FCM messages
    _messageSubscription = FCMService().messageStream.listen((message) {
      // Handle incoming FCM message
      _handleFCMMessage(message);
    });

    // Get FCM token for display
    _getFCMToken();
  }

  Future<void> _getFCMToken() async {
    try {
      print('Attempting to retrieve FCM token...');
      final token = await FCMService().getFCMToken();
      print('FCM token retrieval result: $token');
      if (mounted) {
        setState(() {
          _fcmToken = token;
        });
        if (token != null) {
          print('FCM token successfully retrieved and set in state');
        } else {
          print(
            'FCM token is null - might not be ready yet or there was an issue',
          );
        }
      } else {
        print('Widget not mounted, cannot update state');
      }
    } catch (e) {
      print('Error getting FCM token: $e');
    }
  }

  @override
  void dispose() {
    _messageSubscription.cancel();
    super.dispose();
  }

  void _handleFCMMessage(RemoteMessage message) {
    // Create a notification model from the FCM message
    final notificationModel = NotificationModel(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: message.notification?.title ?? 'New Notification',
      body: message.notification?.body ?? 'You have a new notification',
      timestamp: DateTime.now(),
      isRead: false,
      type: _getNotificationType(message.data['notification_type']),
      data: message.data,
    );

    // Add to notification provider
    Provider.of<NotificationProvider>(
      context,
      listen: false,
    ).addNotification(notificationModel);

    // Show a snackbar when a new FCM message arrives
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'New notification: ${message.notification?.title ?? 'No title'}',
          ),
          duration: const Duration(seconds: 3),
        ),
      );

      // Refresh the UI to show the new notification
      setState(() {
        // This will trigger a rebuild with the new notification
      });
    }
  }

  NotificationType _getNotificationType(String? typeString) {
    if (typeString == null) return NotificationType.general;

    switch (typeString) {
      case 'ticketAssigned':
        return NotificationType.ticketAssigned;
      case 'ticketUpdated':
        return NotificationType.ticketUpdated;
      case 'ticketClosed':
        return NotificationType.ticketClosed;
      case 'leaveApproved':
        return NotificationType.leaveApproved;
      case 'leaveRejected':
        return NotificationType.leaveRejected;
      case 'attendanceReminder':
        return NotificationType.attendanceReminder;
      case 'announcement':
        return NotificationType.announcement;
      default:
        return NotificationType.general;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<HRMSProvider, NotificationProvider>(
      builder: (context, hrmsProvider, notificationProvider, child) {
        final notifications = notificationProvider.notifications;

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notifications',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Stay updated with latest announcements',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Display FCM Token for testing
                      if (_fcmToken != null)
                        Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'FCM Token:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: () {
                                    // Show snackbar when token is tapped
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Token displayed below - check logs for full token',
                                        ),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    _fcmToken!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (_fcmToken == null)
                        Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'FCM Token:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Retrieving token...',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Add a button to test FCM notification
                      ElevatedButton.icon(
                        onPressed: () {
                          // This would typically be called from your backend
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Test notification sent'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.send),
                        label: const Text('Test Notification'),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Display all notifications from the provider
                    if (notifications.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text(
                            'No notifications yet',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ),
                      ),
                    ...notifications
                        .map(
                          (notification) => _buildNotificationCardFromModel(
                            context,
                            notification,
                            notificationProvider,
                          ),
                        )
                        .toList(),
                    const SizedBox(height: 16),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotificationCardFromModel(
    BuildContext context,
    NotificationModel notification,
    NotificationProvider provider,
  ) {
    IconData icon;
    Color iconColor;

    switch (notification.type) {
      case NotificationType.ticketAssigned:
      case NotificationType.ticketUpdated:
      case NotificationType.ticketClosed:
        icon = Icons.confirmation_number;
        iconColor = Colors.blue;
        break;
      case NotificationType.leaveApproved:
      case NotificationType.leaveRejected:
        icon = Icons.beach_access;
        iconColor = Colors.purple;
        break;
      case NotificationType.attendanceReminder:
        icon = Icons.event_available;
        iconColor = Colors.green;
        break;
      case NotificationType.announcement:
        icon = Icons.announcement;
        iconColor = Colors.orange;
        break;
      default:
        icon = Icons.notifications;
        iconColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: notification.isRead ? null : Colors.blue.shade50,
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 28),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                notification.title,
                style: TextStyle(
                  fontWeight: notification.isRead
                      ? FontWeight.w600
                      : FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            if (!notification.isRead)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Text(
              notification.body,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  _formatDateTime(notification.timestamp),
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getNotificationTypeColor(
                      notification.type,
                    ).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    notification.type.displayName,
                    style: TextStyle(
                      fontSize: 10,
                      color: _getNotificationTypeColor(notification.type),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () {
          // Mark as read when tapped
          provider.markAsRead(notification.id);

          // Handle notification tap based on type
          _handleNotificationTap(notification);
        },
      ),
    );
  }

  Color _getNotificationTypeColor(NotificationType type) {
    switch (type) {
      case NotificationType.ticketAssigned:
      case NotificationType.ticketUpdated:
      case NotificationType.ticketClosed:
        return Colors.blue;
      case NotificationType.leaveApproved:
      case NotificationType.leaveRejected:
        return Colors.purple;
      case NotificationType.attendanceReminder:
        return Colors.green;
      case NotificationType.announcement:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'Today ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  void _handleNotificationTap(NotificationModel notification) {
    // Handle navigation based on notification type
    switch (notification.type) {
      case NotificationType.ticketAssigned:
      case NotificationType.ticketUpdated:
      case NotificationType.ticketClosed:
        // Navigate to tickets screen
        if (mounted) {
          Navigator.pushNamed(
            context,
            '/tickets',
            arguments: {'ticketId': notification.data?['item_id']},
          );
        }
        break;
      case NotificationType.leaveApproved:
      case NotificationType.leaveRejected:
        // Navigate to leaves screen
        if (mounted) {
          Navigator.pushNamed(
            context,
            '/leaves',
            arguments: {'leaveId': notification.data?['item_id']},
          );
        }
        break;
      case NotificationType.attendanceReminder:
        // Navigate to attendance screen
        if (mounted) {
          Navigator.pushNamed(context, '/attendance');
        }
        break;
      case NotificationType.announcement:
        // Navigate to announcements screen
        if (mounted) {
          Navigator.pushNamed(
            context,
            '/announcements',
            arguments: {'announcementId': notification.data?['item_id']},
          );
        }
        break;
      default:
        // Handle general notification
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Opened notification: ${notification.title}'),
              duration: const Duration(seconds: 1),
            ),
          );
        }
    }
  }
}
