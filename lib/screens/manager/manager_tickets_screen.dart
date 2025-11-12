import 'package:flutter/material.dart';
import '../../layouts/dashboard_layout.dart';
import '../../widgets/ticket_widget.dart';

class ManagerTicketsScreen extends StatelessWidget {
  const ManagerTicketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DashboardLayout(
      role: 'manager',
      child: TicketWidget(showCreateButton: true),
    );
  }
}
