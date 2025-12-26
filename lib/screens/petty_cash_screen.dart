import 'package:flutter/material.dart';
import '../widgets/petty_cash_widget.dart';

class PettyCashScreen extends StatelessWidget {
  const PettyCashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Petty Cash Ledger'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: const PettyCashWidget(),
    );
  }
}
