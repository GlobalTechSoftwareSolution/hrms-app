import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';
import '../../layouts/dashboard_layout.dart';
import '../../utils/file_viewer.dart';

class ManagerTeamScreen extends StatefulWidget {
  const ManagerTeamScreen({super.key});

  @override
  State<ManagerTeamScreen> createState() => _ManagerTeamScreenState();
}

class _ManagerTeamScreenState extends State<ManagerTeamScreen> {
  final ApiService _apiService = ApiService();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _hrs = [];
  List<Map<String, dynamic>> _managers = [];

  bool _isLoading = false;
  String _searchTerm = '';
  String _view = 'employee'; // 'employee', 'hr', 'manager'

  Map<String, dynamic>? _docs;
  String? _selectedDoc;
  List<Map<String, dynamic>> _awards = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
    _searchController.addListener(() {
      setState(() => _searchTerm = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _apiService.get('/accounts/employees/'),
        _apiService.get('/accounts/hrs/'),
        _apiService.get('/accounts/managers/'),
      ]);

      if (results[0]['success']) {
        final data = results[0]['data'];
        setState(
          () => _employees = List<Map<String, dynamic>>.from(data ?? []),
        );
      }

      if (results[1]['success']) {
        final data = results[1]['data'];
        setState(() => _hrs = List<Map<String, dynamic>>.from(data ?? []));
      }

      if (results[2]['success']) {
        final data = results[2]['data'];
        setState(() => _managers = List<Map<String, dynamic>>.from(data ?? []));
      }
    } catch (e) {
      print('Error fetching team data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _currentList {
    List<Map<String, dynamic>> list;
    switch (_view) {
      case 'hr':
        list = _hrs;
        break;
      case 'manager':
        list = _managers;
        break;
      default:
        list = _employees;
    }

    if (_searchTerm.isEmpty) return list;

    final search = _searchTerm.toLowerCase();
    return list.where((emp) {
      return (emp['fullname'] ?? '').toString().toLowerCase().contains(
            search,
          ) ||
          (emp['email'] ?? '').toString().toLowerCase().contains(search) ||
          (emp['department'] ?? '').toString().toLowerCase().contains(search) ||
          (emp['designation'] ?? '').toString().toLowerCase().contains(search);
    }).toList();
  }

  Future<Map<String, dynamic>?> _fetchDocuments(String email) async {
    try {
      // Call the raw API so we see exactly what the backend returns
      final response = await _apiService.get('/accounts/get_document/$email/');

      if (response['success'] == true) {
        final data = response['data'];

        // API may return a list with a single record or a single map
        Map<String, dynamic>? record;
        if (data is List && data.isNotEmpty) {
          record = data.first is Map<String, dynamic>
              ? Map<String, dynamic>.from(data.first)
              : null;
        } else if (data is Map<String, dynamic>) {
          record = Map<String, dynamic>.from(data);
        }

        if (record != null && record.isNotEmpty) {
          // Keep only non-empty string fields
          final Map<String, dynamic> mapped = {};
          record.forEach((key, value) {
            if (value != null) {
              final v = value.toString().trim();
              if (v.isNotEmpty) {
                mapped[key] = v;
              }
            }
          });
          return mapped.isNotEmpty ? mapped : null;
        } else {
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      print('Error fetching documents: $e');
      return null;
    }
  }

  Future<void> _fetchAwards(String email) async {
    try {
      final response = await _apiService.get('/accounts/list_awards/');
      if (response['success']) {
        final data = response['data'];
        List<Map<String, dynamic>> awards = [];
        if (data is List) {
          awards = data.whereType<Map<String, dynamic>>().toList();
        } else if (data is Map && data['awards'] is List) {
          awards = List<Map<String, dynamic>>.from(data['awards'] ?? []);
        }

        setState(() {
          _awards = awards
              .where((award) => (award['email'] ?? '') == email)
              .toList();
        });
      }
    } catch (e) {
      print('Error fetching awards: $e');
      setState(() => _awards = []);
    }
  }

  void _selectEmployee(Map<String, dynamic> emp) {
    final email = emp['email'] ?? '';
    if (email.isNotEmpty) {
      _fetchAwards(email);
    }
    // Show dialog
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final fullname = emp['fullname'] ?? 'N/A';
        final profilePic = emp['profile_picture'] ?? '';

        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (_docs == null) {
              _fetchDocuments(email).then((result) {
                setDialogState(() => _docs = result);
              });
            }

            return _buildEmployeeDetailsDialog(
              emp,
              fullname,
              profilePic,
              email,
              _docs,
              _selectedDoc,
              setDialogState,
            );
          },
        );
      },
    ).then((_) {
      // Reset when dialog closes
      setState(() {
        _docs = null;
        _selectedDoc = null;
        _awards = [];
      });
    });
  }

  void _closeEmployeeDetails() {
    Navigator.of(context).pop();
  }

  String _getValidImageUrl(String? url, String name) {
    if (url == null || url.isEmpty) {
      return 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=0D8ABC&color=fff&bold=true';
    }
    try {
      Uri.parse(url);
      return url;
    } catch (e) {
      return 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=0D8ABC&color=fff&bold=true';
    }
  }

  Future<void> _openDocument(String url) async {
    await openRemoteFile(context, url, title: 'Document');
  }

  Widget _buildDocumentViewer(String url) {
    final ext = url.split('.').last.toLowerCase();

    if (ext == 'pdf') {
      return Container(
        height: 500,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.picture_as_pdf, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('PDF Document'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _openDocument(url),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open PDF'),
              ),
            ],
          ),
        ),
      );
    } else if (['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
      return Container(
        constraints: const BoxConstraints(maxHeight: 500),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Center(child: Text('Error loading image'));
            },
          ),
        ),
      );
    } else if (['mp4', 'webm'].contains(ext)) {
      return Container(
        height: 500,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.video_library, size: 64, color: Colors.blue),
              const SizedBox(height: 16),
              const Text('Video File'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _openDocument(url),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open Video'),
              ),
            ],
          ),
        ),
      );
    } else {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.insert_drive_file, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text('Unsupported file type: $ext'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _openDocument(url),
                icon: const Icon(Icons.download),
                label: const Text('Download File'),
              ),
            ],
          ),
        ),
      );
    }
  }

  IconData _getAwardIcon(String title) {
    final titleLower = title.toLowerCase();
    if (titleLower.contains('star')) return Icons.star;
    if (titleLower.contains('trophy')) return Icons.emoji_events;
    if (titleLower.contains('medal')) return Icons.military_tech;
    return Icons.workspace_premium;
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
            // Header - Responsive
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 600;
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.group,
                          size: isMobile ? 28 : 32,
                          color: Colors.blue[700],
                        ),
                        SizedBox(width: isMobile ? 8 : 12),
                        Flexible(
                          child: Text(
                            'Team Dashboard',
                            style: TextStyle(
                              fontSize: isMobile ? 22 : 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[900],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 8 : 0,
                      ),
                      child: Text(
                        'Manage and view your team members, their documents, and achievements',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 14,
                          color: Colors.grey[600],
                        ),
                        maxLines: isMobile ? 2 : null,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            // Stats Cards - Responsive layout
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 600;
                if (isMobile) {
                  // Stack cards vertically on mobile
                  return Column(
                    children: [
                      _buildStatCard(
                        'Employees',
                        _employees.length,
                        Icons.people,
                        Colors.green,
                      ),
                      const SizedBox(height: 12),
                      _buildStatCard(
                        'HR Team',
                        _hrs.length,
                        Icons.person,
                        Colors.blue,
                      ),
                      const SizedBox(height: 12),
                      _buildStatCard(
                        'Managers',
                        _managers.length,
                        Icons.workspace_premium,
                        Colors.purple,
                      ),
                    ],
                  );
                } else {
                  // Horizontal layout on larger screens
                  return Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Employees',
                          _employees.length,
                          Icons.people,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'HR Team',
                          _hrs.length,
                          Icons.person,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Managers',
                          _managers.length,
                          Icons.workspace_premium,
                          Colors.purple,
                        ),
                      ),
                    ],
                  );
                }
              },
            ),

            const SizedBox(height: 24),

            // Search and Tabs
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Search
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by name, email, department...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Tabs - Responsive
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 600;
                        if (isMobile) {
                          return Column(
                            children: [
                              _buildTabButton(
                                'employee',
                                'Employees',
                                Icons.people,
                              ),
                              const SizedBox(height: 8),
                              _buildTabButton('hr', 'HR Team', Icons.person),
                              const SizedBox(height: 8),
                              _buildTabButton(
                                'manager',
                                'Managers',
                                Icons.workspace_premium,
                              ),
                            ],
                          );
                        } else {
                          return Row(
                            children: [
                              Expanded(
                                child: _buildTabButton(
                                  'employee',
                                  'Employees',
                                  Icons.people,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildTabButton(
                                  'hr',
                                  'HR Team',
                                  Icons.person,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildTabButton(
                                  'manager',
                                  'Managers',
                                  Icons.workspace_premium,
                                ),
                              ),
                            ],
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Team Grid
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(48.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_currentList.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 64,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No $_view found',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[900],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _searchTerm.isEmpty
                          ? 'No $_view records available'
                          : 'Try adjusting your search terms',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth < 600 ? 1 : 2;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: crossAxisCount == 1 ? 1.5 : 1.1,
                    ),
                    itemCount: _currentList.length,
                    itemBuilder: (context, index) {
                      final emp = _currentList[index];
                      final fullname = emp['fullname'] ?? 'N/A';
                      final email = emp['email'] ?? '';
                      final profilePic = emp['profile_picture'] ?? '';

                      return InkWell(
                        onTap: () => _selectEmployee(emp),
                        borderRadius: BorderRadius.circular(12),
                        child: Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey[200]!),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Top section - Avatar and name
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 28,
                                      backgroundImage: NetworkImage(
                                        _getValidImageUrl(profilePic, fullname),
                                      ),
                                      onBackgroundImageError: (_, __) {},
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            fullname,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            email,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[600],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                // Info section - More compact
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    if (emp['department'] != null)
                                      _buildInfoChip(
                                        Icons.business,
                                        emp['department'],
                                      ),
                                    if (emp['designation'] != null)
                                      _buildInfoChip(
                                        Icons.work,
                                        emp['designation'],
                                      ),
                                    if (emp['phone'] != null)
                                      _buildInfoChip(Icons.phone, emp['phone']),
                                  ],
                                ),

                                const SizedBox(height: 10),

                                // Bottom section - Role badge and View button
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Chip(
                                      label: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _view == 'hr'
                                                ? Icons.person
                                                : _view == 'manager'
                                                ? Icons.workspace_premium
                                                : Icons.people,
                                            size: 12,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _view.toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: _view == 'manager'
                                          ? Colors.purple[100]
                                          : _view == 'hr'
                                          ? Colors.blue[100]
                                          : Colors.green[100],
                                      labelStyle: TextStyle(
                                        color: _view == 'manager'
                                            ? Colors.purple[800]
                                            : _view == 'hr'
                                            ? Colors.blue[800]
                                            : Colors.green[800],
                                        fontSize: 10,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 0,
                                      ),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    TextButton(
                                      onPressed: () => _selectEmployee(emp),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        minimumSize: const Size(0, 32),
                                        backgroundColor: Colors.blue[50],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.visibility,
                                            size: 14,
                                            color: Colors.blue[700],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'View',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.blue[700],
                                            ),
                                          ),
                                        ],
                                      ),
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
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String value, String label, IconData icon) {
    final isSelected = _view == value;
    return InkWell(
      onTap: () => setState(() => _view = value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue[600]! : Colors.transparent,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.blue[100]!,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.blue[600] : Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.blue[600] : Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(fontSize: 10, color: Colors.grey[800]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, int count, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
          ],
        ),
      ),
    );
  }

  String _getHeaderText(dynamic value) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty) return '';
    final lower = text.toLowerCase();
    if (lower == 'null' || lower == 'none' || lower == 'n/a') return '';
    return text;
  }

  Widget _buildEmployeeDetailsDialog(
    Map<String, dynamic> emp,
    String fullname,
    String profilePic,
    String email,
    Map<String, dynamic>? docs,
    String? selectedDoc,
    StateSetter setDialogState,
  ) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.95,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header - simple white card with black/grey content
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: NetworkImage(
                        _getValidImageUrl(profilePic, fullname),
                      ),
                      onBackgroundImageError: (_, __) {},
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
                              color: Colors.black,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            email,
                            style: TextStyle(color: Colors.grey[700]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              if (_getHeaderText(emp['department']).isNotEmpty)
                                Chip(
                                  label: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.business,
                                        size: 14,
                                        color: Colors.black87,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(_getHeaderText(emp['department'])),
                                    ],
                                  ),
                                  backgroundColor: Colors.white,
                                  labelStyle: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 11,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  side: const BorderSide(color: Colors.grey),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              if (_getHeaderText(emp['designation']).isNotEmpty)
                                Chip(
                                  label: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.work,
                                        size: 14,
                                        color: Colors.black87,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(_getHeaderText(emp['designation'])),
                                    ],
                                  ),
                                  backgroundColor: Colors.white,
                                  labelStyle: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 11,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  side: const BorderSide(color: Colors.grey),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black87),
                      onPressed: _closeEmployeeDetails,
                    ),
                  ],
                ),
              ),

              // Content - Responsive layout
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 800;
                      if (isMobile) {
                        // Stack vertically on mobile
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildPersonalInfoCard(emp),
                            const SizedBox(height: 16),
                            _buildEmergencyContactCard(emp),
                            const SizedBox(height: 16),
                            _buildDocumentsCard(
                              email,
                              docs,
                              selectedDoc,
                              setDialogState,
                            ),
                            const SizedBox(height: 16),
                            _buildAwardsCard(setDialogState),
                          ],
                        );
                      } else {
                        // Side by side on larger screens
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Column - Personal Info & Emergency Contact
                            Expanded(
                              flex: 1,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildPersonalInfoCard(emp),
                                  const SizedBox(height: 16),
                                  _buildEmergencyContactCard(emp),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Right Column - Documents & Awards
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildDocumentsCard(
                                    email,
                                    docs,
                                    selectedDoc,
                                    setDialogState,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildAwardsCard(setDialogState),
                                ],
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalInfoCard(Map<String, dynamic> emp) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: Colors.blue[600], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Personal Information',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Department', emp['department'] ?? 'Not provided'),
            _buildDetailRow(
              'Designation',
              emp['designation'] ?? 'Not provided',
            ),
            _buildDetailRow('Phone', emp['phone'] ?? 'Not provided'),
            _buildDetailRow(
              'Employment Type',
              emp['employment_type'] ?? 'Not provided',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyContactCard(Map<String, dynamic> emp) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.favorite, color: Colors.red[500], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Emergency Contact',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailRow(
              'Name',
              emp['emergency_contact_name'] ?? 'Not provided',
            ),
            _buildDetailRow(
              'Relationship',
              emp['emergency_contact_relationship'] ?? 'Not provided',
            ),
            _buildDetailRow(
              'Phone',
              emp['emergency_contact_no'] ?? 'Not provided',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 13),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsCard(
    String email,
    Map<String, dynamic>? docs,
    String? selectedDoc,
    StateSetter setDialogState,
  ) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Icon(Icons.description, color: Colors.blue[600], size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Documents',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_selectedDoc != null)
              Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      setDialogState(() => _selectedDoc = null);
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back to Documents'),
                  ),
                  const SizedBox(height: 16),
                  _buildDocumentViewer(_selectedDoc!),
                ],
              )
            else if (_docs != null && _docs!.isNotEmpty)
              ..._docs!.entries
                  .where(
                    (e) =>
                        e.key != 'email_id' &&
                        e.key != 'id' &&
                        e.key != 'email' &&
                        e.value is String &&
                        (e.value as String).trim().isNotEmpty,
                  )
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        color: Colors.grey[50],
                        child: ListTile(
                          leading: const Icon(Icons.description),
                          title: Text(
                            entry.key.replaceAll('_', ' '),
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: ElevatedButton(
                            onPressed: () {
                              setDialogState(
                                () => _selectedDoc = entry.value.toString(),
                              );
                            },
                            child: const Text(
                              'View',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.description,
                        size: 48,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 8),
                      const Text('No documents available'),
                      const SizedBox(height: 4),
                      Text(
                        'This employee hasn\'t uploaded any documents yet',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAwardsCard(StateSetter setDialogState) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.emoji_events,
                        color: Colors.amber[600],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Awards & Achievements',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_awards.length} awards',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_awards.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.emoji_events,
                        size: 48,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 8),
                      const Text('No awards yet'),
                      const SizedBox(height: 4),
                      Text(
                        'This employee hasn\'t received any awards',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._awards.map(
                (award) => Card(
                  color: Colors.amber[50],
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getAwardIcon(award['title'] ?? ''),
                        color: Colors.amber[800],
                      ),
                    ),
                    title: Text(
                      award['title'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (award['description'] != null)
                          Text(award['description']),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('MMM d, y').format(
                                DateTime.parse(
                                  award['created_at'] ??
                                      DateTime.now().toIso8601String(),
                                ),
                              ),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: award['photo'] != null
                        ? TextButton.icon(
                            onPressed: () {
                              setState(() => _selectedDoc = award['photo']);
                              setDialogState(() {});
                            },
                            icon: const Icon(Icons.visibility, size: 16),
                            label: const Text(
                              'View',
                              style: TextStyle(fontSize: 11),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
