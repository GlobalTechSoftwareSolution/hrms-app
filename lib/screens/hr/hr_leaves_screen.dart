import 'package:flutter/material.dart';

import '../../layouts/dashboard_layout.dart';
import '../../services/api_service.dart';

class HrLeavesScreen extends StatefulWidget {
  const HrLeavesScreen({super.key});

  @override
  State<HrLeavesScreen> createState() => _HrLeavesScreenState();
}

class _HrLeavesScreenState extends State<HrLeavesScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  String _error = '';

  // Leave status: Pending, Approved, Rejected
  final List<String> _tabs = const ['All', 'Pending', 'Approved', 'Rejected'];
  String _filter = 'All';

  List<Map<String, dynamic>> _leaves = [];

  // email -> employee info
  Map<String, Map<String, dynamic>> _employeeMap = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      await Future.wait([
        _fetchEmployees(),
        _fetchLeaves(),
      ]);
    } catch (e) {
      setState(() {
        _error = 'Failed to load leave data';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchEmployees() async {
    try {
      final response = await _apiService.get('/accounts/employees/');
      if (response['success'] == true) {
        final data = response['data'];
        final list = data is List
            ? List<Map<String, dynamic>>.from(data)
            : <Map<String, dynamic>>[];
        final map = <String, Map<String, dynamic>>{};
        for (final emp in list) {
          final email = emp['email']?.toString();
          if (email == null || email.isEmpty) continue;
          map[email] = Map<String, dynamic>.from(emp);
        }
        _employeeMap = map;
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _fetchLeaves() async {
    try {
      final response = await _apiService.get('/accounts/list_leaves/');
      if (response['success'] == true) {
        final data = response['data'];
        List<dynamic> rawLeaves;
        if (data is Map && data['leaves'] is List) {
          rawLeaves = data['leaves'];
        } else if (data is List) {
          rawLeaves = data;
        } else {
          rawLeaves = const [];
        }

        final mapped = <Map<String, dynamic>>[];
        int idx = 0;
        for (final item in rawLeaves) {
          if (item is! Map) continue;
          final map = Map<String, dynamic>.from(item);
          final start = (map['startDate'] ?? map['start_date'] ?? '').toString();
          final end = (map['endDate'] ?? map['end_date'] ?? '').toString();
          final email = map['email']?.toString() ?? '';
          mapped.add({
            'id': map['id'] ?? idx + 1,
            'employeeId': map['employeeId'] ?? email,
            'name': map['name'] ?? (email.isNotEmpty ? email.split('@')[0] : ''),
            'email': email,
            'reason': map['reason']?.toString() ?? '',
            'startDate': start,
            'endDate': end,
            'status': (map['status'] ?? 'Pending').toString(),
            'submittedDate': (map['submittedDate'] ?? map['submitted_date'] ?? start)
                .toString(),
          });
          idx++;
        }

        // Enrich with employee name and pic if we have it
        for (final leave in mapped) {
          final email = leave['email'] as String? ?? '';
          final emp = _employeeMap[email];
          if (emp != null) {
            leave['name'] = emp['fullname']?.toString() ?? leave['name'];
            leave['profile_picture'] = emp['profile_picture'];
          }
        }

        _leaves = mapped;
      }
    } catch (_) {
      rethrow;
    }
  }

  int _calculateDays(String start, String end) {
    try {
      final s = DateTime.parse(start);
      final e = DateTime.parse(end);
      final diff = e.difference(s).inDays + 1;
      return diff > 0 ? diff : 1;
    } catch (_) {
      return 1;
    }
  }

  String _profileImageUrl(dynamic value) {
    final pic = value?.toString() ?? '';
    if (pic.isEmpty) return '';
    if (pic.startsWith('http')) return pic;
    return '${ApiService.baseUrl}/$pic';
  }

  List<Map<String, dynamic>> get _filteredLeaves {
    if (_filter == 'All') return _leaves;
    return _leaves
        .where((l) => (l['status']?.toString() ?? '') == _filter)
        .toList();
  }

  String _formatDate(String value) {
    if (value.isEmpty) return 'N/A';
    try {
      final d = DateTime.parse(value);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DashboardLayout(
      role: 'hr',
      child: Container(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _isLoading
              ? _buildLoading()
              : _error.isNotEmpty
                  ? Center(
                      child: Text(
                        _error,
                        style: const TextStyle(color: Colors.red),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Employee Leave Requests',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildTabs(),
                        const SizedBox(height: 12),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final isMobile = constraints.maxWidth < 600;
                              final leaves = _filteredLeaves;
                              if (leaves.isEmpty) {
                                return _buildEmptyState();
                              }
                              return isMobile
                                  ? _buildCards(leaves)
                                  : _buildTable(leaves);
                            },
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text('Loading leave requests...'),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _tabs.map((tab) {
          final isActive = _filter == tab;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(tab),
              selected: isActive,
              onSelected: (_) {
                setState(() {
                  _filter = tab;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.inbox, size: 40, color: Colors.grey),
          SizedBox(height: 8),
          Text('No leave requests found'),
        ],
      ),
    );
  }

  Widget _buildTable(List<Map<String, dynamic>> leaves) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 16,
          columns: const [
            DataColumn(label: Text('Employee')),
            DataColumn(label: Text('Reason')),
            DataColumn(label: Text('Period')),
            DataColumn(label: Text('Days')),
            DataColumn(label: Text('Submitted')),
            DataColumn(label: Text('Status')),
          ],
          rows: leaves.map((leave) {
            final email = leave['email']?.toString() ?? '';
            final pic = _profileImageUrl(leave['profile_picture']);
            final name = leave['name']?.toString() ?? '';
            final start = leave['startDate']?.toString() ?? '';
            final end = leave['endDate']?.toString() ?? '';
            final status = leave['status']?.toString() ?? 'Pending';
            return DataRow(cells: [
              DataCell(
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage:
                          pic.isNotEmpty ? NetworkImage(pic) : null,
                      child: pic.isEmpty
                          ? Text(
                              name.isNotEmpty
                                  ? name.trim().substring(0, 1).toUpperCase()
                                  : '?',
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isNotEmpty ? name : 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          email,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              DataCell(
                SizedBox(
                  width: 160,
                  child: Text(
                    leave['reason']?.toString() ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              DataCell(Text('${_formatDate(start)} → ${_formatDate(end)}')),
              DataCell(
                Center(
                  child:
                      Text(_calculateDays(start, end).toString()),
                ),
              ),
              DataCell(Text(_formatDate(
                  leave['submittedDate']?.toString() ?? ''))),
              DataCell(_buildStatusChip(status)),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg;
    Color fg;
    switch (status) {
      case 'Approved':
        bg = Colors.green.shade100;
        fg = Colors.green.shade800;
        break;
      case 'Rejected':
        bg = Colors.red.shade100;
        fg = Colors.red.shade800;
        break;
      default:
        bg = Colors.yellow.shade100;
        fg = Colors.yellow.shade800;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 12, color: fg),
      ),
    );
  }

  Widget _buildCards(List<Map<String, dynamic>> leaves) {
    return ListView.builder(
      itemCount: leaves.length,
      itemBuilder: (context, index) {
        final leave = leaves[index];
        final email = leave['email']?.toString() ?? '';
        final pic = _profileImageUrl(leave['profile_picture']);
        final name = leave['name']?.toString() ?? '';
        final start = leave['startDate']?.toString() ?? '';
        final end = leave['endDate']?.toString() ?? '';
        final status = leave['status']?.toString() ?? 'Pending';

        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage:
                          pic.isNotEmpty ? NetworkImage(pic) : null,
                      child: pic.isEmpty
                          ? Text(
                              name.isNotEmpty
                                  ? name.trim().substring(0, 1).toUpperCase()
                                  : '?',
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isNotEmpty ? name : 'Unknown',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            email,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusChip(status),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  leave['reason']?.toString() ?? '',
                  style: const TextStyle(fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_formatDate(start)} → ${_formatDate(end)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      '${_calculateDays(start, end)} days',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
