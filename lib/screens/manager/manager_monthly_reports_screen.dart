import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../layouts/dashboard_layout.dart';

class ManagerMonthlyReportsScreen extends StatefulWidget {
  const ManagerMonthlyReportsScreen({super.key});

  @override
  State<ManagerMonthlyReportsScreen> createState() =>
      _ManagerMonthlyReportsScreenState();
}

class _DayAttendance {
  final int day;
  final double hours;
  final bool absent;
  final bool isSunday;
  final bool present;

  _DayAttendance({
    required this.day,
    required this.hours,
    required this.absent,
    required this.isSunday,
    required this.present,
  });
}

class _ManagerMonthlyReportsScreenState
    extends State<ManagerMonthlyReportsScreen> {
  final ApiService _apiService = ApiService();

  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _attendance = [];
  bool _isLoading = true;
  int _selectedMonth = DateTime.now().month - 1;
  int _selectedYear = DateTime.now().year;
  String _selectedDept = 'All Departments';
  String _searchQuery = '';

  // Employee metrics cache
  Map<String, Map<String, dynamic>> _employeeMetrics = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    try {
      // Fetch employees
      final employeesResponse = await _apiService.get('/accounts/employees/');
      if (employeesResponse['success'] == true) {
        final data = employeesResponse['data'];
        if (data is List) {
          _employees = data.whereType<Map<String, dynamic>>().toList();
        } else if (data is Map && data['employees'] is List) {
          _employees = (data['employees'] as List)
              .whereType<Map<String, dynamic>>()
              .toList();
        }
      }

      // Fetch tasks
      final tasksResponse = await _apiService.get('/accounts/list_tasks/');
      if (tasksResponse['success'] == true) {
        final tasksData = tasksResponse['data'];
        if (tasksData is List) {
          _tasks = tasksData.whereType<Map<String, dynamic>>().toList();
        } else if (tasksData is Map && tasksData['tasks'] is List) {
          _tasks = (tasksData['tasks'] as List)
              .whereType<Map<String, dynamic>>()
              .toList();
        }
      }

      // Fetch attendance
      final attendanceResponse = await _apiService.get(
        '/accounts/list_attendance/',
      );
      if (attendanceResponse['success'] == true) {
        final attendanceData = attendanceResponse['data'];
        if (attendanceData is List) {
          _attendance = attendanceData
              .whereType<Map<String, dynamic>>()
              .toList();
        } else if (attendanceData is Map &&
            attendanceData['attendance'] is List) {
          _attendance = (attendanceData['attendance'] as List)
              .whereType<Map<String, dynamic>>()
              .toList();
        }
      }

      // Compute employee metrics
      _computeEmployeeMetrics();
    } catch (e) {
      debugPrint('Error fetching data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  double _computeDayHours(Map<String, dynamic> att) {
    if (att['total_hours'] is num) {
      return (att['total_hours'] as num).toDouble();
    }
    if (att['total_minutes'] is num) {
      return (att['total_minutes'] as num).toDouble() / 60.0;
    }
    if (att['total_seconds'] is num) {
      return (att['total_seconds'] as num).toDouble() / 3600.0;
    }

    final checkInRaw = att['check_in']?.toString();
    final checkOutRaw = att['check_out']?.toString();
    if (checkInRaw != null && checkOutRaw != null &&
        checkInRaw.isNotEmpty && checkOutRaw.isNotEmpty) {
      try {
        final checkInTime = checkInRaw.split('.').first;
        final checkOutTime = checkOutRaw.split('.').first;
        final inParts = checkInTime.split(':').map(int.parse).toList();
        final outParts = checkOutTime.split(':').map(int.parse).toList();
        if (inParts.length >= 2 && outParts.length >= 2) {
          final inMinutes = inParts[0] * 60 + inParts[1];
          final outMinutes = outParts[0] * 60 + outParts[1];
          double diffMinutes = (outMinutes - inMinutes).toDouble();
          if (diffMinutes < 0) diffMinutes += 24 * 60;
          final h = diffMinutes / 60.0;
          if (h >= 0.5 && h <= 16) return h;
        }
      } catch (_) {}
    }
    return 0;
  }

  List<_DayAttendance> _buildDayAttendanceForDialog(
    List<Map<String, dynamic>> employeeAttendance,
    String email,
  ) {
    final attendanceMap = <String, Map<String, dynamic>>{};
    for (final rec in employeeAttendance) {
      final dateStr = rec['date']?.toString();
      if (dateStr == null || dateStr.isEmpty) continue;
      try {
        final d = DateTime.parse(dateStr.replaceFirst(' ', 'T'));
        final key =
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        attendanceMap[key] = rec;
      } catch (_) {}
    }

    final result = <_DayAttendance>[];
    final daysInMonth = DateTime(_selectedYear, _selectedMonth + 2, 0).day;

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_selectedYear, _selectedMonth + 1, day);
      final key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
      final rec = attendanceMap[key];
      final isSunday = date.weekday == DateTime.sunday;
      final hours = rec != null ? _computeDayHours(rec) : 0.0;

      result.add(
        _DayAttendance(
          day: day,
          hours: hours,
          absent: false, // hook absences here later
          isSunday: isSunday,
          present: rec != null,
        ),
      );
    }

    return result;
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
      final dateStr = att['date'] ?? att['attendance_date'];
      if (dateStr == null) return false;
      try {
        String d2 = dateStr.toString().replaceFirst(' ', 'T');
        final date = DateTime.parse(d2);
        return date.month == (_selectedMonth + 1) && date.year == _selectedYear;
      } catch (_) {
        return false;
      }
    }).toList();

    for (final employee in _employees) {
      final email = (employee['email_id'] ?? employee['email'] ?? '')
          .toString()
          .toLowerCase()
          .trim();

      // Filter tasks for this employee
      final employeeTasks = filteredTasks.where((t) {
        final taskEmail = (t['email'] ?? t['email_id'] ?? '')
            .toString()
            .toLowerCase()
            .trim();
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

      // Calculate completion score
      int completionScore = 0;
      if (totalTasks > 0) {
        completionScore = ((completedTasks / totalTasks) * 100).round();
        int pendingPenalty = (pendingTasks * 5).clamp(0, 20);
        completionScore = (completionScore - pendingPenalty).clamp(0, 100);
      }

      // Calculate total hours for the entire month
      double totalHours = 0;

      for (final att in employeeAttendance) {
        // 1) Prefer explicit total_hours/total_* fields if present
        if (att['total_hours'] is num) {
          totalHours += (att['total_hours'] as num).toDouble();
          continue;
        }

        if (att['total_hours'] is String) {
          final parsed = double.tryParse(att['total_hours']);
          if (parsed != null) {
            totalHours += parsed;
            continue;
          }
        }

        // Other common hour fields from API (worked_hours / hours)
        if (att['worked_hours'] is num) {
          totalHours += (att['worked_hours'] as num).toDouble();
          continue;
        }
        if (att['worked_hours'] is String) {
          final parsed = double.tryParse(att['worked_hours']);
          if (parsed != null) {
            totalHours += parsed;
            continue;
          }
        }
        if (att['hours'] is num) {
          totalHours += (att['hours'] as num).toDouble();
          continue;
        }
        if (att['hours'] is String) {
          final parsed = double.tryParse(att['hours']);
          if (parsed != null) {
            totalHours += parsed;
            continue;
          }
        }

        if (att['total_minutes'] != null) {
          final mins = (att['total_minutes'] as num).toDouble();
          totalHours += mins / 60;
          continue;
        }

        if (att['total_seconds'] != null) {
          final secs = (att['total_seconds'] as num).toDouble();
          totalHours += secs / 3600;
          continue;
        }

        if (att['hours'] is Map) {
          final map = att['hours'] as Map<String, dynamic>;
          final h = ((map['hrs'] ?? 0) as num).toDouble();
          final m = ((map['mins'] ?? 0) as num).toDouble();
          totalHours += h + (m / 60);
          continue;
        }

        // 2) Fallback: derive hours from check_in/check_out like web dashboard
        final checkInRaw = (att['check_in'] ?? att['checkIn'])?.toString();
        final checkOutRaw = (att['check_out'] ?? att['checkOut'])?.toString();
        if (checkInRaw != null && checkOutRaw != null &&
            checkInRaw.isNotEmpty && checkOutRaw.isNotEmpty) {
          try {
            // Strip fractional seconds if present (HH:MM:SS.mmm -> HH:MM:SS)
            final checkInTime = checkInRaw.split('.').first;
            final checkOutTime = checkOutRaw.split('.').first;
            final inParts = checkInTime.split(':').map(int.parse).toList();
            final outParts = checkOutTime.split(':').map(int.parse).toList();
            if (inParts.length >= 2 && outParts.length >= 2) {
              final inMinutes = inParts[0] * 60 + inParts[1] + (inParts.length > 2 ? inParts[2] / 60.0 : 0);
              final outMinutes = outParts[0] * 60 + outParts[1] + (outParts.length > 2 ? outParts[2] / 60.0 : 0);
              double diffMinutes = (outMinutes - inMinutes).toDouble();
              // handle overnight
              if (diffMinutes < 0) diffMinutes += 24 * 60;
              final diffHours = diffMinutes / 60.0;
              if (diffHours >= 0.5 && diffHours <= 16) {
                totalHours += diffHours;
              }
            }
          } catch (_) {
            // ignore bad formats
          }
        }
      }

      // Count working days (excluding Sundays)
      int workingDays = 0;
      for (final att in employeeAttendance) {
        final date = att['date'] ?? att['attendance_date'];
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
        final date = att['date'] ?? att['attendance_date'];
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
    }
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

  @override
  Widget build(BuildContext context) {
    return DashboardLayout(role: 'manager', child: _buildReportsContent());
  }

  Widget _buildReportsContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'Team Performance Dashboard',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_employees.length} employees loaded • Team attendance and task tracking',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),

          // Filters and Search
          _buildAdvancedFilters(),

          const SizedBox(height: 16),

          // Selected Period Display
          _buildPeriodDisplay(),

          const SizedBox(height: 20),

          // Employee Cards Grid
          _buildEmployeeCardsGrid(),
        ],
      ),
    );
  }

  Widget _buildAdvancedFilters() {
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        children: [
          // Search Bar
          TextField(
            decoration: InputDecoration(
              hintText:
                  'Search employees by name, position, department, or email...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              isDense: true,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 12),

          // Filters Column
          Column(
            children: [
              // Department Filter
              DropdownButtonFormField<String>(
                value: _selectedDept,
                decoration: InputDecoration(
                  labelText: 'Department',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  isDense: true,
                ),
                items: _departments
                    .map(
                      (dept) => DropdownMenuItem(
                        value: dept,
                        child: Text(dept, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedDept = value!;
                  });
                },
              ),
              const SizedBox(height: 12),

              // Month Selector
              DropdownButtonFormField<int>(
                value: _selectedMonth,
                decoration: InputDecoration(
                  labelText: 'Month',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  isDense: true,
                ),
                items: List.generate(
                  12,
                  (index) => DropdownMenuItem(
                    value: index,
                    child: Text(months[index]),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _selectedMonth = value!;
                    _computeEmployeeMetrics();
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodDisplay() {
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200, width: 1),
      ),
      child: Column(
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
          const SizedBox(height: 4),
          Text(
            '${_filteredEmployees.length} employees found${_selectedDept != 'All Departments' ? ' in $_selectedDept' : ''}${_searchQuery.isNotEmpty ? ' matching "$_searchQuery"' : ''}',
            style: TextStyle(fontSize: 14, color: Colors.blue.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeCardsGrid() {
    if (_filteredEmployees.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200, width: 1),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No employees found',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
              Text(
                _searchQuery.isNotEmpty
                    ? 'No employees match "$_searchQuery" in $_selectedDept'
                    : 'No employees in $_selectedDept',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredEmployees.length,
      itemBuilder: (context, index) {
        final employee = _filteredEmployees[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildEmployeePerformanceCard(employee),
        );
      },
    );
  }

  Widget _buildEmployeePerformanceCard(Map<String, dynamic> employee) {
    final email = (employee['email'] ?? employee['email_id'] ?? '')
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
    Color textColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
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
    final email = (employee['email'] ?? employee['email_id'] ?? '')
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

    // Build rich data for this employee (tasks + attendance for selected month/year)
    final List<Map<String, dynamic>> employeeTasks = _tasks.where((task) {
      final taskEmail = (task['email'] ?? task['email_id'] ?? '')
          .toString()
          .toLowerCase()
          .trim();
      if (taskEmail != email) return false;
      final dateStr = task['created_at'] ?? task['date'];
      if (dateStr == null) return false;
      try {
        final d = DateTime.parse(dateStr.toString().replaceFirst(' ', 'T'));
        return d.month == (_selectedMonth + 1) && d.year == _selectedYear;
      } catch (_) {
        return false;
      }
    }).toList()
      ..sort((a, b) {
        final da = DateTime.tryParse((a['created_at'] ?? a['date'] ?? '').toString().replaceFirst(' ', 'T'))?.millisecondsSinceEpoch ?? 0;
        final db = DateTime.tryParse((b['created_at'] ?? b['date'] ?? '').toString().replaceFirst(' ', 'T'))?.millisecondsSinceEpoch ?? 0;
        return db.compareTo(da);
      });

    final List<Map<String, dynamic>> employeeAttendance = _attendance.where((att) {
      final attEmail = (att['email'] ?? att['email_id'] ?? '')
          .toString()
          .toLowerCase()
          .trim();
      if (attEmail != email) return false;
      final dateStr = att['date'];
      if (dateStr == null) return false;
      try {
        final d = DateTime.parse(dateStr.toString().replaceFirst(' ', 'T'));
        return d.month == (_selectedMonth + 1) && d.year == _selectedYear;
      } catch (_) {
        return false;
      }
    }).toList()
      ..sort((a, b) {
        final da = DateTime.tryParse((a['date'] ?? '').toString().replaceFirst(' ', 'T'))?.millisecondsSinceEpoch ?? 0;
        final db = DateTime.tryParse((b['date'] ?? '').toString().replaceFirst(' ', 'T'))?.millisecondsSinceEpoch ?? 0;
        return da.compareTo(db);
      });

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Employee Performance Report',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Employee Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
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
              const SizedBox(height: 16),

              // Performance Metrics
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Performance Metrics',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Metrics Grid
                      GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 2,
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
                      const SizedBox(height: 20),

                      const Text(
                        'Task Breakdown',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Task Status Breakdown
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
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
                      ),

                      const SizedBox(height: 20),

                      // Recent Tasks
                      const Text(
                        'Recent Tasks (this period)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (employeeTasks.isEmpty)
                        Text(
                          'No tasks found for this employee in the selected month.',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        )
                      else
                        Column(
                          children: employeeTasks.take(5).map((task) {
                            final title = (task['name'] ?? task['title'] ?? task['task_name'] ?? 'Task ${task['id']}').toString();
                            final status = (task['status'] ?? '').toString();
                            final rawDate = (task['completed_at'] ?? task['completed_date'] ?? task['date'] ?? task['created_at'])
                                ?.toString();
                            String dateLabel = '';
                            if (rawDate != null && rawDate.isNotEmpty) {
                              try {
                                final d = DateTime.parse(rawDate.replaceFirst(' ', 'T'));
                                dateLabel = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
                              } catch (_) {}
                            }
                            Color statusColor = Colors.grey.shade600;
                            final s = status.toLowerCase();
                            if (s == 'completed') statusColor = Colors.green.shade600;
                            else if (s == 'in_progress') statusColor = Colors.orange.shade600;
                            else if (s == 'pending') statusColor = Colors.red.shade600;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Text(
                                              'Status: ',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            Text(
                                              status.isEmpty ? 'Unknown' : status,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: statusColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (dateLabel.isNotEmpty)
                                    Text(
                                      dateLabel,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),

                      const SizedBox(height: 20),

                      // Attendance list
                      const Text(
                        'Attendance (this period)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // No chart – show just the detailed list for now
                      if (employeeAttendance.isEmpty)
                        Text(
                          'No attendance records found for this employee in the selected month.',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        )
                      else
                        Column(
                          children: employeeAttendance.map((att) {
                            final rawDate = att['date']?.toString();
                            String dateLabel = rawDate ?? '';
                            if (rawDate != null && rawDate.isNotEmpty) {
                              try {
                                final d = DateTime.parse(rawDate.replaceFirst(' ', 'T'));
                                dateLabel = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
                              } catch (_) {}
                            }

                            // best-effort total hours display
                            double dayHours = 0;
                            if (att['total_hours'] is num) {
                              dayHours = (att['total_hours'] as num).toDouble();
                            } else if (att['total_hours'] is String) {
                              dayHours = double.tryParse(att['total_hours']) ?? 0;
                            } else if (att['worked_hours'] is num) {
                              dayHours = (att['worked_hours'] as num).toDouble();
                            } else if (att['worked_hours'] is String) {
                              dayHours = double.tryParse(att['worked_hours']) ?? 0;
                            } else if (att['hours'] is num) {
                              dayHours = (att['hours'] as num).toDouble();
                            } else if (att['hours'] is String) {
                              dayHours = double.tryParse(att['hours']) ?? 0;
                            } else if (att['total_minutes'] is num) {
                              dayHours = (att['total_minutes'] as num).toDouble() / 60.0;
                            } else if (att['total_seconds'] is num) {
                              dayHours = (att['total_seconds'] as num).toDouble() / 3600.0;
                            } else {
                              // final fallback from check_in/check_out
                              dayHours = _computeDayHours(att);
                            }

                            final checkIn = att['check_in']?.toString() ?? '';
                            final checkOut = att['check_out']?.toString() ?? '';

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
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          dateLabel,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'In: ${formatTime(checkIn)}  •  Out: ${formatTime(checkOut)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${dayHours.toStringAsFixed(1)}h',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ),

              // Close Button
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Close Report',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceBarsForDialog(
    List<Map<String, dynamic>> employeeAttendance,
    String email,
  ) {
    final dayData = _buildDayAttendanceForDialog(employeeAttendance, email);
    if (dayData.isEmpty) return const SizedBox.shrink();

    final maxHours =
        dayData.fold<double>(0, (m, d) => d.hours > m ? d.hours : m);
    final safeMax = maxHours > 0 ? maxHours : 8.0;

    return SizedBox(
      height: 180,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final d in dayData)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          height: (d.hours / safeMax) * 150,
                          decoration: BoxDecoration(
                            color: _attendanceBarColor(d),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      d.day.toString(),
                      style: const TextStyle(
                        fontSize: 8,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _attendanceBarColor(_DayAttendance d) {
    if (d.absent) return Colors.red.shade600;
    if (d.isSunday && d.present) return Colors.orange.shade600;
    if (d.isSunday && !d.present) return Colors.orange.shade200;
    if (d.present) return Colors.blue.shade600;
    return Colors.grey.shade300;
  }

  // Legacy stub to satisfy any reflection-based lookups expecting this method.
  // The real chart is rendered by _buildAttendanceBarsForDialog.
  Widget _buildAttendanceBars(List<Map<String, dynamic>> _) {
    return const SizedBox.shrink();
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
}

