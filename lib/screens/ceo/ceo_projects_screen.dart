import 'package:flutter/material.dart';
import '../../layouts/dashboard_layout.dart';
import '../../widgets/project_widget.dart';

class CeoProjectsScreen extends StatelessWidget {
  const CeoProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DashboardLayout(
      role: 'ceo',
      child: ProjectWidget(),
    );
  }
}
