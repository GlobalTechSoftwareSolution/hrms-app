import 'package:flutter/material.dart';
import '../../layouts/dashboard_layout.dart';
import '../../widgets/ticket_widget.dart';

class CeoTicketsScreen extends StatelessWidget {
  const CeoTicketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DashboardLayout(
      role: 'ceo',
      child: TicketWidget(showCreateButton: true),
    );
  }
}
