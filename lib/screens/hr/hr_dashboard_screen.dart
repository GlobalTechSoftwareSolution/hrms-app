import 'package:flutter/material.dart';
import '../../layouts/dashboard_layout.dart';
import '../../services/api_service.dart';

class HrDashboardScreen extends StatefulWidget {
  const HrDashboardScreen({super.key});

  @override
  State<HrDashboardScreen> createState() => _HrDashboardScreenState();
}

class _HrDashboardScreenState extends State<HrDashboardScreen> {
  final ApiService _apiService = ApiService();

  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _leaves = [];
  List<Map<String, dynamic>> _payrolls = [];
  int _onboardingCount = 0;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _apiService.get('/accounts/employees/'),
        _apiService.get('/accounts/leaves/'),
        _apiService.get('/accounts/payrolls/'),
      ]);

      if (results[0]['success']) {
        _employees = List<Map<String, dynamic>>.from(results[0]['data'] ?? []);
      }

      if (results[1]['success']) {
        _leaves = List<Map<String, dynamic>>.from(results[1]['data'] ?? []);
      }

      if (results[2]['success']) {
        _payrolls = List<Map<String, dynamic>>.from(results[2]['data'] ?? []);
      }

      // Calculate onboarding count (pre-boarded status)
      _onboardingCount = _employees
          .where((emp) => emp['status'] == 'pre-boarded')
          .length;
    } catch (e) {
      print('Error fetching HR dashboard data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getPayrollValue() {
    double total = 0;
    for (var payroll in _payrolls) {
      final gross = payroll['gross_salary'] ?? 0.0;
      if (gross is num) {
        total += gross.toDouble();
      }
    }
    if (total > 0) {
      return '₹${(total / 1000).floor()}k';
    }
    return '${_payrolls.length}';
  }

  @override
  Widget build(BuildContext context) {
    return DashboardLayout(
      role: 'hr',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'HR Dashboard',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildStatCard(
                    'Total Employees',
                    _employees.length.toString(),
                    Icons.people,
                    Colors.blue,
                  ),
                  _buildStatCard(
                    'Leave Requests',
                    _leaves.length.toString(),
                    Icons.event_note,
                    Colors.orange,
                  ),
                  _buildStatCard(
                    'Onboarding',
                    _onboardingCount.toString(),
                    Icons.person_add,
                    Colors.green,
                  ),
                  _buildStatCard(
                    'Payroll',
                    _getPayrollValue(),
                    Icons.payment,
                    Colors.purple,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
