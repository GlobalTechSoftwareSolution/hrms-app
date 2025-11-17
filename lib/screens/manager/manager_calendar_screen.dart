import 'package:flutter/material.dart';
import '../../layouts/dashboard_layout.dart';
import '../../widgets/holiday_calendar.dart';

class ManagerCalendarScreen extends StatelessWidget {
  const ManagerCalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardLayout(
      role: 'manager',
      child: const HolidayCalendar(role: 'manager'),
    );
  }
}

