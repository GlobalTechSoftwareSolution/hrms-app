import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/hrms_provider.dart';
import '../widgets/stat_card.dart';
import '../widgets/recent_activities.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<HRMSProvider>(
      builder: (context, hrmsProvider, child) {
        final totalEmployees = hrmsProvider.employees.length;
        final pendingLeaves = hrmsProvider.getPendingLeaveRequests().length;
        final attendanceRate = hrmsProvider.getAttendanceRate();
        final todayAttendance = hrmsProvider.getTodayAttendance();
        final presentCount = todayAttendance
            .where((a) => a.status == 'present' || a.status == 'late')
            .length;

        return SingleChildScrollView(
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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 200,
                        child: _buildDepartmentChart(hrmsProvider),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Recent Activities
              const RecentActivities(),
            ],
          ),
        );
      },
    );
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
