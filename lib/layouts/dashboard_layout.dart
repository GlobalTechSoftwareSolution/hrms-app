import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/login_screen.dart';
import '../screens/ceo/ceo_tickets_screen.dart';
import '../screens/manager/manager_tickets_screen.dart';
import '../screens/hr/hr_tickets_screen.dart';
import '../screens/admin/admin_tickets_screen.dart';
import '../screens/admin/admin_approval_screen.dart';
import '../screens/admin/admin_attendance_screen.dart';
import '../screens/admin/admin_calendar_screen.dart';
import '../screens/ceo/ceo_projects_screen.dart';
import '../screens/manager/manager_projects_screen.dart';
import '../screens/manager/manager_tasks_screen.dart';
import '../screens/manager/manager_reports_screen.dart';
import '../screens/manager/manager_team_screen.dart';
import '../screens/manager/manager_leave_approval_screen.dart';
import '../screens/manager/manager_attendance_screen.dart';
import '../screens/manager/manager_monthly_reports_screen.dart';
import '../screens/manager/manager_notice_screen.dart';
import '../screens/manager/manager_calendar_screen.dart';
import '../screens/manager/manager_resigned_employees_screen.dart';
import '../screens/manager/manager_profile_screen.dart';
import '../screens/hr/hr_projects_screen.dart';
import '../screens/hr/hr_calendar_screen.dart';
import '../screens/hr/hr_employees_screen.dart';
import '../screens/hr/hr_leaves_screen.dart';
import '../screens/hr/hr_attendance_screen.dart';
import '../screens/hr/hr_monthly_reports_screen.dart';
import '../screens/hr/hr_payroll_screen.dart';
import '../screens/hr/hr_onboarding_screen.dart';
import '../screens/hr/hr_offboarding_screen.dart';
import '../screens/hr/hr_notice_screen.dart';
import '../screens/hr/hr_documents_screen.dart';
import '../screens/hr/hr_careers_screen.dart';
import '../screens/hr/hr_profile_screen.dart';
import '../screens/admin/admin_notice_screen.dart';
import '../screens/admin/admin_profile_screen.dart';
import '../screens/ceo/ceo_dashboard_screen.dart';
import '../screens/ceo/ceo_reports_screen.dart';
import '../screens/ceo/ceo_employees_screen.dart';
import '../screens/ceo/ceo_attendance_screen.dart';
import '../screens/ceo/monthly_reports_screen.dart';
import '../screens/ceo/ceo_finance_screen.dart';
import '../screens/ceo/ceo_notice_screen.dart';
import '../screens/ceo/ceo_calendar_screen.dart';
import '../screens/ceo/ceo_profile_screen.dart';
import '../screens/employee/employee_calendar_screen.dart';
import '../screens/employee/employee_profile_screen.dart';

class DashboardLayout extends StatefulWidget {
  final Widget child;
  final String role;

  const DashboardLayout({super.key, required this.child, required this.role});

  @override
  State<DashboardLayout> createState() => _DashboardLayoutState();
}

class _DashboardLayoutState extends State<DashboardLayout> {
  Map<String, dynamic>? userInfo;
  bool isLoading = true;
  bool showLogoutModal = false;
  String currentPath = '';

  // Role-based navigation links
  final Map<String, List<Map<String, String>>> roleLinksMap = {
    'ceo': [
      {'name': 'Dashboard', 'path': '/ceo/dashboard'},
      {'name': 'Reports', 'path': '/ceo/reports'},
      {'name': 'Employees', 'path': '/ceo/employees'},
      {'name': 'Attendance', 'path': '/ceo/attendance'},
      {'name': 'Monthly Report', 'path': '/ceo/monthly_report'},
      {'name': 'Finance', 'path': '/ceo/finance'},
      {'name': 'Projects', 'path': '/ceo/projects'},
      {'name': 'Notice', 'path': '/ceo/notice'},
      {'name': 'Calendar', 'path': '/ceo/calendar'},
      {'name': 'Tickets', 'path': '/ceo/tickets'},
      {'name': 'Profile', 'path': '/ceo/profile'},
    ],
    'manager': [
      {'name': 'Tasks', 'path': '/manager/tasks'},
      {'name': 'Reports', 'path': '/manager/reports'},
      {'name': 'Team', 'path': '/manager/team'},
      {'name': 'Leave Approvals', 'path': '/manager/leaveapprovals'},
      {'name': 'Attendance', 'path': '/manager/attendance'},
      {'name': 'Monthly Report', 'path': '/manager/monthly_report'},
      {'name': 'Notice', 'path': '/manager/notice'},
      {'name': 'Calendar', 'path': '/manager/calendar'},
      {'name': 'Tickets', 'path': '/manager/tickets'},
      {'name': 'Projects', 'path': '/manager/projects'},
      {'name': 'Resigned Employee', 'path': '/manager/resigned_employee'},
      {'name': 'Profile', 'path': '/manager/profile'},
    ],
    'hr': [
      {'name': 'Dashboard', 'path': '/hr/dashboard'},
      {'name': 'Employees', 'path': '/hr/employee'},
      {'name': 'Attendance', 'path': '/hr/attendance'},
      {'name': 'Monthly Report', 'path': '/hr/monthly_report'},
      {'name': 'Payroll', 'path': '/hr/payroll'},
      {'name': 'Onboarding', 'path': '/hr/onboarding'},
      {'name': 'Offboarding', 'path': '/hr/offboarding'},
      {'name': 'Leaves', 'path': '/hr/leaves'},
      {'name': 'Documents', 'path': '/hr/documents'},
      {'name': 'Careers', 'path': '/hr/careers'},
      {'name': 'Notice', 'path': '/hr/notice'},
      {'name': 'Tickets', 'path': '/hr/tickets'},
      {'name': 'Profile', 'path': '/hr/profile'},
    ],
    'employee': [
      {'name': 'Dashboard', 'path': '/employee/dashboard'},
      {'name': 'Tasks', 'path': '/employee/tasks'},
      {'name': 'Attendance', 'path': '/employee/attendance'},
      {'name': 'Leaves', 'path': '/employee/leaves'},
      {'name': 'Payroll', 'path': '/employee/payroll'},
      {'name': 'Calendar', 'path': '/employee/calendar'},
      {'name': 'Notice', 'path': '/employee/notice'},
      {'name': 'KRA & KPA', 'path': '/employee/kra_kpa'},
      {'name': 'Tickets', 'path': '/employee/tickets'},
      {'name': 'Projects', 'path': '/employee/projects'},
      {'name': 'Resign', 'path': '/employee/resign'},
      {'name': 'Profile', 'path': '/employee/profile'},
    ],
    'admin': [
      {'name': 'Attendance', 'path': '/admin/attendance'},
      {'name': 'Approvals', 'path': '/admin/approvals'},
      {'name': 'Calendar', 'path': '/admin/calendar'},
      {'name': 'Notice', 'path': '/admin/notice'},
      {'name': 'Tickets', 'path': '/admin/tickets'},
      {'name': 'Profile', 'path': '/admin/profile'},
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userInfoString = prefs.getString('user_info');

      if (userInfoString == null) {
        _redirectToLogin();
        return;
      }

      final parsedUser = jsonDecode(userInfoString);
      setState(() {
        userInfo = {
          'name': parsedUser['name'] ?? 'Guest User',
          'email': parsedUser['email'] ?? '',
          'picture': parsedUser['picture'] ?? '',
          'profile_picture': parsedUser['profile_picture'] ?? '',
          'role': parsedUser['role'] ?? widget.role.toUpperCase(),
        };
        isLoading = false;
      });
    } catch (e) {
      print('Error loading user info: $e');
      _redirectToLogin();
    }
  }

  void _redirectToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('loggedIn', false); // mark user as logged out
    await prefs.remove('user_info');
    await prefs.remove('user_email');

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _navigateToPage(String path) {
    // Navigate to the appropriate screen based on path
    Widget screen;

    switch (path) {
      case '/ceo/tickets':
        screen = const CeoTicketsScreen();
        break;
      case '/manager/tickets':
        screen = const ManagerTicketsScreen();
        break;
      case '/hr/tickets':
        screen = const HrTicketsScreen();
        break;
      case '/admin/tickets':
        screen = const AdminTicketsScreen();
        break;
      case '/admin/approvals':
        screen = const AdminApprovalScreen();
        break;
      case '/admin/attendance':
        screen = const AdminAttendanceScreen();
        break;
      case '/admin/calendar':
        screen = const AdminCalendarScreen();
        break;
      case '/admin/notice':
        screen = const AdminNoticeScreen();
        break;
      case '/admin/profile':
        screen = const AdminProfileScreen();
        break;
      case '/ceo/dashboard':
        screen = const CeoDashboardScreen();
        break;
      case '/ceo/reports':
        screen = const CeoReportsScreen();
        break;
      case '/ceo/employees':
        screen = const CeoEmployeesScreen();
        break;
      case '/ceo/attendance':
        screen = const CeoAttendanceScreen();
        break;
      case '/ceo/monthly_report':
        screen = const MonthlyReportsScreen();
        break;
      case '/ceo/finance':
        screen = const CeoFinanceScreen();
        break;
      case '/ceo/notice':
        screen = const CeoNoticeScreen();
        break;
      case '/ceo/calendar':
        screen = const CeoCalendarScreen();
        break;
      case '/ceo/profile':
        screen = const CeoProfileScreen();
        break;
      case '/ceo/projects':
        screen = const CeoProjectsScreen();
        break;
      case '/manager/projects':
        screen = const ManagerProjectsScreen();
        break;
      case '/manager/tasks':
        screen = const ManagerTasksScreen();
        break;
      case '/manager/reports':
        screen = const ManagerReportsScreen();
        break;
      case '/manager/team':
        screen = const ManagerTeamScreen();
        break;
      case '/manager/leaveapprovals':
        screen = const ManagerLeaveApprovalScreen();
        break;
      case '/manager/attendance':
        screen = const ManagerAttendanceScreen();
        break;
      case '/manager/monthly_report':
        screen = const MonthlyReportsScreen();
        break;
      case '/manager/notice':
        screen = const ManagerNoticeScreen();
        break;
      case '/manager/calendar':
        screen = const ManagerCalendarScreen();
        break;
      case '/manager/resigned_employee':
        screen = const ManagerResignedEmployeesScreen();
        break;
      case '/manager/profile':
        screen = const ManagerProfileScreen();
        break;
      case '/hr/projects':
        screen = const HrProjectsScreen();
        break;
      case '/hr/calendar':
        screen = const HrCalendarScreen();
        break;
      case '/hr/employee':
        screen = const HrEmployeesScreen();
        break;
      case '/hr/leaves':
        screen = const HrLeavesScreen();
        break;
      case '/hr/attendance':
        screen = const HrAttendanceScreen();
        break;
      case '/hr/monthly_report':
        screen = const HrMonthlyReportsScreen();
        break;
      case '/hr/payroll':
        screen = const HrPayrollScreen();
        break;
      case '/hr/onboarding':
        screen = const HrOnboardingScreen();
        break;
      case '/hr/offboarding':
        screen = const HrOffboardingScreen();
        break;
      case '/hr/notice':
        screen = const HrNoticeScreen();
        break;
      case '/hr/documents':
        screen = const HrDocumentsScreen();
        break;
      case '/hr/careers':
        screen = const HrCareersScreen();
        break;
      case '/hr/profile':
        screen = const HrProfileScreen();
        break;
      case '/employee/calendar':
        screen = const EmployeeCalendarScreen();
        break;
      case '/employee/profile':
        screen = const EmployeeProfileScreen();
        break;
      default:
        // Show a snackbar for unimplemented routes
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${path.split('/').last} - Coming soon'),
            duration: const Duration(seconds: 1),
          ),
        );
        return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleLogout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Widget get profilePictureWidget {
    final profilePic = userInfo?['profile_picture'] ?? userInfo?['picture'];

    if (profilePic != null &&
        profilePic.isNotEmpty &&
        (profilePic.startsWith('https://') ||
            profilePic.startsWith('http://'))) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: Colors.blue.shade300,
        child: ClipOval(
          child: Image.network(
            profilePic,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.person, color: Colors.white, size: 24);
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              );
            },
          ),
        ),
      );
    }

    // Default avatar with icon
    return CircleAvatar(
      backgroundColor: Colors.blue.shade300,
      radius: 20,
      child: const Icon(Icons.person, color: Colors.white, size: 24),
    );
  }

  List<Map<String, String>> get roleLinks {
    return roleLinksMap[widget.role] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.role.toUpperCase()} Dashboard'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () {
                // Navigate to profile based on role
                switch (widget.role) {
                  case 'manager':
                    _navigateToPage('/manager/profile');
                    break;
                  case 'ceo':
                    _navigateToPage('/ceo/profile');
                    break;
                  case 'hr':
                    _navigateToPage('/hr/profile');
                    break;
                  case 'admin':
                    _navigateToPage('/admin/profile');
                    break;
                  case 'employee':
                    _navigateToPage('/employee/profile');
                    break;
                  default:
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profile coming soon'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                }
              },
              child: profilePictureWidget,
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: widget.child,
    );
  }

  Widget _buildDrawerProfilePicture() {
    final profilePic = userInfo?['profile_picture'] ?? userInfo?['picture'];

    if (profilePic != null &&
        profilePic.isNotEmpty &&
        (profilePic.startsWith('http://') ||
            profilePic.startsWith('https://'))) {
      return CircleAvatar(
        radius: 32,
        backgroundColor: Colors.white,
        child: ClipOval(
          child: Image.network(
            profilePic,
            width: 64,
            height: 64,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              print('Error loading profile picture: $error');
              return CircleAvatar(
                backgroundColor: Colors.blue.shade300,
                radius: 32,
                child: const Icon(Icons.person, color: Colors.white, size: 32),
              );
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                      : null,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.blue.shade300,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    // Default avatar with icon
    return CircleAvatar(
      backgroundColor: Colors.blue.shade300,
      radius: 32,
      child: const Icon(Icons.person, color: Colors.white, size: 32),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade600, Colors.blue.shade800],
          ),
        ),
        child: Column(
          children: [
            // User Profile Section
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.blue.shade700)),
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    _buildDrawerProfilePicture(),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userInfo?['name'] ?? 'Guest User',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.role.toUpperCase(),
                            style: TextStyle(
                              color: Colors.blue.shade200,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Navigation Links
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: roleLinks.map((link) {
                  final isActive = currentPath == link['path'];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: isActive
                          ? Colors.blue.shade500
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            currentPath = link['path']!;
                          });
                          Navigator.pop(context); // Close drawer
                          _navigateToPage(link['path']!);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Text(
                            link['name']!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // Logout Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.blue.shade800],
                ),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showLogoutDialog,
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
