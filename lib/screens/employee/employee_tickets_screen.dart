import 'package:flutter/material.dart';
import '../../widgets/ticket_widget.dart';

class EmployeeTicketsScreen extends StatelessWidget {
  const EmployeeTicketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tickets'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: const TicketWidget(showCreateButton: true),
    );
  }
}
