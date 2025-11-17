import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../layouts/dashboard_layout.dart';

class HrMonthlyReportsScreen extends StatefulWidget {
  const HrMonthlyReportsScreen({super.key});

  @override
  State<HrMonthlyReportsScreen> createState() => _HrMonthlyReportsScreenState();
}

class _HrMonthlyReportsScreenState extends State<HrMonthlyReportsScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  TabController? _tabController;

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
    _initializeTabController();
    _fetchData();
  }

  void _initializeTabController() {
    _tabController?.dispose();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    try {
      // Fetch employees
      final employeesResponse = await _apiService.get('/accounts/employees/');
      debugPrint('Employees Response: $employeesResponse');
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
      debugPrint('Tasks Response: $tasksResponse');
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
      debugPrint('Attendance Response: $attendanceResponse');
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

      debugPrint(
        'Loaded ${_employees.length} employees, ${_tasks.length} tasks, ${_attendance.length} attendance records',
      );
    } catch (e) {
      debugPrint('Error fetching data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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

        // 3) minutes → convert
        if (att['total_minutes'] != null) {
          final mins = (att['total_minutes'] as num).toDouble();
          totalHours += mins / 60;
          debugPrint('  Attendance total_minutes: $mins');
          continue;
        }

        // 4) seconds → convert
        if (att['total_seconds'] != null) {
          final secs = (att['total_seconds'] as num).toDouble();
          totalHours += secs / 3600;
          debugPrint('  Attendance total_seconds: $secs');
          continue;
        }

        // 5) hours map → hrs + mins
        if (att['hours'] is Map) {
          final map = att['hours'] as Map<String, dynamic>;
          final h = ((map['hrs'] ?? 0) as num).toDouble();
          final m = ((map['mins'] ?? 0) as num).toDouble();
          totalHours += h + (m / 60);
          debugPrint('  Attendance hours map: hrs=$h mins=$m');
          continue;
        }

        // 6) Unknown format
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
            // 1 = Monday, 7 = Sunday
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
    return DashboardLayout(role: 'hr', child: _buildReportsContent());
  }

  Widget _buildModernHeader() {
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF667eea),
            const Color(0xFF764ba2),
            const Color(0xFF6B73FF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.analytics_outlined,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Monthly Reports',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_employees.length} employees • ${months[_selectedMonth]} $_selectedYear',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: IconButton(
                      onPressed: _fetchData,
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      tooltip: 'Refresh Data',
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: TabBar(
                controller: _tabController!,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                labelColor: const Color(0xFF667eea),
                unselectedLabelColor: Colors.white.withOpacity(0.8),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Team Reports'),
                  Tab(text: 'Analytics'),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
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
            'Team Performance Dashboard - HR View',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_employees.length} employees loaded • Human Resources monthly tracking',
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

  Widget _buildSimpleStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
              Icon(icon, color: Colors.grey.shade600, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filter Employees',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              hintText: 'Search employees...',
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
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          const SizedBox(height: 12),
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
            onChanged: (value) => setState(() => _selectedDept = value!),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeSection() {
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
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Employee List (${_filteredEmployees.length})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredEmployees.length,
            separatorBuilder: (context, index) =>
                Divider(color: Colors.grey.shade200, height: 1),
            itemBuilder: (context, index) {
              final employee = _filteredEmployees[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.grey.shade200,
                  child: Text(
                    (employee['fullname'] ?? employee['name'] ?? 'U')[0]
                        .toUpperCase(),
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
                title: Text(
                  employee['fullname'] ?? employee['name'] ?? 'Unknown',
                ),
                subtitle: Text(employee['department'] ?? 'No Department'),
                trailing: Text(employee['designation'] ?? 'Employee'),
              );
            },
          ),
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
            onChanged: (value) => setState(() => _searchQuery = value),
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
                onChanged: (value) => setState(() => _selectedDept = value!),
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
                onChanged: (value) => setState(() => _selectedMonth = value!),
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
            'Viewing data for ${months[_selectedMonth]} ${DateTime.now().year}',
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
        _employeeMetrics[(employee['email'] ?? '')
            .toString()
            .toLowerCase()
            .trim()] ??
        _employeeMetrics[(employee['email_id'] ?? '')
            .toString()
            .toLowerCase()
            .trim()] ??
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

    debugPrint(
      'CARD LOAD for ${employee['email'] ?? employee['email_id']} → metrics=$metrics',
    );
    final completedTasks = metrics['completedTasks'] as int;
    final pendingTasks = metrics['pendingTasks'] as int? ?? 0;
    final inProgressTasks = metrics['inProgressTasks'] as int? ?? 0;
    final totalTasks = metrics['totalTasks'] as int;
    final completionScore = metrics['completionScore'] as int;
    final totalHours = (metrics['totalHours'] as num).toDouble();
    final workingDays = metrics['workingDays'] as int;
    final sundaysWorked = metrics['sundaysWorked'] as int;
    final totalDaysWorked = metrics['totalDaysWorked'] as int;
    debugPrint(
      'TASK METRICS → email=$email completed=$completedTasks pending=$pendingTasks inProgress=$inProgressTasks total=$totalTasks score=$completionScore hours=$totalHours days=$totalDaysWorked workingDays=$workingDays sundays=$sundaysWorked',
    );

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
        .toLowerCase();
    final metrics = _employeeMetrics[email] ?? {};

    final completedTasks = metrics['completedTasks'] as int? ?? 0;
    final pendingTasks = metrics['pendingTasks'] as int? ?? 0;
    final inProgressTasks = metrics['inProgressTasks'] as int? ?? 0;
    final totalTasks = metrics['totalTasks'] as int? ?? 0;
    final completionScore = metrics['completionScore'] as int? ?? 0;
    final totalHours = (metrics['totalHours'] as num?)?.toDouble() ?? 0.0;
    final workingDays = metrics['workingDays'] as int? ?? 0;
    final sundaysWorked = metrics['sundaysWorked'] as int? ?? 0;
    final totalDaysWorked = metrics['totalDaysWorked'] as int? ?? 0;

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
