import 'package:flutter/material.dart';
import '../../layouts/dashboard_layout.dart';
import '../../widgets/project_widget.dart';

class HrProjectsScreen extends StatelessWidget {
  const HrProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DashboardLayout(
      role: 'hr',
      child: ProjectWidget(),
    );
  }
}
