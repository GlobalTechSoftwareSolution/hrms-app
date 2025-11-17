import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/documents_service.dart';
import '../../models/employee_documents_model.dart';

class EmployeeFullProfileScreen extends StatefulWidget {
  final Map<String, dynamic> employee;
  final Map<String, dynamic>? payroll;

  const EmployeeFullProfileScreen({
    super.key,
    required this.employee,
    this.payroll,
  });

  @override
  State<EmployeeFullProfileScreen> createState() =>
      _EmployeeFullProfileScreenState();
}

class _EmployeeFullProfileScreenState extends State<EmployeeFullProfileScreen> {
  final DocumentsService _documentsService = DocumentsService();
  EmployeeDocuments? _documents;
  bool _isLoadingDocuments = true;

  @override
  void initState() {
    super.initState();
    _fetchDocuments();
  }

  Future<void> _fetchDocuments() async {
    try {
      final email =
          widget.employee['email_id'] ?? widget.employee['email'] ?? '';
      if (email.isNotEmpty) {
        final docs = await _documentsService.fetchDocuments(email);
        setState(() {
          _documents = docs;
          _isLoadingDocuments = false;
        });
      } else {
        setState(() => _isLoadingDocuments = false);
      }
    } catch (e) {
      print('Error fetching documents: $e');
      setState(() => _isLoadingDocuments = false);
    }
  }

  Map<String, dynamic> get employee => widget.employee;
  Map<String, dynamic>? get payroll => widget.payroll;

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
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar with Profile Header
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: Colors.blue.shade700,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade600, Colors.blue.shade900],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 20),
                        // Profile Image
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 45,
                            backgroundImage: NetworkImage(
                              _getValidImageUrl(
                                employee['profile_picture'],
                                employee['fullname'] ??
                                    employee['name'] ??
                                    'User',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Name and Title
                        Text(
                          employee['fullname'] ?? employee['name'] ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          employee['designation'] ??
                              employee['role'] ??
                              'Employee',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(
                              employee['status'],
                            ).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white70),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _getStatusColor(employee['status']),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                employee['status']?.toUpperCase() ?? 'ACTIVE',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Stats
                  _buildQuickStats(),
                  const SizedBox(height: 30),

                  // Personal Information
                  _buildSection('Personal Information', Icons.person, [
                    _buildInfoRow(
                      'Full Name',
                      employee['fullname'] ?? employee['name'] ?? 'N/A',
                    ),
                    _buildInfoRow(
                      'Email',
                      employee['email_id'] ?? employee['email'] ?? 'N/A',
                    ),
                    _buildInfoRow(
                      'Phone',
                      employee['phone'] ?? employee['mobile'] ?? 'N/A',
                    ),
                    _buildInfoRow(
                      'Date of Birth',
                      _formatDate(employee['date_of_birth'] ?? employee['dob']),
                    ),
                    _buildInfoRow('Gender', employee['gender'] ?? 'N/A'),
                    _buildInfoRow(
                      'Marital Status',
                      employee['marital_status'] ?? 'N/A',
                    ),
                    _buildInfoRow('Address', employee['address'] ?? 'N/A'),
                    _buildInfoRow(
                      'Emergency Contact',
                      employee['emergency_contact'] ?? 'N/A',
                    ),
                  ]),

                  const SizedBox(height: 30),

                  // Employment Information
                  _buildSection('Employment Information', Icons.work, [
                    _buildInfoRow(
                      'Employee ID',
                      employee['employee_id'] ?? employee['emp_id'] ?? 'N/A',
                    ),
                    _buildInfoRow(
                      'Department',
                      employee['department'] ?? 'N/A',
                    ),
                    _buildInfoRow(
                      'Designation',
                      employee['designation'] ?? employee['role'] ?? 'N/A',
                    ),
                    _buildInfoRow(
                      'Join Date',
                      _formatDate(
                        employee['join_date'] ?? employee['date_joined'],
                      ),
                    ),
                    _buildInfoRow(
                      'Employment Type',
                      employee['employment_type'] ?? 'Full-time',
                    ),
                    _buildInfoRow(
                      'Work Location',
                      employee['work_location'] ??
                          employee['office_location'] ??
                          'N/A',
                    ),
                    _buildInfoRow(
                      'Reporting Manager',
                      employee['manager'] ??
                          employee['reporting_manager'] ??
                          'N/A',
                    ),
                    _buildInfoRow(
                      'Status',
                      employee['status'] ?? 'Active',
                      color: _getStatusColor(employee['status']),
                    ),
                  ]),

                  const SizedBox(height: 30),

                  // Payroll Information
                  if (payroll != null) ...[
                    _buildSection(
                      'Payroll Information',
                      Icons.account_balance_wallet,
                      [
                        _buildInfoRow(
                          'Basic Salary',
                          '₹${payroll!['basic_salary'] ?? payroll!['salary'] ?? 0}',
                          color: Colors.green.shade600,
                        ),
                        _buildInfoRow('HRA', '₹${payroll!['hra'] ?? 0}'),
                        _buildInfoRow(
                          'Medical Allowance',
                          '₹${payroll!['medical_allowance'] ?? 0}',
                        ),
                        _buildInfoRow(
                          'Transport Allowance',
                          '₹${payroll!['transport_allowance'] ?? 0}',
                        ),
                        _buildInfoRow(
                          'PF Deduction',
                          '₹${payroll!['pf_deduction'] ?? 0}',
                          color: Colors.red.shade600,
                        ),
                        _buildInfoRow(
                          'Tax Deduction',
                          '₹${payroll!['tax_deduction'] ?? 0}',
                          color: Colors.red.shade600,
                        ),
                        _buildInfoRow(
                          'Other Deductions',
                          '₹${payroll!['other_deductions'] ?? 0}',
                          color: Colors.red.shade600,
                        ),
                        const Divider(),
                        _buildInfoRow(
                          'Gross Salary',
                          '₹${payroll!['gross_salary'] ?? 0}',
                          color: Colors.blue.shade600,
                          isBold: true,
                        ),
                        _buildInfoRow(
                          'Net Salary',
                          '₹${payroll!['net_salary'] ?? 0}',
                          color: Colors.green.shade600,
                          isBold: true,
                        ),
                        _buildInfoRow(
                          'Pay Period',
                          '${payroll!['month']}/${payroll!['year']}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                  ],

                  // Additional Employee Information
                  _buildSection('Additional Information', Icons.info, [
                    _buildInfoRow(
                      'Employee Code',
                      employee['employee_code'] ??
                          employee['emp_code'] ??
                          'N/A',
                    ),
                    _buildInfoRow(
                      'Blood Group',
                      employee['blood_group'] ?? 'N/A',
                    ),
                    _buildInfoRow(
                      'Nationality',
                      employee['nationality'] ?? 'Indian',
                    ),
                    _buildInfoRow('Religion', employee['religion'] ?? 'N/A'),
                    _buildInfoRow(
                      'Father Name',
                      employee['father_name'] ?? 'N/A',
                    ),
                    _buildInfoRow(
                      'Mother Name',
                      employee['mother_name'] ?? 'N/A',
                    ),
                    _buildInfoRow(
                      'Spouse Name',
                      employee['spouse_name'] ?? 'N/A',
                    ),
                    _buildInfoRow(
                      'PAN Number',
                      employee['pan_number'] ?? 'N/A',
                    ),
                    _buildInfoRow(
                      'Aadhar Number',
                      employee['aadhar_number'] ?? 'N/A',
                    ),
                    _buildInfoRow(
                      'Passport Number',
                      employee['passport_number'] ?? 'N/A',
                    ),
                    _buildInfoRow(
                      'Driving License',
                      employee['driving_license'] ?? 'N/A',
                    ),
                    _buildInfoRow('Bank Name', employee['bank_name'] ?? 'N/A'),
                    _buildInfoRow(
                      'Account Number',
                      employee['account_number'] ?? 'N/A',
                    ),
                    _buildInfoRow('IFSC Code', employee['ifsc_code'] ?? 'N/A'),
                    _buildInfoRow(
                      'UAN Number',
                      employee['uan_number'] ?? 'N/A',
                    ),
                    _buildInfoRow(
                      'ESI Number',
                      employee['esi_number'] ?? 'N/A',
                    ),
                  ]),

                  const SizedBox(height: 30),

                  // Documents & Compliance
                  _buildDocumentsSection(),

                  const SizedBox(height: 30),

                  // Simple back button only
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Years at Company',
            _calculateYearsAtCompany(),
            Icons.calendar_today,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Department',
            employee['department'] ?? 'N/A',
            Icons.business,
            Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Employee ID',
            employee['employee_id'] ?? employee['emp_id'] ?? 'N/A',
            Icons.badge,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.blue.shade600, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    Color? color,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
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
              style: TextStyle(
                color: color ?? Colors.black87,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _calculateYearsAtCompany() {
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

  Future<void> _viewDocument(BuildContext context, String documentUrl) async {
    try {
      // Ensure the URL is properly formatted
      String fullUrl = documentUrl;
      if (!documentUrl.startsWith('http')) {
        fullUrl = 'https://globaltechsoftwaresolutions.cloud/api/$documentUrl';
      }

      final Uri url = Uri.parse(fullUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open document'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening document: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildDocumentsSection() {
    if (_isLoadingDocuments) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.folder,
                    color: Colors.blue.shade600,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Documents & Compliance',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
          ],
        ),
      );
    }

    if (_documents == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.folder,
                    color: Colors.blue.shade600,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Documents & Compliance',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                'No documents found',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      );
    }

    final allDocs = _documents!.getAllDocuments();
    final availableDocs = allDocs.entries
        .where((e) => e.value.isAvailable)
        .toList();
    final missingDocs = allDocs.entries
        .where((e) => !e.value.isAvailable)
        .toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.folder,
                  color: Colors.blue.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Documents & Compliance',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${availableDocs.length}/${allDocs.length} documents uploaded',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: availableDocs.length / allDocs.length,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                availableDocs.length == allDocs.length
                    ? Colors.green.shade600
                    : Colors.orange.shade600,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Available Documents
          if (availableDocs.isNotEmpty) ...[
            Text(
              'Available Documents (${availableDocs.length})',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 12),
            ...availableDocs.map(
              (entry) => _buildDocumentItem(
                entry.value.label,
                entry.value.url!,
                isAvailable: true,
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Missing Documents
          if (missingDocs.isNotEmpty) ...[
            Text(
              'Missing Documents (${missingDocs.length})',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 12),
            ...missingDocs.map(
              (entry) =>
                  _buildDocumentItem(entry.value.label, '', isAvailable: false),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDocumentItem(
    String label,
    String url, {
    required bool isAvailable,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isAvailable ? Colors.green.shade50 : Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isAvailable ? Colors.green.shade200 : Colors.red.shade200,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isAvailable ? Icons.check_circle : Icons.cancel,
              color: isAvailable ? Colors.green.shade600 : Colors.red.shade600,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  if (isAvailable)
                    Text(
                      'Uploaded',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    )
                  else
                    Text(
                      'Not uploaded',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade600,
                      ),
                    ),
                ],
              ),
            ),
            if (isAvailable)
              IconButton(
                icon: Icon(Icons.open_in_new, color: Colors.blue.shade600),
                onPressed: () => _viewDocument(context, url),
                tooltip: 'View Document',
              ),
          ],
        ),
      ),
    );
  }
}
