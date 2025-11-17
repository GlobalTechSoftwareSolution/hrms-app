import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../../layouts/dashboard_layout.dart';
import '../../services/api_service.dart';

class ManagerAttendanceScreen extends StatefulWidget {
  const ManagerAttendanceScreen({super.key});

  @override
  State<ManagerAttendanceScreen> createState() =>
      _ManagerAttendanceScreenState();
}

class _ManagerAttendanceScreenState extends State<ManagerAttendanceScreen> {
  final ApiService _apiService = ApiService();

  List<Map<String, dynamic>> _attendance = [];
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _holidays = [];
  List<Map<String, dynamic>> _absences = [];
  List<Map<String, dynamic>> _leaves = [];
  List<Map<String, dynamic>> _attendanceRequests = [];

  bool _isLoading = true;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDate;
  Map<int, String> _managerRemarks = {};

  @override
  void initState() {
    super.initState();
    _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _fetchAttendance(),
        _fetchEmployees(),
        _fetchHolidays(),
        _fetchAbsences(),
        _fetchLeaves(),
        _fetchAttendanceRequests(),
      ]);
    } catch (e) {
      _showError('Error loading data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchAttendance() async {
    try {
      final response = await _apiService.get('/accounts/list_attendance/');
      if (response['success']) {
        final data = response['data'];
        final attendanceList = List<Map<String, dynamic>>.from(
          data['attendance'] ?? [],
        );

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
    }
  }

  Future<void> _fetchEmployees() async {
    try {
      final response = await _apiService.get('/accounts/employees/');
      if (response['success']) {
        final data = response['data'];
        if (data is List) {
          _employees = List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data['employees'] is List) {
          _employees = List<Map<String, dynamic>>.from(data['employees'] ?? []);
        }
      }
    } catch (e) {
      debugPrint('Error fetching employees: $e');
    }
  }

  Future<void> _fetchHolidays() async {
    try {
      final response = await _apiService.get('/accounts/holidays/');
      if (response['success']) {
        final data = response['data'];
        _holidays = List<Map<String, dynamic>>.from(
          data is List ? data : (data['holidays'] ?? []),
        );
      }
    } catch (e) {
      debugPrint('Error fetching holidays: $e');
    }
  }

  Future<void> _fetchAbsences() async {
    try {
      final response = await _apiService.get('/accounts/list_absent/');
      if (response['success']) {
        final data = response['data'];
        _absences = List<Map<String, dynamic>>.from(
          data is List ? data : [],
        );
      }
    } catch (e) {
      debugPrint('Error fetching absences: $e');
    }
  }

  Future<void> _fetchLeaves() async {
    try {
      final response = await _apiService.get('/accounts/list_leaves/');
      if (response['success']) {
        final data = response['data'];
        _leaves = List<Map<String, dynamic>>.from(
          data['leaves'] ?? [],
        );
      }
    } catch (e) {
      debugPrint('Error fetching leaves: $e');
    }
  }

  Future<void> _fetchAttendanceRequests() async {
    try {
      final response =
          await _apiService.get('/accounts/attendance_requests/');
      if (response['success']) {
        final data = response['data'];
        _attendanceRequests = List<Map<String, dynamic>>.from(
          data is List ? data : [],
        );
      }
    } catch (e) {
      debugPrint('Error fetching attendance requests: $e');
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String _formatDateForDisplay(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('EEEE, MMMM d, yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String get _today {
    return _formatDate(DateTime.now());
  }

  List<Map<String, dynamic>> get _todaysAttendance {
    return _attendance.where((a) => a['date'] == _today).toList();
  }

  int get _checkedIn {
    return _todaysAttendance.where((a) => a['check_in'] != null).length;
  }

  int get _totalEmployees {
    return _employees.length;
  }

  int get _absent {
    return _totalEmployees - _checkedIn;
  }

  String get _totalHoursToday {
    final totalSeconds = _todaysAttendance.fold<int>(
      0,
      (sum, a) =>
          sum +
          ((a['hours']['hrs'] as int) * 3600 +
              (a['hours']['mins'] as int) * 60 +
              (a['hours']['secs'] as int)),
    );
    final hrs = totalSeconds ~/ 3600;
    final mins = (totalSeconds % 3600) ~/ 60;
    final secs = totalSeconds % 60;
    return '${hrs}h ${mins}m ${secs}s';
  }

  List<String> _expandLeaveDates(Map<String, dynamic> leave) {
    final dates = <String>[];
    try {
      final start = DateTime.parse(leave['start_date']);
      final end = DateTime.parse(leave['end_date']);
      var current = DateTime(start.year, start.month, start.day);

      while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
        dates.add(_formatDate(current));
        current = current.add(const Duration(days: 1));
      }
    } catch (e) {
      debugPrint('Error expanding leave dates: $e');
    }
    return dates;
  }

  List<Map<String, dynamic>> get _selectedDateAttendance {
    if (_selectedDate == null) return [];
    final dateStr = _formatDate(_selectedDate!);
    return _attendance.where((a) => a['date'] == dateStr).toList();
  }

  Map<String, dynamic>? get _selectedDateHoliday {
    if (_selectedDate == null) return null;
    final dateStr = _formatDate(_selectedDate!);
    return _holidays.firstWhere(
      (h) => h['date'] == dateStr,
      orElse: () => <String, dynamic>{},
    );
  }

  List<Map<String, dynamic>> get _selectedDateAbsences {
    if (_selectedDate == null) return [];
    final dateStr = _formatDate(_selectedDate!);
    return _absences.where((a) => a['date'] == dateStr).toList();
  }

  List<Map<String, dynamic>> get _selectedDateLeaves {
    if (_selectedDate == null) return [];
    final dateStr = _formatDate(_selectedDate!);
    return _leaves.where((l) {
      final leaveDates = _expandLeaveDates(l);
      return leaveDates.contains(dateStr);
    }).toList();
  }

  List<Map<String, dynamic>> get _selectedDateRequests {
    if (_selectedDate == null) return [];
    final dateStr = _formatDate(_selectedDate!);
    return _attendanceRequests.where((r) => r['date'] == dateStr).toList();
  }

  bool _isHoliday(DateTime date) {
    final dateStr = _formatDate(date);
    return _holidays.any((h) => h['date'] == dateStr);
  }

  Future<void> _handleApproveReject(int requestId, bool approved) async {
    final remark = _managerRemarks[requestId]?.trim() ?? '';
    if (remark.isEmpty) {
      _showError('Please enter a remark before submitting.');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final managerEmail = prefs.getString('user_email') ?? '';

      final response = await _apiService.patch(
        '/accounts/attendance_requests/$requestId/',
        {
          'approved': approved,
          'manager_remark': remark,
          'reviewer_email': managerEmail,
        },
      );

      if (response['success']) {
        _showSuccess(
          approved ? 'Request approved successfully!' : 'Request rejected.',
        );
        setState(() {
          _managerRemarks.remove(requestId);
        });
        await _fetchAttendanceRequests();
      } else {
        _showError(response['error'] ?? 'Failed to update request');
      }
    } catch (e) {
      _showError('Failed to update request. Please try again.');
    }
  }

  Future<void> _downloadPDF() async {
    try {
      final pdf = pw.Document();
      final todayStr = DateFormat('MMMM d, yyyy').format(DateTime.now());

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text(
                  "Today's Attendance Report",
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Date: $todayStr',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: [
                  'ID',
                  'Employee Name',
                  'Email',
                  'Department',
                  'Check-in',
                  'Check-out',
                  'Hours',
                ],
                data: _todaysAttendance.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final rec = entry.value;
                  return [
                    '${idx + 1}',
                    rec['fullname']?.toString() ?? 'Unknown',
                    rec['email']?.toString() ?? '-',
                    rec['department']?.toString() ?? '-',
                    rec['check_in'] != null
                        ? DateFormat('hh:mm a').format(
                            DateTime.parse('${rec['date']}T${rec['check_in']}'),
                          )
                        : 'Pending',
                    rec['check_out'] != null
                        ? DateFormat('hh:mm a').format(
                            DateTime.parse('${rec['date']}T${rec['check_out']}'),
                          )
                        : 'Pending',
                    '${rec['hours']['hrs']}h ${rec['hours']['mins']}m ${rec['hours']['secs']}s',
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 12,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFF2980B9),
                ),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellPadding: const pw.EdgeInsets.all(6),
                border: pw.TableBorder.all(),
              ),
            ];
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/Attendance-Report-$todayStr.pdf');
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        await OpenFilex.open(file.path);
        _showSuccess('PDF downloaded successfully!');
      }
    } catch (e) {
      _showError('Error generating PDF: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DashboardLayout(
      role: 'manager',
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  const Text(
                    'Manager Dashboard 📋',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // KPI Cards
                  _buildKPICards(),
                  const SizedBox(height: 24),

                  // Calendar Section
                  _buildCalendarSection(),
                  const SizedBox(height: 24),

                  // Today Attendance Header
                  _buildTodayAttendanceHeader(),
                  const SizedBox(height: 16),

                  // Today Attendance Cards
                  _buildTodayAttendanceCards(),
                  const SizedBox(height: 24),

                  // All Attendance Records
                  _buildAllAttendanceRecords(),
                ],
              ),
            ),
    );
  }

  Widget _buildKPICards() {
    final kpis = [
      {
        'title': 'Total Employees',
        'value': '$_totalEmployees',
        'color': Colors.blue,
      },
      {
        'title': 'Checked In',
        'value': '$_checkedIn',
        'color': Colors.green,
      },
      {
        'title': 'Absent',
        'value': '$_absent',
        'color': Colors.red,
      },
      {
        'title': 'Total Hours',
        'value': _totalHoursToday,
        'color': Colors.purple,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: kpis.length,
      itemBuilder: (context, index) {
        final kpi = kpis[index];
        final color = kpi['color'] as Color;
        final color1 = color is MaterialColor ? color.shade400 : color;
        final color2 = color is MaterialColor ? color.shade600 : color;
        
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color1, color2],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                kpi['title'] as String,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                kpi['value'] as String,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCalendarSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📅 Attendance Calendar',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                // Use column layout on small screens, row on larger screens
                final isSmallScreen = constraints.maxWidth < 800;
                
                if (isSmallScreen) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Calendar
                      TableCalendar(
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: DateTime.utc(2030, 12, 31),
                        focusedDay: _focusedDay,
                        selectedDayPredicate: (day) =>
                            _selectedDate != null &&
                            isSameDay(_selectedDate, day),
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            _selectedDate = selectedDay;
                            _focusedDay = focusedDay;
                          });
                        },
                        onPageChanged: (focusedDay) {
                          setState(() => _focusedDay = focusedDay);
                        },
                        calendarStyle: CalendarStyle(
                          selectedDecoration: BoxDecoration(
                            color: Colors.blue.shade500,
                            shape: BoxShape.circle,
                          ),
                          todayDecoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.blue.shade300,
                              width: 2,
                            ),
                          ),
                          holidayTextStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          outsideDaysVisible: false,
                        ),
                        calendarBuilders: CalendarBuilders(
                          defaultBuilder: (context, date, _) {
                            if (_isHoliday(date)) {
                              return Container(
                                margin: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade600,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${date.day}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            }
                            return null;
                          },
                        ),
                      ),
                      if (_selectedDate != null) ...[
                        const SizedBox(height: 16),
                        _buildSelectedDateDetails(),
                      ],
                    ],
                  );
                } else {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Calendar
                      Expanded(
                        flex: 2,
                        child: TableCalendar(
                          firstDay: DateTime.utc(2020, 1, 1),
                          lastDay: DateTime.utc(2030, 12, 31),
                          focusedDay: _focusedDay,
                          selectedDayPredicate: (day) =>
                              _selectedDate != null &&
                              isSameDay(_selectedDate, day),
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _selectedDate = selectedDay;
                              _focusedDay = focusedDay;
                            });
                          },
                          onPageChanged: (focusedDay) {
                            setState(() => _focusedDay = focusedDay);
                          },
                          calendarStyle: CalendarStyle(
                            selectedDecoration: BoxDecoration(
                              color: Colors.blue.shade500,
                              shape: BoxShape.circle,
                            ),
                            todayDecoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.blue.shade300,
                                width: 2,
                              ),
                            ),
                            holidayTextStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            outsideDaysVisible: false,
                          ),
                          calendarBuilders: CalendarBuilders(
                            defaultBuilder: (context, date, _) {
                              if (_isHoliday(date)) {
                                return Container(
                                  margin: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade600,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${date.day}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Selected Date Details
                      if (_selectedDate != null)
                        Expanded(
                          flex: 3,
                          child: _buildSelectedDateDetails(),
                        ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedDateDetails() {
    final holiday = _selectedDateHoliday;
    final leaves = _selectedDateLeaves;
    final absences = _selectedDateAbsences;
    final requests = _selectedDateRequests;
    final attendance = _selectedDateAttendance;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 600),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
          Text(
            _formatDateForDisplay(_formatDate(_selectedDate!)),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          // Holiday Info
          if (holiday != null && holiday.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange.shade400, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('🎉', style: TextStyle(fontSize: 24)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          holiday['name'] ?? 'Holiday',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (holiday['description'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      holiday['description'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Public Holiday',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Leaves
          if (leaves.isNotEmpty) ...[
            Text(
              '📋 Approved Leaves',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 8),
            ...leaves.map((leave) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    border: Border.all(color: Colors.green.shade400, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        leave['email'] ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Type: ${(leave['leave_type'] ?? '').toString().replaceAll('_', ' ').toUpperCase()}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade700,
                        ),
                      ),
                      Text(
                        'Duration: ${leave['start_date']} to ${leave['end_date']}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade700,
                        ),
                      ),
                      Text(
                        'Reason: ${leave['reason'] ?? ''}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 16),
          ],

          // Absences & Requests
          if (absences.isNotEmpty || requests.isNotEmpty) ...[
            Text(
              '⚠️ Absences & Requests',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade700,
              ),
            ),
            const SizedBox(height: 8),
            ...absences.map((absence) {
              final matchingRequest = requests.firstWhere(
                (r) => r['email'] == absence['email'],
                orElse: () => <String, dynamic>{},
              );

              return _buildAbsenceCard(absence, matchingRequest);
            }),
            // Requests without matching absences
            ...requests.where((req) {
              return !absences.any((abs) => abs['email'] == req['email']);
            }).map((request) => _buildRequestCard(request)),
            const SizedBox(height: 16),
          ],

          // Attendance Records
          Text(
            '✅ Attendance Records',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          if (attendance.isEmpty)
            Text(
              'No attendance records for this date.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.2,
              ),
              itemCount: attendance.length,
              itemBuilder: (context, index) {
                final rec = attendance[index];
                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rec['fullname'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rec['email'] ?? '',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: rec['check_in'] != null
                                  ? Colors.green.shade100
                                  : Colors.red.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'In: ${rec['check_in'] != null ? DateFormat('hh:mm a').format(DateTime.parse('${rec['date']}T${rec['check_in']}')) : 'N/A'}',
                              style: TextStyle(
                                fontSize: 9,
                                color: rec['check_in'] != null
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: rec['check_out'] != null
                                  ? Colors.green.shade100
                                  : Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Out: ${rec['check_out'] != null ? DateFormat('hh:mm a').format(DateTime.parse('${rec['date']}T${rec['check_out']}')) : 'N/A'}',
                              style: TextStyle(
                                fontSize: 9,
                                color: rec['check_out'] != null
                                    ? Colors.green.shade700
                                    : Colors.orange.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hours: ${rec['hours']['hrs']}h ${rec['hours']['mins']}m',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAbsenceCard(
    Map<String, dynamic> absence,
    Map<String, dynamic> request,
  ) {
    final hasRequest = request.isNotEmpty;
    final status = hasRequest ? request['status'] : null;

    Color bgColor;
    Color borderColor;
    if (hasRequest) {
      if (status == 'Pending') {
        bgColor = Colors.yellow.shade50;
        borderColor = Colors.yellow.shade400;
      } else if (status == 'Approved') {
        bgColor = Colors.green.shade50;
        borderColor = Colors.green.shade400;
      } else {
        bgColor = Colors.red.shade50;
        borderColor = Colors.red.shade400;
      }
    } else {
      bgColor = Colors.red.shade50;
      borderColor = Colors.red.shade400;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
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
                      absence['fullname'] ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      absence['email'] ?? '',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      'Department: ${absence['department'] ?? 'N/A'}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasRequest)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: status == 'Pending'
                        ? Colors.yellow.shade200
                        : status == 'Approved'
                            ? Colors.green.shade200
                            : Colors.red.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status ?? '',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: status == 'Pending'
                          ? Colors.yellow.shade800
                          : status == 'Approved'
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                    ),
                  ),
                ),
            ],
          ),
          if (hasRequest) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📝 Request Reason:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '"${request['reason'] ?? ''}"',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Submitted: ${DateFormat('MMM d, yyyy hh:mm a').format(DateTime.parse(request['created_at']))}',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            if (request['manager_remark'] != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Manager Remark: ${request['manager_remark']}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue.shade800,
                  ),
                ),
              ),
            ],
            if (status == 'Pending') ...[
              const SizedBox(height: 12),
              TextField(
                controller: TextEditingController(
                  text: _managerRemarks[request['id']] ?? '',
                ),
                onChanged: (value) {
                  setState(() {
                    _managerRemarks[request['id']] = value;
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Manager Remark',
                  hintText:
                      'Enter your remark (e.g., Validated with team; allow office presence.)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_managerRemarks[request['id']]?.trim() ?? '')
                              .isEmpty
                          ? null
                          : () => _handleApproveReject(request['id'], true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('✓ Approve'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_managerRemarks[request['id']]?.trim() ?? '')
                              .isEmpty
                          ? null
                          : () => _handleApproveReject(request['id'], false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('✗ Reject'),
                    ),
                  ),
                ],
              ),
            ],
          ] else ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '⚠️ No attendance request submitted',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.red.shade700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final status = request['status'];
    Color bgColor;
    Color borderColor;
    if (status == 'Pending') {
      bgColor = Colors.yellow.shade50;
      borderColor = Colors.yellow.shade400;
    } else if (status == 'Approved') {
      bgColor = Colors.green.shade50;
      borderColor = Colors.green.shade400;
    } else {
      bgColor = Colors.red.shade50;
      borderColor = Colors.red.shade400;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                request['email'] ?? '',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: status == 'Pending'
                      ? Colors.yellow.shade200
                      : status == 'Approved'
                          ? Colors.green.shade200
                          : Colors.red.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status ?? '',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: status == 'Pending'
                        ? Colors.yellow.shade800
                        : status == 'Approved'
                            ? Colors.green.shade800
                            : Colors.red.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📝 Request Reason:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '"${request['reason'] ?? ''}"',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Submitted: ${DateFormat('MMM d, yyyy hh:mm a').format(DateTime.parse(request['created_at']))}',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          if (request['manager_remark'] != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Manager Remark: ${request['manager_remark']}',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.blue.shade800,
                ),
              ),
            ),
          ],
          if (status == 'Pending') ...[
            const SizedBox(height: 12),
            TextField(
              controller: TextEditingController(
                text: _managerRemarks[request['id']] ?? '',
              ),
              onChanged: (value) {
                setState(() {
                  _managerRemarks[request['id']] = value;
                });
              },
              decoration: InputDecoration(
                labelText: 'Manager Remark',
                hintText:
                    'Enter your remark (e.g., Validated with team; allow office presence.)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_managerRemarks[request['id']]?.trim() ?? '')
                            .isEmpty
                        ? null
                        : () => _handleApproveReject(request['id'], true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('✓ Approve'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_managerRemarks[request['id']]?.trim() ?? '')
                            .isEmpty
                        ? null
                        : () => _handleApproveReject(request['id'], false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('✗ Reject'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTodayAttendanceHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Today Attendance',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              _formatDateForDisplay(_today),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: _downloadPDF,
          icon: const Icon(Icons.download),
          label: const Text('Download PDF'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade600,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildTodayAttendanceCards() {
    if (_todaysAttendance.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              "No attendance records for today's employees.",
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: _todaysAttendance.length,
      itemBuilder: (context, index) {
        final rec = _todaysAttendance[index];
        final hours = rec['hours'];
        final totalHours = hours['hrs'] + (hours['mins'] / 60) + (hours['secs'] / 3600);
        final progress = (totalHours / 8).clamp(0.0, 1.0);

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  rec['fullname'] ?? 'Unknown',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  rec['email'] ?? '',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Check-in / Check-out',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: rec['check_in'] != null
                            ? Colors.green.shade100
                            : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        rec['check_in'] != null
                            ? DateFormat('hh:mm a').format(
                                DateTime.parse('${rec['date']}T${rec['check_in']}'),
                              )
                            : 'Pending',
                        style: TextStyle(
                          fontSize: 11,
                          color: rec['check_in'] != null
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: rec['check_out'] != null
                            ? Colors.green.shade100
                            : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        rec['check_out'] != null
                            ? DateFormat('hh:mm a').format(
                                DateTime.parse('${rec['date']}T${rec['check_out']}'),
                              )
                            : 'Pending',
                        style: TextStyle(
                          fontSize: 11,
                          color: rec['check_out'] != null
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Worked Hours',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade500),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    '${hours['hrs']}h ${hours['mins']}m ${hours['secs']}s',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAllAttendanceRecords() {
    final attendanceByDate = <String, List<Map<String, dynamic>>>{};
    for (final rec in _attendance) {
      final date = rec['date'] as String;
      attendanceByDate.putIfAbsent(date, () => []).add(rec);
    }

    final sortedDates = attendanceByDate.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    if (sortedDates.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No attendance records available.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '📊 All Attendance Records',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        ...sortedDates.map((date) {
          final records = attendanceByDate[date]!;
          final totalSeconds = records.fold<int>(
            0,
            (sum, r) =>
                sum +
                ((r['hours']['hrs'] as int) * 3600 +
                    (r['hours']['mins'] as int) * 60 +
                    (r['hours']['secs'] as int)),
          );
          final avgSeconds = totalSeconds ~/ records.length;
          final avgHours = avgSeconds ~/ 3600;
          final avgMins = (avgSeconds % 3600) ~/ 60;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
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
                              _formatDateForDisplay(date),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${records.length} employee${records.length != 1 ? 's' : ''} • Avg: ${avgHours}h ${avgMins}m',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedDate = DateTime.parse(date);
                            _focusedDay = _selectedDate!;
                          });
                          // Scroll to top
                          Scrollable.ensureVisible(
                            context,
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: const Text('View on Calendar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.3,
                    ),
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      final rec = records[index];
                      return Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rec['fullname'] ?? 'Unknown',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              rec['department'] ?? '',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 4,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: rec['check_in'] != null
                                        ? Colors.green.shade100
                                        : Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    rec['check_in'] != null
                                        ? DateFormat('hh:mm a').format(
                                            DateTime.parse(
                                              '${rec['date']}T${rec['check_in']}',
                                            ),
                                          )
                                        : 'No In',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: rec['check_in'] != null
                                          ? Colors.green.shade700
                                          : Colors.red.shade700,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: rec['check_out'] != null
                                        ? Colors.green.shade100
                                        : Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    rec['check_out'] != null
                                        ? DateFormat('hh:mm a').format(
                                            DateTime.parse(
                                              '${rec['date']}T${rec['check_out']}',
                                            ),
                                          )
                                        : 'No Out',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: rec['check_out'] != null
                                          ? Colors.green.shade700
                                          : Colors.orange.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: LinearProgressIndicator(
                                      value: ((rec['hours']['hrs'] +
                                                  rec['hours']['mins'] / 60) /
                                              8)
                                          .clamp(0.0, 1.0),
                                      backgroundColor: Colors.grey.shade200,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                        Colors.blue.shade500,
                                      ),
                                      minHeight: 4,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${rec['hours']['hrs']}h ${rec['hours']['mins']}m',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

