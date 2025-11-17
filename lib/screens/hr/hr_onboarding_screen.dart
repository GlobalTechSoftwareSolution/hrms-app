import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../layouts/dashboard_layout.dart';
import '../../services/api_service.dart';

class HrEmployee {
  final int id;
  final String email;
  final String fullname;
  final int? age;
  final String? phone;
  final String? department;
  final String? designation;
  final String? dateOfBirth;
  final String? dateJoined;
  final String? skills;
  final String? profilePicture;
  final String? reportsTo;
  final String status; // 'active' | 'pending'

  HrEmployee({
    required this.id,
    required this.email,
    required this.fullname,
    this.age,
    this.phone,
    this.department,
    this.designation,
    this.dateOfBirth,
    this.dateJoined,
    this.skills,
    this.profilePicture,
    this.reportsTo,
    required this.status,
  });

  factory HrEmployee.fromJson(Map<String, dynamic> json) {
    return HrEmployee(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      email: json['email']?.toString() ?? '',
      fullname: json['fullname']?.toString() ?? '',
      age: json['age'] is int ? json['age'] as int : int.tryParse(json['age']?.toString() ?? ''),
      phone: json['phone']?.toString(),
      department: json['department']?.toString(),
      designation: json['designation']?.toString(),
      dateOfBirth: json['date_of_birth']?.toString(),
      dateJoined: json['date_joined']?.toString(),
      skills: json['skills']?.toString(),
      profilePicture: json['profile_picture']?.toString(),
      reportsTo: json['reports_to']?.toString(),
      status: json['status']?.toString() ?? 'active',
    );
  }
}

class HrPendingUser {
  final int id;
  final String email;
  final String fullname;
  final bool isStaff;
  final String? userType;
  final String? role;

  HrPendingUser({
    required this.id,
    required this.email,
    required this.fullname,
    required this.isStaff,
    this.userType,
    this.role,
  });

  factory HrPendingUser.fromJson(Map<String, dynamic> json) {
    return HrPendingUser(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      email: json['email']?.toString() ?? '',
      fullname: json['fullname']?.toString() ?? '',
      isStaff: json['is_staff'] == true,
      userType: json['user_type']?.toString(),
      role: json['role']?.toString(),
    );
  }
}

enum HrActiveTab { all, pending }

enum HrSortKey { fullname, designation, department, dateJoined }

class HrOnboardingScreen extends StatefulWidget {
  const HrOnboardingScreen({super.key});

  @override
  State<HrOnboardingScreen> createState() => _HrOnboardingScreenState();
}

class _HrOnboardingScreenState extends State<HrOnboardingScreen> {
  final ApiService _apiService = ApiService();

  List<HrEmployee> _employees = [];
  List<HrPendingUser> _pendingUsers = [];

  bool _isLoading = true;
  String? _error;

  String _searchTerm = '';
  String _filterDepartment = 'all';

  HrActiveTab _activeTab = HrActiveTab.all;
  HrSortKey? _sortKey;
  bool _sortAscending = true;

  // Onboard form
  final TextEditingController _onboardEmailController = TextEditingController();
  final TextEditingController _onboardPasswordController = TextEditingController();
  bool _isSubmittingOnboard = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _onboardEmailController.dispose();
    _onboardPasswordController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Employees
      final empRes = await _apiService.get('/accounts/employees/');
      List<HrEmployee> employees = [];
      if (empRes['success'] == true) {
        final data = empRes['data'];
        final list = data is List ? data : (data is Map && data['results'] is List ? data['results'] : []);
        employees = List<Map<String, dynamic>>.from(list)
            .map((e) => HrEmployee.fromJson(e))
            .toList();
      }

      // Users
      final userRes = await _apiService.get('/accounts/users/');
      List<HrPendingUser> pendingUsers = [];
      if (userRes['success'] == true) {
        final data = userRes['data'];
        final list = data is List ? data : (data is Map && data['results'] is List ? data['results'] : []);
        final allUsers = List<Map<String, dynamic>>.from(list)
            .map((e) => HrPendingUser.fromJson(e))
            .toList();

        pendingUsers = allUsers
            .where((user) {
              final role = user.userType ?? user.role;
              return role == 'employee' && !user.isStaff;
            })
            .toList();
      }

      setState(() {
        _employees = employees;
        _pendingUsers = pendingUsers;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to fetch employee data: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onboardNewEmployee() async {
    final email = _onboardEmailController.text.trim();
    final password = _onboardPasswordController.text.trim();
    if (email.isEmpty || password.isEmpty) return;

    setState(() {
      _isSubmittingOnboard = true;
    });

    try {
      final payload = {
        'email': email,
        'password': password,
        'role': 'employee',
      };

      final res = await _apiService.post('/accounts/signup/', payload);

      if (res['success'] != true) {
        String msg = 'Failed to onboard employee';
        final data = res['data'];
        if (data is Map && data['detail'] is String) {
          msg = data['detail'] as String;
        }
        throw Exception(msg);
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Employee onboarded successfully')),
      );
      _onboardEmailController.clear();
      _onboardPasswordController.clear();
      await _fetchData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to onboard employee: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingOnboard = false;
        });
      }
    }
  }

  Future<void> _approveEmployee(HrPendingUser user) async {
    try {
      final res = await _apiService.patch('/accounts/users/${user.id}/', {
        'is_staff': true,
      });

      if (res['success'] != true) {
        throw Exception('HTTP error while approving employee');
      }

      setState(() {
        _pendingUsers.removeWhere((u) => u.id == user.id);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.fullname} has been approved as an employee')),
      );

      await _fetchData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to approve employee: $e')),
      );
    }
  }

  void _openOnboardDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('Onboard New Employee'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _onboardEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _onboardPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        hintText: 'employee',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isSubmittingOnboard
                      ? null
                      : () {
                          Navigator.of(context).pop();
                        },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _isSubmittingOnboard
                      ? null
                      : () async {
                          setLocalState(() {});
                          await _onboardNewEmployee();
                        },
                  child: _isSubmittingOnboard
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add Employee'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _setSort(HrSortKey key) {
    setState(() {
      if (_sortKey == key) {
        _sortAscending = !_sortAscending;
      } else {
        _sortKey = key;
        _sortAscending = true;
      }
    });
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();
      return '$day/$month/$year';
    } catch (_) {
      return 'N/A';
    }
  }

  List<String> get _departments {
    final set = <String>{};
    for (final emp in _employees) {
      final dept = emp.department;
      if (dept != null && dept.isNotEmpty) set.add(dept);
    }
    final list = set.toList();
    list.sort();
    return list;
  }

  List<HrEmployee> get _filteredEmployees {
    final term = _searchTerm.toLowerCase();
    return _employees.where((emp) {
      final matchesSearch =
          emp.fullname.toLowerCase().contains(term) ||
          emp.email.toLowerCase().contains(term) ||
          (emp.designation ?? '').toLowerCase().contains(term);
      final matchesDept =
          _filterDepartment == 'all' || emp.department == _filterDepartment;
      return matchesSearch && matchesDept;
    }).toList();
  }

  List<HrPendingUser> get _filteredPendingUsers {
    final term = _searchTerm.toLowerCase();
    return _pendingUsers.where((user) {
      return user.fullname.toLowerCase().contains(term) ||
          user.email.toLowerCase().contains(term);
    }).toList();
  }

  List<HrEmployee> get _sortedEmployees {
    final list = List<HrEmployee>.from(_filteredEmployees);
    if (_sortKey == null || _activeTab != HrActiveTab.all) {
      return list;
    }
    list.sort((a, b) {
      int cmp = 0;
      switch (_sortKey!) {
        case HrSortKey.fullname:
          cmp = a.fullname.compareTo(b.fullname);
          break;
        case HrSortKey.designation:
          cmp = (a.designation ?? '').compareTo(b.designation ?? '');
          break;
        case HrSortKey.department:
          cmp = (a.department ?? '').compareTo(b.department ?? '');
          break;
        case HrSortKey.dateJoined:
          cmp = (a.dateJoined ?? '').compareTo(b.dateJoined ?? '');
          break;
      }
      return _sortAscending ? cmp : -cmp;
    });
    return list;
  }

  void _showEmployeeDetails(HrEmployee emp, {bool canEdit = true}) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Employee Details'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  emp.fullname,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(emp.email),
                const SizedBox(height: 12),
                _detailRow('Designation', emp.designation),
                _detailRow('Department', emp.department),
                _detailRow('Phone', emp.phone),
                _detailRow('Date of Birth', _formatDate(emp.dateOfBirth)),
                _detailRow('Date Joined', _formatDate(emp.dateJoined)),
                _detailRow('Reports To', emp.reportsTo),
                _detailRow('Skills', emp.skills),
              ],
            ),
          ),
          actions: [
            if (canEdit)
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _showEditEmployeeDialog(emp);
                },
                child: const Text('Edit'),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showPendingUserDetails(HrPendingUser user) {
    final empData = _employees.firstWhere(
      (emp) => emp.email == user.email,
      orElse: () => HrEmployee(
        id: user.id,
        email: user.email,
        fullname: user.fullname,
        age: null,
        phone: null,
        department: null,
        designation: null,
        dateOfBirth: null,
        dateJoined: null,
        skills: null,
        profilePicture: null,
        reportsTo: null,
        status: 'pending',
      ),
    );
    _showEmployeeDetails(empData, canEdit: false);
  }

  void _showEditEmployeeDialog(HrEmployee emp) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final fullNameCtrl = TextEditingController(text: emp.fullname);
        final phoneCtrl = TextEditingController(text: emp.phone ?? '');
        final deptCtrl = TextEditingController(text: emp.department ?? '');
        final desigCtrl = TextEditingController(text: emp.designation ?? '');
        final dobCtrl = TextEditingController(text: emp.dateOfBirth ?? '');
        final joinedCtrl = TextEditingController(text: emp.dateJoined ?? '');
        final reportsCtrl = TextEditingController(text: emp.reportsTo ?? '');
        final skillsCtrl = TextEditingController(text: emp.skills ?? '');

        XFile? pickedImage;
        bool isSaving = false;

        return StatefulBuilder(
          builder: (context, setLocalState) {
            Future<void> saveChanges() async {
              setLocalState(() => isSaving = true);

              try {
                final uri = Uri.parse('${ApiService.baseUrl}/accounts/employees/${emp.email}/');
                final request = http.MultipartRequest('PUT', uri);

                // Auth header
                final token = await _apiService.getToken();
                if (token != null && token.isNotEmpty) {
                  request.headers['Authorization'] = 'Bearer $token';
                }

                request.fields['email'] = emp.email;
                request.fields['fullname'] = fullNameCtrl.text.trim().isNotEmpty
                    ? fullNameCtrl.text.trim()
                    : emp.fullname;
                request.fields['phone'] = phoneCtrl.text.trim().isNotEmpty
                    ? phoneCtrl.text.trim()
                    : (emp.phone ?? '');
                request.fields['department'] = deptCtrl.text.trim().isNotEmpty
                    ? deptCtrl.text.trim()
                    : (emp.department ?? '');
                request.fields['designation'] = desigCtrl.text.trim().isNotEmpty
                    ? desigCtrl.text.trim()
                    : (emp.designation ?? '');
                request.fields['date_of_birth'] = dobCtrl.text.trim().isNotEmpty
                    ? dobCtrl.text.trim()
                    : (emp.dateOfBirth ?? '');
                request.fields['date_joined'] = joinedCtrl.text.trim().isNotEmpty
                    ? joinedCtrl.text.trim()
                    : (emp.dateJoined ?? '');
                request.fields['skills'] = skillsCtrl.text.trim().isNotEmpty
                    ? skillsCtrl.text.trim()
                    : (emp.skills ?? '');
                request.fields['reports_to'] = reportsCtrl.text.trim().isNotEmpty
                    ? reportsCtrl.text.trim()
                    : (emp.reportsTo ?? '');

                if (pickedImage != null) {
                  request.files.add(
                    await http.MultipartFile.fromPath(
                      'profile_picture',
                      pickedImage!.path,
                    ),
                  );
                } else if (emp.profilePicture != null && emp.profilePicture!.isNotEmpty) {
                  request.fields['profile_picture'] = emp.profilePicture!;
                }

                final streamedResponse = await request.send();

                if (streamedResponse.statusCode < 200 || streamedResponse.statusCode >= 300) {
                  final respBody = await streamedResponse.stream.bytesToString();
                  throw Exception('Failed to update employee: ${streamedResponse.statusCode} $respBody');
                }

                final respBody = await streamedResponse.stream.bytesToString();
                final Map<String, dynamic> json = jsonDecode(respBody) as Map<String, dynamic>;
                final updatedEmp = HrEmployee.fromJson(json);

                if (!mounted) return;
                setState(() {
                  _employees = _employees
                      .map((e) => e.email == updatedEmp.email ? updatedEmp : e)
                      .toList();
                });

                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Employee updated successfully')),
                );
              } catch (e) {
                setLocalState(() => isSaving = false);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to update employee: $e')),
                );
              }
            }

            Future<void> pickImage() async {
              final picker = ImagePicker();
              final XFile? img = await picker.pickImage(source: ImageSource.gallery);
              if (img != null) {
                setLocalState(() {
                  pickedImage = img;
                });
              }
            }

            return AlertDialog(
              title: const Text('Edit Employee'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundImage: pickedImage != null
                              ? FileImage(File(pickedImage!.path)) as ImageProvider
                              : (emp.profilePicture != null && emp.profilePicture!.isNotEmpty)
                                  ? NetworkImage(emp.profilePicture!)
                                  : null,
                          child: (pickedImage == null &&
                                  (emp.profilePicture == null || emp.profilePicture!.isEmpty))
                              ? Text(
                                  emp.fullname.isNotEmpty ? emp.fullname[0].toUpperCase() : '?',
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        TextButton.icon(
                          onPressed: pickImage,
                          icon: const Icon(Icons.image),
                          label: const Text('Change Picture'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: fullNameCtrl,
                      decoration: const InputDecoration(labelText: 'Full Name'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(labelText: 'Phone'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: desigCtrl,
                      decoration: const InputDecoration(labelText: 'Designation'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: deptCtrl,
                      decoration: const InputDecoration(labelText: 'Department'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: dobCtrl,
                      decoration: const InputDecoration(labelText: 'Date of Birth (YYYY-MM-DD)'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: joinedCtrl,
                      decoration: const InputDecoration(labelText: 'Date Joined (YYYY-MM-DD)'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: reportsCtrl,
                      decoration: const InputDecoration(labelText: 'Reports To'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: skillsCtrl,
                      decoration: const InputDecoration(labelText: 'Skills'),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : saveChanges,
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _detailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Expanded(
            child: Text(value == null || value.isEmpty ? 'N/A' : value),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DashboardLayout(
      role: 'hr',
      child: Container(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Header + button
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Employee Management',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: _openOnboardDialog,
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Onboard New Employee'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tabs
              Row(
                children: [
                  _TabButton(
                    label: 'All Employees (${_employees.length})',
                    selected: _activeTab == HrActiveTab.all,
                    onTap: () {
                      setState(() => _activeTab = HrActiveTab.all);
                    },
                  ),
                  const SizedBox(width: 8),
                  _TabButton(
                    label: 'Pending Approval (${_pendingUsers.length})',
                    selected: _activeTab == HrActiveTab.pending,
                    onTap: () {
                      setState(() => _activeTab = HrActiveTab.pending);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Search + filter
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
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                labelText: _activeTab == HrActiveTab.pending
                                    ? 'Search pending users...'
                                    : 'Search employees...',
                                prefixIcon: const Icon(Icons.search),
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _searchTerm = value;
                                });
                              },
                            ),
                          ),
                          if (_activeTab == HrActiveTab.all) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
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
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              if (_isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Expanded(
                  child: Center(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;
                      if (_activeTab == HrActiveTab.pending) {
                        final pending = _filteredPendingUsers;
                        if (pending.isEmpty) {
                          return const Center(
                            child: Text(
                              'No pending users found matching your criteria',
                              style: TextStyle(color: Colors.grey),
                            ),
                          );
                        }
                        return isMobile
                            ? _buildPendingMobileList(pending)
                            : _buildPendingDesktopTable(pending);
                      } else {
                        final employees = _sortedEmployees;
                        if (employees.isEmpty) {
                          return const Center(
                            child: Text(
                              'No employees found matching your criteria',
                              style: TextStyle(color: Colors.grey),
                            ),
                          );
                        }
                        return isMobile
                            ? _buildEmployeeMobileList(employees)
                            : _buildEmployeeDesktopTable(employees);
                      }
                    },
                  ),
                ),

              if (!_isLoading && _error == null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _activeTab == HrActiveTab.pending
                        ? 'Showing ${_filteredPendingUsers.length} of ${_pendingUsers.length} pending users'
                        : 'Showing ${_sortedEmployees.length} of ${_employees.length} employees',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeDesktopTable(List<HrEmployee> employees) {
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
                label: InkWell(
                  onTap: () => _setSort(HrSortKey.fullname),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Employee'),
                      if (_sortKey == HrSortKey.fullname)
                        Icon(_sortAscending ? Icons.arrow_drop_up : Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
              DataColumn(
                label: InkWell(
                  onTap: () => _setSort(HrSortKey.designation),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Designation'),
                      if (_sortKey == HrSortKey.designation)
                        Icon(_sortAscending ? Icons.arrow_drop_up : Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
              DataColumn(
                label: InkWell(
                  onTap: () => _setSort(HrSortKey.department),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Department'),
                      if (_sortKey == HrSortKey.department)
                        Icon(_sortAscending ? Icons.arrow_drop_up : Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
              DataColumn(
                label: InkWell(
                  onTap: () => _setSort(HrSortKey.dateJoined),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Join Date'),
                      if (_sortKey == HrSortKey.dateJoined)
                        Icon(_sortAscending ? Icons.arrow_drop_up : Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
              const DataColumn(label: Text('Actions')),
            ],
            rows: employees.map((emp) {
              return DataRow(
                cells: [
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(emp.fullname),
                        Text(
                          emp.email,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  DataCell(Text(emp.designation ?? 'N/A')),
                  DataCell(Text(emp.department ?? 'N/A')),
                  DataCell(Text(_formatDate(emp.dateJoined))),
                  DataCell(
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => _showEmployeeDetails(emp),
                          child: const Text('View'),
                        ),
                        TextButton(
                          onPressed: () => _showEditEmployeeDialog(emp),
                          child: const Text('Edit'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeMobileList(List<HrEmployee> employees) {
    return ListView.builder(
      itemCount: employees.length,
      itemBuilder: (context, index) {
        final emp = employees[index];
        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => _showEmployeeDetails(emp),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    emp.fullname,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    emp.email,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _smallInfo('Designation', emp.designation),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _smallInfo('Department', emp.department),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => _showEmployeeDetails(emp),
                        child: const Text('View'),
                      ),
                      TextButton(
                        onPressed: () => _showEditEmployeeDialog(emp),
                        child: const Text('Edit'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPendingDesktopTable(List<HrPendingUser> users) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('User')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
          rows: users.map((user) {
            return DataRow(
              cells: [
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(user.fullname),
                      Text(
                        user.email,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const DataCell(
                  Chip(
                    label: Text('Pending Approval'),
                    backgroundColor: Color(0xFFFFF7CC),
                  ),
                ),
                DataCell(
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => _showPendingUserDetails(user),
                        child: const Text('View'),
                      ),
                      TextButton(
                        onPressed: () => _approveEmployee(user),
                        child: const Text('Approve'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPendingMobileList(List<HrPendingUser> users) {
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => _showPendingUserDetails(user),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.fullname,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            user.email,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      const Chip(
                        label: Text('Pending'),
                        backgroundColor: Color(0xFFFFF7CC),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => _showPendingUserDetails(user),
                        child: const Text('View'),
                      ),
                      TextButton(
                        onPressed: () => _approveEmployee(user),
                        child: const Text('Approve'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _smallInfo(String label, String? value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
        Text(
          value == null || value.isEmpty ? 'N/A' : value,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.blue : Colors.grey.shade300;
    final textColor = selected ? Colors.white : Colors.black87;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
