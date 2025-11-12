import 'package:flutter/material.dart';
import '../employee/employee_holiday_calendar_screen.dart';

class AdminCalendarScreen extends StatelessWidget {
  const AdminCalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Simply use the existing holiday calendar component
    return const EmployeeHolidayCalendarScreen();
  }
}
