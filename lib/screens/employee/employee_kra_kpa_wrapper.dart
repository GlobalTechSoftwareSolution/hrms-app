import 'package:flutter/material.dart';
import 'employee_kra_kpa_screen.dart';

class EmployeeKraKpaWrapper extends StatelessWidget {
  const EmployeeKraKpaWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KRA & KPA'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: const EmployeeKraKpaScreen(),
    );
  }
}
