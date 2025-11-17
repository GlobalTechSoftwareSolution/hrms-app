import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../layouts/dashboard_layout.dart';

class HrPayrollScreen extends StatefulWidget {
  const HrPayrollScreen({super.key});

  @override
  State<HrPayrollScreen> createState() => _HrPayrollScreenState();
}

class _HrPayrollScreenState extends State<HrPayrollScreen> {
  final ApiService _apiService = ApiService();

  List<Map<String, dynamic>> _payslips = [];
  List<Map<String, dynamic>> _employees = [];
  bool _isLoading = true;
  String? _error;
  int _selectedMonth = DateTime.now().month - 1; // 0-11 range
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    try {
      // Fetch employees
      final employeesResponse = await _apiService.get('/accounts/employees/');
      final employeesData = employeesResponse['data'] is List
          ? employeesResponse['data'] as List
          : (employeesResponse['data']?['employees'] ?? []);
      final employeesList = employeesData
          .whereType<Map<String, dynamic>>()
          .toList();

      setState(() => _employees = employeesList);

      // Fetch payrolls
      final payrollsResponse = await _apiService.get(
        '/accounts/list_payrolls/',
      );
      final payrollsData = payrollsResponse['data'];

      if (payrollsData['payrolls'] != null &&
          payrollsData['payrolls'] is List) {
        final validPayrolls = (payrollsData['payrolls'] as List)
            .where(
              (payroll) =>
                  payroll is Map &&
                  payroll['email'] != null &&
                  payroll['month'] != null &&
                  payroll['year'] != null,
            )
            .map((payroll) => payroll as Map<String, dynamic>)
            .toList();

        final transformedPayslips = await Future.wait(
          validPayrolls.map((payroll) async {
            final employee = employeesList.firstWhere(
              (emp) => emp['email'] == payroll['email'],
              orElse: () => <String, dynamic>{},
            );

            final monthIndex = (payroll['month'] is String)
                ? int.parse(payroll['month'] as String) - 1
                : (payroll['month'] as int) - 1;
            final monthName = [
              'January',
              'February',
              'March',
              'April',
              'May',
              'June',
              'July',
              'August',
              'September',
              'October',
              'November',
              'December',
            ][monthIndex];

            final basicSalary = (payroll['basic_salary'] is String)
                ? double.parse(payroll['basic_salary'] as String)
                : (payroll['basic_salary'] as num?)?.toDouble() ?? 0.0;

            return {
              'id':
                  '${payroll['email']}_${payroll['month']}_${payroll['year']}',
              'period': '$monthName ${payroll['year']}',
              'employeeId': employee['emp_id']?.toString() ?? 'N/A',
              'employeeName': employee['fullname'] ?? payroll['email'],
              'department': employee['department'] ?? 'N/A',
              'basicSalary': basicSalary,
              'status': payroll['status'] ?? 'Pending',
            };
          }),
        );

        setState(() => _payslips = transformedPayslips);
      } else {
        setState(() => _payslips = []);
      }
    } catch (e) {
      setState(() => _error = e.toString());
      _payslips = [];
      _employees = [];
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredPayslips {
    return _payslips.where((payslip) {
      final period = payslip['period'] as String?;
      if (period == null) return false;

      final parts = period.split(' ');
      if (parts.length < 2) return false;

      final monthStr = parts[0];
      final yearStr = parts[1];
      final monthIndex = _getMonthIndex(monthStr);
      final yearNum = int.tryParse(yearStr) ?? 0;

      final monthMatch = monthIndex == _selectedMonth;
      final yearMatch = yearNum == _selectedYear;

      return monthMatch && yearMatch;
    }).toList();
  }

  int _getMonthIndex(String monthName) {
    const months = {
      'january': 0,
      'february': 1,
      'march': 2,
      'april': 3,
      'may': 4,
      'june': 5,
      'july': 6,
      'august': 7,
      'september': 8,
      'october': 9,
      'november': 10,
      'december': 11,
    };
    return months[monthName.toLowerCase()] ?? DateTime.now().month - 1;
  }

  @override
  Widget build(BuildContext context) {
    return DashboardLayout(
      role: 'hr',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Payroll Management',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_employees.length} employees registered',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),

            // Filters
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200, width: 1),
              ),
              child: Column(
                children: [
                  // Month Selector
                  DropdownButtonFormField<int>(
                    value: _selectedMonth >= 0 && _selectedMonth <= 11
                        ? _selectedMonth
                        : null,
                    decoration: InputDecoration(
                      labelText: 'Month',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      isDense: true,
                    ),
                    items: List.generate(
                      12,
                      (index) => DropdownMenuItem(
                        value: index,
                        child: Text(
                          [
                            'January',
                            'February',
                            'March',
                            'April',
                            'May',
                            'June',
                            'July',
                            'August',
                            'September',
                            'October',
                            'November',
                            'December',
                          ][index],
                        ),
                      ),
                    ),
                    onChanged: (value) =>
                        setState(() => _selectedMonth = value!),
                  ),
                  const SizedBox(height: 12),

                  // Period Display
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Viewing payroll for ${['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][_selectedMonth >= 0 && _selectedMonth <= 11 ? _selectedMonth : DateTime.now().month - 1]} ${_selectedYear}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_filteredPayslips.length} payroll records found',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Payroll List
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Text(
                      'Error: $_error',
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                : _filteredPayslips.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200, width: 1),
                    ),
                    child: const Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.receipt_long,
                            size: 48,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text('No Payroll Records Found'),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredPayslips.length,
                    itemBuilder: (context, index) {
                      final payslip = _filteredPayslips[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildPayslipCard(payslip),
                      );
                    },
                  ),

            const SizedBox(height: 20),

            // Create New Payroll Button
            Center(
              child: SizedBox(
                width: 250,
                child: ElevatedButton.icon(
                  onPressed: () => _showCreatePayrollDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Create New Payroll'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayslipCard(Map<String, dynamic> payslip) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Employee Info
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.blue.shade100,
                  child: const Icon(Icons.person, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payslip['employeeName'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        payslip['period'],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: payslip['status'] == 'Paid'
                        ? Colors.green.shade100
                        : payslip['status'] == 'Processing'
                        ? Colors.orange.shade100
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    payslip['status'],
                    style: TextStyle(
                      fontSize: 12,
                      color: payslip['status'] == 'Paid'
                          ? Colors.green.shade700
                          : payslip['status'] == 'Processing'
                          ? Colors.orange.shade700
                          : Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Salary Info
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Employee ID: ${payslip['employeeId']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        'Department: ${payslip['department']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Basic Salary',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      '₹${payslip['basicSalary'].toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Action Button
            Center(
              child: ElevatedButton.icon(
                onPressed: () => _showPayslipDialog(payslip),
                icon: const Icon(Icons.visibility),
                label: const Text('View Details'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  minimumSize: const Size(120, 36),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPayslipDialog(Map<String, dynamic> payslip) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Payslip Details',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Employee Info Card
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Employee Information',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const Divider(),
                              _buildDetailRow('Name', payslip['employeeName']),
                              _buildDetailRow(
                                'Employee ID',
                                payslip['employeeId'],
                              ),
                              _buildDetailRow('Period', payslip['period']),
                              _buildDetailRow(
                                'Department',
                                payslip['department'],
                              ),
                              _buildDetailRow('Status', payslip['status']),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Salary Info Card
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Salary Information',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const Divider(),
                              const SizedBox(height: 8),
                              Center(
                                child: Text(
                                  '₹${payslip['basicSalary'].toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: Text(
                                  'Basic Salary (Monthly)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Close Button
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showCreatePayrollDialog() {
    String selectedEmail = '';
    String basicSalary = '';
    String selectedMonth = '';
    String selectedYear = DateTime.now().year.toString();
    String status = 'Paid';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            constraints: BoxConstraints(
              maxWidth: 600,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Create New Payroll',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Employee Selection
                Autocomplete<Map<String, dynamic>>(
                  displayStringForOption: (employee) =>
                      employee['fullname'] ??
                      employee['email'] ??
                      'Unknown Employee',
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return _employees;
                    }
                    return _employees.where((employee) {
                      final name =
                          employee['fullname']?.toString().toLowerCase() ??
                          employee['email']?.toString().toLowerCase() ??
                          '';
                      return name.contains(textEditingValue.text.toLowerCase());
                    });
                  },
                  onSelected: (employee) {
                    setState(
                      () => selectedEmail = employee['email']?.toString() ?? '',
                    );
                  },
                  fieldViewBuilder:
                      (context, controller, focusNode, onFieldSubmitted) {
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: 'Employee',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            suffixIcon: const Icon(Icons.search),
                          ),
                        );
                      },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 300,
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final employee = options.elementAt(index);
                              final displayName =
                                  employee['fullname'] ??
                                  employee['email'] ??
                                  'Unknown Employee';
                              return ListTile(
                                title: Text(displayName),
                                onTap: () => onSelected(employee),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),

                // Basic Salary
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Basic Salary',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => basicSalary = value,
                ),

                const SizedBox(height: 12),

                // Month
                DropdownButtonFormField<String>(
                  value: selectedMonth.isEmpty ? null : selectedMonth,
                  decoration: InputDecoration(
                    labelText: 'Month',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items:
                      [
                        'January',
                        'February',
                        'March',
                        'April',
                        'May',
                        'June',
                        'July',
                        'August',
                        'September',
                        'October',
                        'November',
                        'December',
                      ].map((month) {
                        return DropdownMenuItem(
                          value: month,
                          child: Text(month),
                        );
                      }).toList(),
                  onChanged: (value) =>
                      setState(() => selectedMonth = value ?? ''),
                ),

                const SizedBox(height: 12),

                // Year
                DropdownButtonFormField<String>(
                  value: selectedYear,
                  decoration: InputDecoration(
                    labelText: 'Year',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items:
                      List.generate(
                        5,
                        (i) => (DateTime.now().year - 2 + i).toString(),
                      ).map((year) {
                        return DropdownMenuItem(value: year, child: Text(year));
                      }).toList(),
                  onChanged: (value) => setState(
                    () =>
                        selectedYear = value ?? DateTime.now().year.toString(),
                  ),
                ),

                const SizedBox(height: 12),

                const SizedBox(height: 12),

                // Status
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items: ['Paid', 'Pending', 'Processing'].map((statusValue) {
                    return DropdownMenuItem(
                      value: statusValue,
                      child: Text(statusValue),
                    );
                  }).toList(),
                  onChanged: (value) =>
                      setState(() => status = value ?? 'Paid'),
                ),

                const SizedBox(height: 20),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _createPayroll(
                          selectedEmail,
                          basicSalary,
                          selectedMonth,
                          selectedYear,
                          status,
                          context,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Create Payroll'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createPayroll(
    String email,
    String basicSalary,
    String month,
    String year,
    String status,
    BuildContext dialogContext,
  ) async {
    if (email.isEmpty || basicSalary.isEmpty || month.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    try {
      final monthIndex = _getMonthIndex(month) + 1;
      final payrollData = {
        'email': email,
        'basic_salary': double.parse(basicSalary),
        'month': monthIndex.toString().padLeft(2, '0'),
        'year': int.parse(year),
        'status': status,
        'STD': 22, // Default working days
        'LOP': 0, // No loss of pay initially
      };

      await _apiService.post('/accounts/create_payroll/', payrollData);

      Navigator.of(dialogContext).pop(); // Close dialog
      _fetchData(); // Refresh data

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payroll created successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error creating payroll: $e')));
    }
  }
}
