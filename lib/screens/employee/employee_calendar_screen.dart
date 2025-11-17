import 'package:flutter/material.dart';
import '../../layouts/dashboard_layout.dart';
import '../../widgets/holiday_calendar.dart';

class EmployeeCalendarScreen extends StatelessWidget {
  const EmployeeCalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardLayout(
      role: 'employee',
      child: const HolidayCalendar(role: 'employee'),
    );
  }
}

