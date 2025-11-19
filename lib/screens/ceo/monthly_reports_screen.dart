import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/api_service.dart';
import '../../layouts/dashboard_layout.dart';

class MonthlyReportsScreen extends StatefulWidget {
  const MonthlyReportsScreen({super.key});

  @override
  State<MonthlyReportsScreen> createState() => _MonthlyReportsScreenState();
}

class _MonthlyReportsScreenState extends State<MonthlyReportsScreen> {
  final ApiService _apiService = ApiService();

  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _attendance = [];
  bool _isLoading = true;
  int _selectedMonth = DateTime.now().month - 1;
  int _selectedYear = DateTime.now().year;
  String _selectedDept = 'All Departments';
  String _searchQuery = '';

  Map<String, Map<String, dynamic>> _employeeMetrics = {};

  // GPS related state
  bool _isGpsOn = false;

  List<String> get months => [
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

  List<int> get _years {
    final currentYear = DateTime.now().year;
    return List.generate(6, (i) => currentYear - 3 + i);
  }

  List<String> get _departments {
    final departments = _employees
        .map((e) => e['department']?.toString() ?? 'General')
        .toSet()
        .toList();
    departments.sort();
    return ['All Departments', ...departments];
  }

  List<Map<String, dynamic>> get _filteredEmployees {
    return _employees.where((employee) {
      final matchesDept =
          _selectedDept == 'All Departments' ||
          employee['department'] == _selectedDept;
      final matchesSearch =
          _searchQuery.isEmpty ||
          (employee['fullname'] ?? employee['name'] ?? '')
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          (employee['email_id'] ?? employee['email'] ?? '')
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          (employee['designation'] ?? employee['role'] ?? '')
              .toLowerCase()
              .contains(_searchQuery.toLowerCase());
      return matchesDept && matchesSearch;
    }).toList();
  }

  Future<bool> checkLocationReady() async {
    // Check permission
    var permission = await Permission.location.status;

    if (permission.isDenied || permission.isRestricted) {
      permission = await Permission.location.request();
      if (!permission.isGranted) {
        return false; // user refused
      }
    }

    // Check if GPS is ON
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false; // GPS off
    }

    return true;
  }

  Future<void> _checkGPS() async {
    bool ready = await checkLocationReady();
    setState(() {
      _isGpsOn = ready;
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchData();
    _checkGPS();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      // Fetch employees
      final employeesResponse = await _apiService.get('/accounts/employees/');
      if (employeesResponse['success'] == true) {
        final data = employeesResponse['data'];
        if (data is List) {
          _employees = List<Map<String, dynamic>>.from(data);
        } else if (data is Map &&
            data['employees'] != null &&
            data['employees'] is List) {
          _employees = List<Map<String, dynamic>>.from(data['employees']);
        }
      }

      // Fetch tasks
      final tasksResponse = await _apiService.get('/accounts/list_tasks/');
      if (tasksResponse['success'] == true) {
        final data = tasksResponse['data'];
        if (data is List) {
          _tasks = List<Map<String, dynamic>>.from(data);
        } else if (data is Map &&
            data['tasks'] != null &&
            data['tasks'] is List) {
          _tasks = List<Map<String, dynamic>>.from(data['tasks']);
        }
      }

      // Fetch attendance for selected month/year only
      final monthNames = [
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
      final monthName = monthNames[_selectedMonth];

      final attendanceResponse = await _apiService.get(
        '/accounts/list_attendance/?month=$monthName&year=${_selectedYear}',
      );
      if (attendanceResponse['success'] == true) {
        final data = attendanceResponse['data'];
        if (data is List) {
          _attendance = List<Map<String, dynamic>>.from(data);
        } else if (data is Map &&
            data['attendance'] != null &&
            data['attendance'] is List) {
          _attendance = List<Map<String, dynamic>>.from(data['attendance']);
        }
      }

      _computeEmployeeMetrics();
    } catch (e) {
      debugPrint('Error fetching data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _computeEmployeeMetrics() {
    _employeeMetrics.clear();

    // Filter data for the selected month and year
    final filteredTasks = _tasks.where((task) {
      final dateStr = task['created_at'] ?? task['date'];
      if (dateStr == null) return false;
      try {
        String d = dateStr.toString().replaceFirst(' ', 'T');
        final date = DateTime.parse(d);
        return date.month == (_selectedMonth + 1) && date.year == _selectedYear;
      } catch (_) {
        return false;
      }
    }).toList();

    final filteredAttendance = _attendance.where((att) {
      final dateStr = att['date'];
      if (dateStr == null) return false;
      try {
        String d2 = dateStr.toString().replaceFirst(' ', 'T');
        final date = DateTime.parse(d2);
        return date.month == (_selectedMonth + 1) && date.year == _selectedYear;
      } catch (_) {
        return false;
      }
    }).toList();

    debugPrint('Computing metrics for ${_employees.length} employees');
    debugPrint('Total tasks: ${_tasks.length}');
    debugPrint('Total attendance records: ${_attendance.length}');

    for (final employee in _employees) {
      final email = (employee['email_id'] ?? employee['email'] ?? '')
          .toString()
          .toLowerCase()
          .trim();
      debugPrint('Processing employee: $email');

      // Filter tasks for this employee
      final employeeTasks = filteredTasks.where((t) {
        final taskEmail = (t['email'] ?? t['email_id'] ?? '')
            .toString()
            .toLowerCase()
            .trim();
        debugPrint('Matching task email=${taskEmail}, employee email=$email');
        return taskEmail == email;
      }).toList();

      // Filter attendance for this employee
      final employeeAttendance = filteredAttendance.where((a) {
        final attEmail = (a['email'] ?? a['email_id'] ?? '')
            .toString()
            .toLowerCase()
            .trim();
        return attEmail == email;
      }).toList();

      debugPrint(
        'Employee ${email} → FilteredTasks=${filteredTasks.length}, FilteredAttendance=${filteredAttendance.length}',
      );
      debugPrint(
        '  Tasks: ${employeeTasks.length}, Attendance: ${employeeAttendance.length}',
      );

      // Calculate task metrics
      final completedTasks = employeeTasks
          .where(
            (t) => (t['status'] ?? '').toString().toLowerCase() == 'completed',
          )
          .length;
      final pendingTasks = employeeTasks
          .where(
            (t) => (t['status'] ?? '').toString().toLowerCase() == 'pending',
          )
          .length;
      final inProgressTasks = employeeTasks
          .where(
            (t) =>
                (t['status'] ?? '').toString().toLowerCase() == 'in_progress',
          )
          .length;
      final totalTasks = employeeTasks.length;

      // Calculate completion score with logic:
      // If no tasks given → score = 0
      // If tasks given and not completed → penalty
      // If tasks given and completed → bonus
      int completionScore = 0;
      if (totalTasks > 0) {
        // Score based on completion percentage
        completionScore = ((completedTasks / totalTasks) * 100).round();

        // Apply penalty for pending tasks (max -20 points)
        int pendingPenalty = (pendingTasks * 5).clamp(0, 20);
        completionScore = (completionScore - pendingPenalty).clamp(0, 100);
      } else {
        completionScore = 0;
      }

      // Calculate total hours for the entire month
      double totalHours = 0;

      for (final att in employeeAttendance) {
        // 1) total_hours as number
        if (att['total_hours'] is num) {
          totalHours += (att['total_hours'] as num).toDouble();
          debugPrint('  Attendance total_hours(num): ${att['total_hours']}');
          continue;
        }

        // 2) total_hours as string
        if (att['total_hours'] is String) {
          final parsed = double.tryParse(att['total_hours']);
          if (parsed != null) {
            totalHours += parsed;
            debugPrint('  Attendance total_hours(string): $parsed');
            continue;
          }
        }

        // 3) worked_hours, hours, total_minutes, total_seconds
        if (att['worked_hours'] is num) {
          totalHours += (att['worked_hours'] as num).toDouble();
          debugPrint('  Attendance worked_hours(num): ${att['worked_hours']}');
          continue;
        }
        if (att['worked_hours'] is String) {
          final parsed = double.tryParse(att['worked_hours']);
          if (parsed != null) {
            totalHours += parsed;
            debugPrint('  Attendance worked_hours(string): $parsed');
            continue;
          }
        }
        if (att['hours'] is num) {
          totalHours += (att['hours'] as num).toDouble();
          debugPrint('  Attendance hours(num): ${att['hours']}');
          continue;
        }
        if (att['hours'] is String) {
          final parsed = double.tryParse(att['hours']);
          if (parsed != null) {
            totalHours += parsed;
            debugPrint('  Attendance hours(string): $parsed');
            continue;
          }
        }

        if (att['total_minutes'] != null) {
          final mins = (att['total_minutes'] as num).toDouble();
          totalHours += mins / 60;
          debugPrint('  Attendance total_minutes: $mins');
          continue;
        }

        if (att['total_seconds'] != null) {
          final secs = (att['total_seconds'] as num).toDouble();
          totalHours += secs / 3600;
          debugPrint('  Attendance total_seconds: $secs');
          continue;
        }

        if (att['hours'] is Map) {
          final map = att['hours'] as Map<String, dynamic>;
          final h = ((map['hrs'] ?? 0) as num).toDouble();
          final m = ((map['mins'] ?? 0) as num).toDouble();
          totalHours += h + (m / 60);
          debugPrint('  Attendance hours map: hrs=$h mins=$m');
          continue;
        }

        // Fallback: derive hours from check_in/check_out
        final checkInRaw = att['check_in']?.toString();
        final checkOutRaw = att['check_out']?.toString();
        if (checkInRaw != null &&
            checkOutRaw != null &&
            checkInRaw.isNotEmpty &&
            checkOutRaw.isNotEmpty) {
          try {
            // Handle formats like "10:09:19", "10:09:19.558605", "09:47:46.961135"
            final checkInTime = checkInRaw
                .split('.')
                .first; // Remove milliseconds
            final checkOutTime = checkOutRaw
                .split('.')
                .first; // Remove milliseconds

            final inParts = checkInTime.split(':').map(int.parse).toList();
            final outParts = checkOutTime.split(':').map(int.parse).toList();

            if (inParts.length >= 2 && outParts.length >= 2) {
              final inMinutes = inParts[0] * 60 + inParts[1];
              final outMinutes = outParts[0] * 60 + outParts[1];

              double diffMinutes = (outMinutes - inMinutes).toDouble();
              if (diffMinutes < 0) diffMinutes += 24 * 60; // handle overnight

              final diffHours = diffMinutes / 60.0;

              // Only accept reasonable work hours (0.5 to 16 hours)
              if (diffHours >= 0.5 && diffHours <= 16) {
                totalHours += diffHours;
                debugPrint(
                  '  ✓ Attendance hours from check_in/out: $diffHours',
                );
              } else {
                debugPrint(
                  '  ⚠ Invalid work hours: $diffHours (check_in: $checkInTime, check_out: $checkOutTime)',
                );
              }
            } else {
              debugPrint(
                '  ⚠ Malformed time format - in: $checkInRaw, out: $checkOutRaw',
              );
            }
          } catch (e) {
            debugPrint('  ⚠ ERROR parsing check_in/out times: $e');
            debugPrint('  Raw in: $checkInRaw, out: $checkOutRaw');
          }
        } else {
          debugPrint(
            '  ⚠ Missing check_in/check_out times in attendance record',
          );
        }

        // If no method worked, log the unknown format
        debugPrint('⚠️ UNKNOWN ATTENDANCE FORMAT: $att');
      }
      debugPrint('  Total hours for month: $totalHours');

      // Count working days (excluding Sundays)
      int workingDays = 0;
      for (final att in employeeAttendance) {
        final date = att['date'];
        if (date != null) {
          try {
            String d2 = date.toString().replaceFirst(' ', 'T');
            final dateTime = DateTime.parse(d2);
            if (dateTime.weekday != 7) {
              workingDays++;
            }
          } catch (e) {
            debugPrint('Error parsing date: $e');
          }
        }
      }

      // Count Sundays worked
      int sundaysWorked = 0;
      for (final att in employeeAttendance) {
        final date = att['date'];
        if (date != null) {
          try {
            String d3 = date.toString().replaceFirst(' ', 'T');
            final dateTime = DateTime.parse(d3);
            if (dateTime.weekday == 7) {
              sundaysWorked++;
            }
          } catch (e) {
            debugPrint('Error parsing date: $e');
          }
        }
      }

      _employeeMetrics[email] = {
        'completedTasks': completedTasks,
        'pendingTasks': pendingTasks,
        'inProgressTasks': inProgressTasks,
        'totalTasks': totalTasks,
        'completionScore': completionScore,
        'totalHours': totalHours,
        'workingDays': workingDays,
        'sundaysWorked': sundaysWorked,
        'totalDaysWorked': workingDays + sundaysWorked,
      };

      debugPrint(
        '  Metrics: Tasks=$completedTasks/$totalTasks (pending=$pendingTasks, inProgress=$inProgressTasks), Score=$completionScore%, Hours=$totalHours, WorkDays=$workingDays, Sundays=$sundaysWorked',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DashboardLayout(role: 'ceo', child: _buildContent());
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Check GPS status first
    if (!_isGpsOn) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              "GPS is turned OFF",
              style: TextStyle(
                fontSize: 18,
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Location services are required to view employee reports",
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                await Geolocator.openLocationSettings();
                // Re-check GPS after returning from settings
                await Future.delayed(const Duration(seconds: 1));
                _checkGPS();
              },
              icon: const Icon(Icons.settings),
              label: const Text("Enable GPS"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: _checkGPS, child: const Text("Check Again")),
          ],
        ),
      );
    }

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

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Team Performance Dashboard',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_employees.length} employees loaded • attendance and task tracking',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _fetchData,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Filters (Responsive Layout)
            LayoutBuilder(
              builder: (context, constraints) {
                final isWideScreen = constraints.maxWidth >= 768;
                return isWideScreen
                    ? _buildFiltersRow()
                    : _buildFiltersColumn();
              },
            ),
            const SizedBox(height: 20),

            // Period Display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: Colors.blue),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Viewing data for ${months[_selectedMonth]} $_selectedYear',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      Text(
                        '${_filteredEmployees.length} employees found${_selectedDept != 'All Departments' ? ' in $_selectedDept' : ''}${_searchQuery.isNotEmpty ? ' matching "$_searchQuery"' : ''}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Employee Cards List
            Expanded(
              child: _filteredEmployees.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            'No employees found',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No employees match "$_searchQuery" in $_selectedDept'
                                : 'No employees in $_selectedDept',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredEmployees.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildEmployeeCard(_filteredEmployees[index]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeCard(Map<String, dynamic> employee) {
    final email = (employee['email_id'] ?? employee['email'] ?? '')
        .toString()
        .toLowerCase();
    final metrics =
        _employeeMetrics[email] ??
        {
          'completedTasks': 0,
          'pendingTasks': 0,
          'inProgressTasks': 0,
          'totalTasks': 0,
          'completionScore': 0,
          'totalHours': 0,
          'workingDays': 0,
          'sundaysWorked': 0,
          'totalDaysWorked': 0,
        };

    final completedTasks = metrics['completedTasks'] as int;
    final pendingTasks = metrics['pendingTasks'] as int? ?? 0;
    final inProgressTasks = metrics['inProgressTasks'] as int? ?? 0;
    final totalTasks = metrics['totalTasks'] as int;
    final completionScore = metrics['completionScore'] as int;
    final totalHours = (metrics['totalHours'] as num).toDouble();
    final totalDaysWorked = metrics['totalDaysWorked'] as int;

    return GestureDetector(
      onTap: () => _showEmployeeReport(employee),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Employee Info
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.blue.shade100,
                    backgroundImage:
                        (employee['profile_picture'] != null &&
                            employee['profile_picture'].toString().isNotEmpty)
                        ? NetworkImage(employee['profile_picture'])
                        : null,
                    child:
                        (employee['profile_picture'] == null ||
                            employee['profile_picture'].toString().isEmpty)
                        ? Text(
                            (employee['fullname'] ?? employee['name'] ?? 'U')[0]
                                .toUpperCase(),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade700,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          employee['fullname'] ?? employee['name'] ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          employee['designation'] ?? 'Employee',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          employee['department'] ?? 'No Department',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Quick Stats Row
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildQuickStat(
                      'Tasks',
                      '$completedTasks/$totalTasks',
                      Colors.blue.shade50,
                      Colors.blue.shade600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildQuickStat(
                      'Hours',
                      '${totalHours.toStringAsFixed(1)}h',
                      Colors.green.shade50,
                      Colors.green.shade600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildQuickStat(
                      'Score',
                      '$completionScore%',
                      Colors.purple.shade50,
                      Colors.purple.shade600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildQuickStat(
                      'Days',
                      '$totalDaysWorked',
                      Colors.orange.shade50,
                      Colors.orange.shade600,
                    ),
                  ),
                ],
              ),

              // Task Status Breakdown
              if (totalTasks > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildTaskStatus(
                        'Completed',
                        completedTasks,
                        Colors.green,
                      ),
                      _buildTaskStatus(
                        'In Progress',
                        inProgressTasks,
                        Colors.orange,
                      ),
                      _buildTaskStatus('Pending', pendingTasks, Colors.red),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStat(
    String label,
    String value,
    Color bgColor,
    Color textColor, [
    double? width,
    double? height,
  ]) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTaskStatus(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  void _showEmployeeReport(Map<String, dynamic> employee) {
    final email = (employee['email_id'] ?? employee['email'] ?? '')
        .toString()
        .toLowerCase()
        .trim();

    final metrics = _employeeMetrics[email] ?? {};
    final completedTasks = metrics['completedTasks'] as int? ?? 0;
    final pendingTasks = metrics['pendingTasks'] as int? ?? 0;
    final inProgressTasks = metrics['inProgressTasks'] as int? ?? 0;
    final totalTasks = metrics['totalTasks'] as int? ?? 0;
    final completionScore = metrics['completionScore'] as int? ?? 0;
    final totalHours = (metrics['totalHours'] as num?)?.toDouble() ?? 0.0;
    final totalDaysWorked = metrics['totalDaysWorked'] as int? ?? 0;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                      begin: Alignment.topLeft,
                      end: Alignment.topRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Employee Performance Report',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Employee Info
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: Colors.blue.shade100,
                                backgroundImage:
                                    (employee['profile_picture'] != null &&
                                        employee['profile_picture']
                                            .toString()
                                            .isNotEmpty)
                                    ? NetworkImage(employee['profile_picture'])
                                    : null,
                                child:
                                    (employee['profile_picture'] == null ||
                                        employee['profile_picture']
                                            .toString()
                                            .isEmpty)
                                    ? Text(
                                        (employee['fullname'] ??
                                                employee['name'] ??
                                                'U')[0]
                                            .toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.blue.shade700,
                                        ),
                                      )
                                    : null,
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
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      employee['designation'] ?? 'Employee',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    Text(
                                      employee['department'] ?? 'No Department',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Metrics Grid
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: GridView.count(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.5,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _buildMetricCard(
                                'Tasks Completed',
                                '$completedTasks/$totalTasks',
                                Colors.green,
                              ),
                              _buildMetricCard(
                                'Completion Score',
                                '$completionScore%',
                                Colors.purple,
                              ),
                              _buildMetricCard(
                                'Total Hours',
                                '${totalHours.toStringAsFixed(1)}h',
                                Colors.blue,
                              ),
                              _buildMetricCard(
                                'Days Worked',
                                '$totalDaysWorked',
                                Colors.orange,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Task Breakdown
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Task Breakdown',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildTaskStatusDetail(
                                    'Completed',
                                    completedTasks,
                                    Colors.green,
                                  ),
                                  _buildTaskStatusDetail(
                                    'In Progress',
                                    inProgressTasks,
                                    Colors.orange,
                                  ),
                                  _buildTaskStatusDetail(
                                    'Pending',
                                    pendingTasks,
                                    Colors.red,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        const SizedBox(height: 20),

                        // Attendance Details Section
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Attendance Records (This Month)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Builder(
                                builder: (context) {
                                  // Filter attendance for this employee AND selected month/year
                                  final employeeAttendance =
                                      _attendance.where((att) {
                                        final attEmail =
                                            (att['email'] ??
                                                    att['email_id'] ??
                                                    '')
                                                .toString()
                                                .toLowerCase()
                                                .trim();
                                        if (attEmail != email) return false;

                                        final dateStr = att['date'];
                                        if (dateStr == null) return false;
                                        try {
                                          final d = DateTime.parse(
                                            dateStr.toString().replaceFirst(
                                              ' ',
                                              'T',
                                            ),
                                          );
                                          return d.month ==
                                                  (_selectedMonth + 1) &&
                                              d.year == _selectedYear;
                                        } catch (_) {
                                          return false;
                                        }
                                      }).toList()..sort((a, b) {
                                        // Sort by date descending
                                        final dateA =
                                            DateTime.tryParse(
                                              (a['date'] ?? '')
                                                  .toString()
                                                  .replaceFirst(' ', 'T'),
                                            )?.millisecondsSinceEpoch ??
                                            0;
                                        final dateB =
                                            DateTime.tryParse(
                                              (b['date'] ?? '')
                                                  .toString()
                                                  .replaceFirst(' ', 'T'),
                                            )?.millisecondsSinceEpoch ??
                                            0;
                                        return dateB.compareTo(dateA);
                                      });

                                  if (employeeAttendance.isEmpty) {
                                    return Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Text(
                                          'No attendance records found for this month',
                                          style: TextStyle(
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.calendar_view_month,
                                            color: Colors.blue,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${employeeAttendance.length} attendance records',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade700,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Column(
                                        children: employeeAttendance.map((att) {
                                          final rawDate = att['date']
                                              ?.toString();
                                          String dateLabel = rawDate ?? '';
                                          String dayOfWeek = '';
                                          if (rawDate != null &&
                                              rawDate.isNotEmpty) {
                                            try {
                                              final d = DateTime.parse(
                                                rawDate.replaceFirst(' ', 'T'),
                                              );
                                              dateLabel =
                                                  '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
                                              final weekdays = [
                                                'Mon',
                                                'Tue',
                                                'Wed',
                                                'Thu',
                                                'Fri',
                                                'Sat',
                                                'Sun',
                                              ];
                                              dayOfWeek =
                                                  weekdays[d.weekday - 1];
                                            } catch (_) {}
                                          }

                                          // Calculate day hours
                                          double dayHours = 0.0;
                                          final checkInRaw = att['check_in']
                                              ?.toString();
                                          final checkOutRaw = att['check_out']
                                              ?.toString();
                                          bool hasValidCheckInOut = false;

                                          if (checkInRaw != null &&
                                              checkOutRaw != null &&
                                              checkInRaw.isNotEmpty &&
                                              checkOutRaw.isNotEmpty) {
                                            try {
                                              final checkInTime = checkInRaw
                                                  .split('.')
                                                  .first;
                                              final checkOutTime = checkOutRaw
                                                  .split('.')
                                                  .first;
                                              final inParts = checkInTime
                                                  .split(':')
                                                  .map(int.parse)
                                                  .toList();
                                              final outParts = checkOutTime
                                                  .split(':')
                                                  .map(int.parse)
                                                  .toList();
                                              if (inParts.length >= 2 &&
                                                  outParts.length >= 2) {
                                                final inMinutes =
                                                    inParts[0] * 60 +
                                                    inParts[1];
                                                final outMinutes =
                                                    outParts[0] * 60 +
                                                    outParts[1];
                                                double diffMinutes =
                                                    (outMinutes - inMinutes)
                                                        .toDouble();
                                                if (diffMinutes < 0)
                                                  diffMinutes += 24 * 60;
                                                dayHours = diffMinutes / 60.0;
                                                // Only accept reasonable hours (0.5 to 16 hours)
                                                if (dayHours >= 0.5 &&
                                                    dayHours <= 16) {
                                                  hasValidCheckInOut = true;
                                                } else {
                                                  dayHours = 0.0;
                                                }
                                              }
                                            } catch (_) {}
                                          }

                                          final checkIn =
                                              att['check_in']?.toString() ?? '';
                                          final checkOut =
                                              att['check_out']?.toString() ??
                                              '';

                                          Color statusColor = hasValidCheckInOut
                                              ? Colors.green.shade700
                                              : Colors.grey.shade500;
                                          String hoursText = hasValidCheckInOut
                                              ? '${dayHours.toStringAsFixed(1)}h'
                                              : 'N/A';

                                          String formatTime(String t) {
                                            if (t.isEmpty) return 'N/A';
                                            final parts = t.split(':');
                                            if (parts.length < 2) return t;
                                            int h = int.tryParse(parts[0]) ?? 0;
                                            final m = parts[1];
                                            final ampm = h >= 12 ? 'PM' : 'AM';
                                            h = h % 12;
                                            if (h == 0) h = 12;
                                            return '$h:$m $ampm';
                                          }

                                          return Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.grey.shade200,
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      '$dateLabel ($dayOfWeek)',
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 4,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: statusColor
                                                            .withOpacity(0.1),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        hoursText,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: statusColor,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                SingleChildScrollView(
                                                  scrollDirection:
                                                      Axis.horizontal,
                                                  child: Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.access_time,
                                                        size: 16,
                                                        color: Colors.grey,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Check-in: ${formatTime(checkIn)}',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors
                                                              .grey
                                                              .shade600,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      const Icon(
                                                        Icons.exit_to_app,
                                                        size: 16,
                                                        color: Colors.grey,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Check-out: ${formatTime(checkOut)}',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors
                                                              .grey
                                                              .shade600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Footer
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF667eea),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Close Report',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTaskStatusDetail(String label, int count, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFiltersRow() {
    return SizedBox(
      height: 80,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 300),
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.4,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search employees...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Department Filter
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<String>(
                value: _selectedDept,
                decoration: InputDecoration(
                  labelText: 'Department',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                items: _departments
                    .map(
                      (dept) => DropdownMenuItem(
                        value: dept,
                        child: Text(dept, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _selectedDept = value!),
              ),
            ),
            const SizedBox(width: 12),
            // Month
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _selectedMonth,
                decoration: InputDecoration(
                  labelText: 'Month',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                items: List.generate(
                  12,
                  (index) => DropdownMenuItem(
                    value: index,
                    child: Text(months[index]),
                  ),
                ),
                onChanged: (value) {
                  setState(() => _selectedMonth = value!);
                  _fetchData(); // Refresh data when month changes
                },
              ),
            ),
            const SizedBox(width: 12),
            // Year
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _selectedYear,
                decoration: InputDecoration(
                  labelText: 'Year',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                items: _years
                    .map(
                      (year) =>
                          DropdownMenuItem(value: year, child: Text('$year')),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _selectedYear = value!),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersColumn() {
    return Column(
      children: [
        // Search full width
        TextField(
          decoration: InputDecoration(
            hintText: 'Search employees...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
        const SizedBox(height: 12),
        // Wrap for dropdowns
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                value: _selectedDept,
                decoration: InputDecoration(
                  labelText: 'Department',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                items: _departments
                    .map(
                      (dept) => DropdownMenuItem(
                        value: dept,
                        child: Text(dept, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _selectedDept = value!),
              ),
            ),
            // Month
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _selectedMonth,
                decoration: InputDecoration(
                  labelText: 'Month',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                items: List.generate(
                  12,
                  (index) => DropdownMenuItem(
                    value: index,
                    child: Text(months[index]),
                  ),
                ),
                onChanged: (value) {
                  setState(() => _selectedMonth = value!);
                  _fetchData(); // Refresh data when month changes
                },
              ),
            ),
            // Year
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _selectedYear,
                decoration: InputDecoration(
                  labelText: 'Year',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                items: _years
                    .map(
                      (year) =>
                          DropdownMenuItem(value: year, child: Text('$year')),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _selectedYear = value!),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
