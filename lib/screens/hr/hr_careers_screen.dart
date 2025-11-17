import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../layouts/dashboard_layout.dart';
import '../../services/api_service.dart';

class HrCareersScreen extends StatefulWidget {
  const HrCareersScreen({super.key});

  @override
  State<HrCareersScreen> createState() => _HrCareersScreenState();
}

class _HrCareersScreenState extends State<HrCareersScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  bool _isSavingCareer = false;

  // Careers and applicants
  List<Map<String, dynamic>> _careers = [];
  List<Map<String, dynamic>> _appliedJobs = [];

  // Applied jobs filters
  String _searchTerm = '';
  String _filterStatus = 'all'; // all, hired, not-hired

  // Create career form visibility
  bool _showCareerForm = false;
  Map<String, String> _newCareer = {
    'title': '',
    'department': '',
    'description': '',
    'responsibilities': '',
    'requirements': '',
    'benefits': '',
    'skills': '',
    'location': '',
    'type': '',
    'experience': '',
    'salary': '',
    'education': '',
  };

  // Detail dialogs
  Map<String, dynamic>? _selectedCareer;
  Map<String, dynamic>? _selectedApplicant;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _fetchCareers(),
        _fetchAppliedJobs(),
      ]);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchCareers() async {
    try {
      final res = await _apiService.get('/accounts/careers/');
      if (res['success'] == true) {
        final data = res['data'];
        final list = data is List
            ? data
            : (data is Map && data['results'] is List
                ? data['results']
                : []);
        final careers = <Map<String, dynamic>>[];
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            careers.add(_normalizeCareer(item));
          }
        }
        if (mounted) {
          setState(() => _careers = careers);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load careers: $e')),
        );
      }
    }
  }

  Map<String, dynamic> _normalizeCareer(Map<String, dynamic> raw) {
    String _asString(dynamic v) => v?.toString() ?? '';

    String _normalizeList(dynamic v) {
      if (v is List) {
        return v.map((e) => e.toString()).join(', ');
      }
      return v?.toString() ?? '';
    }

    return {
      'id': raw['id'],
      'title': _asString(raw['title']),
      'department': _asString(raw['department']),
      'description': _asString(raw['description']),
      'responsibilities': _normalizeList(raw['responsibilities']),
      'requirements': _normalizeList(raw['requirements']),
      'benefits': _normalizeList(raw['benefits']),
      'skills': _normalizeList(raw['skills']),
      'location': _asString(raw['location']),
      'type': _asString(raw['type']),
      'experience': _asString(raw['experience']),
      'salary': _asString(raw['salary']),
      'education': _asString(raw['education']),
    };
  }

  Future<void> _fetchAppliedJobs() async {
    try {
      final res = await _apiService.get('/accounts/applied_jobs/');
      if (res['success'] == true) {
        final data = res['data'];
        final list = data is List
            ? data
            : (data is Map && data['results'] is List
                ? data['results']
                : []);
        final jobs = <Map<String, dynamic>>[];
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            jobs.add(item);
          }
        }
        if (mounted) {
          setState(() => _appliedJobs = jobs);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load applications: $e')),
        );
      }
    }
  }

  Future<void> _deleteCareer(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Career'),
        content: const Text(
            'Are you sure you want to delete this career? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final res = await _apiService.delete('/accounts/careers/$id/');
      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Career deleted successfully')),
          );
          _fetchCareers();
        }
      } else {
        throw Exception(res['error'] ?? 'Failed to delete career');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete career: $e')),
        );
      }
    }
  }

  Future<void> _saveCareer() async {
    if (_newCareer['title']!.isEmpty ||
        _newCareer['department']!.isEmpty ||
        _newCareer['description']!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Title, Department and Description are required')),
      );
      return;
    }

    setState(() => _isSavingCareer = true);
    try {
      // Build apply_link similar to web: base URL without /api
      final base = ApiService.baseUrl;
      final applyBase = base.endsWith('/api')
          ? base.substring(0, base.length - 4)
          : base;

      final payload = {
        'title': _newCareer['title'],
        'department': _newCareer['department'],
        'description': _newCareer['description'],
        'responsibilities': _newCareer['responsibilities'],
        'requirements': _newCareer['requirements'],
        'benefits': _newCareer['benefits'],
        'skills': _newCareer['skills'],
        'location': _newCareer['location'],
        'type': _newCareer['type'],
        'experience': _newCareer['experience'],
        'salary': _newCareer['salary'],
        'education': _newCareer['education'],
        'posted_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'category': _newCareer['department'],
        'apply_link': '$applyBase/careers/apply',
      };

      final res = await _apiService.post('/accounts/careers/', payload);
      if (res['success'] != true) {
        throw Exception(res['error'] ?? 'Failed to create career');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Career created successfully')),
      );
      setState(() {
        _showCareerForm = false;
        _newCareer.updateAll((key, value) => '');
      });
      _fetchCareers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create career: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingCareer = false);
      }
    }
  }

  Future<void> _updateHiredStatus(String email, bool hired) async {
    try {
      final res = await _apiService.patch(
        '/accounts/applied_jobs/$email/set_hired/',
        {'hired': hired},
      );
      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Applicant has been ${hired ? 'hired' : 'updated'}'),
            ),
          );
          _fetchAppliedJobs();
        }
      } else {
        throw Exception(res['error'] ?? 'Failed to update status');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredAppliedJobs {
    return _appliedJobs.where((job) {
      final name = (job['fullname'] ?? '').toString().toLowerCase();
      final email = (job['email'] ?? '').toString().toLowerCase();
      final course = (job['course'] ?? '').toString().toLowerCase();
      final hired = job['hired'] == true;

      final q = _searchTerm.toLowerCase();
      final matchesSearch = q.isEmpty ||
          name.contains(q) ||
          email.contains(q) ||
          course.contains(q);

      final matchesStatus = _filterStatus == 'all' ||
          (_filterStatus == 'hired' && hired) ||
          (_filterStatus == 'not-hired' && !hired);

      return matchesSearch && matchesStatus;
    }).toList();
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        return RefreshIndicator(
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildStatsRow(),
                const SizedBox(height: 16),
                _buildCareersSection(isMobile),
                const SizedBox(height: 16),
                _buildAppliedJobsSection(isMobile),
                if (_showCareerForm) _buildCareerFormDialog(),
                if (_selectedCareer != null) _buildCareerDetailDialog(),
                if (_selectedApplicant != null) _buildApplicantDetailDialog(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'HR Careers',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _showCareerForm = true;
            });
          },
          child: const Text('Create New Job'),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    final totalJobs = _careers.length;
    final totalApps = _appliedJobs.length;
    final hired = _appliedJobs.where((j) => j['hired'] == true).length;
    final pending = totalApps - hired;

    Widget card(String label, String value, Color color) {
      return Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 8),
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
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        card('Total Jobs', '$totalJobs', Colors.blue),
        card('Applications', '$totalApps', Colors.green),
        card('Hired', '$hired', Colors.purple),
        card('Pending', '$pending', Colors.orange),
      ],
    );
  }

  Widget _buildCareersSection(bool isMobile) {
    if (_careers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.work_outline, size: 40, color: Colors.grey),
            const SizedBox(height: 8),
            const Text(
              'No career opportunities yet',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'Create your first job posting to attract talent.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Container(
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
          const Padding(
            padding: EdgeInsets.all(12.0),
            child: Text(
              'Career Opportunities',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Divider(height: 1),
          if (isMobile)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _careers.length,
              itemBuilder: (context, index) {
                final career = _careers[index];
                return ListTile(
                  title: Text(career['title'] ?? ''),
                  subtitle: Text(career['department'] ?? ''),
                  onTap: () {
                    setState(() => _selectedCareer = career);
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      final id = career['id'];
                      if (id is int) {
                        _deleteCareer(id);
                      }
                    },
                  ),
                );
              },
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Position')),
                  DataColumn(label: Text('Department')),
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: _careers.map((career) {
                  return DataRow(cells: [
                    DataCell(Text(career['title'] ?? '')),
                    DataCell(Text(career['department'] ?? '')),
                    DataCell(Text(career['type'] ?? '')),
                    DataCell(Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() => _selectedCareer = career);
                          },
                          child: const Text('View'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            final id = career['id'];
                            if (id is int) {
                              _deleteCareer(id);
                            }
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          child: const Text('Delete'),
                        ),
                      ],
                    )),
                  ]);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAppliedJobsSection(bool isMobile) {
    final jobs = _filteredAppliedJobs;

    return Container(
      margin: const EdgeInsets.only(top: 8),
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
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Job Applications',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText:
                              'Search by name, email, or course...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (v) {
                          setState(() => _searchTerm = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _filterStatus,
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('All'),
                        ),
                        DropdownMenuItem(
                          value: 'hired',
                          child: Text('Hired'),
                        ),
                        DropdownMenuItem(
                          value: 'not-hired',
                          child: Text('Not hired'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _filterStatus = v);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (jobs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  'No applications found',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else if (isMobile)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: jobs.length,
              itemBuilder: (context, index) {
                final job = jobs[index];
                final hired = job['hired'] == true;
                return ListTile(
                  title: Text(job['fullname'] ?? ''),
                  subtitle: Text(job['email'] ?? ''),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!hired)
                        IconButton(
                          icon: const Icon(Icons.check_circle,
                              color: Colors.green),
                          onPressed: () =>
                              _updateHiredStatus(job['email'] ?? '', true),
                        ),
                      IconButton(
                        icon: const Icon(Icons.visibility,
                            color: Colors.blue),
                        onPressed: () {
                          setState(() => _selectedApplicant = job);
                        },
                      ),
                    ],
                  ),
                );
              },
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Applicant')),
                  DataColumn(label: Text('Course')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: jobs.map((job) {
                  final hired = job['hired'] == true;
                  return DataRow(cells: [
                    DataCell(Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(job['fullname'] ?? ''),
                        Text(
                          job['email'] ?? '',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    )),
                    DataCell(Text(job['course']?.toString() ?? '')),
                    DataCell(
                      Text(hired ? 'Hired' : 'Under review'),
                    ),
                    DataCell(Row(
                      children: [
                        if (!hired)
                          TextButton(
                            onPressed: () => _updateHiredStatus(
                                job['email'] ?? '', true),
                            child: const Text('Hire'),
                          ),
                        TextButton(
                          onPressed: () =>
                              setState(() => _selectedApplicant = job),
                          child: const Text('View'),
                        ),
                      ],
                    )),
                  ]);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCareerFormDialog() {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Create New Job Position',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() => _showCareerForm = false);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildTextField('Job Title *', 'title', requiredField: true),
              _buildTextField('Department *', 'department', requiredField: true),
              _buildTextField('Location *', 'location', requiredField: true),
              _buildTextField('Job Type', 'type'),
              _buildTextField('Experience Level', 'experience'),
              _buildTextField('Salary Range', 'salary'),
              _buildTextField('Education', 'education'),
              _buildMultilineField(
                  'Job Description *', 'description', requiredField: true),
              _buildMultilineField(
                'Responsibilities (comma separated)',
                'responsibilities',
              ),
              _buildMultilineField(
                'Requirements (comma separated)',
                'requirements',
              ),
              _buildMultilineField(
                'Benefits (comma separated)',
                'benefits',
              ),
              _buildMultilineField(
                'Skills (comma separated)',
                'skills',
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSavingCareer
                        ? null
                        : () {
                            setState(() => _showCareerForm = false);
                          },
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSavingCareer ? null : _saveCareer,
                    child: _isSavingCareer
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create Job'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, String key,
      {bool requiredField = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: TextField(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: (v) {
          setState(() {
            _newCareer[key] = v;
          });
        },
      ),
    );
  }

  Widget _buildMultilineField(String label, String key,
      {bool requiredField = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: TextField(
        maxLines: 3,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: (v) {
          setState(() {
            _newCareer[key] = v;
          });
        },
      ),
    );
  }

  Widget _buildCareerDetailDialog() {
    final career = _selectedCareer!;

    List<Widget> _buildBulletList(String? csv) {
      if (csv == null || csv.trim().isEmpty) return [];
      return csv
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(child: Text(s)),
                  ],
                ),
              ))
          .toList();
    }

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      career['title'] ?? '',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() => _selectedCareer = null);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                career['department'] ?? '',
                style: const TextStyle(color: Colors.blue),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _infoChip('Location', career['location']),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _infoChip('Type', career['type']),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Description',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(career['description'] ?? ''),
              const SizedBox(height: 12),
              if ((career['responsibilities'] ?? '').toString().isNotEmpty) ...[
                const Text(
                  'Responsibilities',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                ..._buildBulletList(career['responsibilities']?.toString()),
                const SizedBox(height: 8),
              ],
              if ((career['requirements'] ?? '').toString().isNotEmpty) ...[
                const Text(
                  'Requirements',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                ..._buildBulletList(career['requirements']?.toString()),
                const SizedBox(height: 8),
              ],
              if ((career['benefits'] ?? '').toString().isNotEmpty) ...[
                const Text(
                  'Benefits',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                ..._buildBulletList(career['benefits']?.toString()),
                const SizedBox(height: 8),
              ],
              if ((career['skills'] ?? '').toString().isNotEmpty) ...[
                const Text(
                  'Skills',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: (career['skills'] as String)
                      .split(',')
                      .map((s) => s.trim())
                      .where((s) => s.isNotEmpty)
                      .map(
                        (s) => Chip(
                          label: Text(s),
                          backgroundColor: Colors.blue.shade50,
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApplicantDetailDialog() {
    final job = _selectedApplicant!;
    final hired = job['hired'] == true;

    String _safe(dynamic v) => v?.toString() ?? 'N/A';

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _safe(job['fullname']),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() => _selectedApplicant = null);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _safe(job['email']),
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _infoChip('Course', job['course']),
                  _infoChip('Phone', job['phone_number']),
                  _infoChip('Gender', job['gender']),
                  _infoChip(
                      'Training', job['available_for_training']),
                  _infoChip('Experience', job['work_experience']),
                  _infoChip('Specialization', job['specialization']),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color:
                          hired ? Colors.green.shade50 : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      hired ? 'Hired' : 'Under review',
                      style: TextStyle(
                        color: hired
                            ? Colors.green.shade800
                            : Colors.orange.shade800,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (!hired)
                    ElevatedButton.icon(
                      onPressed: () => _updateHiredStatus(
                          job['email'] ?? '', true),
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text('Hire'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (job['resume'] != null &&
                  job['resume'].toString().isNotEmpty)
                Text(
                  'Resume: ${job['resume']}',
                  style: const TextStyle(fontSize: 12, color: Colors.blue),
                ),
              if (job['report'] != null &&
                  job['report'].toString().isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Additional Information',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(job['report'].toString()),
              ],
            ],
          ),
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
}
