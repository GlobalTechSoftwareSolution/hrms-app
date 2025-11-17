import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import 'employee_leave_screen.dart';
import 'employee_attendance_screen.dart';
import 'employee_payroll_screen.dart';

class EmployeeHomeScreen extends StatefulWidget {
  const EmployeeHomeScreen({super.key});

  @override
  State<EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends State<EmployeeHomeScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  int _attendanceRate = 0;
  int _pendingRequests = 0;
  double _hoursThisWeek = 0.0; // still tracked but not shown directly
  double _hoursToday = 0.0;
  int _leaveBalance = 15;

  List<Map<String, dynamic>> _attendanceRecords = [];
  List<Map<String, dynamic>> _leaveData = [];
  String _userEmail = '';

  // Target working hours for a single day
  final double _totalPossibleHours = 8.0; // 8 hours per day

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userEmail = prefs.getString('user_email') ?? '';

      if (_userEmail.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      // Fetch leaves
      final leaveResponse = await _apiService.get('/accounts/list_leaves/');
      if (leaveResponse['success']) {
        final leaves = (leaveResponse['data']['leaves'] as List? ?? [])
            .map((e) => e as Map<String, dynamic>)
            .toList();

        setState(() {
          _leaveData = leaves;
        });

        // Calculate pending requests
        final userLeaves = leaves
            .where((l) => l['email'] == _userEmail)
            .toList();
        final pendingCount = userLeaves
            .where((l) => (l['status'] as String?)?.toLowerCase() == 'pending')
            .length;

        setState(() {
          _pendingRequests = pendingCount;
        });

        // Calculate leave balance
        final approvedLeaves = userLeaves
            .where((l) => (l['status'] as String?)?.toLowerCase() == 'approved')
            .toList();

        int totalLeaveDays = 0;
        for (var leave in approvedLeaves) {
          final startDate = DateTime.parse(leave['start_date']);
          final endDate = DateTime.parse(leave['end_date']);
          final days = endDate.difference(startDate).inDays + 1;
          totalLeaveDays += days;
        }

        setState(() {
          _leaveBalance = 15 - totalLeaveDays;
        });
      }

      // Fetch attendance
      final attendanceResponse = await _apiService.get(
        '/accounts/list_attendance/',
      );
      if (attendanceResponse['success']) {
        final attendance =
            (attendanceResponse['data']['attendance'] as List? ?? [])
                .map((e) => e as Map<String, dynamic>)
                .toList();

        final userAttendance = attendance
            .where((a) => a['email'] == _userEmail)
            .toList();

        setState(() {
          _attendanceRecords = userAttendance;
        });

        // Calculate hours (this week + today)
        final now = DateTime.now();
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        double weekHours = 0.0;
        double todayHours = 0.0;

        for (var rec in userAttendance) {
          final checkIn = rec['check_in'] ?? rec['checkIn'];
          final checkOut = rec['check_out'] ?? rec['checkOut'];

          if (checkIn != null) {
            try {
              final dateStr = rec['date'] as String;
              final date = DateTime.parse(dateStr);
              final inTime = DateTime.parse('${dateStr}T$checkIn');

              // Weekly hours (only if check-out exists)
              if (checkOut != null) {
                final outTime = DateTime.parse('${dateStr}T$checkOut');
                if (inTime.isAfter(startOfWeek) ||
                    inTime.isAtSameMomentAs(startOfWeek)) {
                  final hours = outTime.difference(inTime).inMinutes / 60.0;
                  weekHours += hours;
                }
              }

              // Today hours = now - check-in (or check-out if available)
              if (date.year == now.year &&
                  date.month == now.month &&
                  date.day == now.day) {
                DateTime outTimeForToday;
                if (checkOut != null) {
                  outTimeForToday = DateTime.parse('${dateStr}T$checkOut');
                } else {
                  outTimeForToday = now;
                }
                final diffMinutes =
                    outTimeForToday.difference(inTime).inMinutes;
                if (diffMinutes > 0) {
                  todayHours = diffMinutes / 60.0;
                }
              }
            } catch (e) {
              print('Error parsing time: $e');
            }
          }
        }

        setState(() {
          _hoursThisWeek = weekHours;
          _hoursToday = todayHours;

          // Attendance rate as percentage of today's 8-hour target
          if (_hoursToday > 0) {
            int rate = ((_hoursToday / _totalPossibleHours) * 100).round();
            if (rate < 0) rate = 0;
            if (rate > 100) rate = 100;
            _attendanceRate = rate;
          } else {
            _attendanceRate = 0;
          }
        });
      }
    } catch (e) {
      print('Dashboard fetch error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _fetchDashboardData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(),
            const SizedBox(height: 24),

            // Stats Cards
            _buildStatsCards(),
            const SizedBox(height: 24),

            // Daily Hours Table
            _buildDailyHoursSection(),
            const SizedBox(height: 24),

            // Leaves Table
            _buildLeavesSection(),
            const SizedBox(height: 24),

            // Quick Actions
            _buildQuickActions(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dashboard Overview',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Welcome back! Here\'s your personal overview',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                DateFormat('dd/MM/yyyy').format(DateTime.now()),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsCards() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        _buildStatCard(
          title: 'Leave Balance',
          value: '$_leaveBalance',
          subtitle: 'Days remaining',
          icon: Icons.calendar_today,
          color: Colors.green,
          bgColor: Colors.green.shade50,
        ),
        _buildStatCard(
          title: 'Hours Worked Today',
          value: _formatHoursDuration(_hoursToday),
          subtitle:
              '${((_hoursToday / _totalPossibleHours) * 100).toStringAsFixed(1)}% of ${_totalPossibleHours.toInt()} hrs',
          icon: Icons.access_time,
          color: Colors.purple,
          bgColor: Colors.purple.shade50,
        ),
        _buildStatCard(
          title: 'Attendance Rate',
          value: '$_attendanceRate%',
          subtitle: 'Of ${_totalPossibleHours.toInt()} hrs today',
          icon: Icons.trending_up,
          color: Colors.blue,
          bgColor: Colors.blue.shade50,
        ),
        _buildStatCard(
          title: 'Pending Requests',
          value: '$_pendingRequests',
          subtitle: 'Awaiting approval',
          icon: Icons.pending_actions,
          color: Colors.orange,
          bgColor: Colors.orange.shade50,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyHoursSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Hours Worked',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (_attendanceRecords.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No attendance records found'),
              ),
            )
          else
            ..._attendanceRecords.map((rec) {
              final checkIn = rec['check_in'] ?? rec['checkIn'];
              final checkOut = rec['check_out'] ?? rec['checkOut'];

              double hours = 0.0;
              if (checkIn != null && checkOut != null) {
                try {
                  final date = rec['date'] as String;
                  final inTime = DateTime.parse('${date}T$checkIn');
                  final outTime = DateTime.parse('${date}T$checkOut');
                  hours = outTime.difference(inTime).inMinutes / 60.0;
                } catch (e) {
                  print('Error calculating hours: $e');
                }
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat(
                              'dd/MM/yyyy',
                            ).format(DateTime.parse(rec['date'])),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${checkIn != null ? _formatTime(checkIn) : '-'} - ${checkOut != null ? _formatTime(checkOut) : '-'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatHoursDuration(hours),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildLeavesSection() {
    final userLeaves = _leaveData
        .where((l) => l['email'] == _userEmail)
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Leaves',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (userLeaves.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No leave records found'),
              ),
            )
          else
            ...userLeaves.map((leave) {
              final status =
                  (leave['status'] as String?)?.toLowerCase() ?? 'pending';
              Color statusColor = Colors.orange;
              if (status == 'approved') statusColor = Colors.green;
              if (status == 'rejected') statusColor = Colors.red;

              final startDate = DateTime.parse(leave['start_date']);
              final endDate = DateTime.parse(leave['end_date']);
              final days = endDate.difference(startDate).inDays + 1;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${DateFormat('dd/MM/yyyy').format(startDate)} - ${DateFormat('dd/MM/yyyy').format(endDate)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '($days days) - ${leave['reason'] ?? 'No reason provided'}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.calendar_today,
                label: 'Request Leave',
                color: Colors.blue,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EmployeeLeaveScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.access_time,
                label: 'Attendance',
                color: Colors.green,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Scaffold(
                        appBar: AppBar(
                          title: const Text('Attendance'),
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                        ),
                        body: const EmployeeAttendanceScreen(),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.attach_money,
                label: 'View Payslips',
                color: Colors.purple,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EmployeePayrollScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.grey.shade300,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatHoursDuration(double hours) {
    if (hours <= 0) return '0h 00m';
    final totalMinutes = (hours * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  String _formatTime(String time) {
    try {
      final parts = time.split(':');
      int hour = int.parse(parts[0]);
      final minute = parts[1];
      final period = hour >= 12 ? 'PM' : 'AM';
      if (hour > 12) hour -= 12;
      if (hour == 0) hour = 12;
      return '$hour:$minute $period';
    } catch (e) {
      return time;
    }
  }
}
