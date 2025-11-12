import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/attendance_record_model.dart';
import '../../services/attendance_service.dart';
import '../../services/approval_service.dart';

class AdminAttendanceScreen extends StatefulWidget {
  const AdminAttendanceScreen({super.key});

  @override
  State<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends State<AdminAttendanceScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  final ApprovalService _approvalService = ApprovalService();

  List<AttendanceRecord> _allAttendance = [];
  int _totalEmployees = 0;
  bool _isLoading = true;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final attendance = await _attendanceService.fetchAttendance();
      final users = await _approvalService.fetchUsers();

      if (mounted) {
        setState(() {
          _allAttendance = attendance;
          _totalEmployees = users.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  List<AttendanceRecord> get _todayAttendance {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return _allAttendance.where((a) => a.date == today).toList();
  }

  List<AttendanceRecord> get _filteredAttendance {
    if (_selectedDate != null) {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      return _allAttendance.where((a) => a.date == dateStr).toList();
    }
    return _todayAttendance;
  }

  int get _checkedInCount => _todayAttendance.where((a) => a.checkIn != null).length;
  int get _absentCount => _totalEmployees - _checkedInCount;

  String get _totalHoursToday {
    final totalSeconds = _todayAttendance.fold<int>(
      0,
      (sum, record) => sum + record.hours.totalSeconds,
    );
    final hrs = totalSeconds ~/ 3600;
    final mins = (totalSeconds % 3600) ~/ 60;
    final secs = totalSeconds % 60;
    return '${hrs}h ${mins}m ${secs}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Dashboard'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // KPI Cards
                    _buildKPICards(),
                    const SizedBox(height: 24),

                    // Charts Section
                    _buildChartsSection(),
                    const SizedBox(height: 24),

                    // Date Filter
                    _buildDateFilter(),
                    const SizedBox(height: 16),

                    // Attendance Cards
                    _buildAttendanceCards(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildKPICards() {
    return GridView.count(
      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        _buildKPICard(
          'Total Employees',
          _totalEmployees.toString(),
          Icons.people,
          Colors.blue,
        ),
        _buildKPICard(
          'Checked In',
          _checkedInCount.toString(),
          Icons.check_circle,
          Colors.green,
        ),
        _buildKPICard(
          'Absent',
          _absentCount.toString(),
          Icons.cancel,
          Colors.red,
        ),
        _buildKPICard(
          'Total Hours',
          _totalHoursToday,
          Icons.access_time,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildKPICard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.8), color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: Colors.white),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartsSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Attendance Distribution',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: PieChart(
                  PieChartData(
                    sections: [
                      PieChartSectionData(
                        value: _checkedInCount.toDouble(),
                        title: '$_checkedInCount\nChecked In',
                        color: Colors.green.shade400,
                        radius: 70,
                        titleStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      PieChartSectionData(
                        value: _absentCount.toDouble(),
                        title: '$_absentCount\nAbsent',
                        color: Colors.red.shade400,
                        radius: 70,
                        titleStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                    sectionsSpace: 2,
                    centerSpaceRadius: 35,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateFilter() {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedDate == null
                      ? 'Select Date'
                      : DateFormat('dd MMM yyyy').format(_selectedDate!),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (_selectedDate != null)
                  TextButton.icon(
                    onPressed: () => setState(() => _selectedDate = null),
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('Clear'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TableCalendar(
              firstDay: DateTime.now().subtract(const Duration(days: 365)),
              lastDay: DateTime.now(),
              focusedDay: _selectedDate ?? DateTime.now(),
              selectedDayPredicate: (day) {
                return _selectedDate != null &&
                    isSameDay(_selectedDate, day);
              },
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDate = isSameDay(_selectedDate, selectedDay)
                      ? null
                      : selectedDay;
                });
              },
              calendarFormat: CalendarFormat.month,
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Colors.green.shade300,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  shape: BoxShape.circle,
                ),
                markerDecoration: BoxDecoration(
                  color: Colors.orange.shade300,
                  shape: BoxShape.circle,
                ),
              ),
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) {
                  final dateStr = DateFormat('yyyy-MM-dd').format(day);
                  final hasAttendance = _allAttendance.any((a) => a.date == dateStr);
                  
                  if (hasAttendance) {
                    return Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isSameDay(day, yesterday)
                            ? Colors.yellow.shade100
                            : Colors.green.shade50,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.green.shade200,
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceCards() {
    if (_filteredAttendance.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'No attendance records found',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      );
    }

    // Calculate responsive columns
    int crossAxisCount = 1;
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) {
      crossAxisCount = 4;
    } else if (width > 900) {
      crossAxisCount = 3;
    } else if (width > 600) {
      crossAxisCount = 2;
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _filteredAttendance.map((record) {
        return SizedBox(
          width: (MediaQuery.of(context).size.width - (12 * (crossAxisCount + 1)) - 32) / crossAxisCount,
          child: _buildAttendanceCard(record),
        );
      }).toList(),
    );
  }

  Widget _buildAttendanceCard(AttendanceRecord record) {
    final checkInTime = record.checkIn != null
        ? DateFormat('hh:mm a').format(
            DateTime.parse('${record.date}T${record.checkIn}'),
          )
        : 'Pending';

    final checkOutTime = record.checkOut != null
        ? DateFormat('hh:mm a').format(
            DateTime.parse('${record.date}T${record.checkOut}'),
          )
        : 'Pending';

    final progressPercent = (record.hours.totalHours / 8).clamp(0.0, 1.0);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Name and Email
            Text(
              record.fullname,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              record.email,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),

            // Check-in/Check-out
            _buildTimeChip('In', checkInTime, record.checkIn != null),
            const SizedBox(height: 5),
            _buildTimeChip('Out', checkOutTime, record.checkOut != null),
            const SizedBox(height: 10),

            // Worked Hours Progress
            const Text(
              'Worked Hours',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
            const SizedBox(height: 5),
            LinearProgressIndicator(
              value: progressPercent,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                progressPercent >= 1.0 ? Colors.green : Colors.blue,
              ),
              minHeight: 5,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 5),
            Text(
              record.hours.toString(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeChip(String label, String time, bool isPresent) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isPresent ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isPresent ? Colors.green.shade200 : Colors.red.shade200,
              ),
            ),
            child: Text(
              time,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isPresent ? Colors.green.shade700 : Colors.red.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}
