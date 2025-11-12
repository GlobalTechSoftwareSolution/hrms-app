import 'package:flutter/material.dart';
import '../../widgets/project_widget.dart';

class EmployeeProjectsScreen extends StatelessWidget {
  const EmployeeProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: const ProjectWidget(),
    );
  }
}
