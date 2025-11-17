import 'dart:convert';

import 'package:flutter/material.dart';

import '../../layouts/dashboard_layout.dart';
import '../../services/api_service.dart';
import '../../utils/file_viewer.dart';

class HrEmployeesScreen extends StatefulWidget {
  const HrEmployeesScreen({super.key});

  @override
  State<HrEmployeesScreen> createState() => _HrEmployeesScreenState();
}

class _HrEmployeesScreenState extends State<HrEmployeesScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  String _error = '';

  List<Map<String, dynamic>> _employees = [];
  Map<String, Map<String, dynamic>> _payrollByEmail = {};
  Map<String, List<Map<String, dynamic>>> _documentsByEmail = {};
  Map<String, List<Map<String, dynamic>>> _awardsByEmail = {};

  String _searchTerm = '';
  String _filterDepartment = 'all';
  String _sortKey = 'fullname';
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
    _fetchAwards();
  }

  Future<void> _fetchEmployees() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final response = await _apiService.get('/accounts/employees/');
      if (response['success'] == true) {
        final data = response['data'];
        final list = data is List
            ? List<Map<String, dynamic>>.from(data)
            : <Map<String, dynamic>>[];
        setState(() {
          _employees = list;
        });

        // Preload payroll data like web
        for (final emp in list) {
          final email = emp['email']?.toString();
          if (email != null && email.isNotEmpty) {
            _fetchPayrollForEmployee(email);
          }
        }
      } else {
        throw Exception('Failed to fetch employees');
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to fetch employee data';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchPayrollForEmployee(String email) async {
    try {
      final response = await _apiService.get('/accounts/get_payroll/$email/');
      if (response['success'] == true) {
        final data = response['data'];
        if (data is Map && data['payrolls'] is List && data['payrolls'].isNotEmpty) {
          final payroll = Map<String, dynamic>.from(data['payrolls'][0]);
          if (mounted) {
            setState(() {
              _payrollByEmail[email] = payroll;
            });
          }
        }
      }
    } catch (_) {
      // Ignore individual payroll errors
    }
  }

  Future<void> _fetchDocumentsForEmployee(String email) async {
    if (_documentsByEmail.containsKey(email)) return; // already loaded

    try {
      final response = await _apiService.get('/accounts/get_document/$email/');
      if (response['success'] == true) {
        final data = response['data'];
        if (data is List && data.isNotEmpty && data[0] is Map) {
          final record = Map<String, dynamic>.from(data[0]);
          const keys = [
            'resume',
            'appointment_letter',
            'offer_letter',
            'bonafide_crt',
            'tenth',
            'twelth',
            'degree',
            'masters',
            'marks_card',
            'certificates',
            'award',
            'id_proof',
            'releaving_letter',
            'resignation_letter',
            'achievement_crt',
          ];

          final docs = <Map<String, dynamic>>[];
          int id = 0;
          for (final key in keys) {
            final value = record[key];
            if (value != null && value.toString().isNotEmpty) {
              docs.add({
                'id': id++,
                'document_name': key.replaceAll('_', ' ').toUpperCase(),
                'document_file': value.toString(),
              });
            }
          }

          if (mounted) {
            setState(() {
              _documentsByEmail[email] = docs;
            });
          }
        }
      }
    } catch (_) {
      // Ignore document errors for now
    }
  }

  Future<void> _fetchAwards() async {
    try {
      final response = await _apiService.get('/accounts/list_awards/');
      if (response['success'] == true) {
        final data = response['data'];
        if (data is List) {
          final byEmail = <String, List<Map<String, dynamic>>>{};
          for (final item in data) {
            if (item is Map<String, dynamic>) {
              final email = item['email']?.toString();
              if (email == null || email.isEmpty) continue;
              byEmail.putIfAbsent(email, () => []);
              byEmail[email]!.add(item);
            }
          }
          if (mounted) {
            setState(() {
              _awardsByEmail = byEmail;
            });
          }
        }
      }
    } catch (_) {
      // Ignore awards errors
    }
  }

  List<Map<String, dynamic>> get _filteredEmployees {
    final term = _searchTerm.toLowerCase();
    return _employees.where((emp) {
      final name = emp['fullname']?.toString().toLowerCase() ?? '';
      final email = emp['email']?.toString().toLowerCase() ?? '';
      final designation = emp['designation']?.toString().toLowerCase() ?? '';
      final dept = emp['department']?.toString();

      final matchesSearch =
          name.contains(term) || email.contains(term) || designation.contains(term);
      final matchesDept =
          _filterDepartment == 'all' || dept == _filterDepartment;
      return matchesSearch && matchesDept;
    }).toList();
  }

  List<Map<String, dynamic>> get _sortedEmployees {
    final list = List<Map<String, dynamic>>.from(_filteredEmployees);
    list.sort((a, b) {
      final av = a[_sortKey];
      final bv = b[_sortKey];
      if (av == null || bv == null) return 0;
      final cmp = av.toString().compareTo(bv.toString());
      return _sortAscending ? cmp : -cmp;
    });
    return list;
  }

  String _profileImageUrl(dynamic value) {
    final pic = value?.toString() ?? '';
    if (pic.isEmpty) return '';
    if (pic.startsWith('http')) return pic;
    return '${ApiService.baseUrl}/$pic';
  }

  List<String> get _departments {
    final set = <String>{};
    for (final emp in _employees) {
      final dept = emp['department']?.toString();
      if (dept != null && dept.isNotEmpty) set.add(dept);
    }
    return set.toList()..sort();
  }

  void _requestSort(String key) {
    setState(() {
      if (_sortKey == key) {
        _sortAscending = !_sortAscending;
      } else {
        _sortKey = key;
        _sortAscending = true;
      }
    });
  }

  String _formatDate(dynamic value) {
    if (value == null) return 'N/A';
    try {
      final date = DateTime.parse(value.toString());
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {
      return value.toString();
    }
  }

  String _formatSalary(dynamic amount) {
    if (amount == null || amount.toString().isEmpty) return 'N/A';
    try {
      final numValue = num.parse(amount.toString());
      return '₹${numValue.toStringAsFixed(0)}';
    } catch (_) {
      return amount.toString();
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
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Employee Management',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Search & filter
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          TextField(
                            decoration: const InputDecoration(
                              labelText: 'Search employees',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _searchTerm = value;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: _filterDepartment,
                            items: [
                              const DropdownMenuItem(
                                value: 'all',
                                child: Text('All Departments'),
                              ),
                              ..._departments.map(
                                (d) => DropdownMenuItem(
                                  value: d,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(d),
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _filterDepartment = value;
                              });
                            },
                            decoration: const InputDecoration(
                              labelText: 'Department',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (_isLoading)
                    const Expanded(
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_error.isNotEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          _error,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    )
              else if (_sortedEmployees.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text(
                      'No employees found matching your criteria.',
                    ),
                  ),
                )
              else
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;
                      return isMobile
                          ? _buildEmployeesCards()
                          : _buildEmployeesTable();
                    },
                  ),
                ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeesTable() {
    final rows = _sortedEmployees;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 16,
            columns: [
              DataColumn(
                label: const Text('Employee'),
                onSort: (_, __) => _requestSort('fullname'),
              ),
              const DataColumn(label: Text('Designation')),
              const DataColumn(label: Text('Department')),
              const DataColumn(label: Text('Salary')),
              const DataColumn(label: Text('Join Date')),
              const DataColumn(label: Text('Actions')),
            ],
            rows: rows.map((emp) {
              final email = emp['email']?.toString() ?? '';
              final payroll = _payrollByEmail[email];
              return DataRow(cells: [
                DataCell(
                  Row(
                    children: [
                      Builder(
                        builder: (context) {
                          final pic = _profileImageUrl(emp['profile_picture']);
                          final initial = (emp['fullname']?.toString() ?? 'U')
                              .trim()
                              .isNotEmpty
                              ? emp['fullname']
                                  .toString()
                                  .trim()
                                  .substring(0, 1)
                                  .toUpperCase()
                              : 'U';
                          return CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.blue.shade100,
                            backgroundImage:
                                pic.isNotEmpty ? NetworkImage(pic) : null,
                            child: pic.isEmpty
                                ? Text(
                                    initial,
                                    style: const TextStyle(color: Colors.blue),
                                  )
                                : null,
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            emp['fullname']?.toString() ?? '',
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
                DataCell(Text(emp['designation']?.toString() ?? 'N/A')),
                DataCell(Text(emp['department']?.toString() ?? 'N/A')),
                DataCell(Text(_formatSalary(payroll?['basic_salary']))),
                DataCell(Text(_formatDate(emp['date_joined']))),
                DataCell(
                  TextButton.icon(
                    onPressed: () async {
                      final theEmail = emp['email']?.toString();
                      if (theEmail != null) {
                        await _fetchDocumentsForEmployee(theEmail);
                      }
                      _showEmployeeDetailsDialog(emp);
                    },
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View'),
                  ),
                ),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeesCards() {
    final rows = _sortedEmployees;
    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final emp = rows[index];
        final email = emp['email']?.toString() ?? '';
        final payroll = _payrollByEmail[email];
        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Builder(
                      builder: (context) {
                        final pic = _profileImageUrl(emp['profile_picture']);
                        final initial = (emp['fullname']?.toString() ?? 'U')
                            .trim()
                            .isNotEmpty
                            ? emp['fullname']
                                .toString()
                                .trim()
                                .substring(0, 1)
                                .toUpperCase()
                            : 'U';
                        return CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.blue.shade100,
                          backgroundImage:
                              pic.isNotEmpty ? NetworkImage(pic) : null,
                          child: pic.isEmpty
                              ? Text(
                                  initial,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.blue,
                                  ),
                                )
                              : null,
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            emp['fullname']?.toString() ?? '',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
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
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Designation',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            emp['designation']?.toString() ?? 'N/A',
                            style: const TextStyle(fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Department',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            emp['department']?.toString() ?? 'N/A',
                            style: const TextStyle(fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Salary',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            _formatSalary(payroll?['basic_salary']),
                            style: const TextStyle(fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Joined',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            _formatDate(emp['date_joined']),
                            style: const TextStyle(fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () async {
                      final theEmail = emp['email']?.toString();
                      if (theEmail != null) {
                        await _fetchDocumentsForEmployee(theEmail);
                      }
                      _showEmployeeDetailsDialog(emp);
                    },
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View Details'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showEmployeeDetailsDialog(Map<String, dynamic> emp) async {
    final email = emp['email']?.toString() ?? '';
    final payroll = _payrollByEmail[email];
    final docs = _documentsByEmail[email] ?? const [];
    final awards = _awardsByEmail[email] ?? const [];

    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 700,
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Employee Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          (emp['fullname']?.toString() ?? 'U').isNotEmpty
                              ? emp['fullname']
                                  .toString()
                                  .trim()
                                  .substring(0, 1)
                                  .toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            fontSize: 20,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              emp['fullname']?.toString() ?? '',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              email,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _infoChip('Designation', emp['designation']),
                      _infoChip('Department', emp['department']),
                      _infoChip('Phone', emp['phone']),
                      _infoChip('Joined', _formatDate(emp['date_joined'])),
                      _infoChip('Salary', _formatSalary(payroll?['basic_salary'])),
                    ],
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'Documents',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (docs.isEmpty)
                    const Text(
                      'No documents found.',
                      style: TextStyle(color: Colors.grey),
                    )
                  else
                    SizedBox(
                      height: 150,
                      child: ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(doc['document_name']?.toString() ?? ''),
                            trailing: TextButton(
                              onPressed: () {
                                final url = doc['document_file']?.toString() ?? '';
                                openRemoteFile(context, url, title: 'Document');
                              },
                              child: const Text('View'),
                            ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 16),

                  const Text(
                    'Awards',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (awards.isEmpty)
                    const Text(
                      'No awards found.',
                      style: TextStyle(color: Colors.grey),
                    )
                  else
                    SizedBox(
                      height: 150,
                      child: ListView.builder(
                        itemCount: awards.length,
                        itemBuilder: (context, index) {
                          final award = awards[index];
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(award['title']?.toString() ?? ''),
                            subtitle: Text(
                              award['description']?.toString() ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Text(
                              _formatDate(award['created_at'] ?? award['date']),
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 12),

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
      },
    );
  }

  Widget _infoChip(String label, dynamic value) {
    final text = value == null || value.toString().isEmpty
        ? 'N/A'
        : value.toString();
    return Chip(
      label: Text('$label: $text'),
      backgroundColor: Colors.grey.shade100,
    );
  }
}
