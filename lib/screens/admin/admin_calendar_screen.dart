import 'package:flutter/material.dart';
import '../../layouts/dashboard_layout.dart';
import '../../widgets/holiday_calendar.dart';

class AdminCalendarScreen extends StatelessWidget {
  const AdminCalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardLayout(
      role: 'admin',
      child: const HolidayCalendar(role: 'admin'),
    );
  }
}
