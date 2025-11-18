import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

import '../../layouts/dashboard_layout.dart';
import '../../utils/file_viewer.dart';
import '../../models/employee_documents_model.dart';
import '../../services/api_service.dart';
import '../../services/documents_service.dart';

class HrDocumentsScreen extends StatefulWidget {
  const HrDocumentsScreen({super.key});

  @override
  State<HrDocumentsScreen> createState() => _HrDocumentsScreenState();
}

class _HrDocumentsScreenState extends State<HrDocumentsScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  String _searchTerm = '';
  String _roleFilter = 'all'; // all, employee, hr, manager, admin

  List<Map<String, dynamic>> _users = []; // merged employees/hrs/managers/admins
  Map<String, EmployeeDocuments?> _documentsByEmail = {};
  Map<String, List<Map<String, dynamic>>> _awardsByEmail = {};

  // Tracks in-progress issue operations per email+docType
  final Map<String, bool> _loadingDocs = {};

  // Tracks create/delete award loading per email
  final Map<String, bool> _loadingAwardAction = {};

  @override
  void initState() {
    super.initState();
    _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final employeesRes = await _apiService.get('/accounts/employees/');
      final hrsRes = await _apiService.get('/accounts/hrs/');
      final managersRes = await _apiService.get('/accounts/managers/');
      final adminsRes = await _apiService.get('/accounts/admins/');
      final docsRes = await _apiService.get('/accounts/list_documents/');
      final awardsRes = await _apiService.get('/accounts/list_awards/');

      final users = <Map<String, dynamic>>[];

      void addUsers(dynamic data, String role) {
        if (data is List) {
          for (final u in data) {
            if (u is Map<String, dynamic>) {
              final user = Map<String, dynamic>.from(u);
              user['role'] = role;
              users.add(user);
            }
          }
        } else if (data is Map && data['results'] is List) {
          for (final u in data['results']) {
            if (u is Map<String, dynamic>) {
              final user = Map<String, dynamic>.from(u);
              user['role'] = role;
              users.add(user);
            }
          }
        }
      }

      if (employeesRes['success'] == true) {
        addUsers(employeesRes['data'], 'employee');
      }
      if (hrsRes['success'] == true) {
        addUsers(hrsRes['data'], 'hr');
      }
      if (managersRes['success'] == true) {
        addUsers(managersRes['data'], 'manager');
      }
      if (adminsRes['success'] == true) {
        addUsers(adminsRes['data'], 'admin');
      }

      // Documents: list_documents returns array of records with email + fields
      final docsByEmail = <String, EmployeeDocuments?>{};
      if (docsRes['success'] == true) {
        final data = docsRes['data'];
        final list = data is List
            ? data
            : (data is Map && data['documents'] is List
                ? data['documents']
                : []);
        for (final entry in list) {
          if (entry is Map<String, dynamic>) {
            final email = (entry['email'] ?? '').toString();
            if (email.isEmpty) continue;
            docsByEmail[email] = EmployeeDocuments.fromJson(entry);
          }
        }
      }

      // Awards: group by email
      final awardsByEmail = <String, List<Map<String, dynamic>>>{};
      if (awardsRes['success'] == true) {
        final data = awardsRes['data'];
        final list = data is List
            ? data
            : (data is Map && data['awards'] is List
                ? data['awards']
                : []);
        for (final entry in list) {
          if (entry is Map<String, dynamic>) {
            final email = (entry['email'] ?? '').toString();
            if (email.isEmpty) continue;
            awardsByEmail.putIfAbsent(email, () => []);
            awardsByEmail[email]!.add(entry);
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _users = users;
        _documentsByEmail = docsByEmail;
        _awardsByEmail = awardsByEmail;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load documents data: $e')),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    final q = _searchTerm.toLowerCase();
    return _users.where((u) {
      final role = (u['role'] ?? '').toString().toLowerCase();
      if (_roleFilter != 'all' && role != _roleFilter) return false;
      if (q.isEmpty) return true;
      final name = (u['fullname'] ?? u['name'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      return name.contains(q) || email.contains(q);
    }).toList();
  }

  String _formatDate(dynamic value) {
    if (value == null) return 'N/A';
    try {
      final dt = DateTime.parse(value.toString());
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {
      return value.toString();
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'employee':
        return 'Employee';
      case 'hr':
        return 'HR';
      case 'manager':
        return 'Manager';
      case 'admin':
        return 'Admin';
      default:
        return role.toUpperCase();
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'employee':
        return Colors.blue.shade600;
      case 'hr':
        return Colors.purple.shade600;
      case 'manager':
        return Colors.orange.shade600;
      case 'admin':
        return Colors.green.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  Future<void> _issueDocument(
    String email,
    String docKey,
    String endpoint,
  ) async {
    final loadingKey = '$email|$docKey';
    setState(() {
      _loadingDocs[loadingKey] = true;
    });

    try {
      final res = await _apiService.post(endpoint, {'email': email});
      if (res['success'] != true) {
        final msg = res['error'] ?? 'Failed to issue document';
        throw Exception(msg);
      }

      // Re-fetch documents list for this email
      final docsRes = await _apiService.get('/accounts/list_documents/');
      String? docUrl;
      if (docsRes['success'] == true) {
        final data = docsRes['data'];
        final list = data is List
            ? data
            : (data is Map && data['documents'] is List
                ? data['documents']
                : []);
        EmployeeDocuments? docs;
        for (final entry in list) {
          if (entry is Map<String, dynamic> &&
              (entry['email'] ?? '').toString() == email) {
            docs = EmployeeDocuments.fromJson(entry);
            break;
          }
        }
        if (docs != null && mounted) {
          setState(() {
            _documentsByEmail[email] = docs;
          });
          // Try to grab the freshly issued document URL for the dialog
          final allDocs = docs.getAllDocuments();
          final info = allDocs[docKey];
          if (info != null && info.isAvailable) {
            docUrl = info.url;
          }
        }
      }

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text(docKey),
            content: Text(
              '$docKey issued successfully for $email.',
            ),
            actions: [
              if (docUrl != null && docUrl!.isNotEmpty)
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    openRemoteFile(context, docUrl!, title: docKey);
                  },
                  child: const Text('View Document'),
                ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to issue $docKey: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingDocs[loadingKey] = false;
      });
    }
  }

  Future<void> _createAward(
    String email,
    String title,
    String description,
    XFile? photo,
  ) async {
    setState(() {
      _loadingAwardAction[email] = true;
    });

    try {
      final uri = Uri.parse('${ApiService.baseUrl}/accounts/create_award/');
      final request = http.MultipartRequest('POST', uri);

      final token = await _apiService.getToken();
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields['email'] = email;
      request.fields['title'] = title;
      request.fields['description'] = description;

      if (photo != null) {
        request.files.add(
          await http.MultipartFile.fromPath('photo', photo.path),
        );
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to create award (${response.statusCode})');
      }

      // Reload awards
      final awardsRes = await _apiService.get('/accounts/list_awards/');
      if (awardsRes['success'] == true) {
        final data = awardsRes['data'];
        final list = data is List
            ? data
            : (data is Map && data['awards'] is List
                ? data['awards']
                : []);
        final byEmail = <String, List<Map<String, dynamic>>>{};
        for (final entry in list) {
          if (entry is Map<String, dynamic>) {
            final mail = (entry['email'] ?? '').toString();
            if (mail.isEmpty) continue;
            byEmail.putIfAbsent(mail, () => []);
            byEmail[mail]!.add(entry);
          }
        }
        if (mounted) {
          setState(() {
            _awardsByEmail = byEmail;
          });
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Award issued successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to issue award: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingAwardAction[email] = false;
      });
    }
  }

  Future<void> _deleteAward(String email, int awardId) async {
    setState(() {
      _loadingAwardAction[email] = true;
    });

    try {
      final res = await _apiService.delete('/accounts/delete_award/$awardId/');
      if (res['success'] != true) {
        throw Exception(res['error'] ?? 'Failed to delete award');
      }

      // Remove locally
      final list = List<Map<String, dynamic>>.from(
        _awardsByEmail[email] ?? const [],
      );
      list.removeWhere((a) => a['id'] == awardId);
      if (mounted) {
        setState(() {
          _awardsByEmail[email] = list;
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Award deleted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete award: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingAwardAction[email] = false;
      });
    }
  }

  void _openUserDetails(Map<String, dynamic> user) {
    final email = (user['email'] ?? '').toString();
    final docs = _documentsByEmail[email];
    final awards = _awardsByEmail[email] ?? const [];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 800,
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: _UserDetailsContent(
              user: user,
              documents: docs,
              awards: awards,
              onIssueDocument: _issueDocument,
              onCreateAward: _createAward,
              onDeleteAward: _deleteAward,
              loadingDocs: _loadingDocs,
              loadingAwardAction: _loadingAwardAction,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DashboardLayout(
      role: 'hr',
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final users = _filteredUsers;

    return RefreshIndicator(
      onRefresh: _fetchAllData,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 700;
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildStatsRow(),
                const SizedBox(height: 16),
                _buildFilters(),
                const SizedBox(height: 16),
                if (users.isEmpty)
                  _buildEmptyState()
                else
                  isMobile
                      ? _buildUserCards(users)
                      : _buildUserGrid(users),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Issue Documents & Awards',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          onPressed: _fetchAllData,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    final totalUsers = _users.length;
    final totalDocs = _documentsByEmail.values
        .where((d) => d != null)
        .fold<int>(0, (prev, docs) => prev + docs!.getAllDocuments().values.where((di) => di.isAvailable).length);
    final filtered = _filteredUsers.length;

    return Row(
      children: [
        Expanded(
          child: _statCard(
            label: 'Total Users',
            value: '$totalUsers',
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            label: 'Documents',
            value: '$totalDocs',
            color: Colors.indigo,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            label: 'Showing',
            value: '$filtered',
            color: Colors.teal,
            subtitle: 'Filtered users',
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required Color color,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: 'Search by name or email',
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _roleFilterChip('All', 'all'),
                const SizedBox(width: 8),
                _roleFilterChip('Employees', 'employee'),
                const SizedBox(width: 8),
                _roleFilterChip('HR', 'hr'),
                const SizedBox(width: 8),
                _roleFilterChip('Managers', 'manager'),
                const SizedBox(width: 8),
                _roleFilterChip('Admins', 'admin'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleFilterChip(String label, String value) {
    final selected = _roleFilter == value;
    return InkWell(
      onTap: () {
        setState(() {
          _roleFilter = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.blue.shade600 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            'No users found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Try adjusting your search or role filter.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCards(List<Map<String, dynamic>> users) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return _userCard(user);
      },
    );
  }

  Widget _buildUserGrid(List<Map<String, dynamic>> users) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 3 / 2,
      ),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return _userCard(user);
      },
    );
  }

  Widget _userCard(Map<String, dynamic> user) {
    final name = (user['fullname'] ?? user['name'] ?? '').toString();
    final email = (user['email'] ?? '').toString();
    final phone = (user['phone'] ?? '').toString();
    final department = (user['department'] ?? '').toString();
    final designation = (user['designation'] ?? '').toString();
    final role = (user['role'] ?? '').toString();
    final profilePicture = (user['profile_picture'] ?? '').toString();

    final initials = name.isNotEmpty
        ? name
            .trim()
            .split(' ')
            .map((p) => p.isNotEmpty ? p[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : 'U';

    return InkWell(
      onTap: () => _openUserDetails(user),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
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
                  radius: 20,
                  backgroundColor: Colors.blue.shade100,
                  backgroundImage: profilePicture.isNotEmpty
                      ? NetworkImage(profilePicture)
                      : null,
                  child: profilePicture.isNotEmpty
                      ? null
                      : Text(
                          initials,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _roleColor(role).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _roleLabel(role),
                    style: TextStyle(
                      fontSize: 11,
                      color: _roleColor(role),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (phone.isNotEmpty)
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.phone,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            phone,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (department.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.apartment,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            department,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            if (designation.isNotEmpty)
              Text(
                designation,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}

class _UserDetailsContent extends StatefulWidget {
  final Map<String, dynamic> user;
  final EmployeeDocuments? documents;
  final List<Map<String, dynamic>> awards;
  final Future<void> Function(String email, String docKey, String endpoint)
      onIssueDocument;
  final Future<void> Function(
    String email,
    String title,
    String description,
    XFile? photo,
  ) onCreateAward;
  final Future<void> Function(String email, int awardId) onDeleteAward;
  final Map<String, bool> loadingDocs;
  final Map<String, bool> loadingAwardAction;

  const _UserDetailsContent({
    required this.user,
    required this.documents,
    required this.awards,
    required this.onIssueDocument,
    required this.onCreateAward,
    required this.onDeleteAward,
    required this.loadingDocs,
    required this.loadingAwardAction,
  });

  @override
  State<_UserDetailsContent> createState() => _UserDetailsContentState();
}

class _UserDetailsContentState extends State<_UserDetailsContent> {
  late Map<String, DocumentInfo> _docsMap;
  final DocumentsService _documentsService = DocumentsService();

  @override
  void initState() {
    super.initState();
    _docsMap = widget.documents?.getAllDocuments() ?? {};
  }

  String get _email => (widget.user['email'] ?? '').toString();

  Future<void> _openDocument(String url) async {
    await openRemoteFile(context, url, title: 'Document');
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.user['fullname'] ?? widget.user['name'] ?? '').toString();
    final role = (widget.user['role'] ?? '').toString();
    final profilePicture = (widget.user['profile_picture'] ?? '').toString();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade600,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white,
                backgroundImage: profilePicture.isNotEmpty
                    ? NetworkImage(profilePicture)
                    : null,
                child: profilePicture.isNotEmpty
                    ? null
                    : Text(
                        name.isNotEmpty
                            ? name[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _email,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  role.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPersonalInfo(),
                const SizedBox(height: 16),
                _buildDocumentsSection(),
                const SizedBox(height: 16),
                _buildAwardsSection(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalInfo() {
    final user = widget.user;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Personal Info',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _infoChip('Department', user['department']),
                _infoChip('Designation', user['designation']),
                _infoChip('Phone', user['phone']),
                _infoChip('Join Date', user['date_joined']),
              ],
            ),
          ],
        ),
      ),
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

  Widget _buildDocumentsSection() {
    final docs = _docsMap;
    final email = _email;

    final docGroups = <String, List<Map<String, dynamic>>>{
      'Core Documents': [
        {
          'key': 'Resume',
          'field': 'Resume',
          'issueable': false,
        },
        {
          'key': 'Appointment Letter',
          'field': 'Appointment Letter',
          'issueable': true,
          'endpoint': '/accounts/appointment_letter/',
        },
        {
          'key': 'Offer Letter',
          'field': 'Offer Letter',
          'issueable': true,
          'endpoint': '/accounts/offer_letter/',
        },
        {
          'key': 'Releaving Letter',
          'field': 'Releaving Letter',
          'issueable': true,
          'endpoint': '/accounts/releaving_letter/',
        },
        {
          'key': 'Bonafide Certificate',
          'field': 'Bonafide Certificate',
          'issueable': true,
          'endpoint': '/accounts/bonafide_certificate/',
        },
      ],
      'Identity & Education': [
        {
          'key': 'ID Proof',
          'field': 'ID Proof',
        },
        {
          'key': '10th Marksheet',
          'field': '10th Marksheet',
        },
        {
          'key': '12th Marksheet',
          'field': '12th Marksheet',
        },
        {
          'key': 'Degree Certificate',
          'field': 'Degree Certificate',
        },
        {
          'key': 'Masters Certificate',
          'field': 'Masters Certificate',
        },
      ],
      'Other Documents': [
        {
          'key': 'Marks Card',
          'field': 'Marks Card',
        },
        {
          'key': 'Certificates',
          'field': 'Certificates',
        },
        {
          'key': 'Awards & Certifications',
          'field': 'Awards & Certifications',
        },
        {
          'key': 'Achievement Certificate',
          'field': 'Achievement Certificate',
        },
        {
          'key': 'Resignation Letter',
          'field': 'Resignation Letter',
        },
      ],
    };

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                'No documents found for this user.',
                style: TextStyle(color: Colors.grey),
              )
            else
              Column(
                children: docGroups.entries.map((entry) {
                  final groupName = entry.key;
                  final items = entry.value;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        groupName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...items.map((item) {
                        final field = item['field'] as String;
                        final docInfo = docs[field];
                        final hasDoc = docInfo?.isAvailable == true;
                        final issueable = item['issueable'] == true;
                        final endpoint = item['endpoint']?.toString();
                        final loadingKey = '$email|$field';
                        final isLoading =
                            widget.loadingDocs[loadingKey] == true;

                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(field),
                          subtitle: Text(
                            hasDoc
                                ? 'Available'
                                : 'Not uploaded',
                            style: TextStyle(
                              color:
                                  docInfo?.isAvailable == true
                                      ? Colors.green
                                      : Colors.grey,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hasDoc && docInfo?.url != null)
                                TextButton(
                                  onPressed: () {
                                    _openDocument(docInfo!.url!);
                                  },
                                  child: const Text('View'),
                                ),
                              if (issueable && endpoint != null)
                                TextButton(
                                  onPressed: isLoading
                                      ? null
                                      : () async {
                                          // If document already exists, confirm re-issue
                                          if (hasDoc) {
                                            final confirmed = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) {
                                                return AlertDialog(
                                                  title: Text(field),
                                                  content: const Text(
                                                    'Document already exists. Do you want to regenerate/issue again?',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.of(ctx).pop(false),
                                                      child: const Text('Cancel'),
                                                    ),
                                                    ElevatedButton(
                                                      onPressed: () => Navigator.of(ctx).pop(true),
                                                      child: const Text('Issue Again'),
                                                    ),
                                                  ],
                                                );
                                              },
                                            );
                                            if (confirmed != true) return;
                                          }

                                          // Optional: small global loader overlay while API runs
                                          showDialog(
                                            context: context,
                                            barrierDismissible: false,
                                            builder: (_) => const Center(
                                              child: CircularProgressIndicator(),
                                            ),
                                          );

                                          await widget.onIssueDocument(
                                            email,
                                            field,
                                            endpoint,
                                          );

                                          // After issuing, fetch latest documents for this user
                                          final updatedDocs = await _documentsService
                                              .fetchDocuments(email);
                                          if (!mounted || updatedDocs == null) {
                                            Navigator.of(context, rootNavigator: true).pop();
                                            return;
                                          }
                                          setState(() {
                                            _docsMap =
                                                updatedDocs.getAllDocuments();
                                          });

                                          // Remove loader before showing success dialog (inside onIssueDocument)
                                          Navigator.of(context, rootNavigator: true).pop();
                                        },
                                  child: isLoading
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Text('Rendering...'),
                                          ],
                                        )
                                      : Text(hasDoc ? 'Re-issue' : 'Issue'),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAwardsSection() {
    final awards = widget.awards;
    final email = _email;
    final isLoading = widget.loadingAwardAction[email] == true;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Awards',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton.icon(
                  onPressed:
                      isLoading ? null : () => _openIssueAwardDialog(),
                  icon: const Icon(Icons.emoji_events, size: 18),
                  label: const Text('Issue Award'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (awards.isEmpty)
              const Text(
                'No awards found for this user.',
                style: TextStyle(color: Colors.grey),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: awards.length,
                itemBuilder: (context, index) {
                  final award = awards[index];
                  final title = (award['title'] ?? '').toString();
                  final description =
                      (award['description'] ?? '').toString();
                  final createdAt = award['created_at'] ?? award['date'];
                  final awardId = award['id'];

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (description.isNotEmpty)
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (createdAt != null)
                          Text(
                            DateFormat('dd/MM/yyyy').format(
                              DateTime.tryParse(
                                      createdAt.toString()) ??
                                  DateTime.now(),
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.delete, color: Colors.red),
                      onPressed: awardId == null || isLoading
                          ? null
                          : () => widget.onDeleteAward(
                                email,
                                awardId is int
                                    ? awardId
                                    : int.tryParse(
                                          awardId.toString(),
                                        ) ??
                                        0,
                              ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openIssueAwardDialog() async {
    final email = _email;
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    XFile? pickedImage;

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Issue Award'),
          content: StatefulBuilder(
            builder: (context, setLocal) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            final picker = ImagePicker();
                            final img = await picker.pickImage(
                              source: ImageSource.gallery,
                            );
                            if (img != null) {
                              setLocal(() {
                                pickedImage = img;
                              });
                            }
                          },
                          icon: const Icon(Icons.image),
                          label: const Text('Add Photo (optional)'),
                        ),
                        const SizedBox(width: 8),
                        if (pickedImage != null)
                          const Icon(Icons.check_circle,
                              color: Colors.green),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final desc = descCtrl.text.trim();
                if (title.isEmpty || desc.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please provide title and description'),
                    ),
                  );
                  return;
                }
                Navigator.of(ctx).pop();
                await widget.onCreateAward(
                  email,
                  title,
                  desc,
                  pickedImage,
                );
              },
              child: const Text('Issue'),
            ),
          ],
        );
      },
    );
  }
}
