import 'package:flutter/material.dart';
import '../employee/employee_notice_screen.dart';

/// Admin Notice Screen
/// Reuses the EmployeeNoticeScreen component for admin role
/// Similar to how the React admin_notice page reuses the Notice component
class AdminNoticeScreen extends StatelessWidget {
  const AdminNoticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmployeeNoticeScreen();
  }
}
