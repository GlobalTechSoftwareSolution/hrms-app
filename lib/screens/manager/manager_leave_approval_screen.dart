import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../layouts/dashboard_layout.dart';
import '../../services/api_service.dart';

class ManagerLeaveApprovalScreen extends StatefulWidget {
  const ManagerLeaveApprovalScreen({super.key});

  @override
  State<ManagerLeaveApprovalScreen> createState() =>
      _ManagerLeaveApprovalScreenState();
}

class _ManagerLeaveApprovalScreenState
    extends State<ManagerLeaveApprovalScreen> {
  final ApiService _apiService = ApiService();

  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _leaveRequests = [];
  bool _isLoading = true;
  String? _updatingLeaveId;
  String _filter = 'All'; // All, Pending, Approved, Rejected

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    try {
      // Fetch employees
      final empResponse = await _apiService.get('/accounts/employees/');
      if (empResponse['success']) {
        final empData = empResponse['data'];
        List<Map<String, dynamic>> employees = [];

        if (empData is List) {
          employees = List<Map<String, dynamic>>.from(empData);
        } else if (empData is Map && empData['employees'] is List) {
          employees = List<Map<String, dynamic>>.from(empData['employees'] ?? []);
        }

        setState(() {
          _employees = employees.map((emp) {
            return {
              'email_id': emp['email_id'] ?? emp['email'] ?? '',
              'email': emp['email'] ?? emp['email_id'] ?? '',
              'fullname': emp['fullname'] ?? emp['name'] ?? 'Unknown',
              'department': emp['department'] ?? 'N/A',
              'designation': emp['designation'] ?? emp['position'] ?? 'N/A',
            };
          }).toList();
        });
      }

      // Fetch leave requests
      final leaveResponse = await _apiService.get('/accounts/list_leaves/');
      if (leaveResponse['success']) {
        final leaveData = leaveResponse['data'];
        List<Map<String, dynamic>> leaves = [];

        if (leaveData is Map && leaveData['leaves'] is List) {
          leaves = List<Map<String, dynamic>>.from(leaveData['leaves'] ?? []);
        } else if (leaveData is List) {
          leaves = List<Map<String, dynamic>>.from(leaveData);
        }

        setState(() => _leaveRequests = leaves);
      }
    } catch (e) {
      _showError('Failed to fetch data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateLeaveStatus(
    String leaveId,
    String status,
  ) async {
    setState(() => _updatingLeaveId = leaveId);

    try {
      final response = await _apiService.patch(
        '/accounts/update_leave/$leaveId/',
        {'status': status},
      );

      if (response['success']) {
        final updatedLeave = response['data'];
        setState(() {
          _leaveRequests = _leaveRequests.map((lr) {
            if (lr['id']?.toString() == leaveId.toString()) {
              return {
                ...lr,
                'status': updatedLeave['leave']?['status'] ?? status,
              };
            }
            return lr;
          }).toList();
        });
        _showSuccess('Leave $status successfully!');
      } else {
        _showError(
          response['error'] ?? 'Failed to update leave status',
        );
      }
    } catch (e) {
      _showError('Network error. Could not update leave status: $e');
    } finally {
      if (mounted) {
        setState(() => _updatingLeaveId = null);
      }
    }
  }

  Map<String, dynamic> _getEmployee(String? email) {
    if (email == null || email.isEmpty) {
      return {
        'fullname': 'Unknown',
        'designation': 'N/A',
        'department': 'N/A',
      };
    }

    final emp = _employees.firstWhere(
      (e) =>
          (e['email_id'] ?? '').toString().toLowerCase() ==
              email.toLowerCase() ||
          (e['email'] ?? '').toString().toLowerCase() == email.toLowerCase(),
      orElse: () => {
        'fullname': email,
        'designation': 'N/A',
        'department': 'N/A',
      },
    );

    return emp;
  }

  List<Map<String, dynamic>> get _filteredLeaves {
    if (_filter == 'All') return _leaveRequests;
    return _leaveRequests
        .where((lr) => (lr['status'] ?? '').toString() == _filter)
        .toList();
  }

  Map<String, int> get _stats {
    return {
      'total': _leaveRequests.length,
      'pending': _leaveRequests
          .where((lr) => (lr['status'] ?? '').toString() == 'Pending')
          .length,
      'approved': _leaveRequests
          .where((lr) => (lr['status'] ?? '').toString() == 'Approved')
          .length,
      'rejected': _leaveRequests
          .where((lr) => (lr['status'] ?? '').toString() == 'Rejected')
          .length,
    };
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '—';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM d, y').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusBgColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.orange.shade50;
      case 'approved':
        return Colors.green.shade50;
      case 'rejected':
        return Colors.red.shade50;
      default:
        return Colors.grey.shade50;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Icons.access_time;
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DashboardLayout(
      role: 'manager',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            const Text(
              'Leave Management Dashboard',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),

            // Stats Cards
            _buildStatsCards(),
            const SizedBox(height: 24),

            // Filter Buttons
            _buildFilterButtons(),
            const SizedBox(height: 24),

            // Leave Requests List
            _buildLeaveRequestsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    final stats = _stats;
    final statItems = [
      {
        'label': 'Total Requests',
        'value': stats['total']!,
        'icon': Icons.calendar_today,
        'color': Colors.blue,
      },
      {
        'label': 'Pending',
        'value': stats['pending']!,
        'icon': Icons.access_time,
        'color': Colors.orange,
      },
      {
        'label': 'Approved',
        'value': stats['approved']!,
        'icon': Icons.check_circle,
        'color': Colors.green,
      },
      {
        'label': 'Rejected',
        'value': stats['rejected']!,
        'icon': Icons.cancel,
        'color': Colors.red,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: statItems.length,
      itemBuilder: (context, index) {
        final item = statItems[index];
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (item['color'] as Color).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    item['icon'] as IconData,
                    color: item['color'] as Color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item['label'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item['value']}',
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
          ),
        );
      },
    );
  }

  Widget _buildFilterButtons() {
    final filters = ['All', 'Pending', 'Approved', 'Rejected'];
    final stats = _stats;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: filters.map((filter) {
        final count = filter == 'All'
            ? null
            : stats[filter.toLowerCase()] ?? 0;

        return FilterChip(
          label: Text(
            count != null ? '$filter ($count)' : filter,
          ),
          selected: _filter == filter,
          onSelected: (selected) {
            if (selected) {
              setState(() => _filter = filter);
            }
          },
          selectedColor: Colors.blue.shade100,
          checkmarkColor: Colors.blue.shade700,
          labelStyle: TextStyle(
            color: _filter == filter ? Colors.blue.shade700 : Colors.black87,
            fontWeight:
                _filter == filter ? FontWeight.bold : FontWeight.normal,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        );
      }).toList(),
    );
  }

  Widget _buildLeaveRequestsList() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_filteredLeaves.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(48.0),
          child: Column(
            children: [
              Icon(
                Icons.calendar_today,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No leave requests found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _filter != 'All'
                    ? 'No ${_filter.toLowerCase()} leave requests.'
                    : 'No leave requests submitted yet.',
                style: TextStyle(
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Responsive grid: 1 column on mobile, 2 on tablet, 3 on desktop
    final crossAxisCount = MediaQuery.of(context).size.width > 1200
        ? 3
        : MediaQuery.of(context).size.width > 600
            ? 2
            : 1;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: crossAxisCount == 1 ? 0.95 : 0.75,
      ),
      itemCount: _filteredLeaves.length,
      itemBuilder: (context, index) {
        final leave = _filteredLeaves[index];
        return _buildLeaveCard(leave);
      },
    );
  }

  Widget _buildLeaveCard(Map<String, dynamic> leave) {
    final emp = _getEmployee(leave['email']?.toString());
    final status = leave['status']?.toString() ?? 'Unknown';
    final leaveId = leave['id']?.toString() ?? '';
    final isPending = status.toLowerCase() == 'pending';
    final isUpdating = _updatingLeaveId == leaveId;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
            // Header with name and status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    emp['fullname'] ?? 'Unknown',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusBgColor(status),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getStatusIcon(status),
                        size: 14,
                        color: _getStatusColor(status),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(status),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Employee details
            _buildInfoRow(
              Icons.email,
              leave['email']?.toString() ?? 'N/A',
            ),
            const SizedBox(height: 6),
            _buildInfoRow(
              Icons.business_center,
              emp['designation'] ?? 'N/A',
            ),
            const SizedBox(height: 6),
            _buildInfoRow(
              Icons.group,
              emp['department'] ?? 'N/A',
            ),
            const SizedBox(height: 6),
            _buildInfoRow(
              Icons.calendar_today,
              'Applied: ${_formatDate(leave['applied_on']?.toString())}',
            ),
            const SizedBox(height: 12),

            // Leave details
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Leave Details',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${leave['leave_type'] ?? 'N/A'} leave from ${_formatDate(leave['start_date']?.toString())} to ${_formatDate(leave['end_date']?.toString())}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text(
                        'Payment: ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (leave['paid_status']?.toString() ?? 'Paid')
                                      .toLowerCase() ==
                                  'unpaid'
                              ? Colors.orange.shade50
                              : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          leave['paid_status']?.toString() ?? 'Paid',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: (leave['paid_status']?.toString() ?? 'Paid')
                                        .toLowerCase() ==
                                    'unpaid'
                                ? Colors.orange.shade700
                                : Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Reason',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    leave['reason']?.toString() ?? 'No reason provided',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Action buttons for pending leaves
            if (isPending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isUpdating
                          ? null
                          : () => _updateLeaveStatus(leaveId, 'Approved'),
                      icon: isUpdating
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.check, size: 18),
                      label: const Text(
                        'Approve',
                        style: TextStyle(fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isUpdating
                          ? null
                          : () => _updateLeaveStatus(leaveId, 'Rejected'),
                      icon: isUpdating
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.close, size: 18),
                      label: const Text(
                        'Reject',
                        style: TextStyle(fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (isUpdating) ...[
                const SizedBox(height: 6),
                Text(
                  'Updating...',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

