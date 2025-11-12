import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/hrms_provider.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<HRMSProvider>(
      builder: (context, provider, child) {
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
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Stay updated with latest announcements',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildNotificationCard(
                      context,
                      icon: Icons.celebration,
                      iconColor: Colors.orange,
                      title: 'Welcome to HRMS!',
                      message: 'Your account has been successfully created. Start exploring the app.',
                      time: '2 hours ago',
                      isRead: false,
                    ),
                    _buildNotificationCard(
                      context,
                      icon: Icons.event_available,
                      iconColor: Colors.green,
                      title: 'Attendance Marked',
                      message: 'Your attendance for today has been recorded successfully.',
                      time: '5 hours ago',
                      isRead: false,
                    ),
                    _buildNotificationCard(
                      context,
                      icon: Icons.announcement,
                      iconColor: Colors.blue,
                      title: 'Company Announcement',
                      message: 'Team meeting scheduled for tomorrow at 10:00 AM in Conference Room A.',
                      time: '1 day ago',
                      isRead: true,
                    ),
                    _buildNotificationCard(
                      context,
                      icon: Icons.beach_access,
                      iconColor: Colors.purple,
                      title: 'Leave Request Update',
                      message: 'Your leave request for Dec 15-17 has been approved by your manager.',
                      time: '2 days ago',
                      isRead: true,
                    ),
                    _buildNotificationCard(
                      context,
                      icon: Icons.payment,
                      iconColor: Colors.teal,
                      title: 'Salary Credited',
                      message: 'Your salary for this month has been credited to your account.',
                      time: '3 days ago',
                      isRead: true,
                    ),
                    _buildNotificationCard(
                      context,
                      icon: Icons.update,
                      iconColor: Colors.indigo,
                      title: 'Policy Update',
                      message: 'New work from home policy has been updated. Please review the changes.',
                      time: '5 days ago',
                      isRead: true,
                    ),
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

  Widget _buildNotificationCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String time,
    required bool isRead,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isRead ? null : Colors.blue.shade50,
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 28,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            if (!isRead)
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
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 4),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () {
          // Handle notification tap
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Opened: $title'),
              duration: const Duration(seconds: 1),
            ),
          );
        },
      ),
    );
  }
}
