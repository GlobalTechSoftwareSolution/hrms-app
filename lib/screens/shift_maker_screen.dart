import 'package:flutter/material.dart';
import '../widgets/shift_maker_widget.dart';

class ShiftMakerScreen extends StatelessWidget {
  const ShiftMakerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shift Management'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: const ShiftMakerWidget(),
    );
  }
}
