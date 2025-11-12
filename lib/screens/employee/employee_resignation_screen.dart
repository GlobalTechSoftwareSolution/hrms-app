import 'package:flutter/material.dart';
import '../../widgets/resignation_widget.dart';

class EmployeeResignationScreen extends StatelessWidget {
  const EmployeeResignationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Resignation'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: const ResignationWidget(),
    );
  }
}
