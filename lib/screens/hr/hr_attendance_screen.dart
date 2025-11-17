import 'package:flutter/material.dart';
import '../../models/attendance_record_model.dart';
import '../../services/api_service.dart';
import '../../layouts/dashboard_layout.dart';
import '../../models/employee.dart';

class HrAttendanceScreen extends StatefulWidget {
  const HrAttendanceScreen({super.key});

  @override
  State<HrAttendanceScreen> createState() => _HrAttendanceScreenState();
}

class _HrAttendanceScreenState extends State<HrAttendanceScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  List<AttendanceRecord> _attendance = [];
  List<Employee> _employees = [];
  bool _isLoading = true;
  bool _isLoadingEmployees = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _fetchEmployees();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    try {
      final response = await _apiService.get('/accounts/list_attendance/');
      if (response['success']) {
        final data = response['data'];
        final attendanceList = (data['attendance'] ?? []) as List<dynamic>;

        setState(() {
          _attendance = attendanceList.map<AttendanceRecord>((a) {
            return AttendanceRecord.fromJson(a as Map<String, dynamic>);
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching attendance: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchEmployees() async {
    setState(() => _isLoadingEmployees = true);

    try {
      // Using the existing API service get method
      final response = await _apiService.get('/accounts/employees/');
      if (response['success']) {
        final employeesData = (response['data'] ?? []) as List<dynamic>;

        setState(() {
          _employees = employeesData.map<Employee>((e) {
            final empMap = e as Map<String, dynamic>;
            return Employee(
              id: empMap['id']?.toString() ?? '',
              name: empMap['fullname'] ?? empMap['name'] ?? '',
              email: empMap['email'] ?? '',
              department: empMap['department'] ?? '',
              position: empMap['position'] ?? empMap['role'] ?? '',
              phone: empMap['phone'] ?? '',
              joinDate:
                  DateTime.tryParse(
                    empMap['date_joined'] ?? empMap['join_date'] ?? '',
                  ) ??
                  DateTime.now(),
              status: empMap['status'] ?? 'active',
              salary:
                  double.tryParse(empMap['salary']?.toString() ?? '0') ?? 0.0,
            );
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching employees: $e');
    } finally {
      setState(() => _isLoadingEmployees = false);
    }
  }

  String get _today {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  List<AttendanceRecord> get _todaysAttendance {
    return _attendance.where((a) => a.date == _today).toList();
  }

  int get _checkedInCount {
    return _todaysAttendance.where((a) => a.checkIn != null).length;
  }

  int get _totalEmployeesCount {
    return _employees.length;
  }

  int get _absentCount {
    return _totalEmployeesCount - _checkedInCount;
  }

  String get _totalHoursDisplay {
    int totalSeconds = 0;
    for (final record in _todaysAttendance) {
      totalSeconds += record.hours.totalSeconds;
    }

    final hrs = totalSeconds ~/ 3600;
    final mins = (totalSeconds % 3600) ~/ 60;
    final secs = totalSeconds % 60;
    return '${hrs}h ${mins}m ${secs}s';
  }

  Future<void> _downloadPDF() async {
    // TODO: Implement PDF generation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PDF download feature coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DashboardLayout(
      role: 'hr',
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'HR Attendance Dashboard',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 24),

              // KPI Cards
              LayoutBuilder(
                builder: (context, constraints) {
                  int crossAxisCount = 4;
                  if (constraints.maxWidth < 600) {
                    crossAxisCount = 2;
                  } else if (constraints.maxWidth < 900) {
                    crossAxisCount = 3;
                  }

                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      _buildKPICard(
                        'Total Employees',
                        _totalEmployeesCount.toString(),
                        Colors.blue,
                      ),
                      _buildKPICard(
                        'Checked In',
                        _checkedInCount.toString(),
                        Colors.green,
                      ),
                      _buildKPICard(
                        'Absent',
                        _absentCount.toString(),
                        Colors.red,
                      ),
                      _buildKPICard(
                        'Total Hours',
                        _totalHoursDisplay,
                        Colors.purple,
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              // Today's Attendance Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Today Attendance',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton(
                    onPressed: _downloadPDF,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Download PDF'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Attendance Cards
              if (_isLoading || _isLoadingEmployees)
                const Center(child: CircularProgressIndicator())
              else if (_todaysAttendance.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No attendance records for today.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _todaysAttendance.length,
                  itemBuilder: (context, index) {
                    final record = _todaysAttendance[index];
                    return _buildAttendanceCard(record);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKPICard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.7), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(AttendanceRecord record) {
    final hasCheckedIn = record.checkIn != null;
    final hasCheckedOut = record.checkOut != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Employee Info
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: hasCheckedIn
                      ? Colors.green.shade100
                      : Colors.red.shade100,
                  child: Icon(
                    hasCheckedIn ? Icons.check_circle : Icons.cancel,
                    color: hasCheckedIn ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.fullname,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        record.email,
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

            const SizedBox(height: 12),

            // Check In/Out Status
            Row(
              children: [
                // Check In
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: hasCheckedIn
                          ? Colors.green.shade50
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Check-in',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasCheckedIn
                              ? _formatTime(record.checkIn!)
                              : 'Pending',
                          style: TextStyle(
                            fontSize: 14,
                            color: hasCheckedIn
                                ? Colors.green.shade700
                                : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Check Out
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: hasCheckedOut
                          ? Colors.green.shade50
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Check-out',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasCheckedOut
                              ? _formatTime(record.checkOut!)
                              : 'Pending',
                          style: TextStyle(
                            fontSize: 14,
                            color: hasCheckedOut
                                ? Colors.green.shade700
                                : Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Hours Worked
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hours',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          record.hours.toString(),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Progress Bar for hours worked
            if (hasCheckedIn) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: (record.hours.totalHours / 8).clamp(0.0, 1.0),
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(String timeString) {
    try {
      final dateTime = DateTime.parse('2023-01-01T$timeString');
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return timeString;
    }
  }
}
