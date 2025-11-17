import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../layouts/dashboard_layout.dart';

class ManagerResignedEmployeesScreen extends StatefulWidget {
  const ManagerResignedEmployeesScreen({super.key});

  @override
  State<ManagerResignedEmployeesScreen> createState() =>
      _ManagerResignedEmployeesScreenState();
}

class _ManagerResignedEmployeesScreenState
    extends State<ManagerResignedEmployeesScreen> {
  final ApiService _apiService = ApiService();

  List<Map<String, dynamic>> _employees = [];
  Map<String, String> _descriptions = {};
  bool _isLoading = false;
  String _activeTab = 'pending'; // 'pending' or 'reviewed'

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
  }

  Future<void> _fetchEmployees() async {
    setState(() => _isLoading = true);

    try {
      final response = await _apiService.get('/accounts/list_releaved/');

      if (response['success'] == true) {
        final data = response['data'];
        List<Map<String, dynamic>> employees = [];

        if (data is List) {
          employees = data.whereType<Map<String, dynamic>>().toList();
        } else if (data is Map && data['releaved'] is List) {
          employees = (data['releaved'] as List)
              .whereType<Map<String, dynamic>>()
              .toList();
        }

        // Add derived approval_status property
        final formattedData = employees.map((emp) {
          String approvalStatus = "Pending";
          String approved = "pending";

          if (emp['manager_approved'] == "Approved") {
            approvalStatus = "Approved";
            approved = "yes";
          } else if (emp['manager_approved'] == "Rejected") {
            approvalStatus = "Rejected";
            approved = "no";
          }

          return {
            ...emp,
            'approval_status': approvalStatus,
            'approved': approved,
          };
        }).toList();

        setState(() => _employees = formattedData);
      } else {
        if (mounted) {
          _showMessageDialog('error', 'Failed to fetch employees data');
        }
      }
    } catch (e) {
      debugPrint('Error fetching employees: $e');
      if (mounted) {
        _showMessageDialog('error', 'Failed to fetch employees data');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleUpdate(int id, String email, String approved) async {
    try {
      setState(() => _isLoading = true);

      final description =
          _descriptions[email] ??
          "manager rejected resignation due to incomplete documentation";

      final response = await _apiService.patch('/accounts/releaved/$id/', {
        'approval_stage': 'manager',
        'approved': approved == 'yes' ? 'Approved' : 'Rejected',
        'description': description,
      });

      if (response['success'] == true) {
        final message =
            response['data']?['message'] ??
            'Employee ${approved == 'yes' ? 'approved' : 'rejected'} successfully!';
        _showMessageDialog('success', message);
        await _fetchEmployees();
      } else {
        final error =
            response['data']?['error'] ??
            response['error'] ??
            'Failed to update status';
        _showMessageDialog('error', error);
      }
    } catch (e) {
      debugPrint('Error updating: $e');
      _showMessageDialog('error', 'Failed to update status and description!');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _openViewModal(Map<String, dynamic> employee) {
    showDialog(
      context: context,
      builder: (context) => _buildViewModalDialog(employee),
    );
  }

  void _openConfirmationModal(Map<String, dynamic> employee, String type) {
    final email = employee['email'] as String? ?? '';
    final description = _descriptions[email]?.trim();
    if (description == null || description.isEmpty) {
      _showMessageDialog(
        'error',
        'Please add a description before taking action',
      );
      return;
    }

    final fullname = employee['fullname'] ?? employee['email'] ?? 'Employee';
    showDialog(
      context: context,
      builder: (context) =>
          _buildConfirmationModalDialog(employee, type, fullname),
    );
  }

  void _showMessageDialog(String type, String message) {
    showDialog(
      context: context,
      builder: (context) => _buildMessageModalDialog(type, message),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '-';
    try {
      return DateFormat('MMM d, y').format(DateTime.parse(dateString));
    } catch (e) {
      return dateString;
    }
  }

  List<Map<String, dynamic>> get _filteredEmployees {
    return _employees.where((emp) {
      if (_activeTab == 'pending') {
        return emp['approved'] == null || emp['approved'] == 'pending';
      } else {
        return emp['approved'] == 'yes' || emp['approved'] == 'no';
      }
    }).toList();
  }

  int get _totalCount => _employees.length;
  int get _approvedCount =>
      _employees.where((emp) => emp['approved'] == 'yes').length;
  int get _rejectedCount =>
      _employees.where((emp) => emp['approved'] == 'no').length;
  int get _pendingCount => _employees
      .where((emp) => emp['approved'] == null || emp['approved'] == 'pending')
      .length;

  @override
  Widget build(BuildContext context) {
    return DashboardLayout(role: 'manager', child: _buildContent());
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildStatsCards(),
          const SizedBox(height: 24),
          _buildTableSection(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Releaved Employees',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Review and manage employee releaving requests',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildStatsCards() {
    // Use a vertical layout for stats cards so they don't overflow on narrow screens.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStatCard(
          'Total Requests',
          _totalCount.toString(),
          Colors.blue,
          Icons.people,
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          'Approved',
          _approvedCount.toString(),
          Colors.green,
          Icons.check_circle,
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          'Rejected',
          _rejectedCount.toString(),
          Colors.red,
          Icons.cancel,
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          'Pending',
          _pendingCount.toString(),
          Colors.orange,
          Icons.pending,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
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
          _buildTabs(),
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(48.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              : _filteredEmployees.isEmpty
              ? _buildEmptyState()
              : _buildTable(),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(child: _buildTabButton('Pending Requests', 'pending')),
          const SizedBox(width: 12),
          Expanded(child: _buildTabButton('Reviewed Requests', 'reviewed')),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, String tab) {
    final isActive = _activeTab == tab;
    return InkWell(
      onTap: () => setState(() => _activeTab = tab),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue.shade600 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.grey.shade800,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(48.0),
      child: Column(
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            'No releaved employees',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'There are currently no employee releaving requests to review.',
            style: TextStyle(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    final width = MediaQuery.of(context).size.width;

    // On narrow screens, show a vertical list of cards instead of a DataTable
    // to avoid tight row height constraints and make the UI mobile-friendly.
    if (width < 600) {
      return _buildMobileList();
    }

    return _buildDesktopTable();
  }

  Widget _buildDesktopTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        dataRowMinHeight: 64,
        dataRowMaxHeight: 80,
        columns: [
          const DataColumn(label: Text('Employee')),
          const DataColumn(label: Text('Department & Role')),
          const DataColumn(label: Text('Dates')),
          const DataColumn(label: Text('Status')),
          if (_activeTab == 'reviewed')
            const DataColumn(label: Text('Description')),
          if (_activeTab == 'pending')
            const DataColumn(label: Text('Description')),
          const DataColumn(label: Text('Actions')),
        ],
        rows: _filteredEmployees.map((emp) => _buildDataRow(emp)).toList(),
      ),
    );
  }

  Widget _buildMobileList() {
    return Column(
      children: _filteredEmployees
          .map((emp) => _buildMobileCard(emp))
          .toList(),
    );
  }

  Widget _buildMobileCard(Map<String, dynamic> emp) {
    final email = emp['email'] as String? ?? '';
    final fullname = emp['fullname'] as String? ?? 'Unknown';
    final approved = emp['approved'] as String? ?? 'pending';
    final isPending = approved == 'pending';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
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
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue.shade600,
                child: Text(
                  fullname.isNotEmpty
                      ? fullname[0].toUpperCase()
                      : email.isNotEmpty
                          ? email[0].toUpperCase()
                          : 'U',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullname,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _openViewModal(emp),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'View Details →',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: approved == 'yes'
                      ? Colors.green.shade100
                      : approved == 'no'
                          ? Colors.red.shade100
                          : Colors.yellow.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  approved == 'yes'
                      ? 'Approved'
                      : approved == 'no'
                          ? 'Rejected'
                          : 'Pending',
                  style: TextStyle(
                    color: approved == 'yes'
                        ? Colors.green.shade800
                        : approved == 'no'
                            ? Colors.red.shade800
                            : Colors.yellow.shade800,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emp['department'] ?? '-',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      emp['designation'] ?? '-',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Applied: ${_formatDate(emp['applied_at'])}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Resigned: ${_formatDate(emp['offboarded_datetime'])}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_activeTab == 'reviewed')
            Text(
              emp['description'] ?? '-',
              style: const TextStyle(fontSize: 12),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          if (_activeTab == 'pending') ...[
            TextField(
              controller: TextEditingController(
                text: _descriptions[email] ?? '',
              ),
              onChanged: (value) {
                setState(() {
                  _descriptions[email] = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Enter reason...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                isDense: true,
              ),
              maxLines: 2,
            ),
            if (!(_descriptions[email]?.trim().isNotEmpty ?? false))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Description required',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.orange.shade600,
                  ),
                ),
              ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: isPending
                ? Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      ElevatedButton.icon(
                        onPressed: (_descriptions[email]?.trim().isNotEmpty ??
                                false)
                            ? () => _openConfirmationModal(emp, 'approve')
                            : null,
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: (_descriptions[email]?.trim().isNotEmpty ??
                                false)
                            ? () => _openConfirmationModal(emp, 'reject')
                            : null,
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Reject'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  DataRow _buildDataRow(Map<String, dynamic> emp) {
    final email = emp['email'] as String? ?? '';
    final fullname = emp['fullname'] as String? ?? 'Unknown';
    final approved = emp['approved'] as String? ?? 'pending';
    final isPending = approved == 'pending';

    return DataRow(
      cells: [
        DataCell(
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue.shade600,
                child: Text(
                  fullname.isNotEmpty
                      ? fullname[0].toUpperCase()
                      : email.isNotEmpty
                      ? email[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      fullname,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _openViewModal(emp),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'View Details →',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emp['department'] ?? '-'),
              Text(
                emp['designation'] ?? '-',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Applied: ${_formatDate(emp['applied_at'])}'),
              Text(
                'Resigned: ${_formatDate(emp['offboarded_datetime'])}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: approved == 'yes'
                  ? Colors.green.shade100
                  : approved == 'no'
                  ? Colors.red.shade100
                  : Colors.yellow.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              approved == 'yes'
                  ? 'Approved'
                  : approved == 'no'
                  ? 'Rejected'
                  : 'Pending',
              style: TextStyle(
                color: approved == 'yes'
                    ? Colors.green.shade800
                    : approved == 'no'
                    ? Colors.red.shade800
                    : Colors.yellow.shade800,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        if (_activeTab == 'reviewed')
          DataCell(
            SizedBox(
              width: 200,
              child: Text(
                emp['description'] ?? '-',
                style: const TextStyle(fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        if (_activeTab == 'pending')
          DataCell(
            SizedBox(
              width: 200,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: TextEditingController(
                      text: _descriptions[email] ?? '',
                    ),
                    onChanged: (value) {
                      setState(() {
                        _descriptions[email] = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Enter reason...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      isDense: true,
                    ),
                    maxLines: 2,
                  ),
                  if (!(_descriptions[email]?.trim().isNotEmpty ?? false))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Description required',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange.shade600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        DataCell(
          isPending
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      onPressed:
                          (_descriptions[email]?.trim().isNotEmpty ?? false)
                          ? () => _openConfirmationModal(emp, 'approve')
                          : null,
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed:
                          (_descriptions[email]?.trim().isNotEmpty ?? false)
                          ? () => _openConfirmationModal(emp, 'reject')
                          : null,
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Reject'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildViewModalDialog(Map<String, dynamic> emp) {
    final fullname = emp['fullname'] as String? ?? 'Unknown';
    final email = emp['email'] as String? ?? '';

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.blue.shade600,
                    child: Text(
                      fullname.isNotEmpty
                          ? fullname[0].toUpperCase()
                          : email.isNotEmpty
                          ? email[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(color: Colors.white, fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullname,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          email,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 24,
                runSpacing: 16,
                children: [
                  _buildDetailItem('Department', emp['department']),
                  _buildDetailItem('Designation', emp['designation']),
                  _buildDetailItem('Role', emp['role']),
                  _buildDetailItem('Phone', emp['phone']),
                  _buildDetailItem('Work Location', emp['work_location']),
                  _buildDetailItem(
                    'Date Joined',
                    _formatDate(emp['date_joined']),
                  ),
                  _buildDetailItem(
                    'Applied Date',
                    _formatDate(emp['applied_at']),
                  ),
                  _buildDetailItem(
                    'Relieved Date',
                    _formatDate(emp['offboarded_datetime']),
                  ),
                ],
              ),
              if (emp['reason_for_resignation'] != null ||
                  emp['description'] != null) ...[
                const SizedBox(height: 24),
                const Text(
                  'Releaving Reason',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    emp['reason_for_resignation'] ?? emp['description'] ?? '',
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String? value) {
    return SizedBox(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(value ?? '-', style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildConfirmationModalDialog(
    Map<String, dynamic> employee,
    String type,
    String fullname,
  ) {
    final isApprove = type == 'approve';

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isApprove ? Colors.green.shade100 : Colors.red.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isApprove ? Icons.check : Icons.close,
                color: isApprove ? Colors.green.shade600 : Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isApprove ? 'Approve Releaving' : 'Reject Releaving',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Are you sure you want to ${isApprove ? 'approve' : 'reject'} $fullname?',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    final id = employee['id'] as int?;
                    final email = employee['email'] as String?;
                    if (id != null && email != null) {
                      _handleUpdate(id, email, isApprove ? 'yes' : 'no');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isApprove
                        ? Colors.green.shade600
                        : Colors.red.shade600,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(isApprove ? 'Yes, Approve' : 'Yes, Reject'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageModalDialog(String type, String message) {
    final isSuccess = type == 'success';

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSuccess ? Colors.green.shade100 : Colors.red.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSuccess ? Icons.check : Icons.error,
                color: isSuccess ? Colors.green.shade600 : Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isSuccess ? 'Success!' : 'Error!',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSuccess
                      ? Colors.green.shade600
                      : Colors.red.shade600,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
