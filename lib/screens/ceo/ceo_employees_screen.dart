import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../layouts/dashboard_layout.dart';
import 'employee_full_profile_screen.dart';

class CeoEmployeesScreen extends StatefulWidget {
  const CeoEmployeesScreen({super.key});

  @override
  State<CeoEmployeesScreen> createState() => _CeoEmployeesScreenState();
}

class _CeoEmployeesScreenState extends State<CeoEmployeesScreen> {
  final ApiService _apiService = ApiService();

  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _documents = [];
  List<Map<String, dynamic>> _payrolls = [];
  List<Map<String, dynamic>> _filteredEmployees = [];

  bool _isLoading = true;
  String _searchTerm = '';
  String _departmentFilter = 'all';
  String _statusFilter = 'all';

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
      print('CEO Employees - API Response: $employeesResponse');

      if (employeesResponse['success']) {
        final data = employeesResponse['data'];
        print('CEO Employees - Raw data: $data');

        if (data is List) {
          _employees = List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data.containsKey('employees')) {
          _employees = List<Map<String, dynamic>>.from(data['employees'] ?? []);
        } else if (data is Map && data.containsKey('results')) {
          _employees = List<Map<String, dynamic>>.from(data['results'] ?? []);
        } else {
          _employees = [];
        }

        print('CEO Employees - Processed employees: ${_employees.length}');
      } else {
        print('CEO Employees - API call not successful');
        _employees = [];
      }

      // Fetch documents
      final documentsResponse = await _apiService.get(
        '/accounts/employee_documents/',
      );
      if (documentsResponse['success']) {
        _documents = List<Map<String, dynamic>>.from(
          documentsResponse['data'] ?? [],
        );
      }

      // Fetch payrolls
      final payrollsResponse = await _apiService.get('/accounts/payrolls/');
      if (payrollsResponse['success']) {
        _payrolls = List<Map<String, dynamic>>.from(
          payrollsResponse['data'] ?? [],
        );
      }

      _applyFilters();
    } catch (e) {
      print('Error fetching data: $e');
      _employees = [];
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilters() {
    _filteredEmployees = _employees.where((employee) {
      final matchesSearch =
          _searchTerm.isEmpty ||
          (employee['fullname'] ?? employee['name'] ?? '')
              .toLowerCase()
              .contains(_searchTerm.toLowerCase()) ||
          (employee['email_id'] ?? employee['email'] ?? '')
              .toLowerCase()
              .contains(_searchTerm.toLowerCase()) ||
          (employee['designation'] ?? employee['role'] ?? '')
              .toLowerCase()
              .contains(_searchTerm.toLowerCase());

      final matchesDepartment =
          _departmentFilter == 'all' ||
          (employee['department'] ?? '') == _departmentFilter;

      final matchesStatus =
          _statusFilter == 'all' ||
          (employee['status'] ?? 'active') == _statusFilter;

      return matchesSearch && matchesDepartment && matchesStatus;
    }).toList();
  }

  List<String> get _departments {
    final departments = _employees
        .map((e) => e['department']?.toString() ?? 'General')
        .toSet()
        .toList();
    departments.sort();
    return ['all', ...departments];
  }

  void _showEmployeeDetails(Map<String, dynamic> employee) {
    final payroll = _getLatestPayroll(
      employee['email_id'] ?? employee['email'] ?? '',
    );
    final hasDocuments = _hasDocuments(
      employee['email_id'] ?? employee['email'] ?? '',
    );

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with Profile
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade600, Colors.blue.shade800],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: CircleAvatar(
                        radius: 30,
                        backgroundImage: NetworkImage(
                          _getValidImageUrl(
                            employee['profile_picture'],
                            employee['fullname'] ?? employee['name'] ?? 'User',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            employee['fullname'] ??
                                employee['name'] ??
                                'Unknown',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            employee['designation'] ??
                                employee['role'] ??
                                'Employee',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(
                                employee['status'],
                              ).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white70),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(employee['status']),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  employee['status']?.toUpperCase() ?? 'ACTIVE',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),

              // Detailed Information
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Personal Information
                      _buildInfoCard('Personal Information', [
                        _buildDetailRow(
                          'Full Name',
                          employee['fullname'] ?? employee['name'] ?? 'N/A',
                        ),
                        _buildDetailRow(
                          'Email',
                          employee['email_id'] ?? employee['email'] ?? 'N/A',
                        ),
                        _buildDetailRow(
                          'Phone',
                          employee['phone'] ?? employee['mobile'] ?? 'N/A',
                        ),
                        _buildDetailRow(
                          'Date of Birth',
                          _formatDate(
                            employee['date_of_birth'] ?? employee['dob'],
                          ),
                        ),
                        _buildDetailRow('Gender', employee['gender'] ?? 'N/A'),
                        _buildDetailRow(
                          'Address',
                          employee['address'] ?? 'N/A',
                        ),
                      ]),

                      const SizedBox(height: 16),

                      // Employment Information
                      _buildInfoCard('Employment Details', [
                        _buildDetailRow(
                          'Employee ID',
                          employee['employee_id'] ??
                              employee['emp_id'] ??
                              'N/A',
                        ),
                        _buildDetailRow(
                          'Department',
                          employee['department'] ?? 'N/A',
                        ),
                        _buildDetailRow(
                          'Designation',
                          employee['designation'] ?? employee['role'] ?? 'N/A',
                        ),
                        _buildDetailRow(
                          'Join Date',
                          _formatDate(
                            employee['join_date'] ?? employee['date_joined'],
                          ),
                        ),
                        _buildDetailRow(
                          'Employment Type',
                          employee['employment_type'] ?? 'Full-time',
                        ),
                        _buildDetailRow(
                          'Work Location',
                          employee['work_location'] ??
                              employee['office_location'] ??
                              'N/A',
                        ),
                        _buildDetailRow(
                          'Manager',
                          employee['manager'] ??
                              employee['reporting_manager'] ??
                              'N/A',
                        ),
                        _buildDetailRow(
                          'Years at Company',
                          _calculateYearsAtCompany(employee),
                        ),
                      ]),

                      if (payroll != null) ...[
                        const SizedBox(height: 16),
                        _buildInfoCard('Salary Information', [
                          _buildDetailRow(
                            'Basic Salary',
                            '₹${payroll['basic_salary'] ?? payroll['salary'] ?? 0}',
                            color: Colors.green.shade600,
                          ),
                          _buildDetailRow('HRA', '₹${payroll['hra'] ?? 0}'),
                          _buildDetailRow(
                            'Medical Allowance',
                            '₹${payroll['medical_allowance'] ?? 0}',
                          ),
                          _buildDetailRow(
                            'Transport Allowance',
                            '₹${payroll['transport_allowance'] ?? 0}',
                          ),
                          _buildDetailRow(
                            'Gross Salary',
                            '₹${payroll['gross_salary'] ?? 0}',
                            color: Colors.blue.shade600,
                          ),
                          _buildDetailRow(
                            'Net Salary',
                            '₹${payroll['net_salary'] ?? 0}',
                            color: Colors.green.shade600,
                          ),
                          _buildDetailRow(
                            'Pay Period',
                            '${payroll['month']}/${payroll['year']}',
                          ),
                        ]),
                      ],

                      const SizedBox(height: 16),

                      // Additional Information
                      _buildInfoCard('Additional Details', [
                        _buildDetailRow(
                          'Emergency Contact',
                          employee['emergency_contact'] ?? 'N/A',
                        ),
                        _buildDetailRow(
                          'Blood Group',
                          employee['blood_group'] ?? 'N/A',
                        ),
                        _buildDetailRow(
                          'Marital Status',
                          employee['marital_status'] ?? 'N/A',
                        ),
                        _buildDetailRow(
                          'PAN Number',
                          employee['pan_number'] ?? 'N/A',
                        ),
                        _buildDetailRow(
                          'Aadhar Number',
                          employee['aadhar_number'] ?? 'N/A',
                        ),
                        _buildDetailRow(
                          'Bank Account',
                          employee['bank_account'] ?? 'N/A',
                        ),
                      ]),
                    ],
                  ),
                ),
              ),

              // Single Action Button - View Full Profile
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EmployeeFullProfileScreen(
                            employee: employee,
                            payroll: payroll,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.person),
                    label: const Text('View Complete Profile'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: color ?? Colors.black87, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '—';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _getValidImageUrl(String? url, String name) {
    if (url == null || url.isEmpty) {
      return 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=0D8ABC&color=fff';
    }
    try {
      Uri.parse(url);
      return url;
    } catch (e) {
      return 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=0D8ABC&color=fff';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'on-leave':
        return Colors.orange;
      case 'pre-boarded':
        return Colors.blue;
      case 'offboarded':
        return Colors.red;
      default:
        return Colors.green; // Default to green for active status
    }
  }

  Color _getRoleColor(String? role) {
    switch (role?.toLowerCase()) {
      case 'manager':
        return Colors.purple;
      case 'lead':
        return Colors.orange;
      case 'senior':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Map<String, dynamic>? _getLatestPayroll(String email) {
    final payrolls = _payrolls
        .where((p) => (p['email'] ?? '').toLowerCase() == email.toLowerCase())
        .toList();

    if (payrolls.isEmpty) return null;

    payrolls.sort((a, b) {
      final aYear = int.tryParse(a['year']?.toString() ?? '0') ?? 0;
      final bYear = int.tryParse(b['year']?.toString() ?? '0') ?? 0;
      final aMonth = int.tryParse(a['month']?.toString() ?? '0') ?? 0;
      final bMonth = int.tryParse(b['month']?.toString() ?? '0') ?? 0;

      if (aYear != bYear) return bYear.compareTo(aYear);
      return bMonth.compareTo(aMonth);
    });

    return payrolls.first;
  }

  bool _hasDocuments(String email) {
    return _documents.any(
      (doc) =>
          (doc['employee_email'] ?? '').toLowerCase() == email.toLowerCase(),
    );
  }

  String _calculateYearsAtCompany(Map<String, dynamic> employee) {
    final joinDateStr = employee['join_date'] ?? employee['date_joined'];
    if (joinDateStr == null) return 'N/A';

    try {
      final joinDate = DateTime.parse(joinDateStr);
      final now = DateTime.now();
      final difference = now.difference(joinDate);
      final years = (difference.inDays / 365).floor();
      final months = ((difference.inDays % 365) / 30).floor();

      if (years > 0) {
        return '$years yr ${months}m';
      } else {
        return '${months}m';
      }
    } catch (e) {
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    return DashboardLayout(
      role: 'ceo',
      child: SafeArea(
        child: Column(
          children: [
            // Fixed Header Card (no collapsing to prevent jumpy behavior)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.people,
                          size: 24,
                          color: Colors.blue.shade600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Employee Management',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              '${_filteredEmployees.length} of ${_employees.length} employees',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 16,
                              color: Colors.green.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_employees.length}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Search Bar
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search employees by name, email, or role...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.blue.shade400),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchTerm = value;
                        _applyFilters();
                      });
                    },
                  ),

                  const SizedBox(height: 12),

                  // Filters Row
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 600) {
                        // Mobile: Stack filters vertically
                        return Column(
                          children: [
                            _buildFilterDropdown(
                              'Department',
                              _departmentFilter,
                              _departments
                                  .map(
                                    (dept) => DropdownMenuItem(
                                      value: dept,
                                      child: Text(
                                        dept == 'all'
                                            ? 'All Departments'
                                            : dept,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              (value) {
                                setState(() {
                                  _departmentFilter = value!;
                                  _applyFilters();
                                });
                              },
                            ),
                            const SizedBox(height: 8),
                            _buildFilterDropdown(
                              'Status',
                              _statusFilter,
                              const [
                                DropdownMenuItem(
                                  value: 'all',
                                  child: Text('All Status'),
                                ),
                                DropdownMenuItem(
                                  value: 'active',
                                  child: Text('Active'),
                                ),
                                DropdownMenuItem(
                                  value: 'on-leave',
                                  child: Text('On Leave'),
                                ),
                                DropdownMenuItem(
                                  value: 'pre-boarded',
                                  child: Text('Pre-boarded'),
                                ),
                                DropdownMenuItem(
                                  value: 'offboarded',
                                  child: Text('Offboarded'),
                                ),
                              ],
                              (value) {
                                setState(() {
                                  _statusFilter = value!;
                                  _applyFilters();
                                });
                              },
                            ),
                          ],
                        );
                      } else {
                        // Desktop: Side by side
                        return Row(
                          children: [
                            Expanded(
                              child: _buildFilterDropdown(
                                'Department',
                                _departmentFilter,
                                _departments
                                    .map(
                                      (dept) => DropdownMenuItem(
                                        value: dept,
                                        child: Text(
                                          dept == 'all'
                                              ? 'All Departments'
                                              : dept,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                (value) {
                                  setState(() {
                                    _departmentFilter = value!;
                                    _applyFilters();
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildFilterDropdown(
                                'Status',
                                _statusFilter,
                                const [
                                  DropdownMenuItem(
                                    value: 'all',
                                    child: Text('All Status'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'active',
                                    child: Text('Active'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'on-leave',
                                    child: Text('On Leave'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'pre-boarded',
                                    child: Text('Pre-boarded'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'offboarded',
                                    child: Text('Offboarded'),
                                  ),
                                ],
                                (value) {
                                  setState(() {
                                    _statusFilter = value!;
                                    _applyFilters();
                                  });
                                },
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ],
              ),
            ),

            // Employee List - Simple ListView without complex scrolling
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Loading employees...',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : _filteredEmployees.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No employees found',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          Text(
                            'Try adjusting your search or filters',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredEmployees.length,
                      itemBuilder: (context, index) {
                        final employee = _filteredEmployees[index];
                        return _buildEmployeeCard(employee);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String value,
    List<DropdownMenuItem<String>> items,
    void Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.blue.shade400),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          items: items,
          onChanged: onChanged,
          isExpanded: true,
        ),
      ],
    );
  }

  Widget _buildEmployeeCard(Map<String, dynamic> employee) {
    final payroll = _getLatestPayroll(
      employee['email_id'] ?? employee['email'] ?? '',
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showEmployeeDetails(employee),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Profile Image
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _getStatusColor(
                        employee['status'],
                      ).withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundImage: NetworkImage(
                      _getValidImageUrl(
                        employee['profile_picture'],
                        employee['fullname'] ?? employee['name'] ?? 'User',
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Employee Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              employee['fullname'] ??
                                  employee['name'] ??
                                  'Unknown',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _getStatusColor(employee['status']),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        employee['email_id'] ?? employee['email'] ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _getRoleColor(
                                employee['designation'] ?? employee['role'],
                              ).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _getRoleColor(
                                  employee['designation'] ?? employee['role'],
                                ).withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              employee['designation'] ??
                                  employee['role'] ??
                                  'Employee',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: _getRoleColor(
                                  employee['designation'] ?? employee['role'],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            employee['department'] ?? 'General',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          if (payroll != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '•',
                              style: TextStyle(color: Colors.grey.shade400),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '₹${payroll['basic_salary'] ?? payroll['salary'] ?? 0}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.green.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Status & Action
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(
                          employee['status'],
                        ).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        employee['status'] ?? 'active',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(employee['status']),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Colors.grey.shade400,
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
}
