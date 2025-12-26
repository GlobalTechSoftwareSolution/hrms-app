import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_filex/open_filex.dart';
import '../../models/attendance_record_model.dart';
import '../../services/attendance_service.dart';
import '../../services/approval_service.dart';
import '../../config/api_config.dart';

class AdminAttendanceScreen extends StatefulWidget {
  const AdminAttendanceScreen({super.key});

  @override
  State<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends State<AdminAttendanceScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  final ApprovalService _approvalService = ApprovalService();

  List<AttendanceRecord> _allAttendance = [];
  List<Map<String, dynamic>> _shifts = [];
  List<Map<String, dynamic>> _otRecords = [];
  List<Map<String, dynamic>> _breaks = [];
  int _totalEmployees = 0;
  bool _isLoading = true;
  DateTime? _selectedDate;
  Timer? _realTimeTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startRealTimeUpdates();
  }

  @override
  void dispose() {
    _realTimeTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    debugPrint('Loading admin attendance data...');
    debugPrint('About to fetch attendance data...');

    try {
      final attendance = await _attendanceService.fetchAttendance();
      debugPrint('Fetched ${attendance.length} attendance records');

      // Fetch employees instead of all users
      final employees = await _fetchEmployees();
      debugPrint('Fetched ${employees.length} employees');

      // Fetch additional data
      debugPrint('About to fetch shifts...');
      await _fetchShifts();
      debugPrint('About to fetch OT records...');
      await _fetchOTRecords();
      debugPrint('About to fetch breaks...');
      await _fetchBreaks();

      if (mounted) {
        setState(() {
          _allAttendance = attendance;
          _totalEmployees = employees.length;
          debugPrint('Setting _totalEmployees to $_totalEmployees');
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error in _loadData: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
  }

  void _startRealTimeUpdates() {
    _realTimeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          // Real-time updates will trigger rebuild
        });
      }
    });
  }

  Future<void> _fetchShifts() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.apiUrl}/accounts/list_shifts/'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _shifts = List<Map<String, dynamic>>.from(
          data is List ? data : (data['shifts'] ?? []),
        );
        debugPrint('Fetched ${_shifts.length} shifts');
        if (_shifts.isNotEmpty) {
          debugPrint('Sample shift: ${_shifts.first}');
        }
      } else {
        debugPrint(
          'Failed to fetch shifts: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching shifts: $e');
    }
  }

  Future<void> _fetchOTRecords() async {
    try {
      debugPrint(
        'About to fetch OT records from: ${ApiConfig.apiUrl}/accounts/list_ot/',
      );
      final response = await http.get(
        Uri.parse('${ApiConfig.apiUrl}/accounts/list_ot/'),
        headers: {'Content-Type': 'application/json'},
      );
      debugPrint('OT Records API response status: ${response.statusCode}');
      debugPrint('OT Records API response body: ${response.body}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _otRecords = List<Map<String, dynamic>>.from(
          data is List ? data : (data['ot_records'] ?? []),
        );
        debugPrint('Fetched ${_otRecords.length} OT records');
        if (_otRecords.isNotEmpty) {
          debugPrint('Sample OT record: ${_otRecords.first}');
        }
      } else {
        debugPrint(
          'Failed to fetch OT records: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching OT records: $e');
    }
  }

  Future<void> _fetchBreaks() async {
    try {
      debugPrint(
        'About to fetch breaks from: ${ApiConfig.apiUrl}/accounts/list_breaks/',
      );
      final response = await http.get(
        Uri.parse('${ApiConfig.apiUrl}/accounts/list_breaks/'),
        headers: {'Content-Type': 'application/json'},
      );
      debugPrint('Breaks API response status: ${response.statusCode}');
      debugPrint('Breaks API response body: ${response.body}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _breaks = List<Map<String, dynamic>>.from(
          data is List ? data : (data['breaks'] ?? data['break_records'] ?? []),
        );
        debugPrint('Fetched ${_breaks.length} breaks');
        if (_breaks.isNotEmpty) {
          debugPrint('Sample break record: ${_breaks.first}');
        }
      } else {
        debugPrint(
          'Failed to fetch breaks: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching breaks: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchEmployees() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.apiUrl}/accounts/employees/'),
        headers: {'Content-Type': 'application/json'},
      );
      debugPrint('Employees API response status: ${response.statusCode}');
      debugPrint('Employees API response body: ${response.body}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Return the list of employees
        final employeesList = List<Map<String, dynamic>>.from(
          data['employees'] ?? [],
        );
        debugPrint('Fetched ${employeesList.length} employees');
        return employeesList;
      }
    } catch (e) {
      debugPrint('Error fetching employees: $e');
    }
    return [];
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

  int get _checkedInCount =>
      _todayAttendance.where((a) => a.checkIn != null).length;
  int get _currentlyWorkingCount => _todayAttendance
      .where((a) => a.checkIn != null && a.checkOut == null)
      .length;
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
        title: const Text('Admin Attendance Dashboard'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _downloadPDF,
            tooltip: 'Download PDF',
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
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
    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = 1;
    if (screenWidth > 1200)
      crossAxisCount = 5;
    else if (screenWidth > 900)
      crossAxisCount = 4;
    else if (screenWidth > 600)
      crossAxisCount = 2;
    else
      crossAxisCount = 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: constraints.maxWidth > 600 ? 1.3 : 2.0,
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
              'Currently Working',
              _currentlyWorkingCount.toString(),
              Icons.work,
              Colors.teal,
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
      },
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
              style: const TextStyle(fontSize: 11, color: Colors.white70),
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
    // Calculate employees who have attendance records today (checked in)
    // and those who don't (not checked in today)
    final checkedInToday = _checkedInCount;
    final notCheckedInToday = _totalEmployees > 0
        ? _totalEmployees - _checkedInCount
        : 0;

    return Column(
      children: [
        // Pie Chart - Checked In vs Not Checked In Today
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'Today\'s Attendance',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 220,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: PieChart(
                      PieChartData(
                        sections: _totalEmployees > 0
                            ? [
                                PieChartSectionData(
                                  value: checkedInToday.toDouble(),
                                  title:
                                      '${checkedInToday > 0 ? (checkedInToday / _totalEmployees * 100).toStringAsFixed(0) : '0'}%\nChecked In',
                                  color: Colors.green.shade400,
                                  radius: 70,
                                  titleStyle: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                PieChartSectionData(
                                  value: notCheckedInToday.toDouble(),
                                  title:
                                      '${notCheckedInToday > 0 ? (notCheckedInToday / _totalEmployees * 100).toStringAsFixed(0) : '0'}%\nNot Checked In',
                                  color: Colors.grey.shade400,
                                  radius: 70,
                                  titleStyle: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ]
                            : [
                                PieChartSectionData(
                                  value: 1.0,
                                  title: 'No Data',
                                  color: Colors.grey.shade400,
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
        ),
        const SizedBox(height: 16),

        // Bar Chart
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'Hours Worked Per Employee (Month)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SizedBox(height: 220, child: _buildBarChart()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBarChart() {
    // Handle case when there's no attendance data
    if (_allAttendance.isEmpty) {
      return const Center(
        child: Text(
          'No attendance data available',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      );
    }

    final currentMonth = DateTime.now().month;
    final currentYear = DateTime.now().year;

    final monthlyAttendance = _allAttendance.where((rec) {
      try {
        final recDate = DateTime.parse(rec.date);
        return recDate.month == currentMonth && recDate.year == currentYear;
      } catch (e) {
        debugPrint('Error parsing date: ${rec.date}');
        return false;
      }
    }).toList();

    final hoursPerEmployeeMap = <String, double>{};
    for (final rec in monthlyAttendance) {
      try {
        final hours =
            rec.hours.hrs + rec.hours.mins / 60.0 + rec.hours.secs / 3600.0;
        if (hoursPerEmployeeMap.containsKey(rec.fullname)) {
          hoursPerEmployeeMap[rec.fullname] =
              hoursPerEmployeeMap[rec.fullname]! + hours;
        } else {
          hoursPerEmployeeMap[rec.fullname] = hours;
        }
      } catch (e) {
        debugPrint('Error calculating hours for ${rec.fullname}: $e');
      }
    }

    // Convert to list with proper indexing
    final entriesList = hoursPerEmployeeMap.entries.toList();
    final barData = entriesList.asMap().entries.map((indexedEntry) {
      final index = indexedEntry.key;
      final entry = indexedEntry.value;
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: double.parse(entry.value.toStringAsFixed(2)),
            color: Colors.indigo.shade400,
            width: 16,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ],
      );
    }).toList();

    if (barData.isEmpty) {
      return const Center(
        child: Text(
          'No data for current month',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      );
    }

    return BarChart(
      BarChartData(
        barGroups: barData,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < entriesList.length) {
                  final name = entriesList[index].key;
                  // Truncate long names for better display
                  final displayName = name.length > 12
                      ? '${name.substring(0, 10)}..'
                      : name;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return const Text('');
              },
              reservedSize: 60,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                );
              },
              reservedSize: 30,
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(show: true, drawVerticalLine: false),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              if (groupIndex < entriesList.length) {
                final name = entriesList[groupIndex].key;
                final hours = entriesList[groupIndex].value;
                return BarTooltipItem(
                  '$name\n${hours.toStringAsFixed(2)}h',
                  const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }
              return null;
            },
          ),
          touchCallback: (FlTouchEvent event, BarTouchResponse? response) {
            // Only show tooltip on tap/click, not on hover
            if (event is FlTapUpEvent) {
              // Tooltip will be shown automatically
              return;
            }
            // For other events (hover, etc.), we could handle them differently if needed
          },
          handleBuiltInTouches: true,
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
                return _selectedDate != null && isSameDay(_selectedDate, day);
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
                  final hasAttendance = _allAttendance.any(
                    (a) => a.date == dateStr,
                  );

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

    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _filteredAttendance.map((record) {
            double cardWidth = constraints.maxWidth;
            if (crossAxisCount > 1) {
              cardWidth =
                  (constraints.maxWidth - (12 * (crossAxisCount - 1))) /
                  crossAxisCount;
            }
            return SizedBox(
              width: cardWidth,
              child: _buildAttendanceCard(record),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildAttendanceCard(AttendanceRecord record) {
    final checkInTime = record.checkIn != null
        ? DateFormat(
            'hh:mm a',
          ).format(DateTime.parse('${record.date}T${record.checkIn}'))
        : 'Pending';

    final checkOutTime = record.checkOut != null
        ? DateFormat(
            'hh:mm a',
          ).format(DateTime.parse('${record.date}T${record.checkOut}'))
        : 'Pending';

    final isCurrentlyWorking =
        record.checkIn != null && record.checkOut == null;
    final currentHours = isCurrentlyWorking
        ? _calculateCurrentHours(record)
        : record.hours;
    final progressPercent = (currentHours.totalHours / 8).clamp(0.0, 1.0);

    // Filter shifts, OT, breaks for this employee and date
    final employeeShifts = _shifts
        .where(
          (shift) =>
              shift['date'] == record.date &&
              (shift['emp_email'] == record.email ||
                  shift['employee_email'] == record.email),
        )
        .toList();

    final employeeOT = _otRecords.where((ot) {
      try {
        // Parse the ISO date string and extract just the date part
        final otDateTime = DateTime.parse(ot['ot_start']);
        final otDate =
            '${otDateTime.year}-${otDateTime.month.toString().padLeft(2, '0')}-${otDateTime.day.toString().padLeft(2, '0')}';

        final emailMatch =
            (ot['email'] == record.email ||
            ot['emp_email'] == record.email ||
            ot['employee_email'] == record.email);
        final dateMatch = otDate == record.date;

        // Debug: print the comparison details
        if (record.email == 'manibharadwajcr@globaltechsoftwaresolutions.com' ||
            record.email == 'kiran@globalfincare.in' ||
            record.email == 'abhishek@globaltechsoftwaresolutions.com') {
          debugPrint(
            'OT Check - Record email: ${record.email}, Record date: ${record.date}',
          );
          debugPrint(
            'OT Check - OT email: ${ot['email']}, OT date: $otDate, OT start: ${ot['ot_start']}',
          );
          debugPrint(
            'OT Check - Email match: $emailMatch, Date match: $dateMatch, Overall match: ${dateMatch && emailMatch}',
          );
        }

        // Debug: print when we have a potential match
        if (dateMatch && emailMatch) {
          debugPrint(
            'OT Match found: ${ot['email']} on $otDate matches ${record.email} on ${record.date}',
          );
        }
        return dateMatch && emailMatch;
      } catch (e) {
        debugPrint('Error parsing OT date: ${ot['ot_start']} - Error: $e');
        return false;
      }
    }).toList();

    final employeeBreaks = _breaks.where((br) {
      try {
        // Parse the ISO date string and extract just the date part
        final breakDateTime = DateTime.parse(br['break_start']);
        final breakDate =
            '${breakDateTime.year}-${breakDateTime.month.toString().padLeft(2, '0')}-${breakDateTime.day.toString().padLeft(2, '0')}';

        final emailMatch =
            (br['email'] == record.email ||
            br['emp_email'] == record.email ||
            br['employee_email'] == record.email);
        final dateMatch = breakDate == record.date;

        // Debug: print the comparison details
        if (record.email == 'manibharadwajcr@globaltechsoftwaresolutions.com' ||
            record.email == 'kiran@globalfincare.in' ||
            record.email == 'abhishek@globaltechsoftwaresolutions.com') {
          debugPrint(
            'Break Check - Record email: ${record.email}, Record date: ${record.date}',
          );
          debugPrint(
            'Break Check - Break email: ${br['email']}, Break date: $breakDate, Break start: ${br['break_start']}',
          );
          debugPrint(
            'Break Check - Email match: $emailMatch, Date match: $dateMatch, Overall match: ${dateMatch && emailMatch}',
          );
        }

        // Debug: print when we have a potential match
        if (dateMatch && emailMatch) {
          debugPrint(
            'Break Match found: ${br['email']} on $breakDate matches ${record.email} on ${record.date}',
          );
        }
        return dateMatch && emailMatch;
      } catch (e) {
        debugPrint(
          'Error parsing break date: ${br['break_start']} - Error: $e',
        );
        return false;
      }
    }).toList();

    // Debug logging
    debugPrint('Employee ${record.email} on ${record.date}:');
    debugPrint('  - Shifts: ${employeeShifts.length}');
    debugPrint('  - OT: ${employeeOT.length}');
    debugPrint('  - Breaks: ${employeeBreaks.length}');

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
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              record.email,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),

            // Check-in/Check-out times
            _buildTimeChip('In', checkInTime, record.checkIn != null),
            const SizedBox(height: 5),
            _buildTimeChip('Out', checkOutTime, record.checkOut != null),
            const SizedBox(height: 10),

            // Check-in/Check-out Images
            Row(
              children: [
                // Check-in photo
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'Check-in',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.green.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child:
                            record.checkInPhoto != null &&
                                record.checkInPhoto!.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(
                                  record.checkInPhoto!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                        Icons.image_not_supported,
                                        size: 20,
                                        color: Colors.grey,
                                      ),
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt,
                                size: 20,
                                color: Colors.grey,
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Check-out photo
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'Check-out',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.red.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child:
                            record.checkOutPhoto != null &&
                                record.checkOutPhoto!.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(
                                  record.checkOutPhoto!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                        Icons.image_not_supported,
                                        size: 20,
                                        color: Colors.grey,
                                      ),
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt,
                                size: 20,
                                color: Colors.grey,
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Shifts
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 12,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Shifts' +
                            (employeeShifts.isNotEmpty
                                ? ' (${employeeShifts.length})'
                                : ''),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (employeeShifts.isNotEmpty) ...[
                    ...employeeShifts.map(
                      (shift) => Text(
                        '${shift['shift'] ?? shift['shift_type'] ?? 'General'}: ${_formatTime(shift['start_time'])} - ${_formatTime(shift['end_time'])}',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.blue.shade600,
                        ),
                      ),
                    ),
                  ] else ...[
                    Text(
                      'No shifts assigned',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.blue.shade400,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Overtime
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Overtime' +
                            (employeeOT.isNotEmpty
                                ? ' (${employeeOT.length})'
                                : ''),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (employeeOT.isNotEmpty) ...[
                    ...employeeOT.map((ot) {
                      final startTime = DateTime.parse(ot['ot_start']);
                      final endTime = DateTime.parse(ot['ot_end']);
                      final hours =
                          endTime.difference(startTime).inMinutes / 60;
                      return Text(
                        '${DateFormat('HH:mm').format(startTime)} - ${DateFormat('HH:mm').format(endTime)} (${hours.toStringAsFixed(1)}h)',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.orange.shade600,
                        ),
                      );
                    }),
                  ] else ...[
                    Text(
                      'No overtime recorded',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.orange.shade400,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Breaks
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.coffee,
                        size: 12,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Breaks' +
                            (employeeBreaks.isNotEmpty
                                ? ' (${employeeBreaks.length})'
                                : ''),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (employeeBreaks.isNotEmpty) ...[
                    ...employeeBreaks.map((br) {
                      final startTime = DateTime.parse(br['break_start']);
                      final endTime = br['break_end'] != null
                          ? DateTime.parse(br['break_end'])
                          : null;
                      if (endTime != null) {
                        final hours =
                            endTime.difference(startTime).inMinutes / 60;
                        return Text(
                          '${DateFormat('HH:mm').format(startTime)} - ${DateFormat('HH:mm').format(endTime)} (${hours.toStringAsFixed(1)}h)',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.green.shade600,
                          ),
                        );
                      } else {
                        return Text(
                          '${DateFormat('HH:mm').format(startTime)} - Ongoing',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.green.shade600,
                          ),
                        );
                      }
                    }),
                  ] else ...[
                    Text(
                      'No breaks recorded',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.green.shade400,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Worked Hours Progress
            Text(
              isCurrentlyWorking ? 'Working Hours' : 'Worked Hours',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            const SizedBox(height: 5),
            LinearProgressIndicator(
              value: progressPercent,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                isCurrentlyWorking
                    ? Colors.green
                    : (progressPercent >= 1.0 ? Colors.green : Colors.blue),
              ),
              minHeight: 5,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${currentHours.hrs}h ${currentHours.mins}m ${currentHours.secs}s',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isCurrentlyWorking) ...[
                  const SizedBox(width: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
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

  WorkedHours _calculateCurrentHours(AttendanceRecord record) {
    if (record.checkIn == null) {
      return WorkedHours(hrs: 0, mins: 0, secs: 0);
    }

    final checkInTime = DateTime.parse('${record.date}T${record.checkIn}');
    final now = DateTime.now();
    final diff = now.difference(checkInTime);

    if (diff.inSeconds <= 0) {
      return WorkedHours(hrs: 0, mins: 0, secs: 0);
    }

    return WorkedHours(
      hrs: diff.inHours,
      mins: diff.inMinutes % 60,
      secs: diff.inSeconds % 60,
    );
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '-';

    try {
      // Handle different time formats
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);

        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour % 12 == 0 ? 12 : hour % 12;

        return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
      }
    } catch (e) {
      debugPrint('Error formatting time: $e');
    }

    return timeStr;
  }

  Future<void> _downloadPDF() async {
    try {
      final pdf = pw.Document();

      // Add company logo and header
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    'Global Tech Solutions',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Center(
                  child: pw.Text(
                    'Attendance Report',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Date: ${DateFormat('dd/MM/yyyy').format(_selectedDate ?? DateTime.now())}',
                  style: pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 20),

                // Table
                pw.Table.fromTextArray(
                  headers: [
                    'ID',
                    'Employee Name',
                    'Email',
                    'Department',
                    'Check-in',
                    'Check-out',
                    'Hours',
                  ],
                  data: _filteredAttendance.asMap().entries.map((entry) {
                    final index = entry.key + 1;
                    final record = entry.value;
                    return [
                      index.toString(),
                      record.fullname,
                      record.email,
                      record.department,
                      record.checkIn != null
                          ? DateFormat('HH:mm').format(
                              DateTime.parse(
                                '${record.date}T${record.checkIn}',
                              ),
                            )
                          : 'Pending',
                      record.checkOut != null
                          ? DateFormat('HH:mm').format(
                              DateTime.parse(
                                '${record.date}T${record.checkOut}',
                              ),
                            )
                          : 'Pending',
                      '${record.hours.hrs}h ${record.hours.mins}m ${record.hours.secs}s',
                    ];
                  }).toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellAlignment: pw.Alignment.centerLeft,
                  cellPadding: pw.EdgeInsets.all(4),
                ),
              ],
            );
          },
        ),
      );

      // Save and open PDF
      final output = await getTemporaryDirectory();
      final file = File(
        '${output.path}/attendance_report_${DateFormat('yyyyMMdd').format(_selectedDate ?? DateTime.now())}.pdf',
      );
      await file.writeAsBytes(await pdf.save());

      await OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error generating PDF: $e')));
      }
    }
  }
}
