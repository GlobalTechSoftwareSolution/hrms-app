import 'package:flutter/material.dart';
import '../../layouts/dashboard_layout.dart';
import '../../widgets/project_widget.dart';

class ManagerProjectsScreen extends StatelessWidget {
  const ManagerProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DashboardLayout(
      role: 'manager',
      child: ProjectWidget(),
    );
  }
}
