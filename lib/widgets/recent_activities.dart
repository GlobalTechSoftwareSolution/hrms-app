import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RecentActivities extends StatelessWidget {
  const RecentActivities({super.key});

  @override
  Widget build(BuildContext context) {
    final activities = [
      {
        'title': 'New Employee Added',
        'description': 'John Doe joined Engineering department',
        'time': DateTime.now().subtract(const Duration(hours: 2)),
        'icon': Icons.person_add,
        'color': Colors.blue,
      },
      {
        'title': 'Leave Approved',
        'description': 'Jane Smith\'s vacation leave approved',
        'time': DateTime.now().subtract(const Duration(hours: 5)),
        'icon': Icons.check_circle,
        'color': Colors.green,
      },
      {
        'title': 'Attendance Alert',
        'description': 'David Brown marked absent today',
        'time': DateTime.now().subtract(const Duration(hours: 8)),
        'icon': Icons.warning,
        'color': Colors.orange,
      },
    ];

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Activities',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ...activities.map((activity) => _buildActivityItem(
                  activity['title'] as String,
                  activity['description'] as String,
                  activity['time'] as DateTime,
                  activity['icon'] as IconData,
                  activity['color'] as Color,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(
    String title,
    String description,
    DateTime time,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatTime(time),
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('MMM dd').format(time);
    }
  }
}
