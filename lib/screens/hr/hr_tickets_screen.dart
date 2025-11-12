import 'package:flutter/material.dart';
import '../../layouts/dashboard_layout.dart';
import '../../widgets/ticket_widget.dart';

class HrTicketsScreen extends StatelessWidget {
  const HrTicketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DashboardLayout(
      role: 'hr',
      child: TicketWidget(showCreateButton: true),
    );
  }
}
