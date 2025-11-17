import 'package:flutter/material.dart';
import '../../layouts/dashboard_layout.dart';
import '../../widgets/holiday_calendar.dart';

class HrCalendarScreen extends StatelessWidget {
  const HrCalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardLayout(
      role: 'hr',
      child: const HolidayCalendar(role: 'hr'),
    );
  }
}

