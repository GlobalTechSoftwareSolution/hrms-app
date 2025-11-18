import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../layouts/dashboard_layout.dart';
import '../../services/api_service.dart';

class HrOffboardingScreen extends StatefulWidget {
  const HrOffboardingScreen({super.key});

  @override
  State<HrOffboardingScreen> createState() => _HrOffboardingScreenState();
}

class _HrOffboardingScreenState extends State<HrOffboardingScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  String _activeTab = 'active'; // 'active', 'applied', 'releaved'

  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _applied = [];
  List<Map<String, dynamic>> _releaved = [];

  Map<String, dynamic>? _selectedEmployee; // active or releaved

  Map<String, dynamic>? _removeTarget;
  String _terminationReason = '';
  DateTime? _terminationDate;
  bool _isRemoving = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    try {
      // Fetch employees and releaved records in parallel
      final employeesRes = await _apiService.get('/accounts/employees/');
      final releavedRes = await _apiService.get('/accounts/list_releaved/');

      List<Map<String, dynamic>> employees = [];
      if (employeesRes['success'] == true) {
        final data = employeesRes['data'];
        if (data is List) {
          employees = data.whereType<Map<String, dynamic>>().toList();
        }
      }

      List<Map<String, dynamic>> releaved = [];
      if (releavedRes['success'] == true) {
        final data = releavedRes['data'];
        if (data is List) {
          releaved = data.whereType<Map<String, dynamic>>().toList();
        } else if (data is Map && data['releaved'] is List) {
          releaved = (data['releaved'] as List)
              .whereType<Map<String, dynamic>>()
              .toList();
        }
      }

      // Apply the same business logic as the Next.js screen
      final applied = <Map<String, dynamic>>[];
      final releavedFinal = <Map<String, dynamic>>[];

      for (final emp in releaved) {
        final managerStatus = emp['manager_approved']?.toString().toLowerCase();
        final hrStatus = emp['hr_approved']?.toString().toLowerCase();
        final readyToReleve = emp['ready_to_releve'] == true;
        final offboardedAt = emp['offboarded_at'];

        final managerApproved =
            managerStatus == 'approved' || managerStatus == 'yes';

        if (!managerApproved) {
          continue; // manager must approve first
        }

        final hrActuallyApproved =
            hrStatus == 'approved' || hrStatus == 'yes' || hrStatus == 'true';
        final isReleaved = offboardedAt != null || readyToReleve;

        if (hrActuallyApproved && isReleaved) {
          releavedFinal.add(emp);
        } else {
          // pending/empty HR approval
          if (hrStatus == null ||
              hrStatus.isEmpty ||
              hrStatus == 'pending') {
            applied.add(emp);
          }
        }
      }

      setState(() {
        _employees = employees;
        _applied = applied;
        _releaved = releavedFinal;
      });
    } catch (e) {
      debugPrint('Error fetching offboarding data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load offboarding data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) return '—';
    try {
      final dt = DateTime.parse(value);
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {
      return value;
    }
  }

  String _formatDateObj(DateTime? value) {
    if (value == null) return '—';
    return DateFormat('dd/MM/yyyy').format(value);
  }

  Future<void> _handleHrApprove(Map<String, dynamic> emp, String status) async {
    final email = emp['email']?.toString() ?? '';
    final id = emp['id'];
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Employee ID not found for HR approval.')),
      );
      return;
    }

    final managerStatus = emp['manager_approved']?.toString().toLowerCase();
    final managerApproved =
        managerStatus == 'approved' || managerStatus == 'yes';
    if (!managerApproved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot process HR approval. Manager approval is required first.',
          ),
        ),
      );
      return;
    }

    try {
      setState(() => _isLoading = true);

      final res = await _apiService.patch(
        '/accounts/releaved/$id/',
        {
          'approval_stage': 'hr',
          'approved': status,
          'description': status == 'Approved'
              ? 'HR approved resignation after manager review'
              : 'HR rejected resignation after review',
        },
      );

      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('HR $status for $email recorded successfully')),
          );
        }
        await _fetchData();
      } else {
        final error = res['error'] ?? 'Failed to update HR approval';
        throw Exception(error);
      }
    } catch (e) {
      debugPrint('Error updating HR approval: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update HR approval: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleRemoveEmployee() async {
    if (_removeTarget == null ||
        _terminationReason.trim().isEmpty ||
        _terminationDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide date and reason.')),
      );
      return;
    }

    final target = _removeTarget!;
    final id = target['id'];
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Employee ID not found for removal.')),
      );
      return;
    }

    try {
      setState(() => _isRemoving = true);

      final res = await _apiService.patch(
        '/accounts/releaved/$id/',
        {
          'approval_stage': 'hr',
          'approved': 'Approved',
          'description': _terminationReason.trim(),
          // Backend can treat this as final offboarding marker; if it expects
          // a date field you can add it here.
        },
      );

      if (res['success'] != true) {
        final error = res['error'] ?? 'Failed to remove employee';
        throw Exception(error);
      }

      if (mounted) {
        Navigator.of(context).pop();
        setState(() {
          _removeTarget = null;
          _terminationReason = '';
          _terminationDate = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Employee offboarding recorded successfully')),
        );
        await _fetchData();
      }
    } catch (e) {
      debugPrint('Error removing employee: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove employee: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRemoving = false);
      }
    }
  }

  void _openRemoveDialog(Map<String, dynamic> emp) {
    setState(() {
      _removeTarget = emp;
      _terminationReason = '';
      _terminationDate = null;
    });

    showDialog(
      context: context,
      builder: (context) {
        final fullname = emp['fullname']?.toString() ?? emp['email']?.toString() ?? '';
        return AlertDialog(
          title: const Text('Remove Employee'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('You are about to remove $fullname from the system.'),
                const SizedBox(height: 12),
                Text('Termination Date', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: now,
                      firstDate: DateTime(now.year - 5),
                      lastDate: DateTime(now.year + 5),
                    );
                    if (picked != null) {
                      setState(() => _terminationDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _terminationDate == null
                              ? 'Select date'
                              : _formatDateObj(_terminationDate),
                          style: TextStyle(
                            color: _terminationDate == null
                                ? Colors.grey.shade500
                                : Colors.black,
                          ),
                        ),
                        const Icon(Icons.calendar_today, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Termination Reason', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                TextField(
                  minLines: 3,
                  maxLines: 4,
                  onChanged: (value) => _terminationReason = value,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    hintText: 'Please provide the reason for termination...',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isRemoving
                  ? null
                  : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isRemoving ? null : _handleRemoveEmployee,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              child: _isRemoving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirm Removal'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DashboardLayout(
      role: 'hr',
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade50,
              Colors.indigo.shade100,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildStatsRow(),
                            const SizedBox(height: 16),
                            _buildTabs(),
                            const SizedBox(height: 12),
                            if (_isLoading)
                              const Center(child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 24.0),
                                child: CircularProgressIndicator(),
                              ))
                            else
                              _buildContent(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Employee Offboarding',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${_employees.length} Active',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatCard(
                title: 'Active Employees',
                value: _employees.length.toString(),
                color: Colors.blue,
                icon: Icons.people,
              ),
              const SizedBox(height: 8),
              _buildStatCard(
                title: 'Applied for Relieve',
                value: _applied.length.toString(),
                color: Colors.orange,
                icon: Icons.hourglass_bottom,
              ),
              const SizedBox(height: 8),
              _buildStatCard(
                title: 'Releaved',
                value: _releaved.length.toString(),
                color: Colors.red,
                icon: Icons.logout,
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Active Employees',
                value: _employees.length.toString(),
                color: Colors.blue,
                icon: Icons.people,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'Applied for Relieve',
                value: _applied.length.toString(),
                color: Colors.orange,
                icon: Icons.hourglass_bottom,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'Releaved',
                value: _releaved.length.toString(),
                color: Colors.red,
                icon: Icons.logout,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
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
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          _buildTabButton('Active Employees', 'active'),
          _buildTabButton('Applied for Relieve', 'applied'),
          _buildTabButton('Releaved Employees', 'releaved'),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, String value) {
    final selected = _activeTab == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeTab = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? Colors.blue.shade50 : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.blue.shade700 : Colors.grey.shade700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_activeTab) {
      case 'active':
        if (_employees.isEmpty) {
          return _buildEmptyState('No active employees found.');
        }
        return _buildActiveList();
      case 'applied':
        if (_applied.isEmpty) {
          return _buildEmptyState('No employees have applied for relieve.');
        }
        return _buildAppliedList();
      case 'releaved':
        if (_releaved.isEmpty) {
          return _buildEmptyState('No releaved employees found.');
        }
        return _buildReleavedList();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildEmptyState(String message) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.info_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveList() {
    return Column(
      children: _employees.map((emp) => _buildActiveCard(emp)).toList(),
    );
  }

  Widget _buildActiveCard(Map<String, dynamic> emp) {
    final fullname = emp['fullname']?.toString() ?? 'Unknown';
    final email = emp['email']?.toString() ?? '';
    final department = emp['department']?.toString() ?? '—';
    final designation = emp['designation']?.toString() ?? '—';
    final profilePicture = emp['profile_picture']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.blue.shade100,
                  backgroundImage: profilePicture != null &&
                          profilePicture.isNotEmpty
                      ? NetworkImage(profilePicture)
                      : null,
                  child: (profilePicture == null || profilePicture.isEmpty)
                      ? Text(
                          fullname.isNotEmpty
                              ? fullname[0].toUpperCase()
                              : email.isNotEmpty
                                  ? email[0].toUpperCase()
                                  : 'U',
                          style: const TextStyle(color: Colors.blue),
                        )
                      : null,
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
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        email,
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
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Dept: $department',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Role: $designation',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => _openRemoveDialog(emp),
                icon: const Icon(Icons.logout, size: 16),
                label: const Text('Remove'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppliedList() {
    return Column(
      children: _applied.map((emp) => _buildAppliedCard(emp)).toList(),
    );
  }

  Widget _buildAppliedCard(Map<String, dynamic> emp) {
    final fullname = emp['fullname']?.toString() ?? 'Unknown';
    final email = emp['email']?.toString() ?? '';
    final department = emp['department']?.toString() ?? '—';
    final designation = emp['designation']?.toString() ?? '—';
    final profilePicture = emp['profile_picture']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.orange.shade100,
                  backgroundImage: profilePicture != null &&
                          profilePicture.isNotEmpty
                      ? NetworkImage(profilePicture)
                      : null,
                  child: (profilePicture == null || profilePicture.isEmpty)
                      ? Text(
                          fullname.isNotEmpty
                              ? fullname[0].toUpperCase()
                              : email.isNotEmpty
                                  ? email[0].toUpperCase()
                                  : 'U',
                          style: const TextStyle(color: Colors.orange),
                        )
                      : null,
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
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.yellow.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Pending HR',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.yellow.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Dept: $department',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Role: $designation',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _handleHrApprove(emp, 'Approved'),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _handleHrApprove(emp, 'Rejected'),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Reject'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReleavedList() {
    return Column(
      children: _releaved.map((emp) => _buildReleavedCard(emp)).toList(),
    );
  }

  Widget _buildReleavedCard(Map<String, dynamic> emp) {
    final fullname = emp['fullname']?.toString() ?? 'Unknown';
    final email = emp['email']?.toString() ?? '';
    final reason = emp['reason_for_resignation']?.toString() ??
        emp['description']?.toString() ??
        'Not specified';
    final releasedDate =
        _formatDate(emp['offboarded_at']?.toString() ?? emp['offboarded_datetime']?.toString());
    final profilePicture = emp['profile_picture']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.red.shade100,
                  backgroundImage: profilePicture != null &&
                          profilePicture.isNotEmpty
                      ? NetworkImage(profilePicture)
                      : null,
                  child: (profilePicture == null || profilePicture.isEmpty)
                      ? Text(
                          fullname.isNotEmpty
                              ? fullname[0].toUpperCase()
                              : email.isNotEmpty
                                  ? email[0].toUpperCase()
                                  : 'U',
                          style: const TextStyle(color: Colors.red),
                        )
                      : null,
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
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Releaved',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Reason: $reason',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              'Date: $releasedDate',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}
