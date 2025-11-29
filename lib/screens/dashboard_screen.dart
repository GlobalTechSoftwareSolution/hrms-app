import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/hrms_provider.dart';
import '../widgets/stat_card.dart';
import '../widgets/recent_notifications.dart'; // Use the new recent notifications widget
import '../widgets/robust_future_builder.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<HRMSProvider>(
      builder: (context, hrmsProvider, child) {
        // Load initial data if needed
        // In a real app, you would fetch data from the API here
        // For now, we'll use the provider data directly

        return _DashboardContent(provider: hrmsProvider);
      },
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final HRMSProvider provider;

  const _DashboardContent({required this.provider});

  @override
  Widget build(BuildContext context) {
    final totalEmployees = provider.employees.length;
    final pendingLeaves = provider.getPendingLeaveRequests().length;
    final attendanceRate = provider.getAttendanceRate();
    final todayAttendance = provider.getTodayAttendance();
    final presentCount = todayAttendance
        .where((a) => a.status == 'present' || a.status == 'late')
        .length;

    return RobustFutureBuilder<HRMSProvider>(
      future: _loadDashboardData(provider),
      builder: (context, data) {
        return Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dashboard Overview',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                // Stats Cards
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.5,
                  children: [
                    StatCard(
                      title: 'Total Employees',
                      value: totalEmployees.toString(),
                      icon: Icons.people,
                      color: Colors.blue,
                    ),
                    StatCard(
                      title: 'Present Today',
                      value: presentCount.toString(),
                      icon: Icons.check_circle,
                      color: Colors.green,
                    ),
                    StatCard(
                      title: 'Pending Leaves',
                      value: pendingLeaves.toString(),
                      icon: Icons.pending_actions,
                      color: Colors.orange,
                    ),
                    StatCard(
                      title: 'Attendance Rate',
                      value: '${attendanceRate.toStringAsFixed(1)}%',
                      icon: Icons.trending_up,
                      color: Colors.purple,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Department Distribution Chart
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Department Distribution',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 200,
                          child: _buildDepartmentChart(provider),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Recent Notifications instead of Recent Activities
                const RecentNotifications(
                  maxNotifications: 5,
                ), // Show only 5 recent notifications
              ],
            ),
          ),
        );
      },
      loadingWidget: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading dashboard...'),
          ],
        ),
      ),
      errorWidget: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Failed to load dashboard',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please check your connection and try again',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // In a real app, you would retry the data loading
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Retrying...')));
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // Simulate async data loading
  Future<HRMSProvider> _loadDashboardData(HRMSProvider provider) async {
    // In a real app, you would fetch data from the API here
    // For now, we'll just return the provider after a short delay
    await Future.delayed(const Duration(milliseconds: 500));
    return provider;
  }

  Widget _buildDepartmentChart(HRMSProvider provider) {
    final departmentData = provider.getEmployeesByDepartment();
    if (departmentData.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
    ];

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: departmentData.entries.map((entry) {
          final index = departmentData.keys.toList().indexOf(entry.key);
          final color = colors[index % colors.length];

          return PieChartSectionData(
            value: entry.value.toDouble(),
            title: '${entry.value}',
            color: color,
            radius: 50,
            titleStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }).toList(),
      ),
    );
  }
}
