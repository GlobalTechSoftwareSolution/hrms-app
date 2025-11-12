import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../services/api_service.dart';
import 'face_scan_attendance_screen.dart';

class EmployeeAttendanceScreen extends StatefulWidget {
  const EmployeeAttendanceScreen({super.key});

  @override
  State<EmployeeAttendanceScreen> createState() =>
      _EmployeeAttendanceScreenState();
}

class _EmployeeAttendanceScreenState extends State<EmployeeAttendanceScreen> {
  final ApiService _apiService = ApiService();

  List<Map<String, dynamic>> _attendanceRecords = [];
  List<Map<String, dynamic>> _absences = [];
  List<Map<String, dynamic>> _leaves = [];

  bool _isLoading = true;
  String _userEmail = '';
  DateTime _focusedDay = DateTime.now();
  DateTime _currentViewMonth = DateTime.now();
  DateTime _selectedMonth = DateTime.now();
  DateTime? _selectedDay;

  int _totalPresent = 0;
  int _thisMonthPresent = 0;
  int _approvedLeaves = 0;
  int _totalAbsences = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _userEmail = prefs.getString('user_email') ?? '';

      await Future.wait([_fetchAttendance(), _fetchAbsences(), _fetchLeaves()]);

      _calculateStats();
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAttendance() async {
    try {
      final response = await _apiService.get(
        '/accounts/get_attendance/${Uri.encodeComponent(_userEmail)}/',
      );
      if (response['success']) {
        final attendance = (response['data']['attendance'] as List? ?? [])
            .map(
              (a) => {
                'email': a['email'],
                'fullname': a['fullname'],
                'department': a['department'],
                'role': a['role'],
                'date': a['date'],
                'check_in': a['check_in'],
                'check_out': a['check_out'],
              },
            )
            .toList();
        setState(
          () =>
              _attendanceRecords = List<Map<String, dynamic>>.from(attendance),
        );
        print('Fetched ${_attendanceRecords.length} attendance records');
      }
    } catch (e) {
      print('Error fetching attendance: $e');
    }
  }

  Future<void> _fetchAbsences() async {
    try {
      final response = await _apiService.get(
        '/accounts/get_absent/${Uri.encodeComponent(_userEmail)}/',
      );
      if (response['success']) {
        final absences = (response['data'] as List? ?? [])
            .where((a) => a['email'] == _userEmail)
            .toList();
        setState(() => _absences = List<Map<String, dynamic>>.from(absences));
      }
    } catch (e) {
      print('Error fetching absences: $e');
    }
  }

  Future<void> _fetchLeaves() async {
    try {
      final response = await _apiService.get('/accounts/list_leaves/');
      if (response['success']) {
        final leaves = (response['data']['leaves'] as List? ?? [])
            .where((l) => (l['email'] ?? l['employee_email']) == _userEmail)
            .toList();
        setState(() => _leaves = List<Map<String, dynamic>>.from(leaves));
      }
    } catch (e) {
      print('Error fetching leaves: $e');
    }
  }

  // Get filtered attendance records for the selected month
  List<Map<String, dynamic>> _getFilteredAttendanceRecords() {
    return _attendanceRecords.where((record) {
      final date = DateTime.parse(record['date']);
      return date.month == _selectedMonth.month && 
             date.year == _selectedMonth.year;
    }).toList();
  }

  // Get filtered leaves for the selected month
  List<Map<String, dynamic>> _getFilteredLeaves() {
    return _leaves.where((leave) {
      final startDate = DateTime.parse(leave['start_date'] ?? leave['date']);
      final endDate = DateTime.parse(leave['end_date'] ?? leave['date']);
      
      // Check if the leave period overlaps with the selected month
      final firstDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final lastDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
      
      return (startDate.isBefore(lastDayOfMonth.add(const Duration(days: 1))) &&
              endDate.isAfter(firstDayOfMonth.subtract(const Duration(days: 1))));
    }).toList();
  }

  // Get filtered absences for the selected month
  List<Map<String, dynamic>> _getFilteredAbsences() {
    return _absences.where((absence) {
      final date = DateTime.parse(absence['date']);
      return date.month == _selectedMonth.month && 
             date.year == _selectedMonth.year;
    }).toList();
  }

  // Show month/year picker dialog
  Future<void> _selectMonth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 240,
                child: YearPicker(
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                  selectedDate: _selectedMonth,
                  onChanged: (DateTime dateTime) {
                    Navigator.pop(context);
                    setState(() {
                      _selectedMonth = dateTime;
                      _currentViewMonth = dateTime;
                      _calculateStats();
                    });
                  },
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL'),
              ),
            ],
          ),
        );
      },
    );

    if (picked != null && picked != _selectedMonth) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month, 1);
        _currentViewMonth = _selectedMonth;
        _calculateStats();
      });
    }
  }

  void _calculateStats() {
    _totalPresent = _attendanceRecords
        .where(
          (r) =>
              r['check_in'] != null &&
              r['check_in'] != '-' &&
              r['check_out'] != null &&
              r['check_out'] != '-',
        )
        .length;

    // Calculate for currently viewed month
    _thisMonthPresent = _getFilteredAttendanceRecords().where((r) {
      return r['check_in'] != null &&
          r['check_in'] != '-' &&
          r['check_out'] != null &&
          r['check_out'] != '-';
    }).length;

    _approvedLeaves = _getFilteredLeaves()
        .where((l) => (l['status'] ?? '').toString().toLowerCase() == 'approved')
        .length;

    _totalAbsences = _getFilteredAbsences().length;
  }

  Future<void> _markAttendance() async {
    try {
      if (_userEmail.isEmpty) {
        _showMessage('⚠️ No user email found. Please log in again.');
        return;
      }

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Text('Marking attendance...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      // Fetch employee info to get profile picture
      Map<String, dynamic>? empData;
      try {
        final empResponse = await _apiService.get(
          '/accounts/employees/${Uri.encodeComponent(_userEmail)}/',
        );
        if (empResponse['success']) {
          empData = empResponse['data'];
        }
      } catch (e) {
        print('Could not fetch employee info: $e');
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).clearSnackBars();
          _showMessage(
            '❌ Location permission denied. Please enable GPS in settings.',
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).clearSnackBars();
        _showMessage(
          '❌ Location permission permanently denied. Please enable in app settings.',
        );
        return;
      }

      // Get current position with high accuracy
      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
        print('GPS Location: ${position.latitude}, ${position.longitude}');
      } catch (e) {
        ScaffoldMessenger.of(context).clearSnackBars();
        _showMessage('⚠️ Please enable GPS and allow location access!');
        print('GPS Error: $e');
        return;
      }

      // Create multipart request
      final uri = Uri.parse(
        '${ApiService.baseUrl}/accounts/office_attendance/',
      );
      final request = http.MultipartRequest('POST', uri);

      // Add form fields
      request.fields['email'] = _userEmail;
      request.fields['latitude'] = position.latitude.toString();
      request.fields['longitude'] = position.longitude.toString();

      print('Sending attendance request for: $_userEmail');
      print('Coordinates: ${position.latitude}, ${position.longitude}');

      // Attach profile image if available
      if (empData != null && empData['profile_picture'] != null) {
        final profilePicUrl = empData['profile_picture'].toString();
        if (profilePicUrl.isNotEmpty &&
            (profilePicUrl.startsWith('http://') ||
                profilePicUrl.startsWith('https://'))) {
          try {
            print('Fetching profile picture from: $profilePicUrl');
            final imgResponse = await http.get(Uri.parse(profilePicUrl));
            if (imgResponse.statusCode == 200) {
              request.files.add(
                http.MultipartFile.fromBytes(
                  'image',
                  imgResponse.bodyBytes,
                  filename: 'profile.jpeg',
                ),
              );
              print('Profile picture attached successfully');
            } else {
              print(
                'Failed to fetch profile picture: ${imgResponse.statusCode}',
              );
            }
          } catch (e) {
            print('Could not attach profile picture: $e');
          }
        }
      } else {
        print('No profile picture available');
      }

      // Send the request
      print('Sending request to: $uri');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      ScaffoldMessenger.of(context).clearSnackBars();

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showMessage('✅ Attendance marked successfully!');
        await _loadData();
      } else {
        _showMessage('❌ Failed to mark attendance: ${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).clearSnackBars();
      print('Error marking attendance: $e');
      _showMessage('❌ Something went wrong: ${e.toString()}');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Color _getCalendarColor(DateTime day) {
    final dateStr = DateFormat('yyyy-MM-dd').format(day);

    // Check if Sunday
    if (day.weekday == DateTime.sunday) {
      return Colors.red.shade100;
    }

    // Check leaves
    final hasLeave = _leaves.any((l) {
      if ((l['status'] ?? '').toString().toLowerCase() != 'approved')
        return false;
      final startDate = DateTime.parse(l['start_date'] ?? l['date']);
      final endDate = DateTime.parse(l['end_date'] ?? l['date']);
      return day.isAfter(startDate.subtract(const Duration(days: 1))) &&
          day.isBefore(endDate.add(const Duration(days: 1)));
    });
    if (hasLeave) return Colors.blue.shade100;

    // Check absences
    if (_absences.any((a) => a['date'] == dateStr)) {
      return Colors.orange.shade100;
    }

    // Check attendance
    final record = _attendanceRecords.firstWhere(
      (r) => r['date'] == dateStr,
      orElse: () => {},
    );

    if (record.isNotEmpty) {
      final hasIn = record['check_in'] != null && record['check_in'] != '-';
      final hasOut = record['check_out'] != null && record['check_out'] != '-';

      if (hasIn && hasOut) return Colors.green.shade100;
      if (hasIn) return Colors.yellow.shade100;
    }

    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Employee Attendance Portal',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Track and manage your attendance records',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),

            _buildFaceScanButton(),
            const SizedBox(height: 24),

            _buildStatsCards(),
            const SizedBox(height: 24),

            _buildMonthNavigation(),
            const SizedBox(height: 16),

            _buildCalendar(),
            const SizedBox(height: 16),

            if (_selectedDay != null) ...[
              _buildSelectedDateDetails(),
              const SizedBox(height: 16),
            ],

            _buildMarkAttendanceButton(),
            const SizedBox(height: 24),

            if (_absences.isNotEmpty) ...[
              _buildAbsencesSection(),
              const SizedBox(height: 24),
            ],

            _buildAttendanceRecords(),
          ],
        ),
      ),
    );
  }

  Widget _buildFaceScanButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade600, Colors.blue.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showAttendanceTypeDialog,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.face, size: 32, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Face Recognition Attendance',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mark attendance using face scan',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAttendanceTypeDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Attendance Type',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              _buildAttendanceTypeCard(
                title: 'Office Attendance',
                description:
                    'Mark attendance at your company office using face recognition and location',
                gradient: LinearGradient(
                  colors: [Colors.purple.shade600, Colors.blue.shade500],
                ),
                icon: Icons.business,
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FaceScanAttendanceScreen(
                        attendanceType: 'office',
                      ),
                    ),
                  );
                  if (result == true) {
                    _loadData(); // Reload attendance data
                  }
                },
              ),
              const SizedBox(height: 16),
              _buildAttendanceTypeCard(
                title: 'Workplace Attendance',
                description:
                    'Mark attendance when working remotely, in the field, or at a client location',
                gradient: LinearGradient(
                  colors: [Colors.green.shade500, Colors.teal.shade400],
                ),
                icon: Icons.home_work,
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FaceScanAttendanceScreen(
                        attendanceType: 'work',
                      ),
                    ),
                  );
                  if (result == true) {
                    _loadData(); // Reload attendance data
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceTypeCard({
    required String title,
    required String description,
    required Gradient gradient,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Total Present',
          _totalPresent.toString(),
          '✓',
          Colors.green,
        ),
        _buildStatCard(
          'This Month',
          _thisMonthPresent.toString(),
          '📅',
          Colors.blue,
        ),
        _buildStatCard(
          'Approved Leaves',
          _approvedLeaves.toString(),
          '🌴',
          Colors.purple,
        ),
        _buildStatCard(
          'Absences',
          _totalAbsences.toString(),
          '⚠️',
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, String emoji, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
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
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 20)),
              ),
            ],
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthNavigation() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            final newMonth = DateTime(
              _currentViewMonth.year,
              _currentViewMonth.month - 1,
              1,
            );
            setState(() {
              _currentViewMonth = newMonth;
              _selectedMonth = newMonth;
              _calculateStats();
            });
          },
        ),
        
        // Month/Year selector button
        TextButton(
          onPressed: () => _selectMonth(context),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat('MMMM yyyy').format(_selectedMonth),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_drop_down, color: Colors.blue),
            ],
          ),
        ),
        
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _currentViewMonth.year == DateTime.now().year &&
                  _currentViewMonth.month == DateTime.now().month
              ? null
              : () {
                  final newMonth = DateTime(
                    _currentViewMonth.year,
                    _currentViewMonth.month + 1,
                    1,
                  );
                  setState(() {
                    _currentViewMonth = newMonth;
                    _selectedMonth = newMonth;
                    _calculateStats();
                  });
                },
        ),
      ],
    );
  }

  Widget _buildCalendar() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: TableCalendar(
          firstDay: DateTime.utc(2010, 10, 16),
          lastDay: DateTime.utc(2030, 3, 14),
          focusedDay: _focusedDay,
          currentDay: DateTime.now(),
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          onPageChanged: (focusedDay) {
            setState(() {
              _focusedDay = focusedDay;
              _selectedMonth = DateTime(focusedDay.year, focusedDay.month, 1);
            });
          },
          calendarFormat: CalendarFormat.month,
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(
              color: Colors.blue.shade100,
              shape: BoxShape.circle,
            ),
            selectedDecoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            todayTextStyle: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
            selectedTextStyle: const TextStyle(color: Colors.white),
            weekendTextStyle: const TextStyle(color: Colors.black54),
            outsideDaysVisible: false,
          ),
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
          ),
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (context, day, focusedDay) {
              return Container(
                margin: const EdgeInsets.all(4.0),
                decoration: BoxDecoration(
                  color: _getCalendarColor(day),
                  shape: BoxShape.circle,
                  border: day.month == _selectedMonth.month && 
                          day.year == _selectedMonth.year
                      ? null
                      : Border.all(color: Colors.grey.shade200, width: 1),
                ),
                child: Center(
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      color: day.weekday == DateTime.sunday
                          ? Colors.red
                          : day.month == _selectedMonth.month && 
                             day.year == _selectedMonth.year
                              ? Colors.black87
                              : Colors.grey,
                      fontWeight: isSameDay(day, DateTime.now())
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAbsencesSection() {
    final filteredAbsences = _getFilteredAbsences();
    if (filteredAbsences.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Absence Records',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${filteredAbsences.length} records',
                style: TextStyle(
                  color: Colors.orange.shade800,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredAbsences.length,
          itemBuilder: (context, index) {
            final absence = filteredAbsences[index];
            return _buildAbsenceCard(absence);
          },
        ),
      ],
    );
  }

  Widget _buildAttendanceRecords() {
    final filteredRecords = _getFilteredAttendanceRecords();
    
    if (filteredRecords.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No attendance records for ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Attendance History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${filteredRecords.length} records',
                style: TextStyle(
                  color: Colors.blue.shade800,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredRecords.length,
          itemBuilder: (context, index) {
            final record = filteredRecords[index];
            return _buildAttendanceRecordCard(record);
          },
        ),
      ],
    );
  }

  String _formatTime(String? time) {
    if (time == null || time == '-' || time == 'null') return '-';
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

  String _calculateHours(String? checkIn, String? checkOut, String date) {
    if (checkIn == null ||
        checkIn == '-' ||
        checkOut == null ||
        checkOut == '-')
      return '-';
    try {
      final inTime = DateTime.parse('${date}T$checkIn');
      final outTime = DateTime.parse('${date}T$checkOut');
      final diff = outTime.difference(inTime);
      final hours = diff.inHours;
      final minutes = diff.inMinutes % 60;
      return '${hours}h ${minutes}m';
    } catch (e) {
      return '-';
    }
  }

  Widget _buildAbsenceCard(Map<String, dynamic> absence) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.event_busy, color: Colors.orange),
        title: Text(DateFormat('dd/MM/yyyy').format(DateTime.parse(absence['date']))),
        subtitle: Text(absence['reason'] ?? 'No reason provided'),
      ),
    );
  }

  Widget _buildAttendanceRecordCard(Map<String, dynamic> record) {
    final date = DateTime.parse(record['date']);
    final checkIn = record['check_in'] ?? '-';
    final checkOut = record['check_out'] ?? '-';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          checkIn != '-' && checkOut != '-'
              ? Icons.check_circle
              : Icons.access_time,
          color: checkIn != '-' && checkOut != '-'
              ? Colors.green
              : Colors.orange,
        ),
        title: Text(DateFormat('dd/MM/yyyy').format(date)),
        subtitle: Text(
          'In: ${_formatTime(checkIn)} | Out: ${_formatTime(checkOut)}',
        ),
        trailing: Text(
          _calculateHours(checkIn, checkOut, record['date']),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildSelectedDateDetails() {
    if (_selectedDay == null) return const SizedBox.shrink();

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDay!);
    final record = _attendanceRecords.firstWhere(
      (r) => r['date'] == dateStr,
      orElse: () => {},
    );

    if (record.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No attendance record for ${DateFormat('dd MMM yyyy').format(_selectedDay!)}',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('dd MMM yyyy').format(_selectedDay!),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildDetailItem(
              'Check In',
              _formatTime(record['check_in']),
              Icons.login,
              Colors.green,
            ),
            const SizedBox(height: 8),
            _buildDetailItem(
              'Check Out',
              _formatTime(record['check_out']),
              Icons.logout,
              Colors.red,
            ),
            const SizedBox(height: 8),
            _buildDetailItem(
              'Total Hours',
              _calculateHours(
                record['check_in'],
                record['check_out'],
                record['date'],
              ),
              Icons.access_time,
              Colors.blue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        Text(value),
      ],
    );
  }

  Widget _buildMarkAttendanceButton() {
    return const SizedBox.shrink();
  }
}
