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
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    try {
      final response = await _apiService.get('/accounts/list_attendance/');
      if (response['success']) {
        final data = response['data'];
        final attendanceList = List<Map<String, dynamic>>.from(
          data['attendance'] ?? [],
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
      final response = await _apiService.get('/accounts/employees/');
      if (response['success']) {
        _employees = List<Map<String, dynamic>>.from(response['data'] ?? []);

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

        setState(() => _totalEmployees = activeEmployees.length);
      }
    } catch (e) {
      debugPrint('Error fetching employees: $e');
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

  List<Map<String, dynamic>> get _dateAttendance {
    final effectiveDate = _selectedDate ?? DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(effectiveDate);

    // Get attendance records for the date
    final attendanceForDate = _attendance
        .where((a) => a['date'] == dateStr)
        .toList();

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
              _buildAttendanceList(),
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
                              tooltipBgColor: Colors.grey.shade800,
                              tooltipRoundedRadius: 8,
                              tooltipPadding: const EdgeInsets.all(8),
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

  Widget _buildAttendanceList() {
    final filteredAttendance = _filteredDateAttendance;

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
                  '${_selectedDate != null ? _formatDate(_selectedDate.toString()) : 'Today\'s'} Attendance',
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
          else if (filteredAttendance.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No attendance records found',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredAttendance.length,
              itemBuilder: (context, index) {
                final record = filteredAttendance[index];
                return _buildAttendanceCard(record);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(Map<String, dynamic> record) {
    final hours = record['hours'] as Map<String, int>;
    final isPresent = record['check_in'] != null;

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
            if (isPresent) ...[
              const SizedBox(height: 12),
              Divider(height: 1, color: Colors.grey.shade200),
              const SizedBox(height: 12),

              // Bottom Row - Time Details
              Row(
                children: [
                  Expanded(
                    child: _buildTimeInfo(
                      'Check In',
                      record['check_in'] != null
                          ? DateFormat('HH:mm').format(
                              DateTime.parse(
                                '${record['date']}T${record['check_in']}',
                              ),
                            )
                          : '-',
                      Icons.login,
                      Colors.blue,
                    ),
                  ),
                  Container(width: 1, height: 40, color: Colors.grey.shade200),
                  Expanded(
                    child: _buildTimeInfo(
                      'Check Out',
                      record['check_out'] != null
                          ? DateFormat('HH:mm').format(
                              DateTime.parse(
                                '${record['date']}T${record['check_out']}',
                              ),
                            )
                          : 'Pending',
                      Icons.logout,
                      record['check_out'] != null ? Colors.orange : Colors.grey,
                    ),
                  ),
                  Container(width: 1, height: 40, color: Colors.grey.shade200),
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
}
