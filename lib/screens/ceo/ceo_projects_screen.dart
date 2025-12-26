import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../layouts/dashboard_layout.dart';
import '../../services/api_service.dart';
import '../../services/project_service.dart';

class CeoProjectsScreen extends StatefulWidget {
  const CeoProjectsScreen({super.key});

  @override
  State<CeoProjectsScreen> createState() => _CeoProjectsScreenState();
}

class _CeoProjectsScreenState extends State<CeoProjectsScreen> {
  final ApiService _apiService = ApiService();
  final ProjectService _projectService = ProjectService();
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  bool _isLoadingUsers = true;
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _fetchProjects();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoadingUsers = true);

    try {
      final response = await _apiService.get('/accounts/users/');
      print('CEO Projects - Users API Response: $response');

      if (response['success']) {
        final data = response['data'];
        final usersList = List<Map<String, dynamic>>.from(
          data['users'] ?? data ?? [],
        );

        print('CEO Projects - Processed users: ${usersList.length}');

        setState(() => _users = usersList);
      } else {
        print('CEO Projects - Users API call not successful');
        setState(() => _users = []);
      }
    } catch (e) {
      print('Error fetching users: $e');
      setState(() => _users = []);
    } finally {
      setState(() => _isLoadingUsers = false);
    }
  }

  Future<void> _fetchProjects() async {
    setState(() => _isLoading = true);

    try {
      final response = await _apiService.get('/accounts/list_projects/');
      print('CEO Projects - Projects API Response: $response');

      if (response['success']) {
        final data = response['data'];
        print('CEO Projects - Projects raw data: $data');

        final projectsList = List<Map<String, dynamic>>.from(
          data['projects'] ?? data['data'] ?? data['results'] ?? [],
        );

        print('CEO Projects - Processed projects: ${projectsList.length}');

        setState(() => _projects = projectsList);
      } else {
        print('CEO Projects - Projects API call not successful');
        setState(() => _projects = []);
      }
    } catch (e) {
      print('Error fetching projects: $e');
      setState(() => _projects = []);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredProjects {
    if (_searchTerm.isEmpty) return _projects;

    return _projects.where((project) {
      final name = (project['name'] ?? project['title'] ?? '').toLowerCase();
      final description = (project['description'] ?? '').toLowerCase();
      final searchLower = _searchTerm.toLowerCase();

      return name.contains(searchLower) || description.contains(searchLower);
    }).toList();
  }

  int get _totalProjects => _projects.length;

  int get _activeProjects => _projects.where((project) {
    final status = (project['status'] ?? '').toLowerCase();
    return status == 'active' ||
        status == 'in progress' ||
        status == 'planning';
  }).length;

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '—';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'done':
        return Colors.green;
      case 'in progress':
      case 'active':
      case 'planning':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
      case 'on hold':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildTimeInfo(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildCompactTimeInfo(String value, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
            padding: const EdgeInsets.all(12),
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
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectCard(Map<String, dynamic> project) {
    final statusColor = _getStatusColor(project['status'] ?? '');

    return InkWell(
      onTap: () => _showProjectDetailsDialog(project),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
          border: Border.all(color: Colors.teal.withOpacity(0.3), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Project Info
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.folder,
                      color: Colors.teal.shade600,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project['name'] ??
                              project['title'] ??
                              'Unknown Project',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          project['email'] ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                          overflow: TextOverflow.ellipsis,
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
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      project['status'] ?? 'Unknown',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),

              if (project['description'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  project['description'],
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 12),
              Divider(height: 1, color: Colors.grey.shade200),
              const SizedBox(height: 12),

              // Project Dates and Members
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildCompactTimeInfo(
                      project['start_date'] != null
                          ? _formatDate(project['start_date'])
                          : '-',
                      Icons.calendar_today,
                      Colors.green,
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: Colors.grey.shade200,
                    ),
                    _buildCompactTimeInfo(
                      project['end_date'] != null
                          ? _formatDate(project['end_date'])
                          : '-',
                      Icons.event,
                      Colors.orange,
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: Colors.grey.shade200,
                    ),
                    _buildCompactTimeInfo(
                      '${(project['members'] as List<dynamic>?)?.length ?? 0}',
                      Icons.people,
                      Colors.purple,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProjectDetailsDialog(Map<String, dynamic> project) {
    final statusColor = _getStatusColor(project['status'] ?? '');
    final members = project['members'] as List<dynamic>? ?? [];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade600, Colors.blue.shade800],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            project['name'] ??
                                project['title'] ??
                                'Unknown Project',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              project['status'] ?? 'Unknown Status',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Description
                      if (project['description'] != null) ...[
                        const Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Text(
                            project['description'],
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Info Grid
                      const Text(
                        'Project Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 2.5,
                        children: [
                          _buildDetailCard(
                            'Start Date',
                            project['start_date'] != null
                                ? _formatDate(project['start_date'])
                                : 'Not set',
                            Icons.calendar_today,
                            Colors.green,
                          ),
                          _buildDetailCard(
                            'End Date',
                            project['end_date'] != null
                                ? _formatDate(project['end_date'])
                                : 'Not set',
                            Icons.event,
                            Colors.orange,
                          ),
                          _buildDetailCard(
                            'Status',
                            project['status'] ?? 'Unknown',
                            Icons.info,
                            statusColor,
                          ),
                          _buildDetailCard(
                            'Members',
                            '${members.length}',
                            Icons.people,
                            Colors.purple,
                          ),
                        ],
                      ),

                      // Members List
                      if (members.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Text(
                          'Team Members',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: members.map<Widget>((member) {
                              final user = _users.firstWhere(
                                (u) => u['email'] == member,
                                orElse: () => {
                                  'email': member,
                                  'role': 'Unknown',
                                },
                              );
                              final role = user['role'] ?? 'Unknown';
                              final roleColor = _getRoleColor(role);

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: roleColor,
                                      child: Text(
                                        member.toString().isNotEmpty
                                            ? member.toString()[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            member.toString(),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            role.toString().toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],

                      // Timestamps
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (project['created_at'] != null) ...[
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 14,
                                    color: Colors.blue.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Created: ${_formatDateTime(project['created_at'])}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (project['updated_at'] != null &&
                                project['updated_at'] !=
                                    project['created_at']) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.update,
                                    size: 14,
                                    color: Colors.blue.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Updated: ${_formatDateTime(project['updated_at'])}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Actions
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null) return '—';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy hh:mm a').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  Future<void> _showCreateProjectDialog() async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;
    List<String> selectedMemberEmails = [];
    bool creating = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: double.maxFinite,
                constraints: const BoxConstraints(
                  maxWidth: 500,
                  maxHeight: 700,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Create New Project',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Project Title',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );
                                if (picked != null) {
                                  setState(() => startDate = picked);
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Start Date',
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.calendar_today),
                                ),
                                child: Text(
                                  startDate != null
                                      ? DateFormat(
                                          'dd/MM/yyyy',
                                        ).format(startDate!)
                                      : 'Select start date',
                                  style: TextStyle(
                                    color: startDate != null
                                        ? Colors.black
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: startDate ?? DateTime.now(),
                                  firstDate: startDate ?? DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );
                                if (picked != null) {
                                  setState(() => endDate = picked);
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'End Date',
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.calendar_today),
                                ),
                                child: Text(
                                  endDate != null
                                      ? DateFormat(
                                          'dd/MM/yyyy',
                                        ).format(endDate!)
                                      : 'Select end date',
                                  style: TextStyle(
                                    color: endDate != null
                                        ? Colors.black
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Select Team Members',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_isLoadingUsers)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_users.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('No users available'),
                          ),
                        )
                      else
                        Flexible(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _users.length,
                              itemBuilder: (context, index) {
                                final user = _users[index];
                                final email = user['email'] ?? '';
                                final role = user['role'] ?? 'user';
                                final isSelected = selectedMemberEmails
                                    .contains(email);

                                return CheckboxListTile(
                                  value: isSelected,
                                  onChanged: (bool? value) {
                                    setState(() {
                                      if (value == true) {
                                        selectedMemberEmails.add(email);
                                      } else {
                                        selectedMemberEmails.remove(email);
                                      }
                                    });
                                  },
                                  title: Text(
                                    email,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  subtitle: Text(
                                    role.toString().toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  secondary: CircleAvatar(
                                    radius: 18,
                                    backgroundColor: _getRoleColor(role),
                                    child: Text(
                                      email.isNotEmpty
                                          ? email[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 0,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      if (selectedMemberEmails.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${selectedMemberEmails.length} member${selectedMemberEmails.length == 1 ? '' : 's'} selected',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: creating
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: creating
                                ? null
                                : () async {
                                    final title = titleController.text.trim();
                                    if (title.isEmpty) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Title is required'),
                                        ),
                                      );
                                      return;
                                    }

                                    if (startDate == null || endDate == null) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Please select start and end dates',
                                          ),
                                        ),
                                      );
                                      return;
                                    }

                                    setState(() => creating = true);

                                    // Get current user email for creator field
                                    final userEmail =
                                        await _getCurrentUserEmail();

                                    final payload = {
                                      'name': title,
                                      'description': descController.text.trim(),
                                      'start_date': DateFormat(
                                        'yyyy-MM-dd',
                                      ).format(startDate!),
                                      'end_date': DateFormat(
                                        'yyyy-MM-dd',
                                      ).format(endDate!),
                                      'status': 'Planning',
                                      'email': userEmail,
                                      'members': selectedMemberEmails,
                                    };

                                    try {
                                      await _projectService.createProject(
                                        payload,
                                      );
                                      if (!mounted) return;
                                      Navigator.of(context).pop();
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Project created successfully',
                                          ),
                                        ),
                                      );
                                      // Refresh list
                                      await _fetchProjects();
                                    } catch (e) {
                                      if (!mounted) return;
                                      setState(() => creating = false);
                                      // Show more detailed error
                                      String errorMessage =
                                          'Failed to create project';
                                      if (e.toString().contains('400')) {
                                        errorMessage =
                                            'Invalid project data. Please check all fields.';
                                      } else if (e.toString().contains('403')) {
                                        errorMessage =
                                            'You do not have permission to create projects.';
                                      } else if (e.toString().contains('500')) {
                                        errorMessage =
                                            'Server error. Please try again later.';
                                      }
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(errorMessage),
                                          backgroundColor: Colors.red,
                                          duration: const Duration(seconds: 5),
                                        ),
                                      );
                                    }
                                  },
                            child: creating
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Create'),
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
      },
    );
  }

  Future<String?> _getCurrentUserEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userInfoString = prefs.getString('user_info');
      if (userInfoString != null) {
        final userInfo = jsonDecode(userInfoString);
        return userInfo['email']?.toString().toLowerCase();
      }
    } catch (e) {
      print('Error getting current user email: $e');
    }
    return null;
  }

  Color _getRoleColor(String? role) {
    if (role == null) return Colors.grey;
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.red;
      case 'ceo':
        return Colors.purple;
      case 'manager':
        return Colors.blue;
      case 'hr':
        return Colors.green;
      case 'employee':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DashboardLayout(
      role: 'ceo',
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Projects Overview Header
              Container(
                padding: const EdgeInsets.all(16),
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
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.folder,
                        size: 20,
                        color: Colors.teal.shade600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Projects Overview',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Search Bar
              Container(
                padding: const EdgeInsets.all(16),
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
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search projects...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.blue.shade300),
                    ),
                    suffixIcon: _searchTerm.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _searchTerm = ''),
                          )
                        : null,
                  ),
                  onChanged: (value) => setState(() => _searchTerm = value),
                ),
              ),
              const SizedBox(height: 16),

              // Stats Cards
              LayoutBuilder(
                builder: (context, constraints) {
                  return Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total Projects',
                          _totalProjects.toString(),
                          Icons.folder,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Active Projects',
                          _activeProjects.toString(),
                          Icons.play_circle,
                          Colors.green,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              // Create Button
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade600, Colors.blue.shade700],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: _showCreateProjectDialog,
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add, color: Colors.white, size: 24),
                      const SizedBox(width: 8),
                      const Text(
                        'Create New Project',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Projects List
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_filteredProjects.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      _searchTerm.isEmpty
                          ? 'No projects found'
                          : 'No projects match your search',
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                )
              else
                Column(
                  children: _filteredProjects.map((project) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: _buildProjectCard(project),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
