import 'package:flutter/material.dart';
import 'employee_tasks_screen.dart';

class EmployeeTasksWrapper extends StatelessWidget {
  const EmployeeTasksWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: const EmployeeTasksScreen(),
    );
  }
}
