import 'package:flutter/material.dart';
import 'employee_notice_screen.dart';

class EmployeeNoticeWrapper extends StatelessWidget {
  const EmployeeNoticeWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notices'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: const EmployeeNoticeScreen(),
    );
  }
}
