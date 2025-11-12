import 'package:flutter/material.dart';
import '../../layouts/dashboard_layout.dart';
import '../../widgets/ticket_widget.dart';

class AdminTicketsScreen extends StatelessWidget {
  const AdminTicketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DashboardLayout(
      role: 'admin',
      child: TicketWidget(showCreateButton: true),
    );
  }
}
