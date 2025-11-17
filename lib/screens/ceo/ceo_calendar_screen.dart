import 'package:flutter/material.dart';
import '../../layouts/dashboard_layout.dart';
import '../../widgets/holiday_calendar.dart';

class CeoCalendarScreen extends StatelessWidget {
  const CeoCalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardLayout(
      role: 'ceo',
      child: const HolidayCalendar(role: 'ceo'),
    );
  }
}
