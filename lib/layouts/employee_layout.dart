import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../screens/login_screen.dart';
import '../services/api_service.dart';
import '../utils/fcm_utils.dart';
import '../screens/employee/employee_home_screen.dart';
import '../screens/employee/employee_tasks_screen.dart';
import '../screens/employee/employee_attendance_screen.dart';
import '../screens/employee/employee_leave_screen.dart';
import '../screens/employee/employee_payroll_screen.dart';
import '../screens/employee/employee_holiday_calendar_screen.dart';
import '../screens/employee/employee_notice_wrapper.dart';
import '../screens/employee/employee_kra_kpa_wrapper.dart';
import '../screens/employee/employee_tickets_screen.dart';
import '../screens/employee/employee_projects_screen.dart';
import '../screens/employee/employee_resignation_screen.dart';
import '../screens/employee/employee_profile_screen.dart';
import '../screens/employee/employee_notifications_screen.dart'; // Import for notifications screen

class EmployeeLayout extends StatefulWidget {
  const EmployeeLayout({super.key});

  @override
  State<EmployeeLayout> createState() => _EmployeeLayoutState();
}

class _EmployeeLayoutState extends State<EmployeeLayout> {
  int _selectedIndex = 0;
  Map<String, dynamic>? userInfo;
  bool isLoading = true;

  final List<Widget> _screens = [
    const EmployeeHomeScreen(),
    const EmployeeNotificationsScreen(), // Changed from EmployeeNoticeScreen()
    const EmployeeAttendanceScreen(),
  ];

  final List<NavigationDestination> _destinations = const [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.notifications_outlined),
      selectedIcon: Icon(Icons.notifications),
      label: 'Notifications', // Changed from 'Notices'
    ),
    NavigationDestination(
      icon: Icon(Icons.access_time_outlined),
      selectedIcon: Icon(Icons.access_time),
      label: 'Attendance',
    ),
  ];

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
          'role': parsedUser['role'] ?? 'EMPLOYEE',
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
    // Unregister FCM token before logging out
    await FCMUtils.unregisterFCMTokenAtLogout();

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
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
        radius: 18,
        backgroundColor: Colors.blue.shade300,
        child: ClipOval(
          child: Image.network(
            profilePic,
            width: 36,
            height: 36,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.person, color: Colors.white, size: 20);
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

    return CircleAvatar(
      backgroundColor: Colors.blue.shade300,
      radius: 18,
      child: const Icon(Icons.person, color: Colors.white, size: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.business_center,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HRMS',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Employee Portal',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: profilePictureWidget,
            onPressed: () {
              // Show profile menu
              showModalBottomSheet(
                context: context,
                builder: (context) => Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: profilePictureWidget,
                        title: Text(
                          userInfo?['name'] ?? 'Guest User',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(userInfo?['email'] ?? ''),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.person),
                        title: const Text('Profile'),
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Profile coming soon'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.settings),
                        title: const Text('Settings'),
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Settings coming soon'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.logout, color: Colors.red),
                        title: const Text(
                          'Logout',
                          style: TextStyle(color: Colors.red),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _showLogoutDialog();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: _buildDrawer(),
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: _destinations,
        animationDuration: const Duration(milliseconds: 500),
      ),
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
                            'EMPLOYEE',
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
                children: [
                  _buildDrawerItem(Icons.dashboard, 'Dashboard', () {
                    Navigator.pop(context);
                    setState(() => _selectedIndex = 0);
                  }),
                  _buildDrawerItem(Icons.task_alt, 'Tasks', () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _TasksScreenWithDrawer(
                          userInfo: userInfo,
                          onLogout: _showLogoutDialog,
                        ),
                      ),
                    );
                  }),
                  _buildDrawerItem(Icons.access_time, 'Attendance', () {
                    Navigator.pop(context);
                    setState(() => _selectedIndex = 2);
                  }),
                  _buildDrawerItem(Icons.event_note, 'Leaves', () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EmployeeLeaveScreen(),
                      ),
                    );
                  }),
                  _buildDrawerItem(Icons.attach_money, 'Payroll', () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EmployeePayrollScreen(),
                      ),
                    );
                  }),
                  _buildDrawerItem(Icons.calendar_today, 'Calendar', () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EmployeeHolidayCalendarScreen(),
                      ),
                    );
                  }),
                  _buildDrawerItem(Icons.announcement, 'Notice', () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EmployeeNoticeWrapper(),
                      ),
                    );
                  }),
                  _buildDrawerItem(Icons.assessment, 'KRA & KPA', () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EmployeeKraKpaWrapper(),
                      ),
                    );
                  }),
                  _buildDrawerItem(Icons.confirmation_number, 'Tickets', () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EmployeeTicketsScreen(),
                      ),
                    );
                  }),
                  _buildDrawerItem(Icons.work, 'Projects', () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EmployeeProjectsScreen(),
                      ),
                    );
                  }),
                  _buildDrawerItem(Icons.exit_to_app, 'Resign', () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EmployeeResignationScreen(),
                      ),
                    );
                  }),
                  _buildDrawerItem(Icons.person, 'Profile', () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EmployeeProfileScreen(),
                      ),
                    );
                  }),
                ],
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
                    onPressed: () {
                      Navigator.pop(context);
                      _showLogoutDialog();
                    },
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

    return CircleAvatar(
      backgroundColor: Colors.blue.shade300,
      radius: 32,
      child: const Icon(Icons.person, color: Colors.white, size: 32),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Tasks Screen with Drawer
class _TasksScreenWithDrawer extends StatelessWidget {
  final Map<String, dynamic>? userInfo;
  final VoidCallback onLogout;

  const _TasksScreenWithDrawer({
    required this.userInfo,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      drawer: _buildDrawer(context),
      body: const EmployeeTasksScreen(),
    );
  }

  Widget _buildDrawer(BuildContext context) {
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
                            'EMPLOYEE',
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
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildDrawerItem(context, Icons.dashboard, 'Dashboard', () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  }),
                  _buildDrawerItem(context, Icons.task_alt, 'Tasks', () {
                    Navigator.pop(context);
                  }),
                  _buildDrawerItem(
                    context,
                    Icons.access_time,
                    'Attendance',
                    () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                  ),
                  _buildDrawerItem(context, Icons.event_note, 'Leaves', () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Leaves - Coming soon')),
                    );
                  }),
                  _buildDrawerItem(context, Icons.attach_money, 'Payroll', () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Payroll - Coming soon')),
                    );
                  }),
                  _buildDrawerItem(
                    context,
                    Icons.calendar_today,
                    'Calendar',
                    () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Calendar - Coming soon')),
                      );
                    },
                  ),
                  _buildDrawerItem(context, Icons.announcement, 'Notice', () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EmployeeNoticeWrapper(),
                      ),
                    );
                  }),
                  _buildDrawerItem(context, Icons.assessment, 'KRA & KPA', () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('KRA & KPA - Coming soon')),
                    );
                  }),
                  _buildDrawerItem(
                    context,
                    Icons.confirmation_number,
                    'Tickets',
                    () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Tickets - Coming soon')),
                      );
                    },
                  ),
                  _buildDrawerItem(context, Icons.work, 'Projects', () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Projects - Coming soon')),
                    );
                  }),
                  _buildDrawerItem(context, Icons.exit_to_app, 'Resign', () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Resign - Coming soon')),
                    );
                  }),
                  _buildDrawerItem(context, Icons.person, 'Profile', () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Profile - Coming soon')),
                    );
                  }),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onLogout();
                    },
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
            errorBuilder: (_, __, ___) => CircleAvatar(
              backgroundColor: Colors.blue.shade300,
              radius: 32,
              child: const Icon(Icons.person, color: Colors.white, size: 32),
            ),
          ),
        ),
      );
    }
    return CircleAvatar(
      backgroundColor: Colors.blue.shade300,
      radius: 32,
      child: const Icon(Icons.person, color: Colors.white, size: 32),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
