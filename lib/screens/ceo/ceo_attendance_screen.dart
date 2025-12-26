import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../services/api_service.dart';
import '../../layouts/dashboard_layout.dart';
import 'monthly_reports_screen.dart';

class CeoAttendanceScreen extends StatefulWidget {
  const CeoAttendanceScreen({super.key});

  @override
  State<CeoAttendanceScreen> createState() => _CeoAttendanceScreenState();
}

class _CeoAttendanceScreenState extends State<CeoAttendanceScreen> {
  final ApiService _apiService = ApiService();

  List<Map<String, dynamic>> _attendance = [];
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _leaves = [];
  List<Map<String, dynamic>> _shifts = [];
  List<Map<String, dynamic>> _overtimeRecords = [];
  List<Map<String, dynamic>> _breaks = [];

  bool _isLoading = true;
  bool _isLoadingEmployees = true;
  bool _showMonthlyReport = false;

  DateTime? _selectedDate;
  String? _attendanceFilter;
  int _selectedMonth = DateTime.now().month - 1;
  int _selectedYear = DateTime.now().year;

  int _totalEmployees = 0;

  // Chart interaction state
  int? _hoveredBarIndex;
  Map<String, dynamic>? _selectedBarEmployee;
  String? _selectedPieSection; // 'present' or 'absent'

  @override
  void initState() {
    super.initState();
    _fetchData();
    _fetchEmployees();
    _fetchLeaves();
    _fetchShifts();
    _fetchOvertimeRecords();
    _fetchBreaks();
    _fetchProjects();
  }

  Future<void> _fetchData({DateTime? forDate}) async {
    setState(() => _isLoading = true);

    try {
      // If a specific date is requested, try to fetch for that date
      // Otherwise fetch general attendance data
      String apiUrl = '/accounts/list_attendance/';
      if (forDate != null) {
        final dateStr = DateFormat('yyyy-MM-dd').format(forDate);
        apiUrl = '/accounts/list_attendance/?date=$dateStr';
        print('CEO Attendance - Fetching attendance for date: $dateStr');
      }

      final response = await _apiService.get(apiUrl);
      print('CEO Attendance - API Response: $response');

      if (response['success']) {
        final data = response['data'];
        print('CEO Attendance - Raw data: $data');

        final attendanceList = List<Map<String, dynamic>>.from(
          data['attendance'] ?? data['data'] ?? data['results'] ?? [],
        );

        print(
          'CEO Attendance - Processed attendance list: ${attendanceList.length} records',
        );

        // Process attendance data with calculated hours
        _attendance = attendanceList.map((a) {
          Map<String, int> hours = {'hrs': 0, 'mins': 0, 'secs': 0};

          if (a['check_in'] != null && a['check_out'] != null) {
            try {
              final checkIn = DateTime.parse('${a['date']}T${a['check_in']}');
              final checkOut = DateTime.parse('${a['date']}T${a['check_out']}');
              final diff = checkOut.difference(checkIn);

              hours = {
                'hrs': diff.inHours,
                'mins': (diff.inMinutes % 60),
                'secs': (diff.inSeconds % 60),
              };
            } catch (e) {
              debugPrint('Error calculating hours: $e');
            }
          }

          return {...a, 'hours': hours};
        }).toList();

        print(
          'CEO Attendance - Final processed attendance: ${_attendance.length} records',
        );
      } else {
        print('CEO Attendance - API call not successful');
        _attendance = [];
      }
    } catch (e) {
      print('Error fetching attendance: $e');
      _attendance = [];
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchEmployees() async {
    setState(() => _isLoadingEmployees = true);

    try {
      final response = await _apiService.get('/accounts/employees/');
      print('CEO Attendance - Employees API Response: $response');

      if (response['success']) {
        final data = response['data'];
        print('CEO Attendance - Employees raw data: $data');

        if (data is List) {
          _employees = List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data.containsKey('employees')) {
          _employees = List<Map<String, dynamic>>.from(data['employees'] ?? []);
        } else if (data is Map && data.containsKey('results')) {
          _employees = List<Map<String, dynamic>>.from(data['results'] ?? []);
        } else {
          _employees = [];
        }

        print('CEO Attendance - Processed employees: ${_employees.length}');

        // Filter employees who have joined on or before today
        final today = DateTime.now();
        final activeEmployees = _employees.where((emp) {
          if (emp['date_joined'] == null && emp['join_date'] == null)
            return true;

          final joinDate = DateTime.tryParse(
            emp['date_joined'] ?? emp['join_date'] ?? '',
          );
          return joinDate == null ||
              joinDate.isBefore(today) ||
              joinDate.isAtSameMomentAs(today);
        }).toList();

        print('CEO Attendance - Active employees: ${activeEmployees.length}');

        setState(() => _totalEmployees = activeEmployees.length);
      } else {
        print('CEO Attendance - Employees API call not successful');
        _employees = [];
      }
    } catch (e) {
      print('Error fetching employees: $e');
      _employees = [];
    } finally {
      setState(() => _isLoadingEmployees = false);
    }
  }

  Future<void> _fetchLeaves() async {
    try {
      final response = await _apiService.get('/accounts/list_leaves/');
      if (response['success']) {
        final data = response['data'];
        _leaves = List<Map<String, dynamic>>.from(data['leaves'] ?? []);
      }
    } catch (e) {
      debugPrint('Error fetching leaves: $e');
    }
  }

  Future<void> _fetchShifts({DateTime? forDate}) async {
    try {
      // Always fetch all shifts and filter on frontend
      // Some APIs may not support date filtering
      final response = await _apiService.get('/accounts/list_shifts/');
      print('CEO Attendance - Shifts API Response: $response');

      if (response['success']) {
        final data = response['data'];
        print('CEO Attendance - Shifts raw data: $data');

        final shiftsList = List<Map<String, dynamic>>.from(
          data['shifts'] ?? data['data'] ?? data['results'] ?? [],
        );

        print('CEO Attendance - Processed shifts: ${shiftsList.length}');

        setState(() => _shifts = shiftsList);
      } else {
        print('CEO Attendance - Shifts API call not successful');
        setState(() => _shifts = []);
      }
    } catch (e) {
      print('Error fetching shifts: $e');
      setState(() => _shifts = []);
    }
  }

  Future<void> _fetchOvertimeRecords({DateTime? forDate}) async {
    try {
      // If a specific date is requested, try to fetch for that date
      // Otherwise fetch general OT data
      String apiUrl = '/accounts/list_ot/';
      if (forDate != null) {
        final dateStr = DateFormat('yyyy-MM-dd').format(forDate);
        apiUrl = '/accounts/list_ot/?date=$dateStr';
        print('CEO Attendance - Fetching OT for date: $dateStr');
      }

      final response = await _apiService.get(apiUrl);
      print('CEO Attendance - OT API Response: $response');

      if (response['success']) {
        final data = response['data'];
        print('CEO Attendance - OT raw data: $data');

        final otList = List<Map<String, dynamic>>.from(
          data['ot_records'] ?? data['data'] ?? data['results'] ?? [],
        );

        print('CEO Attendance - Processed OT records: ${otList.length}');

        setState(() => _overtimeRecords = otList);
      } else {
        print('CEO Attendance - OT API call not successful');
        setState(() => _overtimeRecords = []);
      }
    } catch (e) {
      print('Error fetching overtime records: $e');
      setState(() => _overtimeRecords = []);
    }
  }

  Future<void> _fetchBreaks({DateTime? forDate}) async {
    try {
      // If a specific date is requested, try to fetch for that date
      // Otherwise fetch general breaks data
      String apiUrl = '/accounts/list_breaks/';
      if (forDate != null) {
        final dateStr = DateFormat('yyyy-MM-dd').format(forDate);
        apiUrl = '/accounts/list_breaks/?date=$dateStr';
        print('CEO Attendance - Fetching breaks for date: $dateStr');
      }

      final response = await _apiService.get(apiUrl);
      print('CEO Attendance - Breaks API Response: $response');

      if (response['success']) {
        final data = response['data'];
        print('CEO Attendance - Breaks raw data: $data');

        final breaksList = List<Map<String, dynamic>>.from(
          data['break_records'] ??
              data['breaks'] ??
              data['data'] ??
              data['results'] ??
              [],
        );

        print('CEO Attendance - Processed breaks: ${breaksList.length}');

        setState(() => _breaks = breaksList);
      } else {
        print('CEO Attendance - Breaks API call not successful');
        setState(() => _breaks = []);
      }
    } catch (e) {
      print('Error fetching breaks: $e');
      setState(() => _breaks = []);
    }
  }

  Future<void> _fetchProjects() async {
    try {
      final response = await _apiService.get('/accounts/list_projects/');
      print('CEO Attendance - Projects API Response: $response');

      if (response['success']) {
        final data = response['data'];
        print('CEO Attendance - Projects raw data: $data');

        final projectsList = List<Map<String, dynamic>>.from(
          data['projects'] ?? data['data'] ?? data['results'] ?? [],
        );

        print('CEO Attendance - Processed projects: ${projectsList.length}');

        setState(() => _projects = projectsList);
      } else {
        print('CEO Attendance - Projects API call not successful');
        setState(() => _projects = []);
      }
    } catch (e) {
      print('Error fetching projects: $e');
      setState(() => _projects = []);
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '—';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _getValidImageUrl(String? url, String name) {
    if (url == null || url.isEmpty) {
      return 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=0D8ABC&color=fff';
    }
    try {
      Uri.parse(url);
      return url;
    } catch (e) {
      return 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=0D8ABC&color=fff';
    }
  }

  String _formatTime12Hour(String timeStr) {
    if (timeStr.isEmpty) return '';
    try {
      // Handle HH:mm:ss or HH:mm format
      final parts = timeStr.split(':');
      if (parts.length < 2) return timeStr;

      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      // Convert to 12-hour format
      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);

      return '${hour12}:${minute.toString().padLeft(2, '0')} $period';
    } catch (e) {
      return timeStr; // Return original if parsing fails
    }
  }

  List<Map<String, dynamic>> get _dateAttendance {
    final effectiveDate = _selectedDate ?? DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(effectiveDate);

    print('CEO Attendance - Filtering for date: $dateStr');
    print('CEO Attendance - Total attendance records: ${_attendance.length}');

    // Get attendance records for the date
    final attendanceForDate = _attendance
        .where((a) => a['date'] == dateStr)
        .toList();

    print(
      'CEO Attendance - Records for selected date: ${attendanceForDate.length}',
    );
    if (attendanceForDate.isNotEmpty) {
      print('CEO Attendance - Sample record: ${attendanceForDate.first}');
    }

    // Create attendance map for quick lookup
    final attendanceMap = <String, Map<String, dynamic>>{};
    for (final rec in attendanceForDate) {
      attendanceMap[rec['email']] = rec;
    }

    // Create full list including absent employees
    final result = <Map<String, dynamic>>[];

    for (final emp in _employees) {
      final email = emp['email_id'] ?? emp['email'] ?? '';
      final joinDate = DateTime.tryParse(
        emp['date_joined'] ?? emp['join_date'] ?? '',
      );

      // Skip if employee joined after the selected date
      if (joinDate != null && joinDate.isAfter(effectiveDate)) continue;

      if (attendanceMap.containsKey(email)) {
        result.add(attendanceMap[email]!);
      } else {
        // Mark as absent
        result.add({
          'email': email,
          'fullname': emp['fullname'] ?? emp['name'] ?? 'Unknown',
          'department': emp['department'] ?? 'General',
          'date': dateStr,
          'check_in': null,
          'check_out': null,
          'hours': {'hrs': 0, 'mins': 0, 'secs': 0},
        });
      }
    }

    return result;
  }

  List<Map<String, dynamic>> get _filteredDateAttendance {
    final dateAttendance = _dateAttendance;

    if (_attendanceFilter == 'checked-in') {
      return dateAttendance.where((a) => a['check_in'] != null).toList();
    } else if (_attendanceFilter == 'absent') {
      return dateAttendance.where((a) => a['check_in'] == null).toList();
    }

    return dateAttendance;
  }

  int get _checkedInCount {
    return _dateAttendance.where((a) => a['check_in'] != null).length;
  }

  int get _absentCount {
    return _totalEmployees - _checkedInCount;
  }

  int get _presentCount {
    return _checkedInCount;
  }

  int get _onLeaveCount {
    return _leavesToday;
  }

  int get _leavesToday {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return _leaves.where((leave) {
      final startDate = leave['start_date'] ?? '';
      final endDate = leave['end_date'] ?? '';
      return startDate.compareTo(today) <= 0 && endDate.compareTo(today) >= 0;
    }).length;
  }

  String get _totalHoursDisplay {
    final totalSeconds = _dateAttendance.fold<int>(0, (sum, rec) {
      final hours = rec['hours'] as Map<String, int>;
      return sum +
          (hours['hrs']! * 3600) +
          (hours['mins']! * 60) +
          hours['secs']!;
    });

    final hrs = totalSeconds ~/ 3600;
    final mins = (totalSeconds % 3600) ~/ 60;
    final secs = totalSeconds % 60;

    return '${hrs}h ${mins}m ${secs}s';
  }

  List<PieChartSectionData> get _pieChartData {
    return [
      PieChartSectionData(
        color: Colors.green,
        value: _checkedInCount.toDouble(),
        title: '$_checkedInCount',
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        color: Colors.red,
        value: _absentCount.toDouble(),
        title: '$_absentCount',
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ];
  }

  List<BarChartGroupData> get _barChartData {
    // Include employees who have checked in (with or without checkout)
    final attendanceWithHours = _dateAttendance
        .where((rec) => rec['check_in'] != null)
        .take(8) // Limit to 8 for better display on mobile
        .toList();

    return attendanceWithHours.asMap().entries.map((entry) {
      final rec = entry.value;
      double totalHours;

      // If employee has checked out, use recorded hours
      if (rec['check_out'] != null) {
        final hours = rec['hours'] as Map<String, int>;
        totalHours = hours['hrs']! + (hours['mins']! / 60);
      } else {
        // If still working (no checkout), calculate from check-in to now
        try {
          final checkInTime = DateTime.parse(
            '${rec['date']}T${rec['check_in']}',
          );
          final now = DateTime.now();
          final diff = now.difference(checkInTime);
          totalHours = diff.inHours + (diff.inMinutes % 60) / 60;
        } catch (e) {
          totalHours = 0;
        }
      }

      // Color based on hours worked
      Color barColor;
      if (totalHours >= 8) {
        barColor = Colors.green.shade600; // Full day
      } else if (totalHours >= 6) {
        barColor = Colors.orange.shade600; // Partial day
      } else if (totalHours > 0) {
        barColor =
            Colors.blue.shade600; // Currently working (less than 6 hours)
      } else {
        barColor = Colors.grey.shade400; // Just checked in
      }

      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: totalHours > 0
                ? totalHours
                : 0.1, // Minimum height for visibility
            color: barColor,
            width: 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ],
      );
    }).toList();
  }

  List<String> get _employeeNamesForChart {
    // Include employees who have checked in (with or without checkout)
    final attendanceWithHours = _dateAttendance
        .where((rec) => rec['check_in'] != null)
        .take(8)
        .toList();

    return attendanceWithHours.map<String>((rec) {
      final name = (rec['fullname'] ?? rec['name'] ?? 'Unknown').toString();
      // Get first name only for better display
      return name.split(' ').first;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DashboardLayout(
      role: 'ceo',
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildKPICards(),
              const SizedBox(height: 16),
              _buildCharts(),
              const SizedBox(height: 16),
              _buildCalendar(),
              const SizedBox(height: 16),
              _buildUnifiedRecordsList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.assessment, size: 32, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _showMonthlyReport
                          ? 'MONTHLY PERFORMANCE 📊'
                          : 'CEO ATTENDANCE 📋',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      _showMonthlyReport
                          ? 'Employee performance and productivity insights'
                          : 'Monitor employee attendance and productivity',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // View Toggle Buttons
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showMonthlyReport = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: !_showMonthlyReport
                          ? Colors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white70),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.today,
                          color: !_showMonthlyReport
                              ? Colors.blue.shade600
                              : Colors.white70,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Daily View',
                          style: TextStyle(
                            color: !_showMonthlyReport
                                ? Colors.blue.shade600
                                : Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MonthlyReportsScreen(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white70),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_month,
                          color: Colors.white70,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Monthly Report',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Month/Year selector for monthly report
          if (_showMonthlyReport) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedMonth,
                        dropdownColor: Colors.blue.shade700,
                        style: const TextStyle(color: Colors.white),
                        items: List.generate(12, (index) {
                          final months = [
                            'January',
                            'February',
                            'March',
                            'April',
                            'May',
                            'June',
                            'July',
                            'August',
                            'September',
                            'October',
                            'November',
                            'December',
                          ];
                          return DropdownMenuItem(
                            value: index,
                            child: Text(
                              months[index],
                              style: const TextStyle(color: Colors.white),
                            ),
                          );
                        }),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedMonth = value);
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedYear,
                        dropdownColor: Colors.blue.shade700,
                        style: const TextStyle(color: Colors.white),
                        items: List.generate(6, (index) {
                          final year = DateTime.now().year - 3 + index;
                          return DropdownMenuItem(
                            value: year,
                            child: Text(
                              year.toString(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          );
                        }),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedYear = value);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKPICards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 2;
        if (constraints.maxWidth > 768) {
          crossAxisCount = 4; // Desktop: 4 cards in a row
        } else if (constraints.maxWidth > 480) {
          crossAxisCount = 2; // Tablet: 2 cards in a row
        } else {
          crossAxisCount = 1; // Mobile: 1 card per row
        }

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: crossAxisCount == 1
              ? 3
              : (crossAxisCount == 4 ? 1.2 : 1.5),
          children: [
            _buildKPICard(
              'Total Employees',
              _totalEmployees.toString(),
              Colors.blue,
              Icons.people,
              () {
                // Navigate to employees
              },
            ),
            _buildKPICard(
              'Present Today',
              _presentCount.toString(),
              Colors.green,
              Icons.check_circle,
              () {
                // Filter by present
              },
            ),
            _buildKPICard(
              'Absent Today',
              _absentCount.toString(),
              Colors.red,
              Icons.cancel,
              () {
                // Filter by absent
              },
            ),
            _buildKPICard(
              'On Leave',
              _onLeaveCount.toString(),
              Colors.orange,
              Icons.event_busy,
              () {
                // Filter by on leave
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildKPICard(
    String title,
    String value,
    Color color,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.7), color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: Colors.white),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatHours(Map<String, int> hours) {
    final hrs = hours['hrs'] ?? 0;
    final mins = hours['mins'] ?? 0;
    if (hrs > 0 && mins > 0) {
      return '${hrs}h ${mins}m';
    } else if (hrs > 0) {
      return '${hrs}h';
    } else {
      return '${mins}m';
    }
  }

  Widget _buildCharts() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use column layout for mobile, row for desktop
        if (constraints.maxWidth < 768) {
          return Column(
            children: [
              _buildPieChart(),
              const SizedBox(height: 16),
              _buildBarChart(),
            ],
          );
        } else {
          return Row(
            children: [
              Expanded(child: _buildPieChart()),
              const SizedBox(width: 16),
              Expanded(child: _buildBarChart()),
            ],
          );
        }
      },
    );
  }

  Widget _buildPieChart() {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.pie_chart,
                  size: 20,
                  color: Colors.blue.shade600,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Attendance Distribution',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: _pieChartData.isNotEmpty
                ? Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: PieChart(
                          PieChartData(
                            sections: _pieChartData,
                            centerSpaceRadius: 30,
                            sectionsSpace: 2,
                            pieTouchData: PieTouchData(
                              enabled: true,
                              touchCallback:
                                  (FlTouchEvent event, pieTouchResponse) {
                                    setState(() {
                                      if (pieTouchResponse == null ||
                                          pieTouchResponse.touchedSection ==
                                              null) {
                                        _selectedPieSection = null;
                                        return;
                                      }

                                      final touchedIndex = pieTouchResponse
                                          .touchedSection!
                                          .touchedSectionIndex;
                                      if (touchedIndex == 0) {
                                        _selectedPieSection = 'present';
                                      } else if (touchedIndex == 1) {
                                        _selectedPieSection = 'absent';
                                      }
                                    });
                                  },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 2,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLegendItem(
                              'Present',
                              Colors.green,
                              _presentCount,
                            ),
                            const SizedBox(height: 8),
                            _buildLegendItem(
                              'Absent',
                              Colors.red,
                              _absentCount,
                            ),
                            const SizedBox(height: 8),
                            _buildLegendItem(
                              'On Leave',
                              Colors.orange,
                              _onLeaveCount,
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : const Center(
                    child: Text(
                      'No attendance data available',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
          ),
          // Show employee list when pie section is clicked
          if (_selectedPieSection != null) ...[
            const SizedBox(height: 20),
            _buildPieEmployeeList(),
          ],
        ],
      ),
    );
  }

  Widget _buildPieEmployeeList() {
    final isPresent = _selectedPieSection == 'present';
    final employeeList = _dateAttendance.where((rec) {
      if (isPresent) {
        return rec['check_in'] != null;
      } else {
        return rec['check_in'] == null;
      }
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPresent ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPresent ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPresent ? Icons.check_circle : Icons.cancel,
                color: isPresent ? Colors.green.shade600 : Colors.red.shade600,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                isPresent
                    ? 'Present Employees (${employeeList.length})'
                    : 'Absent Employees (${employeeList.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isPresent
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (employeeList.isEmpty)
            Text(
              isPresent ? 'No employees present' : 'No absent employees',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: employeeList.length,
              itemBuilder: (context, index) {
                final emp = employeeList[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isPresent
                            ? Colors.green.shade200
                            : Colors.red.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: isPresent
                              ? Colors.green.shade100
                              : Colors.red.shade100,
                          child: Text(
                            (emp['fullname'] ?? emp['name'] ?? 'U')
                                .toString()
                                .substring(0, 1)
                                .toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isPresent
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                emp['fullname'] ?? emp['name'] ?? 'Unknown',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                emp['email'] ?? '',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isPresent && emp['hours'] != null)
                          Text(
                            _formatHours(emp['hours'] as Map<String, int>),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.green.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.bar_chart,
                  size: 20,
                  color: Colors.green.shade600,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Employee Hours (${_selectedDate != null ? _formatDate(_selectedDate.toString()) : 'Today'})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 4),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildColorLegend('8+ hrs', Colors.green.shade600),
                          const SizedBox(width: 12),
                          _buildColorLegend('6-8 hrs', Colors.orange.shade600),
                          const SizedBox(width: 12),
                          _buildColorLegend('Working', Colors.blue.shade600),
                          const SizedBox(width: 12),
                          _buildColorLegend('Checked in', Colors.grey.shade400),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Column(
            children: [
              SizedBox(
                height: 200,
                child: _barChartData.isNotEmpty
                    ? BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: 10,
                          minY: 0,
                          barTouchData: BarTouchData(
                            enabled: true,
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipColor: (group) => Colors.grey.shade800,
                              getTooltipItem:
                                  (group, groupIndex, rod, rodIndex) {
                                    final attendanceData = _dateAttendance
                                        .where((rec) => rec['check_in'] != null)
                                        .toList();
                                    if (groupIndex < attendanceData.length) {
                                      final emp = attendanceData[groupIndex];
                                      final hours = rod.toY;
                                      final name =
                                          emp['fullname'] ??
                                          emp['name'] ??
                                          'Unknown';
                                      return BarTooltipItem(
                                        '$name\n${hours.toStringAsFixed(1)}h',
                                        const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      );
                                    }
                                    return null;
                                  },
                            ),
                            handleBuiltInTouches: true,
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (value, meta) {
                                  final employeeNames = _employeeNamesForChart;
                                  if (value.toInt() >= 0 &&
                                      value.toInt() < employeeNames.length) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        employeeNames[value.toInt()],
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (value, meta) {
                                  if (value == 0) return const Text('');
                                  return Text(
                                    '${value.toInt()}h',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  );
                                },
                              ),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: const FlGridData(show: false),
                          barGroups: _barChartData,
                        ),
                      )
                    : _buildEmptyHoursChart(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHoursChart() {
    // Show a nice placeholder chart when no data is available
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Icon(
                Icons.schedule_outlined,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                'No working hours recorded',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Employees will appear here when they check in',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedEmployeeCard(Map<String, dynamic> employee) {
    final hours = employee['hours'] as Map<String, int>?;
    final checkIn = employee['check_in'];
    final checkOut = employee['check_out'];
    final isStillWorking = checkOut == null || checkOut == 'N/A';
    final isPieChartData =
        employee['fullname'] == 'Present Employees' ||
        employee['fullname'] == 'Absent Employees';

    // Calculate current hours if still working
    double totalHours;
    if (isPieChartData) {
      // For pie chart summary data
      totalHours = (hours?['hrs'] ?? 0).toDouble();
    } else if (isStillWorking && checkIn != null && checkIn is String) {
      try {
        final checkInTime = DateTime.parse('${employee['date']}T$checkIn');
        final now = DateTime.now();
        final diff = now.difference(checkInTime);
        totalHours = diff.inHours + (diff.inMinutes % 60) / 60;
      } catch (e) {
        totalHours = 0;
      }
    } else {
      totalHours = ((hours?['hrs'] ?? 0) + ((hours?['mins'] ?? 0) / 60))
          .toDouble();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.person,
                  color: Colors.blue.shade600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee['fullname'] ?? employee['name'] ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      employee['email'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isStillWorking
                      ? Colors.green.shade100
                      : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isStillWorking
                        ? Colors.green.shade300
                        : Colors.orange.shade300,
                  ),
                ),
                child: Text(
                  isStillWorking ? 'Working' : 'Completed',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isStillWorking
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDetailBox(
                  'Check In',
                  isPieChartData
                      ? (checkIn ?? '-')
                      : (checkIn != null && checkIn is String
                            ? DateFormat('HH:mm').format(
                                DateTime.parse('${employee['date']}T$checkIn'),
                              )
                            : '-'),
                  Icons.login,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailBox(
                  'Check Out',
                  isPieChartData
                      ? (checkOut ?? 'N/A')
                      : (checkOut != null && checkOut is String
                            ? DateFormat('HH:mm').format(
                                DateTime.parse('${employee['date']}T$checkOut'),
                              )
                            : 'Pending'),
                  Icons.logout,
                  checkOut != null && checkOut != 'N/A'
                      ? Colors.orange
                      : Colors.grey,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailBox(
                  'Total Hours',
                  '${totalHours.toStringAsFixed(1)}h',
                  Icons.schedule,
                  Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailBox(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, int count) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildColorLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCalendar() {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Select Date',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_selectedDate != null)
                TextButton(
                  onPressed: () {
                    setState(() => _selectedDate = null);
                  },
                  child: const Text('Clear'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TableCalendar<Map<String, dynamic>>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _selectedDate ?? DateTime.now(),
            selectedDayPredicate: (day) {
              return _selectedDate != null && isSameDay(_selectedDate!, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDate = selectedDay;
                _attendanceFilter = null;
              });
              // Fetch all data for the selected date
              _fetchData(forDate: selectedDay);
              _fetchShifts(forDate: selectedDay);
              _fetchOvertimeRecords(forDate: selectedDay);
              _fetchBreaks(forDate: selectedDay);
            },
            calendarFormat: CalendarFormat.month,
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              selectedDecoration: BoxDecoration(
                color: Colors.blue.shade600,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Colors.blue.shade300,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnifiedRecordsList() {
    final filteredAttendance = _filteredDateAttendance;
    final selectedDate = _selectedDate ?? DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

    // Get breaks for the selected date
    final dateBreaks = _breaks.where((breakRecord) {
      if (breakRecord['break_start'] == null) return false;
      try {
        final breakDate = DateTime.parse(breakRecord['break_start']).toLocal();
        final breakDateStr = DateFormat('yyyy-MM-dd').format(breakDate);
        return breakDateStr == dateStr;
      } catch (e) {
        return false;
      }
    }).toList();

    // Get shifts for the selected date
    final dateShifts = _shifts.where((shift) {
      return shift['date'] == dateStr;
    }).toList();

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  '${_selectedDate != null ? _formatDate(_selectedDate.toString()) : 'Today\'s'} Records',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Text(
                  'Total Hours: $_totalHoursDisplay',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_isLoading || _isLoadingEmployees)
            const Center(child: CircularProgressIndicator())
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Attendance Records
                if (filteredAttendance.isNotEmpty) ...[
                  const Text(
                    'Attendance',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredAttendance.length,
                    itemBuilder: (context, index) {
                      final record = filteredAttendance[index];
                      return _buildAttendanceCard(record);
                    },
                  ),
                  const SizedBox(height: 24),
                ],

                // No records message
                if (filteredAttendance.isEmpty &&
                    dateBreaks.isEmpty &&
                    dateShifts.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No records found for this date',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(Map<String, dynamic> record) {
    final hours = record['hours'] as Map<String, int>;
    final isPresent = record['check_in'] != null;
    final employeeEmail = record['email'] ?? '';
    final selectedDate = _selectedDate ?? DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

    // Find employee's shift for today
    print(
      'CEO Attendance - Looking for shift: email=$employeeEmail, date=$dateStr',
    );
    print('CEO Attendance - Available shifts: ${_shifts.length} total');
    print('CEO Attendance - Shift data: $_shifts');

    // Debug shift matching
    print(
      'CEO Attendance - Looking for shift: email=$employeeEmail, date=$dateStr',
    );
    print('CEO Attendance - Available shifts: ${_shifts.length}');

    if (_shifts.isNotEmpty) {
      print('CEO Attendance - First shift sample: ${_shifts.first}');
      print('CEO Attendance - First shift date: ${_shifts.first['date']}');
      print(
        'CEO Attendance - First shift emp_email: ${_shifts.first['emp_email']}',
      );
    }

    final employeeShift = _shifts.firstWhere((shift) {
      final shiftEmail = shift['email'] ?? shift['emp_email'] ?? '';
      final shiftDate = shift['date'] ?? '';

      final emailMatch = shiftEmail == employeeEmail;
      final dateMatch = shiftDate == dateStr;

      print(
        'CEO Attendance - Checking shift: email=$shiftEmail (match: $emailMatch), date=$shiftDate (match: $dateMatch)',
      );

      return emailMatch && dateMatch;
    }, orElse: () => <String, dynamic>{});

    print(
      'CEO Attendance - Found employee shift: ${employeeShift.isNotEmpty ? employeeShift : 'NONE'}',
    );

    print(
      'CEO Attendance - Found shift for employee: ${employeeShift.isNotEmpty ? employeeShift : 'NONE'}',
    );

    // Find employee's OT records for today - Debug the data
    print(
      'CEO Attendance - Looking for OT: email=$employeeEmail, date=$dateStr',
    );
    print(
      'CEO Attendance - Available OT records: ${_overtimeRecords.length} total',
    );

    if (_overtimeRecords.isNotEmpty) {
      print('CEO Attendance - Sample OT record: ${_overtimeRecords.first}');
    }

    final employeeOT = _overtimeRecords.where((ot) {
      final otEmail =
          ot['email'] ?? ot['emp_email'] ?? ot['employee_email'] ?? '';
      if (otEmail != employeeEmail) return false;

      // Try multiple date fields
      final otDateField = ot['ot_start'] ?? ot['start_time'] ?? ot['date'];
      if (otDateField == null) return false;

      try {
        DateTime otDate;
        if (otDateField.contains('T')) {
          // It's a datetime string
          otDate = DateTime.parse(otDateField).toLocal();
        } else {
          // It's a date string
          otDate = DateTime.parse(otDateField);
        }
        final otDateStr = DateFormat('yyyy-MM-dd').format(otDate);
        return otDateStr == dateStr;
      } catch (e) {
        print(
          'CEO Attendance - Error parsing OT date: $otDateField, error: $e',
        );
        return false;
      }
    }).toList();

    print(
      'CEO Attendance - Found OT records for employee: ${employeeOT.length}',
    );
    if (employeeOT.isNotEmpty) {
      print('CEO Attendance - Sample employee OT: ${employeeOT.first}');
    }

    // Calculate total OT hours
    double totalOTHours = 0;
    for (final ot in employeeOT) {
      final startTime = ot['ot_start'] ?? ot['start_time'];
      final endTime = ot['ot_end'] ?? ot['end_time'];

      if (startTime != null && endTime != null) {
        try {
          final start = DateTime.parse(startTime.toString());
          final end = DateTime.parse(endTime.toString());
          final diff = end.difference(start);
          totalOTHours += diff.inMinutes / 60.0;
        } catch (e) {
          print('CEO Attendance - Error calculating OT hours: $e');
          // Skip invalid OT records
        }
      }
    }

    // Find employee's breaks for today - Debug the data
    print(
      'CEO Attendance - Looking for breaks: email=$employeeEmail, date=$dateStr',
    );
    print('CEO Attendance - Available breaks: ${_breaks.length} total');

    if (_breaks.isNotEmpty) {
      print('CEO Attendance - Sample break record: ${_breaks.first}');
      print('CEO Attendance - First break email: ${_breaks.first['email']}');
      print(
        'CEO Attendance - First break start: ${_breaks.first['break_start']}',
      );
    }

    final employeeBreaks = _breaks.where((breakRecord) {
      final breakEmail = breakRecord['email'] ?? '';
      if (breakEmail != employeeEmail) return false;

      final breakStart = breakRecord['break_start'];
      if (breakStart == null) return false;

      try {
        final breakDate = DateTime.parse(breakStart).toLocal();
        final breakDateStr = DateFormat('yyyy-MM-dd').format(breakDate);
        final dateMatch = breakDateStr == dateStr;

        print(
          'CEO Attendance - Checking break: email=$breakEmail (match: ${breakEmail == employeeEmail}), date=$breakDateStr (match: $dateMatch)',
        );

        return dateMatch;
      } catch (e) {
        print(
          'CEO Attendance - Error parsing break date: $breakStart, error: $e',
        );
        return false;
      }
    }).toList();

    print('CEO Attendance - Found employee breaks: ${employeeBreaks.length}');

    // Calculate total break hours
    double totalBreakHours = 0;
    for (final breakRecord in employeeBreaks) {
      if (breakRecord['break_start'] != null &&
          breakRecord['break_end'] != null) {
        try {
          final start = DateTime.parse(breakRecord['break_start']);
          final end = DateTime.parse(breakRecord['break_end']);
          final diff = end.difference(start);
          totalBreakHours += diff.inMinutes / 60.0;
        } catch (e) {
          // Skip invalid break records
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        border: Border.all(
          color: isPresent
              ? Colors.green.withOpacity(0.3)
              : Colors.red.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Top Row - Name and Status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isPresent
                        ? Colors.green.shade100
                        : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isPresent ? Icons.check_circle : Icons.cancel,
                    color: isPresent
                        ? Colors.green.shade600
                        : Colors.red.shade600,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record['fullname'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        record['email'] ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isPresent
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isPresent
                          ? Colors.green.shade200
                          : Colors.red.shade200,
                    ),
                  ),
                  child: Text(
                    isPresent ? 'Present' : 'Absent',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isPresent
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),

            // Divider Line
            const SizedBox(height: 12),
            Divider(height: 1, color: Colors.grey.shade200),
            const SizedBox(height: 12),

            // Shift, OT, and Attendance Info
            Column(
              children: [
                // Shift Information - Always show
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.schedule,
                        size: 14,
                        color: Colors.blue.shade600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        employeeShift.isNotEmpty
                            ? 'Shift: ${employeeShift['shift'] ?? 'N/A'} (${_formatTime12Hour(employeeShift['start_time'] ?? '')} - ${_formatTime12Hour(employeeShift['end_time'] ?? '')})'
                            : 'Shift: No shift assigned',
                        style: TextStyle(
                          fontSize: 12,
                          color: employeeShift.isNotEmpty
                              ? Colors.blue.shade700
                              : Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // OT Information - Always show
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.orange.shade600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        employeeOT.isNotEmpty
                            ? employeeOT.length == 1
                                  ? 'OT: ${DateFormat('hh:mm a').format(DateTime.parse(employeeOT.first['ot_start'] ?? employeeOT.first['start_time']).toLocal())} - ${employeeOT.first['ot_end'] != null || employeeOT.first['end_time'] != null ? DateFormat('hh:mm a').format(DateTime.parse(employeeOT.first['ot_end'] ?? employeeOT.first['end_time']).toLocal()) : 'Ongoing'} (${totalOTHours.toStringAsFixed(2)} hours)'
                                  : 'OT: Multiple (${employeeOT.length})'
                            : 'OT: No overtime recorded',
                        style: TextStyle(
                          fontSize: 12,
                          color: employeeOT.isNotEmpty
                              ? Colors.orange.shade700
                              : Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Break Information - Always show
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.coffee,
                        size: 14,
                        color: Colors.purple.shade600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        employeeBreaks.isNotEmpty
                            ? employeeBreaks.length == 1
                                  ? 'Breaks: ${DateFormat('hh:mm a').format(DateTime.parse(employeeBreaks.first['break_start']).toLocal())} - ${employeeBreaks.first['break_end'] != null ? DateFormat('hh:mm a').format(DateTime.parse(employeeBreaks.first['break_end']).toLocal()) : 'Ongoing'} (${totalBreakHours.toStringAsFixed(2)} hours)'
                                  : 'Breaks: Multiple (${employeeBreaks.length})'
                            : 'Breaks: No breaks recorded',
                        style: TextStyle(
                          fontSize: 12,
                          color: employeeBreaks.isNotEmpty
                              ? Colors.purple.shade700
                              : Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Attendance Information
                Row(
                  children: [
                    Expanded(
                      child: _buildTimeInfo(
                        'Check In',
                        record['check_in'] != null
                            ? DateFormat('hh:mm a').format(
                                DateTime.parse(
                                  '${record['date']}T${record['check_in']}',
                                ),
                              )
                            : '-',
                        Icons.login,
                        Colors.blue,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey.shade200,
                    ),
                    Expanded(
                      child: _buildTimeInfo(
                        'Check Out',
                        record['check_out'] != null
                            ? DateFormat('hh:mm a').format(
                                DateTime.parse(
                                  '${record['date']}T${record['check_out']}',
                                ),
                              )
                            : 'Pending',
                        Icons.logout,
                        record['check_out'] != null
                            ? Colors.orange
                            : Colors.grey,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey.shade200,
                    ),
                    Expanded(
                      child: _buildTimeInfo(
                        'Total Hours',
                        '${hours['hrs']}h ${hours['mins']}m',
                        Icons.schedule,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeInfo(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildMonthlyReportView() {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Report Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.analytics,
                      size: 24,
                      color: Colors.blue.shade600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Team Performance Dashboard',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                        Text(
                          'Viewing data for ${months[_selectedMonth]} $_selectedYear',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '${_employees.length} employees loaded • Employee attendance and performance tracking',
                style: TextStyle(fontSize: 13, color: Colors.blue.shade600),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Employee Performance Cards
        _isLoadingEmployees
            ? const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading employee performance data...'),
                  ],
                ),
              )
            : _employees.isEmpty
            ? Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No employees found',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      'No employee data available',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  int crossAxisCount = 1;
                  if (constraints.maxWidth > 1200) {
                    crossAxisCount = 4;
                  } else if (constraints.maxWidth > 800) {
                    crossAxisCount = 3;
                  } else if (constraints.maxWidth > 600) {
                    crossAxisCount = 2;
                  }

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: _employees.length,
                    itemBuilder: (context, index) {
                      final employee = _employees[index];
                      return _buildEmployeePerformanceCard(employee);
                    },
                  );
                },
              ),
      ],
    );
  }

  Widget _buildEmployeePerformanceCard(Map<String, dynamic> employee) {
    final metrics = _getEmployeeMetrics(employee);

    return GestureDetector(
      onTap: () => _showEmployeeDetailReport(employee),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Employee Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: NetworkImage(
                      _getValidImageUrl(
                        employee['profile_picture'],
                        employee['fullname'] ?? employee['name'] ?? 'User',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          employee['fullname'] ?? employee['name'] ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          employee['designation'] ??
                              employee['role'] ??
                              'Employee',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          employee['department'] ?? 'No Department',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Performance Metrics
              Expanded(
                child: Column(
                  children: [
                    // Top Row Metrics
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            'Attendance',
                            '${metrics['attendanceDays']}',
                            'days',
                            Colors.blue,
                            Icons.calendar_today,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMetricCard(
                            'Avg Hours',
                            '${metrics['avgHours']}',
                            'hrs/day',
                            Colors.green,
                            Icons.schedule,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Bottom Row Metrics
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            'Productivity',
                            '${metrics['productivity']}',
                            '%',
                            Colors.purple,
                            Icons.trending_up,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMetricCard(
                            'Total Hours',
                            '${metrics['totalHours']}',
                            'hrs',
                            Colors.orange,
                            Icons.access_time,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // View Details Button
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  'View Details →',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    String unit,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            unit,
            style: TextStyle(fontSize: 9, color: color.withOpacity(0.8)),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getEmployeeMetrics(Map<String, dynamic> employee) {
    // Mock metrics calculation - in real app, you'd fetch from API
    final attendanceDays = 20 + (employee['fullname']?.hashCode ?? 0) % 5;
    final avgHours = 7.5 + ((employee['email']?.hashCode ?? 0) % 3) * 0.5;
    final productivity = 75 + (employee['department']?.hashCode ?? 0) % 25;
    final totalHours = (attendanceDays * avgHours).round();

    return {
      'attendanceDays': attendanceDays,
      'avgHours': avgHours.toStringAsFixed(1),
      'productivity': productivity,
      'totalHours': totalHours,
    };
  }

  void _showEmployeeDetailReport(Map<String, dynamic> employee) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade600, Colors.blue.shade800],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: NetworkImage(
                        _getValidImageUrl(
                          employee['profile_picture'],
                          employee['fullname'] ?? employee['name'] ?? 'User',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            employee['fullname'] ??
                                employee['name'] ??
                                'Unknown',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            employee['designation'] ??
                                employee['role'] ??
                                'Employee',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                          Text(
                            employee['department'] ?? 'No Department',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white60,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        'Detailed Performance Report',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Coming Soon: Detailed charts, attendance history, task completion rates, and performance analytics.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Icon(
                        Icons.analytics,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreaksList() {
    final selectedDate = _selectedDate ?? DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

    // Filter breaks for the selected date
    final dateBreaks = _breaks.where((breakRecord) {
      if (breakRecord['break_start'] == null) return false;
      try {
        final breakDate = DateTime.parse(breakRecord['break_start']).toLocal();
        final breakDateStr = DateFormat('yyyy-MM-dd').format(breakDate);
        return breakDateStr == dateStr;
      } catch (e) {
        return false;
      }
    }).toList();

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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.coffee,
                  size: 20,
                  color: Colors.purple.shade600,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${_selectedDate != null ? _formatDate(_selectedDate.toString()) : 'Today\'s'} Breaks',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (dateBreaks.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No breaks recorded for this date',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: dateBreaks.length,
              itemBuilder: (context, index) {
                final breakRecord = dateBreaks[index];
                return _buildBreakCard(breakRecord);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBreakCard(Map<String, dynamic> breakRecord) {
    // Find employee details
    final employee = _employees.firstWhere(
      (emp) =>
          emp['email_id'] == breakRecord['email'] ||
          emp['email'] == breakRecord['email'],
      orElse: () => <String, dynamic>{},
    );

    String breakDuration = 'N/A';
    if (breakRecord['break_start'] != null &&
        breakRecord['break_end'] != null) {
      try {
        final start = DateTime.parse(breakRecord['break_start']);
        final end = DateTime.parse(breakRecord['break_end']);
        final diff = end.difference(start);
        final hours = diff.inHours;
        final minutes = diff.inMinutes % 60;
        breakDuration = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
      } catch (e) {
        // Keep default value
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        border: Border.all(color: Colors.purple.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Employee Info
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.coffee,
                    color: Colors.purple.shade600,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee['fullname'] ??
                            breakRecord['emp_name'] ??
                            'Unknown',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        breakRecord['email'] ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Text(
                    'Break',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.purple.shade700,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Divider(height: 1, color: Colors.grey.shade200),
            const SizedBox(height: 12),

            // Break Times
            Row(
              children: [
                Expanded(
                  child: _buildTimeInfo(
                    'Break Start',
                    breakRecord['break_start'] != null
                        ? DateFormat('HH:mm').format(
                            DateTime.parse(
                              breakRecord['break_start'],
                            ).toLocal(),
                          )
                        : '-',
                    Icons.play_arrow,
                    Colors.purple,
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.grey.shade200),
                Expanded(
                  child: _buildTimeInfo(
                    'Break End',
                    breakRecord['break_end'] != null
                        ? DateFormat('HH:mm').format(
                            DateTime.parse(breakRecord['break_end']).toLocal(),
                          )
                        : 'Ongoing',
                    Icons.stop,
                    breakRecord['break_end'] != null
                        ? Colors.orange
                        : Colors.grey,
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.grey.shade200),
                Expanded(
                  child: _buildTimeInfo(
                    'Duration',
                    breakDuration,
                    Icons.schedule,
                    Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftsList() {
    final selectedDate = _selectedDate ?? DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

    // Filter shifts for the selected date
    final dateShifts = _shifts.where((shift) {
      return shift['date'] == dateStr;
    }).toList();

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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.schedule,
                  size: 20,
                  color: Colors.blue.shade600,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${_selectedDate != null ? _formatDate(_selectedDate.toString()) : 'Today\'s'} Shifts',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (dateShifts.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No shifts scheduled for this date',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: dateShifts.length,
              itemBuilder: (context, index) {
                final shift = dateShifts[index];
                return _buildShiftCard(shift);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildShiftCard(Map<String, dynamic> shift) {
    // Find employee details
    final employee = _employees.firstWhere(
      (emp) =>
          emp['email_id'] == shift['emp_email'] ||
          emp['email'] == shift['emp_email'],
      orElse: () => <String, dynamic>{},
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Employee Info
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.schedule,
                    color: Colors.blue.shade600,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee['fullname'] ?? shift['emp_name'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        shift['emp_email'] ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(
                    shift['shift'] ?? 'Shift',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Divider(height: 1, color: Colors.grey.shade200),
            const SizedBox(height: 12),

            // Shift Times and Manager
            Row(
              children: [
                Expanded(
                  child: _buildTimeInfo(
                    'Start Time',
                    shift['start_time'] ?? '-',
                    Icons.play_arrow,
                    Colors.green,
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.grey.shade200),
                Expanded(
                  child: _buildTimeInfo(
                    'End Time',
                    shift['end_time'] ?? '-',
                    Icons.stop,
                    Colors.orange,
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.grey.shade200),
                Expanded(
                  child: Column(
                    children: [
                      Icon(Icons.person, size: 18, color: Colors.purple),
                      const SizedBox(height: 4),
                      Text(
                        'Manager',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        shift['manager_name'] ?? 'N/A',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectCard(Map<String, dynamic> project) {
    final statusColor = _getStatusColor(project['status'] ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        border: Border.all(color: Colors.teal.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Project Info
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.folder,
                    color: Colors.teal.shade600,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project['name'] ??
                            project['title'] ??
                            'Unknown Project',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        project['email'] ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    project['status'] ?? 'Unknown',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),

            if (project['description'] != null) ...[
              const SizedBox(height: 8),
              Text(
                project['description'],
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 12),
            Divider(height: 1, color: Colors.grey.shade200),
            const SizedBox(height: 12),

            // Project Dates and Members
            Row(
              children: [
                Expanded(
                  child: _buildTimeInfo(
                    'Start Date',
                    project['start_date'] != null
                        ? _formatDate(project['start_date'])
                        : '-',
                    Icons.calendar_today,
                    Colors.green,
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.grey.shade200),
                Expanded(
                  child: _buildTimeInfo(
                    'End Date',
                    project['end_date'] != null
                        ? _formatDate(project['end_date'])
                        : '-',
                    Icons.event,
                    Colors.orange,
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.grey.shade200),
                Expanded(
                  child: Column(
                    children: [
                      Icon(Icons.people, size: 18, color: Colors.purple),
                      const SizedBox(height: 4),
                      Text(
                        'Members',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${(project['members'] as List<dynamic>?)?.length ?? 0}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'done':
        return Colors.green;
      case 'in progress':
      case 'active':
      case 'planning':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
      case 'on hold':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
