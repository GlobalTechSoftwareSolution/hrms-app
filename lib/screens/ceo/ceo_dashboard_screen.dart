import 'package:flutter/material.dart';
import '../../layouts/dashboard_layout.dart';

class CeoDashboardScreen extends StatelessWidget {
  const CeoDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardLayout(
      role: 'ceo',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CEO Dashboard',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            
            // Stats Cards
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildStatCard(
                  'Total Employees',
                  '150',
                  Icons.people,
                  Colors.blue,
                ),
                _buildStatCard(
                  'Active Projects',
                  '25',
                  Icons.work,
                  Colors.green,
                ),
                _buildStatCard(
                  'Revenue',
                  '\$2.5M',
                  Icons.attach_money,
                  Colors.orange,
                ),
                _buildStatCard(
                  'Departments',
                  '8',
                  Icons.business,
                  Colors.purple,
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Recent Activity
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recent Activity',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildActivityItem(
                      'New employee onboarded',
                      '2 hours ago',
                      Icons.person_add,
                    ),
                    _buildActivityItem(
                      'Project milestone completed',
                      '5 hours ago',
                      Icons.check_circle,
                    ),
                    _buildActivityItem(
                      'Monthly report generated',
                      '1 day ago',
                      Icons.description,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(String title, String time, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
